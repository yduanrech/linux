# Linux Scripts

Scripts de automação para Ubuntu/Debian (setup inicial, updates, observabilidade e utilitários).

## Resumo Rápido

| Script | Função | Execução |
|---|---|---|
| `initial-settings.sh` | Menu de configuração inicial (timezone, locale, SSH, journald, autologout, unattended-upgrades) | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/initial-settings.sh)"` |
| `unattended-upgrades-install.sh` | Configura unattended-upgrades com ou sem envio de e-mail | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/unattended-upgrades-install.sh)"` |
| `qemu-agent-install.sh` | Instala e habilita `qemu-guest-agent` | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/qemu-agent-install.sh)"` |
| `btop-install.sh` | Instala `btop` (x86_64/aarch64) | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/btop-install.sh)"` |
| `n8n-install.sh` | Instala/atualiza `n8n` com serviço systemd | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/n8n-install.sh)"` |
| `individuais/autologout-install.sh` | Configura autologout global (`TMOUT=900`) | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/individuais/autologout-install.sh)"` |
| `individuais/limit-journal.sh` | Ajusta retenção e tamanho do `journald` | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/individuais/limit-journal.sh)"` |
| `mariadb-backup/mariadb_backup.sh` | Backup lógico MariaDB com envio opcional ao PBS | `bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/mariadb-backup/mariadb_backup.sh)"` |

## Documentação por Script

- `docs/scripts/initial-settings.md`
- `docs/scripts/unattended-upgrades-install.md`
- `docs/scripts/qemu-agent-install.md`
- `docs/scripts/btop-install.md`
- `docs/scripts/n8n-install.md`
- `docs/scripts/autologout-install.md`
- `docs/scripts/limit-journal.md`
- `docs/scripts/mariadb-backup.md`

## Notas

- A maior parte dos scripts exige `root` (`sudo`).
- Os scripts foram escritos para Ubuntu/Debian.




