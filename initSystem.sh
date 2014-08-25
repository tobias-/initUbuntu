#!/bin/bash -eux


if [ $(whoami) != root ] || ! ps ax | grep -q "^ *$$.*bash -eux"; then
	chmod a+rx $0
	exec sudo $0
fi

key=$(md5sum $0 | cut -d' ' -f1)
if [[ -z ${1:-} ]] || [[ $1 != $key ]]; then
	source $0 $key

	
	if [ ! -d .git ]; then
		if [ ! -d initUbuntu ]; then
			aptGet git
			git clone https://github.com/tobias-/initUbuntu
		fi
		cd initUbuntu
	fi

	condCp localBin /usr/local/bin

	locale-gen en_US.UTF-8 sv_SE.UTF-8
	dpkg-reconfigure locales

	apt-get update
	apt-get -u dist-upgrade

	if false && [ ! -x /usr/local/bin/aws-rb ]; then
		add-apt-repository ppa:brightbox/ruby-ng
		apt-get update
		apt-get install ruby2.1 build-essential ruby2.1-dev
		gem install aws-sdk
	fi

	aptGet unzip p7zip-full zip tcpdump

	if ! installed oracle-java8-installer; then
		# Install all java versions
		add-apt-repository ppa:webupd8team/java
		apt-get update
		apt-get install oracle-java.-installer

	fi
	echo
	echo Installing JCE for the oracle java
	(
		tmp=`mktemp -d`
		extractJceProfile $tmp
		cd /usr/lib/jvm/java-6-oracle/jre/lib/security
		unzip -jo $tmp/jce_policy-6.zip */*.jar
		cd /usr/lib/jvm/java-7-oracle/jre/lib/security
		unzip -jo $tmp/UnlimitedJCEPolicyJDK7.zip */*.jar
		cd /usr/lib/jvm/java-8-oracle/jre/lib/security
		unzip -jo $tmp/jce_policy-8.zip */*.jar
	)
	
	aptGet groovy

	sed -r 's/^# *(.*history-search-.*)/\1/g' -i /etc/inputrc

	if [ ! -f /etc/network/if-up.d/mapLocalhost ]; then
		cp scripts/mapLocalhost /etc/network/if-up.d/mapLocalhost
	fi

	if ! installed nullmailer; then
		echo Input nullmailer config as tar.bz2.base64 or nothing. End with ctrl-d
		cat >nullmailer.base64
		if [ -s nullmailer.base64 ]; then
			base64 -d <nullmailer.base64 | ( cd /etc ; tar jx )
			aptGet nullmailer
		fi
	fi

	if [ ! -d /etc/.git ]; then
		aptGet git
		cd /etc
		email=$(git config --global --get user.email || true)
		if [[ -z $email ]]; then
			hostname=$(cat /etc/mailname)
			git config --global user.email "nobody@$hostname"
			git config --global user.name "Nobody"
		fi
		git init .
		chmod 0700 .git
		echo dG1wCiouc3dwCnF1ZXVlCg== | base64 -d >.gitignore
		git add .
		git commit -m "Initial commit"
		echo '* * * * * cd /etc ; git reset master ; git add . ; git commit -q -a -m "Crontabbed update" >/dev/null' >/etc/cron.d/etc_git
	fi

fi

aptGet() {
	for A in "$@"; do
		if ! installed "$A"; then
			apt-get install "$A"
		fi
	done
}

condCp() {
	[[ -n $1 ]] && [[ -n $2 ]]
	(
		cd $1
		for A in *; do
			if ! diff -q $A $2/$A; then
				[ -f $2/$A ] && diff $A $2/$A
				cp -i $A $2
			fi
		done
	)
}

installed() {
	if ! ( dpkg -s "$1" && dpkg -V "$1" ) >/dev/null 2>&1; then
		return 1
	fi
}

extractJceProfile() {
	[[ -n $1 ]]
	(
		cd $1
		base64 -d <<EOF | tar jx 
QlpoOTFBWSZTWcoKZBIAEZh/////////////////////////////////////////////4Dy/AD0P
rd3r316nrbvKa9vOd899X3nep99x49d3evN3o63vN3w7brzXdt7Pnbu3L6+87s7rr3PW896z3fbX
nb7vvt6Ot96++916t99zfb33vrm28++vH3ravvc++6enm92Ozvn33de83e28ezruN697duteuqe+
83z3Lj3fDvdtO+872nc6OTWmlMp3d7FnWvT3ah1q86173vdvd5zve4eOnWtU3qXbr3m928sHnba9
2d73tzVc927eve+33vfbxlTE9ExoEwJgmmTAaTAmRhM1MTTEngmAAmmm1GDRMBMmmjE0wTAAmJgm
k9PQAJgp4CZNoBPJkaAA0DRo0ZCYUMkmAmDU0yYEwE0wTCaYSeJk009ACYRPCYABNMJgTAAATDRN
MIGA000BppoGmjRoNBkNTEY0ATTCk/BNMBKGUATEwEyYABMTRiek9AaAEYmhk9GkME0wTCMTExkT
000ZNRsIGmp6aMTSaY1TxTyGEaap7TCbQCMQ00J4ABNqNBgFQyqn6ZMEwACMNABMAAExJ5DJgEzJ
kwmJo0NTyZJ6Gk00wjAAEGTEMNNRkxMamIyYmmCnpiaYCMmNCaaaYmjIwp+pqhlBNkEyYaAqftTG
jTTFG0Ghpk0yaNNACMVP09RqempvQTEyjwTEZU9piejRMEwmjTU/QTCajwCTbITNAAjJlNpo0xNT
yepiaYTamptqanlQaSIQaNU9GTCaepgABNMmTCYmmATIGmg01NpoKn7RT2TCNT0aYQnhCejQjZMj
QxDCT1PRkBPIZNJsjKT9NTU/JoaZMSbJlPTTTQ0NEoiJ2JIAoAjEgIwJuDqHcbUvpFkmDNkZlQkh
BExsCEEQWgCBiAUjAPphAGJ1MmmQgxEAAzjJhZB5GDKFMwPPJKYxT54TTDckCXzgtp6keQy4MtL5
zMYKIRmCcDwYBfwvuB4QEoARKA8ADPpwOAiTEAoozEYjAGAMQMQOCQGPeTgSiYECQECyb02NrSmI
sw1qzY4h0b0gyNwcAkRJ6JImo0KRIoJEigQpjEzqZxBbVxXHgTa0C7B4xuwcngtATIzqJ0BAG7qY
Sb8oDr7h4yQA/pMVLc5hMAU+Ri3Cpqj34xjGMYxjGMYxou47CAs5Otb+HZiRC6MjMYxjGMYz4bgJ
5dXxpqNEPin+rKFqJ5yTPfp0RPJAvUhCtqTg2mEH1N8nF3/ouJg8WaOERKOicg7jKc0gwMAYSc8c
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
//xdyRThQkMoKZBI
EOF
	)
}
