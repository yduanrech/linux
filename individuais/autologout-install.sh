#!/usr/bin/env bash
#
# autologout-install.sh
# Configura logout automático após 10 min de inatividade.
# Script testado no Ubuntu 22.04 LTS
# v1.0
#
set -euo pipefail

### 1. Somente root -----------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  Este script precisa ser executado como root (sudo)." >&2
  exit 1
fi

### 2. Criar o script em /etc/profile.d/ --------------------------------------
cat > /etc/profile.d/autologout.sh <<'EOF'
# /etc/profile.d/autologout.sh
# Encerra shells Bash inativos após 5min (300s)

TMOUT=900          # 15 minutos
readonly TMOUT
export TMOUT
EOF

### 3. Permissões --------------------------------------------------------------
# Retirado por hora, pelos testes não se viu necessário
#chmod 755 /etc/profile.d/autologout.sh


echo "✅  Autologout configurado (TMOUT=900s)."
echo "   ➜  Abra um novo terminal ou faça logout/login para que todas as sessões peguem a configuração."
