FROM debian:jessie

RUN apt-get update && \
      apt-get -y install \
        unzip \
        xz-utils \
        curl \
        bc \
        git \
        build-essential \
        cpio \
        gcc libc6 libc6-dev \
        kmod \
        squashfs-tools \
        genisoimage \
        xorriso \
        syslinux \
        isolinux \
        automake \
        pkg-config \
        p7zip-full

# https://www.kernel.org/
ENV KERNEL_VERSION  4.4.88

# Fetch the kernel sources
RUN curl \
      --retry 10 \
      https://www.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-$KERNEL_VERSION.tar.xz \
        | tar -C / -xJ && \
          mv /linux-$KERNEL_VERSION /linux-kernel

COPY kernel_config /linux-kernel/.config

RUN jobs=$(nproc); \
    cd /linux-kernel && \
    make -j ${jobs} oldconfig && \
    make -j ${jobs} bzImage && \
    make -j ${jobs} modules

# The post kernel build process

ENV ROOTFS /rootfs

# Make the ROOTFS
RUN mkdir -p $ROOTFS

# Prepare the build directory (/tmp/iso)
RUN mkdir -p /tmp/iso/boot

# Install the kernel modules in $ROOTFS
RUN cd /linux-kernel && \
    make INSTALL_MOD_PATH=$ROOTFS modules_install firmware_install

# Remove useless kernel modules, based on unclejack/debian2docker
RUN cd $ROOTFS/lib/modules && \
    rm -rf ./*/kernel/sound/* && \
    rm -rf ./*/kernel/drivers/gpu/* && \
    rm -rf ./*/kernel/drivers/infiniband/* && \
    rm -rf ./*/kernel/drivers/isdn/* && \
    rm -rf ./*/kernel/drivers/media/* && \
    rm -rf ./*/kernel/drivers/staging/lustre/* && \
    rm -rf ./*/kernel/drivers/staging/comedi/* && \
    rm -rf ./*/kernel/fs/ocfs2/* && \
    rm -rf ./*/kernel/net/bluetooth/* && \
    rm -rf ./*/kernel/net/mac80211/* && \
    rm -rf ./*/kernel/net/wireless/*

# Prepare the ISO directory with the kernel
RUN cp -v /linux-kernel/arch/x86_64/boot/bzImage /tmp/iso/boot/vmlinuz64

ENV TCL_REPO_BASE       http://distro.ibiblio.org/tinycorelinux/7.x/x86_64
ENV TCL_REPO_FALLBACK   http://tinycorelinux.net/7.x/x86_64

ENV TCZ_DEPS  e2fsprogs \
              parted \
              liblvm2 \
              udev-lib \
              lvm2

# Download the rootfs, don't unpack it though:
RUN set -ex; \
	curl -fL -o /tcl_rootfs.gz "$TCL_REPO_BASE/release/distribution_files/rootfs64.gz" \
		|| curl -fL -o /tcl_rootfs.gz "$TCL_REPO_FALLBACK/release/distribution_files/rootfs64.gz"

# Install the TCZ dependencies
RUN set -ex; \
	for dep in $TCZ_DEPS; do \
		echo "Download $TCL_REPO_BASE/tcz/$dep.tcz"; \
		curl -fL -o "/tmp/$dep.tcz" "$TCL_REPO_BASE/tcz/$dep.tcz" \
			|| curl -fL -o "/tmp/$dep.tcz" "$TCL_REPO_FALLBACK/tcz/$dep.tcz"; \
		unsquashfs -f -d "$ROOTFS" "/tmp/$dep.tcz"; \
		rm -f "/tmp/$dep.tcz"; \
	done

# Install Tiny Core Linux rootfs
RUN cd "$ROOTFS" && zcat /tcl_rootfs.gz | cpio -f -i -H newc -d --no-absolute-filenames

# Apply horrible hacks
RUN ln -sT lib "$ROOTFS/lib64"

# Set the version
COPY VERSION $ROOTFS/etc/version
RUN cp -v "$ROOTFS/etc/version" /tmp/iso/version

# Copy our custom rootfs
COPY files/rootfs $ROOTFS

# Make sure init scripts are executable
RUN find "$ROOTFS/etc/rc.d/" -type f -exec chmod --changes +x '{}' +

# Add serial console (do we need this?)
RUN set -ex; \
	for s in 0 1 2 3; do \
		echo "ttyS${s}:2345:respawn:/usr/local/bin/forgiving-getty ttyS${s}" >> "$ROOTFS/etc/inittab"; \
	done; \
	cat "$ROOTFS/etc/inittab"

# Copy boot params
COPY files/isolinux /tmp/iso/boot/isolinux

COPY files/make_iso.sh /tmp/make_iso.sh

RUN /tmp/make_iso.sh

CMD ["sh", "-c", "[ -t 1 ] && exec bash || exec cat lvmify.iso"]
