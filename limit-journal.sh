#!/usr/bin/env bash
# Script para configurar limites do journald sem backup
set -euo pipefail

CONF="/etc/systemd/journald.conf"

# Parâmetros e valores desejados
declare -A PARAMS=(
  [SystemMaxUse]="300M"       # Limite total de espaço em disco para o journal
  [SystemKeepFree]="500M"     # Espaço mínimo livre que sempre deve haver no disco
  [SystemMaxFileSize]="50M"   # Tamanho máximo por arquivo de journal
  [MaxRetentionSec]="1month"  # Tempo máximo de retenção de logs: 1 mês
)

# Para cada parâmetro: se existir, substitui; se não, adiciona ao final
for key in "${!PARAMS[@]}"; do
  value="${PARAMS[$key]}"
  if grep -Eq "^[#[:space:]]*${key}=" "$CONF"; then
    sed -ri "s|^[#[:space:]]*(${key}=).*|\1${value}|" "$CONF"
  else
    echo "${key}=${value}" >> "$CONF"
  fi
done

# Aplicar as mudanças
systemctl daemon-reload
systemctl restart systemd-journald

echo "Limites do journald atualizados:"
journalctl --disk-usage
