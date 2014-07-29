#!/bin/bash -eux


if [ $(whoami) != root ] || ! ps ax | grep -q "^ *$$.*bash -eux"; then
    exec sudo $0
fi
source scripts/functions.bash

if ! installed mongodb-org; then
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
	echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' >/etc/apt/sources.list.d/mongodb.list
	apt-get update
	apt-get install mongodb-org
else
	dpkg --set-selections <<EOF
mongodb-org install
mongodb-org-server install
mongodb-org-shell install
mongodb-org-mongos install
mongodb-org-tools install
EOF
fi

apt-get -u upgrade

dpkg --set-selections <<EOF
mongodb-org hold
mongodb-org-server hold
mongodb-org-shell hold
mongodb-org-mongos hold
mongodb-org-tools hold
EOF
