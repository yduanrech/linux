#!/usr/bin/env bash
# gickup-install.sh
# Instala/atualiza Gickup linux amd64 e prepara config para mirror GitHub -> Codeberg.
# Sem argumentos: abre menu interativo. Com argumentos: executa subcomandos.

set -euo pipefail
umask 077

VERSION="1.0"
GICKUP_REPO="cooperspencer/gickup"
GICKUP_BIN="/usr/local/bin/gickup"
GICKUP_BACKUP_BIN="/usr/local/bin/gickup.bak"
CONFIG_DIR="/etc/gickup"
CONF_FILE="/etc/gickup/conf.yml"
ENV_FILE="/etc/gickup/gickup.env"
SERVICE_FILE="/etc/systemd/system/gickup.service"
STATE_DIR="/var/lib/gickup"
LOG_DIR="/var/log/gickup"
LOCAL_BACKUP_DIR="/var/backups/gickup"
SERVICE_USER="gickup"
SERVICE_GROUP="gickup"
MANAGED_MARKER="Managed by gickup-install.sh"

DRY_RUN=false
FORCE=false
REMAINING_ARGS=()
CONFIG_CRON="0 3 * * *"
CONFIG_GITHUB_OWNER="CHANGE_ME_GITHUB_USER_OR_ORG"
CONFIG_GITHUB_REPOS="CHANGE_ME_REPOSITORY_NAME"
CONFIG_CODEBERG_OWNER="CHANGE_ME_CODEBERG_USER_OR_ORG"

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

confirm_action() {
  local prompt_text="$1"
  local reply=""

  read -r -p "$prompt_text" reply
  [[ "$reply" =~ ^[Yy]$ ]]
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

usage() {
  cat <<EOF
gickup-install.sh v${VERSION}

Uso:
  $(basename "$0")                         # menu interativo
  $(basename "$0") init [--force] [--dry-run]
  $(basename "$0") configure [--force] [--dry-run]
  $(basename "$0") update-binary [--dry-run]
  $(basename "$0") validate-config [--dry-run]
  $(basename "$0") run-now [--dry-run]
  $(basename "$0") enable-service [--dry-run]
  $(basename "$0") restart-service [--dry-run]
  $(basename "$0") status

Exemplos com curl:
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)"
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- init
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- configure --force
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- validate-config
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- run-now
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- enable-service
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- update-binary

Subcomandos:
  init             Instala dependencias, binario, usuario, diretorios, config e service
  configure        Pergunta cron/repositorios e recria /etc/gickup/conf.yml
  update-binary    Atualiza apenas o binario /usr/local/bin/gickup
  validate-config  Valida placeholders, env e executa gickup --dryrun sem cron
  run-now          Executa um backup/mirror agora, sem esperar o cron
  enable-service   Valida e habilita/inicia gickup.service
  restart-service  Reinicia gickup.service
  status           Mostra versao e status do servico

Opcoes globais:
  --dry-run         Mostra as acoes sem alterar o sistema
  --force           Permite recriar conf/env existentes gerenciados
  -h, --help        Mostra esta ajuda
EOF
}

repo_list_yaml() {
  local repo

  for repo in $CONFIG_GITHUB_REPOS; do
    printf '        - %s\n' "$repo"
  done
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

write_file() {
  local target="$1"
  local content="$2"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] escreveria $target"
    printf '%s\n' "$content"
    return 0
  fi

  printf '%s\n' "$content" > "$target"
}

detect_debian_like() {
  command -v apt-get >/dev/null 2>&1 || die "Este script requer apt-get."
  [[ -r /etc/debian_version ]] || die "Este script foi feito para Debian/Ubuntu."
}

ensure_dependencies() {
  local missing=()
  local package

  detect_debian_like
  export DEBIAN_FRONTEND=noninteractive

  for package in curl ca-certificates tar git git-lfs; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
      missing+=("$package")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log "Instalando dependencias: ${missing[*]}"
    run_cmd apt-get update
    run_cmd apt-get install -y "${missing[@]}"
  else
    log "Dependencias ja instaladas."
  fi

  if command -v git >/dev/null 2>&1 && command -v git-lfs >/dev/null 2>&1; then
    run_cmd git lfs install --system
  elif [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] git lfs install --system"
  fi
}

ensure_service_user_and_dirs() {
  if ! getent group "$SERVICE_GROUP" >/dev/null 2>&1; then
    run_cmd groupadd --system "$SERVICE_GROUP"
  fi

  if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
    run_cmd useradd --system --gid "$SERVICE_GROUP" --home-dir "$STATE_DIR" --create-home --shell /usr/sbin/nologin "$SERVICE_USER"
  fi

  run_cmd install -d -m 0750 -o root -g "$SERVICE_GROUP" "$CONFIG_DIR"
  run_cmd install -d -m 0750 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$STATE_DIR"
  run_cmd install -d -m 0750 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$LOG_DIR"
  run_cmd install -d -m 0750 -o "$SERVICE_USER" -g "$SERVICE_GROUP" "$LOCAL_BACKUP_DIR"
}

latest_release_tag() {
  local latest_url tag

  latest_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/${GICKUP_REPO}/releases/latest")"
  tag="${latest_url##*/}"
  [[ "$tag" == v* ]] || die "Nao consegui descobrir a tag latest do Gickup: $latest_url"
  printf '%s' "$tag"
}

install_latest_binary() {
  local tag version asset checksum base_url tmpdir extracted

  ensure_dependencies
  tag="$(latest_release_tag)"
  version="${tag#v}"
  asset="gickup_${version}_linux_amd64.tar.gz"
  checksum="gickup_${version}_checksums.txt"
  base_url="https://github.com/${GICKUP_REPO}/releases/download/${tag}"

  log "Baixando Gickup ${tag} linux amd64..."
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] baixaria ${base_url}/${asset}"
    log "[DRY-RUN] baixaria ${base_url}/${checksum}"
    log "[DRY-RUN] validaria checksum e instalaria em $GICKUP_BIN"
    return 0
  fi

  tmpdir="$(mktemp -d)"

  curl -fL "${base_url}/${asset}" -o "${tmpdir}/${asset}"
  curl -fL "${base_url}/${checksum}" -o "${tmpdir}/${checksum}"

  (
    cd "$tmpdir"
    sha256sum -c --ignore-missing "$checksum"
    tar -xzf "$asset"
  )

  extracted="$(find "$tmpdir" -type f -name gickup -perm /111 | head -n1)"
  [[ -n "$extracted" ]] || die "Binario gickup nao encontrado dentro de $asset."

  if [[ -x "$GICKUP_BIN" ]]; then
    install -m 0755 -o root -g root "$GICKUP_BIN" "$GICKUP_BACKUP_BIN"
  fi
  install -m 0755 -o root -g root "$extracted" "$GICKUP_BIN"
  "$GICKUP_BIN" --version >/dev/null
  log "Gickup instalado em $GICKUP_BIN: $("$GICKUP_BIN" --version)"
  rm -rf "$tmpdir"
}

default_env_content() {
  cat <<EOF
# $MANAGED_MARKER
# Edite este arquivo antes de habilitar o servico.
# O conf.yml usa estes nomes como variaveis de ambiente.
# Se o token tiver caracteres especiais de shell, use aspas simples.

GICKUP_GITHUB_TOKEN=CHANGE_ME_GITHUB_FINE_GRAINED_PAT
GICKUP_CODEBERG_TOKEN=CHANGE_ME_CODEBERG_TOKEN
EOF
}

default_config_content() {
  cat <<EOF
# $MANAGED_MARKER
# Mirror GitHub -> Codeberg usando Gickup.
# Tokens ficam em $ENV_FILE e sao referenciados aqui pelos nomes das variaveis.

cron: "$CONFIG_CRON"

log:
  file-logging:
    dir: $LOG_DIR
    file: gickup.log
    maxage: 7

source:
  github:
    - token: GICKUP_GITHUB_TOKEN
      user: $CONFIG_GITHUB_OWNER
      include:
$(repo_list_yaml)
      wiki: false
      issues: false
      starred: false
      filter:
        excludearchived: false
        excludeforks: false

destination:
  gitea:
    - url: https://codeberg.org/
      token: GICKUP_CODEBERG_TOKEN
      user: $CONFIG_CODEBERG_OWNER
      mirror:
        enabled: true
      visibility:
        repositories: private
        organizations: private
      force: true
      lfs: false

  # Backup local opcional. Descomente se quiser manter copia local tambem.
  # local:
  #   - path: $LOCAL_BACKUP_DIR
  #     structured: true
  #     bare: true
  #     mirror: true
  #     lfs: false
  #     zip: false
  #     keep: 7
EOF
}

write_managed_file_if_needed() {
  local target="$1"
  local content="$2"
  local mode="$3"
  local owner="$4"
  local group="$5"

  if [[ -f "$target" ]]; then
    if [[ "$FORCE" == "true" ]]; then
      if ! grep -q "$MANAGED_MARKER" "$target"; then
        warn "Sobrescrevendo $target nao gerenciado por causa de --force."
      else
        log "Recriando $target por causa de --force."
      fi
    else
      log "$target ja existe. Preservando arquivo existente."
      return 0
    fi
  else
    log "Criando $target..."
  fi

  write_file "$target" "$content"
  if [[ "$DRY_RUN" != "true" ]]; then
    chown "${owner}:${group}" "$target"
    chmod "$mode" "$target"
  fi
}

ensure_config_files() {
  ensure_service_user_and_dirs
  write_managed_file_if_needed "$ENV_FILE" "$(default_env_content)" "0640" "root" "$SERVICE_GROUP"
  write_managed_file_if_needed "$CONF_FILE" "$(default_config_content)" "0640" "root" "$SERVICE_GROUP"
  fix_runtime_permissions
}

normalize_repo_list() {
  local value="$1"

  value="${value//,/ }"
  # shellcheck disable=SC2086
  printf '%s' $value
}

prompt_cron_config() {
  local choice custom_cron

  printf '\nAgendamento do Gickup:\n'
  printf '  1) A cada 1 hora\n'
  printf '  2) Todo dia as 03:00 (padrao)\n'
  printf '  3) A cada 6 horas\n'
  printf '  4) Todo domingo as 03:00\n'
  printf '  5) Cron personalizado\n'
  read -r -p "Escolha [1/2/3/4/5]: " choice

  case "$choice" in
    1) CONFIG_CRON="0 * * * *" ;;
    2|"") CONFIG_CRON="0 3 * * *" ;;
    3) CONFIG_CRON="0 */6 * * *" ;;
    4) CONFIG_CRON="0 3 * * 0" ;;
    5)
      prompt_required "Cron personalizado (ex: 30 2 * * *): " custom_cron
      CONFIG_CRON="$custom_cron"
      ;;
    *) die "Opcao invalida." ;;
  esac
}

prompt_config_values() {
  local repos

  prompt_cron_config
  prompt_required "Usuario ou org de origem no GitHub (ex: yduanrech): " CONFIG_GITHUB_OWNER
  prompt_required "Repositorio(s) de origem no GitHub, separados por espaco ou virgula: " repos
  CONFIG_GITHUB_REPOS="$(normalize_repo_list "$repos")"
  prompt_required "Usuario ou org de destino no Codeberg (ex: yduanrech): " CONFIG_CODEBERG_OWNER

  printf '\nResumo da configuracao:\n'
  printf '  Cron: %s\n' "$CONFIG_CRON"
  printf '  GitHub origem: %s\n' "$CONFIG_GITHUB_OWNER"
  printf '  Repositorios: %s\n' "$CONFIG_GITHUB_REPOS"
  printf '  Codeberg destino: %s\n' "$CONFIG_CODEBERG_OWNER"
  printf '  Observacao: o Gickup usa o mesmo nome do repositorio no destino.\n'
  confirm_action "Recriar $CONF_FILE com essa configuracao? (y/N): " || die "Operacao cancelada."
}

cmd_configure() {
  need_root
  ensure_service_user_and_dirs
  prompt_config_values
  FORCE=true
  write_managed_file_if_needed "$CONF_FILE" "$(default_config_content)" "0640" "root" "$SERVICE_GROUP"
  fix_runtime_permissions
  log "Configuracao recriada em $CONF_FILE. Edite $ENV_FILE com os tokens antes de validar/iniciar."
}

service_content() {
  cat <<EOF
[Unit]
Description=Gickup repository mirror
Documentation=https://gickup.dev/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$CONFIG_DIR
Environment=HOME=$STATE_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$GICKUP_BIN $CONF_FILE
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
}

write_service_file() {
  log "Gravando $SERVICE_FILE..."
  write_file "$SERVICE_FILE" "$(service_content)"
  if [[ "$DRY_RUN" != "true" ]]; then
    chown root:root "$SERVICE_FILE"
    chmod 0644 "$SERVICE_FILE"
    systemctl daemon-reload
  fi
}

check_no_placeholders() {
  local file="$1"

  [[ -r "$file" ]] || die "Arquivo nao encontrado ou ilegivel: $file"
  if grep -q 'CHANGE_ME' "$file"; then
    die "$file ainda contem placeholders CHANGE_ME. Edite antes de validar/iniciar."
  fi
}

fix_runtime_permissions() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] ajustaria permissoes em $LOG_DIR e $LOCAL_BACKUP_DIR para $SERVICE_USER:$SERVICE_GROUP"
    return 0
  fi

  chown -R "$SERVICE_USER:$SERVICE_GROUP" "$LOG_DIR" "$LOCAL_BACKUP_DIR"
  chmod 0750 "$LOG_DIR" "$LOCAL_BACKUP_DIR"
  if [[ -f "$LOG_DIR/gickup.log" ]]; then
    chmod 0640 "$LOG_DIR/gickup.log"
  fi
}

validate_config() {
  need_root
  [[ -x "$GICKUP_BIN" ]] || die "Gickup nao encontrado em $GICKUP_BIN. Rode init primeiro."
  ensure_service_user_and_dirs
  check_no_placeholders "$ENV_FILE"
  check_no_placeholders "$CONF_FILE"

  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] executaria $GICKUP_BIN --dryrun com cron removido temporariamente"
    return 0
  fi

  log "Validando config com gickup --dryrun..."
  run_gickup_once "--dryrun"
  fix_runtime_permissions
}

run_gickup_once() {
  local mode="${1:-}"
  local tmp_config status

  tmp_config="$(mktemp --tmpdir="$STATE_DIR" gickup-conf.XXXXXX.yml)"
  sed '/^[[:space:]]*cron:/d' "$CONF_FILE" > "$tmp_config"
  chown "$SERVICE_USER:$SERVICE_GROUP" "$tmp_config"
  chmod 0640 "$tmp_config"

  set +e
  if [[ -n "$mode" ]]; then
    run_cmd runuser -u "$SERVICE_USER" -- bash -c 'set -a; . "$1"; set +a; export HOME="$2"; exec "$3" "$4" "$5"' _ "$ENV_FILE" "$STATE_DIR" "$GICKUP_BIN" "$mode" "$tmp_config"
  else
    run_cmd runuser -u "$SERVICE_USER" -- bash -c 'set -a; . "$1"; set +a; export HOME="$2"; exec "$3" "$4"' _ "$ENV_FILE" "$STATE_DIR" "$GICKUP_BIN" "$tmp_config"
  fi
  status=$?
  set -e

  rm -f "$tmp_config"
  fix_runtime_permissions
  return "$status"
}

cmd_init() {
  need_root
  install_latest_binary
  ensure_config_files
  write_service_file
  log "Base Gickup concluida. Edite $ENV_FILE e $CONF_FILE antes de enable-service."
}

cmd_update_binary() {
  need_root
  install_latest_binary
  log "Binario atualizado. Reinicie o servico para usar a nova versao se ele estiver ativo."
}

cmd_run_now() {
  need_root
  [[ -x "$GICKUP_BIN" ]] || die "Gickup nao encontrado em $GICKUP_BIN. Rode init primeiro."
  ensure_service_user_and_dirs
  check_no_placeholders "$ENV_FILE"
  check_no_placeholders "$CONF_FILE"
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] executaria backup/mirror agora com cron removido temporariamente"
    return 0
  fi

  log "Executando backup/mirror agora..."
  run_gickup_once
}

cmd_enable_service() {
  need_root
  validate_config
  fix_runtime_permissions
  run_cmd systemctl enable --now gickup.service
  log "Servico gickup habilitado/iniciado."
}

cmd_restart_service() {
  need_root
  validate_config
  fix_runtime_permissions
  run_cmd systemctl restart gickup.service
  log "Servico gickup reiniciado."
}

cmd_status() {
  need_root
  if [[ -x "$GICKUP_BIN" ]]; then
    "$GICKUP_BIN" --version || true
  else
    warn "Gickup nao encontrado em $GICKUP_BIN."
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl --no-pager --full status gickup.service || true
  fi
}

menu() {
  local choice

  while true; do
    printf '\n'
    printf '=======================================\n'
    printf ' GICKUP INSTALLER v%s\n' "$VERSION"
    [[ "$DRY_RUN" == "true" ]] && printf ' [DRY-RUN]\n'
    printf '=======================================\n'
    printf ' 1) Init / instalar base\n'
    printf ' 2) Configurar cron/repositorios\n'
    printf ' 3) Atualizar binario\n'
    printf ' 4) Validar config\n'
    printf ' 5) Executar agora\n'
    printf ' 6) Habilitar/iniciar servico\n'
    printf ' 7) Reiniciar servico\n'
    printf ' 8) Ver status/versao\n'
    printf ' 9) Ajuda\n'
    printf ' 0) Sair\n'
    printf '\n'
    read -r -p "Escolha: " choice

    case "$choice" in
      1)
        confirm_action "Instalar/atualizar base do Gickup? (y/N): " || die "Operacao cancelada."
        cmd_init
        if confirm_action "Configurar cron/repositorios agora? (y/N): "; then
          cmd_configure
        fi
        ;;
      2)
        cmd_configure
        ;;
      3)
        confirm_action "Atualizar apenas o binario do Gickup? (y/N): " || die "Operacao cancelada."
        cmd_update_binary
        ;;
      4)
        cmd_validate_config
        ;;
      5)
        confirm_action "Executar backup/mirror agora? (y/N): " || die "Operacao cancelada."
        cmd_run_now
        ;;
      6)
        confirm_action "Validar config e habilitar/iniciar gickup.service? (y/N): " || die "Operacao cancelada."
        cmd_enable_service
        ;;
      7)
        confirm_action "Validar config e reiniciar gickup.service? (y/N): " || die "Operacao cancelada."
        cmd_restart_service
        ;;
      8)
        cmd_status
        ;;
      9)
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

cmd_validate_config() {
  validate_config
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
  local cmd args=()
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
    configure)
      [[ ${#args[@]} -eq 0 ]] || die "Argumentos invalidos para configure."
      cmd_configure
      ;;
    update-binary)
      [[ ${#args[@]} -eq 0 ]] || die "Argumentos invalidos para update-binary."
      cmd_update_binary
      ;;
    validate-config)
      [[ ${#args[@]} -eq 0 ]] || die "Argumentos invalidos para validate-config."
      cmd_validate_config
      ;;
    run-now)
      [[ ${#args[@]} -eq 0 ]] || die "Argumentos invalidos para run-now."
      cmd_run_now
      ;;
    enable-service)
      [[ ${#args[@]} -eq 0 ]] || die "Argumentos invalidos para enable-service."
      cmd_enable_service
      ;;
    restart-service)
      [[ ${#args[@]} -eq 0 ]] || die "Argumentos invalidos para restart-service."
      cmd_restart_service
      ;;
    status)
      [[ ${#args[@]} -eq 0 ]] || die "Argumentos invalidos para status."
      cmd_status
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
