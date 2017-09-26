#!/bin/sh

# Load TCE extensions
/etc/rc.d/tce-loader

mkdir -p /var/lib/lvmify/log

/etc/rc.d/resize
