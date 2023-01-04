#!/bin/bash

dev=${dev:-sdX}
boot=${dev}1
swap=${dev}2
root=${dev}3
ip=${ip:-192.168.1.217::192.168.1.1:255.255.255.0:rpi7:eth0:off}
zoneInfo=${zoneInfo:-America/New_York}

while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare "$param"="$2"
        # echo $1 $2 // Optional to see the parameter:value result
   fi

  shift
done

echo ""
echo "Creating bootable microSD card of Gentoo Raspberry PI on $dev."
echo "  An automated script of https://wiki.gentoo.org/wiki/Raspberry_Pi_3_64_bit_Install"
echo ""
echo "Will use the following partitions:"
echo "  boot=$boot"
echo "  swap=$swap"
echo "  root=$root"
echo "cmdline.txt for kernel will include IP=${ip}"
echo "Timezone will be set to: $zoneInfo"
echo ""
echo "If you want to change those params pass them in or edit this script."

while true; do
  echo ""
  read -p "This will destroy the filesystem on $dev. Should we proceed? [Yes/No]: " yn
  case $yn in
      [Yy]* ) break;;
      [Nn]* ) exit;;
      * ) echo "Please answer yes or no.";;
  esac
done

umount /dev/"${boot}"
umount /dev/"${swap}"
umount /dev/"${root}"
umount /dev/"${dev}4"

echo
echo "STEP 1: Partitioning disk ..."
echo

fdisk /dev/"${dev}" << EOF
d
4
d
3
d
2
d
n
p
1

+128M
t
c
n
p
2

+8G
t
2
82
n
p
3


p
w
EOF

echo
echo "STEP 2: Creating filesystems ..."
echo

mkfs -t vfat -F 32 /dev/"${boot}"
mkswap /dev/"${swap}"
mkfs -i 8192 -t ext4 /dev/"${root}"

echo
echo "STEP 3: Install the arm64 stage 3 ..."
echo

mount /dev/"${root}" /mnt/gentoo
tar xpf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
mkdir /mnt/gentoo/var/db/repos/gentoo
tar xpf portage-latest.tar.bz2 --strip-components=1 -C /mnt/gentoo/var/db/repos/gentoo

echo
echo "STEP 4: Populating /boot ..."
echo

mount /dev/"${boot}" /mnt/gentoo/boot
cp -rv ./firmware/boot/* /mnt/gentoo/boot
cp ./linux/arch/arm64/boot/Image /mnt/gentoo/boot/kernel8.img

echo
echo "STEP 5: Installing the device tree ..."
echo

mv /mnt/gentoo/boot/bcm2711-rpi-4-b.dtb /mnt/gentoo/boot/bcm2711-rpi-4-b.dtb_32
cp ./linux/arch/arm64/boot/dts/broadcom/bcm2711-rpi-4-b.dtb /mnt/gentoo/boot
cd ./linux || exit 1
ARCH=arm64 CROSS_COMPILE=aarch64-unknown-linux-gnu- make modules_install INSTALL_MOD_PATH=/mnt/gentoo

echo
echo "STEP 6: Verify install ..."
echo

ls /mnt/gentoo/boot
ls /mnt/gentoo/lib/modules

echo
echo "STEP 7: Raspberry Pi 3 peripherals ..."
echo

{
  echo "f0:12345:respawn:/sbin/agetty 9600 ttyAMA0 vt100";
} > /mnt/gentoo/etc/inittab

{
  echo "SUBSYSTEM==\"input\", GROUP=\"input\", MODE=\"0660\"";
  echo "SUBSYSTEM==\"i2c-dev\", GROUP=\"i2c\", MODE=\"0660\"";
  echo "SUBSYSTEM==\"spidev\", GROUP=\"spi\", MODE=\"0660\"";
  echo "SUBSYSTEM==\"bcm2835-gpiomem\", GROUP=\"gpio\", MODE=\"0660\"";
  echo "";
  echo "SUBSYSTEM==\"gpio*\", PROGRAM=\"/bin/sh -c '\\";
  echo "       chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio;\\";
  echo "       chown -R root:gpio /sys/devices/virtual/gpio && chmod -R 770 /sys/devices/virtual/gpio;\\";
  echo "       chown -R root:gpio /sys$devpath && chmod -R 770 /sys$devpath\\";
  echo "'\"";
  echo "";
  echo "KERNEL==\"ttyAMA[01]\", GROUP=\"dialout\", PROGRAM=\"/bin/sh -c '\\";
  echo "       ALIASES=/proc/device-tree/aliases; \\";
  echo "       if cmp -s $ALIASES/uart0 $ALIASES/serial0; then \\";
  echo "               echo 0;\\";
  echo "       elif cmp -s $ALIASES/uart0 $ALIASES/serial1; then \\";
  echo "               echo 1; \\";
  echo "       else \\";
  echo "               exit 1; \\";
  echo "       fi\\";
  echo "'\", SYMLINK+=\"serial%c\"";
  echo "";
  echo "KERNEL==\"ttyS0\", GROUP=\"dialout\", PROGRAM=\"/bin/sh -c '\\";
  echo "       ALIASES=/proc/device-tree/aliases; \\";
  echo "       if cmp -s $ALIASES/uart1 $ALIASES/serial0; then \\";
  echo "               echo 0; \\";
  echo "       elif cmp -s $ALIASES/uart1 $ALIASES/serial1; then \\";
  echo "               echo 1; \\";
  echo "       else \\";
  echo "               exit 1; \\";
  echo "       fi \\";
  echo "'\", SYMLINK+=\"serial%c\"";
} > /mnt/gentoo/etc/udev/rules.d/99-com.rules

echo
echo "STEP 8: Configuration files ..."
echo

{
  echo "/dev/mmcblk0p1          /boot           vfat            noauto,noatime  1 2";
  echo "/dev/mmcblk0p2          none            swap            sw              0 0";
  echo "/dev/mmcblk0p3          /               ext4            noatime         0 1";
} >> /mnt/gentoo/etc/fstab

{
  echo "# config.txt";
  echo "#   For more help consult https://www.raspberrypi.com/documentation/computers/config_txt.html";
  echo "";
  echo "# Have a properly sized image";
  echo "disable_overscan=1";
  echo "";
  echo "# Lets have the VC4 hardware accelerated video";
  echo "dtoverlay=vc4-fkms-v3d";
  echo "";
  echo "# For sound over HDMI";
  echo "hdmi_drive=2";
  echo "";
  echo "# Enable audio (loads snd_bcm2835)";
  echo "dtparam=audio=on";
  echo "";
  echo "# gpu_mem is for closed-source driver only; since we are only using the";
  echo "# open-source driver here, set low";
  echo "gpu_mem=16";
  echo "";
  echo "# Force booting in 64bit mode";
  echo "arm_64bit=1";
} > /mnt/gentoo/boot/config.txt

{
  echo "console=tty1 root=/dev/mmcblk0p3 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait cgroup_memory=1 cgroup_enable=memory ip=${ip}";
} > /mnt/gentoo/boot/cmdline.txt

echo
echo "STEP 9: Enable SSHD ..."
echo

ln -s /mnt/gentoo/lib/systemd/system/ntpdate.service /mnt/gentoo/etc/systemd/system/multi-user.target.wants/ntpdate.service

echo
echo "STEP 10: Configuring timezone ..."
echo

ln -sf /mnt/gentoo/usr/share/zoneinfo/"${zoneInfo}" /mnt/gentoo/etc/localtime
echo "${zoneInfo}" > /mnt/gentoo/etc/timezone
# emerge -v net-misc/ntp
# systemctl enable ntpdate.service

echo
echo "FINISHING: Unmounting ..."
echo

umount /mnt/gentoo/boot
umount /mnt/gentoo
