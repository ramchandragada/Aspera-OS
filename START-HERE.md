# Start here — Aspera OS

1. Read [README.md](README.md) (what this is).
2. Decisions are locked in [docs/DECISIONS.md](docs/DECISIONS.md).
3. On the build PC (Ubuntu/Mint):

```bash
cd ~/Aspera-OS   # or wherever you clone
sudo scripts/fetch-vendor.sh
sudo scripts/build-iso.sh
```

4. Boot `aspera-os-1.0-amd64.iso` (VirtualBox: EFI off, 4 GB+ RAM).
5. Existing Mint desks: Ansible — see `ansible/README.md`.
