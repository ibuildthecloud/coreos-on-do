CoreOS on Digital Ocean
=======================

This is a script to setup CoreOS on Digital Ocean.  It works by using kexec to
first load CoreOS into memory.  The script then repartitions the disk using the
normal coreos raw image and additionally creates a new parition called DOROOT
in which we install a small Ubuntu installation to bootstrap the kernel loading.

On boot of the droplet the Digital Ocean supplied kernel will find the small
Ubuntu installation which will immediately kexec into CoreOS and reload the
environment with the CoreOS kernel and ramdisk.  After that it's all 100%
CoreOS.

I've only tested this for a couple days, so YMMV.  I did at least test that the
CoreOS updates work.

Installation
============

Start with a Debian 7.0 x64 if you're in sfo1 or Ubuntu 14.04 x64 if you're in nyc2.
I haven't tested other regions.  You must create your droplet **with an SSH key**.
The SSH key is important as it's how you're going to log into the CoreOS installation.
Once booted run

    wget https://raw.githubusercontent.com/ibuildthecloud/coreos-on-do/master/coreos-on-do.sh
    chmod +x coreos-on-do.sh
    ./coreos-on-do.sh -c cloud-config.yml -C alpha

The cloud-config file and the channel are optional.  If you don't supply a
channel, the default is alpha.

That will run a bunch of stuff and then reboot the droplet.  The last line
you'll see is `kexec -e`.  After rebooting it will take a couple more minutes to
install.  You can go to the Digital Ocean console and tail
`/var/log/coreos-install.log` to see what's going on.  After the installation is
done it will reboot itself a second time.  If all is swell you should
be able to SSH into your newly installed CoreOS.  **Remember that you need to SSH
in with the core user, not root.**


Automating
==========

If you have just deployed a brand new droplet, you can run a single command to
automate the deployment of CoreOS through SSH.

    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l root <IP> bash -c "curl -sL https://raw.githubusercontent.com/ibuildthecloud/coreos-on-do/master/coreos-on-do.sh | CHANNEL=alpha CLOUD_CONFIG=http://.../cloud-config.yml bash"

In order to supply a config config it must be a http URL.  The simplest thing 
to do is to just create a private gist.
