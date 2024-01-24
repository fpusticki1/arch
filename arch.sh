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
echo "This operation will erase the disk !!!"
echo
read -p "*** Enter your disk name (example: /dev/nvme0n1 ): " mydisk
echo
read -p "Selected disk is: *** ${mydisk} ***
*** Are you sure you want to erase it and install Arch Linux? (yes/n): " confirm
if [ "${confirm}" = "yes" ]; then
  umount "${mydisk}p1" "${mydisk}p2" "${mydisk}p3"
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

### MIRROR LIST
cat << 'EOF' > /etc/pacman.d/mirrorlist
Server = http://archlinux.iskon.hr/$repo/os/$arch
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
Server = http://mirror.sunred.org/archlinux/$repo/os/$arch
Server = http://arch.jensgutermuth.de/$repo/os/$arch
Server = http://ftp.myrveln.se/pub/linux/archlinux/$repo/os/$arch
EOF

### USER INPUTS
echo "***************************************************"
read -p "*** Is this a laptop? (y/n): " iflaptop
read -p "*** Select CPU? (intel/amd): " mycpu
read -p "*** Select GPU? (intel/nvidia): " mygpu
read -p "*** Enter hostname: " myhostname
read -p "*** Enter username: " myuser
read -p "*** Enter password: " mypassword
myname="Franjo Pustički"


###-----------------------------------------------------------------------------
### PART 2: BASE SYSTEM INSTALLATION -------------------------------------------
###-----------------------------------------------------------------------------

### BASE SYSTEM INSTALL
pacstrap -K /mnt base base-devel linux linux-firmware ${mycpu}-ucode zsh

### FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

### TIME ZONE
arch-chroot /mnt /bin/bash << CHROOT
ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime
hwclock --systohc
CHROOT

### LOCALE AND KEYMAP
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

### NETWORK
cat << EOF > /mnt/etc/hostname
${myhostname}
EOF
cat << EOF >> /mnt/etc/hosts
127.0.0.1  localhost
::1        localhost
127.0.1.1  ${myhostname}
EOF

### USER ACCOUNTS
arch-chroot /mnt /bin/bash << CHROOT
useradd -m -G users -s /usr/bin/zsh ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd root
usermod -c "${myname}" ${myuser}
echo "${myuser} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
CHROOT

### BOOTLOADER
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
options root=${rootpart} rw quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3
EOF


###-----------------------------------------------------------------------------
### PART 3: PACMAN INSTALLATION ------------------------------------------------
###-----------------------------------------------------------------------------

arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm nano zip unzip unrar htop neofetch wget git \
zsh-completions zsh-syntax-highlighting zsh-history-substring-search zsh-autosuggestions \
dosfstools mtools nilfs-utils f2fs-tools man-db man-pages \
networkmanager networkmanager-openvpn openresolv net-tools qbittorrent \
cups simple-scan jdk8-openjdk plank vlc audacity mysql-workbench remmina freerdp \
nautilus file-roller xdg-user-dirs seahorse sushi eog mlocate gnome-screenshot \
gnome-shell gnome-control-center gdm gnome-tweaks gnome-shell-extensions \
gnome-system-monitor gvfs-mtp gnome-terminal gnome-calculator gnome-backgrounds \
firefox libreoffice-still ttf-dejavu ttf-liberation ttf-hack noto-fonts-emoji \
pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack easyeffects \
xorg-server xorg-apps
archlinux-java fix
CHROOT

### DISPLAY DRIVER
if [ "${mygpu}" = "intel" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm mesa vulkan-intel
CHROOT
elif [ "${mygpu}" = "nvidia" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm nvidia nvidia-utils
CHROOT
else
  sleep 1
fi

### LAPTOP POWER SETTINGS
if [ "${iflaptop}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm tlp sof-firmware thunderbird
  systemctl enable tlp
CHROOT
fi
