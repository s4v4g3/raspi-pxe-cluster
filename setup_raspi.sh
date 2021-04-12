#!/bin/bash
#
# Sets up NFS shares for a specific raspberry pi serial number.
#
# Usage:  setup_raspi.sh <raspi_sn> <server_ip> <source_dir>
#      raspi_sn:   the last 8 digits of the raspberry pi serial number
#                  as output from /proc/cpuinfo
#
#      server_ip:  the ip address of the NFS/TFTP server (the pc running this script)
#
#      source_dir: the name of subdirectory inside NFS_ROOT to be used as the source
#                  of the root filesystem for the new device.
#
#
# Example:  setup_raspi.sh c302b31c 10.4.1.6 arm64
#
#           copies root filesystem from /nfs/raspxe/arm64 to /nfs/raspxe/c302b31c,
#           instructs raspberry pi to boot from nfs share at 10.4.1.6://nfs/raspxe/c302b31c
#           & creates a bind mount of /tftpboot/c302b31c to /nfs/raspxe/c302b31c


if [[ -z "$1" || -z "$2" || -z "$3" ]]
  then
    echo "usage:  setup_raspi.sh <raspi_sn> <server_ip> <source_dir>"
    exit 1
fi

echo "raspi serial:  $1"
echo "server ip:     $2"
echo "source dir:    $3"

# root NFS and TFTP shares -- need to be the same as in one_time_setup.sh
readonly NFS_ROOT=/nfs/raspxe
readonly TFTP_ROOT=/tftpboot
# source and destination dirs
readonly NFS_SRC=$NFS_ROOT/$3
readonly NFS_DEST=$NFS_ROOT/$1

if [ ! -d $NFS_SRC ]; then
    echo "$NFS_SRC does not exist -- invalid source dir"
    exit 1
fi



if [ -d $NFS_DEST ]; then
    sudo rm -rf $NFS_DEST
fi
sudo mkdir $NFS_DEST
sudo cp -a $NFS_SRC/* $NFS_DEST/
# enable ssh and regenerate host keys on next reboot
sudo touch $NFS_DEST/boot/ssh
if [ ! -h $NFS_DEST/etc/systemd/system/multi-user.target.wants/regenerate_ssh_host_keys.service ]; then
    sudo ln -s /lib/systemd/system/regenerate_ssh_host_keys.service $NFS_DEST/etc/systemd/system/multi-user.target.wants/regenerate_ssh_host_keys.service
fi
# change hostname to raspxe-<serial>
sudo sed -i /127\.0\.1\.1/d $NFS_DEST/etc/hosts
echo "raspxe-$1" | sudo tee $NFS_DEST/etc/hostname
echo "127.0.1.1        raspxe-$1" | sudo tee -a $NFS_DEST/etc/hosts
# get rid of HW device mounts
sudo sed -i /UUID/d $NFS_DEST/etc/fstab
# set boot cmdline.txt to boot from nfs server
echo "console=serial0,115200 console=tty root=/dev/nfs nfsroot=$2:${NFS_DEST},vers=3 rw ip=dhcp rootwait elevator=deadline" | sudo tee $NFS_DEST/boot/cmdline.txt


# bind mount ${TFTP_ROOT}/<raspi-sn> to /nfs/raspxe/<raspi-sn>
if [ ! -d ${TFTP_ROOT}/$1 ]; then
    sudo mkdir -p ${TFTP_ROOT}/$1
fi

# if fstab entry linking ${TFTP_ROOT}/$1 to $NFS_DEST/boot already
# exists, don't create another one
if grep -Fxq "$NFS_DEST/boot ${TFTP_ROOT}/$1 none defaults,bind 0 0" /etc/fstab
then
    sudo umount ${TFTP_ROOT}/$1 > /dev/null
else
    echo "$NFS_DEST/boot ${TFTP_ROOT}/$1 none defaults,bind 0 0" | sudo tee -a /etc/fstab
fi
sudo mount ${TFTP_ROOT}/$1



