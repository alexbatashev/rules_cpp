#!/bin/bash

set -eu

if [ -d "$1/usr" ]; then
    for dir in $1/usr/local/*/
    do
        dir=${dir%*/}
        mv $dir $1/${dir##*/}
    done

    rm -r $1/usr
fi