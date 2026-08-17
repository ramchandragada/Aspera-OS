#!/usr/bin/env bash
# Detach leftover remaster bind-mounts, then wipe .build/remaster.
# Use this when a killed ISO build leaves /sys attached and rm -rf
# prints "Operation not permitted" under .build/remaster/edit/sys.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

. "$ROOT/scripts/lib-remaster-mounts.sh"

WORK="${ASPERA_WORK:-$ROOT/.build/remaster}"

if [ "$(id -u)" -ne 0 ]; then
	echo "Run as root: sudo $0" >&2
	exit 1
fi

unmount_chroot "$WORK"
assert_chroot_unmounted "$WORK"
rm -rf "$WORK"
echo "Remaster work tree is clear."
