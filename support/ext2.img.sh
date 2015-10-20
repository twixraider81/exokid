#!/bin/bash
# these value must match with bochs!
set -x
CYLINDERS=100

dd if=/dev/zero of=/tmp/hdd.img bs=516096c count=$CYLINDERS
losetup /dev/loop0 /tmp/hdd.img
echo -ne 'o\nn\np\n1\n\n\na\n1\nw\n' | fdisk -C$CYLINDERS -S63 -H16 /dev/loop0
losetup -o 1048576 /dev/loop1 /dev/loop0
mke2fs /dev/loop1
mkdir -p /tmp/hdd
mount /dev/loop1 /tmp/hdd/
grub-install --root-directory=/tmp/hdd/ --disk-module=biosdisk --modules="part_msdos ext2" /dev/loop0
umount /tmp/hdd/
rmdir /tmp/hdd/
losetup -d /dev/loop1
losetup -d /dev/loop0
xz -9 /tmp/hdd.img
mv /tmp/hdd.img.xz ./ext2.img.xz