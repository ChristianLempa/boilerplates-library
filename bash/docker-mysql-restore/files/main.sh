#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

CONTAINER_NAME_DEFAULT="<< container_name >>"
ARCHIVE_PATH_DEFAULT="<< archive_path >>"
MYSQL_USER_DEFAULT="<< mysql_user >>"
MYSQL_DATABASE_DEFAULT="<< mysql_database >>"
PASSWORD_ENV_DEFAULT="<< mysql_password_env >>"
DROP_RECREATE_DEFAULT="<< drop_recreate_database >>"
DRY_RUN_DEFAULT="<< dry_run >>"
AUTO_YES_DEFAULT="<< auto_yes >>"

CONTAINER_NAME="$CONTAINER_NAME_DEFAULT"
ARCHIVE_PATH="$ARCHIVE_PATH_DEFAULT"
MYSQL_USER="$MYSQL_USER_DEFAULT"
MYSQL_DATABASE="$MYSQL_DATABASE_DEFAULT"
PASSWORD_ENV="$PASSWORD_ENV_DEFAULT"
DROP_RECREATE="$DROP_RECREATE_DEFAULT"
DRY_RUN="$DRY_RUN_DEFAULT"
AUTO_YES="$AUTO_YES_DEFAULT"

usage() {
  printf '%s\n' \
    "Usage:" \
    "  $SCRIPT_NAME [options]" \
    "" \
    "Restore a MySQL or MariaDB .sql or .sql.gz archive into a running Docker container." \
    "" \
    "Options:" \
    "  --container NAME         Target MySQL/MariaDB container (default: $CONTAINER_NAME_DEFAULT)" \
    "  --archive PATH           Path to a .sql or .sql.gz archive (default: $ARCHIVE_PATH_DEFAULT)" \
    "  --user USER              Database user for mysql (default: $MYSQL_USER_DEFAULT)" \
    "  --database NAME          Target database or 'all' (default: $MYSQL_DATABASE_DEFAULT)" \
    "  --password-env NAME      Host env var holding the database password (default: $PASSWORD_ENV_DEFAULT)" \
    "  --drop-recreate          Drop and recreate the target database before restore" \
    "  --no-drop-recreate       Leave the target database in place" \
    "  --dry-run                Print actions without changing the target" \
    "  --yes                    Skip the confirmation prompt" \
    "  -h, --help               Show this help output" \
    "" \
    "Examples:" \
    "  export MYSQL_PWD='supersecret'" \
    "  $SCRIPT_NAME --container mariadb --archive /backups/mysql/app.sql.gz --database appdb" \
    "  $SCRIPT_NAME --archive /backups/mysql/all.sql.gz --database all --yes" \
    "  $SCRIPT_NAME --archive /backups/mysql/app.sql --database appdb --drop-recreate --dry-run" \
    "" \
    "Notes:" \
    "  - --drop-recreate is only supported for a single database restore, not for 'all'." \
    "  - The password is read from the host environment variable named by --password-env."
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

bool_is_true() {
  case "${1,,}" in
    true|1|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

shell_quote() {
  printf "%q" "$1"
}

mysql_ident() {
  printf '%s' "$1" | sed 's/`/``/g'
}

docker_mysql() {
  if [[ -n "${PASSWORD_VALUE:-}" ]]; then
    docker exec -i -e "MYSQL_PWD=$PASSWORD_VALUE" "$CONTAINER_NAME" \
      mysql -u "$MYSQL_USER" "$@"
  else
    docker exec -i "$CONTAINER_NAME" \
      mysql -u "$MYSQL_USER" "$@"
  fi
}

stream_archive() {
  if [[ "$ARCHIVE_PATH" == *.sql.gz ]]; then
    gzip -dc -- "$ARCHIVE_PATH"
  else
    cat -- "$ARCHIVE_PATH"
  fi
}

confirm_restore() {
  printf '%s\n' \
    "Restore plan" \
    "  Container:       $CONTAINER_NAME" \
    "  Archive:         $ARCHIVE_PATH" \
    "  User:            $MYSQL_USER" \
    "  Database:        $MYSQL_DATABASE" \
    "  Password env:    ${PASSWORD_ENV:-<disabled>}" \
    "  Drop/Recreate:   $DROP_RECREATE" \
    "  Dry Run:         $DRY_RUN"

  if bool_is_true "$AUTO_YES"; then
    log "Auto-approval enabled; skipping confirmation."
    return 0
  fi

  if [[ ! -t 0 ]]; then
    fail "Interactive confirmation is required unless --yes is set."
  fi

  printf 'Proceed with the restore? [y/N] '
  read -r reply
  case "${reply,,}" in
    y|yes) ;;
    *) fail "Restore aborted by user." ;;
  esac
}

preflight() {
  require_command docker
  require_command gzip

  [[ -n "$CONTAINER_NAME" ]] || fail "Container name must not be empty."
  [[ -n "$ARCHIVE_PATH" ]] || fail "Archive path must not be empty."
  [[ -n "$MYSQL_USER" ]] || fail "MySQL user must not be empty."
  [[ -n "$MYSQL_DATABASE" ]] || fail "MySQL database must not be empty."

  [[ -f "$ARCHIVE_PATH" ]] || fail "Archive not found: $ARCHIVE_PATH"
  [[ -r "$ARCHIVE_PATH" ]] || fail "Archive is not readable: $ARCHIVE_PATH"

  case "$ARCHIVE_PATH" in
    *.sql|*.sql.gz) ;;
    *) fail "Archive must end with .sql or .sql.gz: $ARCHIVE_PATH" ;;
  esac

  if [[ -n "$PASSWORD_ENV" ]] && [[ ! "$PASSWORD_ENV" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    fail "Invalid password env variable name: $PASSWORD_ENV"
  fi

  if [[ "$ARCHIVE_PATH" == *.sql.gz ]]; then
    gzip -t -- "$ARCHIVE_PATH" || fail "gzip validation failed for archive: $ARCHIVE_PATH"
  fi

  docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 || fail "Container does not exist: $CONTAINER_NAME"
  [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" == "true" ]] \
    || fail "Container is not running: $CONTAINER_NAME"

  docker exec "$CONTAINER_NAME" sh -c 'command -v mysql >/dev/null 2>&1' \
    || fail "mysql client is not available inside container: $CONTAINER_NAME"

  if [[ -n "$PASSWORD_ENV" ]]; then
    PASSWORD_VALUE="${!PASSWORD_ENV-}"
    if [[ -z "$PASSWORD_VALUE" ]]; then
      warn "Password env variable '$PASSWORD_ENV' is not set; proceeding without a password."
    fi
  else
    PASSWORD_VALUE=""
  fi

  if bool_is_true "$DROP_RECREATE" && [[ "${MYSQL_DATABASE,,}" == "all" ]]; then
    fail "--drop-recreate cannot be used when --database is 'all'."
  fi
}

run_drop_recreate() {
  local db_ident sql
  db_ident="$(mysql_ident "$MYSQL_DATABASE")"
  sql="DROP DATABASE IF EXISTS \`$db_ident\`; CREATE DATABASE \`$db_ident\`;"

  if bool_is_true "$DRY_RUN"; then
    log "Dry run: would drop and recreate database '$MYSQL_DATABASE'."
    return 0
  fi

  log "Dropping and recreating database '$MYSQL_DATABASE'."
  printf '%s\n' "$sql" | docker_mysql
}

run_restore() {
  if bool_is_true "$DRY_RUN"; then
    if [[ "$ARCHIVE_PATH" == *.sql.gz ]]; then
      log "Dry run: would stream gzip archive $(shell_quote "$ARCHIVE_PATH") into mysql database '${MYSQL_DATABASE}'."
    else
      log "Dry run: would stream SQL archive $(shell_quote "$ARCHIVE_PATH") into mysql database '${MYSQL_DATABASE}'."
    fi
    return 0
  fi

  if [[ "${MYSQL_DATABASE,,}" == "all" ]]; then
    log "Restoring archive into server scope."
    stream_archive | docker_mysql
  else
    log "Restoring archive into database '$MYSQL_DATABASE'."
    stream_archive | docker_mysql "$MYSQL_DATABASE"
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --container)
        [[ $# -ge 2 ]] || fail "Missing value for --container"
        CONTAINER_NAME="$2"
        shift 2
        ;;
      --archive)
        [[ $# -ge 2 ]] || fail "Missing value for --archive"
        ARCHIVE_PATH="$2"
        shift 2
        ;;
      --user)
        [[ $# -ge 2 ]] || fail "Missing value for --user"
        MYSQL_USER="$2"
        shift 2
        ;;
      --database)
        [[ $# -ge 2 ]] || fail "Missing value for --database"
        MYSQL_DATABASE="$2"
        shift 2
        ;;
      --password-env)
        [[ $# -ge 2 ]] || fail "Missing value for --password-env"
        PASSWORD_ENV="$2"
        shift 2
        ;;
      --drop-recreate)
        DROP_RECREATE="true"
        shift
        ;;
      --no-drop-recreate)
        DROP_RECREATE="false"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        shift
        ;;
      --yes)
        AUTO_YES="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
  done

  preflight
  confirm_restore

  if bool_is_true "$DROP_RECREATE"; then
    run_drop_recreate
  fi

  run_restore
  log "MySQL restore completed."
}

main "$@"
