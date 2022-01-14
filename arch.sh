#!/bin/zsh

# Arch Linux Installer by: Franjo Pusticki
# ------------------------------------------------------------------------------
echo
echo "####################################################"
echo "##### Welcome to the Arch installation script. #####"
echo "####################################################"
echo && sleep 3

###-----------------------------------------------------------------------------
### PART 1: BASIC CONFIGURATION ------------------------------------------------
###-----------------------------------------------------------------------------

#SET KEYMAP
echo "Setting keymap..." && sleep 1
loadkeys croat

#USER INPUTS
echo
echo "***************************************************"
read -p "*** Connect to wifi? (y/n): " wifi

#SET WIFI
if [ "${wifi}" = "y" ]; then
  iwctl device list
  read -p "*** Enter your device name: " mydevice
  iwctl station ${mydevice} scan
  iwctl station ${mydevice} get-networks
  read -p "*** Enter your wifi name: " mynetwork
  read -p "*** Enter your wifi password: " mywifipassword
  echo "Connecting to wifi network..." && sleep 2
  iwctl --passphrase ${mywifipassword} station ${mydevice} connect ${mynetwork}
  sleep 3 
else
  sleep 1
fi

#SET TIME
echo "Setting timezone..." && sleep 1
timedatectl set-timezone Europe/Zagreb
timedatectl set-ntp true

#DISK PARTITIONING
echo
echo "*****************  Listing Disk drives  *****************" && sleep 1
echo "*********************************************************" && sleep 1
lsblk
echo
echo "*********************************************************" && sleep 1
fdisk -l
echo "*********************************************************" && sleep 1
echo
read -p "This operation will erase the disk!!!
*** Enter your disk name (example: /dev/sda): " mydisk
read -p "Selected disk is: *** ${mydisk} ***
*** Are you sure you want to erase it and install Arch Linux? (YES/n): " confirm
if [ "${confirm}" = "YES" ]; then
  (echo g; echo n; echo; echo; echo +512M; echo t; echo 1; echo w) | fdisk ${mydisk} #boot partition
  (echo n; echo; echo; echo +4G; echo t; echo; echo 19; echo w) | fdisk ${mydisk} #swap partition
  (echo n; echo; echo; echo; echo w) | fdisk ${mydisk} #root partition
  bootpart = "${mydisk}1"
  swappart = "${mydisk}2"
  rootpart = "${mydisk}3"
else
	echo "***** Exiting installation script... *****"
	sleep 5
	exit 0
fi

#PARTITION FORMATTING
echo "Formatting partitions..." && sleep 2
read -p "Press any key to continue..." continue
mkfs.ext4 ${rootpart}
read -p "Press any key to continue..." continue
mkswap ${swappart}
read -p "Press any key to continue..." continue
mkfs.fat -F 32 ${bootpart}
read -p "Press any key to continue..." continue

#MOUNTING FILESYSTEMS
echo "Mounting filesystems..." && sleep 2
mount ${rootpart} /mnt
read -p "Press any key to continue..." continue
swapon ${swappart}
read -p "Press any key to continue..." continue
mkdir /mnt/boot
read -p "Press any key to continue..." continue
mount ${bootpart} /mnt/boot
read -p "Press any key to continue..." continue

#SHOW CREATED PARTITIONS
echo
echo "*****************  Listing Disk drives  *****************" && sleep 1
echo "*********************************************************" && sleep 1
lsblk
echo
echo "*********************************************************" && sleep 1
fdisk -l
echo "*********************************************************" && sleep 1
echo
read -p "Please check your new partitions.
*** Press any key to continue..." continue
