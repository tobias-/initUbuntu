#!/bin/bash -eux

echo "This command should probably be run on your desktop client to avoid putting dangerous keys on server."
echo "Confirm that you know this (Enter continue & Ctrl-C to abort)"
read A



SCRIPT_HOME="$(readlink -f "$(dirname "$(readlink -f "$0")")")"

. $SCRIPT_HOME/scripts/functions.bash

if ! installed awscli; then
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

read -p "How large do you want your database in GiB? " -e -i 400 dbSize
read -p "How large do you want your journal in GiB? " -e -i 25 journalSize
read -p "How large do you want log directory in GiB? " -e -i 20 logSize

read -p "Guaranteed iops (0% for disable)? " -e -i 0% iops

ebsType=standard
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
aws --region $region ec2 create-volume --size $journalSize --volume-type $ebsType --availability-zone $zone $journalIops --dry-run || true
aws --region $region ec2 create-volume --size $logSize --volume-type standard --availability-zone $zone --dry-run || true

read -p "If all you have above is dry-run errors, creation will probably work. (Enter to continue, Ctrl-C to abort)" 


dbVolId=$(aws --region $region ec2 create-volume --size $dbSize --volume-type $ebsType --availability-zone $zone $dbIops | grep '"VolumeId":' | egrep -o 'vol-[^"]+')
journalVolId=$(aws --region $region ec2 create-volume --size $journalSize --volume-type $ebsType --availability-zone $zone $journalIops | grep '"VolumeId":' | egrep -o 'vol-[^"]+')
logVolId=$(aws --region $region ec2 create-volume --size $logSize --volume-type standard --availability-zone $zone | grep '"VolumeId":' | egrep -o 'vol-[^"]+')

echo "dbVolId: $dbVolId"
echo "journalVolId: $journalVolId"
echo "logVolId: $logVolId"

aws --region $region ec2 attach-volume --volume-id $dbVolId --instance-id $instanceId --device xvdd
aws --region $region ec2 attach-volume --volume-id $journalVolId --instance-id $instanceId --device xvdj
aws --region $region ec2 attach-volume --volume-id $logVolId --instance-id $instanceId --device xvdl

echo "Setup complete without errors now run setupMongoDB on server"
