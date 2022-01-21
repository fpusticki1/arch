#!/bin/bash

# Arch Linux Installer by: Franjo Pusticki
# ------------------------------------------------------------------------------
echo
echo "####################################################"
echo "##### Welcome to the Arch installation script. #####"
echo "####################################################"
echo && sleep 1


###-----------------------------------------------------------------------------
### PART 1: BASIC CONFIGURATION ------------------------------------------------
###-----------------------------------------------------------------------------

#SET KEYMAP
loadkeys croat

#USER INPUTS
echo
echo "***************************************************"
read -p "*** Connect to wifi? (y/n): " wifi

#SET WIFI
if [ "${wifi}" = "y" ]; then
  iwctl device list
  read -p "*** Enter your device name: " mydevice
  iwctl station ${mydevice} scan && sleep 3
  iwctl station ${mydevice} get-networks && sleep 3
  read -p "*** Enter your wifi name: " mynetwork
  read -p "*** Enter your wifi password: " mywifipassword
  echo "Connecting to wifi network..." && sleep 2
  iwctl --passphrase ${mywifipassword} station ${mydevice} connect ${mynetwork}
  sleep 3 
else
  sleep 1
fi

#SET TIME
timedatectl set-timezone Europe/Zagreb
timedatectl set-ntp true

#DISK PARTITIONING
echo
echo "*****************  Listing Disk drives  *****************"
echo "*********************************************************" && sleep 1
fdisk -l
echo "*********************************************************" && sleep 1
echo
read -p "This operation will erase the disk!!!
*** Enter your disk name (example: /dev/sda ): " mydisk
echo
read -p "Selected disk is: *** ${mydisk} ***
*** Are you sure you want to erase it and install Arch Linux? (YES/n): " confirm
if [ "${confirm}" = "YES" ]; then
  for n in ${mydisk}* ; do umount $n ; done
  for n in ${mydisk}* ; do swapoff $n ; done
  wipefs -a "${mydisk}" "${mydisk}1" "${mydisk}2" "${mydisk}3"
  (echo g; echo n; echo; echo; echo +512M; echo t; echo 1; echo w) | fdisk ${mydisk} #boot partition
  (echo n; echo; echo; echo +4G; echo t; echo; echo 19; echo w) | fdisk ${mydisk} #swap partition
  (echo n; echo; echo; echo; echo w) | fdisk ${mydisk} #root partition
  read -p "*** Disk erased and partitions created. Press Enter to continue..." continue
  bootpart="${mydisk}1"
  swappart="${mydisk}2"
  rootpart="${mydisk}3"
else
  echo "***** Exiting installation script... *****"
  sleep 5
  exit 0
fi

#PARTITION FORMATTING
mkfs.ext4 ${rootpart}
mkswap ${swappart}
mkfs.fat -F 32 ${bootpart}

#MOUNTING FILESYSTEMS
mount ${rootpart} /mnt
swapon ${swappart}
mkdir /mnt/boot
mount ${bootpart} /mnt/boot

#SHOW CREATED PARTITIONS
echo
echo "*****************  Listing Disk drives  *****************"
echo "*********************************************************" && sleep 1
fdisk -l
echo "*********************************************************" && sleep 1
echo
read -p "Please check your new partitions.
*** Press Enter to continue..." continue

lsblk
echo
echo
read -p "Please check your new partitions.
*** Press Enter to continue..." continue

exit 0
