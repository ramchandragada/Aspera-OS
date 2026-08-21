# Aspera OS — how to work in this repo

You are Chief Architect / CTO. The owner is not a developer. Take decisions. Do not ask them to choose Mint vs Ubuntu, XFCE vs GNOME, or package names.

## Locked (see docs/DECISIONS.md)

- Base: **Linux Mint XFCE** (current LTS), remastered — not a from-scratch OS
- Exactly these staff apps: Chrome, Aspera Hub, TuxGenie, LibreOffice Writer/Calc/Draw, SimpleScreenRecorder, Flameshot, AnyDesk, PDF Sign Verifier
- Hardware: Core i5 4th gen, 8 GB RAM, 128 GB SSD; zram on; amd64
- One person, one login; no guest; no software store for staff
- ISO for new/rebuild PCs; Ansible for existing Mint XFCE
- Branding: `branding/logos/aspera.png` everywhere practical
- Speak plainly; put detail in `docs/`

## Do not

- Add apps, desktops, Snaps-as-store, or GNOME without an ADR change
- Reinstall Impress, VLC, Firefox, Thunderbird, Transmission, Matrix chat, or Mint Screenshot without an ADR change
- Reimage the Mint fleet as the first move
- Leave architecture open-ended in owner-facing replies

## When Hub or TuxGenie release

Run `scripts/fetch-vendor.sh`, then rebuild the ISO or re-run Ansible.
