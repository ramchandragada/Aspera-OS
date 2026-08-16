# Ansible for Aspera OS

1. Copy `inventory/hosts.yml.example` to `inventory/hosts.yml` and add PCs.
2. On the control machine: `sudo ../scripts/fetch-vendor.sh`
3. Run: `ansible-playbook playbooks/mint-to-aspera.yml`
