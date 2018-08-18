#!/bin/sh


##################################################################
# CONFIGURATION
##################################################################

GITEA_USER_NAME="git"

GITEA_VERSION="1.5.0"
GITEA_PORT="443"
GITEA_DOMAIN="gitea.some.one"
#GITEA_DOMAIN=$(hostname -I | head -n1 | cut -d " " -f1)

GITEA_BACKUP_NAME="gitbackup"
# GITEA_BACKUP_EVENT="*/1 *	* * *" # every minute (for testing purpose)
GITEA_BACKUP_EVENT="* 3	* * *" # every day at 03:00 (see https://wiki.ubuntuusers.de/Cron/ for syntax)


##################################################################
# CONFIGURATION
##################################################################


##################################################################
# VARIABLES
##################################################################

GITEA_SERVICE_FILE_CONTENT="
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target
#After=mysqld.service
#After=postgresql.service
#After=memcached.service
#After=redis.service

[Service]
# Modify these two values and uncomment them if you have
# repos with lots of files and get an HTTP error 500 because
# of that
###
LimitMEMLOCK=infinity
LimitNOFILE=65535
RestartSec=2s
Type=simple
User=${GITEA_USER_NAME}
Group=${GITEA_USER_NAME}
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web -c /etc/gitea/app.ini
Restart=always
Environment=USER=${GITEA_USER_NAME} HOME=/home/${GITEA_USER_NAME} GITEA_WORK_DIR=/var/lib/gitea
# If you want to bind Gitea to a port below 1024 uncomment
# the two values below
###
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target"


EDIT_SSH_COMMAND_SCRIPT_CONTENT="
#!/bin/sh
# This file is part of a workaround to enable repository cloning via ssh.
# An extra command to announce the work directory of gitea is needed inside the 
# command string of public shh keys (see <gitea user>/.ssh/authorized_keys).
# To achieve this, a service will be started that activates this script.
# This script then listens on file changes and adds the requiered GITEA_WORK_DIR=/var/lib/gitea command
# whenever the authorized_keys file changes.
while inotifywait /home/${GITEA_USER_NAME}/.ssh/authorized_keys; do sed -Ei 's/command=\"\/usr\/local\/bin\/gitea/command=\"GITEA_WORK_DIR=\/var\/lib\/gitea \/usr\/local\/bin\/gitea/g' /home/${GITEA_USER_NAME}/.ssh/authorized_keys; done"

EDIT_SSH_COMMAND_SERVICE_FILE_CONTENT="
[Unit]
Description=Adds GITEA_WORK_DIR command to ssh autorization keys
After=syslog.target
After=network.target

[Service]
RestartSec=2s
Type=simple
User=${GITEA_USER_NAME}
Group=${GITEA_USER_NAME}
WorkingDirectory=/home/${GITEA_USER_NAME}/
ExecStart=/bin/bash /home/${GITEA_USER_NAME}/edit-ssh-command.sh
Restart=always
Environment=USER=${GITEA_USER_NAME} HOME=/home/${GITEA_USER_NAME}

[Install]
WantedBy=multi-user.target"


INITIAL_APP_INI_CONTENT="
[server]
PROTOCOL=https
ROOT_URL = https://${GITEA_DOMAIN}:${GITEA_PORT}/
HTTP_PORT = ${GITEA_PORT}
CERT_FILE = /etc/gitea/cert.pem
KEY_FILE = /etc/gitea/key.pem"


BACKUP_SCRIPT_CONTENT="
su -c \"cd ~
       rm -f backup-*
       sqlite3 /var/lib/gitea/data/gitea.db .dump >gitea.sql
       cp /etc/gitea/app.ini /home/${GITEA_USER_NAME}
       tar -pcvzf backup-\$(date +'%s').tar.gz gitea-repositories/ gitea.sql app.ini
       rm gitea.sql
       rm app.ini\" \"${GITEA_USER_NAME}\"

rm -f /home/${GITEA_BACKUP_NAME}/backup-*
mv /home/${GITEA_USER_NAME}/backup-* /home/${GITEA_BACKUP_NAME}/"


RESTORE_SCRIPT_CONTENT="
echo \"[INFO] restoring backup ...\"
mv /home/${GITEA_BACKUP_NAME}/backup-*.tar.gz /home/${GITEA_USER_NAME}
chown ${GITEA_USER_NAME} /home/${GITEA_USER_NAME}/backup-*.tar.gz

su -c \"cd ~
       rm -rf gitea-repositories
       mkdir tmp
       cd tmp/
       tar -xzf /home/${GITEA_USER_NAME}/backup*.tar.gz 
       sqlite3 gitea.db < gitea.sql
       mv gitea-repositories/ /home/${GITEA_USER_NAME}/\" \"${GITEA_USER_NAME}\"

cp /home/${GITEA_USER_NAME}/tmp/app.ini /etc/gitea/
cp /home/${GITEA_USER_NAME}/tmp/gitea.db /var/lib/gitea/data/

su -c \"cd /var/lib/gitea/
        gitea admin regenerate keys -c /etc/gitea/app.ini\" \"${GITEA_USER_NAME}\"

rm -r /home/${GITEA_USER_NAME}/tmp
rm -r /home/${GITEA_USER_NAME}/backup*.tar.gz

chmod 644 /etc/gitea/app.ini

echo \"[INFO] rebooting ...\"
reboot"


##################################################################
# VARIABLES
##################################################################



echo "[INFO] setting language variables to solve perls language problem ..."
echo "export LANGUAGE=en_US.UTF-8 
export LANG=en_US.UTF-8 
export LC_ALL=en_US.UTF-8">>~/.profile

# source variables
. ~/.profile


echo "[INFO] updating system ..."
apt update
apt upgrade -y
apt autoremove -y


echo "[INFO] installing tool to listen on file changes ..."
apt install -y inotify-tools


echo "[INFO] installing tool to access sqlite3 database ..."
apt install -y sqlite3


echo "[INFO] getting gitea ..."
wget -O gitea https://dl.gitea.io/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64
chmod +x gitea


echo "[INFO] verifing gitea ..."
gpg --keyserver pgp.mit.edu --recv 0x2D9AE806EC1592E2
wget -O gitea-${GITEA_VERSION}-linux-amd64.asc https://dl.gitea.io/gitea/${GITEA_VERSION}/gitea-${GITEA_VERSION}-linux-amd64.asc
gpg --verify gitea-${GITEA_VERSION}-linux-amd64.asc gitea


echo "[INFO] creating gitea user ..."
adduser \
   --system \
   --shell /bin/bash \
   --gecos 'Git Version Control' \
   --group \
   --disabled-password \
   --home /home/${GITEA_USER_NAME} \
   ${GITEA_USER_NAME}


echo "[INFO] creating gitea backup user ..."
adduser \
   --system \
   --shell /bin/bash \
   --gecos 'Git Backup Account' \
   --group \
   --disabled-password \
   --home /home/${GITEA_BACKUP_NAME} \
   ${GITEA_BACKUP_NAME}


echo "[INFO] creating directories and setting permissions ..."
mkdir -p /var/lib/gitea/custom
mkdir -p /var/lib/gitea/data
mkdir -p /var/lib/gitea/indexers
mkdir -p /var/lib/gitea/public
mkdir -p /var/lib/gitea/log

chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /var/lib/gitea/data
chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /var/lib/gitea/indexers
chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /var/lib/gitea/log

chmod 750 /var/lib/gitea/data
chmod 750 /var/lib/gitea/indexers
chmod 750 /var/lib/gitea/log

mkdir -p /etc/gitea

chown root:${GITEA_USER_NAME} /etc/gitea
chmod 770 /etc/gitea

chmod 700 /home/${GITEA_BACKUP_NAME}
chmod 700 /home/${GITEA_USER_NAME}


echo "[INFO] copying gitea binary to global location ..."
cp gitea /usr/local/bin/gitea


echo "[INFO] creating gitea service ..."
mkdir -p /etc/systemd/system
echo "${GITEA_SERVICE_FILE_CONTENT}">/etc/systemd/system/gitea.service


echo "[INFO] creating ssh command edit service ..."
echo "${EDIT_SSH_COMMAND_SERVICE_FILE_CONTENT}">/etc/systemd/system/ssh-command.service
echo "${EDIT_SSH_COMMAND_SCRIPT_CONTENT}">/home/${GITEA_USER_NAME}/edit-ssh-command.sh

chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /home/${GITEA_USER_NAME}/edit-ssh-command.sh
chmod 700 /home/${GITEA_USER_NAME}/edit-ssh-command.sh


echo "[INFO] creating backup job ..."
echo "${BACKUP_SCRIPT_CONTENT}">/root/create-backup.sh
chmod 700 /root/create-backup.sh

(crontab -l 2>/dev/null; echo "${GITEA_BACKUP_EVENT}	/bin/bash /root/create-backup.sh") | crontab -


echo "[INFO] creating backup restore script ..."
echo "${RESTORE_SCRIPT_CONTENT}">/root/restore-backup.sh
chmod 700 /root/restore-backup.sh


echo "[INFO] creating self signed certificate ..."
gitea cert --host ${GITEA_DOMAIN}

chown root:${GITEA_USER_NAME} key.pem
chown root:${GITEA_USER_NAME} cert.pem

chmod 640 key.pem
chmod 644 cert.pem


echo "[INFO] moving certificate and key to final detination ..."
mv key.pem /etc/gitea/
mv cert.pem /etc/gitea/


echo "[INFO] creating initial app.ini file ..."
echo "${INITIAL_APP_INI_CONTENT}">/etc/gitea/app.ini

chown root:${GITEA_USER_NAME} /etc/gitea/app.ini
chmod 770 /etc/gitea/app.ini


echo "[INFO] creating file for ssh public keys ..."
mkdir -p /home/${GITEA_USER_NAME}/.ssh
echo "">/home/${GITEA_USER_NAME}/.ssh/authorized_keys

chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /home/${GITEA_USER_NAME}/.ssh
chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /home/${GITEA_USER_NAME}/.ssh/authorized_keys

chmod 700 /home/${GITEA_USER_NAME}/.ssh
chmod 600 /home/${GITEA_USER_NAME}/.ssh/authorized_keys


echo "[INFO] enabling and starting gitea service ..."
systemctl enable gitea.service
systemctl start gitea.service


echo "[INFO] enabling and starting ssh command service ..."
systemctl enable ssh-command.service
systemctl start ssh-command.service


echo "[INFO] cleaning up ..."
rm gitea
rm gitea-${GITEA_VERSION}-linux-amd64.asc


echo "[INFO] rebooting ..."
echo "[INFO] IMPORTANT"
echo "[INFO] after initial configuration, change permssions of /etc/gitea and /etc/gitea/app.ini to"
echo "[INFO] chmod 750 /etc/gitea"
echo "[INFO] chmod 644 /etc/gitea/app.ini"
reboot