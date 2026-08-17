#!/bin/bash
# Fast repair: keep Mint's boot, inject the already-built Aspera squashfs.
# Do not remaster. Do not mkisofs a new boot catalog.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/aspera-os-1.0-amd64.iso"
EXTRACT="$ROOT/.build/extract-squash"

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as: sudo $0"
	exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing tool: $1"; exit 1; }; }
need xorriso

MINT_ISO="$(ls "$ROOT/.build"/linuxmint-*-xfce-64bit.iso 2>/dev/null | head -n1 || true)"
if [ -z "${MINT_ISO:-}" ] || [ ! -f "$MINT_ISO" ]; then
	echo "Original Linux Mint ISO not found under $ROOT/.build/"
	echo "It should be named linuxmint-*-xfce-64bit.iso (downloaded by build-iso.sh)."
	exit 1
fi

SQUASH=""
SIZEFILE=""
if [ -f "$ROOT/.build/remaster/iso/casper/filesystem.squashfs" ]; then
	SQUASH="$ROOT/.build/remaster/iso/casper/filesystem.squashfs"
	SIZEFILE="$ROOT/.build/remaster/iso/casper/filesystem.size"
	echo "Using squashfs from remaster tree"
elif [ -f "$OUT" ]; then
	echo "Extracting squashfs from current Aspera ISO (a few minutes)..."
	rm -rf "$EXTRACT"
	mkdir -p "$EXTRACT"
	xorriso -osirrox on -indev "$OUT" -extract /casper/filesystem.squashfs "$EXTRACT/filesystem.squashfs"
	xorriso -osirrox on -indev "$OUT" -extract /casper/filesystem.size "$EXTRACT/filesystem.size" 2>/dev/null || true
	SQUASH="$EXTRACT/filesystem.squashfs"
	SIZEFILE="$EXTRACT/filesystem.size"
else
	echo "No squashfs found. Run a full: sudo scripts/build-iso.sh"
	exit 1
fi

"$ROOT/scripts/assemble-iso.sh" "$MINT_ISO" "$SQUASH" "$SIZEFILE" "$OUT"

if [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
	chown "${SUDO_UID}:${SUDO_GID}" "$OUT" 2>/dev/null || true
fi

echo
echo "Power off the VM. In VirtualBox:"
echo "  Settings → System → uncheck Enable EFI"
echo "  Settings → Storage → remove the old disc, then add:"
echo "  $OUT"
echo "Then start the VM."
