#!/bin/bash


##################################################################
# CONFIGURATION
##################################################################

GITEA_USER_NAME="git"

GITEA_VERSION="1.5.0"
GITEA_PORT="443"
GITEA_DOMAIN="gitea.some.one"
#GITEA_DOMAIN=$(hostname -I | head -n1 | cut -d " " -f1)

GITEA_BACKUP_NAME="gitbackup"
GITEA_BACKUP_EVENT="0 3	* * *" # every day at 03:00 (see https://wiki.ubuntuusers.de/Cron/ for syntax)

SERVER_UPDATE_EVENT="0 4	* * *" # every day at 04:00 (see https://wiki.ubuntuusers.de/Cron/ for syntax)

ENABLE_LETSENCRYPT=true
LETSENCRYPT_EMAIL="dummy@dummy.com"
LETSENCRYPT_RENEW_EVENT="30 2	1 */2 *" # At 02:30 on day-of-month 1 in every 2nd month.
                                         # (Every 60 days. That's the default time range from certbot)

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
WantedBy=multi-user.target
"


EDIT_SSH_COMMAND_SCRIPT_CONTENT="
#!/bin/bash
# This file is part of a workaround to enable repository cloning via ssh.
# An extra command to announce the work directory of gitea is needed inside the 
# command string of public shh keys (see <gitea user>/.ssh/authorized_keys).
# To achieve this, a service will be started that activates this script.
# This script then listens on file changes and adds the requiered GITEA_WORK_DIR=/var/lib/gitea command
# whenever the authorized_keys file changes.
while inotifywait /home/${GITEA_USER_NAME}/.ssh/authorized_keys; do sed -Ei 's/command=\"\/usr\/local\/bin\/gitea/command=\"GITEA_WORK_DIR=\/var\/lib\/gitea \/usr\/local\/bin\/gitea/g' /home/${GITEA_USER_NAME}/.ssh/authorized_keys; done
"

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
WantedBy=multi-user.target
"


INITIAL_APP_INI_CONTENT="
[server]
PROTOCOL=https
ROOT_URL = https://${GITEA_DOMAIN}:${GITEA_PORT}/
HTTP_PORT = ${GITEA_PORT}
CERT_FILE = /etc/gitea/cert.pem
KEY_FILE = /etc/gitea/key.pem
REDIRECT_OTHER_PORT = true
PORT_TO_REDIRECT = 80
"

BACKUP_SCRIPT_CONTENT="
#!/bin/bash

su -c \"cd ~
       rm -f backup-*
       sqlite3 /var/lib/gitea/data/gitea.db .dump >gitea.sql
       cp /etc/gitea/app.ini /home/${GITEA_USER_NAME}
       tar -pcvzf backup-\$(date +'%s').tar.gz gitea-repositories/ gitea.sql app.ini
       rm gitea.sql
       rm app.ini\" \"${GITEA_USER_NAME}\"

rm -f /home/${GITEA_BACKUP_NAME}/persist/backup-*
mv /home/${GITEA_USER_NAME}/backup-* /home/${GITEA_BACKUP_NAME}/persist/
chown ${GITEA_BACKUP_NAME} /home/${GITEA_BACKUP_NAME}/persist/backup-*
"


RESTORE_SCRIPT_CONTENT="
#!/bin/bash

echo \"[INFO] restoring backup ...\"
mv /home/${GITEA_BACKUP_NAME}/restore/backup-*.tar.gz /home/${GITEA_USER_NAME}
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
reboot
"


ADD_BACKUP_SSHKEY_SCRIPT_CONTENT="
#!/bin/bash

PUB_SSH_KEY=\$1


if ! [ \${PUB_SSH_KEY:0:7} = \"ssh-rsa\" ]; then
  echo \"[ERROR] input parameter seems not to be an ssh-rsa public key\"
elif ! [ \$# = 1 ]; then
  echo \"[ERROR] two many arguments. Surround rsa key with double quotes: \\\"<PUBLIC KEY>\\\"\"
else
  echo \"command=\\\"if [[ \\\\\\\"\\\$SSH_ORIGINAL_COMMAND\\\\\\\" =~ ^scp[[:space:]]-t[[:space:]]restore/.? ]] || [[ \\\\\\\"\\\$SSH_ORIGINAL_COMMAND\\\\\\\" =~ ^scp[[:space:]]-f[[:space:]]persist/.? ]]; then \\\$SSH_ORIGINAL_COMMAND ; else echo Access Denied; fi\\\",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding \${PUB_SSH_KEY}\">>/home/${GITEA_BACKUP_NAME}/.ssh/authorized_keys
fi
"


UPDATE_AN_UPGRADE_SCRIPT_CONTENT="
#!/bin/bash

echo \"[INFO] \$(date) ...\" > update-and-upgrade.log

echo \"[INFO] updating ...\" >> update-and-upgrade.log
apt update --assume-yes >> update-and-upgrade.log
echo \"\" >> update-and-upgrade.log

echo \"[INFO] upgrading ...\" >> update-and-upgrade.log
apt upgrade --assume-yes >> update-and-upgrade.log
echo \"\" >> update-and-upgrade.log

echo \"[INFO] autoremoving ...\" >> update-and-upgrade.log
apt autoremove --assume-yes >> update-and-upgrade.log
"


RENEW_CERTIFICATE_SCRIPT_CONTENT="
#!/bin/bash

echo \"[INFO] \$(date) ...\" > renew-certificate.log

echo \"[INFO] stopping gitea service ...\" >> renew-certificate.log
systemctl stop gitea.service
echo \"\" >> renew-certificate.log

echo \"[INFO] renewing certificate ...\" >> renew-certificate.log
certbot renew
echo \"\" >> renew-certificate.log

echo \"[INFO] restarting gitea service ...\" >> renew-certificate.log
systemctl start gitea.service
"

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


if [ ${ENABLE_LETSENCRYPT} == true ]; then
  
  echo "[INFO] installing Let's Encrypt certbot ..."
  apt-get install -y software-properties-common
  add-apt-repository -y ppa:certbot/certbot
  apt-get update -y
  apt-get install -y certbot

fi


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
mkdir -p /etc/gitea

chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /var/lib/gitea/data
chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /var/lib/gitea/indexers
chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /var/lib/gitea/log
chown root:${GITEA_USER_NAME} /etc/gitea

chmod 750 /var/lib/gitea/data
chmod 750 /var/lib/gitea/indexers
chmod 750 /var/lib/gitea/log
chmod 770 /etc/gitea
chmod 700 /home/${GITEA_USER_NAME}

mkdir -p /home/${GITEA_BACKUP_NAME}/persist
mkdir -p /home/${GITEA_BACKUP_NAME}/restore

chown ${GITEA_BACKUP_NAME}:${GITEA_BACKUP_NAME} /home/${GITEA_BACKUP_NAME}/persist
chown ${GITEA_BACKUP_NAME}:${GITEA_BACKUP_NAME} /home/${GITEA_BACKUP_NAME}/restore

chmod 500 /home/${GITEA_BACKUP_NAME}/persist
chmod 300 /home/${GITEA_BACKUP_NAME}/restore
chmod 700 /home/${GITEA_BACKUP_NAME}


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


echo "[INFO] creating backup ssh key script ..."
echo "${ADD_BACKUP_SSHKEY_SCRIPT_CONTENT}">/root/add-backup-ssh-key.sh
chmod 700 /root/add-backup-ssh-key.sh


echo "[INFO] creating backup restore script ..."
echo "${RESTORE_SCRIPT_CONTENT}">/root/restore-backup.sh
chmod 700 /root/restore-backup.sh


echo "[INFO] creating update and upgrade job ..."
echo "${UPDATE_AN_UPGRADE_SCRIPT_CONTENT}">/root/update-and-upgrade.sh
chmod 700 /root/update-and-upgrade.sh
(crontab -l 2>>/dev/null; echo "${SERVER_UPDATE_EVENT}	/bin/bash /root/update-and-upgrade.sh") | crontab -


if [ ${ENABLE_LETSENCRYPT} == true ]; then

  echo "[INFO] requesting Let's Encrypt certificate ..."
  certbot certonly -n --standalone --agree-tos --email ${LETSENCRYPT_EMAIL} -d ${GITEA_DOMAIN}

  
  echo "[INFO] creating links to certificate and key and setting permissions ..."
  ln -s /etc/letsencrypt/live/${GITEA_DOMAIN}/fullchain.pem /etc/gitea/cert.pem
  ln -s /etc/letsencrypt/live/${GITEA_DOMAIN}/privkey.pem /etc/gitea/key.pem

  chown root:git /etc/letsencrypt/live
  chmod 750 /etc/letsencrypt/live

  chown root:git /etc/letsencrypt/archive
  chmod 750 /etc/letsencrypt/archive


  echo "[INFO] creating renew certificate job"
  echo "${RENEW_CERTIFICATE_SCRIPT_CONTENT}">/root/renew-certificate.sh
  chmod 700 /root/renew-certificate.sh
  (crontab -l 2>>/dev/null; echo "${LETSENCRYPT_RENEW_EVENT}	/bin/bash /root/renew-certificate.sh") | crontab -

else

  echo "[INFO] creating self signed certificate ..."
  gitea cert --host ${GITEA_DOMAIN}

  chown root:${GITEA_USER_NAME} key.pem
  chown root:${GITEA_USER_NAME} cert.pem

  chmod 640 key.pem
  chmod 644 cert.pem


  echo "[INFO] moving certificate and key to final detination ..."
  mv key.pem /etc/gitea/
  mv cert.pem /etc/gitea/

fi


echo "[INFO] creating initial app.ini file ..."
echo "${INITIAL_APP_INI_CONTENT}">/etc/gitea/app.ini

chown root:${GITEA_USER_NAME} /etc/gitea/app.ini
chmod 770 /etc/gitea/app.ini


echo "[INFO] creating files for ssh public keys for ${GITEA_USER_NAME} ..."
mkdir -p /home/${GITEA_USER_NAME}/.ssh
echo "">/home/${GITEA_USER_NAME}/.ssh/authorized_keys

chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /home/${GITEA_USER_NAME}/.ssh
chown ${GITEA_USER_NAME}:${GITEA_USER_NAME} /home/${GITEA_USER_NAME}/.ssh/authorized_keys

chmod 700 /home/${GITEA_USER_NAME}/.ssh
chmod 600 /home/${GITEA_USER_NAME}/.ssh/authorized_keys


echo "[INFO] creating files for ssh public keys for ${GITEA_BACKUP_NAME} ..."
mkdir -p /home/${GITEA_BACKUP_NAME}/.ssh
echo "">/home/${GITEA_BACKUP_NAME}/.ssh/authorized_keys

chown ${GITEA_BACKUP_NAME}:${GITEA_BACKUP_NAME} /home/${GITEA_BACKUP_NAME}/.ssh
chown ${GITEA_BACKUP_NAME}:${GITEA_BACKUP_NAME} /home/${GITEA_BACKUP_NAME}/.ssh/authorized_keys

chmod 700 /home/${GITEA_BACKUP_NAME}/.ssh
chmod 400 /home/${GITEA_BACKUP_NAME}/.ssh/authorized_keys


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