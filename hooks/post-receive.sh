#!/bin/bash
# post-receive

# Command to get two IDs for call this hook for testing
# git log -2 --format=oneline --reverse
# ./hooks/post-receive $FROM_ID $TO_ID master
umask 022

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


if [[ $branch =~ master$ ]]; then
    echo "Deploy launched"
else
    echo "Deploy only on master branch"
    exit 0
fi

# Project's name from the path of the repository GIT
repo_name=$(sed -ne '1p' "$GIT_DIR/description" 2>/dev/null)
echo "Project: $repo_name"

# Directory to build the project
build_dir="/tmp/$newrev"
if [ -d $build_dir ]; then
    rm -rf $build_dir;
fi
mkdir $build_dir
git archive $newrev | tar -x --directory $build_dir

# Project's directory Web
www_dir="/home/www/$repo_name"

# Create directories of project for cache date of build, the differents releases and the config of build
mkdir -p $www_dir/{cache,releases,config,log,run}
cache_dir="$www_dir/cache"
config_dir="$www_dir/config"
releases_dir="$www_dir/releases"
log_dir="$www_dir/log"
run_dir="$www_dir/run"

# Call the script to compile the project
echo "Go to build the project"
$HOME/bin/nodejs/bin/compile "$build_dir" "$cache_dir" "$config_dir"
echo "compiled: $?"
if [ $? -eq 0 ]; then
    echo "Deploy project: $repo_name"
    if [ -d "$releases_dir/$newrev" ]; then rm -rf "$releases_dir/$newrev"; fi
    mv "$build_dir" "$releases_dir/"
    echo "Stop server nginx"
    sudo service nginx stop
    echo "Stop script"
    sudo service wcb2014 stop
    echo "Change the link current on the new release"
    if [ -f "$www_dir/current" ]; then rm -f current; fi
    ln -s "$www_dir/releases/$newrev" "$www_dir/current"
    sudo chown -R git:www-data "$www_dir/current/"
    echo "Launch script"
    sudo service wcb2014 start
    echo "Launch server nginx"
    sudo service nginx start
else
    rm -rf $build_dir
    echo >&2 "Error in compile script"
    exit 1
fi

echo "End of script"
exit 0

# vim: set ts=4 sw=4 et ai ft=sh:
