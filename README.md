CoreOS on Digital Ocean
=======================

This is a script to setup CoreOS on Digital Ocean.  It works by using kexec to
first load CoreOS into memory.  Then the script repartitions the disk using the
normal coreos-install script for local disk installation.  Then a new partition
called DOROOT is created and we install a small Ubuntu installation.

On boot of the droplet the Digital Ocean supplied kernel will find the small
Ubuntu installation which will immediately kexec into CoreOS and reload the
environment with the CoreOS kernel and ramdisk.  After that it's all 100%
CoreOS.

I haven't tested this fully, it seems like CoreOS auto-update will work, but I
haven't had enough time to try it out.

Installation
============

Start with a Debian 7.0 x64 if you're in sfo1 or Ubuntu 14.04 x64 if you're in nyc2.
I haven't tested other regions.  You must create your droplet **with an SSH key**.
The SSH key is important as it's how you're going to log into the CoreOS installation.
Once booted run

    wget https://raw.githubusercontent.com/ibuildthecloud/coreos-on-do/master/coreos-on-do.sh
    sudo bash coreos-on-do.sh

That will run a bunch of stuff and then reboot the droplet.  The last line
you'll see is `kexec -e`.  Now go to the Digital Ocean console for your
droplet.  Run the following on the web console.

    sudo mount LABEL=DOROOT /mnt
    sudo /mnt/root/stage2.sh

That will do a bunch of stuff and reboot.  For some reason the networkd config
doesn't seem to take effect on the first boot.  So now go to the Digital Ocean
console and do a power cycle on your droplet.  If all is swell you should be
able to SSH into your newly installed CoreOS.  Remember that you need to SSH
in with the core user, not root.

After the installation you can change `/var/lib/coreos-install/user_data` with
whatever settings you want and reboot.
