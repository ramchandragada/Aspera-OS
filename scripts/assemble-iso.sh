#!/bin/bash
# Assemble Aspera ISO by copying Linux Mint's original boot record and
# injecting our squashfs. Rebuilding with mkisofs broke casper (kernel panic:
# VFS: Unable to mount root fs on unknown-block(0,0)).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MINT_ISO="${1:?usage: assemble-iso.sh MINT.iso SQUASHFS [SIZEFILE] [OUT.iso]}"
SQUASH="${2:?}"
SIZEFILE="${3:-}"
OUT="${4:-$ROOT/aspera-os-1.0-amd64.iso}"

if [ ! -f "$MINT_ISO" ]; then
	echo "Missing original Mint ISO: $MINT_ISO" >&2
	exit 1
fi
if [ ! -f "$SQUASH" ]; then
	echo "Missing squashfs: $SQUASH" >&2
	exit 1
fi

echo "Assembling ISO from Mint boot image + Aspera squashfs"
echo "  Mint:    $MINT_ISO"
echo "  Squash:  $SQUASH"
echo "  Output:  $OUT"

rm -f "$OUT"
XORRISO_ARGS=(
	-indev "$MINT_ISO"
	-outdev "$OUT"
	-boot_image any replay
	-rm_r /casper/filesystem.squashfs --
	-map "$SQUASH" /casper/filesystem.squashfs
	-chmod a+r /casper/filesystem.squashfs --
)
if [ -n "$SIZEFILE" ] && [ -f "$SIZEFILE" ]; then
	XORRISO_ARGS+=(
		-rm_r /casper/filesystem.size --
		-map "$SIZEFILE" /casper/filesystem.size
		-chmod a+r /casper/filesystem.size --
	)
fi
if [ -f "${SQUASH%/*}/filesystem.manifest" ]; then
	XORRISO_ARGS+=(
		-rm_r /casper/filesystem.manifest --
		-map "${SQUASH%/*}/filesystem.manifest" /casper/filesystem.manifest
		-chmod a+r /casper/filesystem.manifest --
	)
fi
CASPER_DIR="${SQUASH%/*}"
for bootf in vmlinuz initrd.lz initrd.img; do
	if [ -f "$CASPER_DIR/$bootf" ]; then
		XORRISO_ARGS+=(
			-rm_r "/casper/$bootf" --
			-map "$CASPER_DIR/$bootf" "/casper/$bootf"
			-chmod a+r "/casper/$bootf" --
		)
	fi
done

xorriso "${XORRISO_ARGS[@]}"

ls -lh "$OUT"
echo "Assembled with original Mint boot (casper can find the disc)."
