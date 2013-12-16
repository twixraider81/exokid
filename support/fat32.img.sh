#!/bin/bash
# these value must match with bochs!
set -x
CYLINDERS=100

dd if=/dev/zero of=/tmp/hdd.img bs=516096c count=$CYLINDERS
losetup /dev/loop0 /tmp/hdd.img
echo -ne 'c\no\nn\np\n1\n\n\na\n1\nw\n' | fdisk -C$CYLINDERS -S63 -H16 /dev/loop0
losetup -o32256 /dev/loop1 /dev/loop0
mkdosfs -F32 /dev/loop1
mkdir -p /tmp/hdd
mount -tvfat /dev/loop1 /tmp/hdd/
grub-install --root-directory=/tmp/hdd/ --disk-module=biosdisk --modules="part_msdos fat" /dev/loop0
umount /tmp/hdd/
rmdir /tmp/hdd/
losetup -d /dev/loop1
losetup -d /dev/loop0
xz -9 /tmp/hdd.img
mv /tmp/hdd.img.xz ./fat32.img.xz