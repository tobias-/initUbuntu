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

