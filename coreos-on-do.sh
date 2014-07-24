#!/bin/bash
set -e

CHANNEL=${CHANNEL:-alpha}
VERSION=${VERSION:-current}

install_kexec()
{
    if which yum 2>/dev/null; then
        yum install -y kexec-tools
    elif which apt-get 2>/dev/null; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y kexec-tools
    fi
}

setup_dirs()
{
    if [ -e /var/tmp/coreos-install ]; then
        rm -rf /var/tmp/coreos-install
    fi
    mkdir -p /var/tmp/coreos-install

    cd /var/tmp/coreos-install
    mkdir -p usr/share/oem/bin
    mkdir -p usr/share/oem/files/{etc/systemd/network,home/core/.ssh,var/lib/coreos-install}
    FILES=$(readlink -f usr/share/oem/files)
}

copy_network()
{
    ip addr show | grep -E '^[0-9].*state UP|link/ether|inet .*scope global' | awk '{print $2}' | sed -n 'N;N;s/\n/ /g;p' | while read IFACE MAC IP; do
        GATEWAY=
        TARGET=${FILES}/etc/systemd/network/do-$MAC.network
        cat > $TARGET << EOF
[Match]
MACAddress=$MAC

[Network]
Address=$IP
EOF

        if ip route show | grep ^default | grep -q ${IFACE/:/}; then
            GATEWAY=$(route | grep default | awk '{print $2}')
            cat >> $TARGET << EOF
Gateway=$GATEWAY
EOF
        fi

        for ns in $(grep '^nameserver' /etc/resolv.conf | awk '{print $2}' | sort -u); do
            cat >> $TARGET << EOF
DNS=$ns
EOF
        done

        if [ -z "$GATEWAY" ]; then
            echo "COREOS_PRIVATE_IPV4=${IP/\/*/}" >> ${FILES}/etc/environment
        else
            echo "COREOS_PUBLIC_IPV4=${IP/\/*/}" >> ${FILES}/etc/environment
        fi
    done

    hostname > ${FILES}/etc/hostname
}

copy_ssh()
{
    cp -p /root/.ssh/authorized_keys ${FILES}/home/core/.ssh/authorized_keys
    chmod 600 ${FILES}/home/core/.ssh/authorized_keys
}

copy_cloud_config()
{
    TARGET=${FILES}/var/lib/coreos-install/user_data
    if [[ "$CLOUD_CONFIG" =~ http.* ]]; then
        curl $CLOUD_CONFIG > ${TARGET}
    elif [ -e "$CLOUD_CONFIG" ]; then
        cp $CLOUD_CONFIG $TARGET
    fi
}

copy_script()
{
    (
        cd /
        for i in $(lsmod | awk '{print $1}' | sort -u; echo vfat nls_iso8859-1); do
            find lib/modules/$(uname -r) -name $i.ko
        done
        ls -1 lib/modules/$(uname -r)/modules* >> ${FILES}/../modules
    ) > $FILES/../modules
    cat > $FILES/../bin/coreos-do-install << "EOF"
#!/bin/bash
set -e
set -x

exec > /var/log/coreos-install.log 2>&1

rsync -av /usr/share/oem/files/ .
systemctl restart systemd-networkd

while ! blkid -L DOROOT; do
    sleep 1
done

mount LABEL=DOROOT /mnt
tar cvzf /var/tmp/modules.tar.gz -C /mnt $(</usr/share/oem/modules)
umount /mnt

echo "Writing image to disk"
curl -s --retry 5 --retry-delay 2 http://%CHANNEL%.release.core-os.net/amd64-usr/%VERSION%/coreos_production_image.bin.bz2 | bzip2 -dc | dd of=/dev/vda bs=1M

blockdev --rereadpt /dev/vda

cgpt repair /dev/vda
parted -s -- /dev/vda mkpart DOROOT ext4 -500M -0
ID=$(parted -sm /dev/vda p | grep DOROOT | cut -f1 -d:)
mkfs.ext4 -L DOROOT /dev/vda${ID}

mount LABEL=ROOT /mnt
rsync -av /usr/share/oem/files/ /mnt
chown -R $(grep ^core: /mnt/etc/passwd | cut -f3,4 -d:) /mnt/home/core
umount /mnt


mount LABEL=DOROOT /mnt
curl -s http://cdimage.ubuntu.com/ubuntu-core/releases/14.04/release/ubuntu-core-14.04-core-amd64.tar.gz | tar xvzf - -C /mnt
mkdir -p /mnt/lib/modules
tar xvzf /var/tmp/modules.tar.gz -C /mnt
cp /etc/resolv.conf /mnt/etc/resolv.conf

export DEBIAN_FRONTEND=noninteractive
chroot /mnt apt-get update
chroot /mnt apt-get install -y kexec-tools

if [ ! -e /mnt/sbin/init.real ]; then
    mv /mnt/sbin/init{,.real}
fi

cat > /mnt/sbin/init << "EOF2"
#!/bin/bash

if [ ! -e /boot/syslinux/vmlinuz-boot_kernel ]; then
    mount -o ro LABEL=EFI-SYSTEM /boot
fi

KERNEL=$(grep '^[[:space:]]*kernel' /boot/syslinux/boot_kernel.cfg | awk '{print $2}')
APPEND=$(grep '^[[:space:]]*append' /boot/syslinux/boot_kernel.cfg | sed 's/^[[:space:]]*append //g')

kexec -l /boot/syslinux/$KERNEL --append="$APPEND"
kexec -e

# In case something goes wrong, we drop to a shell, normally kexec would reboot the system
bash
EOF2

chmod +x /mnt/sbin/init
umount /mnt

reboot -f
EOF

    sed -i -e 's/%CHANNEL%/'$CHANNEL'/g' -e 's/%VERSION%/'$VERSION'/g' $FILES/../bin/coreos-do-install

    cat > ${FILES}/../coreos-do-install.service << EOF
EOF

    cat > ${FILES}/../bin/coreos-setup-environment << EOF
#!/bin/bash

mkdir -p /var/lib/coreos-install
cat > /var/lib/coreos-install/user_data << EOF2
#cloud-config
coreos:
    units:
      - name: coreos-install.service
        command: start
        content: |
          [Unit]
          Description=Installs CoreOS

          [Service]
          Type=oneshot
          RemainAfterExit=yes
          ExecStart=/usr/share/oem/bin/coreos-do-install
          TimeoutStartSec=600

          [Install]
          WantedBy=multi-user.target
EOF2
EOF

    chmod +x $FILES/../bin/coreos-do-install
    chmod +x $FILES/../bin/coreos-setup-environment
}

do_kexec()
{
    wget http://alpha.release.core-os.net/amd64-usr/current/coreos_production_pxe.vmlinuz -O kernel
    wget http://alpha.release.core-os.net/amd64-usr/current/coreos_production_pxe_image.cpio.gz -O initrd.cpio.gz

    gunzip initrd.cpio.gz
    find usr | cpio -o -A -H newc -O initrd.cpio
    gzip initrd.cpio

    kexec -l kernel --initrd initrd.cpio.gz --append='coreos.autologin=tty1'
    echo "Rebooting"
    bash -c "sleep 2; kexec -e" >/dev/null 2>&1 &
}

USAGE="Usage: $0 [-C channel] [-c cloud config] [-V version]
Options:
    -C CHANNEL       CoreOS release, either alpha, beta, or stable, default: alpha
    -c CLOUD_CONFIG  Path to cloud config or a http(s) URL
    -V VERSION       Version to install, default: current
"

while [ "$#" -gt 0 ]; do
    case $1 in
        -V)
            shift 1
            VERSION=$1
            ;;
        -c)
            shift 1
            CLOUD_CONFIG=$1
            ;;
        -C)
            shift 1
            CHANNEL=$1
            ;;
        --help)
            echo "$USAGE"
            exit 0
            ;;
        -h)
            echo "$USAGE"
            exit 0
            ;;
    esac
    shift 1
done

if ! echo $CHANNEL | grep -qE 'alpha|beta|stable'; then
    echo 'Channel must be alpha, beta, or stable'
    exit 1
fi

install_kexec
setup_dirs
copy_script
copy_network
copy_ssh
copy_cloud_config

if [ -e /etc/lsb_release ]; then
    source /etc/lsb_release
fi

if [ "$DISTRIB_ID" != CoreOS ]; then
    do_kexec
fi
