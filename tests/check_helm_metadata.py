"""Check portable Helm manifests and Renovate's chart-header extraction."""

import json
from pathlib import Path
import re
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
config = json.loads((ROOT / "renovate.json").read_text())
manager = next(m for m in config["customManagers"] if m.get("datasourceTemplate") == "helm")
# Renovate/JavaScript and Python use different named-capture syntax.
pattern = re.compile(manager["matchStrings"][0].replace("(?<", "(?P<"))
fields = {"schema", "slug", "kind", "metadata", "variables"}
manifests = sorted((ROOT / "helm").glob("*/template.json"))
assert manifests, "No Helm templates found"
for path in manifests:
    manifest = json.loads(path.read_text())
    assert set(manifest) <= fields, f"{path}: unsupported manifest fields"
    assert manifest["schema"] == "boilerplates/template/v1", path
    values = path.parent / "files" / "values.yaml"
    assert re.search(manager["fileMatch"][0], values.relative_to(ROOT).as_posix()), values
    matches = list(pattern.finditer(values.read_text()))
    assert len(matches) == 1, f"{values}: expected one Renovate-readable chart header"
    chart = matches[0].groupdict()
    assert urlparse(chart["registryUrl"]).netloc, values
    assert chart["depName"] and chart["currentValue"], values
print(f"Checked {len(manifests)} Helm manifests and chart headers")
