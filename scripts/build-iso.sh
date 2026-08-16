#!/bin/bash
# Remaster Linux Mint XFCE into Aspera OS 1.0
# Requires: curl, squashfs-tools, xorriso, rsync, genisoimage/xorriso, chroot tools
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${ASPERA_WORK:-$ROOT/.build/remaster}"
OUT="$ROOT/aspera-os-1.0-amd64.iso"
VENDOR="$ROOT/vendor"

# Linux Mint 22.1 XFCE (Wilma) — amd64 64-bit
MINT_VERSION="${MINT_VERSION:-22.1}"
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
	|| ! ls "$VENDOR"/google-chrome*.deb >/dev/null 2>&1; then
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
rm -rf "$WORK"
mkdir -p "$WORK"/{iso,squash,edit,mount}

echo "Mounting Mint ISO..."
mount -o loop "$MINT_ISO" "$WORK/mount"
rsync -a --exclude=/casper/filesystem.squashfs "$WORK/mount"/ "$WORK/iso"/
unsquashfs -d "$WORK/edit" "$WORK/mount/casper/filesystem.squashfs"
umount "$WORK/mount"

echo "Applying Aspera customization inside chroot..."
cp -a "$ROOT/scripts/chroot-customize.sh" "$WORK/edit/tmp/chroot-customize.sh"
mkdir -p "$WORK/edit/tmp/aspera-vendor" "$WORK/edit/tmp/aspera-branding" "$WORK/edit/tmp/aspera-lists"
cp -a "$VENDOR"/*.deb "$WORK/edit/tmp/aspera-vendor/"
cp -a "$ROOT/branding/logos/." "$WORK/edit/tmp/aspera-branding/"
cp -a "$ROOT/branding/wallpapers/." "$WORK/edit/tmp/aspera-branding/"
cp -a "$ROOT/iso/remaster/lists/." "$WORK/edit/tmp/aspera-lists/"

mount --bind /dev "$WORK/edit/dev"
mount --bind /run "$WORK/edit/run"
mount -t proc proc "$WORK/edit/proc"
mount -t sysfs sysfs "$WORK/edit/sys"
mount -t devpts devpts "$WORK/edit/dev/pts"
cp /etc/resolv.conf "$WORK/edit/etc/resolv.conf"

chroot "$WORK/edit" /bin/bash /tmp/chroot-customize.sh
status=$?

umount "$WORK/edit/dev/pts" 2>/dev/null || true
umount "$WORK/edit/dev" 2>/dev/null || true
umount "$WORK/edit/run" 2>/dev/null || true
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

# Volume label
VOLID="ASPERA_OS_1_0"

echo "Building hybrid ISO..."
rm -f "$OUT"
xorriso -as mkisofs \
	-r -V "$VOLID" \
	-o "$OUT" \
	-J -l \
	-b isolinux/isolinux.bin \
	-c isolinux/boot.cat \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-eltorito-alt-boot \
	-e boot/grub/efi.img \
	-no-emul-boot \
	-isohybrid-gpt-basdat \
	"$WORK/iso" || {
		echo "EFI hybrid failed — trying BIOS-oriented ISO..."
		xorriso -as mkisofs \
			-r -V "$VOLID" \
			-o "$OUT" \
			-J -l \
			-b isolinux/isolinux.bin \
			-c isolinux/boot.cat \
			-no-emul-boot -boot-load-size 4 -boot-info-table \
			-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
			"$WORK/iso" 2>/dev/null \
		|| xorriso -as mkisofs -r -V "$VOLID" -o "$OUT" -J -l "$WORK/iso"
	}

if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
	chown "${SUDO_UID}:${SUDO_GID}" "$OUT" 2>/dev/null || true
	chown -R "${SUDO_UID}:${SUDO_GID}" "$ROOT/vendor" "$ROOT/.build" 2>/dev/null || true
fi

echo
echo "Aspera OS image ready:"
ls -lh "$OUT"
