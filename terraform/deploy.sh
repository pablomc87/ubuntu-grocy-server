#!/bin/bash
# Wrapper script to set environment variables and run deploy-template.sh

export SERVER_IP="192.168.1.126"
export SERVER_USER="pablomartincalvo"
export SSH_KEY="~/.ssh/id_rsa"
export CLOUD_INIT_DIR="/boot/firmware"
export USER_DATA_FILE="./../user-data-generated"
export USER_PASSWORD="Dial4-Armed-Hurled"

exec "./deploy-template.sh"
