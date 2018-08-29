#!/bin/bash


##################################################################
# CONFIGURATION
##################################################################

GITEA_BACKUP_NAME="gitbackup"
GITEA_DOMAIN="gitea.some.one"

STORE_PATH="~/gitea-backup"
NUMBER_OF_STORED_BACKUPS=5

##################################################################
# CONFIGURATION
##################################################################


##################################################################
# VARIABLES
##################################################################

TMP_FILE="${STORE_PATH}/aaa-tmp.txt"

##################################################################
# VARIABLES
##################################################################



mkdir -p ${STORE_PATH}


# reduce backups to configured number of backups - 1
ls -1 ${STORE_PATH} > ${TMP_FILE}
NUMBER_OF_FILES=`wc -l <${TMP_FILE}`

while [ ${NUMBER_OF_FILES} -gt ${NUMBER_OF_STORED_BACKUPS} ]
do

  LAST_FILE_NAME=$(tail -n 1 ${TMP_FILE})
  rm "${STORE_PATH}/${LAST_FILE_NAME}"

  ls -1 ${STORE_PATH} > ${TMP_FILE}
  NUMBER_OF_FILES=`wc -l <${TMP_FILE}`

done

rm ${TMP_FILE}


# pull backup
scp ${GITEA_BACKUP_NAME}@${GITEA_DOMAIN}:persist/* ${STORE_PATH}