systemctl start ssh
passwd

cryptsetup open --type=luks /dev/sda5 cryptroot

wget 'www.archlinux.org/mirrorlist/?country=SG&protocol=http&protocol=https&ip_version=4' -O /etc/pacman.d/mirrorlist.b
sed 's/^#//' /etc/pacman.d/mirrorlist.b > /etc/pacman.d/mirrorlist.c
rankmirrors /etc/pacman.d/mirrorlist.c > /etc/pacman.d/mirrorlist
rm /etc/pacman.d/mirrorlist.b /etc/pacman.d/mirrorlist.c

pacman -Syy

ls /sys/firmware/efi/efivars

mkfs.btrfs -KL "Arch Linux" /dev/mapper/cryptroot

mkdir -p /mnt/btrfs-root
mount -o ssd,discard,noatime,compress=lzo /dev/mapper/cryptroot /mnt/btrfs-root
mkdir -p /mnt/btrfs-root/__snapshot
cd /mnt/btrfs-root && btrfs subvolume create __active && cd __active
btrfs subvolume create system && btrfs subvolume create home
btrfs subvolume create system/rootvol && btrfs subvolume create system/var && btrfs subvolume create system/opt

mkdir -p /mnt/btrfs-active && cd /mnt/btrfs-active
mount -o ssd,discard,noatime,compress=lzo,nodev,subvol=__active/system/rootvol /dev/mapper/cryptroot /mnt/btrfs-active
mkdir -p /mnt/btrfs-active/{home,opt,var,boot,boot/efi}
mount -o ssd,discard,noatime,compress=lzo,nosuid,nodev,subvol=__active/home /dev/mapper/cryptroot /mnt/btrfs-active/home
mount -o ssd,discard,noatime,compress=lzo,nosuid,nodev,subvol=__active/system/opt /dev/mapper/cryptroot /mnt/btrfs-active/opt
mount -o ssd,discard,noatime,compress=lzo,nosuid,nodev,noexec,subvol=__active/system/var /dev/mapper/cryptroot /mnt/btrfs-active/var

pacstrap /mnt/btrfs-active base base-devel efibootmgr grub-efi-x86_64 cryptsetup btrfs-progs openssh rsync bash-completion curl termite-terminfo wget vim

genfstab -pU /mnt/btrfs-active >> /mnt/btrfs-active/etc/fstab
genfstab -p /mnt/btrfs-active > /mnt/btrfs-active/etc/fstab
genfstab -pU /mnt/btrfs-active > /mnt/btrfs-active/etc/fstab
less /mnt/btrfs-active/etc/fstab

arch-chroot /mnt/btrfs-active /bin/bash

ln -sf /usr/share/zoneinfo/Asia/Singapore /etc/localtime
hwclock --systohc --utc --adjfile /etc/adjtime
sed -i 's/#en_SG.U/en_SG.U/g' /etc/locale.gen && locale-gen
echo LANG=en_SG.UTF-8 > /etc/locale.conf && export LANG=en_SG.UTF-8
echo "DF-X230" > /etc/hostname

sed -i 's/HOOKS="base udev autodetect modconf block filesystems keyboard fsck"/HOOKS="base udev autodetect modconf block keyboard keymap encrypt filesystems btrfs"/g' /etc/mkinitcpio.conf

sed -i 's/MODULES=""/MODULES="vfat aes_x86_64 crc32c-intel"/g' /etc/mkinitcpio.conf

sed -i 's,BINARIES="",BINARIES="/usr/bin/btrfsck",g' /etc/mkinitcpio.conf

mkinitcpio -p linux

mkdir -p /boot/efi && mount /dev/sda2 /boot/efi

mount /dev/sda2 /mnt/btrfs-active/boot/efi

echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch_grub --recheck --debug
grub-mkconfig -o /boot/grub/grub.cfg

exit
umount -R /mnt/btrfs-root && umount -R /mnt/btrfs-active
reboot
