#!/bin/bash

nproc=${nproc-2}

while [ $# -gt 0 ]; do
  if [[ $1 == *"--"* ]]; then
      param="${1/--/}"
      declare "$param"="$2"
  fi
  shift
done

echo ""
echo "STEP 1: Setting up the build environment ..."
echo ""

while true; do
  echo ""
  read -p "Do you want to build the toolchain? [Yes/No]: " yn
  case $yn in
      [Yy]* )
        emerge --ask sys-devel/crossdev dev-vcs/git;
        mkdir -p /var/db/repos/localrepo-crossdev/{profiles,metadata};
        echo 'crossdev' > /var/db/repos/localrepo-crossdev/profiles/repo_name;
        echo 'masters = gentoo' > /var/db/repos/localrepo-crossdev/metadata/layout.conf;
        chown -R portage:portage /var/db/repos/localrepo-crossdev;
        {
          echo [crossdev]
          echo location = /var/db/repos/localrepo-crossdev
          echo priority = 10
          echo masters = gentoo
          echo auto-sync = no
        } >> /etc/portage/repos.conf/crossdev.conf;
        echo "Building the ARM64 compiler toolchain. This will take a while..."
        crossdev -t aarch64-unknown-linux-gnu
       break;;
      [Nn]* ) break;;
      * ) echo "Please answer yes or no.";;
  esac
done

echo ""
echo "STEP 2: Compiling the kernel ..."
echo ""

mkdir raspberrypi && cd raspberrypi || exit 1
git clone -b stable --depth=1 https://github.com/raspberrypi/firmware
git clone https://github.com/raspberrypi/linux

cd linux || exit 2
ARCH=arm64 CROSS_COMPILE=aarch64-unknown-linux-gnu- make bcm2711_defconfig
ARCH=arm64 CROSS_COMPILE=aarch64-unknown-linux-gnu- make menuconfig

ARCH=arm64 CROSS_COMPILE=aarch64-unknown-linux-gnu- make -j"$(nproc)"
