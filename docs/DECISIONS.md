# Locked decisions

**Aspera OS** = Linux Mint XFCE company image (2026-08-16).

---

## ADR-001 — Linux Mint XFCE is the base

**Decision:** Remaster current Linux Mint **XFCE 22.3** LTS. Do not build Ubuntu GNOME or Debian from scratch.

**Why:** Staff already understand Mint/XFCE. XFCE is the lightest serious desktop Mint ships. Speed and stability beat inventing a new stack.

## ADR-002 — Staff apps only

**Decision:** Staff image: Chrome, Aspera Hub, TuxGenie, LibreOffice **Writer/Calc/Draw** (no Impress, Base, or Math), SimpleScreenRecorder, Flameshot, AnyDesk, **PDF Sign Verifier**. No VLC. No second browser. Strip Mint extras (Hypnotix, games, Thunderbird, Transmission, Firefox, Matrix/Element chat, Web Apps, Notes, USB Image Writer, Warpinator, Mint Screenshot / `xfce4-screenshooter`, etc.). Flameshot is the only screenshot tool.

**Why:** The company only uses these tools. Extra apps create tickets and waste RAM/disk on 128 GB SSDs. Impress and VLC were unused weight. Firefox/Thunderbird/Transmission/Matrix are replaced by Chrome + Hub.

## ADR-003 — Hardware floor

**Decision:** Design target **Core i5 4th gen, 8 GB RAM, 128 GB SSD**. zram on. amd64, BIOS+UEFI.

**Why:** Real office PCs. 8 GB is enough for Chrome + Hub + LibreOffice on XFCE if the image stays thin.

## ADR-004 — How work is done on the PC

**Decision:** Chrome = general web. Hub = WhatsApp, Arattai, Gmail, Zoho Mail. TuxGenie = repair. AnyDesk = remote support (not autostart). LibreOffice Writer/Calc/Draw = documents. Flameshot = screenshots. SimpleScreenRecorder = screen capture. No desktop video player in the default image.

**Why:** One clear place for each job. No second browser, no second mail client, no unused media stack.

## ADR-005 — Two delivery tracks

**Decision:** Remastered ISO for new and rebuilt PCs. Ansible `mint-to-aspera.yml` for existing Mint XFCE. No fleet-wide wipe on day one.

**Why:** Most desks can be converted in place. ISO is for greenfield and broken machines.

## ADR-006 — Branding

**Decision:** Dark navy company look. Full wordmark (`branding/logos/aspera.png`) for greeter and docs. Start menu / panel uses only the chevron mark (`branding/logos/aspera-mark.png`). Default wallpaper is 1920×1080 navy with a **small centered** wordmark (~20% width) — not a huge full-bleed logo.

**Why:** Staff must see they are on the company OS, not stock Mint. A panel-sized wordmark looks broken; a screen-filling logo looks unprofessional.

## ADR-010 — Mint XFCE default light appearance

**Decision:** Appearance stays **Linux Mint XFCE default light**: Style `Mint-Y`, Icons `Mint-Y`, Window Manager `Mint-Y`, fonts Ubuntu 10, panel light (not dark mode). Aspera changes wallpaper, start-menu mark, and panel launchers only — not a custom dark skin.

**Why:** Staff already know Mint. A custom theme creates “what happened to my PC?” tickets.

## ADR-011 — English only

**Decision:** Ship English only (`en_US.UTF-8`, keep `en_IN` available). Purge other language packs, LibreOffice translations/help, and non-English locale/man/help trees during remaster.

**Why:** Company desks are English. Extra languages waste disk (typically a few hundred MB in the live image) and clutter Language Support. Not a dramatic ISO shrink, but worth doing on 128 GB SSDs.

## ADR-012 — Safe thin pass (clutter out, services stay)

**Decision:**
- Purge leftover Mint apps not in the staff set (games, HexChat, Drawing, Pix, Flatpak, Mint Welcome, preload, etc.). Flameshot only for screenshots.
- `vm.swappiness=20` with zram 50%/zstd. Never install preload.
- Trim welcome/report autostart noise.
- **Do not** disable CUPS or Bluetooth system-wide. Desks print; some PCs use BT. Blueberry GUI is removed; printer stack and NetworkManager stay.

**Why:** Smaller ISO and less clutter without risking “printers stopped working” or “no Bluetooth keyboard” tickets.

## ADR-007 — No staff software store

**Decision:** Remove or hide Software Manager / store workflows for staff. Updates via Mint Update for the system; new apps only by company image/Ansible.

**Why:** Random installs destroy the “bare minimum” promise.

## ADR-008 — Vendor packages pinned at build

**Decision:** `scripts/fetch-vendor.sh` downloads pinned Hub, TuxGenie, Chrome, and AnyDesk `.deb`s into `vendor/` at ISO build time.

**Why:** Every USB and every Ansible run must match. No “whatever was latest on one PC.”

## ADR-009 — Live GUI, successful install, then your login

**Decision:** Remaster only. Keep Mint’s original ISO boot (`xorriso -boot_image any replay`) so casper finds the disc. Live desktop is Mint casper + LightDM/XFCE. Do **not** write `autologin-user=mint` into the squashfs (that is copied onto the PC and blocks the real account). Ubiquity stays installed. After install, LightDM uses the user and password created in the installer. `apt autoremove` is forbidden in the remaster.

**Why:** Staff need: USB → desktop → Install → reboot → their name and password. Baking live autologin into the disk image, rewriting boot with mkisofs, or autoremoving packages breaks those basics.
