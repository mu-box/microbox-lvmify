#!/bin/sh

# Load TCE extensions
/etc/rc.d/tce-loader

mkdir -p /var/lib/lvmify/log

# Launch ACPId
/etc/rc.d/acpid

