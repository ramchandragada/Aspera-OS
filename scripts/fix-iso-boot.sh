#!/bin/bash
# Fast path: rebuild the ISO boot catalog without remastering the whole system.
# Use when the current ISO kernel-panics with unknown-block(0,0).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/aspera-os-1.0-amd64.iso"
WORK="$ROOT/.build/bootfix-$$"
MINT_ISO="${MINT_ISO:-}"

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as: sudo $0"
	exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing tool: $1"; exit 1; }; }
need xorriso
need rsync

SRC=""
if [ -f "$ROOT/.build/remaster/iso/casper/filesystem.squashfs" ]; then
	SRC="$ROOT/.build/remaster/iso"
	echo "Using remaster tree: $SRC"
elif [ -f "$OUT" ]; then
	echo "Extracting existing ISO: $OUT"
	mkdir -p "$WORK/src"
	xorriso -osirrox on -indev "$OUT" -extract / "$WORK/src"
	SRC="$WORK/src"
else
	echo "No ISO or remaster tree found. Run: sudo scripts/build-iso.sh"
	exit 1
fi

"$ROOT/scripts/patch-live-boot.sh" "$SRC"

VOLID="Linux Mint"
if [ -f "$ROOT/.build/linuxmint-"*"-xfce-64bit.iso" ]; then
	MINT_ISO="$(ls "$ROOT/.build"/linuxmint-*-xfce-64bit.iso | head -n1)"
fi
if [ -n "${MINT_ISO}" ] && [ -f "$MINT_ISO" ]; then
	VOLID="$(xorriso -indev "$MINT_ISO" -status 2>/dev/null | awk -F"'" '/Volume id/ {print $2; exit}' || true)"
	VOLID="${VOLID:-Linux Mint}"
fi

echo "Writing ISO (volume id: $VOLID)..."
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
	"$SRC" || xorriso -as mkisofs \
		-r -V "$VOLID" \
		-o "$OUT" \
		-J -l \
		-b isolinux/isolinux.bin \
		-c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		"$SRC"

rm -rf "$WORK"
if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
	chown "${SUDO_UID}:${SUDO_GID}" "$OUT" 2>/dev/null || true
fi
ls -lh "$OUT"
echo "Done. In VirtualBox: EFI off, boot this new ISO."
