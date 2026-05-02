#!/usr/bin/env bash
# caddy-acme-install.sh
# Instala Caddy oficial via apt e/ou integra acme.sh + Cloudflare DNS-01.
# Sem argumentos: abre menu interativo. Com argumentos: executa subcomandos.

set -euo pipefail
umask 077

VERSION="1.1"
CONF_FILE="/etc/caddy-acme.conf"
CADDYFILE="/etc/caddy/Caddyfile"
SITES_DIR="/etc/caddy/sites.d"
DEFAULT_CERTS_DIR="/etc/ssl/acme-certs"
MANAGED_MARKER="Managed by caddy-acme-install.sh"
ACME_SH="/root/.acme.sh/acme.sh"

DRY_RUN=false
FORCE=false
ACME_EMAIL=""
CF_Token=""
CF_Account_ID=""
CF_Zone_ID=""
WEB_SERVER="caddy"
CERTS_DIR=""
RENEW_RELOAD_CMD="systemctl reload caddy"
REMAINING_ARGS=()

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

mask_secret() {
  local value="$1"
  local len=${#value}

  if (( len <= 8 )); then
    printf '********'
  else
    printf '%s********%s' "${value:0:4}" "${value: -4}"
  fi
}

confirm_action() {
  local prompt_text="$1"
  local reply=""

  read -r -p "$prompt_text" reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

usage() {
  cat <<EOF
caddy-acme-install.sh v${VERSION}

Uso:
  $(basename "$0")                         # menu interativo
  $(basename "$0") init [--force] [--dry-run]
  $(basename "$0") init-acme [--certs-dir DIR] [--reload-cmd CMD] [--force] [--dry-run]
  $(basename "$0") issue-cert --domain FQDN [--dry-run]
  $(basename "$0") add-site --domain FQDN --upstream URL [--issue-if-missing] [--skip-upstream-tls-verify] [--force] [--dry-run]
  $(basename "$0") validate
  $(basename "$0") upgrade-acme [--dry-run]

Exemplos com curl:
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)"
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- init
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- init-acme
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- issue-cert --domain app.example.com
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/caddy-acme-install.sh)" -- add-site --domain app.example.com --upstream http://10.0.0.10:3000 --issue-if-missing

Subcomandos:
  init          Instala Caddy/acme.sh e prepara /etc/caddy + /etc/caddy-acme.conf
  init-acme     Instala/configura apenas acme.sh para Apache2, sem instalar Caddy
  issue-cert    Emite e instala certificado para um FQDN usando Cloudflare DNS-01
  add-site      Cria/atualiza reverse proxy em /etc/caddy/sites.d/<fqdn>.caddy
  validate      Valida o Caddyfile
  upgrade-acme  Atualiza o acme.sh pelo gerenciador proprio dele

Opcoes globais:
  --dry-run     Mostra as acoes sem alterar o sistema
  --force       Permite sobrescrever arquivos nao gerenciados em pontos especificos
  -h, --help    Mostra esta ajuda
EOF
}

need_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Execute como root."
}

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[DRY-RUN]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

fmt_caddy_file() {
  local target="$1"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] formataria $target com caddy fmt"
    return 0
  fi

  command -v caddy >/dev/null 2>&1 || die "caddy nao encontrado para formatar $target."
  run_cmd caddy fmt --overwrite "$target"
}

write_file() {
  local target="$1"
  local content="$2"
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] escreveria $target"
    if [[ "$target" != "$CONF_FILE" ]]; then
      printf '%s\n' "$content"
    fi
    return 0
  fi
  printf '%s\n' "$content" > "$target"
}

prompt_required() {
  local prompt_text="$1"
  local var_name="$2"
  local input=""

  while [[ -z "$input" ]]; do
    read -r -p "$prompt_text" input
    [[ -n "$input" ]] || warn "Campo obrigatorio."
  done
  printf -v "$var_name" '%s' "$input"
}

prompt_secret() {
  local prompt_text="$1"
  local var_name="$2"
  local input=""

  while [[ -z "$input" ]]; do
    read -r -s -p "$prompt_text" input
    printf '\n'
    [[ -n "$input" ]] || warn "Campo obrigatorio."
  done
  printf -v "$var_name" '%s' "$input"
}

shell_quote() {
  printf '%q' "$1"
}

normalize_domain() {
  local domain="$1"
  domain="${domain%.}"
  printf '%s' "$domain" | tr '[:upper:]' '[:lower:]'
}

validate_domain() {
  local domain
  domain="$(normalize_domain "$1")"

  [[ "$domain" != *"*"* ]] || die "Wildcard nao faz parte da v1: $domain"
  [[ "$domain" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]] \
    || die "Dominio invalido: $domain"
}

validate_upstream() {
  local upstream="$1"

  [[ "$upstream" =~ ^https?://[^/[:space:]]+/?$ ]] || die "Upstream invalido. Use http://host:porta ou https://host:porta, sem path."
}

validate_certs_dir() {
  local certs_dir="$1"

  [[ "$certs_dir" == /* ]] || die "CERTS_DIR precisa ser um caminho absoluto."
  [[ "$certs_dir" != *[[:space:]]* ]] || die "CERTS_DIR nao pode conter espacos."
}

load_config() {
  [[ -r "$CONF_FILE" ]] || die "Arquivo de configuracao nao encontrado ou ilegivel: $CONF_FILE. Rode init ou init-acme primeiro."
  # shellcheck disable=SC1090
  . "$CONF_FILE"

  : "${ACME_EMAIL:?ACME_EMAIL ausente em $CONF_FILE}"
  : "${CF_Token:?CF_Token ausente em $CONF_FILE}"
  WEB_SERVER="${WEB_SERVER:-caddy}"
  case "$WEB_SERVER" in
    caddy|apache|none) ;;
    *) die "WEB_SERVER invalido em $CONF_FILE: $WEB_SERVER" ;;
  esac

  CERTS_DIR="${CERTS_DIR:-$DEFAULT_CERTS_DIR}"
  validate_certs_dir "$CERTS_DIR"

  if [[ -z "${RENEW_RELOAD_CMD:-}" ]]; then
    case "$WEB_SERVER" in
      caddy) RENEW_RELOAD_CMD="systemctl reload caddy" ;;
      apache) RENEW_RELOAD_CMD="systemctl reload apache2" ;;
      none) RENEW_RELOAD_CMD="true" ;;
    esac
  fi

  if [[ -n "${CF_Account_ID:-}" && -n "${CF_Zone_ID:-}" ]]; then
    die "Defina apenas um entre CF_Account_ID e CF_Zone_ID em $CONF_FILE."
  fi
  if [[ -z "${CF_Account_ID:-}" && -z "${CF_Zone_ID:-}" ]]; then
    die "Defina CF_Account_ID ou CF_Zone_ID em $CONF_FILE."
  fi
}

detect_debian_like() {
  command -v apt-get >/dev/null 2>&1 || die "Este script requer apt-get."
  [[ -r /etc/debian_version ]] || die "Este script foi feito para Debian/Ubuntu."
}

ensure_acme_dependencies() {
  detect_debian_like
  export DEBIAN_FRONTEND=noninteractive

  log "Instalando dependencias minimas para acme.sh..."
  run_cmd apt-get update
  run_cmd apt-get install -y curl ca-certificates
}

ensure_caddy_repo_and_package() {
  detect_debian_like
  export DEBIAN_FRONTEND=noninteractive

  log "Instalando dependencias e reposititorio oficial do Caddy..."
  run_cmd apt-get update
  run_cmd apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl ca-certificates gnupg

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] configuraria /usr/share/keyrings/caddy-stable-archive-keyring.gpg"
    log "[DRY-RUN] configuraria /etc/apt/sources.list.d/caddy-stable.list"
  else
    local tmp_key tmp_list
    tmp_key="$(mktemp)"
    tmp_list="$(mktemp)"

    curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' -o "$tmp_key"
    gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg "$tmp_key"
    curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' -o "$tmp_list"
    install -m 0644 "$tmp_list" /etc/apt/sources.list.d/caddy-stable.list
    chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
    rm -f "$tmp_key" "$tmp_list"
  fi

  run_cmd apt-get update
  run_cmd apt-get install -y caddy
  run_cmd systemctl enable --now caddy
}

configure_acme_ca() {
  [[ -x "$ACME_SH" ]] || return 0
  log "Configurando Let's Encrypt como CA padrao do acme.sh..."
  run_cmd "$ACME_SH" --set-default-ca --server letsencrypt
}

ensure_acme_sh() {
  local email="$1"

  if [[ -x "$ACME_SH" ]]; then
    log "acme.sh ja instalado em $ACME_SH"
    configure_acme_ca
    return 0
  fi

  log "Instalando acme.sh..."
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] curl -fsSL https://get.acme.sh | sh -s email=$email"
  else
    curl -fsSL https://get.acme.sh | sh -s "email=$email"
  fi
  configure_acme_ca
}

write_config_file() {
  local acme_email="$1"
  local cf_token="$2"
  local id_kind="$3"
  local id_value="$4"
  local certs_dir="${5:-$DEFAULT_CERTS_DIR}"
  local web_server="${6:-caddy}"
  local reload_cmd="${7:-systemctl reload caddy}"
  local account_id_line="CF_Account_ID="
  local zone_id_line="CF_Zone_ID="

  if [[ "$id_kind" == "account" ]]; then
    account_id_line="CF_Account_ID=$(shell_quote "$id_value")"
  else
    zone_id_line="CF_Zone_ID=$(shell_quote "$id_value")"
  fi

  local content
  content="# $MANAGED_MARKER
ACME_EMAIL=$(shell_quote "$acme_email")
CF_Token=$(shell_quote "$cf_token")
$account_id_line
$zone_id_line
WEB_SERVER=$(shell_quote "$web_server")
CERTS_DIR=$(shell_quote "$certs_dir")
RENEW_RELOAD_CMD=$(shell_quote "$reload_cmd")"

  log "Gravando $CONF_FILE..."
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] escreveria $CONF_FILE com permissao 0600"
    return 0
  fi

  write_file "$CONF_FILE" "$content"
  chmod 0600 "$CONF_FILE"
  chown root:root "$CONF_FILE"
}

create_cert_dirs() {
  local certs_dir="${1:-$DEFAULT_CERTS_DIR}"
  local web_server="${2:-caddy}"

  validate_certs_dir "$certs_dir"
  if [[ "$web_server" == "caddy" ]]; then
    run_cmd install -d -m 0750 -o root -g caddy "$certs_dir"
  else
    run_cmd install -d -m 0700 -o root -g root "$certs_dir"
  fi
}

create_base_dirs() {
  local certs_dir="${1:-$DEFAULT_CERTS_DIR}"

  run_cmd install -d -m 0755 /etc/caddy
  run_cmd install -d -m 0755 "$SITES_DIR"
  create_cert_dirs "$certs_dir" "caddy"
}

default_caddyfile_content() {
  local acme_email="$1"

  cat <<EOF
# $MANAGED_MARKER
{
    email $acme_email
}

import sites.d/*.caddy
EOF
}

is_default_packaged_caddyfile() {
  local file="$1"

  [[ -f "$file" ]] || return 1
  grep -q '/usr/share/caddy' "$file" && return 0
  grep -q 'respond "Hello, world!"' "$file" && return 0
  return 1
}

ensure_caddyfile() {
  local acme_email="$1"
  local content
  content="$(default_caddyfile_content "$acme_email")"

  if [[ -f "$CADDYFILE" ]]; then
    if grep -q "$MANAGED_MARKER" "$CADDYFILE"; then
      log "Atualizando Caddyfile gerenciado..."
    elif is_default_packaged_caddyfile "$CADDYFILE"; then
      log "Substituindo Caddyfile padrao do pacote..."
    elif [[ "$FORCE" == "true" ]]; then
      warn "Sobrescrevendo Caddyfile nao gerenciado por causa de --force."
    else
      die "$CADDYFILE ja existe e nao parece ser gerenciado por este script. Use --force para sobrescrever."
    fi
  else
    log "Criando $CADDYFILE..."
  fi

  write_file "$CADDYFILE" "$content"
  if [[ "$DRY_RUN" != "true" ]]; then
    chown root:caddy "$CADDYFILE"
    chmod 0644 "$CADDYFILE"
  fi
  fmt_caddy_file "$CADDYFILE"
}

wizard_config() {
  local target_web_server="${1:-caddy}"
  local target_certs_dir="${2:-$DEFAULT_CERTS_DIR}"
  local target_reload_cmd="${3:-systemctl reload caddy}"
  local acme_email cf_token id_choice id_value id_kind

  validate_certs_dir "$target_certs_dir"

  if [[ -r "$CONF_FILE" && "$FORCE" != "true" ]]; then
    log "$CONF_FILE ja existe. Reutilizando configuracao existente."
    load_config
    return 0
  fi

  prompt_required "Email ACME: " acme_email
  prompt_secret "Cloudflare CF_Token: " cf_token

  printf '\nCloudflare ID:\n'
  printf '  1) CF_Account_ID (recomendado para multiplas zonas na mesma conta)\n'
  printf '  2) CF_Zone_ID (recomendado para uma zona especifica)\n'
  read -r -p "Escolha [1/2]: " id_choice
  case "$id_choice" in
    1|"")
      id_kind="account"
      prompt_required "CF_Account_ID: " id_value
      ;;
    2)
      id_kind="zone"
      prompt_required "CF_Zone_ID: " id_value
      ;;
    *)
      die "Opcao invalida."
      ;;
  esac

  printf '\nResumo da configuracao:\n'
  printf '  ACME_EMAIL: %s\n' "$acme_email"
  printf '  CF_Token: %s\n' "$(mask_secret "$cf_token")"
  if [[ "$id_kind" == "account" ]]; then
    printf '  CF_Account_ID: %s\n' "$id_value"
  else
    printf '  CF_Zone_ID: %s\n' "$id_value"
  fi
  printf '  WEB_SERVER: %s\n' "$target_web_server"
  printf '  CERTS_DIR: %s\n' "$target_certs_dir"
  printf '  RENEW_RELOAD_CMD: %s\n' "$target_reload_cmd"

  confirm_action "Confirmar configuracao e continuar? (y/N): " || die "Operacao cancelada."

  write_config_file "$acme_email" "$cf_token" "$id_kind" "$id_value" "$target_certs_dir" "$target_web_server" "$target_reload_cmd"
  if [[ "$DRY_RUN" == "true" ]]; then
    ACME_EMAIL="$acme_email"
    CF_Token="$cf_token"
    CF_Account_ID=""
    CF_Zone_ID=""
    WEB_SERVER="$target_web_server"
    CERTS_DIR="$target_certs_dir"
    RENEW_RELOAD_CMD="$target_reload_cmd"
    if [[ "$id_kind" == "account" ]]; then
      CF_Account_ID="$id_value"
    else
      CF_Zone_ID="$id_value"
    fi
    return 0
  fi
  load_config
}

cmd_init() {
  need_root
  wizard_config "caddy" "$DEFAULT_CERTS_DIR" "systemctl reload caddy"
  [[ "$WEB_SERVER" == "caddy" ]] || die "$CONF_FILE ja existe com WEB_SERVER=$WEB_SERVER. Use --force para recriar configuracao para Caddy."
  ensure_caddy_repo_and_package
  create_base_dirs "$CERTS_DIR"
  ensure_acme_sh "$ACME_EMAIL"
  ensure_caddyfile "$ACME_EMAIL"
  cmd_validate
  run_cmd systemctl reload caddy
  log "Base Caddy + acme.sh concluida."
}

cmd_init_acme() {
  local certs_dir="${1:-$DEFAULT_CERTS_DIR}"
  local reload_cmd="${2:-systemctl reload apache2}"

  need_root
  wizard_config "apache" "$certs_dir" "$reload_cmd"
  [[ "$WEB_SERVER" == "apache" ]] || die "$CONF_FILE ja existe com WEB_SERVER=$WEB_SERVER. Use --force para recriar configuracao para Apache/acme.sh."
  ensure_acme_dependencies
  create_cert_dirs "$CERTS_DIR" "$WEB_SERVER"
  ensure_acme_sh "$ACME_EMAIL"
  log "Base acme.sh concluida sem instalar Caddy."
}

export_cloudflare_env() {
  export CF_Token
  if [[ -n "${CF_Account_ID:-}" ]]; then
    export CF_Account_ID
    unset CF_Zone_ID || true
  else
    export CF_Zone_ID
    unset CF_Account_ID || true
  fi
}

install_domain_cert_dir() {
  local cert_dir="$1"

  if [[ "$WEB_SERVER" == "caddy" ]]; then
    run_cmd install -d -m 0750 -o root -g caddy "$cert_dir"
  else
    run_cmd install -d -m 0700 -o root -g root "$cert_dir"
  fi
}

set_domain_cert_permissions() {
  local cert_dir="$1"

  if [[ "$WEB_SERVER" == "caddy" ]]; then
    chown root:caddy "$cert_dir" "$cert_dir/privkey.pem" "$cert_dir/fullchain.pem"
    chmod 0750 "$cert_dir"
    chmod 0640 "$cert_dir/privkey.pem" "$cert_dir/fullchain.pem"
  else
    chown root:root "$cert_dir" "$cert_dir/privkey.pem" "$cert_dir/fullchain.pem"
    chmod 0700 "$cert_dir"
    chmod 0600 "$cert_dir/privkey.pem"
    chmod 0644 "$cert_dir/fullchain.pem"
  fi
}

renew_reload_cmd_for_cert_dir() {
  local cert_dir="$1"

  if [[ "$WEB_SERVER" == "caddy" ]]; then
    printf 'chown root:caddy %s %s/privkey.pem %s/fullchain.pem && chmod 750 %s && chmod 640 %s/privkey.pem %s/fullchain.pem && %s' \
      "$cert_dir" "$cert_dir" "$cert_dir" "$cert_dir" "$cert_dir" "$cert_dir" "$RENEW_RELOAD_CMD"
  else
    printf 'chown root:root %s %s/privkey.pem %s/fullchain.pem && chmod 700 %s && chmod 600 %s/privkey.pem && chmod 644 %s/fullchain.pem && %s' \
      "$cert_dir" "$cert_dir" "$cert_dir" "$cert_dir" "$cert_dir" "$cert_dir" "$RENEW_RELOAD_CMD"
  fi
}

cmd_issue_cert() {
  local domain="$1"
  local cert_dir reload_cmd

  need_root
  load_config
  domain="$(normalize_domain "$domain")"
  validate_domain "$domain"
  [[ -x "$ACME_SH" ]] || die "acme.sh nao encontrado em $ACME_SH. Rode init ou init-acme primeiro."

  cert_dir="$CERTS_DIR/$domain"
  reload_cmd="$(renew_reload_cmd_for_cert_dir "$cert_dir")"

  create_cert_dirs "$CERTS_DIR" "$WEB_SERVER"
  install_domain_cert_dir "$cert_dir"
  export_cloudflare_env

  log "Emitindo certificado para $domain via Cloudflare DNS-01..."
  if [[ "$DRY_RUN" == "true" ]]; then
    run_cmd "$ACME_SH" --issue --server letsencrypt --dns dns_cf -d "$domain"
  else
    local issue_status
    set +e
    "$ACME_SH" --issue --server letsencrypt --dns dns_cf -d "$domain"
    issue_status=$?
    set -e

    if [[ "$issue_status" -eq 2 ]]; then
      warn "acme.sh indicou que nao havia emissao/renovacao pendente; continuando com install-cert."
    elif [[ "$issue_status" -ne 0 ]]; then
      return "$issue_status"
    fi
  fi

  log "Instalando certificado em $cert_dir..."
  run_cmd "$ACME_SH" --install-cert -d "$domain" \
    --key-file "$cert_dir/privkey.pem" \
    --fullchain-file "$cert_dir/fullchain.pem" \
    --reloadcmd "$reload_cmd"

  if [[ "$DRY_RUN" != "true" ]]; then
    set_domain_cert_permissions "$cert_dir"
  fi
  log "Certificado pronto para $domain."
  if [[ "$WEB_SERVER" == "apache" ]]; then
    log "Apache: use SSLCertificateFile $cert_dir/fullchain.pem e SSLCertificateKeyFile $cert_dir/privkey.pem."
  fi
}

site_file_for_domain() {
  local domain="$1"
  printf '%s/%s.caddy' "$SITES_DIR" "$domain"
}

cert_dir_for_domain() {
  local domain="$1"
  printf '%s/%s' "$CERTS_DIR" "$domain"
}

cert_files_exist_for_domain() {
  local domain="$1"
  local cert_dir
  cert_dir="$(cert_dir_for_domain "$domain")"

  [[ -f "$cert_dir/fullchain.pem" && -f "$cert_dir/privkey.pem" ]]
}

site_content() {
  local domain="$1"
  local upstream="$2"
  local skip_verify="$3"
  local cert_dir="$CERTS_DIR/$domain"
  local log_file="/var/log/caddy/${domain}-access.log"

  if [[ "$skip_verify" == "true" ]]; then
    cat <<EOF
# $MANAGED_MARKER
$domain {
    tls $cert_dir/fullchain.pem $cert_dir/privkey.pem

    # log {
    #     output file $log_file {
    #         roll_size 25MiB
    #         roll_keep 5
    #         roll_keep_for 336h
    #     }
    #     format json
    # }

    reverse_proxy $upstream {
        transport http {
            tls_insecure_skip_verify
        }
    }
}
EOF
  else
    cat <<EOF
# $MANAGED_MARKER
$domain {
    tls $cert_dir/fullchain.pem $cert_dir/privkey.pem

    # log {
    #     output file $log_file {
    #         roll_size 25MiB
    #         roll_keep 5
    #         roll_keep_for 336h
    #     }
    #     format json
    # }

    reverse_proxy $upstream
}
EOF
  fi
}

cmd_add_site() {
  local domain="$1"
  local upstream="$2"
  local skip_verify="$3"
  local issue_if_missing="$4"
  local site_file content cert_dir backup_file="" had_existing=false validate_status=0

  need_root
  load_config
  [[ "$WEB_SERVER" == "caddy" ]] || die "add-site esta disponivel apenas para configuracao WEB_SERVER=caddy. Para Apache, use issue-cert e configure o VirtualHost."
  domain="$(normalize_domain "$domain")"
  upstream="${upstream%/}"
  validate_domain "$domain"
  validate_upstream "$upstream"

  if [[ "$skip_verify" == "true" && "$upstream" != https://* ]]; then
    die "--skip-upstream-tls-verify exige upstream https://."
  fi

  create_base_dirs "$CERTS_DIR"
  cert_dir="$(cert_dir_for_domain "$domain")"
  if [[ "$DRY_RUN" != "true" ]] && ! cert_files_exist_for_domain "$domain"; then
    if [[ "$issue_if_missing" == "true" ]]; then
      log "Certificado ausente para $domain; emitindo antes de criar o site."
      cmd_issue_cert "$domain"
    else
      die "Certificado ausente para $domain em $cert_dir. Rode issue-cert --domain $domain antes de add-site ou use --issue-if-missing."
    fi
  fi
  site_file="$(site_file_for_domain "$domain")"
  content="$(site_content "$domain" "$upstream" "$skip_verify")"

  if [[ -f "$site_file" ]] && ! grep -q "$MANAGED_MARKER" "$site_file"; then
    [[ "$FORCE" == "true" ]] || die "$site_file existe e nao e gerenciado por este script. Use --force para sobrescrever."
    warn "Sobrescrevendo $site_file por causa de --force."
  fi

  log "Gravando site $domain -> $upstream"
  if [[ "$DRY_RUN" != "true" && -f "$site_file" ]]; then
    had_existing=true
    backup_file="$(mktemp)"
    cp -p "$site_file" "$backup_file"
  fi
  write_file "$site_file" "$content"
  if [[ "$DRY_RUN" != "true" ]]; then
    chown root:caddy "$site_file"
    chmod 0644 "$site_file"
  fi
  fmt_caddy_file "$site_file"

  if [[ "$DRY_RUN" == "true" ]]; then
    cmd_validate
  else
    set +e
    cmd_validate
    validate_status=$?
    set -e

    if [[ "$validate_status" -ne 0 ]]; then
      warn "Validacao falhou; restaurando estado anterior de $site_file."
      if [[ "$had_existing" == "true" ]]; then
        mv -f "$backup_file" "$site_file"
        chown root:caddy "$site_file"
        chmod 0644 "$site_file"
      else
        rm -f "$site_file"
        rm -f "$backup_file"
      fi
      die "Configuracao invalida; nenhuma alteracao foi mantida para $domain."
    fi
  fi

  rm -f "$backup_file"
  run_cmd systemctl reload caddy
  log "Site configurado: $domain"
}

cmd_validate() {
  need_root
  if ! command -v caddy >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log "[DRY-RUN] validaria $CADDYFILE com caddy validate"
      return 0
    fi
    die "caddy nao encontrado."
  fi
  log "Validando Caddyfile..."
  run_cmd caddy validate --adapter caddyfile --config "$CADDYFILE"
}

cmd_upgrade_acme() {
  need_root
  [[ -x "$ACME_SH" ]] || die "acme.sh nao encontrado em $ACME_SH. Rode init ou init-acme primeiro."
  log "Atualizando acme.sh..."
  run_cmd "$ACME_SH" --upgrade
}

menu() {
  local choice domain upstream skip
  local skip_enabled

  while true; do
    printf '\n'
    printf '=======================================\n'
    printf ' CADDY + ACME.SH + CLOUDFLARE v%s\n' "$VERSION"
    [[ "$DRY_RUN" == "true" ]] && printf ' [DRY-RUN]\n'
    printf '=======================================\n'
    printf ' 1) Init / instalar base\n'
    printf ' 2) Init acme.sh apenas / Apache2\n'
    printf ' 3) Emitir certificado\n'
    printf ' 4) Adicionar ou atualizar site\n'
    printf ' 5) Validar Caddyfile\n'
    printf ' 6) Atualizar acme.sh\n'
    printf ' 7) Ajuda\n'
    printf ' 0) Sair\n'
    printf '\n'
    read -r -p "Escolha: " choice

    case "$choice" in
      1)
        cmd_init
        ;;
      2)
        cmd_init_acme "$DEFAULT_CERTS_DIR" "systemctl reload apache2"
        ;;
      3)
        prompt_required "FQDN (ex: app.example.com): " domain
        printf '\nResumo:\n'
        printf '  Acao: emitir certificado\n'
        printf '  Dominio: %s\n' "$(normalize_domain "$domain")"
        confirm_action "Confirmar emissao? (y/N): " || die "Operacao cancelada."
        cmd_issue_cert "$domain"
        ;;
      4)
        prompt_required "FQDN (ex: app.example.com): " domain
        prompt_required "Upstream (ex: http://10.0.0.10:3000): " upstream
        read -r -p "Ignorar validacao TLS do upstream HTTPS? (y/N): " skip
        skip_enabled="nao"
        if [[ "$skip" =~ ^[Yy]$ ]]; then
          skip_enabled="sim"
        fi
        printf '\nResumo:\n'
        printf '  Acao: adicionar/atualizar site\n'
        printf '  Dominio: %s\n' "$(normalize_domain "$domain")"
        printf '  Upstream: %s\n' "${upstream%/}"
        printf '  Skip TLS verify: %s\n' "$skip_enabled"
        printf '  Emitir certificado se faltar: sim\n'
        confirm_action "Confirmar gravacao do site? (y/N): " || die "Operacao cancelada."
        if [[ "$skip_enabled" == "sim" ]]; then
          cmd_add_site "$domain" "$upstream" "true" "true"
        else
          cmd_add_site "$domain" "$upstream" "false" "true"
        fi
        ;;
      5)
        cmd_validate
        ;;
      6)
        cmd_upgrade_acme
        ;;
      7)
        usage
        ;;
      0)
        exit 0
        ;;
      *)
        warn "Opcao invalida."
        ;;
    esac
  done
}

parse_global_flags() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      *)
        break
        ;;
    esac
  done
  REMAINING_ARGS=("$@")
}

parse_common_tail_flags() {
  local -n args_ref=$1
  local filtered=()
  local arg

  for arg in "${args_ref[@]}"; do
    case "$arg" in
      --dry-run) DRY_RUN=true ;;
      --force) FORCE=true ;;
      *) filtered+=("$arg") ;;
    esac
  done
  args_ref=("${filtered[@]}")
}

main() {
  local cmd domain="" upstream="" skip_verify=false issue_if_missing=false
  local init_certs_dir="$DEFAULT_CERTS_DIR" init_reload_cmd="systemctl reload apache2"
  local args=()
  REMAINING_ARGS=()

  if [[ $# -eq 0 ]]; then
    need_root
    menu
    return 0
  fi

  parse_global_flags "$@"
  args=("${REMAINING_ARGS[@]}")
  parse_common_tail_flags args

  [[ ${#args[@]} -gt 0 ]] || { need_root; menu; return 0; }
  cmd="${args[0]}"
  args=("${args[@]:1}")

  case "$cmd" in
    init)
      [[ ${#args[@]} -eq 0 ]] || die "Argumentos invalidos para init."
      cmd_init
      ;;
    init-acme)
      while [[ ${#args[@]} -gt 0 ]]; do
        case "${args[0]}" in
          --certs-dir)
            [[ ${#args[@]} -ge 2 ]] || die "--certs-dir requer valor."
            init_certs_dir="${args[1]}"
            args=("${args[@]:2}")
            ;;
          --reload-cmd)
            [[ ${#args[@]} -ge 2 ]] || die "--reload-cmd requer valor."
            init_reload_cmd="${args[1]}"
            args=("${args[@]:2}")
            ;;
          *)
            die "Argumento invalido para init-acme: ${args[0]}"
            ;;
        esac
      done
      cmd_init_acme "$init_certs_dir" "$init_reload_cmd"
      ;;
    issue-cert)
      while [[ ${#args[@]} -gt 0 ]]; do
        case "${args[0]}" in
          --domain)
            [[ ${#args[@]} -ge 2 ]] || die "--domain requer valor."
            domain="${args[1]}"
            args=("${args[@]:2}")
            ;;
          *)
            die "Argumento invalido para issue-cert: ${args[0]}"
            ;;
        esac
      done
      [[ -n "$domain" ]] || die "Use --domain FQDN."
      cmd_issue_cert "$domain"
      ;;
    add-site)
      while [[ ${#args[@]} -gt 0 ]]; do
        case "${args[0]}" in
          --domain)
            [[ ${#args[@]} -ge 2 ]] || die "--domain requer valor."
            domain="${args[1]}"
            args=("${args[@]:2}")
            ;;
          --upstream)
            [[ ${#args[@]} -ge 2 ]] || die "--upstream requer valor."
            upstream="${args[1]}"
            args=("${args[@]:2}")
            ;;
          --skip-upstream-tls-verify)
            skip_verify=true
            args=("${args[@]:1}")
            ;;
          --issue-if-missing)
            issue_if_missing=true
            args=("${args[@]:1}")
            ;;
          *)
            die "Argumento invalido para add-site: ${args[0]}"
            ;;
        esac
      done
      [[ -n "$domain" ]] || die "Use --domain FQDN."
      [[ -n "$upstream" ]] || die "Use --upstream URL."
      cmd_add_site "$domain" "$upstream" "$skip_verify" "$issue_if_missing"
      ;;
    validate)
      [[ ${#args[@]} -eq 0 ]] || die "Argumentos invalidos para validate."
      cmd_validate
      ;;
    upgrade-acme)
      [[ ${#args[@]} -eq 0 ]] || die "Argumentos invalidos para upgrade-acme."
      cmd_upgrade_acme
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      die "Subcomando desconhecido: $cmd"
      ;;
  esac
}

main "$@"
