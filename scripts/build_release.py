#!/usr/bin/env python3
"""Build and validate a deterministic Metadata Scraper release ZIP."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "update.json"
TOP = "metadata_scraper.koplugin"
FIXED_ZIP_TIME = (2026, 1, 1, 0, 0, 0)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_manifest() -> dict:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    version = data.get("version")
    files = data.get("files")
    if not isinstance(version, str) or not version:
        raise ValueError("update.json must contain a version")
    if not isinstance(files, list) or not files:
        raise ValueError("update.json must contain a non-empty files array")
    return data


def validate_rel(rel: str) -> PurePosixPath:
    if not isinstance(rel, str) or not rel:
        raise ValueError(f"invalid manifest path: {rel!r}")
    path = PurePosixPath(rel)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"unsafe manifest path: {rel!r}")
    return path


def write_zip(zip_path: Path, files: list[str]) -> None:
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for rel in files:
            posix = validate_rel(rel)
            source = ROOT / Path(*posix.parts)
            if not source.is_file():
                raise FileNotFoundError(f"manifest file does not exist: {rel}")
            arcname = f"{TOP}/{posix.as_posix()}"
            info = zipfile.ZipInfo(arcname, FIXED_ZIP_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            zf.writestr(info, source.read_bytes())


def verify_zip(zip_path: Path, files: list[str]) -> None:
    expected = [f"{TOP}/{validate_rel(rel).as_posix()}" for rel in files]
    if len(expected) != len(set(expected)):
        raise ValueError("manifest contains duplicate archive paths")

    with zipfile.ZipFile(zip_path, "r") as zf:
        names = zf.namelist()
        if names != expected:
            missing = sorted(set(expected) - set(names))
            extra = sorted(set(names) - set(expected))
            raise ValueError(f"ZIP contents differ from manifest; missing={missing}, extra={extra}")
        for info in zf.infolist():
            path = PurePosixPath(info.filename)
            if not path.parts or path.parts[0] != TOP:
                raise ValueError(f"entry outside top-level plugin folder: {info.filename}")
            if ".." in path.parts:
                raise ValueError(f"unsafe ZIP entry: {info.filename}")
            if info.is_dir():
                raise ValueError(f"unexpected explicit directory entry: {info.filename}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dist", default="dist", help="output directory relative to repository root")
    args = parser.parse_args()

    try:
        data = load_manifest()
        files = data["files"]
        for rel in files:
            validate_rel(rel)

        dist = ROOT / args.dist
        if dist.exists():
            shutil.rmtree(dist)
        dist.mkdir(parents=True)

        zip_path = dist / f"metadata_scraper_koreader_v{data['version']}.zip"
        write_zip(zip_path, files)
        verify_zip(zip_path, files)
        digest = sha256(zip_path)
        checksum_path = zip_path.with_suffix(zip_path.suffix + ".sha256")
        checksum_path.write_text(f"{digest}  {zip_path.name}\n", encoding="utf-8")

        print(f"Built {zip_path.relative_to(ROOT)}")
        print(f"Entries: {len(files)}")
        print(f"SHA-256: {digest}")
        print(f"Checksum: {checksum_path.relative_to(ROOT)}")
        return 0
    except (OSError, ValueError, json.JSONDecodeError, zipfile.BadZipFile) as exc:
        print(f"build error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
