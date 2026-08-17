#!/bin/bash
# Safely add live-session args. Never rewrite the initrd= path.
# A previous sed ate "initrd" (the letter n) and caused:
#   Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
set -euo pipefail

ISO_ROOT="${1:?usage: patch-live-boot.sh /path/to/iso-tree}"

append_args() {
	local extra="noprompt noeject username=mint hostname=aspera-pc"
	local f="$1"
	[ -f "$f" ] || return 0
	# Drop installer-first flags; keep kernel and initrd paths intact
	sed -i \
		-e 's/[[:space:]]maybe-ubiquity//g' \
		-e 's/[[:space:]]only-ubiquity//g' \
		"$f"
	# Insert extra tokens just before -- or --- on casper lines that lack noprompt
	awk -v extra="$extra" '
		/boot=casper/ && $0 !~ /noprompt/ {
			if ($0 ~ / -- *$/) {
				sub(/ -- *$/, " " extra " --")
			} else if ($0 ~ / --- *$/) {
				sub(/ --- *$/, " " extra " ---")
			} else {
				$0 = $0 " " extra
			}
		}
		{ print }
	' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

if [ -f "$ISO_ROOT/isolinux/isolinux.cfg" ]; then
	sed -i 's/^timeout .*/timeout 30/' "$ISO_ROOT/isolinux/isolinux.cfg" || true
	sed -i 's/^PROMPT .*/PROMPT 0/' "$ISO_ROOT/isolinux/isolinux.cfg" || true
fi

for cfg in \
	"$ISO_ROOT/isolinux/isolinux.cfg" \
	"$ISO_ROOT/isolinux/live.cfg" \
	"$ISO_ROOT/isolinux/txt.cfg" \
	"$ISO_ROOT/boot/grub/grub.cfg" \
	"$ISO_ROOT/boot/grub/loopback.cfg"
do
	append_args "$cfg"
done

if [ -f "$ISO_ROOT/boot/grub/grub.cfg" ]; then
	sed -i 's/set timeout=.*/set timeout=3/' "$ISO_ROOT/boot/grub/grub.cfg" || true
	grep -q 'set default=' "$ISO_ROOT/boot/grub/grub.cfg" || sed -i '1iset default=0' "$ISO_ROOT/boot/grub/grub.cfg" || true
fi

# Hard fail if we would ship a broken initrd line
if grep -RIn '---nitrd' "$ISO_ROOT/isolinux" "$ISO_ROOT/boot/grub" 2>/dev/null | grep -q .; then
	echo "ERROR: boot config still looks corrupted (initrd path)." >&2
	exit 1
fi
if ! grep -RIn 'initrd' "$ISO_ROOT/isolinux" "$ISO_ROOT/boot/grub" >/dev/null 2>&1; then
	echo "ERROR: no initrd reference in boot menus." >&2
	exit 1
fi

echo "Live boot menus patched (initrd paths preserved)."
