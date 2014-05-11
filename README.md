# Project to deploy an app Node.js
This project embed the [Heroku Buildpack for Node.js](https://github.com/heroku/heroku-buildpack-nodejs).

French documentation on the server config for this tool (http://blog.phigrate.org/config-server-for-deploy-with-git-push/)

This project add a hook **post-receive** at placed to your bare repository Git of your project.
### The hook do:
* Check the Git directory
* Check the branch to deploy only master
* Retrieve the repository name from the description file
* Create a build directory
* Send an archive of the repository in build directory
* Retrieve the scripts to launch:
 * From the Procfile at the project root with format (name: command for forever) 
 * Else if no found Procfile, check if server.js exists at the project root
* Call compile script of the Heroku Buildpack
* If the return of compile is OK:
 * Move the build directory to releases directory
 * Keep the last 5 releases and remove other
 * Stop Nginx server
 * Stop scripts with forever
 * Remove and create a new symbolic link to the new release
 * Launch scripts with forever
 * Launch Nginx server

## Usage:

On your server, create a user **git**
```
$ sudo adduser --system --home /home/git --shell /usr/bin/git-shell git
```

Add permissions on **service nginx** to git user
```
$ sudo vim /etc/sudoers
```
Add this lines in sudoers file
```
Cmnd_Alias      NGINX=/usr/sbin/service nginx start, /usr/sbin/service nginx stop, /usr/sbin/service nginx status
git ALL=(root) NOPASSWD: NGINX,/bin/chown
```

Add this project in bin directory of git user
```
$ cd /home/git
$ mkdir -p bin/nodejs
$ sudo git clone https://github.com/Azema/DeployGitNodejs bin/nodejs
```

Create your bare repository of your project
```
$ sudo mkdir your_project.git
$ cd your_project.git
$ sudo git init --bare
$ cd hooks
$ sudo ln -s /home/git/bin/nodejs/hooks/post-receive.sh post-receive
$ sudo ln -s /home/git/bin/nodejs/hooks/pre-receive.sh pre-receive
```

Change the proprietary of files
```
$ sudo chown -R git:nogroup /home/git
```

Add your key ssh in git's authorized_keys file

And add your remote in your project
```
$ git remote add your_remote_name git@server_host:/home/git/your_project.git
$ git fetch your_remote_name
$ git push your_remote_name master
```

### Variables:
#### In post-receive hook:
* _user_: Define the user git
* _group_: Define the group Web
* _www_dir_: Define the Web directory

#### In Procfile
* One script by line
* The line begin with name of your script (web, daemon, etc...)
* Separe name and command line with **:**
* Add your parameters for forever launch (-l: logs forever, -o logs stdout, -e: logs stderr, etc...) see forever [documentation](https://github.com/nodejitsu/forever)
* You can use the variable _$log_dir_ => web_directory/log

Example:
```
web: -m 5 --minUptime 1000 --spinSleepTime 500 -a -l "$log_dir/server-forever.log" -o "$log_dir/server.log" -e "$log_dir/server-error.log" server.js) 
```

### Structure Web directory
```
/
|- cache/ (directory: contains the node_modules directory and node version)
|- config/ (directory: contains your config variables for your script)
|- current (symbolic link: point the last release)
|- log/ (directory: contains your log files)
|- releases/ (directory: contains the last releases)
```

## Tests
Test compile script with this command:
```
$ ./bin/test
```

## Versions

### Magny-cours (v1.2.0)

Keep the last 5 releases and remove other

### Carole (v1.1.0)

Compile script cache bower components if bower.json file exists

### Paul-Ricard (v1.0.0)

DeployGitNodejs first release.

- Deploy an application Node.js on git push
- Install npm modules dependencies
- Start application script with forever
