#!/usr/bin/env bash
#
# fix-unattended-upgrades.sh
# Corrige configuração do unattended-upgrades em servidores existentes:
#   1) Automatic-Reboot-WithUsers → "false"
#   2) APT::Periodic::Unattended-Upgrade → "1"
#   3) Remove cronjob legado do unattended-upgrade
#
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Execute como root."; exit 1; }

U50=/etc/apt/apt.conf.d/50unattended-upgrades
U20=/etc/apt/apt.conf.d/20auto-upgrades

echo "=== [1/3] Automatic-Reboot-WithUsers → false ==="
if [[ -f "$U50" ]]; then
  if grep -qE '^[[:space:]]*Unattended-Upgrade::Automatic-Reboot-WithUsers' "$U50"; then
    sed -i -E 's|^([[:space:]]*)Unattended-Upgrade::Automatic-Reboot-WithUsers.*|\1Unattended-Upgrade::Automatic-Reboot-WithUsers "false";|' "$U50"
    echo "  ✅ Alterado para false"
  else
    echo 'Unattended-Upgrade::Automatic-Reboot-WithUsers "false";' >> "$U50"
    echo "  ✅ Adicionado (não existia)"
  fi
else
  echo "  ⚠️ Arquivo $U50 não encontrado. Nada alterado."
fi

echo ""
echo "=== [2/3] APT::Periodic::Unattended-Upgrade → 1 ==="
if [[ -f "$U20" ]]; then
  if grep -qE '^[[:space:]]*APT::Periodic::Unattended-Upgrade' "$U20"; then
    sed -i -E 's|^[[:space:]]*APT::Periodic::Unattended-Upgrade.*|APT::Periodic::Unattended-Upgrade "1";|' "$U20"
    echo "  ✅ Alterado para 1"
  else
    echo 'APT::Periodic::Unattended-Upgrade "1";' >> "$U20"
    echo "  ✅ Adicionado (não existia)"
  fi
else
  echo "  ⚠️ Arquivo $U20 não encontrado. Nada alterado."
fi

echo ""
echo "=== [3/3] Removendo cronjob legado ==="
CRON_LINE='0 1 * * * /usr/bin/unattended-upgrade -v'
if crontab -l 2>/dev/null | grep -Fxq "$CRON_LINE"; then
  crontab -l 2>/dev/null | grep -Fxv "$CRON_LINE" | crontab -
  echo "  ✅ Cronjob removido"
else
  echo "  ℹ️ Cronjob não encontrado (já removido ou inexistente)"
fi

echo ""
echo "═══════════════════════════════════════"
echo "         VERIFICAÇÃO FINAL"
echo "═══════════════════════════════════════"
echo ""
echo "--- Reboot config ---"
grep 'Automatic-Reboot' "$U50" 2>/dev/null || echo "(não encontrado)"
echo ""
echo "--- 20auto-upgrades ---"
cat "$U20" 2>/dev/null || echo "(não encontrado)"
echo ""
echo "--- Cronjob root ---"
crontab -l 2>/dev/null || echo "(vazio)"
echo ""
echo "✅ Correção concluída."
