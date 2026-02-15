# `mariadb-backup/mariadb_backup.sh`

Backup lógico de databases MariaDB selecionadas (`.sql.gz`) com envio opcional ao Proxmox Backup Server (PBS).

## Executar

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/mariadb-backup/mariadb_backup.sh)"
```

## Arquivo de configuração obrigatório

O script lê `/etc/mariadb-backup.conf`.

## Documentação detalhada

- `mariadb-backup/readme.md`

Esse arquivo já contém:

- modelo completo de `/etc/mariadb-backup.conf`
- exemplo de cron
- exemplo de restore
- recomendações de segurança

