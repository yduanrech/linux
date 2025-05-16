#!/usr/bin/env bash
#
# autologout-install.sh
# Instala o QEMU Agent na sua VM.
# Script testado no Ubuntu 22.04 LTS
# v1.0
#

set -euo pipefail

# Função para mensagens
log() {
    echo "[INFO] $1"
}

# Função para mensagens de erro
error() {
    echo "[ERRO] $1" >&2
    exit 1
}

log "Atualizando lista de pacotes..."
apt-get update || error "Falha ao atualizar pacotes."

log "Instalando QEMU Guest Agent..."
apt-get install -y qemu-guest-agent || error "Falha na instalação do QEMU Guest Agent."

log "Ativando e iniciando o serviço do QEMU Guest Agent..."
systemctl enable --now qemu-guest-agent || error "Falha ao ativar ou iniciar o serviço QEMU Guest Agent."

log "QEMU Guest Agent instalado e em execução com sucesso!"

log "Agendando reinicialização do sistema em 60 segundos para aplicar todas as configurações..."
shutdown -r +1 "O sistema será reiniciado em 1 minuto para finalizar a instalação do QEMU Guest Agent."

log "Caso necessário, você pode cancelar o reinício com o comando: shutdown -c"
