# gitea-server

repository for gitea server hosting


## Limitation

The installation and update scripts are currently only tested on x64 machines with Ubuntu 16.04 / Ubuntu 18.04 and SQLite.

## Server Installation

1. copy install-gitea.sh to root user of your server
2. login via ssh and root
2. change permissions with `chmod 700 install-gitea.sh`
3. execute installation script with `./install-gitea.sh`
4. after automatic reboot open gitea via a browser and start initial configuration **CAUTION**: Select SQLite database
5. after configuration, login again and change following permissions: `chmod 750 /etc/gitea && chmod 644 /etc/gitea/app.ini`