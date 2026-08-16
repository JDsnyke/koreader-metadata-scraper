# ZenPM repository support

Metadata Scraper publishes a ZenPM v1 `manifest.json` at the repository root.

## Repository URL for users

In ZenPM, open **Sources → Add repository** and paste this base URL exactly:

`https://raw.githubusercontent.com/JDsnyke/koreader-metadata-scraper/main/`

This is the canonical ZenPM-compatible source URL for Metadata Scraper. ZenPM appends/requests `manifest.json` from the repository base, so the normal GitHub webpage URL (`https://github.com/JDsnyke/koreader-metadata-scraper`) should not be used as the package source.

After adding the source, refresh ZenPM. The listing should show:

- Repository: **JDsnyke KOReader Plugins**
- Application: **Metadata Scraper**
- Description: **Fetch and safely apply EPUB metadata and covers from Hardcover, Amazon Creators API, Google Books, and Open Library without rewriting EPUB files.**

The package maps to the installed KOReader module `metadata_scraper.koplugin` through the ZenPM `plugin_module` field.

## Release maintenance

For each published release, update the package `version`, `source_asset`, and `size` fields in `manifest.json` to match the GitHub release asset. Keep `size` encoded as a JSON string because ZenPM's manifest schema expects a string.

Run:

`python3 scripts/lint_zenpm_manifest.py`

before merging release metadata changes.
