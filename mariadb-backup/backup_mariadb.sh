#!/usr/bin/env bash
# backup_mariadb_selected_dbs.sh
# Backup lógico (SQL) de databases selecionadas, cada uma em seu .sql.gz, com log e rotação.

set -euo pipefail
umask 077

# ====== CONFIG ======
STORAGEDIR="${STORAGEDIR:-/srv/backup/mariadb}"
LOGDIR="${LOGDIR:-/var/log/backup}"
ROTATION_DAYS="${ROTATION_DAYS:-14}"
DEFAULTS_FILE="${DEFAULTS_FILE:-/etc/mariadb/backup.cnf}"

# Coloque aqui as databases que você quer (separadas por espaço OU uma por linha)
# Ex.: INCLUDEDB="erp financeiro site"
# ou:
# INCLUDEDB="
# erp
# financeiro
# site
# "
INCLUDEDB="${INCLUDEDB:-}"

# E-mail em erro (opcional)
SENDMAIL="${SENDMAIL:-0}"
MAILREC="${MAILREC:-}"

# ====== BINÁRIOS ======
MYSQL_BIN="$(command -v mariadb || command -v mysql)"
DUMP_BIN="$(command -v mariadb-dump || command -v mysqldump)"
GZIP_BIN="$(command -v gzip)"
MAIL_BIN="$(command -v mail || true)"

# ====== DATA / PATHS ======
NOW="$(date -u +"%Y-%m-%dT%H%M%SZ")"
DAY="$(date +"%Y-%m-%d")"
BACKUPDIR="$STORAGEDIR/$DAY"
LOGFILE="$LOGDIR/$DAY-mariadb-backup.log"
TMPERR="/tmp/$DAY-mariadb-backup.tmp.log"

mkdir -p "$BACKUPDIR" "$LOGDIR"
exec &>"$LOGFILE"

echo "Info: Starting backup at $(date '+%F %T')"
echo "Info: BACKUPDIR=$BACKUPDIR"
echo "Info: DEFAULTS_FILE=$DEFAULTS_FILE"
echo "Info: dump bin=$DUMP_BIN"

if [ ! -r "$DEFAULTS_FILE" ]; then
  echo "Error: defaults file not readable: $DEFAULTS_FILE"
  exit 1
fi

if [ -z "${INCLUDEDB//[[:space:]]/}" ]; then
  echo "Error: INCLUDEDB está vazio. Defina quais databases serão salvas."
  echo "Example: INCLUDEDB=\"erp financeiro\""
  exit 1
fi

# Testa conexão
"$MYSQL_BIN" --defaults-extra-file="$DEFAULTS_FILE" -NBe "SELECT 1;" 2>>"$TMPERR" >/dev/null

# Função: checa se DB existe
db_exists() {
  local db="$1"
  "$MYSQL_BIN" --defaults-extra-file="$DEFAULTS_FILE" -NBe \
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

  if "$DUMP_BIN" --defaults-extra-file="$DEFAULTS_FILE" \
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

# Rotação só se não houve falha
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "Info: Rotating backups older than $ROTATION_DAYS day(s)"
  find "$STORAGEDIR" -type f -name "*.sql.gz" -mtime +"$ROTATION_DAYS" -delete
else
  echo "Error: Some backups failed; rotation skipped."
fi

echo "Info: Done."

# E-mail em erro (opcional)
if [ "$SENDMAIL" = "1" ] && [ -n "$MAILREC" ] && [ -n "$MAIL_BIN" ]; then
  if [ "$FAIL_COUNT" -ne 0 ] || grep -q 'Error' "$LOGFILE" || ( [ -s "$TMPERR" ] && grep -qiE 'error|denied|failed' "$TMPERR" ); then
    {
      echo "Host: $(hostname -f)"
      echo "When: $(date '+%F %T')"
      echo
      echo "==== LOG ===="
      cat "$LOGFILE"
      echo
      echo "==== STDERR ===="
      [ -f "$TMPERR" ] && cat "$TMPERR" || true
    } | "$MAIL_BIN" -s "$(hostname -f) - MariaDB backup error" "$MAILREC"
  fi
fi
