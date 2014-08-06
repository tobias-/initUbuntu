#!/bin/bash -eu

SCRIPT_HOME="$(readlink -f "$(dirname "$(readlink -f "$0")")")"

if [[ $(id -u) != 0 ]]; then
	echo "Must be run as root"
	exit 1
fi

if [ -b /dev/xvdd ] && [ -b /dev/xvdj ] && [ -b /dev/xvdl ]; then
	echo "All ebs 'drives' found"
else
	echo "One or more EBS 'drives' missing"
	exit 1
fi

if ! grep -q "mongoData" /etc/fstab; then
	cat >>/etc/fstab <<EOF
LABEL=mongoData /data ext4 defaults,auto,noatime,noexec 0 0
LABEL=mongoJournal /journal ext4 defaults,auto,noatime,noexec 0 0
LABEL=mongoLog /log ext4 defaults,auto,noatime,noexec 0 0
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

