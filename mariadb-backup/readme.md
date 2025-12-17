# MariaDB Backup (DBs selecionadas) + PBS — método de **configuração única**

Este método usa **1 arquivo de configuração** para tudo: MariaDB + PBS + caminhos + lista de DBs.

- Script: `mariadb_backup.sh`
- Config única: `/etc/mariadb-backup.conf`
- Cron: 1 linha (limpo)

> Nota: neste método o **DB_PASS** e o **PBS_PASSWORD** ficam no mesmo arquivo de config. Mantenha `chmod 600` e dono `root:root`.

---

## 1) Pré-requisitos

No Ubuntu 22.04:
```bash
sudo apt update
sudo apt install -y mariadb-client gzip
```

Para enviar ao PBS (opcional), você precisa do `proxmox-backup-client` disponível no ambiente onde roda o script.

---

## 2) Instalar o script

Copie o `mariadb_backup.sh` para:
```bash
sudo install -m 750 -o root -g root mariadb_backup.sh /usr/local/sbin/mariadb_backup.sh
```

---

## 3) Criar o arquivo único de configuração

Crie `/etc/mariadb-backup.conf`:
```bash
sudo bash -c 'cat > /etc/mariadb-backup.conf <<EOF
# ===========================
# MariaDB Backup + PBS
# Configuração única
# ===========================

# ---- MariaDB ----
# Databases (separadas por espaço)
INCLUDEDB="erp financeiro site"

DB_HOST="localhost"
DB_PORT="3306"
DB_USER="backup"
DB_PASS="SENHA_FORTE_AQUI"

# ---- Pastas ----
STORAGEDIR="/srv/backup/mariadb"
LOGDIR="/var/log/backup"
ROTATION_DAYS="14"

# ---- PBS (opcional) ----
PBS_ENABLE="0"   # 1 = enviar ao PBS; 0 = não enviar

# Formato: user@pbs!token@pbs-host:datastore
PBS_REPOSITORY="usuario@pbs!token@pbs-host:datastore1"
PBS_PASSWORD="TOKEN_SECRET_AQUI"

# Como aparece no PBS: <type>/<id>/<timestamp>
PBS_BACKUP_TYPE="host"
PBS_BACKUP_ID="SRVAPP02"
PBS_ARCHIVE_NAME="mariadb"

# O que enviar para o PBS (pasta que contém todas as datas)
PBS_SOURCE_PATH="/srv/backup/mariadb"

# Opcional (se precisar):
# PBS_FINGERPRINT="AA:BB:CC:..."
EOF'
sudo chmod 600 /etc/mariadb-backup.conf
sudo chown root:root /etc/mariadb-backup.conf
```

Se você não vai usar PBS ainda:
- deixe `PBS_ENABLE="0"` (pode deixar `PBS_*` como está)

---

## 4) Rodar manualmente (teste)

```bash
sudo /usr/local/sbin/mariadb_backup.sh
```

Saída esperada:
- Backups em: `/srv/backup/mariadb/YYYY-MM-DD/*.sql.gz`
- Log em: `/var/log/backup/YYYY-MM-DD-mariadb-backup.log`

---

## 5) Cron (limpo)

Exemplo: todo dia às 02:00
```cron
0 2 * * * root /usr/local/sbin/mariadb_backup.sh
```

---

## 6) Restore (exemplo)

Para restaurar a DB `erp` a partir de um `.sql.gz`:
```bash
gunzip -c /srv/backup/mariadb/2025-12-17/erp_*.sql.gz | mariadb
```

---

## Segurança (resumo rápido)

- O arquivo `/etc/mariadb-backup.conf` contém segredos: mantenha `chmod 600`.
- Rode o script como `root` (cron root) para garantir acesso aos diretórios e ao arquivo de config.
