#!/usr/bin/env bash
#
# initial-settings.sh
# Menu interativo para configuração inicial de servidores Linux
# Inclui: fuso horário, locale, SSH, journald, autologout, unattended-upgrades
# Script testado no Ubuntu/Debian
# v1.2
#
set -euo pipefail

# Função: Configuração inicial (fuso horário, locale, SSH)
config_inicial() {
  echo "[1/4] Configurando fuso horário para America/Sao_Paulo..."
  timedatectl set-timezone America/Sao_Paulo
  echo "✅ Fuso horário configurado: $(timedatectl show --property=Timezone --value)"

  echo "[2/4] Gerando locale pt_BR.UTF-8..."
  sed -i 's/^# *pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen
  locale-gen

  echo "[3/4] Configurando locale padrão..."
  update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8

  echo "[4/4] Configurando segurança SSH..."
  read -r -p "Deseja permitir o login SSH com senha para o usuário root? (s/n): " permitir_ssh
  if [[ "$permitir_ssh" =~ ^[Ss]$ ]]; then
    SSH_CONFIG="/etc/ssh/sshd_config"
    if [[ -f "$SSH_CONFIG" ]]; then
      if grep -q "^PermitRootLogin" "$SSH_CONFIG"; then
        sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' "$SSH_CONFIG"
      else
        echo "PermitRootLogin yes" >> "$SSH_CONFIG"
      fi
      systemctl restart sshd
      echo "✅ Login SSH do root habilitado com senha"
      echo "   ⚠️ ATENÇÃO: Por segurança, considere usar chaves SSH em vez de senhas"
    else
      echo "⚠️ Arquivo de configuração SSH não encontrado em $SSH_CONFIG"
    fi
  else
    echo "⚠️ Login SSH do root não foi modificado"
  fi
  
  # Configuração anterior (apenas chaves SSH) - COMENTADO
  # read -p "Deseja restringir o login SSH para o usuário root? (s/n): " restringir_ssh
  # if [[ "$restringir_ssh" =~ ^[Ss]$ ]]; then
  #   SSH_CONFIG="/etc/ssh/sshd_config"
  #   if [[ -f "$SSH_CONFIG" ]]; then
  #     if grep -q "^PermitRootLogin" "$SSH_CONFIG"; then
  #       sed -i 's/^PermitRootLogin .*/PermitRootLogin prohibit-password/' "$SSH_CONFIG"
  #     else
  #       echo "PermitRootLogin prohibit-password" >> "$SSH_CONFIG"
  #     fi
  #     systemctl restart sshd
  #     echo "✅ Login SSH do root restringido para apenas chaves (prohibit-password)"
  #     echo "   ➜ Se você ainda não configurou chaves SSH, faça isso antes de sair desta sessão"
  #   else
  #     echo "⚠️ Arquivo de configuração SSH não encontrado em $SSH_CONFIG"
  #   fi
  # else
  #   echo "⚠️ Login SSH do root não foi modificado"
  # fi
  echo "✅ Configuração inicial concluída!"
  echo "   ➜ Locale configurado para pt_BR.UTF-8"
  echo "   ➜ Para aplicar todas as mudanças, recomenda-se reiniciar o sistema"
}


# Função: Limitar uso do journald
limitar_journald() {
  echo "[JOURNALD] Configurando limites do journald..."
  CONF="/etc/systemd/journald.conf"
  declare -A PARAMS=(
    [SystemMaxUse]="300M"
    [SystemKeepFree]="500M"
    [SystemMaxFileSize]="50M"
    [MaxRetentionSec]="1month"
  )
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
  echo "Limites do journald atualizados:"
  journalctl --disk-usage
}

# Função: Configurar autologout
autologout_config() {
  echo "[AUTOLOGOUT] Configurando logout automático após 15 minutos de inatividade..."
  cat > /etc/profile.d/autologout.sh <<'EOF'
# /etc/profile.d/autologout.sh
# Encerra shells Bash inativos após 15min (900s)
TMOUT=900
readonly TMOUT
export TMOUT
EOF
  echo "✅  Autologout configurado (TMOUT=900s)."
  echo "   ➜  Abra um novo terminal ou faça logout/login para que todas as sessões peguem a configuração."
}

# Função: Instalar unattended-upgrades (completo e independente)
# Parâmetro: com_email (true/false)
unattended_upgrades() {
  local SKIP_EMAIL="${1:-false}"
  local CONFIGURE_EMAIL=true
  local CONF_FILE=/etc/unattend.conf
  
  echo ""
  echo "[UNATTENDED-UPGRADES] Configurando atualizações automáticas..."
  
  # Carrega configurações
  if [[ -f "$CONF_FILE" ]]; then
    # shellcheck source=/etc/unattend.conf
    source "$CONF_FILE"
    
    # Valida variáveis obrigatórias
    for var in MAIL_TO GENERIC_FROM RELAY SMTP_USER SMTP_PASS; do
      if [[ -z "${!var:-}" ]]; then
        echo "Erro: variável $var não definida em $CONF_FILE" >&2
        return 1
      fi
    done
  else
    if [[ "$SKIP_EMAIL" == "true" ]]; then
      echo "Aviso: $CONF_FILE não encontrado. Continuando sem configuração de email..."
      CONFIGURE_EMAIL=false
    else
      # Loop para permitir re-verificação do arquivo
      while true; do
        echo ""
        echo "Aviso: $CONF_FILE não encontrado."
        echo "O arquivo de configuração contém as credenciais SMTP para notificações por email."
        echo ""
        echo "Opções:"
        echo "  [Y] Continuar sem configuração de email"
        echo "  [R] Re-verificar (aguardo você criar o arquivo)"
        echo "  [N] Cancelar"
        echo ""
        read -rp "Digite sua opção (y/r/N): " resposta
        case "$resposta" in
          [yY])
            echo "Continuando sem configuração de email..."
            CONFIGURE_EMAIL=false
            break
            ;;
          [rR])
            echo "Re-verificando..."
            if [[ -f "$CONF_FILE" ]]; then
              echo "✅ Arquivo encontrado! Carregando configurações..."
              # shellcheck source=/etc/unattend.conf
              source "$CONF_FILE"
              # Valida variáveis obrigatórias
              for var in MAIL_TO GENERIC_FROM RELAY SMTP_USER SMTP_PASS; do
                if [[ -z "${!var:-}" ]]; then
                  echo "Erro: variável $var não definida em $CONF_FILE" >&2
                  return 1
                fi
              done
              CONFIGURE_EMAIL=true
              break
            else
              echo "⚠️ Arquivo ainda não encontrado. Tente novamente."
            fi
            ;;
          *)
            echo "Operação cancelada." >&2
            return 1
            ;;
        esac
      done
    fi
  fi

  # Prepara limpeza segura do CONF_FILE
  cleanup_conf() {
    if [[ -f "$CONF_FILE" ]]; then
      shred -u "$CONF_FILE" 2>/dev/null || rm -f "$CONF_FILE"
    fi
  }

  # Separa host e porta do RELAY
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

  # Instala pacotes necessários
  echo "[1/8] Atualizando repositórios e instalando pacotes..."
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

  # Configura 50unattended-upgrades
  echo "[2/8] Configurando 50unattended-upgrades..."
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

  # Configura 20auto-upgrades
  echo "[3/8] Configurando 20auto-upgrades..."
  local U20=/etc/apt/apt.conf.d/20auto-upgrades
  declare -A U20_SETTINGS=(
      ["Update-Package-Lists"]="\"1\""
      ["Download-Upgradeable-Packages"]="\"1\""
      ["AutocleanInterval"]="\"7\""
      ["Unattended-Upgrade"]="\"0\""
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

  # Configura Postfix (SMTP Relay)
  if [[ "$CONFIGURE_EMAIL" == "true" ]]; then
    echo "[4/8] Configurando Postfix (SMTP Relay)..."
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

    echo "[5/8] Criando generic map para remetentes..."
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
    echo "[4/8] Postfix (SMTP Relay) ignorado - email não configurado."
    echo "[5/8] Generic map ignorado - email não configurado."
  fi

  # Ajustar cron diário para 01:00
  echo "[6/8] Ajustando cron diário para 01:00..."
  local CRON_LINE="0 1 * * * /usr/bin/unattended-upgrade -v"
  if ! crontab -l 2>/dev/null | grep -Fxq "$CRON_LINE"; then
      (crontab -l 2>/dev/null || true; echo "$CRON_LINE") | crontab -
  fi

  # Habilita serviço unattended-upgrades
  echo "[7/8] Habilitando serviço unattended-upgrades..."
  systemctl enable --now unattended-upgrades

  # Limpeza do arquivo de configuração
  cleanup_conf

  echo "[8/8] ✅ Unattended-upgrades configurado com sucesso!"
}

# Menu interativo
menu() {
  echo ""
  echo "═══════════════════════════════════════"
  echo "    CONFIGURAÇÕES INICIAIS LINUX"
  echo "═══════════════════════════════════════"
  echo ""
  echo " Configurações Básicas:"
  echo "   1) Fuso horário, locale e SSH"
  echo "   2) Limitar uso do journald"
  echo "   3) Configurar autologout (15 min)"
  echo ""
  echo " Atualizações Automáticas:"
  echo "   4) Unattended-upgrades (com email)"
  echo "   5) Unattended-upgrades (sem email)"
  echo ""
  echo " Executar Múltiplas:"
  echo "   A) TODAS as opções (1-5)"
  echo "   0) Sair"
  echo ""
  read -rp " Selecione opção(ões) separadas por espaço: " opcoes
  
  for opcao in $opcoes; do
    case $opcao in
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
      0) echo "Saindo..."; exit 0 ;;
      *) echo "Opção inválida: $opcao" ;;
    esac
  done
}

# Verificação de permissões
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  Este script precisa ser executado como root (sudo)." >&2
  exit 1
fi

menu
