#!/usr/bin/env bash
#
# initial-settings.sh
# Configura fuso horário para São Paulo/Brasil e locale pt_BR.UTF-8
# Script testado no Ubuntu/Debian
#
set -euo pipefail

### 1. Verificação de permissões ----------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  Este script precisa ser executado como root (sudo)." >&2
  exit 1
fi

### 2. Configuração de fuso horário ------------------------------------------
echo "[1/3] Configurando fuso horário para America/Sao_Paulo..."
timedatectl set-timezone America/Sao_Paulo
echo "✅ Fuso horário configurado: $(timedatectl show --property=Timezone --value)"

### 3. Geração do locale pt_BR.UTF-8 -----------------------------------------
echo "[2/3] Gerando locale pt_BR.UTF-8..."
sed -i 's/^# *pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen
locale-gen

### 4. Configuração do locale padrão -----------------------------------------
echo "[3/3] Configurando locale padrão..."
update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8

echo "✅ Configuração inicial concluída!"
echo "   ➜ Locale configurado para pt_BR.UTF-8"
echo "   ➜ Para aplicar todas as mudanças, recomenda-se reiniciar o sistema"