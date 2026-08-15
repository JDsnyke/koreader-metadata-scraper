# Changelog

All notable changes to Metadata Scraper for KOReader will be documented here.

## [0.1.3] - Unreleased

### Reliability

- Centralized the plugin version and HTTP User-Agent in `lib/version.lua` so provider, updater, metadata, and About-dialog versions cannot drift independently.
- Added provider connection diagnostics for Hardcover, Amazon Creators API, Google Books, and Open Library.
- Preserved an existing KOReader custom cover if replacement of the cover fails.
- Added clearer per-provider errors/counts when a search returns no matches.
- Added one broader title-only fallback when a strict title + author search returns no results.
- **Expedited from the v0.1.4 hardening roadmap:** GET requests and downloads now retry once for network failures and HTTP 502/503/504 only. Generic retries deliberately do not retry HTTP 429, authentication failures, or ordinary POST requests.
- Added cover validation before replacement: downloaded covers must be large enough to be plausible images and have a recognized JPEG, PNG, WebP, or GIF signature. Known non-image content types are rejected.
- Metadata and custom-cover writes are isolated with protected calls so unexpected KOReader-side exceptions become controlled failures instead of propagating through the plugin.
- Malformed provider result records are discarded during ranking rather than preventing valid results from other providers from being shown.
- Added a sanitized diagnostics core with a bounded in-memory event buffer, URL query redaction, credential redaction, and support-bundle generation. Configured tokens, API keys, Amazon secrets, credential IDs, and partner tags are never intentionally emitted by the diagnostics bundle.
- HTTP failures/retries are recorded using sanitized URLs with query strings removed.

### Hardcover

- Retains the confirmed `Authorization: Bearer <token>` authentication fix.
- Retains compatibility with Hardcover's Typesense-backed search result shapes, including `hits[].document` and JSON-encoded results.
- Added an authenticated account diagnostic using the `me` GraphQL query.

### Amazon Creators API

- Added an Amazon credential-version setting (`3.1`, `3.2`, or `3.3`) so the OAuth token endpoint follows the credential's region/version rather than assuming it from the marketplace being searched.
- Kept backward-compatible endpoint inference for existing installations where credential version has not yet been saved.
- Token caching is now keyed to the configured credentials and credential endpoint.
- Changing the marketplace no longer unnecessarily discards a still-valid global Creators API access token when the credential version is unchanged.
- A rejected cached token (`HTTP 401`) is discarded, refreshed once, and the search is retried once.
- Improved Amazon authentication/API error text.
- Added an OAuth diagnostic showing the active credential version.

### Google Books

- Removed the stale hard-coded `0.1.1` User-Agent and now uses the central plugin version.
- Retains bounded handling of HTTP 429 and quota-related HTTP 403 responses.
- Retains `Retry-After` support and cooldown/backoff behaviour.
- Added an API-key connection diagnostic.

### Open Library

- Added a versioned User-Agent.
- Added a connection diagnostic.

### Matching and metadata discovery

- KOReader EPUB `identifiers` metadata is now inspected automatically for ISBN-10 and ISBN-13 values.
- Detected ISBNs pre-fill the manual search form and are used automatically in batch mode.
- ISBN-10 is canonicalized to its ISBN-13 equivalent for comparison and deduplication.
- ISBN candidates are checksum-validated before being treated as exact identifiers.
- Results found by multiple providers are deduplicated by canonical ISBN where possible, with normalized title + author as a fallback.
- Missing useful fields from duplicate provider results may be merged into the preferred result.
- The UI shows when the same book was also found on other providers.
- Match previews now show human-readable match reasons such as exact ISBN, exact title, author match, language, series, and year signals.
- Series and publication-year signals can contribute small confidence adjustments without replacing title/author/ISBN as the primary matching inputs.
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
  - Hardcover Bearer normalization
  - Hardcover Typesense result normalization
  - Amazon credential-version token endpoints and token caching
  - Amazon one-time token refresh after HTTP 401
  - Google Books HTTP 429 / `Retry-After` cooldown
  - cautious transient HTTP retry policy
  - image-signature cover validation
  - safe custom-cover rollback
  - controlled writer failures
  - diagnostics credential redaction and support-bundle generation

### Configuration note for Amazon users

Existing installations can leave `amazon_credential_version` blank temporarily; the plugin will use its legacy marketplace-based inference. For a new or updated configuration, save the credential version shown for the Amazon Creators API credential (`3.1`, `3.2`, or `3.3`) so authentication does not depend on the selected marketplace.

### Still deferred beyond 0.1.3

The following larger ideas remain outside this reliability branch for now:

- per-file SHA-256 validation in update manifests
- updater support for explicitly removed files/settings migrations
- interactive review of borderline batch matches
- richer per-book batch report
- series/provider preference memory
- direct `Refresh metadata` using a previously saved provider record
- full persistent diagnostic log UI / copy-export workflow
- provider-specific request pacing beyond existing provider cooldown handling
- safe file renaming and library organization
- audiobook metadata support

These should be evaluated separately after v0.1.3 has been tested on-device, although bounded hardening work may continue to be pulled forward where it reduces release risk without expanding destructive behavior.
