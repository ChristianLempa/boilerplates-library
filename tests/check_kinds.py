"""Check every portable manifest's multi-kind classification contract."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUPPORTED = {
    "generic", "configuration", "compose", "swarm", "kubernetes", "helm_chart",
    "helm_release", "terraform", "terraform_provider", "ansible", "kustomize",
    "packer", "cloud_init", "github_actions", "gitlab_ci",
}
manifests = sorted(ROOT.rglob("template.json"))
assert manifests, "No templates found"
for path in manifests:
    manifest = json.loads(path.read_text())
    assert "kind" not in manifest, f"{path}: use kinds instead of kind"
    kinds = manifest.get("kinds")
    assert isinstance(kinds, list) and kinds, f"{path}: kinds must be a nonempty array"
    assert all(isinstance(kind, str) and kind in SUPPORTED for kind in kinds), path
    assert len(kinds) == len(set(kinds)), f"{path}: duplicate kinds"
print(f"Checked kinds in {len(manifests)} manifests")
