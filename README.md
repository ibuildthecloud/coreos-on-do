CoreOS on Digital Ocean
=======================

This is a script to setup CoreOS on Digital Ocean.  It works by using kexec to first load CoreOS into memory.  The script then repartitions the disk using the normal coreos raw image and additionally creates a new parition called DOROOT in which we install a small Ubuntu installation to bootstrap the kernel loading.  

On boot of the droplet the Digital Ocean supplied kernel will find the small Ubuntu installation which will immediately kexec into CoreOS and reload the environment with the CoreOS kernel and ramdisk.  After that it's all 100% CoreOS.

I've only tested this for a couple days, so YMMV.  I did at least test that the CoreOS updates work.

Installation
============

Start with a Ubuntu 14.04 x64 droplet.  I have tested 512mb on sfo1, nyc2, sgp1, lon1, and ams2 regions.  You must create your droplet **with an SSH key**.  The SSH key is important as it's how you're going to log into the CoreOS installation.  Once booted run

    wget https://raw.githubusercontent.com/ibuildthecloud/coreos-on-do/master/coreos-on-do.sh
    chmod +x coreos-on-do.sh
    ./coreos-on-do.sh

That will run a bunch of stuff and then reboot the droplet.  The last line you'll see is `Rebooting`.  After rebooting it will take a couple more minutes to install.  You can go to the Digital Ocean console and tail `/var/log/coreos-install.log` to see what's going on.  After the installation is done it will reboot itself a second time.  If all is swell you should be able to SSH into your newly installed CoreOS.  **Remember that you need to SSH in with the core user, not root.**

Usage
=====

```bash
coreos-on-do.sh -h

Usage: ./coreos-on-do.sh [-C channel] [-c cloud config] [-V version]
Options:
    -C CHANNEL       CoreOS release, either alpha, beta, or stable, default: alpha
    -c CLOUD_CONFIG  Path to cloud config or a http(s) URL
    -V VERSION       Version to install, default: current
```

All options can be set through environment variables too (CHANNEL, CLOUD_CONFIG, VERSION).

Cloud Config
============

The [CoreOS cloud config](http://coreos.com/docs/cluster-management/setup/cloudinit-cloud-config/) is the primary means of configuring the server.  If you use the `-c` option or `CLOUD_CONFIG` environment variable, the cloud config file will be installed at `/var/lib/coreos-install/user_data` after the install.  You can modify that file if you wish to change some of the bootstrap configuration after installation.

Automation
==========

If you have just deployed a brand new droplet, you can run a single command to automate the deployment of CoreOS through SSH.

    curl -sL https://raw.githubusercontent.com/ibuildthecloud/coreos-on-do/master/coreos-on-do.sh | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l root <IP> VERSION=current CHANNEL=alpha CLOUD_CONFIG=http://.../cloud-config.yml bash

All environment variables (VERSION, CHANNEL, CLOUD_CONFIG) are optional.  In order to supply a config config it must be a http URL.  The simplest thing to do is to just create a private gist.

Networking
==========

Digital Ocean uses static network configuration (no DHCP).  This script will copy the networking information from the original Ubuntu installation over to the CoreOS installation.  Private networking is supported, but IPv6 currently is not tested.

Troubleshooting
===============

kexec hangs on first reboot
---------------------------

In order to install CoreOS this script needs to run kexec.  Sometimes the first kexec will appear to hang.  The script will print `Rebooting` but from the web console you will just Ubuntu login and its hung.  If this happens, first wait 5 minutes or so.  Sometimes it just takes way too long and for some reason the web console is frozen.  If it still does nothing just power cycle the droplet and try again.  Eventually it should work.
