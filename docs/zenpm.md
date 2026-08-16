# ZenPM repository support

Metadata Scraper publishes a ZenPM v1 repository manifest at the repository root.

## Add the repository

In ZenPM, open **Sources → Add repository** and use:

`https://raw.githubusercontent.com/JDsnyke/koreader-metadata-scraper/main/`

ZenPM appends `manifest.json` to the repository base URL and reads the package metadata from that file.

The listing should show:

- Repository: **JDsnyke KOReader Plugins**
- Application: **Metadata Scraper**
- Description: **Fetch and safely apply EPUB metadata and covers from Hardcover, Amazon Creators API, Google Books, and Open Library without rewriting EPUB files.**

The package maps to the installed KOReader module `metadata_scraper.koplugin` through the ZenPM `plugin_module` field.

## Release maintenance

For each release, update the package `version`, `source_asset`, and `size` fields in `manifest.json` to match the published GitHub release asset. Keep `size` encoded as a JSON string because ZenPM's manifest schema expects a string.

Run:

`python3 scripts/lint_zenpm_manifest.py`

before merging release metadata changes.
