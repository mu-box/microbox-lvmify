#!/usr/bin/env bash
# this is a shell script that will be sourced, and should setup the boot process for a centos platform

get_menu_vars() {
  read -r menu_gateway nic <<<$(netstat -nr | awk '/^0.0.0.0|^default/ {print $2" "$8}')
  interface=${nic:${#nic} - 1}
  menu_ip=$(ifconfig $nic | awk '/inet addr/ {print $2}' | cut -f2 -d':')
  menu_netmask=$(ifconfig $nic | awk '/inet addr/ {print $4}' | cut -f2 -d':')
  uuid=$(blkid -s UUID -o value $(df /boot | tail -n1 | awk '{print $1}'))
  boot_path=$(if mountpoint /boot > /dev/null; then echo ""; else echo "/boot"; fi)
}

script_ipxe() {
  cat <<EOF
#!ipxe

set net${interface}/ip ${menu_ip} 
set net${interface}/netmask ${menu_netmask} 
set net${interface}/gateway ${menu_gateway} 
set dns 8.8.8.8 
ifopen net${interface} 
kernel http://s3.amazonaws.com/tools.nanobox.io/bootstrap/memdisk 
initrd http://s3.amazonaws.com/tools.nanobox.io/lvmify/v1/lvmify.iso 
imgargs memdisk iso raw 
boot
EOF
}

# Create ipxe dataset
setup_ipxe() {
  curl -k -s -o /boot/ipxe.krn -O http://s3.amazonaws.com/smartos.pagodagrid.io/live/boot/ipxe.krn
  echo "$(script_ipxe)" > /boot/script.ipxe
}

09_ipxe() {
  cat <<EOF
#!/bin/sh
exec tail -n +3 \$0
# This file provides an easy way to add custom menu entries.  Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.
menuentry 'ipxe' {
        recordfail
        load_video
        gfxmode \$linux_gfx_mode
        insmod gzio
        if [ x\$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
        insmod part_gpt
        insmod ext2
        if [ x\$feature_platform_search_hint = xy ]; then
          search --no-floppy --fs-uuid --set=root  $uuid
        else
          search --no-floppy --fs-uuid --set=root $uuid
        fi
        linux16 $boot_path/ipxe.krn 
        initrd16 $boot_path/script.ipxe
}
EOF
}

create_menu() {
  if [[ ! -f /boot/grub/grub.bak ]]; then
    cp /boot/grub/grub.cfg /boot/grub/grub.bak
  fi
  echo "$(09_ipxe)" > /etc/grub.d/09_ipxe
  chmod 755 /etc/grub.d/09_ipxe
  grub-mkconfig > /boot/grub/grub.cfg
  rm /etc/grub.d/09_ipxe
}

echo "Getting OS vars..."
get_menu_vars

echo "Configuring iPXE..."
setup_ipxe

echo "Configuring menu..."
create_menu

reboot