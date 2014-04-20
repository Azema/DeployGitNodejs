#!/bin/bash
# pre-receive

# Command to get two IDs for call this hook for testing
# git log -2 --format=oneline --reverse
# ./hooks/pre-receive $FROM_ID $TO_ID refs/heads/master

# Parameters
if ! [ -t 0 ]; then
    read -a ref
fi
oldrev=${ref[0]}
newrev=${ref[1]}
IFS='/' read -ra REF <<< "${ref[2]}"
branch="${REF[2]}"


GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
if [ -z "$GIT_DIR" ]; then
    echo >&2 "fatal: post-receive: GIT_DIR not set"
    exit 1
fi

build_dir=$(mktemp -d)
git archive $newrev | tar -x --directory $build_dir

is_node=$($HOME/bin/nodejs/bin/detect "$build_dir")
rm -rf "$build_dir"

if [ $is_node == "no" ]; then
	echo >&2 "This project does not contain package.json file"
	exit 1
else
	echo "Ok to build and deploy this project"
	exit 0
fi

# vim: set ts=4 sw=4 et ai ft=bash:
