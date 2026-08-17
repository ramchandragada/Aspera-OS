# Locked decisions

**Aspera OS** = Linux Mint XFCE company image (2026-08-16).

---

## ADR-001 — Linux Mint XFCE is the base

**Decision:** Remaster current Linux Mint **XFCE** LTS. Do not build Ubuntu GNOME or Debian from scratch.

**Why:** Staff already understand Mint/XFCE. XFCE is the lightest serious desktop Mint ships. Speed and stability beat inventing a new stack.

## ADR-002 — Eight apps only

**Decision:** Staff image contains only: Chrome, Aspera Hub, TuxGenie, LibreOffice (complete), SimpleScreenRecorder, Flameshot, AnyDesk, VLC. Strip Mint extras (Hypnotix, games, Hexchat, Thunderbird, Transmission, Drawing, etc.).

**Why:** The company only uses these tools. Extra apps create tickets and waste RAM/disk on 128 GB SSDs.

## ADR-003 — Hardware floor

**Decision:** Design target **Core i5 4th gen, 8 GB RAM, 128 GB SSD**. zram on. amd64, BIOS+UEFI.

**Why:** Real office PCs. 8 GB is enough for Chrome + Hub + LibreOffice on XFCE if the image stays thin.

## ADR-004 — How work is done on the PC

**Decision:** Chrome = general web. Hub = WhatsApp, Arattai, Gmail, Zoho Mail. TuxGenie = repair. AnyDesk = remote support (not autostart). LibreOffice = documents. Flameshot / SimpleScreenRecorder / VLC = capture and media.

**Why:** One clear place for each job. No second browser, no second mail client.

## ADR-005 — Two delivery tracks

**Decision:** Remastered ISO for new and rebuilt PCs. Ansible `mint-to-aspera.yml` for existing Mint XFCE. No fleet-wide wipe on day one.

**Why:** Most desks can be converted in place. ISO is for greenfield and broken machines.

## ADR-006 — Branding

**Decision:** Aspera logo (`branding/logos/aspera.png`) on wallpaper, Whisker menu icon where possible, LightDM/slick-greeter, and docs. Dark navy company look.

**Why:** Staff must see they are on the company OS, not stock Mint.

## ADR-007 — No staff software store

**Decision:** Remove or hide Software Manager / store workflows for staff. Updates via Mint Update for the system; new apps only by company image/Ansible.

**Why:** Random installs destroy the “bare minimum” promise.

## ADR-008 — Vendor packages pinned at build

**Decision:** `scripts/fetch-vendor.sh` downloads pinned Hub, TuxGenie, Chrome, and AnyDesk `.deb`s into `vendor/` at ISO build time.

**Why:** Every USB and every Ansible run must match. No “whatever was latest on one PC.”

## ADR-009 — Live GUI, successful install, then your login

**Decision:** Remaster only. Keep Mint’s original ISO boot (`xorriso -boot_image any replay`) so casper finds the disc. Live desktop is Mint casper + LightDM/XFCE. Do **not** write `autologin-user=mint` into the squashfs (that is copied onto the PC and blocks the real account). Ubiquity stays installed. After install, LightDM uses the user and password created in the installer. `apt autoremove` is forbidden in the remaster.

**Why:** Staff need: USB → desktop → Install → reboot → their name and password. Baking live autologin into the disk image, rewriting boot with mkisofs, or autoremoving packages breaks those basics.
