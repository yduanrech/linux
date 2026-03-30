#!/usr/bin/env bash
# n8n-install.sh — instala ou atualiza o n8n em VM bare‑metal
# Coloque em /usr/local/sbin/n8n-install.sh  e  chmod +x

set -euo pipefail

##### DETECÇÃO DE IP ##########################################################
if [[ -z "${HOST_IP:-}" ]]; then
  HOST_IP="$(hostname -I | tr ' ' '\n' | grep -v '^127\.' | head -n1)"
  [[ -z "$HOST_IP" ]] && { echo "[ERRO] Não consegui detectar IP. Defina HOST_IP."; exit 1; }
fi
echo "[INFO] HOST_IP = $HOST_IP"
###############################################################################

##### DEFAULTS DAS VARIÁVEIS DE AMBIENTE ######################################
GENERIC_TIMEZONE="${GENERIC_TIMEZONE:-America/Sao_Paulo}"
N8N_DEFAULT_LOCALE="${N8N_DEFAULT_LOCALE:-pt_BR}"
N8N_HOST="${N8N_HOST:-$HOST_IP}"
N8N_PROTOCOL="${N8N_PROTOCOL:-http}"
N8N_PORT="${N8N_PORT:-5678}"                       # porta padrão
WEBHOOK_URL="${WEBHOOK_URL:-${N8N_PROTOCOL}://${N8N_HOST}}"

: "${N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS:=false}"
: "${N8N_RUNNERS_ENABLED:=true}"
: "${N8N_SECURE_COOKIE:=false}"
: "${N8N_DIAGNOSTICS_ENABLED:=false}"
: "${N8N_RELEASE_TYPE:=stable}"
###############################################################################

log() { printf '\e[1;34m[INFO]\e[0m %s\n' "$*"; }
installed() { systemctl list-unit-files n8n.service &>/dev/null; }

ensure_node() {
  # ::: ALTERADO: agora checa e instala Node 22.x LTS :::
  if ! command -v node >/dev/null || [[ $(node -v) != v22.* ]]; then
    log "Instalando Node.js 22.x LTS..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get update
    apt-get install -y nodejs
  fi
  command -v npm >/dev/null || apt-get install -y npm
}

install_n8n() {
  log "Instalando n8n..."
  ensure_node
  npm install -g n8n

  # Cria usuário de serviço com diretório home
  id -u n8n &>/dev/null || useradd --system --create-home --home-dir /home/n8n --shell /usr/sbin/nologin n8n

  # Pastas de dados e logs
  install -d -o n8n -g n8n /var/lib/n8n /var/log/n8n

  cat >/etc/systemd/system/n8n.service <<EOF
[Unit]
Description=n8n workflow automation
After=network.target

[Service]
Type=simple
User=n8n
Environment="GENERIC_TIMEZONE=$GENERIC_TIMEZONE"
Environment="N8N_DEFAULT_LOCALE=$N8N_DEFAULT_LOCALE"
Environment="N8N_HOST=$N8N_HOST"
Environment="N8N_PROTOCOL=$N8N_PROTOCOL"
Environment="WEBHOOK_URL=$WEBHOOK_URL"
Environment="N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=$N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS"
Environment="N8N_RUNNERS_ENABLED=$N8N_RUNNERS_ENABLED"
Environment="N8N_SECURE_COOKIE=$N8N_SECURE_COOKIE"
Environment="N8N_DIAGNOSTICS_ENABLED=$N8N_DIAGNOSTICS_ENABLED"
Environment="N8N_PORT=$N8N_PORT"
Environment="N8N_USER_FOLDER=/var/lib/n8n"
ExecStart=/usr/bin/env n8n
WorkingDirectory=/var/lib/n8n
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now n8n
  log "n8n instalado e ativo em ${N8N_PROTOCOL}://${N8N_HOST}:${N8N_PORT}"
}

update_n8n() {
  local CURRENT_VER
  CURRENT_VER="$(n8n --version 2>/dev/null || echo 'unknown')"
  log "Current n8n version: $CURRENT_VER"

  # Backup SQLite database before update (migrations can't be rolled back)
  local DB_FILE="/var/lib/n8n/.n8n/database.sqlite"
  if [[ -f "$DB_FILE" ]]; then
    local BACKUP="${DB_FILE}.bak-$(date +%F-%H%M%S)"
    log "Backing up database to $BACKUP"
    cp "$DB_FILE" "$BACKUP"
  fi

  log "Updating n8n..."
  ensure_node
  npm install -g n8n@latest
  systemctl restart n8n

  local NEW_VER
  NEW_VER="$(n8n --version 2>/dev/null || echo 'unknown')"
  log "n8n updated: $CURRENT_VER → $NEW_VER"
}

##### MAIN ####################################################################
if installed; then
  update_n8n
else
  install_n8n
fi