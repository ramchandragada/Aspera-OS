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

## Rebuild

Full remaster (needed after chroot/login fixes):

```bash
cd ~/Aspera-OS
sudo chown -R shree:shree .
git pull
sudo scripts/build-iso.sh
```
