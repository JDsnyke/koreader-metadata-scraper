# Metadata Scraper for KOReader

A Kindle-friendly KOReader plugin for fetching EPUB metadata and covers from:

- Hardcover
- Amazon (Creators API)
- Google Books
- Open Library

## Target

KOReader **2026.07 (Sailing Walrus)** and newer. The plugin uses KOReader's native custom metadata and custom cover sidecars; it does **not** rewrite EPUB files.

## Installation on Kindle

1. Unzip `metadata_scraper.koplugin`.
2. Copy the whole folder to:
   `/mnt/base-us/koreader/plugins/metadata_scraper.koplugin/`
3. Restart KOReader.
4. If necessary, enable **Metadata Scraper** under plugin management.

With current Zen UI installed, long-press an EPUB and choose **Fetch metadata**. Long-press a folder to run a bounded folder batch. Stock KOReader users can use **Tools → Metadata Scraper → Choose EPUB…**.

## Provider setup

Open Library is enabled by default. Google Books is enabled automatically when you save an API key.

### Google Books

Google Books now requires a project API key in this plugin. This avoids relying on anonymous/shared quota, which can surface as HTTP 429. When Google returns a quota/rate-limit response, the plugin respects `Retry-After` when present and applies a bounded exponential cooldown instead of repeatedly hammering the API. Other enabled providers continue to work.

### Hardcover

Open **Metadata Scraper → Provider accounts → Hardcover API token…** and enter the token from your Hardcover account settings. The token is stored locally in KOReader's settings file.

### Amazon

Amazon support uses the official **Creators API** and therefore requires valid Creators API credentials and a Partner Tag. Configure:

- Credential ID
- Credential secret
- Partner Tag
- Marketplace (Australia is the default)
- Search index (Books or Kindle Store)

The plugin obtains and caches an OAuth access token and calls `SearchItems`; it does not scrape Amazon product HTML.

## UI / Zen UI

The plugin intentionally uses KOReader's stock `ButtonDialog`, `MultiInputDialog`, `PathChooser`, `ConfirmBox`, and TouchMenu components. Current Zen UI themes/patches those same components, so dialogs inherit the Zen look rather than carrying an independent visual skin.

Selection controls (search source, Amazon marketplace, Amazon search index) use compact one-choice dialogs with a checkmark on the current selection—an e-ink friendly dropdown/select pattern.

## Metadata written

KOReader 2026.07 custom metadata currently supports:

- Title
- Authors
- Series
- Series index
- Language
- Keywords / genres
- Description
- Custom cover

Publisher, publication date, ISBN and provider IDs are shown during matching but are not forced into unsupported KOReader metadata fields. The selected provider ID/ISBN is retained in the plugin's own local settings for future use.

## Batch mode

Batch mode is intentionally conservative:

- Current folder only (non-recursive)
- Maximum 20 EPUBs per run by default
- Automatic application only at 90% match confidence or higher

These defaults reduce accidental edition mismatches and excessive API traffic.

## Notes

- Credentials are stored locally in KOReader's Lua settings; they are not encrypted by this plugin.
- Hardcover's API is beta and may change.
- Amazon Creators API access depends on your Amazon Associates/Creators API eligibility.
- Covers are downloaded to a temporary cache file and then copied using KOReader's native custom-cover mechanism.


## Plugin updates

Metadata Scraper can update itself from this repository's **latest GitHub release**.

- **Metadata Scraper → Check for updates…** performs a manual check.
- **Automatic update checks** are enabled by default, at most once every 24 hours, and never turn Wi-Fi on by themselves.
- Updates are staged completely before installation. The updater reads `update.json` from the release tag, downloads every listed file over HTTPS, backs up the installed files, and rolls back if replacement fails.
- Restart KOReader after an update so the new Lua modules are loaded.

Release maintainers must include an `update.json` manifest whose `version` matches the release tag.
