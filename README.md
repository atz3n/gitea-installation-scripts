# gitea-server

repository for gitea server hosting


## Limitation

The installation and update scripts are currently only tested on x64 machines with Ubuntu 16.04 and SQLite.


## Server Installation

1. copy `install-gitea.sh` to the root user of the server
2. login as root via ssh
3. make script executable `chmod 700 install-gitea.sh`
4. execute script `./install-gitea.sh`
5. after automatic reboot open gitea via a browser and start the initial configuration. **CAUTION**: Select SQLite database
6. after initial configuration, change permssions of /etc/gitea and /etc/gitea/app.ini with `chmod 750 /etc/gitea && chmod 644 /etc/gitea/app.ini`


## Backups

### Creating

If you want to **create** a backup **manually**, login as root and execute the backup script `./create-bakup.sh`. The backup will be created under: `backup-<unix timestamp>.tar.gz` and can be found inside the backup users persist folder `/home/<GITEA_BACKUP_NAME>/persist/`. Creating a backup manually is usually not necessary because there is a daemon running that **creates** backups **periodically**. The period can be configured via the `GITEA_BACKUP_EVENT` config variable inside the `install-gitea.sh` script.
    

### Persisting

1. preparation (you can skip this step if you allready set up your backup system)
    1. login as root and **add** the **ssh-rsa public key** of the remote machine to persist backups via the `add-backup-ssh-key.sh` script.
2. **scp** with the backup user at the backup machine to hosts persist folder `scp <GITEA_BACKUP_NAME>@<GITEA_DOMAIN>:persist/* /path/to/backup/storage`

### Restoring

1. preparation (see preparation in Persisting)
2. **scp** with the backup user at the backup machine to hosts restore folder `scp /path/to/backup/storage/<backup name> <GITEA_BACKUP_NAME>@<GITEA_DOMAIN>:restore/`
3. login via root and execute the `restore-backup.sh` script