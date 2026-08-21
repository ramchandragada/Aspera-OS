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
# Also win Mint's "default wallpaper" slot so Appearance cannot snap back
if [ -d /usr/share/backgrounds/linuxmint ]; then
	install -m 0644 /usr/share/backgrounds/aspera/aspera-default.png \
		/usr/share/backgrounds/linuxmint/default_background.jpg 2>/dev/null || true
fi

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

# Prefer RAM over early SSD swap (good on 8 GB desks). Do not install preload.
printf 'vm.swappiness=%s\n' "${ASPERA_SWAPPINESS:-20}" > /etc/sysctl.d/99-aspera-swappiness.conf
# Drop preload if a meta-package pulled it in (uses RAM to "speed" launches).
apt-get -y purge preload 2>/dev/null || true
rm -f /etc/xdg/autostart/preload*.desktop 2>/dev/null || true

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
cursor-theme-name=Bibata-Modern-Classic
draw-user-backgrounds=false
EOF

# Mint XFCE default light look (Appearance): never ship Dark variants as default
for f in \
	/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
	/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
do
	[ -f "$f" ] || continue
	sed -i 's/Mint-Y-Dark/Mint-Y/g; s/Mint-X-Dark/Mint-X/g' "$f" || true
done
for f in \
	/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml \
	/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
do
	[ -f "$f" ] || continue
	sed -i 's/Mint-Y-Dark/Mint-Y/g' "$f" || true
done
# Panel must stay light
find /etc/skel /etc/xdg -name 'xfce4-panel.xml' -print0 2>/dev/null \
	| xargs -0 -r sed -i 's/name="dark-mode" type="bool" value="true"/name="dark-mode" type="bool" value="false"/g' \
	|| true

# Ubuntu fonts are Mint XFCE default; keep them available
apt-get -y install fonts-ubuntu 2>/dev/null || true

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
	/etc/xdg/autostart/mintwelcome.desktop \
	/etc/xdg/autostart/mintwelcome*.desktop \
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
		*warpinator*|*notes*|*sticky*|*mintreport*|*mintwelcome*|*vmware*|*onboard*|*prime*|*flatpak*)
			echo 'Hidden=true' >> "$f" || true
			echo 'X-GNOME-Autostart-enabled=false' >> "$f" || true
			;;
	esac
done

# Do NOT disable cups or bluetooth system-wide — desks print; laptops use BT.
# Blueberry GUI is purged; printer stack (cups) and NetworkManager stay.

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
		*thunderbird*|*transmission*|*hypnotix*|*celluloid*|*rhythmbox*|*webapp*|*matrix*|*element*|*nheko*|*fractal*|*warpinator*|*mintstick*|*usb-image*|*notes*|*libreoffice-base*|*libreoffice-impress*|*libreoffice-math*|*firefox*|*vlc*|*screenshooter*)
			grep -q '^NoDisplay=true' "$f" || echo 'NoDisplay=true' >> "$f" || true
			;;
	esac
done

# Whisker menu: full Aspera wordmark, no "Menu" text
mkdir -p /etc/skel/.config/xfce4/panel
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
for app in google-chrome asperadock tuxgenie libreoffice-writer libreoffice-calc flameshot simplescreenrecorder anydesk pdf-sign sign-verifier; do
	src=$(ls /usr/share/applications/${app}*.desktop 2>/dev/null | head -n1 || true)
	if [ -n "${src:-}" ] && [ -f "$src" ]; then
		cp "$src" /etc/skel/Desktop/ || true
	fi
done
chmod +x /etc/skel/Desktop/*.desktop 2>/dev/null || true

# Live USB boots as user "mint" with a pre-seeded /home/mint from the Mint
# squashfs. /etc/skel only affects new accounts (installer), not the live desk.
apply_aspera_xfce_profile() {
	local home="$1"
	local uid="$2"
	local gid="$3"
	[ -d "$home" ] || return 0

	mkdir -p "$home/.config/xfce4/xfconf/xfce-perchannel-xml" \
		"$home/.config/xfce4/panel"

	for cfg in xfce4-desktop.xml xfce4-panel.xml xsettings.xml xfwm4.xml; do
		[ -f "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/$cfg" ] || continue
		install -m 0644 "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/$cfg" \
			"$home/.config/xfce4/xfconf/xfce-perchannel-xml/$cfg"
	done

	if [ -f /etc/skel/.config/xfce4/panel/whiskermenu-1.rc ]; then
		install -m 0644 /etc/skel/.config/xfce4/panel/whiskermenu-1.rc \
			"$home/.config/xfce4/panel/whiskermenu-1.rc"
	fi

	# Drop Mint's app-grid launcher and any other stale panel launchers.
	find "$home/.config/xfce4/panel" -maxdepth 1 -type d -name 'launcher-*' \
		-exec rm -rf {} + 2>/dev/null || true
	for d in /etc/skel/.config/xfce4/panel/launcher-*; do
		[ -d "$d" ] || continue
		cp -a "$d" "$home/.config/xfce4/panel/"
	done
	rm -f "$home/.config/xfce4/panel/default.xml" 2>/dev/null || true

	if [ -d /etc/skel/Desktop ]; then
		mkdir -p "$home/Desktop"
		cp -a /etc/skel/Desktop/. "$home/Desktop/" 2>/dev/null || true
		chmod +x "$home/Desktop/"*.desktop 2>/dev/null || true
	fi

	rm -rf "$home/.cache/xfce4" 2>/dev/null || true
	chown -R "$uid:$gid" "$home/.config" "$home/Desktop" 2>/dev/null || true
}

if [ -d /home/mint ]; then
	MINT_UID=$(id -u mint 2>/dev/null || echo 1000)
	MINT_GID=$(id -g mint 2>/dev/null || echo 1000)
	apply_aspera_xfce_profile /home/mint "$MINT_UID" "$MINT_GID"
fi

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

# English only — drop other language packs and locale files (typically a few hundred MB)
echo "Aspera OS: keeping English only (smaller image, staff desks are English)"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
printf 'LANG=en_US.UTF-8\nLC_ALL=en_US.UTF-8\n' > /etc/default/locale
# Generate only English locales (US + India office English)
printf '%s\n' 'en_US.UTF-8 UTF-8' 'en_IN UTF-8' > /etc/locale.gen
locale-gen en_US.UTF-8 en_IN.UTF-8 2>/dev/null || locale-gen || true
update-locale LANG=en_US.UTF-8 2>/dev/null || true

# Purge non-English language packs and LibreOffice translations/help
mapfile -t DROP_LANG < <(
	dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -E '^(language-pack|language-pack-gnome|libreoffice-l10n|libreoffice-help|hunspell|mythes|hyphen|aspell|firefox-locale|thunderbird-locale)-' \
	| grep -vE '(^language-pack-en$|^language-pack-en-|^language-pack-gnome-en$|^language-pack-gnome-en-|^libreoffice-l10n-en|^libreoffice-help-en|^hunspell-en|^mythes-en|^hyphen-en|^aspell-en|^firefox-locale-en|^thunderbird-locale-en)' \
	|| true
)
if [ "${#DROP_LANG[@]}" -gt 0 ]; then
	apt-get -y purge "${DROP_LANG[@]}" 2>/dev/null || true
fi

# Remove leftover translation trees (keep English + C)
keep_locale() {
	case "$1" in
		en|en_*|C|locale.alias|l10n) return 0 ;;
		*) return 1 ;;
	esac
}
if [ -d /usr/share/locale ]; then
	for d in /usr/share/locale/*; do
		[ -e "$d" ] || continue
		base=$(basename "$d")
		keep_locale "$base" || rm -rf "$d"
	done
fi
if [ -d /usr/share/help ]; then
	for d in /usr/share/help/*; do
		[ -e "$d" ] || continue
		base=$(basename "$d")
		case "$base" in
			C|en|en_*) ;;
			*) rm -rf "$d" ;;
		esac
	done
fi
# Non-English man pages
if [ -d /usr/share/man ]; then
	for d in /usr/share/man/*; do
		[ -d "$d" ] || continue
		base=$(basename "$d")
		case "$base" in
			man|man.?|en|en_*) ;;
			*) rm -rf "$d" ;;
		esac
	done
fi

# Cleanup apt caches for smaller squashfs
apt-get clean
rm -rf /tmp/aspera-vendor /tmp/aspera-branding /tmp/aspera-lists /tmp/chroot-customize.sh
rm -rf /var/lib/apt/lists/*

echo "Aspera OS: chroot customization done"
