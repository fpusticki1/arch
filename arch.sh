#!/bin/bash

echo "####################################################"
echo "##### Welcome to the Arch installation script. #####"
echo "####################################################"
echo && sleep 1


###-----------------------------------------------------------------------------
### PART 1: BASIC CONFIGURATION ------------------------------------------------
###-----------------------------------------------------------------------------

### SET KEYMAP
loadkeys croat

### USER INPUTS
echo "***************************************************"
read -p "*** Is your name Franjo Pustički? (y/n): " ifname
if [ "${ifname}" = "y" ]; then
  myname="Franjo Pustički"
else
  read -p "*** Enter your full name: " myname
fi
read -p "*** Is this a laptop? (y/n): " iflaptop
read -p "*** Select CPU? (intel/amd): " mycpu
read -p "*** Select GPU? (intel/amd/nvidia): " mygpu
read -p "*** Enter hostname: " myhostname
read -p "*** Enter username: " myuser
read -p "*** Enter password: " mypassword
read -p "*** Install NTH apps? (y/N): " nth
read -p "*** Install Thunderbird? (y/N): " thund
read -p "*** Install Printer support? (y/N): " print
read -p "*** Install Torrent support? (y/N): " torr
read -p "*** Install Plex media server? (y/N): " plex
read -p "*** Install Pycharm? (y/N): " pycharm
read -p "*** Install Steam for games? (y/N): " games

### SET TIME
timedatectl set-timezone Europe/Zagreb
timedatectl set-ntp true

### DISK PARTITIONING
echo
echo "*****************  Listing Disk drives  *****************"
echo "*********************************************************"
fdisk -l
echo "*********************************************************"
echo && sleep 1
echo "This operation will erase the disk!!!"
echo && sleep 1
read -p "*** Enter your disk name (example: /dev/sda ): " mydisk
echo
read -p "Selected disk is: *** ${mydisk} ***
*** Are you sure you want to erase it and install Arch Linux? (yes/n): " confirm
if [ "${confirm}" = "yes" ]; then
  for n in ${mydisk}* ; do umount $n ; done
  sleep 1
  for n in ${mydisk}* ; do swapoff $n ; done
  sleep 1
  if [ "${mydisk}" = "/dev/nvme0n1" ]; then
    wipefs -a "${mydisk}" "${mydisk}p1" "${mydisk}p2" "${mydisk}p3"
  else
    wipefs -a "${mydisk}" "${mydisk}1" "${mydisk}2" "${mydisk}3"
  fi
  sleep 1
  (echo g; echo n; echo; echo; echo +512M; echo t; echo 1; echo w) | fdisk ${mydisk}
  sleep 1
  (echo n; echo; echo; echo +4G; echo t; echo; echo 19; echo w) | fdisk ${mydisk}
  sleep 1
  (echo n; echo; echo; echo; echo w) | fdisk ${mydisk}
  sleep 1
  if [ "${mydisk}" = "/dev/nvme0n1" ]; then
    bootpart="${mydisk}p1"
    swappart="${mydisk}p2"
    rootpart="${mydisk}p3"
  else
    bootpart="${mydisk}1"
    swappart="${mydisk}2"
    rootpart="${mydisk}3"  
  fi

else
  echo "***** Exiting installation script... *****"
  sleep 5
  exit 0
fi

### PARTITION FORMATTING
mkfs.ext4 ${rootpart}
mkswap ${swappart}
mkfs.fat -F 32 ${bootpart}

### MOUNTING FILESYSTEMS
mount ${rootpart} /mnt
swapon ${swappart}
mkdir /mnt/boot
mount ${bootpart} /mnt/boot

### SHOW CREATED PARTITIONS
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

### BASE SYSTEM INSTALL
pacstrap /mnt base base-devel linux linux-firmware \
dosfstools f2fs-tools man-db man-pages nano git zsh \
networkmanager networkmanager-openvpn openresolv ${mycpu}-ucode

### USER ACCOUNTS
arch-chroot /mnt /bin/bash << CHROOT
useradd -m -G users -s /usr/bin/zsh ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd ${myuser}
(echo ${mypassword}; echo ${mypassword}) | passwd root
usermod -c "${myname}" ${myuser}
echo "${myuser} ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
CHROOT

### INSTALL PARU
arch-chroot /mnt /bin/bash << CHROOT
cd /opt
git clone https://aur.archlinux.org/paru.git
chown -R ${myuser}:${myuser} paru
cd paru
sudo -u ${myuser} makepkg -si --noconfirm
CHROOT


###-----------------------------------------------------------------------------
### PART 3: SYSTEM CONFIGURATION -----------------------------------------------
###-----------------------------------------------------------------------------

### PACMAN CONFIGURATION
sed -i 's/#include \"\/usr\/share\/nano\/\*.nanorc\"/include \"\/usr\/share\/nano\/\*.nanorc\"/g' /mnt/etc/nanorc
sed -i 's/#Color/Color/g' /mnt/etc/pacman.conf
sed -i 's/#VerbosePkgLists/VerbosePkgLists/g' /mnt/etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 8/g' /mnt/etc/pacman.conf
sed -i 's/#RemoveMake/RemoveMake/g' /mnt/etc/paru.conf
sed -i '/^\[options\]/a SkipReview' /mnt/etc/paru.conf
sed -i 's/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j\$(nproc)\"/g' /mnt/etc/makepkg.conf
sed -i 's/COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=0 -)/g' /mnt/etc/makepkg.conf
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
sudo rm -rf /var/cache/pacman/pkg/{,.[!.],..?}*
sudo rm -rf /home/${myuser}/.cache/paru/{,.[!.],..?}*
paru -Sy
if [[ \$(paru -Qu) ]]; then
  notify-send '*** UPDATES ***' 'New updates available...'
fi
exit 0
EOF
#---------------------------------
arch-chroot /mnt /bin/bash << CHROOT
chmod +x /usr/local/checkupdates.sh
sudo -u ${myuser} mkdir -p /home/${myuser}/.config/systemd/user/timers.target.wants
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
#----------------------------------
cat << EOF > /mnt/home/${myuser}/.config/systemd/user/checkupdates.timer
[Unit]
Description=Run checkupdates every boot
[Timer]
OnBootSec=10sec
[Install]
WantedBy=timers.target
EOF
#---------------------------------
arch-chroot /mnt /bin/bash << CHROOT
chown ${myuser}:${myuser} /home/${myuser}/.config/systemd/user/checkupdates.service
chown ${myuser}:${myuser} /home/${myuser}/.config/systemd/user/checkupdates.timer
sudo -u ${myuser} ln -s /home/${myuser}/.config/systemd/user/checkupdates.timer /home/${myuser}/.config/systemd/user/timers.target.wants
CHROOT
#---------------------------------

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

### BLACKLIST MODULES
cat << EOF > /mnt/etc/modprobe.d/blacklist.conf
blacklist iTCO_wdt
blacklist iTCO_vendor_support
blacklist aesni_intel
blacklist pcspkr
blacklist joydev
blacklist mousedev
blacklist mac_hid
EOF

### INITRAMFS
sed -i 's/HOOKS=(base udev autodetect/HOOKS=(base systemd autodetect/g' /mnt/etc/mkinitcpio.conf
sed -i 's/#COMPRESSION=\"lz4\"/COMPRESSION=\"lz4\"/g' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt /bin/bash << CHROOT
mkinitcpio -P
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
options root=${rootpart} rw quiet loglevel=3 rd.udev.log_level=3 nowatchdog
EOF


###-----------------------------------------------------------------------------
### PART 4: DESKTOP ENVIRONMENT INSTALLATION -----------------------------------
###-----------------------------------------------------------------------------

### XORG
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm xorg-server xorg-apps
CHROOT

### DISPLAY DRIVER
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
  pacman -S --needed --noconfirm xf86-video-amdgpu 
  sudo -u ${myuser} paru -S --needed --noconfirm amdgpu-pro-libgl
CHROOT
else
  sleep 1
fi

### PIPEWIRE
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm wireplumber pipewire-jack pipewire-pulse
CHROOT

### DESKTOP ENVIRONMENT - GNOME
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm gnome-shell gnome-control-center gdm \
gnome-tweaks gnome-shell-extensions gnome-system-monitor gvfs-mtp \
gnome-terminal gnome-calculator gnome-screenshot gnome-backgrounds \
nautilus file-roller seahorse simple-scan xdg-user-dirs sushi eog
CHROOT

### ENABLE SERVICES
arch-chroot /mnt /bin/bash << CHROOT
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
systemctl enable systemd-boot-update
systemctl enable gdm
CHROOT

### DISABLE SERVICES
arch-chroot /mnt /bin/bash << CHROOT
systemctl disable lvm2-monitor
systemctl mask lvm2-monitor
systemctl disable ldconfig
systemctl mask ldconfig
CHROOT

### LAPTOP POWER SETTINGS
if [ "${iflaptop}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm tlp sof-firmware
  systemctl enable tlp
CHROOT
fi

### JAVA
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm jdk11-openjdk
archlinux-java fix
CHROOT


###-----------------------------------------------------------------------------
### PART 5: APPS INSTALLATION --------------------------------------------------
###-----------------------------------------------------------------------------

### PACMAN PACKAGES
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm unrar p7zip htop neofetch wget \
mlocate net-tools plank vlc firefox libreoffice-still zsh-completions \
zsh-syntax-highlighting zsh-history-substring-search zsh-autosuggestions
CHROOT

### AUR PACKAGES
arch-chroot /mnt /bin/bash << CHROOT
sudo -u ${myuser} paru -S --needed --noconfirm sublime-text-4 \
google-chrome chrome-gnome-shell yaru-icon-theme zsh-theme-powerlevel10k-git
CHROOT

### NTH APPS
if [ "${nth}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm mysql-workbench remmina freerdp audacity
  sudo -u ${myuser} paru -S --needed --noconfirm skypeforlinux-stable-bin zoom postman-bin
  sudo -u ${myuser} mkdir -p /home/${myuser}/temp
  cd /home/${myuser}/temp
  sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/Zoiper_3.3_Linux_Free_64Bit.run
  chmod +x Zoiper_3.3_Linux_Free_64Bit.run
  sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/OpenVPN.zip
  unzip OpenVPN.zip
  cp -R OpenVPN/ /usr/local/
  rm -rf OpenVPN*
  sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/Sect_Studio.zip
  unzip Sect_Studio.zip
  cp -R Sect_Studio/ /usr/local/
  cp Sect_Studio/Studio.desktop /usr/share/applications
  cp Sect_Studio/SMS_tester.desktop /usr/share/applications
  chown -R ${myuser}:${myuser} /usr/local/Sect_Studio
  rm -rf Sect_Studio*
  sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/mysql_conn.zip
  sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/dotfiles/Config.xml
  sudo -u ${myuser} mkdir -p /home/${myuser}/.Zoiper
  sudo -u ${myuser} mv Config.xml /home/${myuser}/.Zoiper
  sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/dotfiles/audacity.cfg
  sudo -u ${myuser} mkdir -p /home/${myuser}/.audacity-data
  sudo -u ${myuser} mv audacity.cfg /home/${myuser}/.audacity-data
CHROOT
fi

### THUNDERBIRD
if [ "${thund}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm thunderbird
CHROOT
fi

### PRINTER SUPPORT
if [ "${print}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm cups gutenprint
  systemctl enable cups.socket
  sudo -u ${myuser} mkdir -p /home/${myuser}/.local/share/applications
  cp /usr/share/applications/cups.desktop /home/${myuser}/.local/share/applications
  sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/cups.desktop
CHROOT
fi

### TORRENT
if [ "${torr}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm fragments
CHROOT
fi

### PLEX
if [ "${plex}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  sudo -u ${myuser} paru -S --needed --noconfirm plex-media-server
  systemctl enable plexmediaserver
CHROOT
fi

### PYCHARM
if [ "${pycharm}" = "y" ]; then
  arch-chroot /mnt /bin/bash << CHROOT
  sudo -u ${myuser} paru -S --needed --noconfirm pycharm-professional
  pacman -S --needed --noconfirm python-pip
CHROOT
fi

### STEAM
if [ "${games}" = "y" ]; then
  cat << EOF >> /mnt/etc/pacman.conf
  [multilib]
  Include = /etc/pacman.d/mirrorlist
EOF
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -Syu --noconfirm
CHROOT
  if [ "${mygpu}" = "intel" ]; then
    arch-chroot /mnt /bin/bash << CHROOT
    pacman -S --needed --noconfirm lib32-mesa vulkan-intel lib32-vulkan-intel
CHROOT
  elif [ "${mygpu}" = "nvidia" ]; then
    arch-chroot /mnt /bin/bash << CHROOT
    pacman -S --needed --noconfirm lib32-nvidia-utils
CHROOT
  elif [ "${mygpu}" = "amd" ]; then
    arch-chroot /mnt /bin/bash << CHROOT
    sudo -u ${myuser} paru -S --needed --noconfirm lib32-amdgpu-pro-libgl
    pacman -S --needed --noconfirm amdvlk lib32-amdvlk
CHROOT
  fi
  arch-chroot /mnt /bin/bash << CHROOT
  pacman -S --needed --noconfirm steam
CHROOT
fi


###-----------------------------------------------------------------------------
### PART 6: POST INSTALL TWEAKS ------------------------------------------------
###-----------------------------------------------------------------------------

### SYSTEMD TWEAKS
sed -i 's/#Storage=auto/Storage=none/g' /mnt/etc/systemd/journald.conf
sed -i 's/#DefaultTimeoutStopSec.*/DefaultTimeoutStopSec=2s/g' /mnt/etc/systemd/system.conf
rm -rf /mnt/var/log/journal/

### SWAPPINESS
echo "vm.swappiness=10" > /mnt/etc/sysctl.d/99-swappiness.conf

### DISABLE WAYLAND
sed -i '/^\[daemon\]/a AutomaticLoginEnable=True' /mnt/etc/gdm/custom.conf
sed -i "/^\[daemon\]/a AutomaticLogin=${myuser}" /mnt/etc/gdm/custom.conf
sed -i 's/#WaylandEnable=false/WaylandEnable=false/g' /mnt/etc/gdm/custom.conf

### PLANK THEME, WALLPAPER, Z-SHELL
arch-chroot /mnt /bin/bash << CHROOT
sudo -u ${myuser} mkdir -p /home/${myuser}/temp
cd /home/${myuser}/temp
sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/Todo.txt
sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/kbd_shortcuts.zip
sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/App_screen.png
curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/dock.theme
mv dock.theme /usr/share/plank/themes/Default
curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/2dwall.jpg
mv 2dwall.jpg /usr/share/backgrounds/gnome
sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/p10k.zsh
sudo -u ${myuser} mv p10k.zsh /home/${myuser}/.p10k.zsh
sudo -u ${myuser} curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/zshrc
chmod +x zshrc
sudo -u ${myuser} mv zshrc /home/${myuser}/.zshrc
CHROOT

### HIDING APPLICATIONS FROM START MENU
arch-chroot /mnt /bin/bash << CHROOT
sudo -u ${myuser} mkdir -p /home/${myuser}/.local/share/applications
cp /usr/share/applications/libreoffice-base.desktop /home/${myuser}/.local/share/applications
cp /usr/share/applications/libreoffice-draw.desktop /home/${myuser}/.local/share/applications
cp /usr/share/applications/libreoffice-math.desktop /home/${myuser}/.local/share/applications
cp /usr/share/applications/libreoffice-startcenter.desktop /home/${myuser}/.local/share/applications
cp /usr/share/applications/avahi-discover.desktop /home/${myuser}/.local/share/applications
cp /usr/share/applications/bvnc.desktop /home/${myuser}/.local/share/applications
cp /usr/share/applications/bssh.desktop /home/${myuser}/.local/share/applications
cp /usr/share/applications/qv4l2.desktop /home/${myuser}/.local/share/applications
cp /usr/share/applications/qvidcap.desktop /home/${myuser}/.local/share/applications
cp /usr/share/applications/nm-connection-editor.desktop /home/${myuser}/.local/share/applications
sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/libreoffice-base.desktop
sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/libreoffice-draw.desktop
sed -i 's/NoDisplay=false/NoDisplay=true/g' /home/${myuser}/.local/share/applications/libreoffice-math.desktop
sed -i 's/NoDisplay=false/NoDisplay=true/g' /home/${myuser}/.local/share/applications/libreoffice-startcenter.desktop
sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/avahi-discover.desktop
sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/bvnc.desktop
sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/bssh.desktop
sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/qv4l2.desktop
sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/qvidcap.desktop
sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /home/${myuser}/.local/share/applications/nm-connection-editor.desktop
CHROOT

### FONTS
arch-chroot /mnt /bin/bash << CHROOT
pacman -S --needed --noconfirm ttf-dejavu ttf-liberation \
ttf-hack ttf-ubuntu-font-family noto-fonts-emoji
cd /home/${myuser}/temp
curl -LO https://raw.githubusercontent.com/fpusticki1/arch/main/ms-fonts.zip
unzip ms-fonts.zip
chmod 755 ms-fonts
mv ms-fonts /usr/share/fonts/
rm -rf ms-fonts.zip
CHROOT
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
</fontconfig>
EOF

### FINISH INSTALLATION
rm -rf /mnt/home/${myuser}/.bash_logout
rm -rf /mnt/home/${myuser}/.bash_profile
rm -rf /mnt/home/${myuser}/.bashrc
umount -a
read -p "***********************************
***** Installation completed! *****
***********************************"
exit 0
