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


## Backups

### Creating

If you want to **create** a backup **manually**, login as root and execute the backup script `./create-bakup.sh`. The backup will be created under: `backup-<unix timestamp>.tar.gz` and can be found inside backup users persist folder `/home/<backup user>/persist/`. Creating a backup manually is usually not needed because there is a daemon running which **creates** a backup **cyclical**. The cycle time can be configured via the `GITEA_BACKUP_EVENT` config variable inside the `install-gitea.sh` script.
    

### Persisting

1. preparation (you can skip this steps if you allready set up your backup system)
    1. login as root and **add** the **ssh-rsa public key** of the remote machine to persist backups via the `add-backup-ssh-key.sh` script.
2. scp with the backup user at the backup machine to hosts persist folder `scp <GITEA_BACKUP_NAME>@<GITEA_DOMAIN>:persist/* /path/to/backup/storage`

### Restoring

1. preparation (see **preparation in Persisting**)
2. scp with the backup user at the backup machine to hosts restore folder `scp /path/to/backup/storage/<backup name> <GITEA_BACKUP_NAME>@<GITEA_DOMAIN>:restore/`
3. login via root and execute the `restore-backup.sh` script