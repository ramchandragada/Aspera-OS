#!/bin/bash
# Runs inside the remaster chroot. Idempotent where possible.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "Aspera OS: customize chroot"

# Branding name only. Keep ID=linuxmint so apt, ubiquity, and mintupdate still work.
if [ -f /etc/os-release ]; then
	sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Aspera OS 1.0"/' /etc/os-release || true
fi
echo "Aspera OS 1.0 \\n \\l" > /etc/issue
echo "aspera-pc" > /etc/hostname

# Branding files
install -d /usr/share/backgrounds/aspera /usr/share/pixmaps /usr/share/icons
install -m 0644 /tmp/aspera-branding/aspera.png /usr/share/pixmaps/aspera.png
if [ -f /tmp/aspera-branding/aspera-mark.png ]; then
	install -m 0644 /tmp/aspera-branding/aspera-mark.png /usr/share/pixmaps/aspera-mark.png
else
	install -m 0644 /tmp/aspera-branding/aspera.png /usr/share/pixmaps/aspera-mark.png
fi
install -m 0644 /tmp/aspera-branding/aspera-avatar.png /usr/share/icons/aspera-avatar.png 2>/dev/null \
	|| install -m 0644 /tmp/aspera-branding/aspera.png /usr/share/icons/aspera-avatar.png
install -m 0644 /tmp/aspera-branding/aspera-default.png /usr/share/backgrounds/aspera/aspera-default.png 2>/dev/null \
	|| install -m 0644 /tmp/aspera-branding/aspera.png /usr/share/backgrounds/aspera/aspera-default.png

# Force IPv4 for apt on flaky networks
mkdir -p /etc/apt/apt.conf.d
printf 'Acquire::ForceIPv4 "true";\n' > /etc/apt/apt.conf.d/99aspera-force-ipv4

apt-get update -qq
echo "Upgrading all packages in the remaster (so the USB is current)..."
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

NEVER_PURGE='ubiquity|casper|lightdm|slick-greeter|xfce4|grub|shim|mokutil|os-prober|user-setup|mint-meta|live-boot|live-config'

# Purge Mint extras (never touch installer/boot stack)
if [ -f /tmp/aspera-lists/purge.list ]; then
	mapfile -t PURGE < <(grep -vE '^\s*(#|$)' /tmp/aspera-lists/purge.list | grep -vE "$NEVER_PURGE" || true)
	if [ "${#PURGE[@]}" -gt 0 ]; then
		apt-get -y purge "${PURGE[@]}" 2>/dev/null || true
		# Do not autoremove — it can pull ubiquity/casper off a remaster.
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

# PDF Sign Verifier belongs in Office
for f in /usr/share/applications/*sign* /usr/share/applications/*verifier*; do
	[ -f "$f" ] || continue
	if grep -qiE 'sign|verifier|pdf' "$f"; then
		if grep -q '^Categories=' "$f"; then
			sed -i 's/^Categories=.*/Categories=Office;Utility;/' "$f" || true
		else
			echo 'Categories=Office;Utility;' >> "$f"
		fi
	fi
done

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

# XFCE wallpaper, desktop icons, light theme (from remaster includes)
mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml \
	/etc/xdg/xfce4/xfconf/xfce-perchannel-xml
for cfg in xfce4-desktop.xml xfce4-panel.xml xsettings.xml xfwm4.xml; do
	if [ -f "/tmp/aspera-includes/$cfg" ]; then
		install -m 0644 "/tmp/aspera-includes/$cfg" \
			"/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/$cfg"
		install -m 0644 "/tmp/aspera-includes/$cfg" \
			"/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/$cfg"
	fi
done
# Replace any other shipped panel defaults so Mint's app-grid launcher cannot return
find /etc/xdg -name 'xfce4-panel.xml' -exec cp /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml {} \; 2>/dev/null || true
rm -f /etc/xdg/xfce4/panel/default.xml 2>/dev/null || true

# GUI session for live AND installed. Do NOT autologin as mint here —
# that file is copied onto the hard disk and then nobody can log in.
# Live USB autologin is casper (Mint already does this).
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-aspera-session.conf <<'EOF'
[Seat:*]
user-session=xfce
greeter-session=slick-greeter
EOF
rm -f /etc/lightdm/lightdm.conf.d/50-aspera-autologin.conf
cat > /etc/lightdm/slick-greeter.conf <<'EOF'
[Greeter]
background=/usr/share/backgrounds/aspera/aspera-default.png
theme-name=Mint-Y
icon-theme-name=Mint-Y
draw-user-backgrounds=false
EOF

# Live session identity (casper only; not the installed login)
cat > /etc/casper.conf <<'EOF'
export USERNAME="mint"
export USERFULLNAME="Aspera Live"
export HOST="aspera-pc"
export BUILD_SYSTEM="Ubuntu"
EOF

# After ubiquity copies the filesystem, drop live-only bits and keep GUI login
install -d /usr/lib/ubiquity/target-config
cat > /usr/lib/ubiquity/target-config/10aspera-installed-login <<'EOF'
#!/bin/sh
set -e
# Installed PC: the person created in the installer must be able to log in.
rm -f /target/etc/lightdm/lightdm.conf.d/50-aspera-autologin.conf
mkdir -p /target/etc/lightdm/lightdm.conf.d
cat > /target/etc/lightdm/lightdm.conf.d/50-aspera-session.conf <<CONF
[Seat:*]
user-session=xfce
greeter-session=slick-greeter
CONF
chroot /target systemctl set-default graphical.target >/dev/null 2>&1 || true
chroot /target systemctl enable lightdm.service >/dev/null 2>&1 || true
exit 0
EOF
chmod 0755 /usr/lib/ubiquity/target-config/10aspera-installed-login

systemctl set-default graphical.target 2>/dev/null || true
systemctl enable lightdm.service 2>/dev/null || true

# Faster login: drop leftover / non-essential autostart (keep NM, power, polkit, updates)
for f in \
	/etc/xdg/autostart/warpinator.desktop \
	/etc/xdg/autostart/xfce4-notes-autostart.desktop \
	/etc/xdg/autostart/sticky.desktop \
	/etc/xdg/autostart/mintreport.desktop \
	/etc/xdg/autostart/mintreport-tray.desktop \
	/etc/xdg/autostart/nvidia-prime-applet.desktop \
	/etc/xdg/autostart/vmware-user.desktop \
	/etc/xdg/autostart/onboard-autostart.desktop \
	/etc/xdg/autostart/orage-*.desktop \
	/etc/xdg/autostart/xfce4-clipman-plugin-autostart.desktop
do
	rm -f $f 2>/dev/null || true
done
# Hide if removal is blocked
for f in /etc/xdg/autostart/*.desktop; do
	[ -f "$f" ] || continue
	base=$(basename "$f" | tr '[:upper:]' '[:lower:]')
	case "$base" in
		*warpinator*|*notes*|*sticky*|*mintreport*|*vmware*|*onboard*|*prime*)
			echo 'Hidden=true' >> "$f" || true
			echo 'X-GNOME-Autostart-enabled=false' >> "$f" || true
			;;
	esac
done

# Hide Software Manager from casual use
for f in \
	/usr/share/applications/mintinstall.desktop \
	/usr/share/applications/ubuntu-software.desktop \
	/usr/share/applications/gnome-software.desktop
do
	if [ -f "$f" ]; then
		grep -q '^NoDisplay=true' "$f" || echo 'NoDisplay=true' >> "$f" || true
	fi
done

# Hide leftover menu entries even if the package name differed
for f in /usr/share/applications/*.desktop; do
	[ -f "$f" ] || continue
	base=$(basename "$f" | tr '[:upper:]' '[:lower:]')
	case "$base" in
		*thunderbird*|*transmission*|*hypnotix*|*celluloid*|*rhythmbox*|*webapp*|*matrix*|*element*|*nheko*|*fractal*|*warpinator*|*mintstick*|*usb-image*|*notes*|*libreoffice-base*|*libreoffice-math*|*firefox*)
			grep -q '^NoDisplay=true' "$f" || echo 'NoDisplay=true' >> "$f" || true
			;;
	esac
done

# Whisker menu: full Aspera wordmark, no "Menu" text
if [ -f /tmp/aspera-includes/whiskermenu-1.rc ]; then
	install -m 0644 /tmp/aspera-includes/whiskermenu-1.rc \
		/etc/skel/.config/xfce4/panel/whiskermenu-1.rc
fi

# Panel launchers (left): Chrome, Hub, TuxGenie, PDF Signer, Writer, Calc, SSR, AnyDesk
place_launcher() {
	local id="$1"
	local destname="$2"
	shift 2
	local src=""
	local g
	for g in "$@"; do
		src=$(ls /usr/share/applications/$g 2>/dev/null | head -n1 || true)
		[ -n "$src" ] && [ -f "$src" ] && break
	done
	if [ -z "$src" ] || [ ! -f "$src" ]; then
		echo "WARN: no desktop file for panel launcher $destname ($*)"
		return 0
	fi
	mkdir -p "/etc/skel/.config/xfce4/panel/launcher-${id}"
	rm -f "/etc/skel/.config/xfce4/panel/launcher-${id}/"*
	cp "$src" "/etc/skel/.config/xfce4/panel/launcher-${id}/${destname}"
}

place_launcher 2 chrome.desktop 'google-chrome*.desktop' 'google-chrome.desktop'
place_launcher 3 hub.desktop 'asperadock*.desktop' '*hub*.desktop'
place_launcher 4 tuxgenie.desktop 'tuxgenie*.desktop' '*tuxgenie*.desktop'
place_launcher 5 pdfsigner.desktop '*sign*verifier*.desktop' 'pdf-sign*.desktop' '*verifier*.desktop'
place_launcher 6 writer.desktop 'libreoffice-writer.desktop'
place_launcher 7 calc.desktop 'libreoffice-calc.desktop'
place_launcher 8 ssr.desktop 'simplescreenrecorder.desktop' '*simplescreen*.desktop'
place_launcher 9 anydesk.desktop 'anydesk*.desktop'

# Desktop shortcuts for staff apps
mkdir -p /etc/skel/Desktop
for app in google-chrome asperadock tuxgenie libreoffice-writer flameshot simplescreenrecorder vlc anydesk pdf-sign sign-verifier; do
	src=$(ls /usr/share/applications/${app}*.desktop 2>/dev/null | head -n1 || true)
	if [ -n "${src:-}" ] && [ -f "$src" ]; then
		cp "$src" /etc/skel/Desktop/ || true
	fi
done
chmod +x /etc/skel/Desktop/*.desktop 2>/dev/null || true

# Rebuild initramfs so an upgraded kernel inside the squashfs has modules
update-initramfs -u -k all 2>/dev/null || true


# Fail the remaster if the three basics are missing
for pkg in lightdm ubiquity; do
	if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed'; then
		echo "ERROR: required package missing after remaster: $pkg" >&2
		exit 1
	fi
done
if ! dpkg-query -W -f='${Status}' xfce4-session 2>/dev/null | grep -q 'install ok installed' \
	&& ! dpkg-query -W -f='${Status}' xfce4 2>/dev/null | grep -q 'install ok installed'; then
	echo "ERROR: XFCE session missing after remaster" >&2
	exit 1
fi

# Cleanup apt caches for smaller squashfs
apt-get clean
rm -rf /tmp/aspera-vendor /tmp/aspera-branding /tmp/aspera-lists /tmp/chroot-customize.sh
rm -rf /var/lib/apt/lists/*

echo "Aspera OS: chroot customization done"
