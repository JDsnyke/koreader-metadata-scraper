#!/usr/bin/env python3
"""Static release-tree checks that do not require KOReader runtime modules."""

from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "update.json"
VERSION_FILE = ROOT / "lib" / "version.lua"


def fail(message: str) -> None:
    print(f"LINT ERROR: {message}", file=sys.stderr)


def main() -> int:
    errors = 0

    try:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot parse update.json: {exc}")
        return 1

    version_text = VERSION_FILE.read_text(encoding="utf-8")
    match = re.search(r'VERSION\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"', version_text)
    if not match:
        fail("could not read VERSION from lib/version.lua")
        return 1
    version = match.group(1)

    if data.get("version") != version:
        fail(f"update.json version {data.get('version')!r} != lib/version.lua {version!r}")
        errors += 1

    files = data.get("files")
    if not isinstance(files, list) or not files:
        fail("update.json files must be a non-empty array")
        return 1

    seen: set[str] = set()
    for rel in files:
        if not isinstance(rel, str) or not rel:
            fail(f"invalid manifest path {rel!r}")
            errors += 1
            continue
        path = Path(rel)
        if path.is_absolute() or ".." in path.parts:
            fail(f"unsafe manifest path {rel!r}")
            errors += 1
        if rel in seen:
            fail(f"duplicate manifest path {rel!r}")
            errors += 1
        seen.add(rel)
        if not (ROOT / rel).is_file():
            fail(f"manifest file does not exist: {rel}")
            errors += 1

    required = {"README.md", "_meta.lua", "main.lua", "update.json"}
    required.update(
        str(path.relative_to(ROOT)).replace("\\", "/")
        for base in (ROOT / "lib", ROOT / "providers")
        for path in base.glob("*.lua")
    )
    missing = sorted(required - seen)
    extra_runtime = sorted(
        rel for rel in seen
        if rel.endswith(".lua") and not (rel == "main.lua" or rel == "_meta.lua" or rel.startswith("lib/") or rel.startswith("providers/"))
    )
    for rel in missing:
        fail(f"runtime file missing from update.json: {rel}")
        errors += 1
    for rel in extra_runtime:
        fail(f"unexpected runtime Lua path in update.json: {rel}")
        errors += 1

    if "update.json" not in seen:
        fail("update.json must list itself as the updater control document")
        errors += 1

    runtime_text = "\n".join(
        (ROOT / rel).read_text(encoding="utf-8", errors="replace")
        for rel in sorted(required)
        if rel.endswith(".lua") and (ROOT / rel).is_file()
    )
    for stale in ("Metadata Scraper 0.1.1", "Metadata Scraper 0.1.2", "KOReader-Metadata-Scraper/0.1.1", "KOReader-Metadata-Scraper/0.1.2"):
        if stale in runtime_text:
            fail(f"stale runtime release string found: {stale}")
            errors += 1

    if errors:
        print(f"Release lint failed with {errors} error(s).", file=sys.stderr)
        return 1

    print(f"Release lint OK for v{version}: {len(files)} manifest paths, {len(required)} required runtime paths.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
