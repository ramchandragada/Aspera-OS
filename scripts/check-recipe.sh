#!/bin/bash
# Guardrails for the remaster: live GUI, installer present, installed login.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }

test -f "$ROOT/scripts/build-iso.sh" || fail "build-iso.sh missing"
test -f "$ROOT/scripts/assemble-iso.sh" || fail "assemble-iso.sh missing"
test -f "$ROOT/scripts/chroot-customize.sh" || fail "chroot-customize.sh missing"
test -f "$ROOT/scripts/lib-remaster-mounts.sh" || fail "lib-remaster-mounts.sh missing"
test -f "$ROOT/scripts/clean-remaster.sh" || fail "clean-remaster.sh missing"
test -f "$ROOT/branding/logos/aspera.png" || fail "logo missing"
test -f "$ROOT/iso/remaster/lists/install.list" || fail "install.list missing"
test -f "$ROOT/iso/remaster/lists/purge.list" || fail "purge.list missing"

grep -q 'boot_image any replay' "$ROOT/scripts/assemble-iso.sh" \
	|| fail "ISO must be assembled with Mint boot replay (not mkisofs)"

grep -q 'ubiquity' "$ROOT/iso/remaster/lists/install.list" \
	|| fail "ubiquity must stay in the image"
grep -q 'lightdm' "$ROOT/iso/remaster/lists/install.list" \
	|| fail "lightdm must stay in the image"

if grep -qxE 'ubiquity|casper|lightdm|xfce4|grub-pc' "$ROOT/iso/remaster/lists/purge.list"; then
	fail "purge.list must not remove installer/boot/desktop"
fi

grep -q 'autoremove --purge' "$ROOT/scripts/chroot-customize.sh" \
	&& fail "chroot must not autoremove (can delete ubiquity)"

grep -q 'autologin-user=mint' "$ROOT/scripts/chroot-customize.sh" \
	&& fail "do not bake autologin-user=mint into the squashfs (breaks installed login)"

grep -q 'target-config/10aspera-installed-login' "$ROOT/scripts/chroot-customize.sh" \
	|| fail "ubiquity target-config hook missing"

grep -q 'set-default graphical.target' "$ROOT/scripts/chroot-customize.sh" \
	|| fail "graphical.target must be the default"

grep -q 'lib-remaster-mounts.sh' "$ROOT/scripts/build-iso.sh" \
	|| fail "build-iso.sh must use lib-remaster-mounts.sh"
grep -q 'assert_chroot_unmounted' "$ROOT/scripts/build-iso.sh" \
	|| fail "build-iso.sh must refuse rm -rf while /sys is still bound"
grep -q 'umount -l' "$ROOT/scripts/lib-remaster-mounts.sh" \
	|| fail "unmount helper must use umount -l"

bash -n "$ROOT/scripts/build-iso.sh"
bash -n "$ROOT/scripts/assemble-iso.sh"
bash -n "$ROOT/scripts/chroot-customize.sh"
bash -n "$ROOT/scripts/fix-iso-boot.sh"
bash -n "$ROOT/scripts/fetch-vendor.sh"
bash -n "$ROOT/scripts/lib-remaster-mounts.sh"
bash -n "$ROOT/scripts/clean-remaster.sh"

echo "OK: remaster recipe keeps live GUI, installer, and installed login."
