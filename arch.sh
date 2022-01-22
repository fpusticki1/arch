#!/bin/bash

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>log.out 2>&1

echo "***************************************************"
read -p "*** Enter your full name: " myname
read -p "*** Enter username: " myuser
read -p "*** Enter password: " mypassword
read -p "*** Enter hostname: " myhostname
read -p "*** AMD or Intel CPU? (amd/intel): " mycpu
read -p "*** Connect to wifi? (y/n): " wifi


#USER ACCOUNTS
(echo "(echo ${mypassword}; echo ${mypassword}) | passwd root") | arch-chroot /mnt
(echo useradd -m -G wheel -s /usr/bin/zsh ${myuser}) | arch-chroot /mnt
(echo "(echo ${mypassword}; echo ${mypassword}) | passwd ${myuser}") | arch-chroot /mnt
(echo usermod -c "${myname}" ${myuser}) | arch-chroot /mnt
sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/s/^#//' /mnt/etc/sudoers

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

#NETWORK
echo "${myhostname}" > /mnt/etc/hostname
echo "127.0.0.1  localhost
::1        localhost
127.0.1.1  ${myhostname}" >> /mnt/etc/hosts

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
# --------------------------------
echo "#!/bin/bash
rm -rf /var/cache/pacman/pkg/{,.[!.],..?}* /home/${myuser}/.cache/yay/{,.[!.],..?}*
exit 0" > /mnt/usr/local/cleancache.sh 
chmod +x /mnt/usr/local/cleancache.sh
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
# --------------------------------
echo "#!/bin/bash
if [[ \$(pacman -Qu) || \$(yay -Qu) ]]; then
  notify-send '*** UPDATES ***' 'New updates available...' --icon=dialog-information
fi
exit 0" > /mnt/usr/local/checkupdates.sh
chmod +x /mnt/usr/local/checkupdates.sh
#---------------------------------
(echo sudo -u ${myuser} mkdir -p /home/${myuser}/.config/systemd/user) | arch-chroot /mnt
echo "[Unit]
Description=Check Updates service
[Service]
Type=oneshot
ExecStart=/usr/local/checkupdates.sh
[Install]
RequiredBy=default.target" > /mnt/home/${myuser}/.config/systemd/user/checkupdates.service
(echo systemctl --user enable checkupdates.service) | arch-chroot /mnt
#----------------------------------
echo "[Unit]
Description=Run checkupdates every boot
[Timer]
OnBootSec=15sec
[Install]
WantedBy=timers.target" > /mnt/home/${myuser}/.config/systemd/user/checkupdates.timer
(echo systemctl --user enable checkupdates.timer) | arch-chroot /mnt

#INITRAMFS
sed -i 's/^HOOKS=(base udev.*/HOOKS=(base systemd autodetect modconf block filesystems keyboard fsck)/g' /mnt/etc/mkinitcpio.conf
sed -i 's/#COMPRESSION=\"lz4\"/COMPRESSION=\"lz4\"/g' /mnt/etc/mkinitcpio.conf
(echo mkinitcpio -P) | arch-chroot /mnt

#BOOTLOADER
(echo bootctl install) | arch-chroot /mnt
echo "timeout 0
default arch" > /mnt/boot/loader/loader.conf
echo "title Arch Linux
linux /vmlinuz-linux
initrd /${mycpu}-ucode.img
initrd /initramfs-linux.img
options root=${rootpart} rw quiet splash" > /mnt/boot/loader/entries/arch.conf

#CLEAN ORPHAN PACKAGES
(echo "if [[ \$(pacman -Qqdt) ]]; then
  pacman -Rsc --noconfirm \$(pacman -Qqdt)
fi") | arch-chroot /mnt
(echo "if [[ \$(sudo -u ${myuser} yay -Qqdt) ]]; then
  sudo -u ${myuser} yay -Rsc --noconfirm \$(sudo -u ${myuser} yay -Qqdt)
fi") | arch-chroot /mnt


exit 0
