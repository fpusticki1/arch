#!/bin/bash

set -e

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
read -p "*** Is this a laptop or pc? (laptop/PC): " iflaptop
read -p "*** Intel or AMD CPU? (intel/amd): " mycpu
read -p "*** Intel, AMD or Nvidia GPU? (intel/amd/nvidia): " mygpu
read -p "*** Install Windows fonts? (y/N): " winfonts
read -p "*** Install NTH apps? (y/N): " nth
read -p "*** Install Thunderbird? (y/N): " thund
read -p "*** Install Printer support? (y/N): " print
read -p "*** Install Torrent support? (y/N): " torr
read -p "*** Install Plex media server? (y/N): " plex
read -p "*** Install Pycharm? (y/N): " pycharm
read -p "*** Install Steam for games? (y/N): " games

#SET TIME
timedatectl set-timezone Europe/Zagreb
timedatectl set-ntp true

sleep 3

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
  sleep 3
  for n in ${mydisk}* ; do swapoff $n ; done
  sleep 3
  wipefs -a "${mydisk}" "${mydisk}1" "${mydisk}2" "${mydisk}3"
  sleep 3
  (echo g; echo n; echo; echo; echo +512M; echo t; echo 1; echo w) | fdisk ${mydisk}
  sleep 3
  (echo n; echo; echo; echo +4G; echo t; echo; echo 19; echo w) | fdisk ${mydisk}
  sleep 3
  (echo n; echo; echo; echo; echo w) | fdisk ${mydisk}
  sleep 3
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
sleep 3
mkswap ${swappart}
sleep 3
mkfs.fat -F 32 ${bootpart}
sleep 3

#MOUNTING FILESYSTEMS
mount ${rootpart} /mnt
sleep 3
swapon ${swappart}
sleep 3
mkdir /mnt/boot
sleep 3
mount ${bootpart} /mnt/boot
sleep 3

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

sleep 3
#USER ACCOUNTS
arch-chroot /mnt /bin/bash << CHROOT
useradd -m -s /usr/bin/zsh ${myuser}
sleep 3
(echo ${mypassword}; echo ${mypassword}) | passwd ${myuser}
sleep 3
(echo ${mypassword}; echo ${mypassword}) | passwd root
sleep 3
usermod -c "${myname}" ${myuser}
sleep 3
echo "${myuser} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
sleep 3
CHROOT

#INSTALL YAY
arch-chroot /mnt /bin/bash << CHROOT
cd /opt
sleep 3
git clone https://aur.archlinux.org/yay.git
sleep 3
chown -R ${myuser}:${myuser} yay
sleep 3
cd yay
sudo -u ${myuser} makepkg -si --noconfirm
sleep 3
CHROOT


###-----------------------------------------------------------------------------
### PART 3: SYSTEM CONFIGURATION -----------------------------------------------
###-----------------------------------------------------------------------------

#PACMAN CONFIGURATION
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 8/g' /mnt/etc/pacman.conf
sed -i 's/#Color/Color/g' /mnt/etc/pacman.conf
sed -i 's/#VerbosePkgLists/VerbosePkgLists/g' /mnt/etc/pacman.conf
sleep 3
cat << 'EOF' > /mnt/etc/pacman.d/mirrorlist
Server = http://mirror.luzea.de/archlinux/$repo/os/$arch
Server = http://arch.jensgutermuth.de/$repo/os/$arch
Server = http://mirror.wtnet.de/arch/$repo/os/$arch
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
Server = http://archlinux.iskon.hr/$repo/os/$arch
EOF
sleep 3
# --------------------------------
cat << EOF > /mnt/usr/local/checkupdates.sh
#!/bin/bash
# Clean cache...
rm -rf /var/cache/pacman/pkg/{,.[!.],..?}*
rm -rf /home/${myuser}/.cache/yay/{,.[!.],..?}*
# Check updates...
if [[ \$(pacman -Qu) || \$(yay -Qu) ]]; then
  notify-send '*** UPDATES ***' 'New updates available...'
fi
exit 0
EOF
sleep 3
#---------------------------------
arch-chroot /mnt /bin/bash << CHROOT
sudo -u ${myuser} yay --save --answerdiff None --removemake
sleep 3
sudo -u ${myuser} mkdir -p /home/${myuser}/.config/systemd/user
sleep 3
chmod +x /usr/local/checkupdates.sh
sleep 3
CHROOT
#----------------------------------
cat << EOF > /mnt/home/${myuser}/.config/systemd/user/checkupdates.service
[Unit]
Description=Check Updates service
[Service]
Type=oneshot
ExecStart=/usr/local/checkupdates.sh
[Install]
RequiredBy=default.target
EOF
sleep 3
#----------------------------------
cat << EOF > /mnt/home/${myuser}/.config/systemd/user/checkupdates.timer
[Unit]
Description=Run checkupdates every boot
[Timer]
OnBootSec=15sec
[Install]
WantedBy=timers.target
EOF
sleep 3
#---------------------------------

#FSTAB
genfstab -U /mnt >> /mnt/etc/fstab
sleep 3

#TIME ZONE
arch-chroot /mnt /bin/bash << CHROOT
ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime
hwclock --systohc
sleep 3
CHROOT

#LOCALE AND KEYMAP
cat << EOF > /mnt/etc/locale.gen
en_US.UTF-8 UTF-8
hr_HR.UTF-8 UTF-8
EOF
sleep 3
arch-chroot /mnt /bin/bash << CHROOT
locale-gen
sleep 3
CHROOT
cat << EOF > /mnt/etc/locale.conf
LANG=en_US.UTF-8
EOF
sleep 3
cat << EOF > /mnt/etc/vconsole.conf
KEYMAP=croat
EOF
sleep 3

#NETWORK
cat << EOF > /mnt/etc/hostname
${myhostname}
EOF
cat << EOF >> /mnt/etc/hosts
127.0.0.1  localhost
::1        localhost
127.0.1.1  ${myhostname}
EOF
sleep 3

#INITRAMFS
sed -i 's/#COMPRESSION=\"lz4\"/COMPRESSION=\"lz4\"/g' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt /bin/bash << CHROOT
mkinitcpio -P
CHROOT
sleep 3

#BOOTLOADER
arch-chroot /mnt /bin/bash << CHROOT
bootctl install
CHROOT
sleep 3
cat << EOF > /mnt/boot/loader/loader.conf
timeout 0
default arch
EOF
sleep 3
cat << EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /${mycpu}-ucode.img
initrd /initramfs-linux.img
options root=${rootpart} rw quiet nowatchdog fsck.mode=skip
EOF
sleep 3


###-----------------------------------------------------------------------------
### PART 4: DESKTOP ENVIRONMENT INSTALLATION -----------------------------------
###-----------------------------------------------------------------------------

#XORG
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm xorg-server xorg-apps
CHROOT
sleep 3

#DISPLAY DRIVER
if [ "${mygpu}" = "intel" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm xf86-video-intel mesa
CHROOT
elif [ "${mygpu}" = "nvidia" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm nvidia
CHROOT
elif [ "${mygpu}" = "amd" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm xf86-video-amdgpu mesa
CHROOT
else
  sleep 1
fi
sleep 3

#PIPEWIRE
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm wireplumber pipewire-jack pipewire-pulse
CHROOT
sleep 3

#DESKTOP ENVIRONMENT - GNOME
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm gnome-shell gnome-control-center gdm \
gnome-tweaks gnome-shell-extensions gnome-system-monitor gvfs-mtp \
gnome-terminal gnome-calculator gnome-screenshot gnome-backgrounds \
nautilus file-roller seahorse simple-scan xdg-user-dirs sushi eog
CHROOT
sleep 3

#ENABLE SERVICES
arch-chroot /mnt /bin/bash << CHROOT
systemctl enable NetworkManager
sleep 3
systemctl enable systemd-timesyncd
sleep 3
systemctl enable systemd-boot-update
sleep 3
systemctl enable gdm
sleep 3
CHROOT

#DISABLE SERVICES
arch-chroot /mnt /bin/bash << CHROOT
systemctl disable lvm2-monitor
sleep 3
systemctl mask lvm2-monitor
sleep 3
systemctl disable ldconfig
sleep 3
systemctl mask ldconfig
sleep 3
CHROOT

#LAPTOP POWER SETTINGS
if [ "${iflaptop}" = "laptop" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  sudo -u ${myuser} yay -S --needed --noconfirm auto-cpufreq
  systemctl enable auto-cpufreq
CHROOT
fi

sleep 3

#JAVA -----------------------
#export JAVA_TOOL_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true'
#echo "JAVA_FONTS=/usr/share/fonts/TTF" >> /etc/environment
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm jdk-openjdk
archlinux-java fix
sleep 3
CHROOT

#FONTS
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm ttf-dejavu ttf-liberation \
ttf-hack ttf-ubuntu-font-family
CHROOT
sleep 3
if [ "${winfonts}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  sudo -u ${myuser} yay -S --needed --noconfirm ttf-ms-win10-auto
CHROOT
fi
sleep 3
cat << EOF > /mnt/etc/fonts/local.conf
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hinting" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="rgba" mode="assign">
      <const>rgb</const>
    </edit>
    <edit name="hintstyle" mode="assign">
      <const>hintslight</const>
    </edit>
    <edit name="lcdfilter" mode="assign">
      <const>lcddefault</const>
    </edit>
    <edit name="embeddedbitmap" mode="assign">
      <bool>false</bool>
    </edit>
  </match>
</fontconfig>
EOF
sleep 3


###-----------------------------------------------------------------------------
### PART 5: APPS INSTALLATION --------------------------------------------------
###-----------------------------------------------------------------------------

#PACMAN PACKAGES
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm unrar p7zip htop neofetch wget \
mlocate net-tools plank vlc firefox libreoffice-still
CHROOT
sleep 3

#AUR PACKAGES
arch-chroot /mnt /bin/bash << CHROOT
sudo -u ${myuser} yay -S --needed --noconfirm sublime-text-4 \
google-chrome yaru-icon-theme
CHROOT
sleep 3


#--------------------- TODO --------------------
#NTH APPS
if [ "${nth}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm mysql-workbench remmina freerdp audacity
  sudo -u ${myuser} yay -S --needed --noconfirm skypeforlinux-stable-bin \
  zoom termius-app postman-bin


  #ZOIPER
  #Files/APPS/Zoiper_3.3_Linux_Free_64Bit.run
  #VPN
  #cp -R Files/OpenVPN/ /usr/local/
  #SECT STUDIO
  #cp -R Files/Sect_Studio/ /usr/local/
  #cp Files/Sect_Studio/Studio.desktop /usr/share/applications
  #cp Files/Sect_Studio/SMS_tester.desktop /usr/share/applications
  #chown -R ${myuser}:${myuser} /usr/local/Sect_Studio
CHROOT
fi
sleep 3

#THUNDERBIRD
if [ "${thund}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm thunderbird
CHROOT
fi
sleep 3

#PRINTER SUPPORT
if [ "${print}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm cups ghostscript gutenprint
  sleep 3
  systemctl enable cups.socket
  sleep 3
  cp /usr/share/applications/cups.desktop /home/${myuser}/.local/share/applications
  sleep 3
  sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/cups.desktop
  sleep 3
CHROOT
fi

#TORRENT
if [ "${torr}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm fragments
CHROOT
fi
sleep 3

#PLEX
if [ "${plex}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  sudo -u ${myuser} yay -S --needed --noconfirm plex-media-server
  sleep 3
  systemctl enable plexmediaserver
  sleep 3
  chmod -R 755 /home/${myuser}
  sleep 3
CHROOT
fi

#PYCHARM
if [ "${pycharm}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  sudo -u ${myuser} yay -S --needed --noconfirm pycharm-professional
  sleep 3
  pacman -S --needed --noconfirm python-pip
  sleep 3
CHROOT
fi

#STEAM
if [ "${games}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm steam
CHROOT
fi
sleep 3


###-----------------------------------------------------------------------------
### PART 6: POST INSTALL TWEAKS ------------------------------------------------
###-----------------------------------------------------------------------------


exit 0





#JOURNAL DISABLE
sed -i 's/#Storage=auto/Storage=none/g' /mnt/etc/systemd/journald.conf
rm -rf /mnt/var/log/journal/

# ---------------- todo investigate ---------------
#SWAPPINESS
echo "vm.swappiness=10" > /mnt/etc/sysctl.d/99-manjaro.conf

#DISABLE WAYLAND
sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' /mnt/etc/gdm/custom.conf

#BOOTLOADER
# quiet nmi_watchdog=0 nowatchdog udev.log_priority=3
echo "blacklist iTCO_wdt 
blacklist iTCO_vendor_support" > /mnt/etc/modprobe.d/watchdog.conf

#PLANK THEME
cp -R Files/Themes/Frenky/ /mnt/usr/share/plank/themes/

#SHUTDOWN TIME LIMIT
sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=2s/g' /mnt/etc/systemd/system.conf
rm -rf Files



cat << EOF > FILE
EOF

arch-chroot /mnt /bin/bash << CHROOT
CHROOT



#--------------------------------------------------------------------------
#FINISH INSTALLATION
umount -a
read -p "***********************************
***** Installation completed! *****
***********************************

*** Press any key to finish and reboot..." rbt
reboot
exit 0
