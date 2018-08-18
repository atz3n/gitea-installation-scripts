# gitea-server

repository for gitea server hosting


## Limitation

The installation and update scripts are currently only tested on x64 machines with Ubuntu 16.04 and SQLite.

## Server Installation

1. copy install-gitea.sh to root user of your server
1. login via ssh and root
1. change permissions with `chmod 700 install-gitea.sh`
1. execute installation script with `./install-gitea.sh`
1. after automatic reboot open gitea via a browser and start initial configuration. **CAUTION**: Select SQLite database
1. after initial configuration, change permssions of /etc/gitea and /etc/gitea/app.ini with `chmod 750 /etc/gitea && chmod 644 /etc/gitea/app.ini`