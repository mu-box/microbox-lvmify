#!/usr/bin/env bash

if vgdisplay data > /dev/null 2>&1; then
  echo "LVM already configured with a 'data' volume group"
  exit
fi

# in order to generate the iPXE menu and grub conf, we need to set some
# global variables to be used throughout this script
set_menu_vars() {
  # when iPXE boots, it will need to have a minimal network configuration,
  # so we need to extract the external interface/ip from the host to set
  # in the iPXE menu configuration.
  read -r menu_gateway nic <<<$(netstat -nr | awk '/^0.0.0.0|^default/ {print $2" "$8}')
  interface=${nic:${#nic} - 1}
  menu_ip=$(ifconfig $nic | awk '/inet addr/ {print $2}' | cut -f2 -d':')
  menu_netmask=$(ifconfig $nic | awk '/inet addr/ {print $4}' | cut -f2 -d':')
  
  # fetch the uuid to inform grub of the root partition
  uuid=$(blkid -s UUID -o value $(df /boot | tail -n1 | awk '{print $1}'))
  
  # determine the boot path for grub
  boot_path=$(if mountpoint /boot > /dev/null; then echo ""; else echo "/boot"; fi)
}

# generate an iPXE boot script
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

# download iPXE and configure it for the next boot
setup_ipxe() {
  curl -k -s -o /boot/ipxe.krn -O http://s3.amazonaws.com/smartos.pagodagrid.io/live/boot/ipxe.krn
  echo "$(script_ipxe)" > /boot/script.ipxe
}

# generate a grub menu entry for ipxe
09_ipxe() {
  cat <<EOF
#!/bin/sh
exec tail -n +3 \$0

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

# create the ipxe menu entry for grub
create_ipxe_grub_menu() {
  # create a backup, just in case ;)
  if [[ ! -f /boot/grub/grub.bak ]]; then
    cp /boot/grub/grub.cfg /boot/grub/grub.bak
  fi
  
  # add the ipxe menu entry
  echo "$(09_ipxe)" > /etc/grub.d/09_ipxe
  chmod 755 /etc/grub.d/09_ipxe
  
  # generate the final grub config
  grub-mkconfig > /boot/grub/grub.cfg
  
  # remove the temporary ipxe menu entry
  rm /etc/grub.d/09_ipxe
}

echo "Setting boot menu vars..."
set_menu_vars

echo "Configuring iPXE..."
setup_ipxe

echo "Configuring menu..."
create_ipxe_grub_menu

echo "Rebooting..."
reboot
