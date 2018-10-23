#!/bin/bash

###################################################################################################
# CONFIGURATION
###################################################################################################

SERVER_DOMAIN="dummy.domain"


###################################################################################################
# DEFINES
###################################################################################################

INSTALL_GITEA_SCRIPT_NAME="install-gitea.sh"
INSTALL_GITEA_SCRIPT_PATH=$(dirname `which $0`)


###################################################################################################
# MAIN
###################################################################################################

scp ${INSTALL_GITEA_SCRIPT_PATH}/${INSTALL_GITEA_SCRIPT_NAME} root@${SERVER_DOMAIN}: | tee -a log.txt
ssh -t root@${SERVER_DOMAIN} "chmod 700 ${INSTALL_GITEA_SCRIPT_NAME} && ./${INSTALL_GITEA_SCRIPT_NAME}" | tee -a log.txt