#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

CONTAINER_NAME_DEFAULT="<< container_name >>"
ARCHIVE_PATH_DEFAULT="<< archive_path >>"
RESTORE_CONTAINER_PATH_DEFAULT="<< restore_container_path >>"
HELPER_IMAGE_DEFAULT="<< helper_image >>"
STOP_CONTAINER_DEFAULT="<< stop_container_during_restore >>"
START_CONTAINER_DEFAULT="<< start_container_after_restore >>"
WIPE_TARGET_DEFAULT="<< wipe_target_path >>"
DRY_RUN_DEFAULT="<< dry_run >>"
AUTO_YES_DEFAULT="<< auto_yes >>"

CONTAINER_NAME="$CONTAINER_NAME_DEFAULT"
ARCHIVE_PATH="$ARCHIVE_PATH_DEFAULT"
RESTORE_CONTAINER_PATH="$RESTORE_CONTAINER_PATH_DEFAULT"
HELPER_IMAGE="$HELPER_IMAGE_DEFAULT"
STOP_CONTAINER="$STOP_CONTAINER_DEFAULT"
START_CONTAINER="$START_CONTAINER_DEFAULT"
WIPE_TARGET="$WIPE_TARGET_DEFAULT"
DRY_RUN="$DRY_RUN_DEFAULT"
AUTO_YES="$AUTO_YES_DEFAULT"

STOPPED_BY_SCRIPT="false"

usage() {
  printf '%s\n' \
    "Usage:" \
    "  $SCRIPT_NAME [options]" \
    "" \
    "Restore a Docker container-path archive back through the target container mounts." \
    "" \
    "Options:" \
    "  --container NAME         Target container (default: $CONTAINER_NAME_DEFAULT)" \
    "  --archive PATH           Path to a .tar.gz or .tgz archive (default: $ARCHIVE_PATH_DEFAULT)" \
    "  --path PATH              Container path to restore into (default: $RESTORE_CONTAINER_PATH_DEFAULT)" \
    "  --helper-image IMAGE     Helper image used for extraction (default: $HELPER_IMAGE_DEFAULT)" \
    "  --stop-container         Stop the target container before restore" \
    "  --no-stop-container      Leave the target container running" \
    "  --start-container        Start the container again if this script stopped it" \
    "  --no-start-container     Leave the container stopped after restore" \
    "  --wipe-target            Delete existing files under the target path before extraction" \
    "  --no-wipe-target         Preserve existing files under the target path" \
    "  --dry-run                Print actions without changing the target" \
    "  --yes                    Skip the confirmation prompt" \
    "  -h, --help               Show this help output" \
    "" \
    "Examples:" \
    "  $SCRIPT_NAME --container app --archive /backups/backup_app_20260413.tar.gz --path /config" \
    "  $SCRIPT_NAME --container app --archive /backups/backup_app_20260413.tar.gz --path /config --wipe-target --yes" \
    "  $SCRIPT_NAME --archive /backups/backup_app_20260413.tgz --path /var/lib/app --dry-run" \
    "" \
    "Notes:" \
    "  - Archives created by the complementary backup template preserve the full container path." \
    "  - The target path should usually match the original backed-up path."
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

archive_list() {
  tar -tzf "$ARCHIVE_PATH"
}

confirm_restore() {
  printf '%s\n' \
    "Restore plan" \
    "  Container:         $CONTAINER_NAME" \
    "  Archive:           $ARCHIVE_PATH" \
    "  Target Path:       $RESTORE_CONTAINER_PATH" \
    "  Helper Image:      $HELPER_IMAGE" \
    "  Stop Container:    $STOP_CONTAINER" \
    "  Restart After:     $START_CONTAINER" \
    "  Wipe Target Path:  $WIPE_TARGET" \
    "  Dry Run:           $DRY_RUN"

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

cleanup() {
  if bool_is_true "$STOPPED_BY_SCRIPT" && bool_is_true "$START_CONTAINER"; then
    log "Starting container '$CONTAINER_NAME' after restore."
    docker start "$CONTAINER_NAME" >/dev/null
  fi
}

preflight() {
  local normalized_target

  require_command docker
  require_command tar

  [[ -n "$CONTAINER_NAME" ]] || fail "Container name must not be empty."
  [[ -n "$ARCHIVE_PATH" ]] || fail "Archive path must not be empty."
  [[ -n "$RESTORE_CONTAINER_PATH" ]] || fail "Container restore path must not be empty."
  [[ "$RESTORE_CONTAINER_PATH" == /* ]] || fail "Container restore path must be absolute: $RESTORE_CONTAINER_PATH"
  [[ -n "$HELPER_IMAGE" ]] || fail "Helper image must not be empty."

  [[ -f "$ARCHIVE_PATH" ]] || fail "Archive not found: $ARCHIVE_PATH"
  [[ -r "$ARCHIVE_PATH" ]] || fail "Archive is not readable: $ARCHIVE_PATH"

  case "$ARCHIVE_PATH" in
    *.tar.gz|*.tgz) ;;
    *) fail "Archive must end with .tar.gz or .tgz: $ARCHIVE_PATH" ;;
  esac

  tar -tzf "$ARCHIVE_PATH" >/dev/null || fail "tar validation failed for archive: $ARCHIVE_PATH"

  docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 || fail "Container does not exist: $CONTAINER_NAME"

  docker image inspect "$HELPER_IMAGE" >/dev/null 2>&1 || warn "Helper image '$HELPER_IMAGE' is not present locally; Docker may try to pull it."

  normalized_target="${RESTORE_CONTAINER_PATH#/}"
  normalized_target="${normalized_target%/}"

  if [[ -n "$normalized_target" ]]; then
    if ! archive_list | grep -Fqx "$normalized_target" && ! archive_list | grep -Fq "${normalized_target}/"; then
      fail "Archive entries do not appear to match target path '$RESTORE_CONTAINER_PATH'. Use the original backup path."
    fi
  fi
}

stop_container_if_needed() {
  local was_running

  was_running="$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")"
  if bool_is_true "$STOP_CONTAINER" && [[ "$was_running" == "true" ]]; then
    if bool_is_true "$DRY_RUN"; then
      log "Dry run: would stop container '$CONTAINER_NAME'."
      return 0
    fi

    log "Stopping container '$CONTAINER_NAME' before restore."
    docker stop "$CONTAINER_NAME" >/dev/null
    STOPPED_BY_SCRIPT="true"
  else
    STOPPED_BY_SCRIPT="false"
  fi
}

run_restore() {
  local archive_dir archive_name wipe_flag
  archive_dir="$(cd "$(dirname "$ARCHIVE_PATH")" && pwd)"
  archive_name="$(basename "$ARCHIVE_PATH")"
  wipe_flag="false"

  if bool_is_true "$WIPE_TARGET"; then
    wipe_flag="true"
  fi

  if bool_is_true "$DRY_RUN"; then
    log "Dry run: would run helper container $(shell_quote "$HELPER_IMAGE") with --volumes-from $(shell_quote "$CONTAINER_NAME")."
    log "Dry run: would extract $(shell_quote "$ARCHIVE_PATH") back into $(shell_quote "$RESTORE_CONTAINER_PATH") with wipe-target=$wipe_flag."
    return 0
  fi

  log "Restoring archive into '$RESTORE_CONTAINER_PATH' using helper image '$HELPER_IMAGE'."
  docker run --rm \
    --volumes-from "$CONTAINER_NAME" \
    -v "$archive_dir":/restore:ro \
    "$HELPER_IMAGE" \
    sh -ceu '
      archive="/restore/$1"
      target="$2"
      wipe="$3"

      test -f "$archive"
      mkdir -p "$target"

      if [ "$wipe" = "true" ]; then
        find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
      fi

      tar -xzf "$archive" -C /
    ' sh "$archive_name" "$RESTORE_CONTAINER_PATH" "$wipe_flag"
}

main() {
  trap cleanup EXIT

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
      --path)
        [[ $# -ge 2 ]] || fail "Missing value for --path"
        RESTORE_CONTAINER_PATH="$2"
        shift 2
        ;;
      --helper-image)
        [[ $# -ge 2 ]] || fail "Missing value for --helper-image"
        HELPER_IMAGE="$2"
        shift 2
        ;;
      --stop-container)
        STOP_CONTAINER="true"
        shift
        ;;
      --no-stop-container)
        STOP_CONTAINER="false"
        shift
        ;;
      --start-container)
        START_CONTAINER="true"
        shift
        ;;
      --no-start-container)
        START_CONTAINER="false"
        shift
        ;;
      --wipe-target)
        WIPE_TARGET="true"
        shift
        ;;
      --no-wipe-target)
        WIPE_TARGET="false"
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
  stop_container_if_needed
  run_restore
  log "Docker volume restore completed."
}

main "$@"
