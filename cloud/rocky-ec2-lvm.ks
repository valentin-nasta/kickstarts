%include rocky-cloud-base.ks
%include rocky-cloud-parts-lvm.ks
%include rocky-cloud-base-packages.ks

bootloader --append="console=ttyS0,115200n8 no_timer_check crashkernel=auto net.ifnames=0 nvme_core.io_timeout=4294967295 nvme_core.max_retries=10" --location=mbr --timeout=1

%post --erroronfail
passwd -d root
passwd -l root

# Attempting to force legacy BIOS boot if we boot from UEFI
# This was backported from our 9 kickstarts to address some issues.
if [ "$(arch)" = "x86_64" ]; then
  dnf install grub2-pc-modules grub2-pc -y
  grub2-install --target=i386-pc /dev/vda
  grub2-mkconfig -o /boot/grub2/grub.cfg --no-grubenv-update
fi

# Ensure that the pmbr_boot flag is off
parted /dev/vda disk_set pmbr_boot off

# setup systemd to boot to the right runlevel
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
echo .

dnf -C -y remove linux-firmware

# Remove firewalld; it is required to be present for install/image building.
# but we dont ship it in cloud
dnf -C -y remove firewalld --setopt="clean_requirements_on_remove=1"
dnf -C -y remove avahi\* 
sed -i '/^#NAutoVTs=.*/ a\
NAutoVTs=0' /etc/systemd/logind.conf

cat > /etc/sysconfig/network << EOF
NETWORKING=yes
NOZEROCONF=yes
EOF

# For cloud images, 'eth0' _is_ the predictable device name, since
# we don't want to be tied to specific virtual (!) hardware
rm -f /etc/udev/rules.d/70*
ln -s /dev/null /etc/udev/rules.d/80-net-name-slot.rules

# simple eth0 config, again not hard-coded to the build hardware
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="dhcp"
ONBOOT="yes"
TYPE="Ethernet"
USERCTL="yes"
PEERDNS="yes"
IPV6INIT="no"
PERSISTENT_DHCLIENT="1"
EOF

echo "virtual-guest" > /etc/tuned/active_profile

# generic localhost names
cat > /etc/hosts << EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

EOF
echo .

systemctl mask tmp.mount

cat <<EOL > /etc/sysconfig/kernel
# UPDATEDEFAULT specifies if new-kernel-pkg should make
# new kernels the default
UPDATEDEFAULT=yes

# DEFAULTKERNEL specifies the default kernel package type
DEFAULTKERNEL=kernel
EOL

# make sure firstboot doesn't start
echo "RUN_FIRSTBOOT=NO" > /etc/sysconfig/firstboot

# rocky cloud user
sed -i '1i # Modified for cloud image' /etc/cloud/cloud.cfg
echo -e 'rocky\tALL=(ALL)\tNOPASSWD: ALL' >> /etc/sudoers
sed -i 's/name: cloud-user/name: rocky/g' /etc/cloud/cloud.cfg

dnf clean all

# XXX instance type markers - MUST match Rocky Infra expectation
echo 'ec2' > /etc/yum/vars/infra

# change dhcp client retry/timeouts to resolve #6866
cat  >> /etc/dhcp/dhclient.conf << EOF

timeout 300;
retry 60;
EOF


rm -rf /var/log/yum.log
rm -rf /var/lib/yum/*
rm -rf /root/install.log
rm -rf /root/install.log.syslog
rm -rf /root/anaconda-ks.cfg
rm -rf /var/log/anaconda*

rm -f /var/lib/systemd/random-seed

cat /dev/null > /etc/machine-id

echo "Fixing SELinux contexts."
touch /var/log/cron
touch /var/log/boot.log
mkdir -p /var/cache/yum
/usr/sbin/fixfiles -R -a restore

# remove these for ec2 debugging
sed -i -e 's/ rhgb quiet//' /boot/grub/grub.conf

cat > /etc/modprobe.d/blacklist-nouveau.conf << EOL
blacklist nouveau
EOL

# enable resizing on copied AMIs
echo 'install_items+=" sgdisk "' > /etc/dracut.conf.d/sgdisk.conf

echo 'add_drivers+=" xen-netfront xen-blkfront "' > /etc/dracut.conf.d/xen.conf
# Rerun dracut for the installed kernel (not the running kernel):
KERNEL_VERSION=$(rpm -q kernel --qf '%{V}-%{R}.%{arch}\n')
dracut -f /boot/initramfs-$KERNEL_VERSION.img $KERNEL_VERSION


# reorder console entries
sed -i 's/console=tty0/console=tty0 console=ttyS0,115200n8/' /boot/grub2/grub.cfg

true

%end
