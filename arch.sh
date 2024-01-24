#!/bin/bash

echo "####################################################"
echo "##### Welcome to the Arch installation script. #####"
echo "####################################################"

###-----------------------------------------------------------------------------
### PART 1: BASIC CONFIGURATION ------------------------------------------------
###-----------------------------------------------------------------------------

### SET KEYMAP
loadkeys croat

### SET TIME
timedatectl set-timezone Europe/Zagreb
timedatectl set-ntp true

### DISK PARTITIONING
echo
echo "*****************  Listing Disk drives  *****************"
echo "*********************************************************"
fdisk -l
echo "*********************************************************"
echo
echo "This operation will erase the disk!!!"
echo
read -p "*** Enter your disk name (example: /dev/nvme0n1 ): " mydisk
echo
read -p "Selected disk is: *** ${mydisk} ***
*** Are you sure you want to erase it and install Arch Linux? (yes/n): " confirm
if [ "${confirm}" = "yes" ]; then
  wipefs -af "${mydisk}" "${mydisk}p1" "${mydisk}p2" "${mydisk}p3"
  sleep 1
  (echo n; echo; echo; echo +512M; echo ef00; echo n; echo; echo; echo; echo 8300; echo w; echo y) | gdisk ${mydisk}
  sleep 1
  bootpart="${mydisk}p1"
  rootpart="${mydisk}p2"
else
  exit 0
fi

### PARTITION FORMATTING
mkfs.fat -F32 ${bootpart}
mkfs.ext4 ${rootpart}

### MOUNTING FILESYSTEMS
mount ${rootpart} /mnt
mount --mkdir ${bootpart} /mnt/boot

### SHOW CREATED PARTITIONS
echo
echo "*****************  Listing Disk drives  *****************"
echo "*********************************************************"
fdisk -l
echo "*********************************************************"
echo && sleep 1
read -p "Please check your new partitions and mount points.
*** Press Enter to continue..."
