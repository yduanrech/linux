#!/usr/bin/env bash
# -------------------------------------------------------------------
# Configura unattended‑upgrades + update-notifier-common + envio por e-mail
# Lê variáveis de /etc/unattend.conf e destrói o arquivo ao final
# -------------------------------------------------------------------
# v1.3
#
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Execute como root."; exit 1; }
export DEBIAN_FRONTEND=noninteractive

# 0) Localização do arquivo de configuração
CONF_FILE=/etc/unattend.conf

# 1) Carrega configurações
if [[ -f "$CONF_FILE" ]]; then
  source "$CONF_FILE"
else
  echo "Erro: $CONF_FILE não encontrado" >&2
  exit 1
fi

# 2) Valida variáveis obrigatórias
for var in MAIL_TO GENERIC_FROM RELAY SMTP_USER SMTP_PASS; do
  if [[ -z "${!var:-}" ]]; then
    echo "Erro: variável $var não definida em $CONF_FILE" >&2
    exit 1
  fi
done

# 3) Prepara limpeza segura do CONF_FILE ao sair (sucesso ou erro)
cleanup() {
  shred -u "$CONF_FILE" || rm -f "$CONF_FILE"
}
trap cleanup EXIT

# 4) Separa host e porta do RELAY (formato host:port)
if [[ "$RELAY" == *:* ]]; then
  RELAY_HOST="${RELAY%%:*}"
  RELAY_PORT="${RELAY##*:}"
else
  RELAY_HOST="$RELAY"
  RELAY_PORT="25"
fi

# 5) Instala pacotes necessários
echo "[1/8] Atualizando repositórios e instalando pacotes..."
apt-get update
apt-get install -y \
    unattended-upgrades \
    update-notifier-common \
    postfix \
    mailutils \
    libsasl2-modules

# 6) Configura 50unattended-upgrades
echo "[2/8] Configurando 50unattended-upgrades..."
U50=/etc/apt/apt.conf.d/50unattended-upgrades
declare -A U50_SETTINGS=(
    ["Remove-Unused-Kernel-Packages"]="\"true\""
    ["Automatic-Reboot"]="\"true\""
    ["Automatic-Reboot-WithUsers"]="\"true\""
    ["Automatic-Reboot-Time"]="\"03:00\""
    ["Mail"]="\"${MAIL_TO}\""
    ["MailReport"]="\"on-change\""
)
for key in "${!U50_SETTINGS[@]}"; do
    val=${U50_SETTINGS[$key]}
    pattern="^[[:space:]]*Unattended-Upgrade::${key}[[:space:];]"
    cpattern="^[[:space:]]*//[[:space:]]*Unattended-Upgrade::${key}[[:space:];]"

    if grep -qE "$pattern" "$U50"; then
        sed -i -E "s|^([[:space:]]*)Unattended-Upgrade::${key}[[:space:];].*|\\1Unattended-Upgrade::${key} ${val};|" "$U50"
    elif grep -qE "$cpattern" "$U50"; then
        sed -i -E "s|^([[:space:]]*)//[[:space:]]*Unattended-Upgrade::${key}[[:space:];].*|\\1Unattended-Upgrade::${key} ${val};|" "$U50"
    else
        echo "Unattended-Upgrade::${key} ${val};" >> "$U50"
    fi
done

# 7) Configura 20auto-upgrades
echo "[3/8] Configurando 20auto-upgrades..."
U20=/etc/apt/apt.conf.d/20auto-upgrades
declare -A U20_SETTINGS=(
    ["Update-Package-Lists"]="\"1\""
    ["Download-Upgradeable-Packages"]="\"1\""
    ["AutocleanInterval"]="\"7\""
    # O controle de quando o Unattended Upgrade roda é feito vai cronjon, para mais controle
    ["Unattended-Upgrade"]="\"0\""
)
touch "$U20"
for key in "${!U20_SETTINGS[@]}"; do
    val=${U20_SETTINGS[$key]}
    if grep -qE "^[[:space:]]*APT::Periodic::${key}" "$U20"; then
        sed -i -E "s|^[[:space:]]*APT::Periodic::${key}.*|APT::Periodic::${key} ${val};|" "$U20"
    else
        echo "APT::Periodic::${key} ${val};" >> "$U20"
    fi
done

# 8) Configura Postfix (SMTP Relay)
echo "[4/8] Configurando Postfix (SMTP Relay)..."
postconf -e \
    "relayhost = [${RELAY_HOST}]:${RELAY_PORT}" \
    "smtp_use_tls = yes" \
    "smtp_tls_wrappermode = yes" \
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

# 9) Criar generic map (não remover)
echo "[5/8] Criando generic map para remetentes..."
HOST_FQDN=$(hostname -f)
HOST_SHORT=$(hostname -s)
cat > /etc/postfix/generic <<EOF
root@${HOST_FQDN}           ${GENERIC_FROM}
root@${HOST_SHORT}.localdomain  ${GENERIC_FROM}
EOF
chmod 600 /etc/postfix/generic
postmap /etc/postfix/generic
systemctl restart postfix

# 10) Ajustar cron diário para 01:00
echo "[6/8] Ajustando cron diário para 01:00..."
CRON_LINE="0 1 * * * /usr/bin/unattended-upgrade -v"
if ! crontab -l 2>/dev/null | grep -Fxq "$CRON_LINE"; then
    (crontab -l 2>/dev/null || true; echo "$CRON_LINE") | crontab -
fi

# 11) Habilita serviço unattended-upgrades
echo "[7/8] Habilitando serviço unattended-upgrades..."
systemctl enable --now unattended-upgrades

# 12) Conclusão
echo "[8/8] ✅ Script concluído."