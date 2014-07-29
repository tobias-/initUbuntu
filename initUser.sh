#!/bin/bash -eux

key=$(md5sum $0 | cut -d' ' -f1)
if [[ -z ${1:-} ]] || [[ $1 != $key ]]; then
	source $0 $key

	bashrc=$HOME/.bashrc
	if ! grep -q redot $bashrc; then
		mkdir -p ~/bin
		cp -av ~/bin/ ~/bin/bash.bashrc
		echo >>~/.bashrc
		echo "~/bin/bash.bashrc" >>~/.bashrc
		echo "redot" >>~/.bashrc
		. ~/bin/bash.bashrc
		redot
	fi
fi
