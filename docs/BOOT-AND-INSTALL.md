# Live, install, login (the basics)

This is a **Linux Mint XFCE remaster**, not a new OS. Three things must work:

1. **Live USB** — boots to the XFCE desktop (Mint casper autologin).
2. **Install** — Mint’s installer (Ubiquity) still on the USB. You pick disk, name, and password.
3. **After reboot** — LightDM shows the user you created. That password works. No `mint` autologin on the hard disk.

## VirtualBox dry-run

Do **not** install Linux Mint in the VM. Create a **new empty machine** and boot
only `aspera-os-1.0-amd64.iso`.

- Machine → New
- Type: **Linux**, Version: **Debian (64-bit)** (VirtualBox label only — the
  disk stays empty until Aspera boots)
- Memory **4096 MB** or more, disk **25 GB** or more
- System → **uncheck Enable EFI**
- Storage: attach **only** `~/Aspera-OS/aspera-os-1.0-amd64.iso`
- Prefer the optical drive on **IDE**

If an old Mint VM is still listed, remove it (Machine → Remove) so you cannot
accidentally boot the previous disk.

A kernel panic (`Unable to mount root fs`) is a crash. Do not wait.

## Why the desk still looked like Mint

The live session logs in as **mint**, using the home folder baked into the Mint
squashfs. Settings copied only to `/etc/skel` affect **new** users after install,
not the live desktop. The remaster now applies the same panel, wallpaper, light
theme, and desktop icons to `/home/mint` as well.

## Rebuild

Full remaster (needed after chroot/login fixes):

On a **new PC** (office), clone instead of pull — see [OFFICE-PC.md](OFFICE-PC.md).

On the existing laptop:

```bash
cd ~/Aspera-OS
sudo chown -R shree:shree .
git fetch origin
git checkout cursor/fix-live-desktop-b747
git pull origin cursor/fix-live-desktop-b747
sudo scripts/build-iso.sh
```

If a rebuild was interrupted, leftover mounts can make cleanup print
`rm: cannot remove '.../.build/remaster/edit/sys/module/...': Operation not permitted`.
That is the host kernel tree still bound into the work folder. Unmount it
before deleting:

```bash
sudo scripts/clean-remaster.sh
```

Then run `sudo scripts/build-iso.sh` again. If the helper is not on this
clone yet, unmount by hand:

```bash
sudo umount -l ~/Aspera-OS/.build/remaster/edit/dev/pts
sudo umount -l ~/Aspera-OS/.build/remaster/edit/dev
sudo umount -l ~/Aspera-OS/.build/remaster/edit/proc
sudo umount -l ~/Aspera-OS/.build/remaster/edit/sys
sudo umount -l ~/Aspera-OS/.build/remaster/mount
sudo rm -rf ~/Aspera-OS/.build/remaster
```
