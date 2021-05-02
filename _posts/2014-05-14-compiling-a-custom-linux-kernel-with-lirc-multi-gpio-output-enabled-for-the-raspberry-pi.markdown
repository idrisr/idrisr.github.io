---
layout: post
title: "LIRC multi-GPIO output for the Raspberry Pi"
date: 2014-05-29 16:44
comments: true
published: true
---

LIRC gives your Raspberry Pi infrared superpowers, but the current included version (as of rpi-3.12.y) does not allow for controlling multiple IR LEDs simultaneuously. Bengt Martensson updated the source to make this possible, but you probably have to recompile the kernel and modules and install them on to your Rasperry Pi. This took me a while to figure out, so I thought I'd document the steps here.

I compiled these instructions from the following sources:

* [Alex Bain's](http://alexba.in/blog/2013/06/08/open-source-universal-remote-parts-and-pictures/) instructions and wiring diagrams for creating a universal remote with a Raspberry Pi.
* [ELinux Guide](http://elinux.org/RPi_Kernel_Compilation) to cross-compiling the the Linux kernel for the Raspberry Pi
* [Aron Szabo's](http://aron.ws/projects/lirc_rpi/) work on porting LIRC to the Raspberry Pi
* [Bengt Martensson's](http://harctoolbox.org/lirc_rpi.html) work on creating multiple GPIO outputs for LIRC on the Raspberry Pi

You want to do this on a different machine than your Raspberry Pi. This process will take half a day on a rasppi, much less time if on a more powerful machine. If you have a spare, fast linux machine running, use that. If not, I suggest using [Vagrant](http://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) to create a virtual Ubuntu box. This is pretty easy, and look [here](http://docs.vagrantup.com/v2/getting-started/index.html) for more information. You can do this on any host operating system.



______

## 1. Clone the Raspberry Pi linux kernel

```
git clone --depth 1 https://github.com/raspberrypi/linux
```

______

## 2. Change the 2 files needed so LIRC supports multiple GPIO outputs

Add these lines in ```linux/drivers/staging/media/lirc/Kconfig```

{% highlight sh %}
config LIRC_RPI
	tristate "Homebrew GPIO Port Receiver/Transmitter for the RaspberryPi"
	depends on LIRC
	help
	  Driver for Homebrew GPIO Port Receiver/Transmitter for the RaspberryPi
{% endhighlight %}


And add these lines to ```linux/drivers/staging/media/lirc/Makefile```

{% highlight sh %}
    obj-$(CONFIG_LIRC_RPI)		+= lirc_rpi.o
{% endhighlight %}

______

## 3. Download lirc_rpi.c

Download the file ```lirc_rpi.c``` from Bengt Mårtensson [here](http://harctoolbox.org/lirc_rpi.html)
and put it in the folder ```linux/drivers/staging/media/lirc```

```
wget http://harctoolbox.org/downloads/lirc_rpi.c
```

___

## 4. Set an environment variable KERNEL_SRC to point to the location of the source

If you cloned the repository in step 1 to your ```~```, then use the following. Otherwise adjust the path accordingly.

```
export KERNEL_SRC=$HOME/linux/
```

___

## 5. Get the latest raspberrypi compiler 

```
git clone --depth 1 https://github.com/raspberrypi/tools
```

___

## 6. Set an environment variable CCPREFIX to point to the location of tools

```
export CCPREFIX=$HOME/tools/arm-bcm2708/arm-bcm2708-linux-gnueabi/bin/arm-bcm2708-linux-gnueabi-
```

___

## 7. From the kernel clone location, clean the kernel source with 

```
make mrproper
```

___

## 8. Pull the /proc/config.gz from the running Raspbian installation

Do this form the Raspberry Pi. I assume you are running a Debian flavor OS on your Raspberry Pi.

```
zcat /proc/config.gz > .config
```

___


## 9. Prime kernel with the old config

You need to have the ```.config``` file in the folder from step 1 and then run 

```
ARCH=arm CROSS_COMPILE=${CCPREFIX} make oldconfig
```

If you are asked a bunch of questions, press enter and accept all of the default values.

___

## 10. Build the new kernel 

This will take about an hour, depending on the speed of your processor. This will take 12 hours if you do it on the Raspberry Pi.

```
ARCH=arm CROSS_COMPILE=${CCPREFIX} make -j4 all
```

___

## 11. Set an environment variable MODULES_TEMP to point to the location of the source 

```
export MODULES_TEMP=$HOME/modules
```

___

## 12. Set aside the new kernel modules by using 

From the directory in step 1, run:

```
ARCH=arm CROSS_COMPILE=${CCPREFIX} INSTALL_MOD_PATH=${MODULES_TEMP} make modules_install
```

___

## 13. Create the kernel image

From the `tools/mkimage` clone location in step 5 run:

```
./imagetool-uncompressed.py ${KERNEL_SRC}/arch/arm/boot/zImage
```

___

## 14. Move kernel.img to the Raspberry Pi's /boot/ directory

There now should be a file `kernel.img` in the same directory from the previous step.

Copy the file ```kernel.img``` somehow (USB, scp, Dropbox, whatever) to the ```/boot``` dir on the Raspberry Pi

___


##  15. Package up the modules into an archive 

Move into the `~/modules` directory and package up the `lib` dir.

```
cd $MODULES_TEMP
tar cvzpf lib.tgz lib/
```

Now move the file ```lib.tgz``` to your Raspberry Pi.


___

## 16. Move the modules archive to the Raspberry Pi 

Now back to the Raspberry Pi. Find `lib.tgz` from the previous step and:

``` 
tar xvzpf lib.tgz
sudo cp -r lib/firmware lib/modules /lib/
```

___

## 17. Get the latest raspberrypi firmware 

Do this on the Raspberry Pi.

```
git clone --depth 1 git://github.com/raspberrypi/firmware.git
```
___


## 18. Transfer more files to /boot

Transfer the following files from the firmware/boot directory from the above step to the Raspberry Pi /boot directory:

```
sudo cp firmware/boot/bootcode.bin firmware/boot/fixup.dat firmware/boot/start.elf /boot
```

___

## 19. Transfer the firmware/hardfp/opt directory 

```
sudo cp -r firmware/hardfp/opt /opt 
```

___

## 20. Update /etc/modules

add the following lines to `/etc/modules`

```
lirc_dec
lirc_rpi gpio_in_pin=18 gpio_out_pins=17,22
```

___

## 21. Reboot the Raspberry Pi

```
sudo reboot
```

## 22. install lirc

```
sudo apt-get install lirc
```


## 23. Check that the right lirc module is installed

If all went correctly, you should see something similar after running `modinfo lirc_rpi`

You should see something similar to the following. You should see a mention of `gpio_out_pins`, instead of just `gpio_out_pin`.

{% highlight sh %}
filename:       /lib/modules/3.12.20+/kernel/drivers/staging/media/lirc/lirc_rpi.ko
license:        GPL
author:         Bengt Martensson <barf@bengt-martensson.de>
author:         Michael Bishop <cleverca22@gmail.com>
author:         Aron Robert Szabo <aron@reon.hu>
description:    Infra-red receiver and blaster driver for Raspberry Pi GPIO.
srcversion:     BF8F27ED526BB6E89060F06
depends:        lirc_dev
staging:        Y
intree:         Y
vermagic:       3.12.20+ preempt mod_unload modversions ARMv6
parm:           gpio_out_pins:GPIO output/transmitter pins of the BCM processor as array. The first is called transmitter #1 (not 0). Valid pin numbers are: 0, 1, 4, 8, 7, 9, 10, 11, 14, 15, 17, 18, 21, 22, 23, 24, 25. Default is none (array of int)
parm:           gpio_in_pin:GPIO input pin number of the BCM processor. Valid pin numbers are: 0, 1, 4, 8, 7, 9, 10, 11, 14, 15, 17, 18, 21, 22, 23, 24, 25. Default is none (int)
parm:           sense:Override autodetection of IR receiver circuit (0 = active high, 1 = active low ) (bool)
parm:           softcarrier:Software carrier (0 = off, 1 = on, default on) (bool)
parm:           invert:Invert output (0 = off, 1 = on, default off) (bool)
parm:           tx_mask:Transmitter mask (default: 0x01) (int)
parm:           debug:Enable debugging messages (bool)
{% endhighlight %}


