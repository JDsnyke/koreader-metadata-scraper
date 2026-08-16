#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))

assert manifest.get("schema_version") == "1", "ZenPM schema_version must be string '1'"
repo = manifest.get("repo") or {}
for field in ("id", "name", "url"):
    assert isinstance(repo.get(field), str) and repo[field].strip(), f"ZenPM repo.{field} is required"

packages = manifest.get("packages")
assert isinstance(packages, list) and packages, "ZenPM packages must be a non-empty array"

for package in packages:
    for field in ("id", "name", "version", "description", "author", "source", "source_type", "source_asset", "plugin_module", "size"):
        assert isinstance(package.get(field), str) and package[field].strip(), f"ZenPM package {package.get('id', '<unknown>')}.{field} is required"
    assert package.get("category") in {"utility", "games", "productivity", "media", "theme", "patches", "fonts"}, "Invalid ZenPM category"
    assert isinstance(package.get("platforms"), list) and "koreader" in package["platforms"], "KOReader package must declare koreader platform"
    assert isinstance(package.get("dependencies"), list), "ZenPM dependencies must be an array"
    assert package["size"].isdigit(), "ZenPM size must be encoded as a JSON string containing digits"

print(f"ZenPM manifest OK: {repo['name']} / {len(packages)} package(s)")
