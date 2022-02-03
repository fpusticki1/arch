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

#EXIT ON ERROR
set -e

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
useradd -m -s /usr/bin/zsh ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd root
usermod -c "${myname}" ${myuser}
echo "${myuser} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
chmod -R 755 /home/${myuser}
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
#---------------------------------
arch-chroot /mnt /bin/bash << CHROOT
sudo -u ${myuser} yay --save --answerdiff None --removemake
sudo -u ${myuser} mkdir -p /home/${myuser}/.config/systemd/user
sudo -u ${myuser} mkdir -p /home/${myuser}/.config/systemd/user/default.target.requires
sudo -u ${myuser} mkdir -p /home/${myuser}/.config/systemd/user/timers.target.wants
chmod +x /usr/local/checkupdates.sh
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
#arch-chroot /mnt /bin/bash << CHROOT
#sudo -u ${myuser} ln -s /home/${myuser}/.config/systemd/user/checkupdates.service /home/${myuser}/.config/systemd/user/default.target.requires
#CHROOT
#----------------------------------
cat << EOF > /mnt/home/${myuser}/.config/systemd/user/checkupdates.timer
[Unit]
Description=Run checkupdates every boot
[Timer]
OnBootSec=15sec
[Install]
WantedBy=timers.target
EOF
arch-chroot /mnt /bin/bash << CHROOT
sudo -u ${myuser} ln -s /home/${myuser}/.config/systemd/user/checkupdates.timer /home/${myuser}/.config/systemd/user/timers.target.wants
CHROOT
#---------------------------------

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
options root=${rootpart} rw quiet nowatchdog fsck.mode=skip
EOF


###-----------------------------------------------------------------------------
### PART 4: DESKTOP ENVIRONMENT INSTALLATION -----------------------------------
###-----------------------------------------------------------------------------

#XORG
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm xorg-server xorg-apps
CHROOT

#DISPLAY DRIVER
if [ "${mygpu}" = "intel" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm xf86-video-intel mesa
CHROOT
elif [ "${mygpu}" = "nvidia" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm nvidia nvidia-utils
CHROOT
elif [ "${mygpu}" = "amd" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm xf86-video-amdgpu mesa
CHROOT
else
  sleep 1
fi

#PIPEWIRE
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm wireplumber pipewire-jack pipewire-pulse
CHROOT

#DESKTOP ENVIRONMENT - GNOME
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm gnome-shell gnome-control-center gdm \
gnome-tweaks gnome-shell-extensions gnome-system-monitor gvfs-mtp \
gnome-terminal gnome-calculator gnome-screenshot gnome-backgrounds \
nautilus file-roller seahorse simple-scan xdg-user-dirs sushi eog
CHROOT

#ENABLE SERVICES
arch-chroot /mnt /bin/bash << CHROOT
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
systemctl enable systemd-boot-update
systemctl enable gdm
CHROOT

#DISABLE SERVICES
arch-chroot /mnt /bin/bash << CHROOT
systemctl disable lvm2-monitor
systemctl mask lvm2-monitor
systemctl disable ldconfig
systemctl mask ldconfig
CHROOT

#LAPTOP POWER SETTINGS
if [ "${iflaptop}" = "laptop" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  sudo -u ${myuser} yay -S --needed --noconfirm auto-cpufreq
  systemctl enable auto-cpufreq
CHROOT
fi

#JAVA -----------------------
#export JAVA_TOOL_OPTIONS='-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true'
#echo "JAVA_FONTS=/usr/share/fonts/TTF" >> /etc/environment
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm jdk-openjdk
archlinux-java fix
CHROOT

#FONTS
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm ttf-dejavu ttf-liberation \
ttf-hack ttf-ubuntu-font-family
CHROOT
if [ "${winfonts}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  sudo -u ${myuser} yay -S --needed --noconfirm ttf-ms-win10-auto
CHROOT
fi
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


###-----------------------------------------------------------------------------
### PART 5: APPS INSTALLATION --------------------------------------------------
###-----------------------------------------------------------------------------

#PACMAN PACKAGES
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm unrar p7zip htop neofetch wget \
mlocate net-tools plank vlc firefox libreoffice-still
CHROOT

#AUR PACKAGES
arch-chroot /mnt /bin/bash << CHROOT
sudo -u ${myuser} yay -S --needed --noconfirm sublime-text-4 \
google-chrome yaru-icon-theme
CHROOT

#NTH APPS
if [ "${nth}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm mysql-workbench remmina freerdp audacity
  sudo -u ${myuser} yay -S --needed --noconfirm skypeforlinux-stable-bin \
  zoom postman-bin
  mkdir /home/${myuser}/temp
  cd /home/${myuser}/temp
  curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/Zoiper_3.3_Linux_Free_64Bit.run
  curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/OpenVPN.zip
  curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/Sect_Studio.zip
  chmod +x *
  yes | Zoiper_3.3_Linux_Free_64Bit.run
  unzip OpenVPN.zip
  cp -R OpenVPN/ /usr/local/
  unzip Sect_Studio.zip
  cp -R Sect_Studio/ /usr/local/
  cp Sect_Studio/Studio.desktop /usr/share/applications
  cp Sect_Studio/SMS_tester.desktop /usr/share/applications
  chown -R ${myuser}:${myuser} /usr/local/Sect_Studio
  cd
  rm -rf /home/${myuser}/temp
CHROOT
fi

#THUNDERBIRD
if [ "${thund}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm thunderbird
CHROOT
fi

#PRINTER SUPPORT
if [ "${print}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm cups gutenprint
  systemctl enable cups.socket
  mkdir -p /home/${myuser}/.local/share/applications
  cp /usr/share/applications/cups.desktop /home/${myuser}/.local/share/applications
  sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/cups.desktop
CHROOT
fi

#TORRENT
if [ "${torr}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm fragments
CHROOT
fi

#PLEX
if [ "${plex}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  sudo -u ${myuser} yay -S --needed --noconfirm plex-media-server
  systemctl enable plexmediaserver
CHROOT
fi

#PYCHARM
if [ "${pycharm}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  sudo -u ${myuser} yay -S --needed --noconfirm pycharm-professional
  pacman -S --needed --noconfirm python-pip
CHROOT
fi

#STEAM
if [ "${games}" = "y" ]; then
  cat << EOF >> /mnt/etc/pacman.conf

  [multilib]
  Include = /etc/pacman.d/mirrorlist
EOF
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -Syu --noconfirm
  pacman -S --needed --noconfirm steam
CHROOT
fi


###-----------------------------------------------------------------------------
### PART 6: POST INSTALL TWEAKS ------------------------------------------------
###-----------------------------------------------------------------------------

#JOURNAL DISABLE
sed -i 's/#Storage=auto/Storage=none/g' /mnt/etc/systemd/journald.conf
rm -rf /mnt/var/log/journal/

#SWAPPINESS
echo "vm.swappiness=10" > /mnt/etc/sysctl.d/99-swappiness.conf

#DISABLE WAYLAND
sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' /mnt/etc/gdm/custom.conf

#PLANK THEME, WALLPAPER
arch-chroot /mnt /bin/bash << CHROOT
mkdir /home/${myuser}/temp
cd /home/${myuser}/temp
curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/dock.theme
curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/Mojave.jpg
curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/Mountain.jpg
curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/2dwall.jpg
curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/kbd_shortcuts.zip
curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/App_screen.png
curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/mysql_conn.zip
chmod +x *
cp dock.theme /usr/share/plank/themes/Default
cp Mojave.jpg /usr/share/backgrounds
cp Mountain.jpg /usr/share/backgrounds
cp 2dwall.jpg /usr/share/backgrounds
cp kbd_shortcuts.zip /home/${myuser}
cp App_screen.png /home/${myuser}
cp mysql_conn.zip /home/${myuser}
cd
rm -rf /home/${myuser}/temp
CHROOT
