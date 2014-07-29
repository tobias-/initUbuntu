#!/bin/bash

#export pth=4.0.4
export pth=$(repo info 2>&1 | sed -r 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})*)?m//g' | head -1 | grep --color=never -o "[^/]*$")

find [^4]* -iname *.java -type f  | egrep -v "(test|javassist)" | perl -ne 'chomp; $orig = $_; if (/^.*?\/(?:src(?:\/main\/java)*|java)(\/.*\/)([^\/]+)$/) { $pack=$ENV{pth}.$1; system("mkdir", "-p", $pack); system("cp", $orig, $pack.$2); }' 

cd $pth
7z a ../${pth}.zip
