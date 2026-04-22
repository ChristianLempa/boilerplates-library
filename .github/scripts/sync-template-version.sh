#!/usr/bin/env bash
# Sync dependency versions to metadata.template_version in template.json
# Triggered by GitHub Actions when Renovate updates dependencies

set -euo pipefail

extract_version() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    case "$filename" in
        *.yaml|*.yml)
            local image_version
            image_version=$(grep -E '^\s*image:\s*[^<][^\s]+:[^\s]+' "$file" | head -n1 | sed -E 's/.*:([^:[:space:]]+)$/\1/' | tr -d ' ' || true)
            if [[ -n "$image_version" ]]; then
                printf '%s\n' "$image_version"
                return 0
            fi

            local tag_version
            tag_version=$(python3 - "$file" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r"repository:\s*[\"']?([^:\s\"']+)[\"']?\s*\n\s*tag:\s*[\"']?([^\s\"']+)[\"']?", text, re.MULTILINE)
print(match.group(2) if match else "")
PY
)
            printf '%s\n' "$tag_version"
            ;;
        *)
            printf '\n'
            ;;
    esac
}

update_template() {
    local template_file="$1"
    local new_version="$2"

    python3 - "$template_file" "$new_version" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
new_version = sys.argv[2]
data = json.loads(path.read_text(encoding="utf-8"))
metadata = data.get("metadata")
if not isinstance(metadata, dict):
    raise SystemExit(1)
current_version = str(metadata.get("template_version", "")).strip()
if not current_version or current_version == new_version:
    raise SystemExit(2)
metadata["template_version"] = new_version
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(f"✓ Updating {path}: {current_version} → {new_version}")
PY
    local status=$?
    if [[ $status -eq 0 ]]; then
        return 0
    fi
    if [[ $status -eq 2 ]]; then
        return 1
    fi
    return $status
}

collect_files() {
    if [[ $# -gt 0 ]]; then
        printf '%s\n' "$@"
    else
        find compose swarm helm kubernetes -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null || true
    fi
}

updated=0
processed=0

while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    ((processed++)) || true

    template_file="$(dirname "$(dirname "$file")")/template.json"
    [[ ! -f "$template_file" ]] && continue

    version=$(extract_version "$file")
    [[ -z "$version" ]] && continue

    update_template "$template_file" "$version" && ((updated++)) || true
done < <(collect_files "$@")

echo "Processed $processed file(s), updated $updated template(s)"
exit 0
