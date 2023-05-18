# rocky-live-kde.ks
# BROKEN

%include rocky-live-base-spin.ks
%include rocky-live-mate-common.ks

part / --size 8192

%post
# mate configuration

cat >> /etc/rc.d/init.d/livesys << EOF
# make the installer show up
if [ -f /usr/share/applications/liveinst.desktop  ]; then
  # Show harddisk install in shell dash
  sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop ""
fi
mkdir /home/liveuser/Desktop
cp /usr/share/applications/liveinst.desktop /home/liveuser/Desktop
chmod +x /home/liveuser/Desktop/liveinst.desktop

# move to anaconda - probably not required for MATE.
mv /usr/share/applications/liveinst.desktop /usr/share/applications/anaconda.desktop

if [ -f /usr/share/anaconda/gnome/fedora-welcome.desktop  ]; then
  mkdir -p ~liveuser/.config/autostart
  cp /usr/share/anaconda/gnome/fedora-welcome.desktop /usr/share/applications/
  cp /usr/share/anaconda/gnome/fedora-welcome.desktop ~liveuser/.config/autostart/
fi

# rebuild schema cache with any overrides we installed
glib-compile-schemas /usr/share/glib-2.0/schemas

# set up lightdm autologin
sed -i 's/^#autologin-user=.*/autologin-user=liveuser/' /etc/lightdm/lightdm.conf
sed -i 's/^#autologin-user-timeout=.*/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
sed -i 's/^#show-language-selector=.*/show-language-selector=true/' /etc/lightdm/lightdm-gtk-greeter.conf

# set MATE as default session, otherwise login will fail
sed -i 's/^#user-session=.*/user-session=mate/' /etc/lightdm/lightdm.conf

# Turn off PackageKit-command-not-found while uninstalled
if [ -f /etc/PackageKit/CommandNotFound.conf  ]; then
  sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf
fi

# The updater applet might or might not exist
rm -f /etc/xdg/autostart/org.mageia.dnfdragora-updater.desktop

# reset selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/
restorecon -R /

EOF

# this doesn't come up automatically. not sure why.
systemctl enable --force lightdm.service

# CRB needs to be enabled for EPEL to function.
dnf config-manager --set-enabled powertools

%end
