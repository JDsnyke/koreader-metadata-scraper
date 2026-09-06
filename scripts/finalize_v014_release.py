#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Finalize release-facing documentation.
readme = ROOT / "README.md"
text = readme.read_text(encoding="utf-8")
text = text.replace("## v0.1.4 development additions", "## v0.1.4")
text = text.replace(
    "The current v0.1.4 development branch also includes foundations pulled forward from the later roadmap: explainable numeric match-score components, an interactive batch review/deselect step, bounded multi-revision Undo history, and exact saved Google Books record refresh for metadata or cover-only updates. These remain unreleased until v0.1.4 is finalized.",
    "v0.1.4 expands reliability and metadata lifecycle support with safer result previews, explainable match scoring, interactive batch review, bounded multi-revision Undo history, exact saved Google Books refresh, provider cooldown handling, persistent diagnostics, settings migrations/tools, and ZenPM repository support.",
)
readme.write_text(text, encoding="utf-8")

changelog = ROOT / "CHANGELOG.md"
text = changelog.read_text(encoding="utf-8")
text = text.replace("## [0.1.4] - Unreleased", "## [0.1.4] - 2026-09-06", 1)
changelog.write_text(text, encoding="utf-8")

# Runtime README changed, so refresh updater payload hashes before building.
subprocess.run(["python3", "scripts/generate_update_manifest.py"], cwd=ROOT, check=True)
subprocess.run(["python3", "scripts/build_release.py"], cwd=ROOT, check=True)
zip_path = ROOT / "dist" / "metadata_scraper_koreader_v0.1.4.zip"
blob = zip_path.read_bytes()
digest = hashlib.sha256(blob).hexdigest()
size = len(blob)
published_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

site_manifest_path = ROOT / "zenpm-repo" / "manifest.json"
manifest = json.loads(site_manifest_path.read_text(encoding="utf-8"))
package = manifest["packages"][0]
package["version"] = "0.1.4"
package["source_asset"] = "metadata_scraper_koreader_v0.1.4.zip"
package["published_at"] = published_at
package["size"] = str(size)
site_manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
(ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

versions_path = ROOT / "zenpm-repo" / "packages" / "metadata-scraper" / "versions.json"
versions = json.loads(versions_path.read_text(encoding="utf-8"))
entry = {
    "tag_name": "v0.1.4",
    "name": "Metadata Scraper for KOReader v0.1.4",
    "prerelease": False,
    "assets": [{
        "name": "metadata_scraper_koreader_v0.1.4.zip",
        "url": "https://github.com/JDsnyke/koreader-metadata-scraper/releases/download/v0.1.4/metadata_scraper_koreader_v0.1.4.zip",
        "size": size,
        "digest": "sha256:" + digest,
    }],
}
versions["releases"] = [entry] + [r for r in versions.get("releases", []) if r.get("tag_name") != "v0.1.4"]
versions_path.write_text(json.dumps(versions, indent=2) + "\n", encoding="utf-8")

# Make ZenPM site lint release-agnostic instead of pinning v0.1.3 forever.
lint_path = ROOT / "scripts" / "lint_zenpm_site.py"
text = lint_path.read_text(encoding="utf-8")
start = text.index("    # Public catalog follows published stable releases only.")
end = text.index("    readme_path = SITE / package.get(\"readme_url\", \"\")")
replacement = '''    version = str(package.get("version") or "")\n    expected_tag = "v" + version\n    expected_asset = "metadata_scraper_koreader_v" + version + ".zip"\n    if not version:\n        fail("package.version is required")\n        errors += 1\n    if package.get("source_asset") != expected_asset:\n        fail("stable source_asset does not match package.version")\n        errors += 1\n    try:\n        package_size = int(package.get("size"))\n    except (TypeError, ValueError):\n        package_size = -1\n        fail("package.size must be an integer string")\n        errors += 1\n\n    versions_path = SITE / package.get("versions_url", "")\n    versions = load(versions_path)\n    releases = versions.get("releases")\n    if not isinstance(releases, list) or not releases:\n        fail("versions.json must contain at least one release")\n        errors += 1\n    else:\n        release = releases[0]\n        assets = release.get("assets") or []\n        if release.get("tag_name") != expected_tag or release.get("prerelease") is not False:\n            fail("first versions.json entry must match the stable package version")\n            errors += 1\n        if len(assets) != 1:\n            fail("stable versions entry must contain exactly one release asset")\n            errors += 1\n        else:\n            asset = assets[0]\n            digest = str(asset.get("digest") or "")\n            if asset.get("name") != expected_asset:\n                fail("versions asset name mismatch")\n                errors += 1\n            if asset.get("size") != package_size:\n                fail("versions asset size mismatch")\n                errors += 1\n            if not (digest.startswith("sha256:") and len(digest) == 71):\n                fail("versions asset digest must be sha256:<64 hex>")\n                errors += 1\n\n'''
text = text[:start] + replacement + text[end:]
text = text.replace('print("ZenPM Pages lint OK: static repository mirrors published stable v0.1.3.")', 'print("ZenPM Pages lint OK: static repository mirrors the configured stable release.")')
lint_path.write_text(text, encoding="utf-8")

# Convert the development-only ZenPM assertion into a release-aware one.
test_path = ROOT / "tests" / "v014_roadmap.lua"
text = test_path.read_text(encoding="utf-8")
old = '''    truthy(site_manifest:find('\"version\": \"0.1.3\"', 1, true), \"Pages manifest must not advertise unreleased v0.1.4\")\n    truthy(site_manifest:find('\"versions_url\": \"packages/metadata-scraper/versions.json\"', 1, true))\n    truthy(versions:find(\"metadata_scraper_koreader_v0.1.3.zip\", 1, true))\n    truthy(versions:find(\"sha256:ccb18681158f80dd41af824b954b2fd2333995502b206295f3b60c00c9723a3a\", 1, true))\n'''
new = '''    truthy(site_manifest:find('\"version\": \"0.1.4\"', 1, true), \"Pages manifest must advertise stable v0.1.4 after release finalization\")\n    truthy(site_manifest:find('\"versions_url\": \"packages/metadata-scraper/versions.json\"', 1, true))\n    truthy(versions:find(\"metadata_scraper_koreader_v0.1.4.zip\", 1, true))\n    truthy(versions:find(\"sha256:\", 1, true), \"stable release digest missing\")\n'''
if old not in text:
    raise SystemExit("development ZenPM test block not found")
test_path.write_text(text.replace(old, new, 1), encoding="utf-8")

print(f"FINAL_ZIP_SHA256={digest}")
print(f"FINAL_ZIP_SIZE={size}")
print(f"PUBLISHED_AT={published_at}")
