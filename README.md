# Linux Scripts

[Portuguese (Brazil)](./README.pt-BR.md)

Automation scripts for Ubuntu/Debian covering initial setup, updates, observability, and utilities.

## Quick Overview

| Script | Purpose | Run |
|---|---|---|
| `initial-settings.sh` | Initial setup menu for timezone, locale, SSH, journald, autologout, and unattended-upgrades | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/initial-settings.sh)"` |
| `unattended-upgrades-install.sh` | Configures unattended-upgrades with or without email notifications | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/unattended-upgrades-install.sh)"` |
| `qemu-agent-install.sh` | Installs and enables `qemu-guest-agent` | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/qemu-agent-install.sh)"` |
| `btop-install.sh` | Installs `btop` for `x86_64` and `aarch64` | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/btop-install.sh)"` |
| `caddy-acme-install.sh` | Installs the official Caddy package plus `acme.sh`, or only `acme.sh` for other web servers using Cloudflare DNS-01 | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)"` |
| `n8n-install.sh` | Installs or updates `n8n` with a systemd service | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/n8n-install.sh)"` |
| `gickup-install.sh` | Installs or updates Gickup for Linux amd64 to mirror GitHub to Codeberg with systemd | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)"` |
| `individuais/autologout-install.sh` | Configures global autologout with `TMOUT=900` | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/individuais/autologout-install.sh)"` |
| `individuais/limit-journal.sh` | Adjusts `journald` retention and size | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/individuais/limit-journal.sh)"` |
| `mariadb-backup/mariadb_backup.sh` | Runs logical MariaDB backups with optional PBS upload | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/mariadb-backup/mariadb_backup.sh)"` |
| `fix/fix-unattended-upgrades.sh` | Fixes unattended-upgrades on existing servers, including `reboot-with-users`, periodic settings, and cronjob configuration | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/fix/fix-unattended-upgrades.sh)"` |

## Script Documentation

Detailed script documentation is available in `docs/scripts/`:

- `docs/scripts/initial-settings.md`
- `docs/scripts/unattended-upgrades-install.md`
- `docs/scripts/qemu-agent-install.md`
- `docs/scripts/btop-install.md`
- `docs/scripts/caddy-acme-install.md`
- `docs/scripts/n8n-install.md`
- `docs/scripts/gickup-install.md`
- `docs/scripts/autologout-install.md`
- `docs/scripts/limit-journal.md`
- `docs/scripts/mariadb-backup.md`

## Extras

- `caddy/examples/`: sample `Caddyfile` configurations for PVE, PBS, UniFi, Uptime Kuma, and n8n

## Notes

- Most scripts require `root` via `sudo`.
- The scripts target Ubuntu/Debian systems.
