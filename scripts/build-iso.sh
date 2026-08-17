#!/bin/bash
# Remaster Linux Mint XFCE into Aspera OS 1.0
# Requires: curl, squashfs-tools, xorriso, rsync, genisoimage/xorriso, chroot tools
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${ASPERA_WORK:-$ROOT/.build/remaster}"
OUT="$ROOT/aspera-os-1.0-amd64.iso"
VENDOR="$ROOT/vendor"

# Linux Mint 22.3 XFCE (Zena) — already the current point release
MINT_VERSION="${MINT_VERSION:-22.3}"
MINT_EDITION="xfce"
MINT_ISO_NAME="linuxmint-${MINT_VERSION}-${MINT_EDITION}-64bit.iso"
MINT_ISO_URL="${MINT_ISO_URL:-https://mirrors.kernel.org/linuxmint/stable/${MINT_VERSION}/${MINT_ISO_NAME}}"
MINT_ISO="${MINT_ISO:-$ROOT/.build/$MINT_ISO_NAME}"

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as: sudo $0"
	exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing tool: $1"; exit 1; }; }
need curl
need unsquashfs
need mksquashfs
need xorriso
need rsync

if ! ls "$VENDOR"/asperadock*.deb >/dev/null 2>&1 \
	|| ! ls "$VENDOR"/tuxgenie*.deb >/dev/null 2>&1 \
	|| ! ls "$VENDOR"/anydesk*.deb >/dev/null 2>&1 \
	|| ! ls "$VENDOR"/google-chrome*.deb >/dev/null 2>&1 \
	|| ! ls "$VENDOR"/pdf-sign-verifier*.deb >/dev/null 2>&1; then
	echo "Vendor .deb packages missing — running fetch-vendor.sh"
	"$ROOT/scripts/fetch-vendor.sh"
fi

mkdir -p "$ROOT/.build" "$WORK"
if [ ! -f "$MINT_ISO" ]; then
	echo "Downloading Linux Mint XFCE ISO..."
	curl -fL --retry 3 -o "$MINT_ISO.partial" "$MINT_ISO_URL"
	mv "$MINT_ISO.partial" "$MINT_ISO"
fi
ls -lh "$MINT_ISO"

echo "Cleaning work dir..."
# Unmount any leftover chroot binds from a previous failed run
if [ -d "$WORK/edit" ]; then
	umount "$WORK/edit/dev/pts" 2>/dev/null || true
	umount "$WORK/edit/dev" 2>/dev/null || true
	umount "$WORK/edit/run" 2>/dev/null || true
	umount "$WORK/edit/proc" 2>/dev/null || true
	umount "$WORK/edit/sys" 2>/dev/null || true
	umount "$WORK/mount" 2>/dev/null || true
fi
rm -rf "$WORK"
mkdir -p "$WORK"/{iso,squash,edit,mount}

echo "Mounting Mint ISO..."
mount -o loop "$MINT_ISO" "$WORK/mount"
rsync -a --exclude=/casper/filesystem.squashfs "$WORK/mount"/ "$WORK/iso"/
unsquashfs -d "$WORK/edit" "$WORK/mount/casper/filesystem.squashfs"
umount "$WORK/mount"

echo "Applying Aspera customization inside chroot..."
mkdir -p "$WORK/edit/tmp"
cp -a "$ROOT/scripts/chroot-customize.sh" "$WORK/edit/tmp/chroot-customize.sh"
mkdir -p "$WORK/edit/tmp/aspera-vendor" "$WORK/edit/tmp/aspera-branding" "$WORK/edit/tmp/aspera-lists"
cp -a "$VENDOR"/*.deb "$WORK/edit/tmp/aspera-vendor/"
cp -a "$ROOT/branding/logos/." "$WORK/edit/tmp/aspera-branding/"
cp -a "$ROOT/branding/wallpapers/." "$WORK/edit/tmp/aspera-branding/"
cp -a "$ROOT/iso/remaster/lists/." "$WORK/edit/tmp/aspera-lists/"
mkdir -p "$WORK/edit/tmp/aspera-includes"
if [ -d "$ROOT/iso/remaster/includes" ]; then
	cp -a "$ROOT/iso/remaster/includes/." "$WORK/edit/tmp/aspera-includes/"
fi

mount --bind /dev "$WORK/edit/dev"
mount -t proc proc "$WORK/edit/proc"
mount -t sysfs sysfs "$WORK/edit/sys"
mount -t devpts devpts "$WORK/edit/dev/pts"
# Do not bind-mount /run: on systemd hosts /etc/resolv.conf is often the same
# file via /run/systemd/resolve, and cp then aborts the whole build.
rm -f "$WORK/edit/etc/resolv.conf"
cat > "$WORK/edit/etc/resolv.conf" <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 9.9.9.9
EOF

chroot "$WORK/edit" /bin/bash /tmp/chroot-customize.sh
status=$?

umount "$WORK/edit/dev/pts" 2>/dev/null || true
umount "$WORK/edit/dev" 2>/dev/null || true
umount "$WORK/edit/proc" 2>/dev/null || true
umount "$WORK/edit/sys" 2>/dev/null || true

if [ "$status" -ne 0 ]; then
	echo "ERROR: chroot customization failed"
	exit "$status"
fi

echo "Repacking squashfs (this takes a while)..."
rm -f "$WORK/iso/casper/filesystem.squashfs"
mksquashfs "$WORK/edit" "$WORK/iso/casper/filesystem.squashfs" -comp xz -noappend
printf '%s' "$(du -sx --block-size=1 "$WORK/edit" | cut -f1)" > "$WORK/iso/casper/filesystem.size"

# Refresh package manifest if tool exists
if [ -x "$WORK/edit/usr/bin/dpkg-query" ]; then
	chroot "$WORK/edit" dpkg-query -W --showformat='${Package} ${Version}\n' > "$WORK/iso/casper/filesystem.manifest" || true
fi

# Live boot kernel must match modules inside the upgraded squashfs
echo "Syncing casper kernel with remaster..."
VMLINUZ=$(ls -1 "$WORK/edit/boot"/vmlinuz-* 2>/dev/null | sort -V | tail -1 || true)
INITRD=$(ls -1 "$WORK/edit/boot"/initrd.img-* 2>/dev/null | sort -V | tail -1 || true)
if [ -n "${VMLINUZ:-}" ]; then
	cp -L "$VMLINUZ" "$WORK/iso/casper/vmlinuz"
fi
if [ -n "${INITRD:-}" ]; then
	cp -L "$INITRD" "$WORK/iso/casper/initrd.lz"
fi

"$ROOT/scripts/assemble-iso.sh" "$MINT_ISO" \
	"$WORK/iso/casper/filesystem.squashfs" \
	"$WORK/iso/casper/filesystem.size" \
	"$OUT"

if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
	chown "${SUDO_UID}:${SUDO_GID}" "$OUT" 2>/dev/null || true
	chown -R "${SUDO_UID}:${SUDO_GID}" "$ROOT/vendor" "$ROOT/.build" 2>/dev/null || true
fi

echo
echo "Aspera OS image ready:"
ls -lh "$OUT"
