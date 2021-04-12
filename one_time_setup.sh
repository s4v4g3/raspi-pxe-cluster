#!/bin/bash
#
# One-time setup to enable services for Raspberry PI PXE cluster
#
# Installs dnsmasq and nfs-kernel-server packages
# Downloads arm64 and armhf flavors of raspberry pi raspios "lite" image
# and extracts them to /nfs/raspxe/arm64 and /nfs/raspxe/armhf directories
# so they can be used as prototypes for devices, set up with the "setup_raspi.sh" script
#

# Mask for the DHCP listener -- set this to your server's subnet mask
readonly DHCP_MASK=10.4.1.255


readonly IMAGE_URL_ARM64=https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2021-04-09/2021-03-04-raspios-buster-arm64-lite.zip
readonly IMAGE_URL_ARMHF=https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-03-25/2021-03-04-raspios-buster-armhf-lite.zip
readonly SEVENZIP=${PWD}/7z/7zz
readonly NFS_ROOT=/nfs/raspxe
readonly TFTP_ROOT=/tftpboot


install_requirements() {

    sudo apt-get install unzip kpartx dnsmasq nfs-kernel-server wget xz-utils

    # create directories
    if [ ! -d ${NFS_ROOT} ]; then
        sudo mkdir -p ${NFS_ROOT}
    fi
    if [ ! -d ${TFTP_ROOT} ]; then
        sudo mkdir -p ${TFTP_ROOT}
    fi

    # download 7zip to 7z directory
    if [ -f "${SEVENZIP}" ]; then
        echo "${SEVENZIP} exists, skipping download"
    else
        wget -O /tmp/7z.tar.xz https://7-zip.org/a/7z2101-linux-x64.tar.xz
        mkdir 7z
        tar xvf /tmp/7z.tar.xz --directory 7z
        rm -rf /tmp/7z.tar.xz
    fi

}

#
# Sets up dnsmasq configuration to enable the DHCP proxy and enable
# the tftp server
#
setup_dnsmasq() {
    # make a backup of the original file, or start from the backup
    # if we've created one already
    if [ ! -f /etc/dnsmasq.conf.orig ]; then
        sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
    else
        sudo cp /etc/dnsmasq.conf.orig /etc/dnsmasq.conf
    fi

    echo "dhcp-range=${DHCP_MASK},proxy" | sudo tee -a /etc/dnsmasq.conf
    echo 'log-dhcp' | sudo tee -a /etc/dnsmasq.conf
    echo 'enable-tftp' | sudo tee -a /etc/dnsmasq.conf
    echo "tftp-root=${TFTP_ROOT}" | sudo tee -a /etc/dnsmasq.conf
    echo 'pxe-service=0,"Raspberry Pi Boot"' | sudo tee -a /etc/dnsmasq.conf
    # disable the dns service due to conflicts with systemd-resolved
    echo 'port=0' | sudo tee -a /etc/dnsmasq.conf
    # enable and restart the services
    sudo systemctl enable dnsmasq
    sudo systemctl restart dnsmasq
}

#
# Sets up the NFS exports file and enables the rpcbind and nfs services
#
setup_nfs() {
    # export the ${NFS_ROOT} directory
    echo "${NFS_ROOT} *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
    # enable and restart the services
    sudo systemctl enable rpcbind
    sudo systemctl enable nfs-kernel-server
    sudo systemctl restart rpcbind
    sudo systemctl restart nfs-kernel-server
}

#
# Downloads the raspios image from the specifed url (param $2)
# and extracts it to the ${NFS_ROOT}/$1 directory
#
extract_root_fs() {

    if [ ! -d $1 ]; then
        mkdir $1
    fi
    pushd $1
    if [ -f "raspios.img" ]; then
        echo "raspios.img already exists"
    else
        echo "Downloading raspios.zip from $2"
        wget -O raspios.zip $2
        echo "Unzipping image"
        unzip raspios.zip 
        mv *.img raspios.img 
        rm -rf raspios.zip
    fi
    # use 7zip to extract partitions from raspios.img
    # this will create 0.fat and 1.img files for
    # boot partition and rootfs, respectively
    ${SEVENZIP} x -aoa raspios.img
    ${SEVENZIP} x -aoa -oboot ./0.fat
    mkdir -p ${PWD}/root
    # mount 1.img to a temporary dir
    sudo mount -o ro,noload 1.img ${PWD}/root
    sudo rm -rf ${NFS_ROOT}/$1
    sudo mkdir -p ${NFS_ROOT}/$1
    # copy files, along with their attributes (important)
    # to the destination folder
    sudo cp -a ${PWD}/root/* ${NFS_ROOT}/$1/
    sudo cp -a ${PWD}/boot/* ${NFS_ROOT}/$1/boot/
    # unmount and clean up
    sudo umount ${PWD}/root
    rm -rf boot
    rm -rf root
    rm -rf 0.fat
    rm -rf 1.img
    popd
}

# install packages and set up services
install_requirements
setup_dnsmasq
setup_nfs
# download and extract filesystems for arm64 and armhf flavors
extract_root_fs arm64 ${IMAGE_URL_ARM64}
extract_root_fs armhf ${IMAGE_URL_ARMHF}




