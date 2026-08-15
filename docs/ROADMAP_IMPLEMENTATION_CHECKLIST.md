# Roadmap implementation checklist

This document turns [`ROADMAP.md`](../ROADMAP.md) into release-level engineering work. It is intentionally detailed enough to use during implementation and review.

Checkboxes indicate implementation/release state. A checked item means the work exists on the current development branch or has been verified by an automated test; it does **not** imply that the work is merged into `main` or published unless the release itself is marked complete.

## Global definition of done

Every feature/release should satisfy the following where applicable:

- [ ] Lua syntax validation passes under the supported Lua version.
- [ ] Regression tests cover the new success path.
- [ ] Regression tests cover at least one failure/edge path.
- [ ] Provider/network failures remain isolated from unrelated providers.
- [ ] Credentials, tokens, keys, secrets, authorization headers, and private query values are redacted from diagnostics.
- [ ] Existing user settings migrate without requiring a reset.
- [ ] Any write/rename/delete operation has an explicit failure strategy.
- [ ] Existing metadata/cover/files are preserved when a replacement operation fails.
- [ ] Batch behavior has a bounded limit and does not silently become recursive/unbounded.
- [ ] UI text is usable on Kindle-size displays and does not require a hardware keyboard.
- [ ] README/changelog/roadmap/checklists are updated for user-visible changes.
- [ ] `update.json` matches the runtime file set and release version.
- [ ] Release payload hashes are generated from the frozen runtime tree and verified.
- [ ] Real-device smoke testing is completed before a stable release.

---

# v0.1.3 — Reliability, Matching & Hardening

Branch: `agent/v0.1.3-reliability-matching`

Goal: establish a stable, diagnosable matching baseline before adding destructive or library-wide functions. Several highly ranked v0.1.4/v0.2.0 safety items were intentionally expedited because they are bounded and reduce current-release risk.

## A. Versioning and provider baseline

- [x] Central version module (`lib/version.lua`).
- [x] Remove stale provider/About/updater version strings.
- [x] Provider connection diagnostics.
- [x] Hardcover Bearer normalization retained.
- [x] Hardcover Typesense result normalization retained.
- [x] Google 429/Retry-After behavior retained and regression-tested.
- [x] Amazon credential-version setting and regional token endpoint handling.
- [x] Amazon token cache tied to credential identity/endpoint.
- [x] Amazon one-time token refresh/retry after HTTP 401.

## B. Metadata discovery and identity

- [x] Automatic EPUB ISBN extraction from KOReader identifiers.
- [x] ISBN-10/ISBN-13 checksum validation.
- [x] ISBN-10 → ISBN-13 canonical comparison.
- [x] Cross-provider duplicate collapsing.
- [x] Merge useful missing fields from duplicate provider records.
- [x] Title-only fallback after strict title+author zero-result search.
- [x] Per-provider zero-result/error reporting.
- [x] Saved provenance includes provider ID/ISBN/plugin version/timestamp.

## C. Confidence safeguards — expedited core of #42

- [x] Exact valid ISBN remains authoritative at 100%.
- [x] Conflicting valid ISBN is treated as strong negative evidence.
- [x] Conflicting ISBN result is capped far below the default 90% automatic threshold.
- [x] Strong author conflict reduces confidence.
- [x] Language conflict reduces confidence.
- [x] Series conflict reduces confidence.
- [x] Material year conflict reduces confidence.
- [x] Match/conflict reasons are shown in preview.
- [x] Regression fixtures cover the conflict behavior.
- [ ] Add explicit ebook/audiobook/format edition evidence — v0.2.0.
- [ ] Add richer numeric score-component breakdown — v0.2.0.

## D. Crash/error isolation — expedited core of #48

- [x] Provider calls remain protected so one provider exception does not terminate a multi-provider search.
- [x] Malformed provider result records are discarded during ranking rather than crashing valid results.
- [x] KOReader metadata-read exceptions return controlled empty metadata and are logged.
- [x] Metadata-write exceptions return controlled failures.
- [x] Cover-write exceptions return controlled failures.
- [x] Updater verifies/stages before mutating installed files and retains rollback behavior.
- [x] Regression tests cover malformed provider records and writer exceptions.
- [ ] Consolidate remaining operation wrappers if real-device testing shows duplicated failure paths — v0.1.4.

## E. Shared transient HTTP resilience — expedited core of #24

- [x] One default retry for GET/HEAD network failure.
- [x] One default retry for HTTP 502/503/504.
- [x] Downloads use the same cautious transient retry model.
- [x] Ordinary POST requests are not generically duplicated.
- [x] Generic logic does not blindly retry HTTP 429.
- [x] Provider-specific 429/cooldown handling remains authoritative.
- [x] Retry/failure events are recorded in sanitized diagnostics.
- [x] Failed download file handles are explicitly closed before cleanup.
- [ ] Add provider-specific request pacing for batch operations — v0.1.4.

## F. Cover validation and rollback — expedited core of #25

- [x] Validate downloaded file is readable.
- [x] Reject implausibly tiny payloads.
- [x] Check Content-Type when available and reject known non-image responses.
- [x] Check binary signature.
- [x] Accept supported JPEG/PNG/WebP signatures only.
- [x] Validate before touching an existing custom cover.
- [x] Back up and restore previous custom cover if KOReader replacement fails.
- [x] Regression tests cover valid image/HTML rejection and rollback behavior.
- [ ] Optional decoded-dimension/aspect-ratio checks — v0.2.1 cover-quality work.
- [ ] Placeholder-image scoring where multiple alternatives exist — v0.2.1.

## G. Sanitized diagnostics — expedited core of #46/#47/#30

- [x] Bounded in-memory event buffer.
- [x] Record HTTP failures/retries using URLs with query strings removed.
- [x] Record provider diagnostic/search errors.
- [x] Record updater failures.
- [x] Record metadata-read/write and cover-write failures.
- [x] Redact configured Hardcover token.
- [x] Redact configured Google API key.
- [x] Redact Amazon Credential ID, secret, and Partner Tag.
- [x] Pattern-redact Bearer credentials and common query-secret forms.
- [x] Generate a support bundle containing provider/configuration state but not credential values.
- [x] Add **Save support diagnostics…** UI action.
- [x] Save bundle under plugin cache and report its path.
- [x] Regression tests inject fake credentials and ensure the bundle does not contain them.
- [ ] Persist/rotate diagnostic logs across restarts — v0.1.4.
- [ ] Include richer safe device/KOReader runtime fields where APIs are stable — v0.1.4.
- [ ] Optional clipboard/copy workflow where KOReader support is reliable — v0.1.4.

## H. SHA-256 updater integrity — expedited #26

- [x] Use KOReader's bundled `ffi/sha2` SHA-256 implementation; no shell/binary dependency.
- [x] Extend target manifest format with a `sha256` path→digest map.
- [x] Require a valid 64-character digest for every runtime payload except the control `update.json` itself.
- [x] Stage the exact already-fetched `update.json` body rather than fetching it twice.
- [x] Download all target runtime files into staging before installation.
- [x] Verify every staged runtime file after download.
- [x] Abort before installed plugin files are touched if any digest is absent/malformed/mismatched.
- [x] Re-verify staged files immediately before apply.
- [x] Keep backup/rollback behavior after verification.
- [x] Regression tests cover successful install, mismatch abort, missing map, and missing per-file digest.
- [x] Add `scripts/generate_update_manifest.py` for release-time generation/verification.
- [ ] Freeze the v0.1.3 runtime file set.
- [ ] Run `python3 scripts/generate_update_manifest.py` on the frozen release tree.
- [ ] Run `python3 scripts/generate_update_manifest.py --check` successfully before tagging.

## I. Automated tests currently required

- [x] `tests/run.lua` — core/provider regressions.
- [x] `tests/hardening.lua` — retry/image/writer/malformed-result isolation.
- [x] `tests/diagnostics.lua` — redaction/support bundle.
- [x] `tests/matcher_safety.lua` — conflict safeguards.
- [x] `tests/updater_integrity.lua` — SHA-256 updater behavior.
- [x] Lua 5.1 syntax check for every `.lua` file.
- [ ] Exact release-candidate head is green after all final doc/runtime changes.

## J. v0.1.3 release gate

Follow [`v0.1.3-testing.md`](v0.1.3-testing.md).

- [ ] Install branch build on real Kindle/KOReader.
- [ ] Confirm plugin loads and About shows 0.1.3.
- [ ] Confirm Open Library/Hardcover/Google provider diagnostics; Amazon when credentials are available.
- [ ] Search `Dungeon Crawler Carl` through Hardcover.
- [ ] Confirm embedded ISBN prefill and checksum filtering.
- [ ] Sample ISBN/language/author/series conflict scoring on-device.
- [ ] Confirm cross-provider deduplication and match reasons.
- [ ] Confirm valid cover replacement and old-cover preservation on a safe failure path if practical.
- [ ] Review a generated support diagnostics file with real configured accounts and confirm no secret values appear.
- [ ] Run a small batch and check automatic threshold behavior.
- [ ] Verify existing settings/credentials survive an in-place upgrade.
- [ ] Update README for all v0.1.3 user/release-maintainer changes.
- [ ] Freeze runtime files.
- [ ] Generate/verify manifest SHA-256 map.
- [ ] Build/test exact release ZIP.
- [ ] Only then prepare merge/release candidate.

---

# v0.1.4 — Remaining hardening & supportability

Primary remaining roadmap IDs: #27, #22, #20, #30, #29, #28 plus follow-up depth for #48/#46/#47/#25.

## A. Updater deletion and settings migrations — #27

- [ ] Add optional `remove` list to `update.json`.
- [ ] Validate removal paths using install traversal protections.
- [ ] Back up files before removal.
- [ ] Restore removed files if a later installation step fails.
- [ ] Add settings schema version.
- [ ] Add ordered migration functions (`N → N+1`).
- [ ] Test upgrade paths from oldest supported settings format.

## B. Provider request pacing/status — #22/#20

- [ ] Define provider-specific minimum request intervals for batch mode.
- [ ] Honor `Retry-After` and provider cooldowns.
- [ ] Prevent batch from hammering a provider after quota response.
- [ ] Continue healthy providers when another is cooling down.
- [ ] Expose `ready`, `cooling down`, `credentials missing`, `auth failed`, `temporarily unavailable` states.

## C. Persistent diagnostic logging — #46 follow-up

- [ ] Decide opt-in/always-bounded persistence model.
- [ ] Log timestamp, plugin version, provider, operation, elapsed time, HTTP status, retry/cooldown state, result count, response-shape summary.
- [ ] Never persist provider response bodies by default.
- [ ] Add rotation/size cap.
- [ ] Add `Clear diagnostic log`.
- [ ] Re-run redaction over persisted data before export.

## D. Richer support bundle — #47 follow-up

- [ ] Add KOReader version when safely exposed.
- [ ] Add safe device/platform string when available.
- [ ] Include batch threshold/update-channel/updater state.
- [ ] Optional copy-to-clipboard action where supported.
- [ ] Keep save-to-file action as universal fallback.

## E. Credential UX — #30

- [ ] Mask saved credentials in account UI.
- [ ] Optionally show last four characters for identification.
- [ ] Validate Amazon credential-version input before saving.
- [ ] Never echo secrets in error dialogs.
- [ ] Keep provider-specific Test action close to account configuration.

## F. Settings backup/reset — #29

- [ ] `Reset matching settings`.
- [ ] `Reset provider settings` with warning.
- [ ] `Reset all plugin settings`.
- [ ] Consider credential-free configuration export as default backup mode.
- [ ] If secret export is ever supported, require separate explicit warning/action.

## G. Stable/prerelease channel — #28

- [ ] Stable remains default.
- [ ] Optional Prerelease/Test channel follows published GitHub prereleases only, never arbitrary `main`.
- [ ] Clearly label test updates.
- [ ] Allow return to Stable without settings reset.

---

# v0.2.0 — Metadata lifecycle, review & undo

Primary roadmap IDs: #6, #12, #1, #14, expanded #42, #10, #44, #23, #15, #13, #11, #18, #16, #45, #17.

## A. Provenance model prerequisite

Before refresh/undo, define a stable record per matched file:

- [ ] canonical file identity/path strategy;
- [ ] provider ID and source;
- [ ] ISBN-10/ISBN-13;
- [ ] canonical work/edition key where available;
- [ ] matched title/author/series;
- [ ] score/confidence class;
- [ ] plugin version and timestamps;
- [ ] fields written and cover source;
- [ ] previous-state reference for undo/history.

## B. Exact-edition awareness — #6

- [ ] Add edition-format signals when providers expose them.
- [ ] Distinguish work-level and edition-level IDs.
- [ ] Prefer exact ISBN edition over same-work text matches.
- [ ] Extend current conflict penalties to format/edition evidence.
- [ ] Penalize audiobook-only result while processing EPUB where a book edition exists.
- [ ] Use publication year/publisher/series/subtitle as secondary evidence.
- [ ] Never assume same title+author means same edition.

## C. Explainable confidence — expanded #42/#44

- [ ] Move scoring into explicit positive/negative components.
- [ ] Human-readable score breakdown.
- [ ] Add ambiguous-title fixtures.
- [ ] Ensure title-only exact match cannot imply exact edition without evidence.
- [ ] Add confidence class that honors hard conflicts rather than score alone.

## D. Current vs proposed comparison — #10

- [ ] Show existing KOReader values beside proposed values.
- [ ] Mark unchanged/added/replaced/unavailable fields.
- [ ] Display provider provenance for proposed fields.
- [ ] Keep readable on e-ink screens.

## E. Select fields at apply time — #11

- [ ] Start with global defaults.
- [ ] Per-book override before Apply.
- [ ] Independent Cover toggle.
- [ ] Optional `Save as defaults` rather than silently changing global settings.

## F. Undo/history — #12/#13

- [ ] Snapshot custom metadata before mutation.
- [ ] Snapshot existing custom cover safely.
- [ ] `Undo last metadata update` per book.
- [ ] Restore metadata and cover atomically where possible.
- [ ] Record bounded revision history with source/score/fields/plugin version.
- [ ] Never discard the only backup before replacement is known-good.

## G. Refresh exact record — #1

- [ ] Provider `get_by_id`/detail capability where available.
- [ ] Refresh saved provider record before fuzzy search.
- [ ] Stale provider ID offers a new search instead of silently picking another edition.
- [ ] `Refresh metadata`.
- [ ] `Refresh cover only`.
- [ ] Preview material changes.

## H. Batch preview/review — #14/#15

- [ ] Discovery phase performs no writes.
- [ ] Group high-confidence/borderline/unmatched/failed.
- [ ] Present counts before apply.
- [ ] Allow high-confidence-only apply.
- [ ] Borderline review supports Apply/Skip/Search again/Stop.
- [ ] Cancel preview with zero writes.

## I. Batch resume/skip/report — #23/#18/#16

- [ ] Persist batch identity/completed files.
- [ ] Recover after Wi-Fi loss/restart.
- [ ] Avoid duplicate writes.
- [ ] Default skip books with valid provenance.
- [ ] Optional refresh-existing mode.
- [ ] Save sanitized report with filename/title/source/score/status/error.

## J. Threshold presets and recursion — #45/#17

- [ ] Strict 95 / Recommended 90 / Permissive 80-with-warning presets.
- [ ] Preserve custom threshold.
- [ ] Recursive batch remains off by default.
- [ ] Preview folder/file count and enforce hard upper bound.
- [ ] Avoid symlink loops.
- [ ] Require preview before recursive writes.

---

# v0.2.1 — Multi-source quality & normalization

Primary roadmap IDs: #2, #40, #41, #7, #19, #5, #37, #43, #8, #36, #38, #3, #9, #39, #4, #21.

## A. Normalized metadata and source merging — #2/#3

- [ ] Provider-independent normalized record.
- [ ] Track field-level provenance.
- [ ] Merge only confidently identical work/edition records.
- [ ] Never let lower-confidence duplicate overwrite stronger populated field without rule.
- [ ] Global/per-field provider preferences with `Best available` default.

## B. Title/author/role normalization — #7/#40/#41

- [ ] Conservative title whitespace/punctuation cleanup.
- [ ] Safe removal of obvious format labels/repeated series suffixes.
- [ ] `Surname, Given` vs `Given Surname` comparison normalization.
- [ ] Initial/multi-author handling.
- [ ] Separate author/editor/translator/illustrator/narrator roles where exposed.
- [ ] Never replace stored author solely with comparison-normalized text.

## C. Search cache — #19

- [ ] Cache normalized query+provider+relevant settings for short TTL.
- [ ] Do not long-cache auth errors.
- [ ] Keep cooldown state separate.
- [ ] Invalidate when provider/account settings change.

## D. Cover quality/chooser — #5/#4

- [ ] Collect cover candidates from deduplicated results.
- [ ] Record dimensions/file size where discoverable.
- [ ] Prefer larger valid edition-compatible covers with sensible aspect ratio.
- [ ] Reject placeholders.
- [ ] Optional source/dimension chooser.
- [ ] `Best automatically` simple default.

## E. Description/genre/language normalization — #37/#38/#39

- [ ] Safe HTML/whitespace cleanup for descriptions.
- [ ] Deduplicate genre case/punctuation variants and cap excessive subject lists.
- [ ] Expand ISO 639 mappings and normalize locale variants for matching.
- [ ] Retain raw values in provenance where useful.

## F. Series/confidence/additional fields — #8/#43/#36

- [ ] Normalize series names/indexes including decimals.
- [ ] Confidence classes `Exact/Strong/Possible/Weak` honoring conflicts.
- [ ] Evaluate publisher/date/identifiers/page count/original title/format against KOReader-native support.
- [ ] Unsupported values remain in provenance rather than being forced into sidecars.

## G. Search controls/provider priority — #9/#21

- [ ] ISBN only / title+author / title only / cleaned title / choose provider quick actions.
- [ ] Preserve search fields while switching mode.
- [ ] Configurable provider order used as tie-break, not substitute for evidence.

---

# v0.2.2 — File organization & interoperability

Primary roadmap IDs: #51, #50, #33, #49, #31, #34, #32.

## A. Safe file renaming and library organization — #51

This feature is intentionally delayed until provenance and undo are reliable because it changes filesystem paths and can affect KOReader sidecars/history.

### Rename model

- [ ] Template engine: `{title}`, `{author}`, `{series}`, `{series_index}`, `{year}`, `{isbn}`.
- [ ] Conservative presets: `{title}.epub`, `{author} - {title}.epub`, `{series} {series_index} - {title}.epub`, `{author}/{series}/{series_index} - {title}.epub`.
- [ ] Zero-padding without breaking decimal volumes.
- [ ] Preserve original extension.
- [ ] Omit empty template segments cleanly.

### Filename/path safety

- [ ] Sanitize separators/control/reserved/problematic characters.
- [ ] Conservative path/filename length.
- [ ] Normalize repeated whitespace.
- [ ] Never silently overwrite.
- [ ] Detect case-only and destination collisions before moving anything.

### Preview and confirmation

- [ ] Always show `old path → new path`.
- [ ] Batch preview before operations.
- [ ] Separate collision/invalid rows.
- [ ] Allow deselecting rows.
- [ ] Ordinary metadata fetch never renames unless explicitly enabled.

### KOReader sidecar/history preservation

- [ ] Use KOReader-supported relocation mechanisms where possible.
- [ ] Preserve `.sdr`, reading progress/history, custom metadata, custom cover.
- [ ] Migrate plugin provenance/book link and batch/history references.

### Rename transaction/undo

- [ ] Preflight every source/destination.
- [ ] Transaction-like file + sidecar relocation.
- [ ] Record original/destination.
- [ ] `Undo last rename`.
- [ ] Roll back file move if sidecar relocation fails.
- [ ] If rollback fails, surface both paths and never delete either copy silently.

### Folder organization

- [ ] Optional author folder.
- [ ] Optional series folder.
- [ ] Validate before creating directories.
- [ ] Avoid nested duplicates.
- [ ] Keep organization rules independent from metadata-writing rules.

### Rename tests

- [ ] duplicate destination;
- [ ] illegal characters;
- [ ] very long title;
- [ ] no series;
- [ ] decimal series index;
- [ ] Unicode names;
- [ ] already-correct filename;
- [ ] read-only destination;
- [ ] sidecar relocation failure;
- [ ] undo after success.

## B. Filename parser/search bootstrap — #50

- [ ] Parse common `Author - Title` patterns.
- [ ] Parse series/volume tokens conservatively.
- [ ] Never overwrite good embedded metadata based on filename guess.
- [ ] Use parsed values as suggestions/fallbacks.
- [ ] Review parsed values before search.

## C. Calibre compatibility — #33

- [ ] Detect useful Calibre title/authors/series/identifiers where KOReader exposes them.
- [ ] Avoid degrading richer existing metadata.
- [ ] Document Calibre-generated EPUB/sidecar behavior.
- [ ] Do not require Calibre.

## D. Offline/manual editor — #49

- [ ] Edit title/authors/series/index/language/keywords/description offline.
- [ ] Choose/remove local cover.
- [ ] Use same undo/history infrastructure.

## E. Provider ID/URL — #31/#32

- [ ] Store canonical public URL where available.
- [ ] Show provider ID in advanced preview/diagnostics.
- [ ] Copy/open only where platform support is reliable.
- [ ] Never expose authenticated API URLs with keys/tokens.

## F. OPF import/export — #34

- [ ] Define field mapping.
- [ ] Export without modifying EPUB.
- [ ] Import into KOReader custom metadata with preview.
- [ ] Preserve OPF/manual provenance.
- [ ] Avoid clobbering richer data without confirmation.

---

# v0.3.0 — Audiobook metadata support

Primary roadmap ID: #52.

Audiobooks require a format/edition model rather than an `isEpub()` extension check. The first milestone focuses on discovery, matching, metadata/provenance, covers, and safe organization—not playback or destructive media-tag writes.

## A. Architecture

- [ ] Replace EPUB-only assumptions with media-kind abstraction: `ebook`, `audiobook-single`, `audiobook-folder`.
- [ ] Keep ebook behavior unchanged behind abstraction.
- [ ] Capability checks instead of scattered extension tests.
- [ ] Normalized `BookWork` and `Edition` concepts.
- [ ] Audiobook fields: narrator, duration, abridged state, audio format, track count.
- [ ] Provider raw payloads remain isolated.

## B. Supported formats — first milestone

- [ ] `.m4b`.
- [ ] `.mp3`.
- [ ] `.m4a`.
- [ ] Investigate `.ogg`/`.opus` only if metadata handling is reliable.
- [ ] Multi-track audiobook folder.

## C. Local metadata discovery

- [ ] Read title/author/album/series-equivalent tags without modification.
- [ ] Read narrator/performer.
- [ ] Read duration.
- [ ] Read embedded identifiers/ASIN/ISBN.
- [ ] Read embedded cover where accessible.
- [ ] Detect track/disc number.
- [ ] Fall back to parent-folder/filename parsing when tags absent.
- [ ] If KOReader lacks required tags, research lightweight compatible parser before adding heavy dependency.

## D. Multi-track folder detection

- [ ] Group supported audio files in one directory only with supporting evidence.
- [ ] Detect sequential track numbering.
- [ ] Verify common album/book title where tags exist.
- [ ] Calculate total duration.
- [ ] Avoid grouping unrelated music solely because it shares a folder.
- [ ] User override `Treat folder as audiobook`.
- [ ] One shared provenance record plus per-track ordering if needed.

## E. Audiobook matching

Positive signals:

- [ ] exact audiobook ASIN/provider ID;
- [ ] edition-appropriate exact ISBN;
- [ ] title;
- [ ] author;
- [ ] narrator;
- [ ] duration tolerance;
- [ ] language;
- [ ] series/volume;
- [ ] audio format/edition label;
- [ ] abridged/unabridged state.

Negative signals:

- [ ] conflicting narrator;
- [ ] materially different duration;
- [ ] conflicting language;
- [ ] ebook/paperback-only edition when audiobook expected;
- [ ] dramatized/full-cast mismatch;
- [ ] abridged/unabridged conflict.

## F. Provider audit

- [ ] Hardcover audiobook/edition fields.
- [ ] Amazon Creators API audiobook/ASIN search data.
- [ ] Google/Open Library work-level fallback usefulness.
- [ ] Research audiobook-specific official/public APIs before adding another provider.
- [ ] Document terms/eligibility.
- [ ] Add audiobook response fixtures.

## G. Normalized audiobook fields

- [ ] title;
- [ ] author(s);
- [ ] narrator(s);
- [ ] series/index;
- [ ] language;
- [ ] publisher/date;
- [ ] description/genres;
- [ ] ISBN/ASIN/provider IDs;
- [ ] duration;
- [ ] abridged state;
- [ ] cover;
- [ ] track count.

## H. Audiobook cover workflow

- [ ] Prefer edition-compatible audiobook cover.
- [ ] Show source/provider.
- [ ] Reuse validated cover pipeline.
- [ ] Preserve existing cover on failure.
- [ ] Define shared cover location for folder audiobook without rewriting every track.

## I. Audiobook file/folder renaming

Reuse v0.2.2 safe rename engine.

- [ ] `{author} - {title}.m4b`.
- [ ] `{series} {series_index} - {title}.m4b`.
- [ ] `{author}/{series}/{series_index} - {title}/`.
- [ ] Parent folder rename independent from tracks.
- [ ] Preserve track ordering.
- [ ] Optional `{track:02} - {title}.mp3` template.
- [ ] No automatic track rename solely because metadata was scraped.
- [ ] Preview every affected path.
- [ ] Undo entire rename set.

## J. Ebook ↔ audiobook linking — later sub-milestone

- [ ] Detect same underlying work.
- [ ] Share work-level title/author/series/genres.
- [ ] Keep cover/narrator/duration/format/identifiers/dates edition-specific.
- [ ] Never assume same title+author means same edition.

## K. Direct audio tag writing — explicitly deferred

Before source-file modification:

- [ ] reliable tag-writing library on KOReader targets;
- [ ] full/tag backup strategy;
- [ ] M4B chapter preservation tests;
- [ ] MP3 ID3 preservation tests;
- [ ] embedded cover replacement tests;
- [ ] explicit opt-in confirmation;
- [ ] rollback on failure;
- [ ] normal scrape remains non-destructive default.

## L. Playback integration — optional/later

- [ ] Determine whether KOReader/external player exposes stable integration.
- [ ] Keep playback state separate unless reliable integration exists.

---

# Later / experimental

## Optional EPUB write-back — #35

The current project principle is that EPUB files are not rewritten. If direct write-back is ever implemented:

- [ ] disabled by default;
- [ ] backup first;
- [ ] edit OPF without damaging manifest/spine/navigation;
- [ ] preserve DRM-free EPUB validity;
- [ ] validate resulting container;
- [ ] explicit confirmation and restore;
- [ ] never mix write-back silently into normal Apply.

---

# Dependency map

1. **Diagnostics/error isolation** → safer provider expansion and easier field testing. Core exists in v0.1.3; persistence can deepen later.
2. **Updater hashes/migrations** → safer future release complexity. Hash verification exists in v0.1.3; removals/settings migrations remain v0.1.4.
3. **Provenance + exact-edition model** → refresh, history, multi-source merging, audiobook linking.
4. **Undo/history** → batch preview automation and safe file renaming.
5. **Normalized metadata record** → per-field source preferences and audiobook support.
6. **Safe rename transaction** → audiobook folder/track organization.
7. **Cover validation** → cover chooser and audiobook cover workflows. Core validation exists in v0.1.3.
8. **Format/media abstraction** → audiobook support without destabilizing EPUB behavior.

# Re-scoring policy

Update scores in `ROADMAP.md` when:

- a real bug demonstrates higher/lower risk;
- provider/API change alters complexity;
- usage/issue data changes expected breadth;
- prerequisite completion makes another feature materially easier;
- KOReader adds/removes native capability;
- proposed feature creates new source-file/privacy risk.

When scores tie, prefer in order:

1. higher Risk Reduction;
2. higher User Impact;
3. higher Architectural Leverage;
4. lower implementation risk/dependency count;
5. smaller bounded implementation size.
