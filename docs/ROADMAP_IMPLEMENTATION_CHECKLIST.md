# Roadmap implementation checklist

This document turns [`ROADMAP.md`](../ROADMAP.md) into release-level engineering work. It is intentionally detailed enough to use during implementation and review.

Checkboxes indicate implementation/release state. A checked item means the work exists on the current development branch or has automated coverage; it does **not** imply that the work is merged into `main` or published.

## Global definition of done

Every feature/release should satisfy the following where applicable:

- [ ] Lua syntax validation passes under the supported Lua version.
- [ ] Regression tests cover the success path.
- [ ] Regression tests cover at least one failure/edge path.
- [ ] Provider/network failures remain isolated from unrelated providers.
- [ ] Credentials, tokens, keys, authorization headers, and private query values are redacted from diagnostics.
- [ ] Existing user settings load without requiring a reset.
- [ ] Any write/rename/delete operation has an explicit failure strategy.
- [ ] Existing metadata/cover/files are preserved when replacement fails.
- [ ] Batch behavior stays bounded and does not silently become recursive/unbounded.
- [ ] UI remains usable on Kindle-size/e-ink displays.
- [ ] README/changelog/roadmap/checklists are updated for user-visible changes.
- [ ] `update.json` matches the runtime file set and release version.
- [ ] Release payload hashes are generated from the frozen runtime tree and verified.
- [ ] Real-device smoke testing is completed before a stable release.

---

# v0.1.3 — Reliability, Matching, Hardening & Lifecycle Safety

Branch: `agent/v0.1.3-reliability-matching`

Goal: establish a safe, diagnosable metadata baseline before adding filesystem-wide or media-format functionality. Bounded high-value work from later roadmap releases has been deliberately expedited where it reduces current-release risk.

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
- [x] Save provider source/ID and canonical ISBN in provenance.

## C. Confidence safeguards and classes — #42/#43/#44 core

- [x] Exact valid ISBN remains authoritative at 100%.
- [x] Conflicting valid ISBN is strong negative evidence.
- [x] Conflicting ISBN result is capped far below the default automatic threshold.
- [x] Strong author conflict reduces confidence.
- [x] Language conflict reduces confidence.
- [x] Series conflict reduces confidence.
- [x] Material year conflict reduces confidence.
- [x] Match/conflict reasons are shown in preview.
- [x] Evidence-aware `Exact`, `Strong`, `Possible`, `Weak` classes.
- [x] Exact ISBN → Exact.
- [x] ISBN conflict → Weak even when title/author text is similar.
- [x] Strong requires high score without hard author/language/series conflicts.
- [x] Confidence is shown in result rows and preview.
- [x] Confidence is persisted in provenance/Last match details.
- [x] Regression fixtures cover conflict and class behavior.
- [ ] Explicit ebook/audiobook/format edition evidence — v0.2.0.
- [ ] Numeric positive/negative score-component breakdown — v0.2.0.

## D. Current → Proposed and per-book Apply controls — #10/#11

- [x] Calculate the fields that would actually change under current write mode.
- [x] Show Current → Proposed values for bounded text fields.
- [x] Represent long description changes as add/replace rather than dumping full text.
- [x] Treat no-text/no-cover changes as a no-op.
- [x] Add **Choose fields for this book…**.
- [x] Start one-off selection from global defaults.
- [x] One-off Title/Authors/Series/Series index/Language/Keywords/Description toggles.
- [x] Independent one-off Cover toggle.
- [x] **Apply selected** passes temporary options to the writer path.
- [x] One-off choices do not mutate global defaults.
- [x] Ordinary **Apply** continues to use global defaults unchanged.
- [ ] Optional explicit `Save as defaults` from the one-off selector — later only if useful.
- [ ] Field-level source provenance in comparison — v0.2.x multi-source work.

## E. One-step undo and provenance — #12/#13/#1 groundwork

- [x] Snapshot exact pre-apply custom-metadata bytes.
- [x] Snapshot exact pre-apply custom-cover bytes.
- [x] Refuse mutation if required undo snapshot cannot be created.
- [x] Remove newly-created override on undo when no prior override existed.
- [x] Restore prior custom metadata.
- [x] Restore prior custom cover.
- [x] Restore prior Metadata Scraper provenance.
- [x] Expose **Undo last metadata update** in current-book/context UI.
- [x] Persist undo record across KOReader restart via plugin settings.
- [x] Keep only one undo point per book.
- [x] Bound overall undo set to 20 books.
- [x] Collision-check undo backup names.
- [x] Reject undo snapshot for another book.
- [x] Save source/ID/ISBN/title/authors/series/language/date/publisher.
- [x] Save score/confidence/match reasons/query.
- [x] Save fields written, cover outcome, plugin version, timestamp.
- [x] Add **Last match details**.
- [x] Cover-only successful changes receive undo/provenance.
- [ ] Multi-revision history — v0.2.0.
- [ ] Direct provider-record refresh — v0.2.0.

## F. Batch safety controls — #18/#45 core

- [x] Keep batch current-folder-only and non-recursive.
- [x] Keep existing file-count bound.
- [x] Recommended threshold remains 90% by default.
- [x] Add Strict 95% preset.
- [x] Add Recommended 90% preset.
- [x] Add Permissive 80% preset.
- [x] Add **Skip already matched in batch**.
- [x] Skip-matched defaults to enabled for new/old settings lacking the key.
- [x] Skip matched files before provider queries, reducing repeat API calls.
- [x] Batch confirmation states when matched files will be skipped.
- [x] Applied batch books retain one-step undo/provenance.
- [ ] Full discovery-only batch preview — v0.2.0.
- [ ] Interactive borderline review — v0.2.0.
- [ ] Rich per-book batch report/export — v0.2.0.
- [ ] Preserve arbitrary custom numeric threshold alongside presets if demand appears.

## G. Crash/error isolation — #48 core

- [x] Provider calls remain protected so one provider exception does not terminate multi-provider search.
- [x] Malformed provider records are discarded during ranking rather than crashing valid results.
- [x] KOReader metadata-read exceptions return controlled empty metadata and are logged.
- [x] Metadata-write exceptions return controlled failures.
- [x] Cover-write exceptions return controlled failures.
- [x] Updater verifies/stages before mutating installed files and retains rollback behavior.
- [x] Regression tests cover malformed records and writer exceptions.
- [ ] Consolidate remaining operation wrappers if real-device testing shows duplicated failure paths — v0.1.4.

## H. Shared transient HTTP resilience — #24 core

- [x] One default retry for GET/HEAD network failure.
- [x] One default retry for HTTP 502/503/504.
- [x] Downloads use the same cautious transient retry model.
- [x] Ordinary POST requests are not generically duplicated.
- [x] Generic logic does not blindly retry HTTP 429.
- [x] Provider-specific 429/cooldown handling remains authoritative.
- [x] Retry/failure events enter sanitized diagnostics.
- [x] Failed download handles close before cleanup.
- [ ] Provider-specific request pacing for larger batch workloads — v0.1.4.

## I. Cover validation and rollback — #25 core

- [x] Validate downloaded file is readable.
- [x] Reject implausibly tiny payloads.
- [x] Check Content-Type when available.
- [x] Reject known non-image responses.
- [x] Check binary signature.
- [x] Support JPEG/PNG/WebP cover signatures.
- [x] Validate before touching existing custom cover.
- [x] Back up and restore previous cover if KOReader replacement fails.
- [x] Regression tests cover image/HTML rejection and rollback.
- [ ] Decoded-dimension/aspect-ratio checks — v0.2.1 cover-quality work.
- [ ] Placeholder scoring when multiple covers exist — v0.2.1.

## J. Diagnostics and provider readiness — #46/#47/#30/#20 core

- [x] Bounded in-memory sanitized event buffer.
- [x] HTTP failures/retries use URLs with query values removed.
- [x] Record provider diagnostic/search errors.
- [x] Record updater failures.
- [x] Record metadata/cover failures.
- [x] Redact configured Hardcover token.
- [x] Redact configured Google API key.
- [x] Redact Amazon Credential ID/secret/Partner Tag.
- [x] Pattern-redact Bearer/common query-secret forms.
- [x] Generate support bundle without credential values.
- [x] Add **Save support diagnostics…**.
- [x] Save bundle under plugin cache and report path.
- [x] Add provider `status()` hooks that do not make a network call just to render UI.
- [x] Open Library reports credential-free readiness.
- [x] Hardcover reports token missing/configured state.
- [x] Google reports missing key/ready/active cooldown.
- [x] Amazon reports credentials missing/configured/cached-token-ready.
- [x] Providers dialog surfaces current readiness text.
- [x] Regression tests exercise provider status states.
- [ ] Persist/rotate diagnostic logs across restarts — v0.1.4.
- [ ] Richer safe device/KOReader runtime fields — v0.1.4.
- [ ] Persist last successful/failed provider health state — optional v0.1.4.
- [ ] `auth failed`/`temporarily unavailable` remembered beyond the immediate error path — optional v0.1.4.

## K. SHA-256 updater integrity — #26

- [x] Use KOReader bundled `ffi/sha2`; no shell/binary dependency.
- [x] Target manifest supports `sha256` path→digest map.
- [x] Require valid digest for every runtime payload except control `update.json`.
- [x] Stage exact fetched `update.json` body rather than fetching it twice.
- [x] Download runtime files before installation.
- [x] Verify staged files after download.
- [x] Abort before installed files are touched on missing/malformed/mismatched digest.
- [x] Re-verify immediately before apply.
- [x] Keep backup/rollback after verification.
- [x] Regression tests cover success/mismatch/missing map/missing digest.
- [x] Add `scripts/generate_update_manifest.py`.
- [ ] Freeze v0.1.3 runtime file set.
- [ ] Generate final v0.1.3 hash map.
- [ ] `python3 scripts/generate_update_manifest.py --check` passes before tagging.

## L. Automated tests currently required

- [x] `tests/run.lua` — core/provider/status/UI wiring regressions.
- [x] `tests/hardening.lua` — retry/image/writer/malformed-result isolation.
- [x] `tests/diagnostics.lua` — redaction/support bundle.
- [x] `tests/matcher_safety.lua` — conflict safeguards/confidence classes.
- [x] `tests/updater_integrity.lua` — SHA-256 updater behavior.
- [x] `tests/lifecycle.lua` — Current/Proposed and exact-byte undo behavior.
- [x] Lua 5.1 syntax check for every `.lua` file.
- [ ] Exact release-candidate head green after all final doc/runtime changes.

## M. v0.1.3 release gate

Follow [`v0.1.3-testing.md`](v0.1.3-testing.md).

- [ ] Install branch build on real Kindle/KOReader.
- [ ] Plugin loads; About shows 0.1.3.
- [ ] Provider diagnostics work; readiness/status UI looks sensible.
- [ ] Hardcover `Dungeon Crawler Carl` regression passes.
- [ ] Embedded ISBN prefill/checksum filtering works.
- [ ] Conflict scoring and confidence labels look sensible.
- [ ] Cross-provider dedupe/match reasons work.
- [ ] Current → Proposed preview works in both write modes.
- [ ] Per-book field selection does not alter global defaults.
- [ ] One-step undo survives restart and restores metadata/cover/provenance.
- [ ] Cover validation/replacement works on disposable book.
- [ ] Support diagnostics reviewed with real accounts; no secrets appear.
- [ ] Batch 95/90/80 presets work.
- [ ] Skip-already-matched works before provider querying.
- [ ] Existing settings/credentials survive in-place upgrade.
- [ ] README updated for all v0.1.3 user/release-maintainer changes.
- [ ] Freeze runtime files.
- [ ] Generate/verify manifest hashes.
- [ ] Build/test exact release ZIP.
- [ ] Only then prepare merge/release candidate.

---

# v0.1.4 — Remaining hardening & supportability

Primary remaining roadmap IDs: #27, #22, #30, #29, #28 plus follow-up depth for #48/#46/#47/#25/#20.

## A. Updater deletion and settings migrations — #27

- [ ] Optional `remove` list in `update.json`.
- [ ] Apply same path-traversal validation as install paths.
- [ ] Back up before removal.
- [ ] Restore removed files if later install step fails.
- [ ] Settings schema version.
- [ ] Ordered migration functions (`N → N+1`).
- [ ] Test upgrade from oldest supported settings shape.

## B. Provider request pacing — #22

- [ ] Define provider-specific safe minimum intervals for batch mode where needed.
- [ ] Honor `Retry-After` and provider cooldowns.
- [ ] Stop hammering a provider after quota response.
- [ ] Continue healthy providers while another cools down.
- [ ] Avoid adding arbitrary delays where provider/API behavior does not require them.

## C. Provider status depth — #20 follow-up

v0.1.3 already provides non-network readiness/cooldown status.

- [ ] Consider bounded last-success/last-failure state.
- [ ] Distinguish auth-failed vs temporary-network failure without storing secrets.
- [ ] Consider last-test timestamp.
- [ ] Keep status display cheap; opening a menu must not itself trigger provider traffic.

## D. Persistent diagnostics — #46/#47 follow-up

- [ ] Decide opt-in/always-bounded persistence model.
- [ ] Store timestamp/version/provider/operation/status/retry/cooldown/result count where safe.
- [ ] Never persist full provider response bodies by default.
- [ ] Rotation/size cap.
- [ ] `Clear diagnostic log`.
- [ ] Re-run redaction before export.
- [ ] Add KOReader/device metadata only where safely exposed.
- [ ] Optional clipboard/copy action with save-to-file fallback.

## E. Credential UX — #30

- [ ] Mask saved credentials in account UI.
- [ ] Optional last-four identification.
- [ ] Validate Amazon credential-version value before saving.
- [ ] Never echo secrets in error dialogs.
- [ ] Keep Test action near account configuration.

## F. Settings backup/reset — #29

- [ ] `Reset matching settings`.
- [ ] `Reset provider settings` with warning.
- [ ] `Reset all plugin settings`.
- [ ] Consider credential-free configuration export as default backup.
- [ ] Secret export, if ever supported, is separate and explicitly warned.

## G. Stable/prerelease update channel — #28

- [ ] Stable remains default.
- [ ] Optional Prerelease/Test follows published GitHub prereleases only, never arbitrary `main`.
- [ ] Clearly label test updates.
- [ ] Return to Stable without settings reset.

---

# v0.2.0 — Full metadata lifecycle, review & refresh

v0.1.3 already includes one-step undo, provenance, per-book Apply field selection, skip-matched batch behavior, and threshold presets.

## A. Exact-edition awareness — #6

- [ ] Add edition-format signals where providers expose them.
- [ ] Distinguish work-level and edition-level IDs.
- [ ] Prefer exact ISBN edition over same-work text match.
- [ ] Extend conflict penalties to format/edition evidence.
- [ ] Penalize audiobook-only result while processing EPUB when book edition exists.
- [ ] Use year/publisher/series/subtitle as secondary evidence.
- [ ] Never assume same title+author means same edition.

## B. Explainable scoring — #42/#44 follow-up

- [ ] Explicit positive/negative score components.
- [ ] Human-readable component breakdown.
- [ ] Ambiguous-title fixtures.
- [ ] Exact-title-only match cannot imply exact edition.
- [ ] Keep v0.1.3 Exact/Strong/Possible/Weak classes, refined with format evidence.

## C. Richer comparison/provenance — #10 follow-up

- [ ] Mark unchanged/added/replaced/unavailable fields distinctly.
- [ ] Display provider provenance per proposed field after multi-source merging exists.
- [ ] Keep e-ink layout compact.

## D. Multi-revision history — #13

- [ ] Retain bounded multiple revisions per book.
- [ ] Timestamp/source/score/fields/plugin version per revision.
- [ ] View history.
- [ ] Restore selected prior revision safely.
- [ ] Bound disk/settings usage.

## E. Refresh exact record — #1

- [ ] Provider `get_by_id`/detail capability where available.
- [ ] Refresh saved provider ID before fuzzy search.
- [ ] Stale ID offers new search instead of silently selecting another edition.
- [ ] `Refresh metadata`.
- [ ] `Refresh cover only`.
- [ ] Preview material changes before commit.

## F. Batch preview/review — #14/#15

- [ ] Discovery phase performs no writes.
- [ ] Group high-confidence/borderline/unmatched/failed.
- [ ] Present counts before Apply.
- [ ] High-confidence-only Apply.
- [ ] Borderline review: Apply/Skip/Search again/Stop.
- [ ] Cancel preview with zero writes.

## G. Batch resume/report — #23/#16

- [ ] Persist batch identity/completed files.
- [ ] Recover after Wi-Fi loss/restart.
- [ ] Avoid duplicate writes.
- [ ] Optional refresh-existing mode complements v0.1.3 skip-matched.
- [ ] Save sanitized report: filename/title/source/score/status/error.

## H. Recursive batch — #17

- [ ] Remains off by default.
- [ ] Preview folder/file count.
- [ ] Hard upper bound.
- [ ] Avoid symlink loops.
- [ ] Require discovery preview before recursive writes.

---

# v0.2.1 — Multi-source quality & normalization

## A. Normalized metadata and source merging — #2/#3

- [ ] Provider-independent normalized record.
- [ ] Track field-level provenance.
- [ ] Merge only confidently identical work/edition records.
- [ ] Lower-confidence duplicate cannot overwrite stronger populated field without rule.
- [ ] Global/per-field provider preferences with `Best available` default.

## B. Title/author/role normalization — #7/#40/#41

- [ ] Conservative whitespace/punctuation title cleanup.
- [ ] Safe removal of obvious format labels/repeated series suffixes.
- [ ] `Surname, Given` vs `Given Surname` comparison normalization.
- [ ] Initial/multi-author handling.
- [ ] Separate author/editor/translator/illustrator/narrator roles where exposed.
- [ ] Never replace stored author solely with comparison-normalized text.

## C. Search cache — #19

- [ ] Cache normalized query+provider+relevant settings for short TTL.
- [ ] Do not long-cache auth errors.
- [ ] Keep cooldown state separate.
- [ ] Invalidate on provider/account changes.

## D. Cover quality/chooser — #5/#4

- [ ] Collect cover candidates from deduplicated records.
- [ ] Record dimensions/file size where discoverable.
- [ ] Prefer larger valid edition-compatible covers with sensible ratio.
- [ ] Reject placeholders.
- [ ] Optional source/dimension chooser.
- [ ] `Best automatically` remains simple default.

## E. Description/genre/language normalization — #37/#38/#39

- [ ] Safe HTML/whitespace description cleanup.
- [ ] Deduplicate genre case/punctuation variants and cap excessive subject lists.
- [ ] Expand ISO 639 mappings and locale normalization for matching.
- [ ] Retain raw values in provenance where useful.

## F. Series/additional fields — #8/#36

- [ ] Normalize series names/indexes including decimals.
- [ ] Evaluate publisher/date/identifiers/page count/original title/format against KOReader-native support.
- [ ] Unsupported values remain in provenance rather than being forced into sidecars.

Confidence classes (#43) are already present in v0.1.3 and should be refined, not duplicated.

## G. Search controls/provider priority — #9/#21

- [ ] ISBN only / title+author / title only / cleaned title / choose provider quick actions.
- [ ] Preserve search fields while switching mode.
- [ ] Configurable provider order used only as preference/tie-break, not substitute for evidence.

---

# v0.2.2 — File organization & interoperability

Primary roadmap IDs: #51, #50, #33, #49, #31, #34, #32.

## A. Safe file renaming and library organization — #51

This stays delayed until v0.1.3 undo/provenance has passed real-device testing because it changes filesystem paths and can affect KOReader sidecars/history.

### Rename model

- [ ] Template engine: `{title}`, `{author}`, `{series}`, `{series_index}`, `{year}`, `{isbn}`.
- [ ] Presets: `{title}.epub`.
- [ ] Preset: `{author} - {title}.epub`.
- [ ] Preset: `{series} {series_index} - {title}.epub`.
- [ ] Preset: `{author}/{series}/{series_index} - {title}.epub`.
- [ ] Zero-padding without breaking decimal volumes.
- [ ] Preserve extension.
- [ ] Omit empty template segments cleanly.

### Filename/path safety

- [ ] Sanitize separators/control/reserved/problematic characters.
- [ ] Conservative path/filename length.
- [ ] Normalize repeated whitespace.
- [ ] Never silently overwrite.
- [ ] Detect case-only collisions where relevant.
- [ ] Detect every destination collision before moving anything.

### Preview/confirmation

- [ ] Always show `old path → new path`.
- [ ] Batch preview before operations.
- [ ] Separate collision/invalid rows.
- [ ] Allow deselecting rows.
- [ ] Ordinary metadata fetch never renames unless explicitly enabled.

### KOReader state preservation

- [ ] Prefer KOReader-supported relocation mechanisms.
- [ ] Preserve `.sdr`.
- [ ] Preserve reading progress/history association.
- [ ] Preserve custom metadata.
- [ ] Preserve custom cover.
- [ ] Migrate plugin provenance/book link.
- [ ] Migrate batch/history references.

### Rename transaction/undo

- [ ] Preflight every source/destination.
- [ ] Transaction-like file + sidecar relocation.
- [ ] Record original/destination.
- [ ] `Undo last rename`.
- [ ] Roll back file move if sidecar relocation fails.
- [ ] If rollback fails, surface both paths and never silently delete either copy.

### Folder organization

- [ ] Optional author folder.
- [ ] Optional series folder.
- [ ] Validate before creating directories.
- [ ] Avoid nested duplicate folders.
- [ ] Keep organization rules independent from metadata-write rules.

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
- [ ] Parse series/volume conservatively.
- [ ] Never overwrite good embedded metadata from filename guess.
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
- [ ] Reuse undo/history infrastructure.

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

- [ ] Media-kind abstraction: `ebook`, `audiobook-single`, `audiobook-folder`.
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
- [ ] Detect track/disc numbers.
- [ ] Fall back to parent-folder/filename parsing when tags are absent.
- [ ] If KOReader lacks required tags, research a lightweight compatible parser before adding a heavy dependency.

## D. Multi-track folder detection

- [ ] Group supported audio files only with supporting evidence.
- [ ] Detect sequential track numbering.
- [ ] Verify common album/book title where tags exist.
- [ ] Calculate total duration.
- [ ] Avoid grouping unrelated music solely because it shares a folder.
- [ ] User override `Treat folder as audiobook`.
- [ ] One shared provenance record plus per-track ordering where needed.

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
- [ ] Amazon Creators API audiobook/ASIN data.
- [ ] Google/Open Library work-level fallback usefulness.
- [ ] Research audiobook-specific official/public APIs before adding provider.
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
- [ ] Shared cover location for folder audiobook without rewriting every track.

## I. Audiobook file/folder renaming

Reuse v0.2.2 safe rename engine.

- [ ] `{author} - {title}.m4b`.
- [ ] `{series} {series_index} - {title}.m4b`.
- [ ] `{author}/{series}/{series_index} - {title}/`.
- [ ] Parent folder rename independent from tracks.
- [ ] Preserve track ordering.
- [ ] Optional `{track:02} - {title}.mp3`.
- [ ] No automatic track rename solely because metadata was scraped.
- [ ] Preview every affected path.
- [ ] Undo entire rename set.

## J. Ebook ↔ audiobook linking — later

- [ ] Detect same underlying work.
- [ ] Share work-level title/author/series/genres.
- [ ] Keep cover/narrator/duration/format/identifiers/dates edition-specific.
- [ ] Never assume same title+author means same edition.

## K. Direct audio tag writing — explicitly deferred

Before source-file modification:

- [ ] reliable tag-writing library on KOReader targets;
- [ ] full/tag backup strategy;
- [ ] M4B chapter-preservation tests;
- [ ] MP3 ID3-preservation tests;
- [ ] embedded-cover replacement tests;
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
3. **Provenance + exact-edition model** → refresh, history, multi-source merging, audiobook linking. Provenance core exists in v0.1.3.
4. **Undo/history** → batch automation and safe file renaming. One-step undo exists in v0.1.3; multi-revision history remains later.
5. **Per-book field selection** → safer manual application; implemented in v0.1.3.
6. **Normalized metadata record** → per-field source preferences and audiobook support.
7. **Safe rename transaction** → audiobook folder/track organization.
8. **Cover validation** → cover chooser and audiobook cover workflows. Core validation exists in v0.1.3.
9. **Format/media abstraction** → audiobook support without destabilizing EPUB behavior.

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
