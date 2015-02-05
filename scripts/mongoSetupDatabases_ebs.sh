#!/bin/bash -eu

SCRIPT_HOME="$(readlink -f "$(dirname "$(readlink -f "$0")")")"

if [[ $(id -u) != 0 ]]; then
	echo "Must be run as root"
	exit 1
fi

if [ -b /dev/xvdd ] && [ -b /dev/xvdl ]; then
	echo "All ebs 'drives' found"
else
	instanceId=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
	zone=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
	region=${zone%?}
	echo "One or more EBS 'drives' missing."
	echo "You should probably run (from your local machine)"
	echo "./mongoCreateEbsVolumes.sh ${region} $instanceId"
	exit 1
fi

if ! grep -q "mongoData" /etc/fstab; then
	cat >>/etc/fstab <<EOF
LABEL=mongoData /data ext4 nobootwait,defaults,auto,noatime,noexec 0 0
LABEL=mongoLog /log ext4 nobootwait,defaults,auto,noatime,noexec 0 0
EOF
	if [ -d /dev/xvdj ]; then
		echo 'LABEL=mongoJournal /journal ext4 nobootwait,defaults,auto,noatime,noexec 0 0' >>fstab
	fi
fi

mkdir -p /log /journal /data

busywait() {
	while ! [ -b $1 ]; do sleep 1; done
}

echo
echo "Creating filesystems. This may take a while"
echo
mkfs.ext4 -q /dev/xvdd -L mongoData &
if [ -d /dev/xvdj ]; then
	mkfs.ext4 -q /dev/xvdj -L mongoJournal &
fi
mkfs.ext4 -q /dev/xvdl -L mongoLog &
wait
busywait /dev/xvdd
if [ -d /dev/xvdj ]; then
	busywait /dev/xvdj
fi
busywait /dev/xvdl

echo "Mounting filesystems"
mount /data
if [ -d /dev/xvdj ]; then
	mount /journal
fi
mount /log

chown -R mongodb:mongodb /log /data
if [ -d /dev/xvdj ]; then
	chown -R mongodb:mongodb /journal
	ln -s /journal /data/journal
fi
mkdir -p /log/backup
chown -R ubuntu:ubuntu /log/backup
ln -s /log/backup /backup

echo "Setup complete without errors"

