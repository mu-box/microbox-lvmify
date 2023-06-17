#!/bin/sh
set -e

# Ensure init system invokes /opt/shutdown.sh on reboot or shutdown.
#  1) Find three lines with `useBusyBox`, blank, and `clear`
#  2) insert run op after those three lines
sed -i "1,/^useBusybox/ { /^useBusybox/ { N;N; /^useBusybox\n\nclear/ a\
\\\n\
# Run lvmify shutdown script\n\
test -x \"/opt/shutdown.sh\" && /opt/shutdown.sh\n
} }" $ROOTFS/etc/init.d/rc.shutdown
# Verify sed worked
grep -q "/opt/shutdown.sh" $ROOTFS/etc/init.d/rc.shutdown || ( echo "Error: failed to insert shutdown script into /etc/init.d/rc.shutdown"; exit 1 )

# Setup /etc/os-release with some nice contents
lvmifyVersion="$(cat $ROOTFS/etc/version)" # something like "1.1.0"
tclVersion="$(cat $ROOTFS/usr/share/doc/tc/release.txt)" # something like "5.3"
cat > $ROOTFS/etc/os-release <<-EOOS
NAME=lvmify
VERSION=$lvmifyVersion
ID=lvmify
ID_LIKE=tcl
VERSION_ID=$lvmifyVersion
PRETTY_NAME="lvmify $lvmifyVersion (TCL $tclVersion); $b2dDetail"
ANSI_COLOR="1;34"
HOME_URL="http://github.com/mu-box/microbox-lvmify"
SUPPORT_URL="https://github.com/mu-box/microbox-lvmify"
BUG_REPORT_URL="https://github.com/mu-box/microbox-lvmify/issues"
EOOS

# Pack the rootfs
cd $ROOTFS
find | ( set -x; cpio -o -H newc | xz -9 --format=lzma --verbose --verbose ) > /tmp/iso/boot/initrd.img
cd -

# Make the ISO
# Note: only "-isohybrid-mbr /..." is specific to xorriso.
# It builds an image that can be used as an ISO *and* a disk image.
xorriso  \
    -publisher "The Microbox Team" \
    -as mkisofs \
    -l -J -R -V "llvmify-v$(cat $ROOTFS/etc/version)" \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -o /lvmify.iso /tmp/iso
