#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

CONTAINER_NAME_DEFAULT="<< container_name >>"
BACKUP_DIR_DEFAULT="<< backup_dir >>"
BACKUP_PREFIX_DEFAULT="<< backup_prefix >>"
POSTGRES_USER_DEFAULT="<< postgres_user >>"
POSTGRES_DATABASE_DEFAULT="<< postgres_database >>"
PASSWORD_ENV_DEFAULT="<< postgres_password_env >>"
COMPRESS_BACKUP_DEFAULT="<< compress_backup >>"
RETENTION_DAYS_DEFAULT="<< retention_days >>"
CREATE_LATEST_SYMLINK_DEFAULT="<< create_latest_symlink >>"
DRY_RUN_DEFAULT="<< dry_run >>"

CONTAINER_NAME="$CONTAINER_NAME_DEFAULT"
BACKUP_DIR="$BACKUP_DIR_DEFAULT"
BACKUP_PREFIX="$BACKUP_PREFIX_DEFAULT"
POSTGRES_USER="$POSTGRES_USER_DEFAULT"
POSTGRES_DATABASE="$POSTGRES_DATABASE_DEFAULT"
PASSWORD_ENV="$PASSWORD_ENV_DEFAULT"
COMPRESS_BACKUP="$COMPRESS_BACKUP_DEFAULT"
RETENTION_DAYS="$RETENTION_DAYS_DEFAULT"
CREATE_LATEST_SYMLINK="$CREATE_LATEST_SYMLINK_DEFAULT"
DRY_RUN="$DRY_RUN_DEFAULT"

TMP_PATH=""
FINAL_PATH=""
LATEST_PATH=""

usage() {
  printf '%s\n' \
    "Usage:" \
    "  $SCRIPT_NAME [options]" \
    "" \
    "Back up PostgreSQL from a running Docker container to a timestamped SQL file." \
    "" \
    "Options:" \
    "  --container NAME         Source PostgreSQL container (default: $CONTAINER_NAME_DEFAULT)" \
    "  --backup-dir PATH        Host directory for backup files (default: $BACKUP_DIR_DEFAULT)" \
    "  --prefix PREFIX          Backup filename prefix (default: $BACKUP_PREFIX_DEFAULT)" \
    "  --user USER              PostgreSQL user for pg_dump/pg_dumpall (default: $POSTGRES_USER_DEFAULT)" \
    "  --database NAME          Database to dump, or 'all' (default: $POSTGRES_DATABASE_DEFAULT)" \
    "  --password-env NAME      Host env var holding the database password (default: $PASSWORD_ENV_DEFAULT)" \
    "  --compress               Write .sql.gz output" \
    "  --no-compress            Write plain .sql output" \
    "  --retention-days DAYS    Delete matching backups older than DAYS; 0 disables cleanup (default: $RETENTION_DAYS_DEFAULT)" \
    "  --latest                 Update a latest symlink after a successful backup" \
    "  --no-latest              Do not update a latest symlink" \
    "  --dry-run                Print actions without writing backup files or deleting old backups" \
    "  -h, --help               Show this help output" \
    "" \
    "Examples:" \
    "  export PGPASSWORD  # supply through your secret manager" \
    "  $SCRIPT_NAME --container postgres --backup-dir /backups/postgres --database appdb" \
    "  $SCRIPT_NAME --container postgres --database all --retention-days 30" \
    "  $SCRIPT_NAME --database appdb --no-compress --dry-run" \
    "" \
    "Exit codes:" \
    "  0 on success or dry-run success; non-zero if preflight, dump, compression, retention, or symlink steps fail."
}

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

on_error() {
  local status="$1"
  local line="$2"
  printf '[ERROR] Unhandled failure at line %s; exiting with status %s.\n' "$line" "$status" >&2
  cleanup_tmp
  exit "$status"
}

cleanup_tmp() {
  if [[ -n "${TMP_PATH:-}" && -e "$TMP_PATH" ]]; then
    rm -f -- "$TMP_PATH" || true
  fi
}

trap 'on_error "$?" "$LINENO"' ERR
trap cleanup_tmp EXIT

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

load_password() {
  PASSWORD_VALUE=""
  if [[ -n "$PASSWORD_ENV" ]]; then
    if [[ -n "${!PASSWORD_ENV:-}" ]]; then
      PASSWORD_VALUE="${!PASSWORD_ENV}"
    else
      warn "Password env variable '$PASSWORD_ENV' is not set; attempting backup without it."
    fi
  fi
}

docker_postgres_dump() {
  if [[ "$POSTGRES_DATABASE" == "all" ]]; then
    if [[ -n "${PASSWORD_VALUE:-}" ]]; then
      docker exec -i -e "PGPASSWORD=$PASSWORD_VALUE" "$CONTAINER_NAME" \
        pg_dumpall -U "$POSTGRES_USER"
    else
      docker exec -i "$CONTAINER_NAME" \
        pg_dumpall -U "$POSTGRES_USER"
    fi
  else
    if [[ -n "${PASSWORD_VALUE:-}" ]]; then
      docker exec -i -e "PGPASSWORD=$PASSWORD_VALUE" "$CONTAINER_NAME" \
        pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" --format=plain
    else
      docker exec -i "$CONTAINER_NAME" \
        pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" --format=plain
    fi
  fi
}

preflight() {
  require_command docker
  require_command date
  require_command find
  require_command mkdir
  require_command mv
  require_command rm
  require_command tr
  require_command sed

  if bool_is_true "$COMPRESS_BACKUP"; then
    require_command gzip
  fi

  [[ -n "$CONTAINER_NAME" ]] || fail "Container name must not be empty."
  [[ -n "$BACKUP_DIR" ]] || fail "Backup directory must not be empty."
  [[ -n "$BACKUP_PREFIX" ]] || fail "Backup prefix must not be empty."
  [[ -n "$POSTGRES_USER" ]] || fail "Postgres user must not be empty."
  [[ -n "$POSTGRES_DATABASE" ]] || fail "Database name must not be empty."
  is_nonnegative_int "$RETENTION_DAYS" || fail "Retention days must be a non-negative integer."

  docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 || fail "Docker container not found: $CONTAINER_NAME"
  if [[ "$POSTGRES_DATABASE" == "all" ]]; then
    docker exec "$CONTAINER_NAME" sh -c 'command -v pg_dumpall >/dev/null 2>&1' || fail "pg_dumpall is not available inside container: $CONTAINER_NAME"
  else
    docker exec "$CONTAINER_NAME" sh -c 'command -v pg_dump >/dev/null 2>&1' || fail "pg_dump is not available inside container: $CONTAINER_NAME"
  fi
}

build_paths() {
  local timestamp
  local safe_container
  local safe_database
  local extension

  timestamp="$(date +%Y%m%d-%H%M%S)"
  safe_container="$(safe_name "$CONTAINER_NAME")"
  safe_database="$(safe_name "$POSTGRES_DATABASE")"

  if [[ "$POSTGRES_DATABASE" == "all" ]]; then
    safe_database="all_databases"
  fi

  if bool_is_true "$COMPRESS_BACKUP"; then
    extension="sql.gz"
  else
    extension="sql"
  fi

  FINAL_PATH="$BACKUP_DIR/${BACKUP_PREFIX}_${safe_container}_${safe_database}_${timestamp}.${extension}"
  TMP_PATH="$FINAL_PATH.tmp.$$"
  LATEST_PATH="$BACKUP_DIR/${BACKUP_PREFIX}_${safe_container}_${safe_database}_latest.${extension}"
}

print_plan() {
  printf '%s\n' \
    "Backup plan" \
    "  Container:        $CONTAINER_NAME" \
    "  Backup Dir:       $BACKUP_DIR" \
    "  Output File:      $FINAL_PATH" \
    "  User:             $POSTGRES_USER" \
    "  Database:         $POSTGRES_DATABASE" \
    "  Password env:     ${PASSWORD_ENV:-<disabled>}" \
    "  Compress:         $COMPRESS_BACKUP" \
    "  Retention Days:   $RETENTION_DAYS" \
    "  Latest Symlink:   $CREATE_LATEST_SYMLINK" \
    "  Dry Run:          $DRY_RUN"
}

write_backup() {
  mkdir -p -- "$BACKUP_DIR"

  log "Writing backup to temporary file: $TMP_PATH"
  if bool_is_true "$COMPRESS_BACKUP"; then
    if ! docker_postgres_dump | gzip -c > "$TMP_PATH"; then
      cleanup_tmp
      fail "PostgreSQL dump or gzip compression failed."
    fi
  else
    if ! docker_postgres_dump > "$TMP_PATH"; then
      cleanup_tmp
      fail "PostgreSQL dump failed."
    fi
  fi

  [[ -s "$TMP_PATH" ]] || fail "Backup file is empty: $TMP_PATH"
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
  local safe_database
  local extension

  safe_container="$(safe_name "$CONTAINER_NAME")"
  safe_database="$(safe_name "$POSTGRES_DATABASE")"
  [[ "$POSTGRES_DATABASE" == "all" ]] && safe_database="all_databases"
  bool_is_true "$COMPRESS_BACKUP" && extension="sql.gz" || extension="sql"
  pattern="${BACKUP_PREFIX}_${safe_container}_${safe_database}_*.${extension}"

  log "Deleting matching backups older than $RETENTION_DAYS days."
  find "$BACKUP_DIR" -maxdepth 1 -type f -name "$pattern" -mtime +"$RETENTION_DAYS" -print -exec rm -f -- {} +
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --container) CONTAINER_NAME="${2:-}"; shift 2 ;;
    --backup-dir) BACKUP_DIR="${2:-}"; shift 2 ;;
    --prefix) BACKUP_PREFIX="${2:-}"; shift 2 ;;
    --user) POSTGRES_USER="${2:-}"; shift 2 ;;
    --database) POSTGRES_DATABASE="${2:-}"; shift 2 ;;
    --password-env) PASSWORD_ENV="${2:-}"; shift 2 ;;
    --compress) COMPRESS_BACKUP="true"; shift ;;
    --no-compress) COMPRESS_BACKUP="false"; shift ;;
    --retention-days) RETENTION_DAYS="${2:-}"; shift 2 ;;
    --latest) CREATE_LATEST_SYMLINK="true"; shift ;;
    --no-latest) CREATE_LATEST_SYMLINK="false"; shift ;;
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

preflight
load_password
build_paths
print_plan

if bool_is_true "$DRY_RUN"; then
  log "Dry-run enabled; no backup file, symlink, or retention changes were made."
  exit 0
fi

write_backup
update_latest_symlink
cleanup_retention

log "Done."
