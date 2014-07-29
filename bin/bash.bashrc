#!/bin/echo "Do not run this. It needs to be sourced"

add_path() {
	if [[ $PATH =~ :$1(:.*)?$ ]]; then
		#echo Already added $1
		echo -n
	else
		export PATH="$PATH:$1"
	fi
}


redot() {
	for A in ~/bin/*.bashrc; do 
		. "$A"
	done
}

gs() {
	`which git` status "$@"
}

gds() {
	`which git` diff --stat "$@"
}

gdc() {
	`which git` diff --cached "$@"
}

gd() {
	`which git` diff "$@"
}

ga() {
	`which git` add "${@##[ab]/}"
}

git() {
	if [[ $1 == checkout ]]; then
		shift
		`which git` checkout "${@##[ab]/}"
	elif [[ $1 == "reset" ]] ;then
		shift
		`which git` reset "${@##[ab]/}"
	elif [[ $1 == "add" ]] ;then
		shift
		ga "$@"
	else
		`which git` "${@##[ab]/}"
	fi
}


setwindow() {
  [ $# != 0 ] && "$@"
  cksum=$(($(hostname -s | cksum | cut -d' ' -f1) % 100))
  case $cksum in
	10 )
		color=30 ;;
	88 | 41 | 91 )
		color=31 ;;
	43 )
		color=37 ;;
	49)
		color=35 ;;
	99)
		color=33 ;;
	53)
		color=53 ;;
	*)
		color=35 ;;
  esac
  usercolor=32
  [ `whoami` == "root" ] && usercolor=31


  export PS1="\[\033[00m\]\t \[\033[01;${usercolor}m\]\u\[\033[0;33m\]@\[\033[01;${color}m\]\h\[\033[0;33m\]:\[\033[00m\]\w\[\033[0;32m\]\$(__git_ps1)\[\033[0;33m\]> \[\033[00m\]"
  if [ "$TERM" = "xterm" -o "$TERM" = "rxvt" -o "$TERM" = "Eterm" -o "$TERM" = "kterm" ]; then
    #xtermset -fg black -fg gray -title "`whoami`@`uname -n` running `uname -s` `uname -r`"
    echo -ne "\033]0;`whoami`@`uname -n` running `uname -s` `uname -r`\007"
    export PS1="\[\033]0;\u@\h running `uname -s` `uname -r`:\w\007\]$PS1"
  fi
}
setwindow


get_device() {
	if [[ -n $ANDROID_SERIAL ]]; then
		echo -n "-s $ANDROID_SERIAL"
	elif adb devices | grep -q "device$"; then
		if [[ $(adb devices | grep -v "emulator" | grep -c "device$") == 1 ]]; then
			echo -n "-s "
			adb devices | grep "device$" | grep -v "emulator"| cut -d'	' -f1
		fi
	elif [[ $(adb devices | grep -c "emulator$") == 1 ]]; then
		echo -n -- "-s "
		adb devices | grep -q "emulator$" | cut -d'	' -f1
	fi
}



eight() {
	perl -we '
		use strict;
		my %event = ("\n" => 66, "\r" => 66, "\t" => 61, " " => 62);
		my $cmd = shift @ARGV;
		my $x;
		if ($ARGV[0]) {
			$x = join(" ", @ARGV);;
		} else {
			$x = join("", <STDIN>);
		}
		$x =~ s/ /%s/g;
		while ($x =~ /^(.*?)([ \n\r\t])(.*)/s) {
			$x = $3;
			if ($1) {
				system "$cmd text $1\n";
			}
			system("$cmd keyevent ".$event{$2});
		}
		if ($x) {
			system("$cmd text $x");
		}
	' "adb $(get_device) shell input" "$@"
}

createUser() {
	local user x
	if [[ -z $1 ]]; then
		user=`pwgen 10`
	else
		user=$1
	fi
	echo "Creating user $user"
	echo -e "$user@example.com" | eight
	echo "Accept terms..."
	read x
	echo -e "qwe123asd\tqwe123asd" | eight
	sleep 5
	echo -ne "$user" | eight
}

logcat() {
	local xargs
	adb $(get_device) logcat -v time "$@" | \
		egrep --line-buffered -v "D/(B?Burstly|AndroidRuntime|LightsService|dalvikvm|fast-dormancy|HeadsetPhoneState)" | \
		egrep --line-buffered -v "V/WindowManager" | \
		egrep --line-buffered -v "I/(chromium|Ads|Web Console|InputDispatcher|Burstly|GAV2)" | \
		egrep --line-buffered -v "W/(MillennialMediaSDK|GAV2|WindowManager|CellInfoLte|Settings)" | \
		egrep --line-buffered -v "TCPFinAggregation|Finsky|QCNEA|lights-sniffer|GCoreUlr|InputMethodManagerService|StatusBar.NetworkController|QcConnectivityService|MillennialMediaSDK" | \
		egrep --line-buffered --color=always "([EW]/|)"
	#adb logcat "$@" | egrep -v "D/(AndroidRuntime|LightsService|dalvikvm|burstly|Burstly)" | egrep -v "V/WindowManager" | egrep -v "I/(Burstly|GAV2)" | grep -v "W/(GAV2|WindowManager)" | grep -v "Finsky" | egrep --color=always "([EW]/|)"
}


grc() {
	if [[ $# != 0 ]]; then
		git reset HEAD -- "$@"
		git checkout HEAD -- "$@"
	fi
}

awseu() {
	local both ip user
	both=$1
	shift
	ip=${both##*@}
	user=
	if [[ $both =~ .*@.* ]]; then
		user=${both%%@*}@
	fi
	if [[ $ip =~ ^i-[a-f0-9]*$ ]]; then
		ip=`getawsip_eu $ip`
	fi
	TERM=${TERM%%-color}-color ssh -l ec2-user -t -oPasswordAuthentication=no -oStrictHostKeyChecking=no $user$ip "$@" || \
	TERM=${TERM%%-color}-color ssh -l ubuntu -t -oPasswordAuthentication=no -oStrictHostKeyChecking=no $user$ip "$@"
}

aws() {
	local both ip user
	
	both=$1
	shift
	ip=${both##*@}
	user=
	if [[ $both =~ .*@.* ]]; then
		user=${both%%@*}@
	fi
	if [[ $ip =~ ^i-[a-f0-9]*$ ]]; then
		ip=`getawsip $ip`
	fi
	TERM=${TERM%%-color}-color ssh -l ec2-user -t -oPasswordAuthentication=no -oStrictHostKeyChecking=no $user$ip "$@" || \
	TERM=${TERM%%-color}-color ssh -l ubuntu -t -oPasswordAuthentication=no -oStrictHostKeyChecking=no $user$ip "$@"
}

awssync() {
	rsync -e "ssh -l ec2-user -oPasswordAuthentication=no -oStrictHostKeyChecking=no" "$@" || \
	rsync -e "ssh -l ubuntu -oPasswordAuthentication=no -oStrictHostKeyChecking=no" "$@"

}

___getReplSetName() {
	LC_ALL=C perl -ne '/.*replSetName: (.*)$/ && print $1' </etc/mongod.conf
	if mount | grep -qF '/data'; then
		echo -n ":Replica"
	elif [[ $(readlink /data) == /mnt/data ]]; then
		echo -n ":Primary"
	fi
}

add_path $HOME/bin
export ANDROID_HOME=$HOME/bin/adt/sdk
export MAVEN_OPTS="-XX:MaxPermSize=256M -Dmaven.wagon.http.ssl.insecure=true -Dmaven.wagon.http.ssl.allowall=true"

