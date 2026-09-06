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

    # Public catalog follows published stable releases only. The v0.1.4 branch
    # must not publish its unreleased development ZIP through ZenPM.
    if package.get("version") != "0.1.3":
        fail("development Pages catalog must remain on published stable v0.1.3")
        errors += 1
    if package.get("source_asset") != "metadata_scraper_koreader_v0.1.3.zip":
        fail("stable source_asset does not match the published v0.1.3 asset")
        errors += 1
    if package.get("size") != "44803":
        fail("stable asset size must match GitHub release metadata (44803 bytes)")
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
        if release.get("tag_name") != "v0.1.3" or release.get("prerelease") is not False:
            fail("first versions.json entry must be stable v0.1.3")
            errors += 1
        if len(assets) != 1:
            fail("v0.1.3 versions entry must contain exactly one release asset")
            errors += 1
        else:
            asset = assets[0]
            if asset.get("name") != "metadata_scraper_koreader_v0.1.3.zip":
                fail("versions asset name mismatch")
                errors += 1
            if asset.get("size") != 44803:
                fail("versions asset size mismatch")
                errors += 1
            if asset.get("digest") != "sha256:ccb18681158f80dd41af824b954b2fd2333995502b206295f3b60c00c9723a3a":
                fail("versions asset digest mismatch")
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
    print("ZenPM Pages lint OK: static repository mirrors published stable v0.1.3.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
