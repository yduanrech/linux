#!/usr/bin/env bash
#
# initial-settings.sh
# Interactive menu for initial Linux server setup
# Includes: timezone, locale, SSH, journald, autologout, unattended-upgrades
# Tested on Ubuntu/Debian
# v2.0
#
set -euo pipefail

VERSION="2.0"
LOG_FILE="/var/log/initial-settings.log"
DRY_RUN=false
SUMMARY=()

# --- Utility functions ---

# Log: writes to file and displays on screen
log() {
  echo "$*"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Safe config file loader (does not execute code, only reads key=value pairs)
safe_load_conf() {
  local conf_file="$1"
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    read -r key <<< "$key"
    read -r value <<< "$value"
    value="${value#\"}" ; value="${value%\"}"
    value="${value#\'}" ; value="${value%\'}"
    case "$key" in
      MAIL_TO|GENERIC_FROM|RELAY|SMTP_USER|SMTP_PASS|MAIL_SENDER)
        declare -g "$key=$value"
        ;;
    esac
  done < "$conf_file"
}

# Display summary of completed actions
show_summary() {
  if [[ ${#SUMMARY[@]} -gt 0 ]]; then
    echo ""
    echo "═══════════════════════════════════════"
    echo "              SUMMARY"
    echo "═══════════════════════════════════════"
    for item in "${SUMMARY[@]}"; do
      echo "  ✅ $item"
    done
    echo "═══════════════════════════════════════"
    echo ""
  fi
}

# Display help
show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [OPTION_NUMBERS...]

Interactive menu for initial Linux server setup.

Options:
  --dry-run    Show what would be done without making changes
  -h, --help   Show this help message

Option numbers (can be combined):
  1   Timezone, locale, and SSH
  2   Limit journald usage
  3   Configure autologout (15 min)
  4   Unattended-upgrades (with email)
  5   Unattended-upgrades (without email)
  A   All options (1-5)

Examples:
  $(basename "$0")              # Interactive menu
  $(basename "$0") 1 3          # Run options 1 and 3
  $(basename "$0") --dry-run A  # Dry-run all options
EOF
}

# --- Feature functions ---

# Function: Initial setup (timezone, locale, SSH)
config_inicial() {
  log "[1/4] Configurando fuso horário para America/Sao_Paulo..."
  if [[ "$DRY_RUN" != "true" ]]; then
    timedatectl set-timezone America/Sao_Paulo
    log "✅ Fuso horário configurado: $(timedatectl show --property=Timezone --value)"
  else
    log "[DRY-RUN] timedatectl set-timezone America/Sao_Paulo"
  fi

  log "[2/4] Gerando locale pt_BR.UTF-8..."
  if [[ "$DRY_RUN" != "true" ]]; then
    sed -i 's/^# *pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen
    locale-gen
  else
    log "[DRY-RUN] sed locale.gen + locale-gen"
  fi

  log "[3/4] Configurando locale padrão..."
  if [[ "$DRY_RUN" != "true" ]]; then
    update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8
  else
    log "[DRY-RUN] update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8"
  fi

  log "[4/4] Configurando segurança SSH..."
  read -r -p "Allow root SSH login with password? (y/n): " permitir_ssh
  if [[ "$permitir_ssh" =~ ^[Yy]$ ]]; then
    SSH_CONFIG="/etc/ssh/sshd_config"
    if [[ -f "$SSH_CONFIG" ]]; then
      if [[ "$DRY_RUN" != "true" ]]; then
        if grep -q "^PermitRootLogin" "$SSH_CONFIG"; then
          sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' "$SSH_CONFIG"
        else
          echo "PermitRootLogin yes" >> "$SSH_CONFIG"
        fi
        systemctl reload-or-restart sshd
      else
        log "[DRY-RUN] Set PermitRootLogin yes + reload sshd"
      fi
      log "✅ Root SSH login enabled with password"
      log "   ⚠️ WARNING: Consider using SSH keys instead of passwords"
    else
      log "⚠️ SSH config not found at $SSH_CONFIG"
    fi
  else
    log "⚠️ Root SSH login was not modified"
  fi

  log "✅ Initial setup complete!"
  log "   ➜ Locale set to pt_BR.UTF-8"
  log "   ➜ A system reboot is recommended to apply all changes"
  SUMMARY+=("Timezone, locale, SSH")
}

# Function: Limit journald usage
limitar_journald() {
  log "[JOURNALD] Configurando limites do journald..."
  CONF="/etc/systemd/journald.conf"
  declare -A PARAMS=(
    [SystemMaxUse]="300M"
    [SystemKeepFree]="500M"
    [SystemMaxFileSize]="50M"
    [MaxRetentionSec]="1month"
  )
  if [[ "$DRY_RUN" != "true" ]]; then
    for key in "${!PARAMS[@]}"; do
      value="${PARAMS[$key]}"
      if grep -Eq "^[#[:space:]]*${key}=" "$CONF"; then
        sed -ri "s|^[#[:space:]]*(${key}=).*|\1${value}|" "$CONF"
      else
        echo "${key}=${value}" >> "$CONF"
      fi
    done
    systemctl daemon-reload
    systemctl restart systemd-journald
    log "Limites do journald atualizados:"
    journalctl --disk-usage
  else
    for key in "${!PARAMS[@]}"; do
      log "[DRY-RUN] Set ${key}=${PARAMS[$key]}"
    done
  fi
  SUMMARY+=("Journald limits (300M max)")
}

# Function: Configure autologout
autologout_config() {
  log "[AUTOLOGOUT] Configurando logout automático após 15 minutos de inatividade..."
  if [[ "$DRY_RUN" != "true" ]]; then
    cat > /etc/profile.d/autologout.sh <<'EOF'
# /etc/profile.d/autologout.sh
# Encerra shells Bash inativos após 15min (900s)
TMOUT=900
readonly TMOUT
export TMOUT
EOF
  else
    log "[DRY-RUN] Would create /etc/profile.d/autologout.sh (TMOUT=900)"
  fi
  log "✅ Autologout configurado (TMOUT=900s)."
  log "   ➜ Open a new terminal or logout/login for all sessions to pick up the configuration."
  SUMMARY+=("Autologout (15min)")
}

# Function: Install unattended-upgrades
# Parameter: SKIP_EMAIL (true/false)
unattended_upgrades() {
  local SKIP_EMAIL="${1:-false}"
  local CONFIGURE_EMAIL=true
  local CONF_FILE=/etc/unattend.conf

  log ""
  log "[UNATTENDED-UPGRADES] Configurando atualizações automáticas..."

  # Load configuration safely
  if [[ -f "$CONF_FILE" ]]; then
    safe_load_conf "$CONF_FILE"

    # Validate required variables
    for var in MAIL_TO GENERIC_FROM RELAY SMTP_USER SMTP_PASS; do
      if [[ -z "${!var:-}" ]]; then
        log "Error: variable $var not defined in $CONF_FILE" >&2
        return 1
      fi
    done
  else
    if [[ "$SKIP_EMAIL" == "true" ]]; then
      log "Warning: $CONF_FILE not found. Continuing without email configuration..."
      CONFIGURE_EMAIL=false
    else
      # Loop to allow re-checking the file
      while true; do
        echo ""
        log "Warning: $CONF_FILE not found."
        echo "This config file contains SMTP credentials for email notifications."
        echo ""
        echo "Options:"
        echo "  [Y] Continue without email"
        echo "  [R] Re-check (waiting for you to create the file)"
        echo "  [N] Cancel"
        echo ""
        read -rp "Choose an option (y/r/N): " resposta
        case "$resposta" in
          [yY])
            log "Continuing without email configuration..."
            CONFIGURE_EMAIL=false
            break
            ;;
          [rR])
            log "Re-checking..."
            if [[ -f "$CONF_FILE" ]]; then
              log "✅ File found! Loading configuration..."
              safe_load_conf "$CONF_FILE"
              # Validate required variables
              for var in MAIL_TO GENERIC_FROM RELAY SMTP_USER SMTP_PASS; do
                if [[ -z "${!var:-}" ]]; then
                  log "Error: variable $var not defined in $CONF_FILE" >&2
                  return 1
                fi
              done
              CONFIGURE_EMAIL=true
              break
            else
              log "⚠️ File still not found. Try again."
            fi
            ;;
          *)
            log "Operation cancelled." >&2
            return 1
            ;;
        esac
      done
    fi
  fi

  # Prepare safe cleanup of CONF_FILE
  cleanup_conf() {
    if [[ -f "$CONF_FILE" ]]; then
      shred -u "$CONF_FILE" 2>/dev/null || rm -f "$CONF_FILE"
    fi
  }
  trap cleanup_conf EXIT

  # Split host and port from RELAY
  local RELAY_HOST=""
  local RELAY_PORT=""
  if [[ "$CONFIGURE_EMAIL" == "true" ]]; then
    if [[ "$RELAY" == *:* ]]; then
      RELAY_HOST="${RELAY%%:*}"
      RELAY_PORT="${RELAY##*:}"
    else
      RELAY_HOST="$RELAY"
      RELAY_PORT="25"
    fi
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would install unattended-upgrades, update-notifier-common"
    [[ "$CONFIGURE_EMAIL" == "true" ]] && log "[DRY-RUN] Would install postfix, mailutils, libsasl2-modules"
    log "[DRY-RUN] Would configure 50unattended-upgrades and 20auto-upgrades"
    [[ "$CONFIGURE_EMAIL" == "true" ]] && log "[DRY-RUN] Would configure Postfix SMTP relay"
    log "[DRY-RUN] Would add cron job: 0 1 * * * /usr/bin/unattended-upgrade -v"
    log "[DRY-RUN] Would enable unattended-upgrades service"
    if [[ "$CONFIGURE_EMAIL" == "true" ]]; then
      SUMMARY+=("Unattended-upgrades with email (dry-run)")
    else
      SUMMARY+=("Unattended-upgrades without email (dry-run)")
    fi
    trap - EXIT
    return 0
  fi

  # Install required packages
  log "[1/8] Atualizando repositórios e instalando pacotes..."
  apt-get update
  apt-get install -y \
      unattended-upgrades \
      update-notifier-common

  if [[ "$CONFIGURE_EMAIL" == "true" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        postfix \
        mailutils \
        libsasl2-modules
  fi

  # Configure 50unattended-upgrades
  log "[2/8] Configurando 50unattended-upgrades..."
  local U50=/etc/apt/apt.conf.d/50unattended-upgrades
  declare -A U50_SETTINGS=(
      ["Remove-Unused-Kernel-Packages"]="\"true\""
      ["Automatic-Reboot"]="\"true\""
      ["Automatic-Reboot-WithUsers"]="\"true\""
      ["Automatic-Reboot-Time"]="\"03:00\""
  )

  if [[ "$CONFIGURE_EMAIL" == "true" ]]; then
      local MAIL_SENDER_VALUE="${MAIL_SENDER:-${GENERIC_FROM}}"
      local MAIL_SENDER_ESCAPED="${MAIL_SENDER_VALUE//\"/\\\"}"
      U50_SETTINGS["Mail"]="\"${MAIL_TO}\""
      U50_SETTINGS["MailReport"]="\"on-change\""
      U50_SETTINGS["Sender"]="\"${MAIL_SENDER_ESCAPED}\""
  fi

  for key in "${!U50_SETTINGS[@]}"; do
      local val=${U50_SETTINGS[$key]}
      local pattern="^[[:space:]]*Unattended-Upgrade::${key}[[:space:];]"
      local cpattern="^[[:space:]]*//[[:space:]]*Unattended-Upgrade::${key}[[:space:];]"

      if grep -qE "$pattern" "$U50"; then
          sed -i -E "s|^([[:space:]]*)Unattended-Upgrade::${key}[[:space:];].*|\\1Unattended-Upgrade::${key} ${val};|" "$U50"
      elif grep -qE "$cpattern" "$U50"; then
          sed -i -E "s|^([[:space:]]*)//[[:space:]]*Unattended-Upgrade::${key}[[:space:];].*|\\1Unattended-Upgrade::${key} ${val};|" "$U50"
      else
          echo "Unattended-Upgrade::${key} ${val};" >> "$U50"
      fi
  done

  # Configure 20auto-upgrades
  log "[3/8] Configurando 20auto-upgrades..."
  local U20=/etc/apt/apt.conf.d/20auto-upgrades
  declare -A U20_SETTINGS=(
      ["Update-Package-Lists"]="\"1\""
      ["Download-Upgradeable-Packages"]="\"1\""
      ["AutocleanInterval"]="\"7\""
      ["Unattended-Upgrade"]="\"1\""
  )
  touch "$U20"
  for key in "${!U20_SETTINGS[@]}"; do
      local val=${U20_SETTINGS[$key]}
      if grep -qE "^[[:space:]]*APT::Periodic::${key}" "$U20"; then
          sed -i -E "s|^[[:space:]]*APT::Periodic::${key}.*|APT::Periodic::${key} ${val};|" "$U20"
      else
          echo "APT::Periodic::${key} ${val};" >> "$U20"
      fi
  done

  # Configure Postfix (SMTP Relay)
  if [[ "$CONFIGURE_EMAIL" == "true" ]]; then
    log "[4/8] Configurando Postfix (SMTP Relay)..."
    local SMTP_TLS_WRAPPERMODE="no"
    if [[ "$RELAY_PORT" == "465" ]]; then
      SMTP_TLS_WRAPPERMODE="yes"
    fi

    postconf -e \
        "relayhost = [${RELAY_HOST}]:${RELAY_PORT}" \
        "smtp_use_tls = yes" \
        "smtp_tls_wrappermode = ${SMTP_TLS_WRAPPERMODE}" \
        "smtp_tls_security_level = encrypt" \
        "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt" \
        "smtp_sasl_auth_enable = yes" \
        "smtp_sasl_security_options = noanonymous" \
        "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" \
        "smtp_generic_maps = hash:/etc/postfix/generic" \
        "inet_interfaces = loopback-only"
    cat > /etc/postfix/sasl_passwd <<EOF
[${RELAY_HOST}]:${RELAY_PORT} ${SMTP_USER}:${SMTP_PASS}
EOF
    chmod 600 /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd && shred -u /etc/postfix/sasl_passwd

    log "[5/8] Criando generic map para remetentes..."
    local HOST_FQDN
    local HOST_SHORT
    HOST_FQDN=$(hostname -f)
    HOST_SHORT=$(hostname -s)
    cat > /etc/postfix/generic <<EOF
root                          ${GENERIC_FROM}
root@${HOST_SHORT}            ${GENERIC_FROM}
root@${HOST_FQDN}           ${GENERIC_FROM}
root@${HOST_SHORT}.localdomain  ${GENERIC_FROM}
EOF
    chmod 600 /etc/postfix/generic
    postmap /etc/postfix/generic
    systemctl restart postfix
  else
    log "[4/8] Postfix (SMTP Relay) skipped - email not configured."
    log "[5/8] Generic map skipped - email not configured."
  fi

  # Set daily cron for 01:00
  log "[6/8] Ajustando cron diário para 01:00..."
  local CRON_LINE="0 1 * * * /usr/bin/unattended-upgrade -v"
  if ! crontab -l 2>/dev/null | grep -Fxq "$CRON_LINE"; then
      (crontab -l 2>/dev/null || true; echo "$CRON_LINE") | crontab -
  fi

  # Enable unattended-upgrades service
  log "[7/8] Habilitando serviço unattended-upgrades..."
  systemctl enable --now unattended-upgrades

  # Clean up config file
  cleanup_conf
  trap - EXIT

  log "[8/8] ✅ Unattended-upgrades configurado com sucesso!"
  if [[ "$CONFIGURE_EMAIL" == "true" ]]; then
    SUMMARY+=("Unattended-upgrades (with email)")
  else
    SUMMARY+=("Unattended-upgrades (without email)")
  fi
}

# --- Menu ---

# Execute a menu option
run_option() {
  local opcao="$1"
  case "$opcao" in
    1) config_inicial ;;
    2) limitar_journald ;;
    3) autologout_config ;;
    4) unattended_upgrades false ;;
    5) unattended_upgrades true ;;
    [aA])
      config_inicial
      limitar_journald
      autologout_config
      unattended_upgrades false
      ;;
    0) show_summary; log "Exiting..."; exit 0 ;;
    *) echo "Invalid option: $opcao" ;;
  esac
}

# Interactive menu (loop)
menu() {
  while true; do
    echo ""
    echo "═══════════════════════════════════════"
    echo "     INITIAL LINUX SETTINGS v${VERSION}"
    [[ "$DRY_RUN" == "true" ]] && echo "           [DRY-RUN MODE]"
    echo "═══════════════════════════════════════"
    echo ""
    echo " Basic Setup:"
    echo "   1) Timezone, locale, and SSH"
    echo "   2) Limit journald usage"
    echo "   3) Configure autologout (15 min)"
    echo ""
    echo " Automatic Updates:"
    echo "   4) Unattended-upgrades (with email)"
    echo "   5) Unattended-upgrades (without email)"
    echo ""
    echo " Run Multiple:"
    echo "   A) ALL options (1-5)"
    echo "   0) Exit"
    echo ""
    read -rp " Select option(s) separated by space: " opcoes

    for opcao in $opcoes; do
      run_option "$opcao"
    done

    show_summary
    SUMMARY=()
  done
}

# --- Main ---

# Parse arguments
CLI_OPTIONS=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help) show_help; exit 0 ;;
    *) CLI_OPTIONS+=("$arg") ;;
  esac
done

# Check permissions
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  This script must be run as root (sudo)." >&2
  exit 1
fi

# Initialize log
echo "" >> "$LOG_FILE" 2>/dev/null || true
log "=== initial-settings.sh v${VERSION} started ==="

# Execute: CLI args or interactive menu
if [[ ${#CLI_OPTIONS[@]} -gt 0 ]]; then
  for opcao in "${CLI_OPTIONS[@]}"; do
    run_option "$opcao"
  done
  show_summary
else
  menu
fi
