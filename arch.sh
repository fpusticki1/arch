#!/bin/bash

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
echo "***************************************************"
read -p "*** Enter your full name: " myname
read -p "*** Enter username: " myuser
read -p "*** Enter password: " mypassword
read -p "*** Enter hostname: " myhostname
read -p "*** AMD or Intel CPU? (amd/intel): " mycpu
read -p "*** Intel or Nvidia GPU? (intel/nvidia): " mygpu
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

sleep 10

#DISK PARTITIONING
echo
echo "*****************  Listing Disk drives  *****************"
echo "*********************************************************"
fdisk -l
echo "*********************************************************"
echo && sleep 1
read -p "This operation will erase the disk!!!
*** Enter your disk name (example: /dev/sda ): " mydisk
echo
read -p "Selected disk is: *** ${mydisk} ***
*** Are you sure you want to erase it and install Arch Linux? (YES/n): " confirm
if [ "${confirm}" = "YES" ]; then
  for n in ${mydisk}* ; do umount $n ; done
  sleep 10
  for n in ${mydisk}* ; do swapoff $n ; done
  sleep 10
  wipefs -a "${mydisk}" "${mydisk}1" "${mydisk}2" "${mydisk}3"
  sleep 10
  (echo g; echo n; echo; echo; echo +512M; echo t; echo 1; echo w) | fdisk ${mydisk}
  sleep 10
  (echo n; echo; echo; echo +4G; echo t; echo; echo 19; echo w) | fdisk ${mydisk}
  sleep 10
  (echo n; echo; echo; echo; echo w) | fdisk ${mydisk}
  sleep 10
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

sleep 10

#MOUNTING FILESYSTEMS
mount ${rootpart} /mnt
swapon ${swappart}
mkdir /mnt/boot
mount ${bootpart} /mnt/boot

sleep 10

#SHOW CREATED PARTITIONS
echo
echo "*****************  Listing Disk drives  *****************"
echo "*********************************************************"
fdisk -l
echo "*********************************************************"
lsblk
echo "*********************************************************"
echo && sleep 1
read -p "Please check your new partitions and mount points.
*** Press Enter to continue..."


###-----------------------------------------------------------------------------
### PART 2: BASE SYSTEM INSTALLATION -------------------------------------------
###-----------------------------------------------------------------------------

#BASE SYSTEM INSTALL
pacstrap /mnt base base-devel linux linux-firmware \
dosfstools f2fs-tools man-db man-pages nano git zsh \
networkmanager networkmanager-openvpn openresolv ${mycpu}-ucode

sleep 10

arch-chroot /mnt /bin/bash << EOF
systemctl enable NetworkManager
EOF

#USER ACCOUNTS
arch-chroot /mnt /bin/bash << EOF
useradd -m -G wheel -s /usr/bin/zsh ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd root
usermod -c "${myname}" ${myuser}
sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /etc/sudoers
EOF

sleep 10

#INSTALL YAY
arch-chroot /mnt /bin/bash << EOF
cd /opt
git clone https://aur.archlinux.org/yay.git
chown -R ${myuser}:${myuser} yay
cd yay
sudo -u ${myuser} makepkg -si --noconfirm
EOF

sleep 10

###-----------------------------------------------------------------------------
### PART 3: SYSTEM CONFIGURATION -----------------------------------------------
###-----------------------------------------------------------------------------

#PACMAN CONFIGURATION
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 8/g' /mnt/etc/pacman.conf
sed -i 's/#Color/Color/g' /mnt/etc/pacman.conf
sed -i 's/#VerbosePkgLists/VerbosePkgLists/g' /mnt/etc/pacman.conf
cat << 'EOF' > /mnt/etc/pacman.d/mirrorlist
Server = http://mirror.luzea.de/archlinux/$repo/os/$arch
Server = http://arch.jensgutermuth.de/$repo/os/$arch
Server = http://mirror.wtnet.de/arch/$repo/os/$arch
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
Server = http://archlinux.iskon.hr/$repo/os/$arch
EOF
sleep 10
# --------------------------------
cat << EOF > /mnt/usr/local/cleancache.sh 
#!/bin/bash
rm -rf /var/cache/pacman/pkg/{,.[!.],..?}*
rm -rf /home/${myuser}/.cache/yay/{,.[!.],..?}*
exit 0
EOF
sleep 10
# --------------------------------
cat << EOF > /mnt/usr/share/libalpm/hooks/cleancache.hook
[Trigger]
Operation = Remove
Operation = Install
Operation = Upgrade
Type = Package
Target = *
[Action]
Description = Cleaning cache...
When = PostTransaction
Exec = /usr/local/cleancache.sh
EOF
sleep 10
# --------------------------------
cat << 'EOF' > /mnt/usr/local/checkupdates.sh
#!/bin/bash
if [[ $(pacman -Qu) || $(yay -Qu) ]]; then
  notify-send '*** UPDATES ***' 'New updates available...' --icon=dialog-information
fi
exit 0
EOF
sleep 10
#---------------------------------
arch-chroot /mnt /bin/bash << EOF
sudo -u ${myuser} yay --save --answerdiff None
sudo -u ${myuser} mkdir -p /home/${myuser}/.config/systemd/user
chmod +x /usr/local/cleancache.sh
chmod +x /usr/local/checkupdates.sh
EOF
sleep 10
#---------------------------------
cat << EOF > /mnt/home/${myuser}/.config/systemd/user/checkupdates.service
[Unit]
Description=Check Updates service
[Service]
Type=oneshot
ExecStart=/usr/local/checkupdates.sh
[Install]
RequiredBy=default.target
EOF
sleep 10
#----------------------------------
cat << EOF > /mnt/home/${myuser}/.config/systemd/user/checkupdates.timer
[Unit]
Description=Run checkupdates every boot
[Timer]
OnBootSec=15sec
[Install]
WantedBy=timers.target
EOF
sleep 10
#----------------------------------

#FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

#TIME ZONE
arch-chroot /mnt /bin/bash << EOF
ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime
hwclock --systohc
systemctl enable systemd-timesyncd
EOF

sleep 10

# LOCALE AND KEYMAP
cat << EOF > /mnt/etc/locale.gen
en_US.UTF-8 UTF-8
hr_HR.UTF-8 UTF-8
EOF

sleep 10

cat << EOF > /mnt/etc/locale.conf
LANG=en_US.UTF-8
LC_ADDRESS=hr_HR.UTF-8
LC_IDENTIFICATION=hr_HR.UTF-8
LC_MEASUREMENT=hr_HR.UTF-8
LC_MONETARY=hr_HR.UTF-8
LC_NAME=hr_HR.UTF-8
LC_NUMERIC=hr_HR.UTF-8
LC_PAPER=hr_HR.UTF-8
LC_TELEPHONE=hr_HR.UTF-8
LC_TIME=hr_HR.UTF-8
EOF

sleep 10

arch-chroot /mnt /bin/bash << EOF
locale-gen
localectl set-keymap --no-convert croat
EOF

sleep 10

#NETWORK
cat << EOF > /mnt/etc/hostname
${myhostname}
EOF
cat << EOF >> /mnt/etc/hosts
127.0.0.1  localhost
::1        localhost
127.0.1.1  ${myhostname}
EOF

sleep 10

#INITRAMFS
sed -i 's/^HOOKS=(base udev.*/HOOKS=(base systemd autodetect modconf block filesystems keyboard fsck)/g' /mnt/etc/mkinitcpio.conf
sed -i 's/#COMPRESSION=\"lz4\"/COMPRESSION=\"lz4\"/g' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt /bin/bash << EOF
mkinitcpio -P
EOF

sleep 10

#BOOTLOADER
arch-chroot /mnt /bin/bash << EOF
bootctl install
systemctl enable systemd-boot-update
EOF

sleep 10

cat << EOF > /mnt/boot/loader/loader.conf
timeout 0
default arch
EOF
cat << EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /${mycpu}-ucode.img
initrd /initramfs-linux.img
options root=${rootpart} rw quiet splash
EOF

sleep 10

#CLEAN ORPHAN PACKAGES
arch-chroot /mnt /bin/bash << 'EOF'
if [[ $(pacman -Qqdt) ]]; then
  pacman -Rsc --noconfirm $(pacman -Qqdt)
fi
EOF

sleep 10

arch-chroot /mnt /bin/bash << EOF
if [[ \$(sudo -u ${myuser} yay -Qqdt) ]]; then
  sudo -u ${myuser} yay -Rsc --noconfirm \$(sudo -u ${myuser} yay -Qqdt)
fi
EOF

sleep 10


###-----------------------------------------------------------------------------
### PART 4: DESKTOP ENVIRONMENT INSTALLATION -----------------------------------
###-----------------------------------------------------------------------------

#XORG
arch-chroot /mnt /bin/bash << EOF
pacman -S --noconfirm xorg-server xorg-apps
sleep 10
localectl set-x11-keymap --no-convert hr
EOF

sleep 10



#DISPLAY DRIVER
if [ "${mygpu}" = "intel" ]; then
  arch-chroot /mnt /bin/bash <<- EOF
  pacman -S --noconfirm xf86-video-intel mesa
  EOF
  sleep 10
elif [ "${mygpu}" = "nvidia" ]; then
  arch-chroot /mnt /bin/bash <<- EOF
  pacman -S --noconfirm nvidia nvidia-utils
  EOF
  sleep 10
else
  sleep 1
fi

#DESKTOP ENVIRONMENT - GNOME
arch-chroot /mnt /bin/bash << EOF
pacman -S --noconfirm gdm gnome-shell gnome-control-center \
gnome-tweaks gnome-shell-extensions gnome-system-monitor \
gnome-terminal gnome-calculator gnome-screenshot gnome-backgrounds \
nautilus file-roller seahorse simple-scan xdg-user-dirs \
gvfs-mtp sushi eog
sleep 10
systemctl enable gdm
EOF
sleep 10
exit 0

###-----------------------------------------------------------------------------
### PART 5: APPS INSTALLATION --------------------------------------------------
###-----------------------------------------------------------------------------

#PACMAN PACKAGES

#AUR PACKAGES


###-----------------------------------------------------------------------------
### PART 6: POST INSTALL TWEAKS ------------------------------------------------
###-----------------------------------------------------------------------------



cat << EOF > FILE
EOF

arch-chroot /mnt /bin/bash << EOF
EOF
