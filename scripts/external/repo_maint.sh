#!/usr/bin/env bash
set -euo pipefail
[[ "${DEBUG:-0}" == "1" ]] && set -x

# ---------- Path & args ----------
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARG1="${1:-}"; ARG2="${2:-}"

# Decide REPO_DIR (0-arg mode if script lives in the repo)
if [[ -n "$ARG1" && -d "$ARG1" ]]; then
  REPO_DIR="$(cd "$ARG1" && pwd)"; shift || true
else
  if [[ -f "$_script_dir/.repo-maint.conf" ]] || ls "$_script_dir"/{docker-compose.yml,compose.yml,docker-compose.yaml,compose.yaml} >/dev/null 2>&1; then
    REPO_DIR="$_script_dir"
  else
    REPO_DIR="$PWD"
  fi
fi
SUBCMD="${1:-run}"

cd "$REPO_DIR"
CONFIG_FILE="${REPO_DIR}/.repo-maint.conf"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# ---------- Defaults ----------
REPO_NAME="${REPO_NAME:-$(basename "$REPO_DIR")}"
STOP_TIMEOUT="${STOP_TIMEOUT:-120}"

BACKUP_MODE="${BACKUP_MODE:-incremental}"   # incremental only (full on first run)
BACKUP_EXCLUDES="${BACKUP_EXCLUDES:-.git node_modules}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups}"
SNAPSHOT_DIR="${SNAPSHOT_DIR:-.backup-snapshots}"

COMPRESS="${COMPRESS:-7z}"                  # tar|gz|zstd|7z
GZ_LEVEL="${GZ_LEVEL:-9}"
ZSTD_LEVEL="${ZSTD_LEVEL:-19}"
SEVENZ_LEVEL="${SEVENZ_LEVEL:-9}"
BACKUP_PASSWORD="${BACKUP_PASSWORD:-}"      # only for 7z

UPLOAD="${UPLOAD:-true}"
GDRIVE_REMOTE="${GDRIVE_REMOTE:-}"
RETENTION_LOCAL_DAYS="${RETENTION_LOCAL_DAYS:-2}"
RETENTION_REMOTE_DAYS="${RETENTION_REMOTE_DAYS:-30}"

SCHEDULE_BACKUP_CRON="${SCHEDULE_BACKUP_CRON:-0 3 * * *}"
SCHEDULE_RESTART_CRON="${SCHEDULE_RESTART_CRON:-7 */4 * * *}"

LOCKDIR="${BACKUP_DIR}/.locks"
mkdir -p "$BACKUP_DIR" "$LOCKDIR" "$REPO_DIR/$SNAPSHOT_DIR"
umask 077

timestamp(){ date +"%Y%m%d_%H%M%S"; }
log(){ echo "[$(date +'%F %T')]" "$@" >&2; }
have(){ command -v "$1" >/dev/null 2>&1; }

compose_cmd(){
  if have docker && docker compose version >/dev/null 2>&1; then echo "docker compose";
  elif have docker-compose; then echo "docker-compose";
  else echo "docker compose"; fi
}
# Auto-detect compose files if not set
if [[ -z "${COMPOSE_FILES:-}" ]]; then
  _candidates=(docker-compose.yml docker-compose.yaml compose.yml compose.yaml docker-compose-dev.yml docker-compose-prod.yml)
  COMPOSE_FILES=""
  for f in "${_candidates[@]}"; do [[ -f "$REPO_DIR/$f" ]] && COMPOSE_FILES="${COMPOSE_FILES:+$COMPOSE_FILES,}$f"; done
fi
compose_files_args(){ local IFS=,; for f in $COMPOSE_FILES; do [[ -f "$REPO_DIR/$f" ]] && printf ' -f %q' "$REPO_DIR/$f"; done; }

DC="$(compose_cmd)"; CFA="$(compose_files_args)"
require_compose_files(){ [[ -n "$CFA" ]] || { echo "No compose files found in ${REPO_DIR}. Set COMPOSE_FILES in .repo-maint.conf"; exit 1; }; }

# ---------- Compose control ----------
compose_ps_running(){ # shellcheck disable=SC2086
  local n="$($DC $CFA ps --status=running -q | wc -l | tr -d ' ')"; echo "$n"; }

do_stop(){
  require_compose_files
  log "Stopping Docker Compose services..."
  # shellcheck disable=SC2086
  $DC $CFA stop
  log "Waiting up to ${STOP_TIMEOUT}s for containers to stop..."
  local deadline=$(( $(date +%s) + STOP_TIMEOUT ))
  while (( $(compose_ps_running) > 0 )); do
    (( $(date +%s) > deadline )) && { echo "Timed out waiting for stop."; exit 1; }
    sleep 2
  done
  log "All containers stopped."
}
do_start(){ require_compose_files; log "Starting services..."; # shellcheck disable=SC2086
  $DC $CFA up -d; }
do_restart(){ do_stop; do_start; }

# ---------- Backup ----------
build_exclude_file(){
  local exfile; exfile="$(mktemp)"
  while IFS= read -r pat; do [[ -n "$pat" ]] && echo "$pat"; done \
    < <(printf "%s\n" $BACKUP_EXCLUDES) > "$exfile"
  echo "$exfile"
}
archive_path(){
  local kind="$1"; local base="${BACKUP_DIR}/${REPO_NAME}_$(timestamp)_${kind}"
  case "$COMPRESS" in
    tar)  echo "${base}.tar" ;;
    gz)   echo "${base}.tar.gz" ;;
    zstd) echo "${base}.tar.zst" ;;
    7z)   echo "${base}.tar.7z" ;;
    *) echo "Unsupported COMPRESS: $COMPRESS" >&2; exit 2 ;;
  esac
}
backup_stream(){
  local kind="$1"; local exfile="$2"
  local out; out="$(archive_path "$kind")"
  local snapshot="${REPO_DIR}/${SNAPSHOT_DIR}/${REPO_NAME}.snar"
  log "Creating ${kind^^} backup -> $out"

  # Full on first run = remove snapshot; otherwise incremental
  if [[ "$kind" == "full" ]]; then rm -f "$snapshot" 2>/dev/null || true; fi
  TAR_CMD=(tar -C "$REPO_DIR" --listed-incremental="$snapshot" -cf - --exclude-vcs --exclude-from="$exfile" .)

  case "$COMPRESS" in
    tar)  "${TAR_CMD[@]}" > "$out" ;;
    gz)   "${TAR_CMD[@]}" | gzip -"$GZ_LEVEL" > "$out" ;;
    zstd) "${TAR_CMD[@]}" | zstd -q -"$ZSTD_LEVEL" -T0 -o "$out" ;;
    7z)
      local args=(-mx="$SEVENZ_LEVEL")
      [[ -n "$BACKUP_PASSWORD" ]] && args+=("-p$BACKUP_PASSWORD" "-mhe=on")
      "${TAR_CMD[@]}" | 7z a "${args[@]}" -si"backup.tar" "$out" >/dev/null
      ;;
  esac
  echo "$out"
}
cleanup_local(){
  log "Pruning local backups older than ${RETENTION_LOCAL_DAYS} days..."
  find "$BACKUP_DIR" -type f -name "${REPO_NAME}_*.tar*" -mtime +"$RETENTION_LOCAL_DAYS" -print -delete || true
}
upload_remote(){
  local file="$1"
  if [[ "$UPLOAD" != "true" || -z "$GDRIVE_REMOTE" ]]; then
    log "Skipping upload (UPLOAD=${UPLOAD}, GDRIVE_REMOTE='${GDRIVE_REMOTE}')."; return 0; fi
  log "Uploading ${file} -> ${GDRIVE_REMOTE} ..."
  rclone copy "$file" "$GDRIVE_REMOTE" --checksum --transfers=4 --checkers=8 --fast-list
  log "Upload complete."
  if [[ -n "${RETENTION_REMOTE_DAYS}" ]]; then
    log "Pruning remote older than ${RETENTION_REMOTE_DAYS} days..."
    rclone delete "$GDRIVE_REMOTE" --min-age "${RETENTION_REMOTE_DAYS}d" --fast-list || true
    rclone rmdirs "$GDRIVE_REMOTE" --leave-root || true
  fi
}

# ---------- Cron (dual: backup daily + restart every 4h) ----------
_abs(){ if command -v realpath >/dev/null 2>&1; then realpath "$1"; else (cd "$1" 2>/dev/null && pwd) || echo "$1"; fi; }
cron_marker_begin(){ echo "# --- BEGIN REPO_MAINT $(_abs "$REPO_DIR") ---"; }
cron_marker_end(){   echo "# --- END REPO_MAINT $(_abs "$REPO_DIR") ---"; }
install_cron_dual(){
  local script_path="$(_abs "$_script_dir")/$(basename "$0")"
  local repo_path="$(_abs "$REPO_DIR")"
  local backup="${SCHEDULE_BACKUP_CRON} ${script_path} ${repo_path}"
  local restart="${SCHEDULE_RESTART_CRON} ${script_path} ${repo_path} --restart-only"
  local begin; begin="$(cron_marker_begin)"; local end; end="$(cron_marker_end)"
  local current; current="$(crontab -l 2>/dev/null || true)"
  current="$(printf "%s\n" "$current" | awk -v b="$begin" -v e="$end" 'BEGIN{skip=0} $0==b{skip=1;next} $0==e{skip=0;next} !skip')"
  { printf "%s\n" "$current"; echo "$begin"; echo "$backup"; echo "$restart"; echo "$end"; } | crontab -
  log "Cron installed:"; log "  $backup"; log "  $restart"
}
remove_cron(){
  local begin; begin="$(cron_marker_begin)"; local end; end="$(cron_marker_end)"
  local current; current="$(crontab -l 2>/dev/null || true)"
  current="$(printf "%s\n" "$current" | awk -v b="$begin" -v e="$end" 'BEGIN{skip=0} $0==b{skip=1;next} $0==e{skip=0;next} !skip')"
  printf "%s\n" "$current" | crontab -
  log "Cron removed for ${REPO_DIR}"
}

# ---------- Pipeline ----------
MONGODB_BACKUP_ENABLED="${MONGODB_BACKUP_ENABLED:-false}"
MONGODB_CONTAINER="${MONGODB_CONTAINER:-mongodb}"
MONGODB_USER="${MONGODB_USER:-root}"
MONGODB_PASSWORD_ENV_FILE="${MONGODB_PASSWORD_ENV_FILE:-.env-mongodb}"
MONGODB_PASSWORD_ENV_VAR="${MONGODB_PASSWORD_ENV_VAR:-MONGO_INITDB_ROOT_PASSWORD}"

mongodb_backup() {
  [[ "$MONGODB_BACKUP_ENABLED" != "true" ]] && return 0
  log "Starting mongodb backup with container $MONGODB_CONTAINER ..."
  if [[ -f "$REPO_DIR/$MONGODB_PASSWORD_ENV_FILE" ]]; then
    MONGODB_PASSWORD=$(grep "^$MONGODB_PASSWORD_ENV_VAR=" "$REPO_DIR/$MONGODB_PASSWORD_ENV_FILE" | cut -d'=' -f2-)
  else
    log "WARNING: $MONGODB_PASSWORD_ENV_FILE not found, skipped MongoDB Backup."
    return 1
  fi
  if [[ -z "$MONGODB_PASSWORD" ]]; then
    log "WARNING: MongoDB Password not found, skipped MongoDB Backup."
    return 1
  fi
  local mongo_backup_file="$BACKUP_DIR/mongodb_$(timestamp).dump"
  docker exec "$MONGODB_CONTAINER" sh -c "mongodump -u $MONGODB_USER -p $MONGODB_PASSWORD --archive --gzip" > "$BACKUP_DIR/$mongo_backup_file"
  log "MongoDB Backup saved as $BACKUP_DIR/$MONGODB_BACKUP_FILE"
  upload_remote "$mongo_backup_file"
}

run_pipeline(){
  local LOCKFILE="${LOCKDIR}/${REPO_NAME}.lock"
  exec 9>"$LOCKFILE"; flock -n 9 || { echo "Another run is in progress for ${REPO_NAME}"; exit 1; }

  if [[ "$SUBCMD" == "--restart-only" ]]; then do_restart; return; fi
  if [[ "$SUBCMD" != "--backup-only" ]]; then do_stop; fi

  # MongoDB Backup in front of the minecraft server backup
  mongodb_backup

  local exfile; exfile="$(build_exclude_file)"; trap '[[ -n ${exfile-} ]] && rm -f "$exfile"' EXIT
  local kind="inc"; [[ "$BACKUP_MODE" == "incremental" ]] || kind="full"
  # First run produces a full automatically (no snapshot yet)
  [[ ! -f "${REPO_DIR}/${SNAPSHOT_DIR}/${REPO_NAME}.snar" ]] && kind="full"

  local archive; archive="$(backup_stream "$kind" "$exfile" | tail -n1)"
  upload_remote "$archive"
  cleanup_local

  if [[ "$SUBCMD" != "--backup-only" ]]; then do_start; fi
  log "All done for ${REPO_NAME}."
}

case "$SUBCMD" in
  run|--backup-only|--restart-only) run_pipeline ;;
  --install-cron-dual) install_cron_dual ;;
  --remove-cron)  remove_cron ;;
  *) echo "Usage: $0 [REPO_DIR] [run|--backup-only|--restart-only|--install-cron-dual|--remove-cron]"; exit 2 ;;
esac
