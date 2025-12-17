# Backup MariaDB — Databases selecionadas (um .sql.gz por DB)

Este guia descreve como usar o script `backup_mariadb.sh` para fazer **backup lógico** (SQL) de **apenas algumas databases**, salvando **arquivos separados** (`.sql.gz`) por database, com **logs** e **rotação**.

---

## O que este script faz

- Faz backup lógico (SQL) **somente** das databases definidas em `INCLUDEDB`
- Gera **um arquivo separado por database**: `DBNAME_timestamp.sql.gz`
- Cria um diretório por dia: `.../YYYY-MM-DD/`
- Comprime com gzip e valida integridade (`gunzip -t`)
- Grava log diário em `/var/log/backup`
- Rotaciona backups antigos (apaga `.sql.gz` com mais de N dias) **somente se não houver falhas**
- Opcional: envia e-mail se houver erro (se habilitado)

---

## Caminhos padrão

- Script: `/usr/local/sbin/backup_mariadb.sh`
- Credenciais: `/etc/mariadb/backup.cnf`
- Backups: `/srv/backup/mariadb/YYYY-MM-DD/`
- Logs: `/var/log/backup/YYYY-MM-DD-mariadb-backup.log`

---

## Variáveis configuráveis

Você pode configurar por **variáveis de ambiente** (cron/linha de comando) **ou** por arquivo `/etc/default` (recomendado).

### Obrigatória
- `INCLUDEDB`: lista das databases a salvar  
  Exemplo por espaço: `INCLUDEDB="erp financeiro site"`  
  Exemplo por linhas:

```bash
INCLUDEDB="
erp
financeiro
site
"
```

### Opcionais
- `STORAGEDIR` (padrão `/srv/backup/mariadb`)
- `LOGDIR` (padrão `/var/log/backup`)
- `ROTATION_DAYS` (padrão `14`)
- `DEFAULTS_FILE` (padrão `/etc/mariadb/backup.cnf`)
- `SENDMAIL` (padrão `0`; use `1` para habilitar)
- `MAILREC` (destinatário do e-mail)

---

## Pré-requisitos (Ubuntu 22.04 / MariaDB 11)

```bash
sudo apt update
sudo apt install -y mariadb-client gzip
```

Para envio de e-mail (opcional):

```bash
sudo apt install -y bsd-mailx
```

---

## Criar usuário de backup (somente localhost)

> Recomendação: usar um usuário dedicado `backup` permitido **apenas em `localhost`**.

Entre no MariaDB como root (no Ubuntu geralmente funciona via socket):

```bash
sudo mariadb
```

Crie o usuário:

```sql
CREATE USER 'backup'@'localhost' IDENTIFIED BY 'SENHA_FORTE_AQUI';
```

Conceda permissões **somente** nas databases que você vai backupear (exemplos):

```sql
GRANT SELECT, SHOW VIEW, TRIGGER, EVENT, LOCK TABLES
ON `erp`.* TO 'backup'@'localhost';

GRANT SELECT, SHOW VIEW, TRIGGER, EVENT, LOCK TABLES
ON `financeiro`.* TO 'backup'@'localhost';

GRANT SELECT, SHOW VIEW, TRIGGER, EVENT, LOCK TABLES
ON `site`.* TO 'backup'@'localhost';

FLUSH PRIVILEGES;
```

> Dica: se você mudar a lista de bancos, lembre de ajustar os GRANTs para refletir a mesma lista.

---

## Criar o arquivo de credenciais `/etc/mariadb/backup.cnf`

Crie o diretório e o arquivo com permissões seguras:

```bash
sudo install -d -m 700 /etc/mariadb

sudo bash -c 'cat > /etc/mariadb/backup.cnf <<EOF
[client]
host=localhost
port=3306
user=backup
password=SENHA_FORTE_AQUI
EOF'

sudo chmod 600 /etc/mariadb/backup.cnf
sudo chown root:root /etc/mariadb/backup.cnf
```

Teste:

```bash
mariadb --defaults-extra-file=/etc/mariadb/backup.cnf -e "SELECT CURRENT_USER(), @@version;"
```

---

## Instalação do script

1. Salve o script em:

```bash
sudo nano /usr/local/sbin/backup_mariadb.sh
```

2. Permissões:

```bash
sudo chmod 750 /usr/local/sbin/backup_mariadb.sh
sudo chown root:root /usr/local/sbin/backup_mariadb.sh
```

3. Pastas (opcional):

```bash
sudo mkdir -p /srv/backup/mariadb /var/log/backup
sudo chmod 750 /srv/backup/mariadb /var/log/backup
sudo chown root:root /srv/backup/mariadb /var/log/backup
```

---

## Por que inserir variáveis junto do cron?

O **cron roda com ambiente mínimo** (quase sem variáveis). Ao colocar variáveis na linha do cron, você garante que o script rode **sempre com as configurações esperadas** sem precisar editar o script.

Exemplo:

```cron
0 2 * * * root INCLUDEDB="erp financeiro site" ROTATION_DAYS=14 /usr/local/sbin/backup_mariadb.sh
```

### Vantagens

* Evita editar o script para mudar a lista de bancos ou retenção
* Permite ter **mais de um job** usando o mesmo script com configurações diferentes
* Deixa explícito no cron o que está sendo backupeado

---

## Alternativa recomendada: arquivo de configuração `/etc/default`

Se você prefere **não** colocar variáveis no cron, use um arquivo de config padrão do Debian/Ubuntu:

### 1) Criar `/etc/default/mariadb-backup-selected`

```bash
sudo bash -c 'cat > /etc/default/mariadb-backup-selected <<EOF
INCLUDEDB="erp financeiro site"
ROTATION_DAYS=14
STORAGEDIR="/srv/backup/mariadb"
LOGDIR="/var/log/backup"
DEFAULTS_FILE="/etc/mariadb/backup.cnf"
SENDMAIL=0
MAILREC=""
EOF'
sudo chmod 600 /etc/default/mariadb-backup-selected
sudo chown root:root /etc/default/mariadb-backup-selected
```

### 2) Ajuste necessário no script

No começo do script (logo após o `umask 077`), adicione:

```bash
[ -r /etc/default/mariadb-backup-selected ] && . /etc/default/mariadb-backup-selected
```

### 3) Cron fica “limpo”

```cron
0 2 * * * root /usr/local/sbin/backup_mariadb.sh
```

---

## Como rodar manualmente

Com variáveis na linha:

```bash
sudo INCLUDEDB="erp financeiro site" /usr/local/sbin/backup_mariadb.sh
```

Ou usando `/etc/default` (se você aplicou o include no script):

```bash
sudo /usr/local/sbin/backup_mariadb.sh
```

---

## Onde ficam os backups

Exemplo:

* `/srv/backup/mariadb/2025-12-17/erp_2025-12-17T020000Z.sql.gz`
* `/srv/backup/mariadb/2025-12-17/financeiro_2025-12-17T020000Z.sql.gz`

---

## Como restaurar (exemplo)

Para restaurar `erp`:

```bash
gunzip -c /srv/backup/mariadb/2025-12-17/erp_*.sql.gz | mariadb
```

Ou usando o `.cnf`:

```bash
gunzip -c /srv/backup/mariadb/2025-12-17/erp_*.sql.gz | mariadb --defaults-extra-file=/etc/mariadb/backup.cnf
```

---

## Checklist rápido de validação

* Credenciais funcionam:

  ```bash
  mariadb --defaults-extra-file=/etc/mariadb/backup.cnf -e "SELECT 1;"
  ```
* Rodar o script manual uma vez e conferir:

  * arquivos `.sql.gz` criados (um por DB)
  * log diário em `/var/log/backup/`
  * rotação após `ROTATION_DAYS`

