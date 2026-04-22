#!/usr/bin/env bash
# Sync metadata.version.* from the configured metadata.version.source_dep_name

set -euo pipefail

extract_source_version() {
    local template_file="$1"
    local source_file="$2"

    python3 - "$template_file" "$source_file" <<'PY'
import json
import re
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
source_path = Path(sys.argv[2])

template = json.loads(template_path.read_text(encoding="utf-8"))
metadata = template.get("metadata")
if not isinstance(metadata, dict):
    raise SystemExit(0)

version = metadata.get("version")
if not isinstance(version, dict):
    raise SystemExit(0)

source_dep_name = str(version.get("source_dep_name", "")).strip()
if not source_dep_name or source_dep_name.startswith("manual/"):
    raise SystemExit(0)

text = source_path.read_text(encoding="utf-8")

image_pattern = re.compile(
    r"^\s*image:\s*(?P<dep>[^@\s:][^\s@]*?)(?::(?P<tag>[^\s@<]+))?(?:@(?P<digest>sha256:[0-9a-fA-F]+))?\s*$",
    re.MULTILINE,
)
for match in image_pattern.finditer(text):
    dep = match.group("dep")
    tag = match.group("tag") or ""
    digest = match.group("digest") or ""
    if dep == source_dep_name and tag:
        payload = {"version": tag}
        if digest:
            payload["digest"] = digest
        print(json.dumps(payload))
        raise SystemExit(0)

repo_tag_pattern = re.compile(
    r'repository:\s*["\']?(?P<dep>[^:"\'\s]+)["\']?\s*\n\s*tag:\s*["\']?(?P<tag>[^\s"\'<]+)["\']?',
    re.MULTILINE,
)
for match in repo_tag_pattern.finditer(text):
    dep = match.group("dep")
    tag = match.group("tag")
    if dep == source_dep_name:
        print(json.dumps({"version": tag}))
        raise SystemExit(0)
PY
}

update_template() {
    local template_file="$1"
    local new_version="$2"
    local new_digest="${3:-}"

    python3 - "$template_file" "$new_version" "$new_digest" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
new_version = sys.argv[2]
new_digest = sys.argv[3].strip()

data = json.loads(path.read_text(encoding="utf-8"))
metadata = data.get("metadata")
if not isinstance(metadata, dict):
    raise SystemExit(1)

version = metadata.get("version")
if not isinstance(version, dict):
    raise SystemExit(1)

current_name = str(version.get("name", "")).strip()
current_source_version = str(version.get("source_dep_version", "")).strip()
current_digest = str(version.get("source_dep_digest", "")).strip()

changed = False
if current_name != new_version:
    version["name"] = new_version
    changed = True

if current_source_version != new_version:
    version["source_dep_version"] = new_version
    changed = True

if new_digest:
    if current_digest != new_digest:
        version["source_dep_digest"] = new_digest
        changed = True
elif "source_dep_digest" in version:
    version.pop("source_dep_digest", None)
    changed = True

if not changed:
    raise SystemExit(2)

path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(f"✓ Updating {path}: {current_name or '<unset>'} → {new_version}")
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

    match_json="$(extract_source_version "$template_file" "$file")"
    [[ -z "$match_json" ]] && continue

    version="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["version"])' "$match_json")"
    digest="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("digest",""))' "$match_json")"

    update_template "$template_file" "$version" "$digest" && ((updated++)) || true
done < <(collect_files "$@")

echo "Processed $processed file(s), updated $updated template(s)"
exit 0
