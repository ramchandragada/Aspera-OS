#!/bin/bash
# Runs inside the remaster chroot. Idempotent where possible.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "Aspera OS: customize chroot"

# Identity
cat > /etc/os-release <<'EOF'
PRETTY_NAME="Aspera OS 1.0"
NAME="Aspera OS"
VERSION_ID="1.0"
VERSION="1.0 (Mint XFCE)"
VERSION_CODENAME=aspera
ID=aspera
ID_LIKE="ubuntu debian"
HOME_URL="https://github.com/ramchandragada/Aspera-OS"
EOF
echo "aspera-pc" > /etc/hostname

# Branding files
install -d /usr/share/backgrounds/aspera /usr/share/pixmaps /usr/share/icons
install -m 0644 /tmp/aspera-branding/aspera.png /usr/share/pixmaps/aspera.png
install -m 0644 /tmp/aspera-branding/aspera-avatar.png /usr/share/icons/aspera-avatar.png 2>/dev/null \
	|| install -m 0644 /tmp/aspera-branding/aspera.png /usr/share/icons/aspera-avatar.png
install -m 0644 /tmp/aspera-branding/aspera-default.png /usr/share/backgrounds/aspera/aspera-default.png 2>/dev/null \
	|| install -m 0644 /tmp/aspera-branding/aspera.png /usr/share/backgrounds/aspera/aspera-default.png

# Force IPv4 for apt on flaky networks
mkdir -p /etc/apt/apt.conf.d
printf 'Acquire::ForceIPv4 "true";\n' > /etc/apt/apt.conf.d/99aspera-force-ipv4

apt-get update -qq

# Purge Mint extras
if [ -f /tmp/aspera-lists/purge.list ]; then
	mapfile -t PURGE < <(grep -vE '^\s*(#|$)' /tmp/aspera-lists/purge.list || true)
	if [ "${#PURGE[@]}" -gt 0 ]; then
		apt-get -y purge "${PURGE[@]}" 2>/dev/null || true
		apt-get -y autoremove --purge 2>/dev/null || true
	fi
fi

# Install apt apps
if [ -f /tmp/aspera-lists/install.list ]; then
	mapfile -t INST < <(grep -vE '^\s*(#|$)' /tmp/aspera-lists/install.list || true)
	if [ "${#INST[@]}" -gt 0 ]; then
		apt-get -y install "${INST[@]}"
	fi
fi

# Vendor debs
shopt -s nullglob
for deb in /tmp/aspera-vendor/*.deb; do
	echo "Installing $(basename "$deb")"
	apt-get -y install "$deb" || dpkg -i "$deb" || true
	apt-get -y -f install || true
done
shopt -u nullglob

# zram
if [ -f /etc/default/zramswap ]; then
	sed -i 's/^#\?PERCENT=.*/PERCENT=50/' /etc/default/zramswap || true
	sed -i 's/^#\?ALGO=.*/ALGO=zstd/' /etc/default/zramswap || true
fi
systemctl enable zramswap.service 2>/dev/null || true

# Default browser Chrome
if command -v update-alternatives >/dev/null && [ -x /usr/bin/google-chrome-stable ]; then
	update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/google-chrome-stable 200 || true
	update-alternatives --set x-www-browser /usr/bin/google-chrome-stable || true
fi

# AnyDesk: installed but do not autostart for all users
systemctl disable anydesk.service 2>/dev/null || true
rm -f /etc/xdg/autostart/anydesk*.desktop 2>/dev/null || true

# Flameshot as screenshot tool
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/flameshot.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Flameshot
Exec=flameshot
Icon=flameshot
Comment=Screenshot tool
X-GNOME-Autostart-enabled=true
EOF

# XFCE wallpaper for new users
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/aspera/aspera-default.png"/>
        </property>
      </property>
      <property name="monitorVbox0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/aspera/aspera-default.png"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

# slick-greeter + always boot to GUI (live and installed)
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-aspera-autologin.conf <<'EOF'
[Seat:*]
autologin-user=mint
autologin-user-timeout=0
user-session=xfce
greeter-session=slick-greeter
EOF
cat > /etc/lightdm/slick-greeter.conf <<'EOF'
[Greeter]
background=/usr/share/backgrounds/aspera/aspera-default.png
theme-name=Mint-Y-Dark-Blue
icon-theme-name=Mint-Y-Dark-Blue
draw-user-backgrounds=false
EOF
# Live session identity (casper uses this on USB boot)
cat > /etc/casper.conf <<'EOF'
export USERNAME="mint"
export USERFULLNAME="Aspera Live"
export HOST="aspera-pc"
export BUILD_SYSTEM="Ubuntu"
EOF
# Graphical boot is the only face of the OS
systemctl set-default graphical.target 2>/dev/null || true
systemctl enable lightdm.service 2>/dev/null || true
# No first-boot quizzes / welcome noise
rm -f /etc/xdg/autostart/mintwelcome.desktop 2>/dev/null || true
rm -f /etc/xdg/autostart/mintupdate.desktop 2>/dev/null || true
mkdir -p /etc/skel/.config/autostart
echo "Hidden=true" >> /etc/xdg/autostart/mintwelcome.desktop 2>/dev/null || true

# Hide Software Manager from casual use (keep package for mintupdate deps if needed)
for f in \
	/usr/share/applications/mintinstall.desktop \
	/usr/share/applications/ubuntu-software.desktop \
	/usr/share/applications/gnome-software.desktop
do
	if [ -f "$f" ]; then
		echo 'NoDisplay=true' >> "$f" || true
	fi
done

# Desktop shortcuts for staff apps
mkdir -p /etc/skel/Desktop
for app in google-chrome asperadock tuxgenie libreoffice-writer flameshot simplescreenrecorder vlc anydesk; do
	src=$(ls /usr/share/applications/${app}*.desktop 2>/dev/null | head -n1 || true)
	if [ -n "${src:-}" ] && [ -f "$src" ]; then
		cp "$src" /etc/skel/Desktop/ || true
	fi
done
chmod +x /etc/skel/Desktop/*.desktop 2>/dev/null || true

# Cleanup apt caches for smaller squashfs
apt-get clean
rm -rf /tmp/aspera-vendor /tmp/aspera-branding /tmp/aspera-lists /tmp/chroot-customize.sh
rm -rf /var/lib/apt/lists/*

echo "Aspera OS: chroot customization done"
