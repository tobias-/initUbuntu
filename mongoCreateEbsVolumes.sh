#!/bin/bash -eu

echo "This command should probably be run on your desktop client to avoid putting dangerous keys on server."
echo "Confirm that you know this (Enter continue & Ctrl-C to abort)"
read A



SCRIPT_HOME="$(readlink -f "$(dirname "$(readlink -f "$0")")")"

. $SCRIPT_HOME/scripts/functions.bash

if ! which aws >/dev/null; then
	sudo apt-get install awscli
	if [ -d ~/.aws ]; then
		echo "Configure aws now."
		aws
		exit 1
	fi
fi

if [[ $# -ne 2 ]]; then
	echo "Usage: $0 <region> <instanceId>"
	exit 1
fi

region="$1"
instanceId="$2"
echo "This host's Instance Id: $instanceId"

zone=$(aws --region $region ec2 describe-instances  | $SCRIPT_HOME/scripts/getAZ.groovy $instanceId)
echo Availability zone: $zone


echo
echo "To be able to use EBS snapshot backups, combined database and log volume is required."
echo "Separate partitions are faster than combined"
read -p 'Use [C]ombined or [S]eparate database and log volumes? (S/C) ' cs
case $cs in
[Ss])
	read -p "Size of the database in GiB? " -e -i 400 dbSize
	read -p "Size of the journal in GiB? " -e -i 25 journalSize
	;;
[Cc])
	read -p "Size of the journal+database in GiB? " -e -i 400 dbSize
	journalSize=0
	;;
*)
	echo "You failed"
	exit 1
	;;
esac

read -p "Size of the /log+/backup directory in GiB? " -e -i $dbSize logSize
read -p "Guaranteed iops (0% for disable)? " -e -i 0% iops

ebsType=gp2
dbIops=
journalIops=
percentage=${iops%%%}
if [[ $percentage =~ ^[0-9]*[1-9][0-9]*$ ]]; then
	dbType=io1
	dbIops="--iops $(($percentage * $dbSize))"
	ebsType=io1
	journalIops="--iops $(($percentage * $journalSize))"
fi

echo "Doing dry-run"
aws --region $region ec2 create-volume --size $dbSize --volume-type $ebsType --availability-zone $zone $dbIops --dry-run || true
aws --region $region ec2 create-volume --size $logSize --volume-type $ebsType --availability-zone $zone --dry-run || true
if [[ $journalSize -gt 0 ]]; then
	aws --region $region ec2 create-volume --size $journalSize --volume-type $ebsType --availability-zone $zone $journalIops --dry-run || true
fi

read -p "If all you have above is dry-run errors, creation will probably work. (Enter to continue, Ctrl-C to abort)" 


dbVolId=$(aws --region $region ec2 create-volume --size $dbSize --volume-type $ebsType --availability-zone $zone $dbIops | grep '"VolumeId":' | egrep -o 'vol-[^"]+')
logVolId=$(aws --region $region ec2 create-volume --size $logSize --volume-type $ebsType --availability-zone $zone | grep '"VolumeId":' | egrep -o 'vol-[^"]+')
if [[ $journalSize -gt 0 ]]; then
	journalVolId=$(aws --region $region ec2 create-volume --size $journalSize --volume-type $ebsType --availability-zone $zone $journalIops | grep '"VolumeId":' | egrep -o 'vol-[^"]+')
fi

echo "dbVolId: $dbVolId"
echo "logVolId: $logVolId"
if [[ $journalSize -gt 0 ]]; then
	echo "journalVolId: $journalVolId"
fi
echo
echo "Sleeping 30 secs for volume to be available"
sleep 30

aws --region $region ec2 attach-volume --volume-id $dbVolId --instance-id $instanceId --device xvdd
aws --region $region ec2 attach-volume --volume-id $logVolId --instance-id $instanceId --device xvdl
if [[ $journalSize -gt 0 ]]; then
	aws --region $region ec2 attach-volume --volume-id $journalVolId --instance-id $instanceId --device xvdj
fi

aws --region $region ec2 modify-instance-attribute --instance-id $instanceId --block-device-mappings "[{\"DeviceName\": \"xvdd\",\"Ebs\":{\"DeleteOnTermination\":true}}]"
aws --region $region ec2 modify-instance-attribute --instance-id $instanceId --block-device-mappings "[{\"DeviceName\": \"xvdl\",\"Ebs\":{\"DeleteOnTermination\":true}}]"
if [[ $journalSize -gt 0 ]]; then
	aws --region $region ec2 modify-instance-attribute --instance-id $instanceId --block-device-mappings "[{\"DeviceName\": \"xvdj\",\"Ebs\":{\"DeleteOnTermination\":true}}]"
fi

echo "Setup complete without errors now run ./mongoSetupDatabases.sh on server"
