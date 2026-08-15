# Roadmap implementation checklist

This document turns [`ROADMAP.md`](../ROADMAP.md) into release-level engineering work. It is intentionally detailed enough to use during implementation and review.

Checkboxes indicate implementation/release state. A checked item means the work exists on the current development branch or has been verified by an automated test; it does **not** imply that the work is merged into `main` or published unless the release itself is marked complete.

## Global definition of done

Every feature/release should satisfy the following where applicable:

- [ ] Lua syntax validation passes under the supported Lua version.
- [ ] Regression tests cover the new success path.
- [ ] Regression tests cover at least one failure/edge path.
- [ ] Provider/network failures remain isolated from unrelated providers.
- [ ] Credentials, tokens, keys, secrets, authorization headers, and private URLs are redacted from diagnostics.
- [ ] Existing user settings migrate without requiring a reset.
- [ ] Any write/rename/delete operation has an explicit failure strategy.
- [ ] Existing metadata/cover/files are preserved when a replacement operation fails.
- [ ] Batch behavior has a bounded limit and does not silently become recursive/unbounded.
- [ ] UI text is usable on Kindle-size displays and does not require a hardware keyboard.
- [ ] README/changelog/roadmap are updated for user-visible changes.
- [ ] `update.json` matches the runtime file set and release version.
- [ ] Real-device smoke testing is completed before a stable release.

---

# v0.1.3 — Reliability & Matching

Branch: `agent/v0.1.3-reliability-matching`

Goal: establish a stable, diagnosable matching baseline before adding destructive or library-wide functions.

## Implemented on branch

- [x] Central version module (`lib/version.lua`).
- [x] Remove stale provider/About/updater version strings.
- [x] Provider connection diagnostics.
- [x] Hardcover Bearer normalization retained.
- [x] Hardcover Typesense result normalization retained.
- [x] Automatic EPUB ISBN extraction from KOReader identifiers.
- [x] ISBN-10/ISBN-13 checksum validation.
- [x] ISBN-10 → ISBN-13 canonical comparison.
- [x] Cross-provider duplicate collapsing.
- [x] Merge useful missing fields from duplicate provider records.
- [x] Match reasons displayed in result/preview flow.
- [x] Title-only fallback after a strict title+author zero-result search.
- [x] Per-provider zero-result/error reporting.
- [x] Existing custom cover restored if replacement fails.
- [x] Amazon credential-version setting and token endpoint handling.
- [x] Amazon token cache tied to credential identity/endpoint.
- [x] Amazon one-time token refresh/retry after HTTP 401.
- [x] Google 429/Retry-After regression coverage.
- [x] Lua 5.1 syntax CI.
- [x] Regression suite.

## Release gate

Follow [`v0.1.3-testing.md`](v0.1.3-testing.md).

- [ ] Install branch build on a real Kindle/KOReader installation.
- [ ] Confirm plugin loads with no startup error.
- [ ] Confirm About/version is 0.1.3 everywhere user-visible.
- [ ] Test Open Library connection diagnostic.
- [ ] Test Hardcover connection diagnostic with a real token.
- [ ] Test Google Books diagnostic with a real API key.
- [ ] Test Amazon diagnostic if valid Creators API credentials are available.
- [ ] Search `Dungeon Crawler Carl` through Hardcover.
- [ ] Confirm an EPUB with a valid embedded ISBN pre-fills the ISBN field.
- [ ] Confirm an invalid 10/13-digit identifier is not promoted to exact ISBN confidence.
- [ ] Confirm cross-provider duplicates collapse correctly.
- [ ] Confirm provider `+N` source indicator is understandable.
- [ ] Confirm match reasons fit the preview UI.
- [ ] Apply metadata and cover to a test EPUB.
- [ ] Confirm a failed replacement cover preserves the previous custom cover.
- [ ] Run a small batch against known books.
- [ ] Verify existing `metadata_scraper.lua` credentials survive an in-place upgrade.
- [ ] Only after the above: prepare PR/release candidate.

---

# v0.1.4 — Hardening, updater integrity & supportability

Primary roadmap IDs: #48, #26, #46, #47, #24, #27, #25, #22, #30, #20, #29, #28.

## A. Crash/error isolation — #48

- [ ] Introduce a shared provider-call wrapper that converts thrown errors into structured provider failures.
- [ ] Ensure parser failures cannot terminate a multi-provider search.
- [ ] Ensure cover parsing/download errors do not invalidate already-written text metadata.
- [ ] Ensure updater errors cannot corrupt plugin files already on disk.
- [ ] Add tests for malformed JSON, unexpected response types, provider exceptions, and nil fields.
- [ ] Include provider ID, operation, HTTP status, and sanitized error class in diagnostics.

**Acceptance criteria**

- A deliberately broken provider response still allows healthy providers to return results.
- No secret value is included in the surfaced error.
- No plugin restart is required after a recoverable provider failure.

## B. SHA-256 updater verification — #26

- [ ] Extend the manifest format so each runtime file has a SHA-256 digest.
- [ ] Preserve compatibility with old manifests during a transition period or fail with a clear minimum-version message.
- [ ] Download every file into staging before touching the installed plugin.
- [ ] Verify every staged file digest.
- [ ] Abort before installation if any digest mismatches.
- [ ] Keep current backup/rollback behavior after digest verification.
- [ ] Add manifest parser tests for missing, malformed, duplicate, and mismatching hashes.

**Acceptance criteria**

- A modified staged file is rejected before replacement.
- A hash mismatch leaves the installed plugin untouched.
- The updater reports which path failed verification without dumping content.

## C. Updater deletion and settings migrations — #27

- [ ] Add an optional `remove` list to `update.json`.
- [ ] Validate removal paths with the same traversal protections as install paths.
- [ ] Back up files before removal.
- [ ] Restore removed files if a later installation step fails.
- [ ] Add a settings schema version.
- [ ] Add ordered migration functions (`N → N+1`) rather than ad-hoc checks.
- [ ] Test upgrade paths from at least the oldest supported plugin settings format.

## D. Provider diagnostic logging — #46

- [ ] Add a disabled-by-default diagnostic log mode.
- [ ] Record timestamp, plugin version, provider, operation, elapsed time, HTTP status, retry/cooldown state, result count, and response-shape summary.
- [ ] Redact `Authorization`, API keys, secrets, OAuth tokens, partner credentials, and query parameters known to contain secrets.
- [ ] Never write full provider response bodies by default.
- [ ] Add log rotation/size cap.
- [ ] Add `Clear diagnostic log` action.

## E. Sanitized support bundle — #47

- [ ] Add `Copy diagnostics`/`Save diagnostics` action.
- [ ] Include plugin version and KOReader version.
- [ ] Include device/platform string where KOReader safely exposes it.
- [ ] Include enabled providers and selected source scope.
- [ ] Include provider diagnostic status, not credentials.
- [ ] Include recent sanitized provider errors.
- [ ] Include relevant settings such as batch threshold and marketplace, excluding secrets.
- [ ] Include updater status/release channel.
- [ ] Add a final redaction pass and tests using fake secrets.

**Acceptance criteria**

- A fixture containing fake API keys/tokens produces a support bundle with none of the fake secrets present.

## F. Shared transient HTTP resilience — #24

- [ ] Add a common retry policy for transient connection failures.
- [ ] Retry selected `502`, `503`, `504`, socket reset, and timeout cases once by default.
- [ ] Use bounded delay/jitter.
- [ ] Do not blindly retry `400`, `401`, `403`, `404`, or provider-specific quota responses.
- [ ] Preserve provider-specific 429 handling.
- [ ] Surface final attempt count in diagnostics.

## G. Cover validation — #25

- [ ] Validate HTTP success status.
- [ ] Reject zero-byte files.
- [ ] Check content type when available.
- [ ] Detect obvious HTML/JSON error payloads saved as image files.
- [ ] Where practical, validate decodable image dimensions before installation.
- [ ] Reject known placeholder/tiny images below a conservative threshold when alternatives exist.
- [ ] Keep previous cover when validation fails.

## H. Provider rate controls/status — #22 and #20

- [ ] Define provider-specific minimum request intervals for batch operations.
- [ ] Honor provider `Retry-After`/cooldown information.
- [ ] Show `ready`, `cooling down`, `credentials missing`, `auth failed`, or `temporarily unavailable` status.
- [ ] Prevent batch mode from hammering a provider after a quota response.
- [ ] Continue querying healthy providers when one provider is cooling down.

## I. Credential UX — #30

- [ ] Mask saved credentials in the UI.
- [ ] Optionally show only last four characters for identification.
- [ ] Add provider-specific `Test` action next to account configuration where practical.
- [ ] Validate Amazon credential-version value.
- [ ] Never echo secrets back in an error dialog.

## J. Settings backup/reset — #29

- [ ] Add `Reset matching settings`.
- [ ] Add `Reset provider settings` with an explicit warning.
- [ ] Add `Reset all plugin settings`.
- [ ] Consider export without credentials as the default backup mode.
- [ ] If secret export is ever supported, require an explicit warning and separate action.

## K. Stable/prerelease channel — #28

- [ ] Keep Stable as default.
- [ ] Add optional Prerelease/Test channel that only follows GitHub prereleases, not arbitrary `main` commits.
- [ ] Clearly label test releases in update prompts.
- [ ] Allow returning to Stable without a settings reset.

---

# v0.2.0 — Metadata lifecycle, review & undo

Primary roadmap IDs: #6, #12, #1, #14, #42, #10, #44, #23, #15, #13, #11, #18, #16, #45, #17.

## A. Provenance model prerequisite

Before refresh/undo, define a stable record per matched file:

- [ ] canonical file identity/path strategy;
- [ ] provider ID;
- [ ] provider source;
- [ ] ISBN-10/ISBN-13;
- [ ] canonical work/edition key where available;
- [ ] matched title/author/series;
- [ ] match score/confidence class;
- [ ] plugin version;
- [ ] matched timestamp;
- [ ] last refresh timestamp;
- [ ] fields written;
- [ ] cover source/provider;
- [ ] previous-state reference for undo/history.

## B. Exact-edition awareness — #6

- [ ] Add explicit edition-format signals when providers expose them.
- [ ] Distinguish work-level and edition-level IDs.
- [ ] Prefer exact ISBN edition over same-work text matches.
- [ ] Penalize conflicting valid ISBNs.
- [ ] Penalize conflicting language.
- [ ] Penalize audiobook-only result when processing an EPUB if a book edition exists.
- [ ] Consider publication year, publisher, series, and subtitle as secondary evidence.
- [ ] Do not treat same title/author as automatically the same edition.

## C. Confidence safeguards — #42 and explain-score #44

- [ ] Move scoring into explicit positive/negative components.
- [ ] Preserve exact valid ISBN as strongest signal.
- [ ] Add strong negative signals for conflicting identifiers/authors/languages/formats.
- [ ] Add human-readable score breakdown.
- [ ] Add regression fixtures for intentionally ambiguous titles.
- [ ] Verify a title-only exact match cannot become “exact edition” without additional evidence.

## D. Current vs proposed comparison — #10

- [ ] Show current KOReader values beside proposed values.
- [ ] Indicate unchanged, added, replaced, and unavailable fields.
- [ ] Display provider provenance for proposed fields.
- [ ] Keep the display readable on e-ink screens.

## E. Select fields at apply time — #11

- [ ] Start with global field defaults.
- [ ] Allow per-book override before Apply.
- [ ] Include independent `Cover` toggle.
- [ ] Preserve the global defaults after a one-off override unless the user chooses `Save as defaults`.

## F. Undo — #12

- [ ] Snapshot custom metadata before each mutation.
- [ ] Snapshot existing custom cover path/content safely.
- [ ] Add `Undo last metadata update` per book.
- [ ] Restore prior sidecar metadata atomically where possible.
- [ ] Restore prior cover.
- [ ] Record undo success/failure in history.
- [ ] Never discard the only backup before the new write is known-good.

## G. Metadata history — #13

- [ ] Retain a bounded number of revisions per book.
- [ ] Store timestamp, source/provider, score, fields changed, and plugin version.
- [ ] Cap history size to avoid uncontrolled settings growth.
- [ ] Add `View metadata history`.

## H. Refresh exact record — #1

- [ ] Add provider `get_by_id`/detail capability where available.
- [ ] Refresh using saved provider ID before fuzzy search.
- [ ] If provider ID is invalid/stale, offer a new search rather than silently selecting another edition.
- [ ] Add `Refresh metadata`.
- [ ] Add `Refresh cover only`.
- [ ] Show current vs refreshed values before committing if changes are material.

## I. Batch preview — #14

- [ ] Search first; do not write while discovering matches.
- [ ] Group results into high-confidence, borderline, unmatched, and failed.
- [ ] Present counts before applying.
- [ ] Allow applying only the high-confidence group.
- [ ] Allow cancelling with zero writes.
- [ ] Persist enough state to resume review without repeating all searches when practical.

## J. Borderline review — #15

- [ ] Define a default borderline range (for example 70–89) separately from the automatic threshold.
- [ ] Step through candidates one book at a time.
- [ ] Allow `Apply`, `Skip`, `Search again`, and `Stop review`.

## K. Batch resume — #23

- [ ] Persist current batch identity and completed files.
- [ ] Recover after Wi-Fi loss or KOReader restart.
- [ ] Avoid duplicating writes to already-completed books.
- [ ] Add `Discard saved batch`.

## L. Skip already matched — #18

- [ ] Default option to skip books with valid existing plugin provenance.
- [ ] Optional `Refresh previously matched` mode.
- [ ] Future option: refresh only matches older than N days.

## M. Batch summary/export — #16

- [ ] Include filename, selected title, source, score, status, and error.
- [ ] Save a sanitized text/JSON report under plugin cache/export location.
- [ ] Do not include credentials or full API responses.

## N. Threshold presets — #45

- [ ] Strict preset (e.g. 95%).
- [ ] Recommended preset (90%).
- [ ] Permissive preset (80%) with a warning.
- [ ] Preserve custom numeric threshold for advanced users.

## O. Optional recursive batch — #17

- [ ] Remain disabled by default.
- [ ] Explicitly show number of folders/files before starting.
- [ ] Preserve a hard upper bound.
- [ ] Avoid following symlinks or looping directory structures.
- [ ] Require batch preview before any recursive writes.

---

# v0.2.1 — Multi-source quality & normalization

Primary roadmap IDs: #2, #40, #41, #7, #19, #5, #37, #43, #8, #36, #38, #3, #9, #39, #4, #21.

## A. Multi-source metadata merging — #2

- [ ] Introduce a normalized internal metadata record independent of provider payload shape.
- [ ] Track field-level provenance (`title from Hardcover`, `description from Google`, etc.).
- [ ] Merge only records that are confidently the same work/edition.
- [ ] Never use a lower-confidence duplicate to overwrite a stronger non-empty field without a rule.
- [ ] Prefer edition-compatible cover/ISBN/date fields.
- [ ] Expose merge provenance in preview.

## B. Per-field source preference — #3

- [ ] Global source preference order.
- [ ] Optional per-field preferences for title/series/description/genres/cover.
- [ ] `Best available` default.
- [ ] Fallback when preferred provider lacks the field.

## C. Title cleaning — #7

- [ ] Normalize whitespace and punctuation conservatively.
- [ ] Remove obvious format labels such as `[Kindle Edition]` only when safe.
- [ ] Handle repeated series suffixes.
- [ ] Keep original query visible and allow disabling cleanup.
- [ ] Test punctuation-heavy and subtitle-heavy titles.

## D. Author normalization — #40 and roles #41

- [ ] Normalize `Surname, Given` vs `Given Surname` for comparison only.
- [ ] Handle initials conservatively.
- [ ] Handle multiple authors.
- [ ] Separate author from editor/translator/illustrator/narrator roles where providers expose them.
- [ ] Do not overwrite stored author strings solely with normalized comparison strings.

## E. Search cache — #19

- [ ] Cache normalized query + provider + relevant settings.
- [ ] Set short TTL (5–30 minutes).
- [ ] Do not cache authentication failures for long periods.
- [ ] Respect provider cooldown state separately.
- [ ] Add cache invalidation when provider/account settings change.

## F. Cover quality and chooser — #5 and #4

- [ ] Collect candidate cover URLs from deduplicated provider records.
- [ ] Record dimensions/file size where discoverable.
- [ ] Prefer larger valid images with sensible book-cover aspect ratio.
- [ ] Reject placeholders and invalid payloads.
- [ ] Add optional chooser showing source and dimensions.
- [ ] Keep `Best automatically` as a simple default.

## G. Description cleanup — #37

- [ ] Strip/normalize HTML safely.
- [ ] Normalize excessive whitespace.
- [ ] Preserve paragraph boundaries where KOReader supports them.
- [ ] Avoid provider boilerplate when reliably identifiable.
- [ ] Optional maximum-length policy if extremely long descriptions cause UI/sidecar problems.

## H. Confidence classes — #43

- [ ] Map scores/evidence to `Exact`, `Strong`, `Possible`, `Weak`.
- [ ] Do not derive class from numeric score alone when a hard conflict exists.
- [ ] Display class alongside score.

## I. Series intelligence — #8

- [ ] Normalize series names for comparison.
- [ ] Parse integer and decimal series indices.
- [ ] Penalize conflicting series/volume evidence.
- [ ] Prefer provider record with edition-compatible series information.

## J. Additional fields — #36

Evaluate KOReader-native support before storing new fields:

- [ ] publisher;
- [ ] publication date;
- [ ] identifiers/ISBN;
- [ ] page count;
- [ ] original title;
- [ ] edition/format.

Unsupported values may remain in plugin provenance rather than being forced into KOReader custom metadata.

## K. Genre normalization — #38

- [ ] Deduplicate case/punctuation variants.
- [ ] Map a small curated set of obvious synonyms.
- [ ] Cap excessive Open Library subjects.
- [ ] Keep raw provider tags available in provenance for debugging.

## L. Language normalization — #39

- [ ] Expand ISO 639-1/2 mappings.
- [ ] Normalize locale variants (`en-US` → `en` for matching while retaining raw value if useful).
- [ ] Penalize conflicting languages for edition selection.

## M. Quick search controls — #9

- [ ] `ISBN only`.
- [ ] `Title + author`.
- [ ] `Title only`.
- [ ] `Cleaned title`.
- [ ] `Choose provider`.
- [ ] Preserve current search fields while switching modes.

## N. Provider priority — #21

- [ ] Configurable provider order.
- [ ] Use order only as tie-break/preference, not as permission to ignore stronger evidence.
- [ ] Integrate with per-field preferences later.

---

# v0.2.2 — File organization & interoperability

Primary roadmap IDs: #51, #50, #33, #49, #31, #34, #32.

## A. Safe file renaming and library organization — #51

This feature is intentionally delayed until provenance and undo are reliable because it changes filesystem paths and can affect KOReader sidecars/history.

### Rename model

- [ ] Build a template engine with placeholders such as `{title}`, `{author}`, `{series}`, `{series_index}`, `{year}`, `{isbn}`.
- [ ] Ship conservative presets:
  - [ ] `{title}.epub`
  - [ ] `{author} - {title}.epub`
  - [ ] `{series} {series_index} - {title}.epub`
  - [ ] `{author}/{series}/{series_index} - {title}.epub`
- [ ] Support zero-padding (`01`, `02`) without breaking decimal volumes (`3.5`).
- [ ] Preserve the original file extension.
- [ ] Omit empty template segments cleanly.

### Filename/path safety

- [ ] Sanitize separators, control characters, reserved names, trailing dots/spaces, and filesystem-problematic characters.
- [ ] Enforce a conservative path/filename length.
- [ ] Normalize repeated whitespace.
- [ ] Never silently overwrite an existing file.
- [ ] Detect case-only collisions where relevant.
- [ ] Detect destination directory/file collision before moving anything.

### Preview and confirmation

- [ ] Always show `old path → new path` before a manual rename.
- [ ] Batch rename must show a preview list before any operation.
- [ ] Show collision/invalid-name rows separately.
- [ ] Allow deselecting individual rename rows.
- [ ] Default automatic metadata fetch must **not** rename a file unless the user explicitly enables that workflow.

### KOReader sidecar/history preservation

- [ ] Use KOReader-supported location/update mechanisms where possible instead of a blind `os.rename`.
- [ ] Preserve `.sdr` sidecar data.
- [ ] Preserve reading progress/history association.
- [ ] Preserve custom metadata sidecar.
- [ ] Preserve custom cover.
- [ ] Preserve plugin provenance/book link under the new path.
- [ ] Update or migrate any plugin batch/history references to the new path.

### Rename transaction/undo

- [ ] Preflight every source and destination.
- [ ] Perform filesystem move and KOReader sidecar relocation as a transaction-like sequence.
- [ ] Record original path and destination in rename history.
- [ ] Add `Undo last rename`.
- [ ] If sidecar relocation fails after file move, attempt rollback to original path.
- [ ] If rollback also fails, surface both paths clearly and do not delete either copy.

### Folder organization

- [ ] Optional `Move into author folder`.
- [ ] Optional `Move into series folder`.
- [ ] Create directories only after validation.
- [ ] Avoid accidental nested duplicate folders.
- [ ] Keep organization rules independent of metadata-writing rules.

### Batch rename tests

- [ ] duplicate destination filenames;
- [ ] illegal characters;
- [ ] extremely long title;
- [ ] no series metadata;
- [ ] decimal series index;
- [ ] Unicode author/title;
- [ ] already correctly named file;
- [ ] destination on read-only storage;
- [ ] sidecar relocation failure;
- [ ] undo after successful rename.

## B. Filename parser / search bootstrap — #50

- [ ] Parse common `Author - Title` filename patterns.
- [ ] Parse series/volume tokens conservatively.
- [ ] Never overwrite good embedded metadata merely because a filename parser guessed something.
- [ ] Use parsed values as search suggestions/fallbacks.
- [ ] Allow user to review parsed title/author before search.

## C. Calibre compatibility awareness — #33

- [ ] Detect useful Calibre-provided title/authors/series/identifiers where KOReader exposes them.
- [ ] Avoid degrading richer existing metadata.
- [ ] Document behavior with Calibre-generated EPUBs and sidecars.
- [ ] Do not require Calibre to use the plugin.

## D. Offline/manual metadata editor — #49

- [ ] Edit title/authors/series/index/language/keywords/description without network access.
- [ ] Choose/remove a local cover.
- [ ] Use the same undo/history infrastructure as scraped changes.

## E. Provider ID/URL display — #31 and #32

- [ ] Store canonical public URL where available.
- [ ] Show provider ID in advanced preview/diagnostics.
- [ ] Add copy/open action only where KOReader platform support is reliable.
- [ ] Never expose authenticated API URLs containing keys/tokens.

## F. OPF import/export — #34

- [ ] Define which metadata fields map cleanly to OPF.
- [ ] Export without modifying the EPUB.
- [ ] Import into KOReader custom metadata with preview.
- [ ] Preserve provenance indicating OPF/manual source.
- [ ] Avoid clobbering richer data without confirmation.

---

# v0.3.0 — Audiobook metadata support

Primary roadmap ID: #52.

Audiobooks require a format/edition model rather than an `isEpub()` extension check. The first audiobook milestone should focus on discovery, matching, metadata sidecars/provenance, covers, and safe organization—not playback or destructive media-tag writes.

## A. Architecture

- [ ] Replace EPUB-only assumptions with a media-kind abstraction: `ebook`, `audiobook-single`, `audiobook-folder`.
- [ ] Keep ebook behavior unchanged behind the abstraction.
- [ ] Add format capability checks rather than scattering extension checks through the UI.
- [ ] Define normalized `BookWork` and `Edition` concepts.
- [ ] Define audiobook-specific fields: narrator, duration, abridged state, audio format, track count.
- [ ] Keep provider-specific raw payloads isolated in provider modules.

## B. Supported formats — first milestone

- [ ] `.m4b` single-file audiobook.
- [ ] `.mp3` single-file audiobook.
- [ ] `.m4a` single-file audiobook.
- [ ] `.ogg`/`.opus` investigated and enabled only if metadata handling is reliable.
- [ ] Multi-track audiobook folder containing sequential audio files.

## C. Local metadata discovery

- [ ] Read title/author/album/series-equivalent tags where available without modifying the file.
- [ ] Read narrator/performer where available.
- [ ] Read duration.
- [ ] Read embedded identifiers/ASIN/ISBN where available.
- [ ] Read embedded cover/artwork where accessible.
- [ ] Detect track number/disc number for folder grouping.
- [ ] Fall back to parent-folder/filename parsing when tags are absent.

If KOReader itself does not expose the required audio tags, research a lightweight compatible parser/library before adding a heavy dependency.

## D. Multi-track folder detection

Treat a folder as one audiobook when evidence supports it.

- [ ] Group supported audio files in one directory.
- [ ] Detect sequential track numbering.
- [ ] Verify common album/book title where tags exist.
- [ ] Calculate total duration.
- [ ] Avoid grouping unrelated music/audio files solely because they share a folder.
- [ ] Allow user to override `Treat folder as audiobook`.
- [ ] Store one shared provenance record for the audiobook plus per-track ordering if needed.

## E. Audiobook matching

Audiobook ranking should not reuse ebook scoring unchanged.

Positive signals:

- [ ] exact audiobook ASIN/provider ID;
- [ ] exact valid ISBN when edition-appropriate;
- [ ] exact title;
- [ ] author match;
- [ ] narrator match;
- [ ] duration within a tolerance;
- [ ] language;
- [ ] series and volume;
- [ ] audio format/edition label;
- [ ] abridged/unabridged state.

Negative signals:

- [ ] conflicting narrator when narrator is known;
- [ ] materially different duration;
- [ ] conflicting language;
- [ ] ebook/paperback-only edition when an audiobook edition is expected;
- [ ] dramatized/full-cast edition mismatch;
- [ ] abridged/unabridged conflict.

## F. Provider work for audiobooks

- [ ] Audit Hardcover audiobook/edition fields.
- [ ] Audit Amazon Creators API data available for audiobook/ASIN searches.
- [ ] Audit Google Books/Open Library usefulness for work-level fallback only.
- [ ] Research audiobook-specific public/official APIs before adding another provider.
- [ ] Keep provider eligibility/terms documented.
- [ ] Add audiobook response fixtures to regression tests.

## G. Audiobook metadata fields

Initial normalized fields:

- [ ] title;
- [ ] author(s);
- [ ] narrator(s);
- [ ] series;
- [ ] series index;
- [ ] language;
- [ ] publisher;
- [ ] publication/release date;
- [ ] description;
- [ ] genres;
- [ ] ISBN/ASIN/provider IDs;
- [ ] duration;
- [ ] abridged/unabridged state;
- [ ] cover;
- [ ] track count for folders.

## H. Audiobook cover workflow

- [ ] Prefer edition-compatible audiobook cover over ebook cover.
- [ ] Show source/provider.
- [ ] Validate image as in v0.1.4 cover pipeline.
- [ ] Preserve existing cover on failure.
- [ ] For folder audiobooks, define a shared cover location without modifying every track.

## I. Audiobook file/folder renaming

Reuse the safe rename engine from v0.2.2.

Suggested templates:

- [ ] `{author} - {title}.m4b`
- [ ] `{series} {series_index} - {title}.m4b`
- [ ] `{author}/{series}/{series_index} - {title}/`

For multi-track folders:

- [ ] rename parent folder independently from tracks;
- [ ] preserve original track ordering;
- [ ] optional track template such as `{track:02} - {title}.mp3`;
- [ ] do not rename tracks automatically merely because parent folder metadata was scraped;
- [ ] preview every affected path before commit;
- [ ] support undo across the entire rename set.

## J. Ebook ↔ audiobook linking — later sub-milestone

- [ ] Detect same underlying work across EPUB and audiobook records.
- [ ] Share work-level title/author/series/genres.
- [ ] Keep edition-specific cover, narrator, duration, format, identifiers, and dates separate.
- [ ] Never assume same title+author means same edition.

## K. Direct audio tag writing — explicitly deferred

Do not include in the first audiobook release.

Before enabling any source-file modification:

- [ ] establish reliable tag-writing library support on KOReader targets;
- [ ] create full-file or tag-level backup strategy;
- [ ] test M4B chapter preservation;
- [ ] test MP3 ID3 preservation;
- [ ] test embedded cover replacement;
- [ ] provide explicit opt-in confirmation;
- [ ] provide rollback on failure;
- [ ] ensure normal metadata scraping remains non-destructive by default.

## L. Playback integration — optional/later

Audiobook metadata support does not require the plugin to become an audiobook player.

- [ ] First determine whether KOReader or a supported external player exposes a stable integration surface.
- [ ] Keep playback state separate from metadata scraping unless a reliable integration exists.

---

# Later / experimental

## Optional EPUB write-back — #35

The current project principle is that EPUB files are not rewritten. If direct write-back is ever implemented:

- [ ] keep it disabled by default;
- [ ] create a backup first;
- [ ] edit OPF metadata without damaging manifest/spine/navigation;
- [ ] preserve DRM-free EPUB validity;
- [ ] validate the resulting ZIP/container;
- [ ] provide explicit user confirmation and undo/restore;
- [ ] never mix write-back silently into the normal `Apply` action.

---

# Dependency map

High-level dependencies that should influence implementation order even when roadmap scores differ:

1. **Diagnostics/error isolation** → safer provider expansion and easier field testing.
2. **Updater hashes/migrations** → safer future release complexity.
3. **Provenance + exact-edition model** → refresh, history, multi-source merging, audiobook linking.
4. **Undo/history** → batch preview automation and safe file renaming.
5. **Normalized metadata record** → per-field source preferences and audiobook support.
6. **Safe rename transaction** → audiobook folder/track organization.
7. **Cover validation** → cover chooser and audiobook cover workflows.
8. **Format/media abstraction** → audiobook support without destabilizing EPUB behavior.

# Re-scoring policy

Update the scores in `ROADMAP.md` when one of the following occurs:

- a real bug demonstrates higher/lower risk than assumed;
- a provider/API change alters implementation complexity;
- usage/issue data shows that a feature affects substantially more/fewer users;
- a prerequisite is completed and makes another feature materially easier;
- KOReader adds/removes a native capability that changes feasibility;
- a proposed feature creates new source-file or privacy risk.

When scores tie, prefer the item with, in order:

1. higher Risk Reduction;
2. higher User Impact;
3. higher Architectural Leverage;
4. lower implementation risk/dependency count;
5. smaller bounded implementation size.
