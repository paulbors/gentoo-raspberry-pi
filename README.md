# gentoo-raspberry-pi

Collection of scripts that will compile the kernel and configure Gentoo on a Raspberry Pi based on https://wiki.gentoo.org/wiki/Raspberry_Pi4_64_Bit_Install

## Gentoo on Raspberry Pi

This repository has a collection of reusable scripts that will aid to compile from scratch Raspberry Pi's kernel and then create the bootable microSD card.

### Headless installs

Currently the script does not create the first Gentoo user that can ssh into the new Pi OS running off the microSD. As such you might need to use a USB adaptor to plug your microSD card into a live Pi env and chroot over to create the user and set its password (if I have time I'll fix that later, pull requests are welcomed).

## Instalation

1. Create Gentoo overlay \
   ```Copy /raspberrypi/gentoo_overlay.sh to your ~/, and execute it as root (look it over before you do).```
2. Install Gentoo and the Raspberry Pi \
   ```Copy /raspberrypi/pi_install.sh to your ~/raspberrypi/, and execute it as root (look it over before you do).```
