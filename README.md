# Metadata Scraper for KOReader

A Kindle-friendly KOReader plugin for finding EPUB metadata and covers from **Hardcover**, **Amazon Creators API**, **Google Books**, and **Open Library**, then saving selected values as KOReader-native custom metadata.

**EPUB files are never rewritten by the normal plugin workflow.** Metadata, provenance, undo state, and custom covers are handled through KOReader settings/sidecars and the plugin cache.

> The built-in updater follows the repository's latest **published GitHub Release**, not arbitrary commits on `main`.

## Highlights in v0.1.3

v0.1.3 is a major reliability and metadata-lifecycle release. It adds:

- automatic ISBN detection from EPUB/KOReader identifiers;
- ISBN-10/ISBN-13 checksum validation and canonical matching;
- cross-provider duplicate collapsing;
- conflict-aware scoring with **Exact / Strong / Possible / Weak** confidence classes;
- explicit ebook-vs-print/audiobook safeguards when a provider supplies format evidence;
- comparison-only author normalization for forms such as `Dinniman, Matt` vs `Matt Dinniman`;
- **Current → Proposed** field comparison before writing;
- **Choose fields for this book…** without changing global defaults;
- exact one-step metadata/cover **Undo**;
- richer per-book provenance and **Last match details**;
- provider connection tests plus lightweight readiness/cooldown status;
- sanitized support diagnostics with credential redaction;
- safer cover validation and rollback;
- cautious transient HTTP retries;
- a two-phase **batch discovery → confirmation → apply** workflow;
- batch threshold presets and skip-already-matched behavior;
- SHA-256 verification for updater payloads;
- automated Lua 5.1 regression checks.

## Compatibility

### KOReader

The plugin targets **KOReader 2026.07 (Sailing Walrus)** and newer and currently operates on **EPUB** files.

For modern Kindle firmware **5.16.3+**, use KOReader's `kindlehf` package.

A confirmed working Hardcover-search setup is:

- Kindle Coloursoft
- Kindle firmware 5.19.5
- Vera jailbreak
- KOReader `kindlehf`
- KOReader 2026.07

The plugin itself does not depend on a particular jailbreak once KOReader is already running.

### USB transfers on Kindle

Exit KOReader before using normal USB mass storage. When KOReader is running, a USB cable may only charge the device depending on the Kindle environment.

## Installation

### Fresh installation

1. Download the release ZIP.
2. Extract it on your computer.
3. Exit KOReader completely.
4. Connect the Kindle/device.
5. Copy the complete `metadata_scraper.koplugin` folder to:

   `koreader/plugins/metadata_scraper.koplugin/`

6. Confirm the folder is **not nested twice**. This is wrong:

   `koreader/plugins/metadata_scraper.koplugin/metadata_scraper.koplugin/main.lua`

7. Safely eject the device and restart KOReader.

Expected runtime layout:

```text
metadata_scraper.koplugin/
├── _meta.lua
├── main.lua
├── README.md
├── update.json
├── lib/
│   ├── diagnostics.lua
│   ├── http.lua
│   ├── matcher.lua
│   ├── updater.lua
│   ├── util.lua
│   ├── version.lua
│   └── writer.lua
└── providers/
    ├── amazon.lua
    ├── googlebooks.lua
    ├── hardcover.lua
    └── openlibrary.lua
```

Internal storage may appear as `/mnt/us`, `/mnt/base-us`, or another path. The updater discovers the running plugin path dynamically and does not require a hard-coded Kindle mount point.

## Updating manually

For a normal upgrade, **copy over and merge/replace** the existing plugin folder rather than deleting the settings file.

1. Exit KOReader.
2. Optional but recommended: back up `koreader/settings/metadata_scraper.lua`.
3. Copy the new `metadata_scraper.koplugin` over the existing plugin folder.
4. Merge/replace changed runtime files.
5. Restart KOReader fully.

Credentials and preferences are stored separately in:

`koreader/settings/metadata_scraper.lua`

Do not delete that file unless you intentionally want to reset the plugin configuration.

A clean plugin-folder replacement can be useful after a corrupt/incomplete install, but preserve the settings file.

## Opening Metadata Scraper

### Stock KOReader

Open **Tools → Metadata Scraper**.

### Zen UI

Long-press/select an EPUB or folder and choose **Metadata** from the context actions where supported.

For one EPUB, the common workflow is:

1. **Fetch metadata**.
2. Review/edit Title, Author, and ISBN search fields.
3. Search one provider or all enabled providers.
4. Select a candidate.
5. Review score, confidence, reasons, edition information, and Current → Proposed changes.
6. Use normal **Apply**, or **Choose fields for this book…** for a one-off field selection.
7. Use **Undo last metadata update** if the result is not what you wanted.

## Provider configuration

Open **Metadata Scraper → Provider accounts**.

Available configuration includes:

- **Test provider connections…**
- **Save support diagnostics…**
- **Hardcover API token…**
- **Amazon Creators API…**
- **Amazon marketplace**
- **Amazon search index**
- **Google Books API key…**

### Provider defaults

- **Open Library** — enabled by default; no credentials required.
- **Google Books** — requires your own Google Books API key for normal plugin use.
- **Hardcover** — requires a Hardcover API token.
- **Amazon** — requires Creators API Credential ID, Credential secret, Partner Tag, and preferably the credential version.

## Editing credentials from a computer

Long credentials can be easier to paste into:

`koreader/settings/metadata_scraper.lua`

Exit KOReader first, back up the file, then edit the existing generated configuration rather than replacing the whole settings structure.

Relevant setting keys include:

```text
hardcover_token
google_api_key
amazon_client_id
amazon_client_secret
amazon_credential_version
amazon_partner_tag
amazon_marketplace
amazon_search_index
enabled
source_scope
batch_threshold
batch_skip_matched
auto_update_check
```

Keep valid Lua quoting/commas and restart KOReader after editing.

## Open Library

Open Library requires no API credentials and is useful for verifying basic network/search/write behavior before configuring authenticated providers.

Official API documentation: https://openlibrary.org/developers/api

## Hardcover

Hardcover requires an API token.

Official API documentation: https://docs.hardcover.app/

Configure it under **Hardcover API token…**.

### Authorization

The API request must use:

`Authorization: Bearer YOUR_TOKEN`

The plugin accepts either a raw token or an already-prefixed `Bearer ...` value and normalizes it so `Bearer Bearer ...` is not sent.

### Search-response compatibility

Hardcover search has returned Typesense-backed structures in multiple shapes. v0.1.3 handles:

- flat result arrays;
- `hits[].document` responses;
- arrays of hit objects;
- JSON-encoded versions of those structures.

This fixes the case where authentication worked but searches such as **Dungeon Crawler Carl** incorrectly appeared as **No matches found**.

When Hardcover search documents include usable format/edition hints, v0.1.3 can use those as matching evidence. Their absence is treated as unknown/neutral rather than as an error.

## Google Books

The plugin uses the public Google Books Volumes API with a user-supplied API key.

Official documentation: https://developers.google.com/books/docs/v1/using

Typical setup:

1. Create/select a Google Cloud project.
2. Enable the Books API.
3. Create an API key.
4. Restrict it to the Books API where practical.
5. Save it under **Google Books API key…**.

### Rate limits

v0.1.3:

- recognizes HTTP 429 and quota-related 403 responses;
- honors numeric `Retry-After` where supplied;
- otherwise applies bounded cooldown/backoff;
- exposes active cooldown in provider readiness status;
- lets other enabled providers continue while Google is cooling down.

The generic HTTP layer does **not** blindly override Google's provider-specific 429 handling.

## Amazon Creators API

Amazon support uses the official **Creators API** and does **not** scrape Amazon HTML pages.

Official documentation:

- Getting started: https://affiliate-program.amazon.com/creatorsapi/docs/en-us/get-started/using-curl
- SearchItems: https://affiliate-program.amazon.com/creatorsapi/docs/en-us/api-reference/operations/search-items

Configure:

- Credential ID
- Credential secret
- Credential version (`3.1`, `3.2`, or `3.3`)
- Partner Tag
- Marketplace
- Search index (`Books` or `KindleStore`)

### Credential version vs marketplace

These are separate concepts:

- **Credential version** chooses the OAuth token endpoint associated with that credential.
- **Marketplace** chooses the Amazon catalog being searched.

v0.1.3 token endpoints are:

```text
3.1 → https://api.amazon.com/auth/o2/token
3.2 → https://api.amazon.co.uk/auth/o2/token
3.3 → https://api.amazon.co.jp/auth/o2/token
```

For compatibility with older settings, the plugin can still infer a credential version when the field is blank. For a new/current configuration, save the actual version shown for the Creators API credential.

The OAuth access token is cached by credential identity/endpoint until near expiry. Changing only marketplace can reuse the valid token. A cached token rejected with HTTP 401 is cleared and refreshed once.

### Edition evidence

The SearchItems request includes ItemInfo classification/content resources. When Amazon returns values such as Binding or Edition, v0.1.3 records them and can classify clearly identified results such as Kindle/ebook, Paperback/Hardcover/print, or audiobook.

This is **not audiobook support**. It is a safety feature that prevents a known audiobook/print result from being automatically applied to an EPUB.

## Search and matching

### Automatic ISBN detection

Where KOReader exposes EPUB identifiers, the plugin looks for valid ISBN-10/ISBN-13 values and pre-fills the ISBN search field.

ISBN candidates are checksum-validated. ISBN-10 is converted to its canonical ISBN-13 equivalent for comparison/deduplication.

### Ranking evidence

The matcher can use:

- exact ISBN;
- title similarity;
- author similarity;
- language;
- series;
- publication year;
- known media/edition format.

A candidate can also receive explicit conflict reasons.

### Confidence classes

Results show both the numeric score and a class:

- **Exact** — decisive evidence such as exact ISBN with no explicit hard edition conflict.
- **Strong** — high-confidence text/metadata evidence with no hard conflict.
- **Possible** — useful but requires more judgment.
- **Weak** — insufficient or contradictory evidence.

### Edition safeguards

Every EPUB query is identified internally as an `ebook` search target.

If a provider explicitly identifies a candidate as:

- **audiobook** — it is capped at 35% for an EPUB;
- **print** (for example Paperback/Hardcover) — it is capped at 65% for an EPUB.

These candidates remain visible for manual inspection but cannot cross the 80/90/95 automatic batch thresholds.

If provider format is unknown, it is neutral. The plugin does not invent a format conflict from missing data.

### Author normalization

Author normalization is for **comparison only**. It does not rewrite provider/displayed author names.

Equivalent punctuation/order token forms such as:

`Matt Dinniman`

and

`Dinniman, Matt`

can compare consistently while genuinely different author tokens still reduce confidence.

### Cross-provider deduplication

Results are collapsed primarily by canonical ISBN and secondarily by normalized title + author. A preferred result can be supplemented with missing fields from a duplicate source, and the UI indicates when the book was also found elsewhere.

## Match preview and Apply

The preview can show:

- author;
- series/index;
- publication date;
- language;
- ISBN-10/ISBN-13;
- provider/source;
- format/edition when available;
- score and confidence;
- match/conflict reasons;
- cover availability;
- **Current → Proposed** text-field changes.

Long descriptions are summarized as add/replace operations rather than filling the e-ink screen with the whole description.

### Global metadata fields

Global toggles exist for:

- Title
- Authors
- Series
- Series index
- Language
- Keywords / genres
- Description
- Cover

### One-off per-book field selection

Choose **Choose fields for this book…** from the preview to temporarily select fields for that single Apply operation.

Those temporary choices do **not** change the global defaults.

## Write modes

### Replace existing metadata

Selected fields can replace existing KOReader custom metadata.

### Fill missing only

Existing populated custom values remain untouched and only missing selected fields are filled.

The plugin does not rewrite the EPUB container in either mode.

## Undo and provenance

Before a successful metadata/cover mutation, the plugin snapshots the exact existing KOReader custom metadata file and custom-cover bytes.

If the snapshot cannot be created safely, the mutation is refused.

### Undo

**Undo last metadata update** restores the state immediately before the most recent Metadata Scraper apply for that book.

- one undo point is retained per book;
- records are bounded to the 20 most recently updated books;
- undo survives a KOReader restart because the record is persisted in plugin settings;
- if no custom override existed before, Undo removes the newly-created override rather than creating a synthetic empty one.

### Last match details

Per-book provenance can include:

- provider/source and provider ID;
- ISBN/canonical identifier;
- title/authors/series;
- language/date/publisher;
- known format/binding/edition;
- score/confidence/reasons;
- original search query;
- fields written;
- cover outcome/source;
- plugin version and timestamp.

This groundwork is intended to support exact-record refresh in a future release.

## Batch mode

Batch mode is intentionally conservative:

- current folder only;
- non-recursive;
- maximum 20 EPUBs per run by default;
- default threshold **Recommended 90%**;
- optional **Strict 95%** and **Permissive 80%** presets;
- **Skip already matched in batch** enabled by default.

### Two-phase safety workflow

v0.1.3 does **not** immediately write while it is discovering matches.

1. Choose **Batch folder…**.
2. Confirm **Discover**.
3. The plugin searches/ranks up to the configured limit but performs **no metadata or cover writes**.
4. It summarizes:
   - Ready to apply
   - Low/no match
   - Already matched
   - Search failures
5. If there are ready matches, a second explicit **Apply** confirmation is shown.
6. Cancelling the second confirmation leaves every book unchanged.
7. Only after the second confirmation are the ready matches applied.

A later release may add row-by-row borderline review and richer batch reports. v0.1.3 deliberately keeps that additional complexity out of the release.

## Covers

Downloaded cover payloads are checked before an existing custom cover is touched.

The plugin currently accepts plausible **JPEG, PNG, or WebP** signatures and rejects tiny/non-image/error payloads where detected.

If KOReader fails while replacing the custom cover, the previous custom cover is restored where possible.

## HTTP resilience

For idempotent GET/HEAD operations and downloads, the shared HTTP layer can retry once after:

- a transient network failure;
- HTTP 502;
- HTTP 503;
- HTTP 504.

It does not generically retry ordinary POST requests, authentication failures, or HTTP 429. Provider-specific handling remains authoritative.

## Provider diagnostics

### Test provider connections

**Provider accounts → Test provider connections…** checks each provider and reports a useful result without requiring a book search.

### Readiness/status UI

The Providers dialog can show lightweight non-network state such as:

- token/key/credentials missing;
- configured but not yet tested;
- Open Library ready;
- Amazon token cached;
- Google cooling down for approximately N seconds.

Opening the dialog does not intentionally perform a new network test.

## Sanitized support diagnostics

Choose **Save support diagnostics…** to write a support file under the Metadata Scraper cache directory.

The diagnostic path is intended to include useful plugin/provider state and recent sanitized errors while redacting:

- Hardcover token;
- Google API key;
- Amazon Credential ID;
- Amazon Credential secret;
- Amazon Partner Tag;
- Bearer authorization values;
- secret query parameters.

URLs logged by the HTTP layer omit query values.

Do not intentionally paste credentials into GitHub issues even though the support bundle is designed to redact them.

## Built-in updater

The updater checks:

`https://api.github.com/repos/JDsnyke/koreader-metadata-scraper/releases/latest`

It therefore follows the latest **published Release**.

The updater:

1. reads the target release/tag;
2. fetches the tagged `update.json`;
3. validates release/manifest version and safe paths;
4. downloads runtime files to staging;
5. verifies required SHA-256 payload hashes;
6. verifies the staged files again immediately before installation;
7. backs up current files;
8. installs the staged files;
9. rolls back if installation fails.

Restart KOReader after installing an update so new Lua modules are loaded.

Automatic checks run at most once every 24 hours and do not intentionally turn Wi-Fi on merely to check.

## Updater integrity manifest

v0.1.3 introduces a `sha256` map in `update.json` for release payload files. `update.json` itself is the control document and is not self-hashed.

A target release with a missing/malformed/mismatched required digest is rejected before installed plugin files are modified.

Maintainers generate the final map from a frozen release tree with:

```text
python3 scripts/generate_update_manifest.py
python3 scripts/generate_update_manifest.py --check
```

Do not hand-edit release hashes.

## Files and privacy

### Plugin runtime

`koreader/plugins/metadata_scraper.koplugin/`

### Settings

`koreader/settings/metadata_scraper.lua`

Credentials stored there are local configuration values and are **not encrypted by this plugin**.

### Plugin cache

Metadata Scraper uses KOReader's data/cache area for temporary covers, updater staging/backups, support diagnostics, and undo backups.

### Network requests

Search terms and provider requests necessarily leave the device when an online provider is used. Cover URLs are requested when a cover is applied.

The EPUB itself is not uploaded by this plugin.

## Troubleshooting

### Plugin does not appear

- Verify the folder is directly under `koreader/plugins/`.
- Verify it is not nested twice.
- Restart KOReader.
- Confirm your KOReader version is supported.

### Hardcover says malformed Authorization header

Use current plugin code. Store either a raw Hardcover token or a single `Bearer ...` prefix; the provider normalizes it.

### Hardcover authenticates but returns No matches

Use current plugin code with the Typesense response normalizer. This was a known issue fixed after authentication itself was already working.

### Google returns 429

- use your own Google Books API key;
- check Books API enablement/key restrictions/quota;
- allow the plugin cooldown to expire;
- use another enabled provider meanwhile.

### Amazon authentication fails

- verify Credential ID/secret;
- verify the **credential version** (`3.1/3.2/3.3`);
- verify Partner Tag and marketplace eligibility;
- do not assume changing marketplace changes the credential's OAuth version.

### Wrong edition is ranked highly

Inspect ISBN, confidence, Match reasons, Format, and Edition. Explicit print/audiobook conflicts are intentionally capped for EPUB searches, but providers that omit format cannot be treated as conflicting without evidence.

### Cover did not replace

The plugin may have rejected a bad/non-image payload or restored the old cover after a KOReader write failure. Generate sanitized support diagnostics if needed.

### Batch changed nothing

The first batch phase is discovery-only. After discovery, confirm the second **Apply** dialog. If Ready to apply is zero, inspect the selected threshold, match confidence, provider errors, and whether files were skipped as already matched.

## Development and tests

The repository includes Lua 5.1 checks and regression suites for:

- provider parsing/authentication/status;
- matching/ISBN/conflict/edition logic;
- author normalization;
- two-phase batch wiring;
- HTTP and cover hardening;
- diagnostics redaction;
- metadata lifecycle/undo;
- updater SHA-256 integrity.

`tests/edition_batch.lua` specifically guards the v0.1.3 media-kind and batch-discovery behavior.

## Release maintainer workflow

Before a stable release:

1. Freeze runtime behavior.
2. Confirm `_meta.lua`, `lib/version.lua`, updater metadata, and `update.json` all identify the same version.
3. Run Lua syntax checks and all regression suites.
4. Update README, CHANGELOG, ROADMAP, implementation checklist, and the release/device test checklist.
5. Generate `update.json` SHA-256 entries from the exact frozen runtime tree.
6. Run `python3 scripts/generate_update_manifest.py --check`.
7. Build the release ZIP with exactly one top-level `metadata_scraper.koplugin/` directory.
8. Verify ZIP contents and Lua syntax from the built artifact.
9. Record the release ZIP SHA-256.
10. Merge the approved release branch.
11. Tag the exact intended merged commit as `vX.Y.Z`.
12. Publish a GitHub Release and attach the matching ZIP.
13. Verify `/releases/latest` resolves to the new published release.
14. Test **Check for updates…** from an older compatible installation when practical.

## Roadmap

See:

- [`ROADMAP.md`](ROADMAP.md)
- [`docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md`](docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md)
- [`docs/v0.1.3-testing.md`](docs/v0.1.3-testing.md)

Major future areas include exact provider-record refresh, richer batch review, multi-source field merging, safe file renaming/library organization, and first-class audiobook metadata support.
