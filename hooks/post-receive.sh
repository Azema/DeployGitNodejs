#!/bin/bash
# post-receive

# Command to get two IDs for call this hook for testing
# git log -2 --format=oneline --reverse
# echo $FROM_ID $TO_ID refs/heads/master | ./hooks/post-receive
umask 022

# Load some convenience functions like status(), echo(), and indent()
source $HOME/bin/nodejs/bin/common.sh

# Parameters
if ! [ -t 0 ]; then
    read -a ref
fi
# Resolv hash revisions and branch name for the current push
oldrev=${ref[0]}
newrev=${ref[1]}
IFS='/' read -ra REF <<< "${ref[2]}"
branch="${REF[2]}"

# Resolv the git directory
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
if [ -z "$GIT_DIR" ]; then
    error "fatal: post-receive: GIT_DIR not set"
    exit 1;
fi

# Check the branch name and exit if it's not master branch
if [[ $branch =~ master$ ]]; then
    status "Deploy launched"
else
    status "Deploy only on master branch"
    exit 0
fi

# Project's name from the path of the repository GIT
repo_name=$(sed -ne '1p' "$GIT_DIR/description" 2>/dev/null)
if [ "$repo_name" == "" ]; then
    error "Project name not found in description of repository. Please, set the description of your repository."
    exit 1;
fi
status "Project: $repo_name"

# Directory to build the project
build_dir="/tmp/$newrev"
if [ -d $build_dir ]; then
    rm -rf $build_dir;
fi
mkdir $build_dir
# Get archive of the project and send to directory build
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

# Resolv daemons from Procfile at the project's root
unset daemons
declare -A daemons
if [ -f "$build_dir/Procfile" ]; then
    eval $(awk -v quote='"' -F': ' '{ print "daemons["quote$1quote"]="quote$2quote; }' "$build_dir/Procfile");
fi
# Check if one daemon is define or if project's root contains server.js file
if [[ 0 -eq ${#daemons[*]} ]] && [[ ! -f "$build_dir/server.js" ]]; then
    error "No daemons found and no file server.js found at the project's root"
    exit 1;
elif [ 0 -eq ${#daemons[*]} ]; then
    status "Define server.js as script to launch"
    daemons["web"]="-m 1 --minUptime 1000 --spinSleepTime 1000 server.js";
fi

# Call the script to compile the project
status "Go to build the project"
echo ""
$HOME/bin/nodejs/bin/compile "$build_dir" "$cache_dir" "$config_dir"
if [ $? -eq 0 ]; then
    # Add blank line with the compile script
    echo ""
    status "Deploy project: $repo_name"
    # Remove the release directory if exists
    if [ -d "$releases_dir/$newrev" ]; then
        rm -rf "$releases_dir/$newrev";
    fi
    # Move build_dir to releases directory
    mv "$build_dir" "$releases_dir/"
    status "Stop server nginx"
    sudo service nginx stop
    status "Stop script(s)"
    for key in ${!daemons[*]}; do
        script=$(echo ${daemons[$key]} | awk '{print $NF}')
        status "Stop script: $key"
        forever stop $script > /dev/null 2>&1;
    done
    status "Change the link current on the new release"
    # Remove symbolic link if exists
    if [ -h "$www_dir/current" ]; then
        status "Remove the symbolic link"
        rm -f "$www_dir/current";
    fi
    # Create symbolic link to new release
    ln -s "$www_dir/releases/$newrev" "$www_dir/current"
    # Change group of release files to group Web
    sudo chown -R git:www-data "$www_dir/current/"
    status "Launch script(s)"
    # Move to the new release directory for start daemons
    cd "$www_dir/current/"
    for key in ${!daemons[*]}; do
        status "Start script: $key"
        forever start ${daemons[$key]} > /dev/null;
    done
    status "Launch server nginx"
    sudo service nginx start
else
    # compile error, remove build_dir
    rm -rf $build_dir
    error "Error in compile script"
    exit 1
fi

status "End of script"
exit 0

# vim: set ts=4 sw=4 et ai ft=sh:
