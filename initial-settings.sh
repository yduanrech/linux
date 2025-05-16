#!/usr/bin/env bash
#
# initial-settings.sh
# Configura fuso horário para São Paulo/Brasil e locale pt_BR.UTF-8
# Script testado no Ubuntu/Debian
# v1.1
#
set -euo pipefail

### 1. Verificação de permissões ----------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  Este script precisa ser executado como root (sudo)." >&2
  exit 1
fi

### 2. Configuração de fuso horário ------------------------------------------
echo "[1/4] Configurando fuso horário para America/Sao_Paulo..."
timedatectl set-timezone America/Sao_Paulo
echo "✅ Fuso horário configurado: $(timedatectl show --property=Timezone --value)"

### 3. Geração do locale pt_BR.UTF-8 -----------------------------------------
echo "[2/4] Gerando locale pt_BR.UTF-8..."
sed -i 's/^# *pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen
locale-gen

### 4. Configuração do locale padrão -----------------------------------------
echo "[3/4] Configurando locale padrão..."
update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8

### 5. Configuração de segurança SSH -----------------------------------------
echo "[4/4] Configurando segurança SSH..."

# Perguntar ao usuário se deseja restringir login SSH do root
read -p "Deseja restringir o login SSH para o usuário root? (s/n): " restringir_ssh

if [[ "$restringir_ssh" =~ ^[Ss]$ ]]; then
  # Buscar pelo arquivo de configuração SSH
  SSH_CONFIG="/etc/ssh/sshd_config"
  if [[ -f "$SSH_CONFIG" ]]; then
    # Verificar se já existe uma configuração para PermitRootLogin
    if grep -q "^PermitRootLogin" "$SSH_CONFIG"; then
      # Se existir, substituir a linha existente
      sed -i 's/^PermitRootLogin .*/PermitRootLogin prohibit-password/' "$SSH_CONFIG"
    else
      # Se não existir, adicionar a configuração no final do arquivo
      echo "PermitRootLogin prohibit-password" >> "$SSH_CONFIG"
    fi
    
    # Reiniciar o serviço SSH
    systemctl restart sshd
    echo "✅ Login SSH do root restringido para apenas chaves (prohibit-password)"
    echo "   ➜ Se você ainda não configurou chaves SSH, faça isso antes de sair desta sessão"
  else
    echo "⚠️ Arquivo de configuração SSH não encontrado em $SSH_CONFIG"
  fi
else
  echo "⚠️ Login SSH do root não foi modificado"
fi

echo "✅ Configuração inicial concluída!"
echo "   ➜ Locale configurado para pt_BR.UTF-8"
echo "   ➜ Para aplicar todas as mudanças, recomenda-se reiniciar o sistema"