# Work from another PC (office)

The project lives on GitHub. Do **not** copy the home folder, `.build/`, or
vendor `.deb` files. Those are large and rebuild themselves.

**Repo:** https://github.com/ramchandragada/Aspera-OS  
**Branch to use:** `cursor/fix-live-desktop-b747`  
(this is the current Aspera remaster, including the live-desktop fix)

The ISO file is **not** in git. Rebuild it on the office PC, or copy only
`aspera-os-1.0-amd64.iso` on a USB if you only need to test VirtualBox.

## Office Linux PC (build and test)

Needs: internet, `sudo`, git, VirtualBox (for a dry-run).

```bash
sudo apt-get update
sudo apt-get install -y git curl squashfs-tools xorriso rsync

git clone -b cursor/fix-live-desktop-b747 \
  https://github.com/ramchandragada/Aspera-OS.git
cd Aspera-OS

sudo scripts/fetch-vendor.sh
sudo scripts/build-iso.sh
```

ISO output: `aspera-os-1.0-amd64.iso`

Then test in VirtualBox as in [BOOT-AND-INSTALL.md](BOOT-AND-INSTALL.md):
new empty machine, Debian (64-bit), no EFI, attach **only** that ISO.

If a remaster was interrupted:

```bash
sudo scripts/clean-remaster.sh
sudo scripts/build-iso.sh
```

## Office Windows PC (Cursor / GitHub only)

You can open the GitHub repo in Cursor and keep working on files.
You **cannot** remaster the ISO on Windows. For a USB or VirtualBox test,
either rebuild on a Linux PC or copy the finished ISO from home.

```text
git clone -b cursor/fix-live-desktop-b747 https://github.com/ramchandragada/Aspera-OS.git
```

## Do not bring from home

| Leave behind | Why |
|---|---|
| `.build/` | Leftover mounts; several GB |
| `vendor/*.deb` | `fetch-vendor.sh` downloads them |
| Old `aspera-os-1.0-amd64.iso` | Easy to test the wrong image |
| Linux Mint VM | Boot a new empty VM + Aspera ISO |

## After you change files

Push to GitHub from that PC (or let Cursor do it). Home and office then
both pull the same branch. Do not keep a private copy that never gets pushed.
