#!/bin/bash

# Arch Linux Installer by: Franjo Pusticki
# ------------------------------------------------------------------------------

#USER INPUTS
echo "***************************************************"
read -p "*** Enter your full name: " myname
read -p "*** Enter username: " myuser
read -p "*** Enter password: " mypassword
read -p "*** Enter hostname: " myhostname
read -p "*** AMD or Intel CPU? (amd/intel): " mycpu
read -p "*** Connect to wifi? (y/n): " wifi


###-----------------------------------------------------------------------------
### PART 2: BASE SYSTEM INSTALLATION -------------------------------------------
###-----------------------------------------------------------------------------

#BASE SYSTEM INSTALL
pacstrap /mnt base base-devel linux linux-firmware \
dosfstools f2fs-tools man-db man-pages nano git zsh \
networkmanager networkmanager-openvpn openresolv
(echo systemctl enable NetworkManager) | arch-chroot /mnt

read -p "Press enter to continue"

#USER ACCOUNTS
(echo "(echo ${mypassword}; echo ${mypassword}) | passwd root") | arch-chroot /mnt
(echo useradd -m -G wheel -s /usr/bin/zsh ${myuser}) | arch-chroot /mnt
(echo "(echo ${mypassword}; echo ${mypassword}) | passwd ${myuser}") | arch-chroot /mnt
(echo usermod -c \"${myname}\" ${myuser}) | arch-chroot /mnt
sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers

read -p "Press enter to continue"

#INSTALL YAY
(echo "sudo -u ${myuser} git clone https://aur.archlinux.org/yay.git && cd yay && sudo -u ${myuser} makepkg -si") | arch-chroot /mnt

read -p "Press enter to continue"

#PACMAN CONFIGURATION
echo "Server = http://mirror.luzea.de/archlinux/\$repo/os/\$arch
Server = http://arch.jensgutermuth.de/\$repo/os/\$arch
Server = http://mirror.wtnet.de/arch/\$repo/os/\$arch
Server = https://mirror.osbeck.com/archlinux/\$repo/os/\$arch
Server = http://archlinux.iskon.hr/\$repo/os/\$arch" > /mnt/etc/pacman.d/mirrorlist
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 8/g' /mnt/etc/pacman.conf
sed -i 's/#Color/Color/g' /mnt/etc/pacman.conf
sed -i 's/#VerbosePkgLists/VerbosePkgLists/g' /mnt/etc/pacman.conf
(echo sudo -u ${myuser} yay --save --answerdiff None) | arch-chroot /mnt

read -p "Press enter to continue"

# --------------------------------
echo "#!/bin/bash
rm -rf /var/cache/pacman/pkg/{,.[!.],..?}* /home/${myuser}/.cache/yay/{,.[!.],..?}*
exit 0" > /mnt/usr/local/cleancache.sh 
chmod +x /mnt/usr/local/cleancache.sh

read -p "Press enter to continue"

# --------------------------------
echo "[Trigger]
Operation = Remove
Operation = Install
Operation = Upgrade
Type = Package
Target = *
[Action]
Description = Cleaning cache...
When = PostTransaction
Exec = /usr/local/cleancache.sh " > /mnt/usr/share/libalpm/hooks/cleancache.hook

read -p "Press enter to continue"

# --------------------------------
echo "#!/bin/bash
if [[ \$(pacman -Qu) || \$(yay -Qu) ]]; then
  notify-send '*** UPDATES ***' 'New updates available...' --icon=dialog-information
fi
exit 0" > /mnt/usr/local/checkupdates.sh
chmod +x /mnt/usr/local/checkupdates.sh

read -p "Press enter to continue"

#---------------------------------
(echo sudo -u ${myuser} mkdir -p /home/${myuser}/.config/systemd/user) | arch-chroot /mnt
echo "[Unit]
Description=Check Updates service
[Service]
Type=oneshot
ExecStart=/usr/local/checkupdates.sh
[Install]
RequiredBy=default.target" > /mnt/home/${myuser}/.config/systemd/user/checkupdates.service

read -p "Press enter to continue"

#----------------------------------
echo "[Unit]
Description=Run checkupdates every boot
[Timer]
OnBootSec=15sec
[Install]
WantedBy=timers.target" > /mnt/home/${myuser}/.config/systemd/user/checkupdates.timer

read -p "Press enter to continue"

### Gnome, xorg, 

### ADD PACMAN AND YAY PACKAGES HERE !

###-----------------------------------------------------------------------------
### PART 3: SYSTEM CONFIGURATION -----------------------------------------------
###-----------------------------------------------------------------------------

#FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

#TIME ZONE
(echo ln -sf /usr/share/zoneinfo/Europe/Zagreb /etc/localtime) | arch-chroot /mnt
(echo hwclock --systohc) | arch-chroot /mnt
(echo systemctl enable systemd-timesyncd) | arch-chroot /mnt

read -p "Press enter to continue"





# LOCALE AND KEYMAP
echo "en_US.UTF-8 UTF-8
hr_HR.UTF-8 UTF-8" >> /mnt/etc/locale.gen
(echo locale-gen) | arch-chroot /mnt
echo "LANG=en_US.UTF-8
LC_ADDRESS=hr_HR.UTF-8
LC_IDENTIFICATION=hr_HR.UTF-8
LC_MEASUREMENT=hr_HR.UTF-8
LC_MONETARY=hr_HR.UTF-8
LC_NAME=hr_HR.UTF-8
LC_NUMERIC=hr_HR.UTF-8
LC_PAPER=hr_HR.UTF-8
LC_TELEPHONE=hr_HR.UTF-8
LC_TIME=hr_HR.UTF-8" > /mnt/etc/locale.conf
(echo localectl set-keymap --no-convert croat) | arch-chroot /mnt
(echo localectl set-x11-keymap --no-convert hr) | arch-chroot /mnt

read -p "Press enter to continue"

#NETWORK
echo "${myhostname}" > /mnt/etc/hostname
echo "127.0.0.1  localhost
::1        localhost
127.0.1.1  ${myhostname}" >> /mnt/etc/hosts

read -p "Press enter to continue"







#INITRAMFS
sed -i 's/^HOOKS=(base udev.*/HOOKS=(base systemd autodetect modconf block filesystems keyboard fsck)/g' /mnt/etc/mkinitcpio.conf
sed -i 's/#COMPRESSION=\"lz4\"/COMPRESSION=\"lz4\"/g' /mnt/etc/mkinitcpio.conf
(echo mkinitcpio -P) | arch-chroot /mnt

read -p "Press enter to continue"

#BOOTLOADER
(echo bootctl install) | arch-chroot /mnt
echo "timeout 0
default arch" > /mnt/boot/loader/loader.conf
echo "title Arch Linux
linux /vmlinuz-linux
initrd /${mycpu}-ucode.img
initrd /initramfs-linux.img
options root=${rootpart} rw quiet splash" > /mnt/boot/loader/entries/arch.conf

read -p "Press enter to continue"

#CLEAN ORPHAN PACKAGES
(echo "if [[ \$(pacman -Qqdt) ]]; then
  pacman -Rsc --noconfirm \$(pacman -Qqdt)
fi") | arch-chroot /mnt
(echo "if [[ \$(sudo -u ${myuser} yay -Qqdt) ]]; then
  sudo -u ${myuser} yay -Rsc --noconfirm \$(sudo -u ${myuser} yay -Qqdt)
fi") | arch-chroot /mnt

read -p "Press enter to continue"

exit 0
