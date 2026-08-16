# Changelog

All notable changes to Metadata Scraper for KOReader will be documented here.

## [0.1.3] - Unreleased

### Reliability

- Centralized the plugin version and HTTP User-Agent in `lib/version.lua` so provider, updater, metadata, and About-dialog versions cannot drift independently.
- Added provider connection diagnostics for Hardcover, Amazon Creators API, Google Books, and Open Library.
- Added lightweight provider readiness/status reporting in the Providers UI. Google Books exposes active cooldown time, Amazon indicates missing/configured/cached-token state, Hardcover indicates token configuration state, and Open Library reports its credential-free readiness.
- Preserved an existing KOReader custom cover if replacement of the cover fails.
- Added clearer per-provider errors/counts when a search returns no matches.
- Added one broader title-only fallback when a strict title + author search returns no results.
- **Expedited from the v0.1.4 hardening roadmap:** GET requests and downloads now retry once for network failures and HTTP 502/503/504 only. Generic retries deliberately do not retry HTTP 429, authentication failures, or ordinary POST requests.
- Added cover validation before replacement: downloaded covers must be large enough to be plausible images and have a recognized JPEG, PNG, or WebP signature. Known non-image content types are rejected.
- Failed download paths explicitly close temporary file handles before cleanup/retry.
- Metadata and custom-cover writes are isolated with protected calls so unexpected KOReader-side exceptions become controlled failures instead of propagating through the plugin.
- Malformed provider result records are discarded during ranking rather than preventing valid results from other providers from being shown.
- Added a sanitized diagnostics core with a bounded in-memory event buffer, URL query redaction, credential redaction, and support-bundle generation. Configured tokens, API keys, Amazon secrets, credential IDs, and partner tags are never intentionally emitted by the diagnostics bundle.
- HTTP failures/retries are recorded using sanitized URLs with query strings removed.
- Added **Save support diagnostics…** to the plugin UI. It writes a sanitized support file under KOReader's Metadata Scraper cache directory and reports the path to the user.
- Provider-test failures, provider-search failures, updater failures, KOReader metadata-read failures, metadata-write failures, and cover-write failures now feed the sanitized diagnostics buffer.
- Added SHA-256 verification to the updater using KOReader's bundled `ffi/sha2` implementation. Future release manifests must provide a valid SHA-256 for every staged runtime payload except the control `update.json` itself.
- Updater payloads are verified immediately after download and re-verified immediately before installation. A missing hash, malformed digest, download mismatch, or staged-file change aborts before installed files are modified.
- The updater stages the exact fetched `update.json` response body rather than downloading the control manifest a second time, avoiding a self-referential manifest hash requirement.

### Metadata lifecycle and undo

- **Expedited from the v0.2.0 lifecycle roadmap:** match preview now calculates the actual KOReader fields that will change under the current field selection and write mode.
- The preview shows a bounded **Current → Proposed** comparison for changed title, authors, series, series index, language, and keywords; descriptions are represented as add/replace actions rather than dumping long text into the dialog.
- Added **Choose fields for this book…**. A user can temporarily enable/disable title, authors, series, series index, language, genres/keywords, description, and cover for one Apply operation without changing the saved global defaults.
- The normal **Apply** button continues to use the user's global field defaults unchanged.
- An apply with no selected text changes and no cover change is treated as a no-op rather than creating an unnecessary custom-metadata sidecar.
- Before any metadata or cover mutation, the plugin creates an undo snapshot of the exact existing KOReader custom-metadata file and custom-cover bytes.
- If no custom metadata or cover existed before the apply, undo removes the newly created override instead of synthesizing an approximate prior state.
- Undo snapshot creation is fail-safe: if the prior state cannot be captured, the plugin refuses to apply the mutation.
- Added **Undo last metadata update** for the current book and in the book context metadata menu.
- Undo restores the previous custom metadata and cover, then restores the previous Metadata Scraper provenance record.
- Undo backup names are collision-checked and restore paths refuse to silently leave a competing current override behind.
- One undo snapshot is retained per book, with the global undo-record set bounded to the 20 most recent books so cache/settings growth remains controlled.
- Expanded per-book provenance to record provider/source ID, canonical ISBN, title/authors/series/language/date/publisher, score, confidence class, match reasons, search query, fields written, cover outcome, plugin version, and timestamp.
- Added **Last match details** for the current/context-selected book so the recorded source, provider ID, score, confidence, ISBN, written fields, reasons, date, and plugin version can be inspected without re-searching.
- Cover-only changes can also be undone; a failed cover-only operation does not replace a previously valid undo record.

### Batch workflow

- Added batch confidence presets: **Strict (95%)**, **Recommended (90%)**, and **Permissive (80%)**.
- The existing 90% behavior remains the default.
- Added **Skip already matched in batch**, enabled by default. Files with existing Metadata Scraper provenance are skipped before provider queries are made, reducing unnecessary API calls and accidental repeat writes.
- The batch confirmation dialog states when previously matched books will be skipped.
- Batch processing remains current-folder-only, non-recursive, and bounded by the existing batch file limit.

### Hardcover

- Retains the confirmed `Authorization: Bearer <token>` authentication fix.
- Retains compatibility with Hardcover's Typesense-backed search result shapes, including `hits[].document` and JSON-encoded results.
- Added an authenticated account diagnostic using the `me` GraphQL query.
- Added non-network readiness status based on whether a token is configured.

### Amazon Creators API

- Added an Amazon credential-version setting (`3.1`, `3.2`, or `3.3`) so the OAuth token endpoint follows the credential's region/version rather than assuming it from the marketplace being searched.
- Kept backward-compatible endpoint inference for existing installations where credential version has not yet been saved.
- Token caching is now keyed to the configured credentials and credential endpoint.
- Changing the marketplace no longer unnecessarily discards a still-valid global Creators API access token when the credential version is unchanged.
- A rejected cached token (`HTTP 401`) is discarded, refreshed once, and the search is retried once.
- Improved Amazon authentication/API error text.
- Added an OAuth diagnostic showing the active credential version.
- Added readiness status that distinguishes missing credentials, configured/not-yet-tested credentials, and a currently reusable cached OAuth token.

### Google Books

- Removed the stale hard-coded `0.1.1` User-Agent and now uses the central plugin version.
- Retains bounded handling of HTTP 429 and quota-related HTTP 403 responses.
- Retains `Retry-After` support and cooldown/backoff behaviour.
- Added an API-key connection diagnostic.
- Added readiness status that exposes missing API-key state and active cooldown time without generating a network request.

### Open Library

- Added a versioned User-Agent.
- Added a connection diagnostic.
- Added credential-free readiness status.

### Matching and metadata discovery

- KOReader EPUB `identifiers` metadata is now inspected automatically for ISBN-10 and ISBN-13 values.
- Detected ISBNs pre-fill the manual search form and are used automatically in batch mode.
- ISBN-10 is canonicalized to its ISBN-13 equivalent for comparison and deduplication.
- ISBN candidates are checksum-validated before being treated as exact identifiers.
- Results found by multiple providers are deduplicated by canonical ISBN where possible, with normalized title + author as a fallback.
- Missing useful fields from duplicate provider results may be merged into the preferred result.
- The UI shows when the same book was also found on other providers.
- Match previews now show human-readable match reasons such as exact ISBN, exact title, author match, language, series, and year signals.
- Added explicit **conflict safeguards** for contradictory ISBN, author, language, series, and publication-year evidence.
- A candidate carrying a valid ISBN that conflicts with the user's/query EPUB ISBN is capped far below the default automatic batch threshold even when title and author are exact.
- Strong author, language, series, and year conflicts reduce confidence instead of being silently ignored.
- Added evidence-aware confidence classes: **Exact**, **Strong**, **Possible**, and **Weak**. Exact ISBN matches are Exact; contradictory ISBNs are always Weak; strong confidence is only assigned when the score is high and hard-conflict evidence is absent.
- Confidence is shown in match results/previews and persisted in per-book provenance.
- Exact ISBN remains authoritative when it matches.
- Saved book-link provenance now records the Metadata Scraper plugin version.

### Testing and development

- Added a GitHub Actions Lua 5.1 workflow.
- Every Lua file is syntax-checked with `luac5.1 -p`.
- Added regression coverage for:
  - central versioning and stale-version detection
  - EPUB ISBN extraction and checksum validation
  - ISBN-10/ISBN-13 canonicalization
  - cross-provider deduplication
  - malformed provider-result isolation
  - ISBN/author/language/series conflict safeguards
  - evidence-aware confidence classification
  - provider readiness/cooldown status
  - presence of per-book field selection and batch-safety UI controls
  - Hardcover Bearer normalization
  - Hardcover Typesense result normalization
  - Amazon credential-version token endpoints and token caching
  - Amazon one-time token refresh after HTTP 401
  - Google Books HTTP 429 / `Retry-After` cooldown
  - cautious transient HTTP retry policy
  - image-signature cover validation
  - safe custom-cover rollback
  - controlled writer failures
  - current-vs-proposed change calculation
  - exact-byte metadata/cover undo snapshot and restoration
  - removing newly created overrides when no prior custom state existed
  - refusing an undo snapshot for a different book
  - diagnostics credential redaction and support-bundle generation
  - updater SHA-256 success, mismatch aborts, missing-hash rejection, and manifest validation
- Added `scripts/generate_update_manifest.py` to generate or verify release payload SHA-256 entries from a frozen runtime tree.

### Configuration note for Amazon users

Existing installations can leave `amazon_credential_version` blank temporarily; the plugin will use its legacy marketplace-based inference. For a new or updated configuration, save the credential version shown for the Amazon Creators API credential (`3.1`, `3.2`, or `3.3`) so authentication does not depend on the selected marketplace.

### Release-manifest note

The v0.1.3 updater now expects **future target releases** to include a `sha256` map in `update.json`. Each runtime path in `files` except `update.json` itself must have a 64-character SHA-256 digest. The final release process must generate and verify these hashes after the runtime file set is frozen and before a tag is published.

### Still deferred beyond 0.1.3

The following larger ideas remain outside this reliability branch for now:

- multi-revision metadata history beyond the current one-step undo snapshot
- direct `Refresh metadata` using a previously saved provider record
- full batch preview / interactive review of borderline batch matches
- richer per-book batch report
- updater support for explicitly removed files/settings migrations
- series/provider preference memory
- persistent cross-restart diagnostic logging / direct clipboard export
- provider-specific request pacing beyond existing provider cooldown handling
- safe file renaming and library organization
- audiobook metadata support

These should be evaluated separately after v0.1.3 has been tested on-device, although bounded hardening/lifecycle work may continue to be pulled forward where it reduces release risk without expanding destructive behavior.
