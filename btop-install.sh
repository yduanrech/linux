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

# Instalar dependências
log "Instalando dependências necessárias..."
apt-get update -qq || error "Falha ao atualizar repositórios"
apt-get install -y wget make bzip2 || error "Falha ao instalar dependências"

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
tar -xjf btop.tbz || error "Falha ao extrair arquivo"

log "Instalando btop..."
cd btop || error "Diretório btop não encontrado"
make install || error "Falha ao instalar btop"

# Limpar arquivos temporários
cd / && rm -rf "$TMP_DIR"

log "✅ btop v${BTOP_VERSION} instalado com sucesso!"
log "Execute 'btop' para iniciar o monitor de sistema."


# "Para desinstalar o btop no futuro, você tem duas opções:"
# "Método 1 (baixando novamente e usando make uninstall):"
# "  wget https://github.com/aristocratos/btop/releases/download/v${BTOP_VERSION}/btop-${ARCH_NAME}-linux-musl.tbz"
# "  tar -xf btop-${ARCH_NAME}-linux-musl.tbz"
# "  cd btop && sudo make uninstall"
# ""
# "Método 2 (remoção manual dos arquivos):"
# "sudo rm -f /usr/local/bin/btop"
# "sudo rm -rf /usr/local/share/btop"
# "sudo rm -f /usr/local/share/applications/btop.desktop"
# "sudo rm -f /usr/local/share/icons/hicolor/48x48/apps/btop.png"
# "sudo rm -f /usr/local/share/icons/hicolor/scalable/apps/btop.svg"
# "hash -r" Limpa o cache do comando
# "sudo rm -rf /usr/local/share/doc/btop"