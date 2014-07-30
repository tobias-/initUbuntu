#!/bin/bash -eux


if [ $(whoami) != root ] || ! ps ax | grep -q "^ *$$.*bash -eux"; then
    exec sudo $0
fi
source scripts/functions.bash

markMongo() {
	[[ -n $1 ]]
	apt-mark $1 mongodb-org mongodb-org-server mongodb-org-shell mongodb-org-mongos mongodb-org-tools
}
	

if ! installed mongodb-org; then
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
	echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' >/etc/apt/sources.list.d/mongodb.list
	apt-get update
	apt-get install mongodb-org
else
	markMongo install
	apt-get update
fi

apt-get -u upgrade

markMongo hold
