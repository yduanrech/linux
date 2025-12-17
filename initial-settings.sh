#!/usr/bin/env bash
#
# initial-settings.sh
# Configura fuso horário para São Paulo/Brasil e locale pt_BR.UTF-8
# Script testado no Ubuntu/Debian
# v1.1
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
  read -p "Deseja permitir o login SSH com senha para o usuário root? (s/n): " permitir_ssh
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

# Menu interativo
menu() {
  echo "==============================="
  echo "  CONFIGURAÇÕES INICIAIS LINUX "
  echo "==============================="
  echo "Escolha as opções desejadas (separe por espaço):"
  echo " 1) Fuso horário, locale e SSH"
  echo " 2) Limitar uso do journald"
  echo " 3) Todas as opções acima"
  echo " 4) Configurar autologout (logout automático)"
  echo " 0) Sair"
  read -p "Digite o(s) número(s) da(s) opção(ões): " opcoes
  for opcao in $opcoes; do
    case $opcao in
      1) config_inicial ;;
      2) limitar_journald ;;
      3) config_inicial; limitar_journald; autologout_config ;;
      4) autologout_config ;;
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