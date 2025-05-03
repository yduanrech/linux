#!/usr/bin/env bash
set -euo pipefail

# 1. Root obrigatorio
if [[ $EUID -ne 0 ]]; then
  echo "⚠️  Precisa ser root (sudo)." >&2
  exit 1
fi

# 2. Criar/atualizar o arquivo de autologout
cat > /etc/profile.d/autologout.sh <<'EOF'
# /etc/profile.d/autologout.sh
# Encerra shells Bash inativos após 5 min

# So define se ainda não estiver readonly
if ! (declare -p TMOUT 2>/dev/null | grep -q '^-r'); then
  TMOUT=30       # 15 minutos
  readonly TMOUT
  export TMOUT
fi
EOF

# 3. Permissoes
chmod 755 /etc/profile.d/autologout.sh

# 4. FORÇAR source + log para teste em lab
# shellcheck disable=SC1091
source /etc/profile.d/autologout.sh || true
echo "$(date '+%F %T') [$$] autologout aplicado (TMOUT=$TMOUT)" \
  >> /tmp/autologout.log

echo "✅  Autologout configurado (TMOUT=900 s)."
echo "   ➜ Veja /tmp/autologout.log para confirmar."
