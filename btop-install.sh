#!/usr/bin/env bash
#
# btop-install.sh
# Instala o btop (monitor avançado de sistema) em servidores Linux
# Script testado no Ubuntu/Debian
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

# Verificar permissões
if [[ $EUID -ne 0 ]]; then
    error "Este script precisa ser executado como root (sudo)."
fi

# Detectar arquitetura
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH_NAME="x86_64"
        ;;
    aarch64|arm64)
        ARCH_NAME="aarch64"
        ;;
    *)
        error "Arquitetura não suportada: $ARCH"
        ;;
esac

# Definir versão e URL
BTOP_VERSION="1.4.2"
BTOP_URL="https://github.com/aristocratos/btop/releases/download/v${BTOP_VERSION}/btop-${ARCH_NAME}-linux-musl.tbz"

# Criar diretório temporário
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || error "Falha ao criar diretório temporário"

log "Baixando btop v${BTOP_VERSION}..."
wget "$BTOP_URL" -O btop.tbz || error "Falha ao baixar btop"

log "Extraindo arquivos..."
tar -xf btop.tbz || error "Falha ao extrair arquivo"

log "Instalando btop..."
cd btop || error "Diretório btop não encontrado"
make install || error "Falha ao instalar btop"

# Limpar arquivos temporários
cd / && rm -rf "$TMP_DIR"

log "✅ btop v${BTOP_VERSION} instalado com sucesso!"
log "Execute 'btop' para iniciar o monitor de sistema."