#!/bin/bash -eu

if [ $# -ne 1 ]; then
	echo "Usage: $0 <ShardID>"
	echo "E.g.: $0 Shard1"
	exit 1
fi

SHARD=$1
SCRIPT_HOME="$(readlink -f "$(dirname "$(readlink -f "$0")")")"

. $SCRIPT_HOME/scripts/functions.bash


writeMongodConf() {
	cat >/etc/mongod.conf <<EOF
systemLog:
   destination: file
   path: "/log/mongodb.log"
   quiet: true
   logAppend: true
   timeStampFormat: iso8601-utc

storage:
   dbPath: /data
EOF

	if [ $1 = arbiter ]; then
	cat >>/etc/mongod.conf <<EOF
# Disable all database stuff
   journal:
      enabled: false
   smallFiles: true
   preallocDataFiles: false

EOF
	fi

	cat >>/etc/mongod.conf <<EOF
processManagement:
   fork: false

net:
   port: 27017
   http:
       enabled: true
       RESTInterfaceEnabled: true

replication:
    replSetName: $SHARD

operationProfiling:
# Disable profiling logging
    mode: off

EOF
}

if ! installed mongodb-org; then
	echo "Installing mongo first"
	$SCRIPT_HOME/mongoInstallOrUpgrade.sh
fi


if [[ $(id -u) != 0 ]]; then
	echo "Restarting as root"
	exec sudo $0 "$@"
fi

if [ -d /data ]; then
	echo "You already have a /data directory"
else
	read -p 'Use [E]bs, [I]nstance or [A]rbiter storage? (E/I/A) ' A
	case $A in
	[Aa])
		writeMongodConf arbiter
		dd if=/dev/zero bs=1M seek=1023 count=1 of=/log_filesystem
		mkfs.ext4 -F /log_filesystem
		echo "/log_filesystem /log ext4 defaults,noatime,loop,auto 0 0" >>/etc/fstab
		mkdir -p /data
		mkdir -p /log
		mount /log
		chown -R mongodb:mongodb /data /log
	;;
	[Ee])
		writeMongodConf normal
		scripts/mongoSetupDatabases_ebs.sh
	;;
	[Ii])
		writeMongodConf normal
		if ! mount | grep -qF '/mnt'; then
			mkfs.ext4 /dev/xvdb
			mount /dev/xvdb /mnt
		fi
		if ! [ -f /etc/init/mount-local-storage.conf ]; then
			cp $SCRIPT_HOME/scripts/mount-local-storage.conf /etc/init/
			chown root:root /etc/init/mount-local-storage.conf
		fi
		mkdir -p /log
		mkdir -p /mnt/data
		chown -R mongodb:mongodb /mnt/data /log
		ln -s /mnt/data /data
		;;
	*)
		echo "You failed"
		exit 1
		;;
	esac
fi


restart mongod || start mongod

if ! status mms-agent; then
	echo "Input mms-agent as tar.gz.base64. End with ctrl-d on empty line"
	cat >mms-agent.tar.gz.base64
	if [ -s mms-agent.tar.gz.base64 ]; then
		cat mms-agent.tar.gz.base64 | ( cd /opt ; base64 -d | tar jx )
		apt-get install python-pymongo
		sudo stop mms-agent || true
		sleep 2
		kill $(ps afx | egrep "/usr/bin/python /h{1,1}ome/ec2-user/mms-agent/agentProcess.py" | sed "s/.* //") || true
		cp scripts/mms-agent.conf /etc/init/
		start mms-agent

		ps afx | egrep --color=always '(|mms-agent)'
		echo "Trying 5 times to be sure it's not just being restarted"
		a=0
		while [ $a -lt 5 ] && ! status mms-agent ; do
			sleep 2
			let a++
		done
		status mms-agent || ( echo "This is bad. Please fix" ; exit 1)
		curl -s http://169.254.169.254/latest/meta-data/public-ipv4
		echo
	fi
fi
