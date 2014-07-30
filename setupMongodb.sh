#!/bin/bash -eu

if [[ $(id -u) != 0 ]]; then
	echo "Must be run as root"
	exit 1
fi

if [ -d /data ]; then
	echo "You already have a /data directory"
else
	read -p 'Use [E]bs or [I]nstance storage? (E/I) ' A
	if [[ $A == [eE] ]]; then
		scripts/setupMongodb_ebs.sh
	elif [[ $A == [iI] ]]; then
		mkdir -p /log
		mkdir -p /mnt/data
		chown -R mongodb:mongodb /mnt/data /log
		sudo ln -s /mnt/data /data
	else
		echo "You failed"
	fi
fi


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
	while [ $a -lt 5 ] && !status mms-agent ; do
	    sleep 2
		let a++
	done
	status mms-agent || ( echo "This is bad. Please fix" ; exit 1)
	curl -s http://169.254.169.254/latest/meta-data/public-ipv4
fi
