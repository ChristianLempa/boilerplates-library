#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

CONTAINER_NAME_DEFAULT="<< container_name >>"
BACKUP_DIR_DEFAULT="<< backup_dir >>"
BACKUP_PREFIX_DEFAULT="<< backup_prefix >>"
BACKUP_CONTAINER_PATH_DEFAULT="<< backup_container_path >>"
HELPER_IMAGE_DEFAULT="<< helper_image >>"
STOP_CONTAINER_DEFAULT="<< stop_container_during_backup >>"
START_CONTAINER_DEFAULT="<< start_container_after_backup >>"
RETENTION_DAYS_DEFAULT="<< retention_days >>"
CREATE_LATEST_SYMLINK_DEFAULT="<< create_latest_symlink >>"
DRY_RUN_DEFAULT="<< dry_run >>"

CONTAINER_NAME="$CONTAINER_NAME_DEFAULT"
BACKUP_DIR="$BACKUP_DIR_DEFAULT"
BACKUP_PREFIX="$BACKUP_PREFIX_DEFAULT"
BACKUP_CONTAINER_PATH="$BACKUP_CONTAINER_PATH_DEFAULT"
HELPER_IMAGE="$HELPER_IMAGE_DEFAULT"
STOP_CONTAINER="$STOP_CONTAINER_DEFAULT"
START_CONTAINER="$START_CONTAINER_DEFAULT"
RETENTION_DAYS="$RETENTION_DAYS_DEFAULT"
CREATE_LATEST_SYMLINK="$CREATE_LATEST_SYMLINK_DEFAULT"
DRY_RUN="$DRY_RUN_DEFAULT"

TMP_PATH=""
FINAL_PATH=""
LATEST_PATH=""
STOPPED_BY_SCRIPT="false"
TAR_PARENT=""
TAR_BASENAME=""

usage() {
  printf '%s\n' \
    "Usage:" \
    "  $SCRIPT_NAME [options]" \
    "" \
    "Back up a path from a Docker container's mounted volumes to a timestamped .tar.gz archive." \
    "" \
    "Options:" \
    "  --container NAME         Source container (default: $CONTAINER_NAME_DEFAULT)" \
    "  --backup-dir PATH        Host directory for backup files (default: $BACKUP_DIR_DEFAULT)" \
    "  --prefix PREFIX          Backup filename prefix (default: $BACKUP_PREFIX_DEFAULT)" \
    "  --path PATH              Container path to archive (default: $BACKUP_CONTAINER_PATH_DEFAULT)" \
    "  --helper-image IMAGE     Helper image used to read mounted volumes (default: $HELPER_IMAGE_DEFAULT)" \
    "  --stop-container         Stop the target container during backup" \
    "  --no-stop-container      Leave the target container running" \
    "  --start-container        Restart the container if this script stopped it" \
    "  --no-start-container     Leave the container stopped if this script stopped it" \
    "  --retention-days DAYS    Delete matching backups older than DAYS; 0 disables cleanup (default: $RETENTION_DAYS_DEFAULT)" \
    "  --latest                 Update a latest symlink after a successful backup" \
    "  --no-latest              Do not update a latest symlink" \
    "  --dry-run                Print actions without writing backup files, stopping containers, or deleting old backups" \
    "  -h, --help               Show this help output" \
    "" \
    "Examples:" \
    "  $SCRIPT_NAME --container app --backup-dir /backups/docker --path /config" \
    "  $SCRIPT_NAME --container app --path /var/lib/app --stop-container --retention-days 30" \
    "  $SCRIPT_NAME --container app --path /config --dry-run" \
    "" \
    "Notes:" \
    "  - The archive contains the basename of --path. For --path /config, the archive contains config/..." \
    "  - Use --stop-container for applications that write actively to the backed-up path." \
    "" \
    "Exit codes:" \
    "  0 on success or dry-run success; non-zero if preflight, stop/start, archive, retention, or symlink steps fail."
}

log() {
  printf '[INFO] %s\n' "$*"
}

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

cleanup_tmp() {
  if [[ -n "${TMP_PATH:-}" && -e "$TMP_PATH" ]]; then
    rm -f -- "$TMP_PATH" || true
  fi
}

restart_if_needed() {
  if [[ "$STOPPED_BY_SCRIPT" == "true" ]] && bool_is_true "$START_CONTAINER"; then
    log "Starting container again: $CONTAINER_NAME"
    if docker start "$CONTAINER_NAME" >/dev/null; then
      STOPPED_BY_SCRIPT="false"
      log "Container started: $CONTAINER_NAME"
      return 0
    fi
    printf '[ERROR] Failed to start container after backup: %s\n' "$CONTAINER_NAME" >&2
    return 1
  fi

  return 0
}

on_error() {
  local status="$1"
  local line="$2"
  printf '[ERROR] Unhandled failure at line %s; exiting with status %s.\n' "$line" "$status" >&2
  exit "$status"
}

on_exit() {
  local status="$1"

  cleanup_tmp

  if ! restart_if_needed; then
    status=1
  fi

  exit "$status"
}

trap 'on_error "$?" "$LINENO"' ERR
trap 'on_exit "$?"' EXIT

bool_is_true() {
  case "$1" in
    true|True|TRUE|1|yes|Yes|YES|y|Y|on|On|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

is_nonnegative_int() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

safe_name() {
  printf '%s' "$1" | tr -c '[:alnum:]_.-' '_' | sed 's/^_*//; s/_*$//; s/__*/_/g'
}

normalize_path() {
  BACKUP_CONTAINER_PATH="/${BACKUP_CONTAINER_PATH#/}"
  BACKUP_CONTAINER_PATH="${BACKUP_CONTAINER_PATH%/}"

  [[ "$BACKUP_CONTAINER_PATH" != "/" ]] || fail "Backing up the container root path '/' is not supported by this template. Choose a specific path."

  TAR_PARENT="$(dirname "$BACKUP_CONTAINER_PATH")"
  TAR_BASENAME="$(basename "$BACKUP_CONTAINER_PATH")"
}

preflight() {
  require_command docker
  require_command date
  require_command dirname
  require_command basename
  require_command find
  require_command mkdir
  require_command mv
  require_command rm
  require_command tr
  require_command sed

  [[ -n "$CONTAINER_NAME" ]] || fail "Container name must not be empty."
  [[ -n "$BACKUP_DIR" ]] || fail "Backup directory must not be empty."
  [[ -n "$BACKUP_PREFIX" ]] || fail "Backup prefix must not be empty."
  [[ -n "$BACKUP_CONTAINER_PATH" ]] || fail "Container path must not be empty."
  [[ -n "$HELPER_IMAGE" ]] || fail "Helper image must not be empty."
  is_nonnegative_int "$RETENTION_DAYS" || fail "Retention days must be a non-negative integer."

  docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 || fail "Docker container not found: $CONTAINER_NAME"

  if ! bool_is_true "$DRY_RUN"; then
    docker run --rm --volumes-from "$CONTAINER_NAME" "$HELPER_IMAGE" \
      sh -c 'test -e "$1"' sh "$BACKUP_CONTAINER_PATH" || fail "Path not found through container volumes: $BACKUP_CONTAINER_PATH"
  fi
}

build_paths() {
  local timestamp
  local safe_container
  local safe_path

  timestamp="$(date +%Y%m%d-%H%M%S)"
  safe_container="$(safe_name "$CONTAINER_NAME")"
  safe_path="$(safe_name "${BACKUP_CONTAINER_PATH#/}")"

  FINAL_PATH="$BACKUP_DIR/${BACKUP_PREFIX}_${safe_container}_${safe_path}_${timestamp}.tar.gz"
  TMP_PATH="$FINAL_PATH.tmp.$$"
  LATEST_PATH="$BACKUP_DIR/${BACKUP_PREFIX}_${safe_container}_${safe_path}_latest.tar.gz"
}

print_plan() {
  printf '%s\n' \
    "Backup plan" \
    "  Container:        $CONTAINER_NAME" \
    "  Container Path:   $BACKUP_CONTAINER_PATH" \
    "  Archive Root:     $TAR_PARENT" \
    "  Archive Entry:    $TAR_BASENAME" \
    "  Helper Image:     $HELPER_IMAGE" \
    "  Backup Dir:       $BACKUP_DIR" \
    "  Output File:      $FINAL_PATH" \
    "  Stop Container:   $STOP_CONTAINER" \
    "  Restart After:    $START_CONTAINER" \
    "  Retention Days:   $RETENTION_DAYS" \
    "  Latest Symlink:   $CREATE_LATEST_SYMLINK" \
    "  Dry Run:          $DRY_RUN"
}

container_is_running() {
  [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" == "true" ]]
}

stop_container_if_needed() {
  bool_is_true "$STOP_CONTAINER" || return 0

  if container_is_running; then
    log "Stopping container for backup consistency: $CONTAINER_NAME"
    docker stop "$CONTAINER_NAME" >/dev/null
    STOPPED_BY_SCRIPT="true"
  else
    log "Container is already stopped: $CONTAINER_NAME"
  fi
}

write_backup() {
  mkdir -p -- "$BACKUP_DIR"

  log "Writing archive to temporary file: $TMP_PATH"
  if ! docker run --rm --volumes-from "$CONTAINER_NAME" "$HELPER_IMAGE" \
    tar -C "$TAR_PARENT" -czf - "$TAR_BASENAME" > "$TMP_PATH"; then
    cleanup_tmp
    fail "Docker volume archive failed."
  fi

  [[ -s "$TMP_PATH" ]] || fail "Backup archive is empty: $TMP_PATH"
  mv -- "$TMP_PATH" "$FINAL_PATH"
  TMP_PATH=""
  log "Backup completed: $FINAL_PATH"
}

update_latest_symlink() {
  bool_is_true "$CREATE_LATEST_SYMLINK" || return 0

  ln -sfn "$(basename "$FINAL_PATH")" "$LATEST_PATH"
  log "Latest symlink updated: $LATEST_PATH"
}

cleanup_retention() {
  if [[ "$RETENTION_DAYS" == "0" ]]; then
    log "Retention cleanup disabled."
    return 0
  fi

  local pattern
  local safe_container
  local safe_path

  safe_container="$(safe_name "$CONTAINER_NAME")"
  safe_path="$(safe_name "${BACKUP_CONTAINER_PATH#/}")"
  pattern="${BACKUP_PREFIX}_${safe_container}_${safe_path}_*.tar.gz"

  log "Deleting matching backups older than $RETENTION_DAYS days."
  find "$BACKUP_DIR" -maxdepth 1 -type f -name "$pattern" -mtime +"$RETENTION_DAYS" -print -exec rm -f -- {} +
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --container) CONTAINER_NAME="${2:-}"; shift 2 ;;
    --backup-dir) BACKUP_DIR="${2:-}"; shift 2 ;;
    --prefix) BACKUP_PREFIX="${2:-}"; shift 2 ;;
    --path) BACKUP_CONTAINER_PATH="${2:-}"; shift 2 ;;
    --helper-image) HELPER_IMAGE="${2:-}"; shift 2 ;;
    --stop-container) STOP_CONTAINER="true"; shift ;;
    --no-stop-container) STOP_CONTAINER="false"; shift ;;
    --start-container) START_CONTAINER="true"; shift ;;
    --no-start-container) START_CONTAINER="false"; shift ;;
    --retention-days) RETENTION_DAYS="${2:-}"; shift 2 ;;
    --latest) CREATE_LATEST_SYMLINK="true"; shift ;;
    --no-latest) CREATE_LATEST_SYMLINK="false"; shift ;;
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

normalize_path
preflight
build_paths
print_plan

if bool_is_true "$DRY_RUN"; then
  log "Dry-run enabled; no backup file, container state, symlink, or retention changes were made."
  exit 0
fi

stop_container_if_needed
write_backup
restart_if_needed
update_latest_symlink
cleanup_retention

log "Done."
