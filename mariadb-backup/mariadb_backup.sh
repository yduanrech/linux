#!/usr/bin/env bash
# mariadb_backup.sh
# Backup lógico de DBs selecionadas (um .sql.gz por DB) + envio opcional ao Proxmox Backup Server (PBS)
# Configuração única em: /etc/mariadb-backup.conf

set -euo pipefail
umask 077

CONF="/etc/mariadb-backup.conf"
if [ ! -r "$CONF" ]; then
  echo "Error: config file not readable: $CONF"
  exit 1
fi
# shellcheck disable=SC1090
. "$CONF"

# ---- validações mínimas ----
: "${INCLUDEDB:?INCLUDEDB is required in $CONF}"
: "${STORAGEDIR:=/srv/backup/mariadb}"
: "${LOGDIR:=/var/log/backup}"
: "${ROTATION_DAYS:=14}"

: "${DB_HOST:=localhost}"
: "${DB_PORT:=3306}"
: "${DB_USER:?DB_USER is required in $CONF}"
: "${DB_PASS:?DB_PASS is required in $CONF}"

PBS_ENABLE="${PBS_ENABLE:-0}"
PBS_BACKUP_TYPE="${PBS_BACKUP_TYPE:-host}"
PBS_BACKUP_ID="${PBS_BACKUP_ID:-$(hostname -s)}"
PBS_ARCHIVE_NAME="${PBS_ARCHIVE_NAME:-mariadb}"
PBS_SOURCE_PATH="${PBS_SOURCE_PATH:-$STORAGEDIR}"
PBS_REPOSITORY="${PBS_REPOSITORY:-}"
PBS_PASSWORD="${PBS_PASSWORD:-}"
PBS_FINGERPRINT="${PBS_FINGERPRINT:-}"

MYSQL_BIN="$(command -v mariadb || command -v mysql)"
DUMP_BIN="$(command -v mariadb-dump || command -v mysqldump)"
GZIP_BIN="$(command -v gzip)"
PBS_CLIENT_BIN="$(command -v proxmox-backup-client || true)"

NOW="$(date -u +"%Y-%m-%dT%H%M%SZ")"
DAY="$(date +"%Y-%m-%d")"
BACKUPDIR="$STORAGEDIR/$DAY"
LOGFILE="$LOGDIR/$DAY-mariadb-backup.log"
TMPERR="/tmp/$DAY-mariadb-backup.tmp.log"

cleanup() { rm -f "$TMPERR"; }
trap cleanup EXIT

mkdir -p "$BACKUPDIR" "$LOGDIR"
exec &>"$LOGFILE"

echo "Info: Starting backup at $(date '+%F %T')"
echo "Info: BACKUPDIR=$BACKUPDIR"
echo "Info: INCLUDEDB=$INCLUDEDB"
echo "Info: DB_HOST=$DB_HOST DB_PORT=$DB_PORT DB_USER=$DB_USER"

# conexão: usa MYSQL_PWD para não aparecer senha no ps (a senha fica no arquivo de config)
export MYSQL_PWD="$DB_PASS"

# testa conexão
"$MYSQL_BIN" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -NBe "SELECT 1;" 2>>"$TMPERR" >/dev/null

db_exists() {
  local db="$1"
  "$MYSQL_BIN" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -NBe \
    "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${db//\'/\'\'}';" \
    2>>"$TMPERR" | grep -qx "$db"
}

OK_COUNT=0
FAIL_COUNT=0

for db in $INCLUDEDB; do
  echo -e "\nInfo: Selected DB: $db"

  if ! db_exists "$db"; then
    echo "Error: Database does not exist: $db"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi

  OUTFILE="$BACKUPDIR/${db}_${NOW}.sql.gz"
  echo "Info: Dumping -> $OUTFILE"

  if "$DUMP_BIN" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" \
      --databases "$db" \
      --single-transaction --quick \
      --routines --events --triggers \
      --hex-blob --set-charset \
      2>>"$TMPERR" \
      | "$GZIP_BIN" -9 > "$OUTFILE"; then

    if gunzip -t "$OUTFILE"; then
      echo "Info: OK: $db"
      ls -alh "$OUTFILE"
      OK_COUNT=$((OK_COUNT + 1))
    else
      echo "Error: gzip integrity FAILED for $OUTFILE"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    echo "Error: dump FAILED for DB $db"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

echo -e "\nInfo: Summary: OK=$OK_COUNT FAIL=$FAIL_COUNT"

# Envio PBS (somente se tudo OK)
if [ "$FAIL_COUNT" -eq 0 ] && [ "$PBS_ENABLE" = "1" ]; then
  echo -e "\nInfo: PBS enabled."

  if [ -z "$PBS_CLIENT_BIN" ]; then
    echo "Error: proxmox-backup-client not found."
    FAIL_COUNT=$((FAIL_COUNT + 1))
  elif [ -z "$PBS_REPOSITORY" ] || [ -z "$PBS_PASSWORD" ]; then
    echo "Error: PBS_REPOSITORY e PBS_PASSWORD precisam estar definidos em $CONF"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    PBS_BACKUP_ID="${PBS_BACKUP_ID// /_}"
    PBS_ARCHIVE_NAME="$(echo -n "$PBS_ARCHIVE_NAME" | tr -c 'A-Za-z0-9_-' '_' )"

    export PBS_REPOSITORY="$PBS_REPOSITORY"
    export PBS_PASSWORD="$PBS_PASSWORD"
    [ -n "$PBS_FINGERPRINT" ] && export PBS_FINGERPRINT

    echo "Info: Uploading $PBS_SOURCE_PATH as ${PBS_ARCHIVE_NAME}.pxar"
    echo "Info: PBS group: $PBS_BACKUP_TYPE/$PBS_BACKUP_ID"

    if "$PBS_CLIENT_BIN" backup \
        "${PBS_ARCHIVE_NAME}.pxar:${PBS_SOURCE_PATH}" \
        --backup-type "$PBS_BACKUP_TYPE" \
        --backup-id "$PBS_BACKUP_ID" \
        2>>"$TMPERR"; then
      echo "Info: PBS upload OK."
    else
      echo "Error: PBS upload FAILED."
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi
fi

# Rotação local (somente se tudo OK)
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "Info: Rotating backups older than $ROTATION_DAYS day(s)"
  find "$STORAGEDIR" -type f -name "*.sql.gz" -mtime +"$ROTATION_DAYS" -delete
else
  echo "Error: Some steps failed; rotation skipped."
fi

echo "Info: Done."
exit "$FAIL_COUNT"
