# Shared remaster unmount helpers. Sourced from scripts/ that already
# set ROOT. Do not bind-mount host /run into the chroot.

is_mounted() {
	local p="$1"
	[ -n "$p" ] || return 1
	if command -v mountpoint >/dev/null 2>&1; then
		mountpoint -q "$p" 2>/dev/null
		return $?
	fi
	awk -v p="$p" '$2 == p { found=1 } END { exit !found }' /proc/mounts 2>/dev/null
}

unmount_path() {
	local p="$1"
	local n=0
	[ -n "$p" ] || return 0
	while is_mounted "$p"; do
		n=$((n + 1))
		if [ "$n" -gt 8 ]; then
			echo "still mounted after retries: $p" >&2
			return 1
		fi
		umount -l "$p" 2>/dev/null || true
		sleep 0.2
	done
	return 0
}

unmount_chroot() {
	local work="${1:-}"
	[ -n "$work" ] || return 0
	unmount_path "$work/edit/dev/pts" || true
	unmount_path "$work/edit/dev" || true
	unmount_path "$work/edit/run" || true
	unmount_path "$work/edit/proc" || true
	unmount_path "$work/edit/sys" || true
	unmount_path "$work/mount" || true
	return 0
}

assert_chroot_unmounted() {
	local work="${1:-}"
	local leftover=0
	local p
	[ -n "$work" ] || return 0
	for p in \
		"$work/edit/dev/pts" \
		"$work/edit/dev" \
		"$work/edit/run" \
		"$work/edit/proc" \
		"$work/edit/sys" \
		"$work/mount"
	do
		if is_mounted "$p"; then
			echo "still mounted: $p" >&2
			leftover=1
		fi
	done
	if [ "$leftover" -ne 0 ]; then
		echo "Stop. Leftover remaster mounts are still attached to this PC." >&2
		echo "Do not rm -rf .build/remaster until they are gone." >&2
		echo "Run: sudo scripts/clean-remaster.sh" >&2
		echo "Or:" >&2
		echo "  sudo umount -l $work/edit/dev/pts" >&2
		echo "  sudo umount -l $work/edit/dev" >&2
		echo "  sudo umount -l $work/edit/proc" >&2
		echo "  sudo umount -l $work/edit/sys" >&2
		echo "  sudo umount -l $work/mount" >&2
		return 1
	fi
	return 0
}
