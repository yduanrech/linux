# Linux Scripts

[English](./README.md)

Scripts de automação para Ubuntu/Debian com foco em setup inicial, updates, observabilidade e utilitários.

## Resumo Rápido

| Script | Função | Execução |
|---|---|---|
| `initial-settings.sh` | Menu de configuração inicial para timezone, locale, SSH, journald, autologout e unattended-upgrades | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/initial-settings.sh)"` |
| `unattended-upgrades-install.sh` | Configura unattended-upgrades com ou sem notificações por e-mail | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/unattended-upgrades-install.sh)"` |
| `qemu-agent-install.sh` | Instala e habilita `qemu-guest-agent` | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/qemu-agent-install.sh)"` |
| `btop-install.sh` | Instala `btop` para `x86_64` e `aarch64` | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/btop-install.sh)"` |
| `caddy-acme-install.sh` | Instala o pacote oficial do Caddy com `acme.sh`, ou apenas `acme.sh` para outros servidores web usando Cloudflare DNS-01 | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)"` |
| `n8n-install.sh` | Instala ou atualiza `n8n` com serviço systemd | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/n8n-install.sh)"` |
| `gickup-install.sh` | Instala ou atualiza Gickup para Linux amd64 para fazer mirror de GitHub para Codeberg com systemd | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)"` |
| `individuais/autologout-install.sh` | Configura autologout global com `TMOUT=900` | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/individuais/autologout-install.sh)"` |
| `individuais/limit-journal.sh` | Ajusta retenção e tamanho do `journald` | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/individuais/limit-journal.sh)"` |
| `mariadb-backup/mariadb_backup.sh` | Executa backup lógico do MariaDB com envio opcional para PBS | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/mariadb-backup/mariadb_backup.sh)"` |
| `fix/fix-unattended-upgrades.sh` | Corrige unattended-upgrades em servidores existentes, incluindo `reboot-with-users`, parâmetros periódicos e configuração de cronjob | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/fix/fix-unattended-upgrades.sh)"` |

## Documentação por Script

A documentação detalhada dos scripts está em `docs/scripts/`:

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

- `caddy/examples/`: exemplos de `Caddyfile` para PVE, PBS, UniFi, Uptime Kuma e n8n

## Notas

- A maior parte dos scripts exige `root` via `sudo`.
- Os scripts foram escritos para sistemas Ubuntu/Debian.
