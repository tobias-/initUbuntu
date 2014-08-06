#!/bin/bash -eu

SCRIPT_HOME="$(readlink -f "$(dirname "$(readlink -f "$0")")")"

if [[ $(id -u) != 0 ]]; then
	echo "Must be run as root"
	exit 1
fi

. $SCRIPT_HOME/functions.bash

if ! installed awscli; then
	apt-get install awscli
fi


instanceId=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "This host's Instance Id: $instanceId"

zone=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
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
aws ec2 create-volume --size $dbSize --volume-type $ebsType --availability-zone $zone $dbIops --dry-run || true
aws ec2 create-volume --size $journalSize --volume-type $ebsType --availability-zone $zone $journalIops --dry-run || true
aws ec2 create-volume --size $logSize --volume-type standard --availability-zone $zone --dry-run || true

read -p "If all you have above is dry-run errors, creation will probably work. (Enter to continue, Ctrl-C to abort)" 


dbVolId=$(aws ec2 create-volume --size $dbSize --volume-type $ebsType --availability-zone $zone $dbIops | grep '"VolumeId":' | egrep -o 'vol-[^"]+')
journalVolId=$(aws ec2 create-volume --size $journalSize --volume-type $ebsType --availability-zone $zone $journalIops | grep '"VolumeId":' | egrep -o 'vol-[^"]+')
logVolId=$(aws ec2 create-volume --size $logSize --volume-type standard --availability-zone $zone | grep '"VolumeId":' | egrep -o 'vol-[^"]+')

echo "dbVolId: $dbVolId"
echo "journalVolId: $journalVolId"
echo "logVolId: $logVolId"

aws ec2 attach-volume --volume-id $dbVolId --instance-id $instanceId --device xvdd
aws ec2 attach-volume --volume-id $journalVolId --instance-id $instanceId --device xvdj
aws ec2 attach-volume --volume-id $logVolId --instance-id $instanceId --device xvdl

if ! grep -q "mongoData" /etc/fstab; then
	cat >>/etc/fstab <<EOF
/dev/xvdd /data ext4 defaults,auto,noatime,noexec 0 0
/dev/xvdj /journal ext4 defaults,auto,noatime,noexec 0 0
/dev/xvdl /log ext4 defaults,auto,noatime,noexec 0 0
EOF
fi

mkdir -p /log /journal /data

busywait() {
	while ! [ -b $1 ]; do sleep 1; done
}

echo
echo "Creating filesystems. This may take a while"
echo
mkfs.ext4 -q /dev/xvdd -L mongoData &
mkfs.ext4 -q /dev/xvdj -L mongoJournal &
mkfs.ext4 -q /dev/xvdl -L mongoLog &
wait
busywait /dev/xvdd
busywait /dev/xvdj
busywait /dev/xvdl

echo "Mounting filesystems"
mount /data
mount /journal
mount /log

chown -R mongodb:mongodb /log /journal /data
ln -s /journal /data/journal


echo "Setup complete without errors"

