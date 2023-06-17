#!/bin/sh
. /etc/init.d/tc-functions

echo "${YELLOW}Running lvmify init script...${NORMAL}"

# This log is started before the persistence partition is mounted
/opt/bootscript.sh 2>&1 | tee -a /var/log/lvmify.log

echo "${YELLOW}Finished lvmify init script...${NORMAL}"
