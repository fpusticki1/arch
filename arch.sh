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
read -p "*** Is your name Franjo Pustički? (y/n): " ifname
if [ "${ifname}" = "y" ]; then
  myname="Franjo Pustički"
else
  read -p "*** Enter your full name: " myname
fi
read -p "*** Enter username: " myuser
read -p "*** Enter password: " mypassword
read -p "*** Enter hostname: " myhostname
read -p "*** Intel or AMD CPU? (intel/amd): " mycpu
read -p "*** Intel, AMD or Nvidia GPU? (intel/amd/nvidia): " mygpu

#SET TIME
timedatectl set-timezone Europe/Zagreb
timedatectl set-ntp true

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
  for n in ${mydisk}* ; do swapoff $n ; done
  wipefs -a "${mydisk}" "${mydisk}1" "${mydisk}2" "${mydisk}3"
  (echo g; echo n; echo; echo; echo +512M; echo t; echo 1; echo w) | fdisk ${mydisk}
  (echo n; echo; echo; echo +4G; echo t; echo; echo 19; echo w) | fdisk ${mydisk}
  (echo n; echo; echo; echo; echo w) | fdisk ${mydisk}
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
echo "*********************************************************"
fdisk -l
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

#USER ACCOUNTS
arch-chroot /mnt /bin/bash << CHROOT
useradd -m -G wheel -s /usr/bin/zsh ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd root
usermod -c "${myname}" ${myuser}
sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /etc/sudoers
CHROOT

#INSTALL YAY
arch-chroot /mnt /bin/bash << CHROOT
cd /opt
git clone https://aur.archlinux.org/yay.git
chown -R ${myuser}:${myuser} yay
cd yay
sudo -u ${myuser} makepkg -si --noconfirm
CHROOT


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
# --------------------------------
cat << 'EOF' > /mnt/usr/local/checkupdates.sh
#!/bin/bash
# Clean cache
rm -rf /var/cache/pacman/pkg/{,.[!.],..?}*
rm -rf /home/${myuser}/.cache/yay/{,.[!.],..?}*
# Check updates
if [[ $(pacman -Qu) || $(yay -Qu) ]]; then
  notify-send '*** UPDATES ***' 'New updates available...'
fi
exit 0
EOF
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
#----------------------------------
cat << EOF > /mnt/home/${myuser}/.config/systemd/user/checkupdates.timer
[Unit]
Description=Run checkupdates every boot
[Timer]
OnBootSec=15sec
[Install]
WantedBy=timers.target
EOF
#---------------------------------
arch-chroot /mnt /bin/bash << CHROOT
sudo -u ${myuser} yay --save --answerdiff None --removemake
sudo -u ${myuser} mkdir -p /home/${myuser}/.config/systemd/user
chmod +x /usr/local/checkupdates.sh
CHROOT
#----------------------------------

#FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

#TIME ZONE
arch-chroot /mnt /bin/bash << CHROOT
ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime
hwclock --systohc
CHROOT

#LOCALE AND KEYMAP
cat << EOF > /mnt/etc/locale.gen
en_US.UTF-8 UTF-8
hr_HR.UTF-8 UTF-8
EOF
arch-chroot /mnt /bin/bash << CHROOT
locale-gen
CHROOT
cat << EOF > /mnt/etc/locale.conf
LANG=en_US.UTF-8
EOF
cat << EOF > /mnt/etc/vconsole.conf
KEYMAP=croat
EOF

#NETWORK
cat << EOF > /mnt/etc/hostname
${myhostname}
EOF
cat << EOF >> /mnt/etc/hosts
127.0.0.1  localhost
::1        localhost
127.0.1.1  ${myhostname}
EOF

#INITRAMFS
# ??? sed -i 's/^HOOKS=(base udev.*/HOOKS=(base systemd autodetect modconf block filesystems keyboard fsck)/g' /mnt/etc/mkinitcpio.conf
sed -i 's/#COMPRESSION=\"lz4\"/COMPRESSION=\"lz4\"/g' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt /bin/bash << CHROOT
mkinitcpio -P
CHROOT

#BOOTLOADER
arch-chroot /mnt /bin/bash << CHROOT
bootctl install
CHROOT
cat << EOF > /mnt/boot/loader/loader.conf
timeout 0
default arch
EOF
cat << EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /${mycpu}-ucode.img
initrd /initramfs-linux.img
options root=${rootpart} rw quiet
EOF

###-----------------------------------------------------------------------------
### PART 4: DESKTOP ENVIRONMENT INSTALLATION -----------------------------------
###-----------------------------------------------------------------------------

#XORG
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --noconfirm xorg-server xorg-apps
CHROOT

#DISPLAY DRIVER
if [ "${mygpu}" = "intel" ]; then
  arch-chroot /mnt /bin/bash <<- CHROOT
  pacman -S --noconfirm xf86-video-intel mesa
CHROOT
elif [ "${mygpu}" = "nvidia" ]; then
  arch-chroot /mnt /bin/bash <<- CHROOT
  pacman -S --noconfirm nvidia nvidia-utils
CHROOT
elif [ "${mygpu}" = "amd" ]; then
  arch-chroot /mnt /bin/bash <<- CHROOT
  pacman -S --noconfirm xf86-video-amdgpu mesa
CHROOT
else
  sleep 1
fi

#DESKTOP ENVIRONMENT - GNOME
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --noconfirm gdm gnome-shell gnome-control-center \
gnome-tweaks gnome-shell-extensions gnome-system-monitor \
gnome-terminal gnome-calculator gnome-screenshot gnome-backgrounds \
nautilus file-roller seahorse simple-scan xdg-user-dirs \
gvfs-mtp sushi eog
CHROOT

echo "FINIESHED..."
exit 0
