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
build_dir=$(mktemp -d)
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

whitelist_regex=${2:-''}
blacklist_regex=${3:-'^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH)$'}
if [ -d "$config_dir" ]; then
    for e in $(ls $config_dir); do
        echo "$e" | grep -E "$whitelist_regex" | grep -qvE "$blacklist_regex" && export "$e=$(cat $config_dir/$e)"
    done
fi

# Call the script to compile the project
echo "Go to build the project"
$HOME/bin/nodejs/bin/compile "$build_dir" "$cache_dir" "$config_dir"
if [ $? -eq 0 ]; then
    echo "Deploy project: $repo_name"
    mkdir "$releases_dir/$newrev"
    cp -rp "$build_dir/*" "$releases_dir/$newrev/"
    rm -rf $build_dir
    echo "Stop server nginx"
    sudo service nginx stop
    echo "Stop script"
    sudo service wcb2014 stop
    cd $www_dir
    echo "Change the link current on the new release"
    if [ -f "$www_dir/current" ]; then rm -f current && ln -s "./releases/$newrev" current fi
    #chmod -R g+w "$www_dir/current/"
    sudo chown -R git:www-data "$www_dir/current/"
    echo "Launch script"
    #forever start -m 5 -p "$www_dir" -a -l "$log_dir/forever.log" -o "$log_dir/$repo_name.log" -e "$log_dir/error.log" --pidFile "$run_dir/$repo_name.pid" --sourceDir "$www_dir/current/" --minUptime 1000 --spinSleepTime 5000 server.js
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
