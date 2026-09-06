#!/usr/bin/env python3
"""Validate the static ZenPM repository tree deployed by GitHub Pages."""

from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "zenpm-repo"
PAGES_URL = "https://jdsnyke.github.io/koreader-metadata-scraper/"


def fail(message: str) -> None:
    print(f"ZENPM SITE LINT ERROR: {message}", file=sys.stderr)


def load(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot parse {path.relative_to(ROOT)}: {exc}")
        raise SystemExit(1)


def main() -> int:
    errors = 0
    manifest = load(SITE / "manifest.json")
    root_manifest = load(ROOT / "manifest.json")

    if manifest.get("schema_version") != "1":
        fail("schema_version must be string '1'")
        errors += 1
    repo = manifest.get("repo") or {}
    if repo.get("name") != "JDsnyke KOReader Plugins":
        fail("unexpected repo.name")
        errors += 1
    if repo.get("url") != PAGES_URL:
        fail(f"repo.url must be {PAGES_URL}")
        errors += 1

    packages = manifest.get("packages")
    if not isinstance(packages, list) or len(packages) != 1:
        fail("Pages manifest must contain exactly one package")
        return 1
    package = packages[0]
    required = {
        "id", "name", "version", "description", "author", "platforms",
        "dependencies", "source", "source_type", "source_asset",
        "plugin_module", "readme_url", "versions_url", "size",
    }
    missing = sorted(required - package.keys())
    if missing:
        fail("package missing fields: " + ", ".join(missing))
        errors += 1
    if package.get("id") != "metadata-scraper":
        fail("unexpected package id")
        errors += 1
    if package.get("platforms") != ["koreader"]:
        fail("Metadata Scraper must advertise the KOReader platform")
        errors += 1
    if package.get("plugin_module") != "metadata_scraper":
        fail("plugin_module must match metadata_scraper.koplugin")
        errors += 1

    version = str(package.get("version") or "")
    expected_tag = "v" + version
    expected_asset = "metadata_scraper_koreader_v" + version + ".zip"
    if not version:
        fail("package.version is required")
        errors += 1
    if package.get("source_asset") != expected_asset:
        fail("stable source_asset does not match package.version")
        errors += 1
    try:
        package_size = int(package.get("size"))
    except (TypeError, ValueError):
        package_size = -1
        fail("package.size must be an integer string")
        errors += 1

    versions_path = SITE / package.get("versions_url", "")
    versions = load(versions_path)
    releases = versions.get("releases")
    if not isinstance(releases, list) or not releases:
        fail("versions.json must contain at least one release")
        errors += 1
    else:
        release = releases[0]
        assets = release.get("assets") or []
        if release.get("tag_name") != expected_tag or release.get("prerelease") is not False:
            fail("first versions.json entry must match the stable package version")
            errors += 1
        if len(assets) != 1:
            fail("stable versions entry must contain exactly one release asset")
            errors += 1
        else:
            asset = assets[0]
            digest = str(asset.get("digest") or "")
            if asset.get("name") != expected_asset:
                fail("versions asset name mismatch")
                errors += 1
            if asset.get("size") != package_size:
                fail("versions asset size mismatch")
                errors += 1
            if not (digest.startswith("sha256:") and len(digest) == 71):
                fail("versions asset digest must be sha256:<64 hex>")
                errors += 1

    readme_path = SITE / package.get("readme_url", "")
    if not readme_path.is_file():
        fail(f"package readme_url does not resolve: {readme_path.relative_to(ROOT)}")
        errors += 1
    index = (SITE / "index.html")
    if not index.is_file() or PAGES_URL not in index.read_text(encoding="utf-8"):
        fail("index.html must show the paste-ready Pages repository URL")
        errors += 1

    # Keep the root manifest usable as a mirror/source artifact without letting
    # its package metadata drift from the deployed Pages catalog.
    if root_manifest != manifest:
        fail("root manifest.json must mirror zenpm-repo/manifest.json")
        errors += 1

    if errors:
        print(f"ZenPM Pages lint failed with {errors} error(s).", file=sys.stderr)
        return 1
    print("ZenPM Pages lint OK: static repository mirrors the configured stable release.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
