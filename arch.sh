#!/bin/bash
set -e

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

### USER INPUTS
echo "***************************************************"
read -p "*** Is this a laptop? (y/n): " iflaptop
read -p "*** Enter hostname: " myhostname
read -p "*** Enter username: " myuser
read -p "*** Enter password: " mypassword
myname="Franjo Pustički"
if [ "${iflaptop}" = "y" ]; then
  mycpu="intel"
else
  mycpu="amd"
fi


###-----------------------------------------------------------------------------
### PART 2: BASE SYSTEM INSTALLATION -------------------------------------------
###-----------------------------------------------------------------------------

### MIRROR LIST
cat << 'EOF' > /etc/pacman.d/mirrorlist
Server = http://archlinux.iskon.hr/$repo/os/$arch
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
Server = http://mirror.sunred.org/archlinux/$repo/os/$arch
Server = http://arch.jensgutermuth.de/$repo/os/$arch
Server = http://ftp.myrveln.se/pub/linux/archlinux/$repo/os/$arch
EOF

### BASE SYSTEM INSTALL
pacstrap -K /mnt base base-devel linux linux-firmware ${mycpu}-ucode zsh git

### FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

### TIME, LOCALE, KEYMAP, NETWORK
arch-chroot /mnt /bin/bash << CHROOT
ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "hr_HR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=croat" > /etc/vconsole.conf
echo "${myhostname}" > /etc/hostname
echo "127.0.0.1  localhost" >> /etc/hosts
echo "::1        localhost" >> /etc/hosts
echo "127.0.1.1  ${myhostname}" >> /etc/hosts
CHROOT

### USER ACCOUNTS
arch-chroot /mnt /bin/bash << CHROOT
useradd -m -G users ${myuser}
usermod -c "${myname}" ${myuser}
echo "${myuser} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
(echo ${mypassword}; echo ${mypassword}) | passwd ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd root
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
### PART 3: PACKAGE INSTALLATION -----------------------------------------------
###-----------------------------------------------------------------------------

### INSTALL PARU
arch-chroot /mnt /bin/bash << CHROOT
cd /home/${myuser}
sudo -u ${myuser} git clone https://aur.archlinux.org/paru.git
cd paru
sudo -u ${myuser} makepkg -si --noconfirm
rm -rf /home/${myuser}/paru
CHROOT

### PACMAN/PARU CONFIGURATION
sed -i 's/#Color/Color/g' /mnt/etc/pacman.conf
sed -i 's/#VerbosePkgLists/VerbosePkgLists/g' /mnt/etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /mnt/etc/pacman.conf
sed -i 's/#HookDir/HookDir/g' /mnt/etc/pacman.conf
sed -i 's/#RemoveMake/RemoveMake/g' /mnt/etc/paru.conf
sed -i '/^\[options\]/a BatchInstall' /mnt/etc/paru.conf
sed -i '/^\[options\]/a SkipReview' /mnt/etc/paru.conf

### INSTALL PACKAGES
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm nano htop neofetch wget zip unzip unrar \
zsh-completions zsh-syntax-highlighting zsh-history-substring-search zsh-autosuggestions \
dosfstools mtools nilfs-utils f2fs-tools sqlite man-db man-pages source-highlight \
networkmanager networkmanager-openvpn openresolv net-tools seahorse jdk8-openjdk \
pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack alsa-utils easyeffects \
xorg-server xorg-apps system-config-printer cups hplip simple-scan gnome-screenshot gnome-backgrounds \
xdg-user-dirs gvfs-mtp nautilus file-roller sushi eog mlocate gnome-terminal gnome-calculator \
gnome-shell gnome-control-center gdm gnome-tweaks gnome-shell-extensions gnome-system-monitor \
ttf-dejavu ttf-liberation noto-fonts noto-fonts-emoji ttf-ubuntu-font-family \
firefox libreoffice-still plank vlc audacity sox mysql-workbench remmina freerdp
archlinux-java fix
CHROOT

### AUR PACKAGES
arch-chroot /mnt /bin/bash << CHROOT
sudo -u ${myuser} paru -S --noconfirm google-chrome sublime-text-4 skypeforlinux-stable-bin \
postman-bin termius-deb zsh-theme-powerlevel10k-git 7-zip gnome-browser-connector \
yaru-icon-theme yaru-gtk-theme 
CHROOT

### LAPTOP OR DESKTOP
if [ "${iflaptop}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm mesa vulkan-intel intel-media-driver tlp sof-firmware thunderbird 
  systemctl enable tlp
CHROOT
else
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm nvidia nvidia-utils qbittorrent openrazer-daemon
  gpasswd -a ${myuser} plugdev
  sudo -u ${myuser} paru -S --noconfirm plex-media-server polychromatic
  systemctl enable plexmediaserver
CHROOT
fi


###-----------------------------------------------------------------------------
### PART 4: SYSTEM CONFIGURATION -----------------------------------------------
###-----------------------------------------------------------------------------

### AUTOLOGIN
sed -i '/^\[daemon\]/a AutomaticLoginEnable=True' /mnt/etc/gdm/custom.conf
sed -i "/^\[daemon\]/a AutomaticLogin=${myuser}" /mnt/etc/gdm/custom.conf
sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' /mnt/etc/gdm/custom.conf
sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=5s/g' /mnt/etc/systemd/system.conf

### ENABLE SERVICES
arch-chroot /mnt /bin/bash << CHROOT
systemctl enable gdm
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
systemctl enable systemd-boot-update
systemctl enable cups.socket
systemctl enable fstrim.timer
CHROOT

### DISABLE SERVICES
arch-chroot /mnt /bin/bash << CHROOT
systemctl disable lvm2-monitor
systemctl mask lvm2-monitor
systemctl disable ldconfig
systemctl mask ldconfig
systemctl disable bolt
systemctl mask bolt
systemctl disable iio-sensor-proxy
systemctl mask iio-sensor-proxy
CHROOT

### BLACKLIST MODULES
cat << EOF > /mnt/etc/modprobe.d/blacklist.conf
blacklist sp5100_tco
blacklist iTCO_wdt
blacklist iTCO_vendor_support
blacklist aesni_intel
blacklist pcspkr
blacklist joydev
blacklist mousedev
blacklist mac_hid
EOF

### INITRAMFS (NVIDIA KMS)
if [ "${iflaptop}" = "y" ]; then
  sed -i 's/MODULES=()/MODULES=(i915)/g' /mnt/etc/mkinitcpio.conf
  sed -i 's/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont/HOOKS=(base systemd autodetect modconf kms keyboard keymap/g' /mnt/etc/mkinitcpio.conf
  arch-chroot /mnt /bin/bash << CHROOT
  mkinitcpio -P
CHROOT
else
  sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /mnt/etc/mkinitcpio.conf
  sed -i 's/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont/HOOKS=(base systemd autodetect modconf keyboard keymap/g' /mnt/etc/mkinitcpio.conf
  sed -i 's/rd.udev.log_level=3/rd.udev.log_level=3 nvidia-drm.modeset=1)/g' /mnt/boot/loader/entries/arch.conf
  arch-chroot /mnt /bin/bash << CHROOT
  mkinitcpio -P
CHROOT
  mkdir /mnt/etc/pacman.d/hooks
  cat << 'EOF' > /mnt/etc/pacman.d/hooks/nvidia.hook
  [Trigger]
  Operation=Install
  Operation=Upgrade
  Operation=Remove
  Type=Package
  Target=nvidia
  
  [Action]
  Description=Update Nvidia module in initcpio
  Depends=mkinitcpio
  When=PostTransaction
  Exec=/usr/bin/mkinitcpio -P
EOF
fi


###-----------------------------------------------------------------------------
### PART 5: POST INSTALL TWEAKS ------------------------------------------------
###-----------------------------------------------------------------------------

### NANO COLORS
sed -i 's/# include \"\/usr\/share\/nano\/\*.nanorc\"/include \"\/usr\/share\/nano\/\*.nanorc\"/g' /mnt/etc/nanorc
cat << EOF >> /mnt/etc/nanorc
set titlecolor bold,white,blue
set promptcolor lightwhite,grey
set statuscolor bold,white,green
set errorcolor bold,white,red
set spotlightcolor black,lightyellow
set selectedcolor lightwhite,magenta
set stripecolor ,yellow
set scrollercolor cyan
set numbercolor cyan
set keycolor cyan
set functioncolor green
EOF

### FONTS
cat << EOF > /mnt/etc/fonts/local.conf
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit mode="assign" name="antialias">
      <bool>true</bool>
    </edit>
    <edit mode="assign" name="embeddedbitmap">
      <bool>false</bool>
    </edit>
    <edit mode="assign" name="hinting">
      <bool>true</bool>
    </edit>
    <edit mode="assign" name="hintstyle">
      <const>hintslight</const>
    </edit>
    <edit mode="assign" name="lcdfilter">
      <const>lcddefault</const>
    </edit>
    <edit mode="assign" name="rgba">
      <const>rgb</const>
    </edit>
  </match>
  <match target="pattern">
    <test name="family" compare="eq">
      <string>Ubuntu</string>
    </test>
    <edit name="family" mode="prepend">
      <string>Cantarell</string>
    </edit>
  </match>
  <alias>
      <family>sans-serif</family>
      <prefer>
          <family>Ubuntu</family>
      </prefer>
  </alias>
  <alias>
      <family>serif</family>
      <prefer>
          <family>Ubuntu</family>
      </prefer>
  </alias>
  <alias>
      <family>monospace</family>
      <prefer>
          <family>Ubuntu Mono</family>
      </prefer>
  </alias>
</fontconfig>
EOF

### FINISH INSTALLATION
arch-chroot /mnt /bin/bash << CHROOT
pacman -Qtdq | pacman -Rns -
CHROOT
echo "***********************************
***** Installation completed! *****
***********************************"
read -p "System will reboot now
*** Press Enter to continue..."
sleep 1
umount -R /mnt
sleep 3
reboot
