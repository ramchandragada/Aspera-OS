# Aspera OS

Company Linux for staff PCs. **Linux Mint XFCE**, thin and fast.

## Locked apps only

| App | Role |
|---|---|
| Google Chrome | General browsing |
| Aspera Hub | WhatsApp, Arattai, Gmail, Zoho Mail |
| TuxGenie | Linux troubleshooting |
| LibreOffice | Full office suite |
| SimpleScreenRecorder | Screen recording |
| Flameshot | Screenshots |
| AnyDesk | Remote support |
| VLC | Video |

Nothing else is a product app.

## Hardware target

**Intel Core i5 4th gen · 8 GB RAM · 128 GB SSD**

## Build the USB (on a Linux PC)

```bash
git clone https://github.com/ramchandragada/Aspera-OS.git
cd Aspera-OS
sudo scripts/fetch-vendor.sh
sudo scripts/build-iso.sh
```

ISO output: `aspera-os-1.0-amd64.iso`

## Existing Mint PCs (no wipe)

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/mint-to-aspera.yml
```

## Docs

- [Decisions](docs/DECISIONS.md)
- [Apps](docs/APPS.md)
- [Hardware](docs/HARDWARE.md)
- [Roadmap](docs/ROADMAP.md)
