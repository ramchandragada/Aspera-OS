# Live, install, login (the basics)

This is a **Linux Mint XFCE remaster**, not a new OS. Three things must work:

1. **Live USB** — boots to the XFCE desktop (Mint casper autologin).
2. **Install** — Mint’s installer (Ubiquity) still on the USB. You pick disk, name, and password.
3. **After reboot** — LightDM shows the user you created. That password works. No `mint` autologin on the hard disk.

## VirtualBox dry-run

- Power off the VM first
- System → **uncheck Enable EFI**
- Memory **4096 MB** or more, disk **25 GB** or more
- Storage: remove any old ISO, attach the new `aspera-os-1.0-amd64.iso`
- Prefer the optical drive on **IDE**

A kernel panic (`Unable to mount root fs`) is a crash. Do not wait.

## Why the desk still looked like Mint

The live session logs in as **mint**, using the home folder baked into the Mint
squashfs. Settings copied only to `/etc/skel` affect **new** users after install,
not the live desktop. The remaster now applies the same panel, wallpaper, light
theme, and desktop icons to `/home/mint` as well.

## Rebuild

Full remaster (needed after chroot/login fixes):

```bash
cd ~/Aspera-OS
sudo chown -R shree:shree .
git pull
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
