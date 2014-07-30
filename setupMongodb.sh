#!/bin/bash -eu

if [[ $(id -u) != 0 ]]; then
	echo "Must be run as root"
	exit 1
fi

if [ -d /data ]; then
	echo "You already have a /data directory"
	exit 1
fi

read -p 'Use [E]bs or [I]nstance storage? (E/I) ' A
if [[ $A == [eE] ]]; then
	exec scripts/setupMongodb_ebs.sh
elif [[ $A == [iI] ]]; then
	mkdir -p /log
	mkdir -p /mnt/data
	chown -R mongodb:mongodb /mnt/data /log
	sudo ln -s /mnt/data /data
else
	echo "You failed"
fi

