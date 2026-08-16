#!/usr/bin/env python3
"""Generate or verify update.json SHA-256 entries for release payloads.

The updater intentionally does not require update.json to hash itself. All other
paths listed in `files` must have a SHA-256 entry before a release is tagged.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "update.json"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_manifest() -> dict:
    with MANIFEST.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    files = data.get("files")
    if not isinstance(files, list) or not files:
        raise ValueError("update.json must contain a non-empty files array")
    return data


def computed_hashes(data: dict) -> dict[str, str]:
    out: dict[str, str] = {}
    for rel in data["files"]:
        if rel == "update.json":
            continue
        if not isinstance(rel, str) or not rel or rel.startswith("/") or ".." in Path(rel).parts:
            raise ValueError(f"unsafe manifest path: {rel!r}")
        path = ROOT / rel
        if not path.is_file():
            raise FileNotFoundError(f"manifest runtime file does not exist: {rel}")
        out[rel] = digest(path)
    return out


def check(data: dict, expected: dict[str, str]) -> int:
    stored = data.get("sha256")
    if not isinstance(stored, dict):
        print("update.json has no sha256 map", file=sys.stderr)
        return 1

    failed = False
    expected_paths = set(expected)
    stored_paths = set(stored)

    for rel in sorted(expected_paths):
        actual = expected[rel]
        recorded = stored.get(rel)
        if recorded != actual:
            print(f"HASH MISMATCH  {rel}", file=sys.stderr)
            print(f"  expected current file: {actual}", file=sys.stderr)
            print(f"  manifest:              {recorded}", file=sys.stderr)
            failed = True
        else:
            print(f"OK             {rel}  {actual}")

    extra = sorted(stored_paths - expected_paths)
    for rel in extra:
        print(f"UNEXPECTED HASH {rel}", file=sys.stderr)
        failed = True

    if failed:
        return 1
    print(f"Verified {len(expected)} release payload hashes.")
    return 0


def write(data: dict, hashes: dict[str, str]) -> None:
    data["sha256"] = dict(sorted(hashes.items()))
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    MANIFEST.write_text(text, encoding="utf-8")
    print(f"Wrote {len(hashes)} SHA-256 entries to {MANIFEST.relative_to(ROOT)}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify existing sha256 entries instead of rewriting update.json",
    )
    args = parser.parse_args()

    try:
        data = load_manifest()
        hashes = computed_hashes(data)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"manifest error: {exc}", file=sys.stderr)
        return 2

    if args.check:
        return check(data, hashes)

    write(data, hashes)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
