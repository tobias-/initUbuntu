#!/bin/bash -eux

key=$(md5sum $0 | cut -d' ' -f1)
if [[ -z ${1:-} ]] || [[ $1 != $key ]]; then
	source $0 $key

	bashrc=$HOME/.bashrc
	if ! grep -q redot $bashrc; then
		mkdir -p ~/bin
		condCp ~/userBin/ ~/bin/bash.bashrc
		echo >>~/.bashrc
		echo "~/bin/bash.bashrc" >>~/.bashrc
		echo "redot" >>~/.bashrc
		. ~/bin/bash.bashrc
		redot
	fi
fi

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

