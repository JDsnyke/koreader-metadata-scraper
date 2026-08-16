# Roadmap implementation checklist

This document turns [`ROADMAP.md`](../ROADMAP.md) into release-level engineering work. A checked item means it is implemented on the current development branch or covered by an automated check; it does **not** by itself mean the feature has been published.

## Global definition of done

For each release/feature where applicable:

- [ ] Supported Lua syntax/lint checks pass.
- [ ] Success and failure/edge regressions exist.
- [ ] Provider/network failures remain isolated.
- [ ] Credentials and query secrets are redacted from diagnostics.
- [ ] Existing settings migrate/load without requiring reset.
- [ ] Replacement/write operations have an explicit failure strategy.
- [ ] Existing metadata/cover/files are preserved when replacement fails.
- [ ] Batch behavior remains bounded and non-recursive unless explicitly approved.
- [ ] Destructive path/file operations have preview, collision protection, and rollback.
- [ ] User-facing docs and changelog match actual behavior.
- [ ] `update.json` matches the runtime file set/version.
- [ ] Release hashes are generated from the frozen runtime tree.
- [ ] Exact release artifact is validated before publishing.
- [ ] Real-device smoke testing is completed before stable release publication.

---

# v0.1.3 — Reliability, Matching, Hardening & Lifecycle Safety

Branch: `agent/v0.1.3-reliability-matching`

## A. Versioning and provider baseline

- [x] Central version module (`lib/version.lua`).
- [x] Remove stale provider/About/updater version strings.
- [x] Provider connection diagnostics.
- [x] Non-network provider readiness/status hooks.
- [x] Hardcover Bearer normalization.
- [x] Hardcover Typesense result normalization.
- [x] Google 429/Retry-After cooldown.
- [x] Amazon credential-version (`3.1/3.2/3.3`) token endpoints.
- [x] Amazon token cache tied to credential identity/endpoint.
- [x] Amazon one-time refresh after HTTP 401.

## B. Metadata identity and discovery

- [x] Automatic EPUB ISBN extraction from KOReader identifiers.
- [x] ISBN-10/ISBN-13 checksum validation.
- [x] ISBN-10 → ISBN-13 canonical comparison.
- [x] Cross-provider duplicate collapsing.
- [x] Merge useful missing fields from duplicate provider records.
- [x] One title-only fallback after title+author zero-result search.
- [x] Per-provider zero-result/error reporting.
- [x] Provider ID and canonical ISBN provenance.

## C. Confidence, conflicts, edition awareness — #42/#43/#44/#6

- [x] Exact valid ISBN remains strongest positive evidence when format is compatible/unknown.
- [x] Conflicting valid ISBN is capped far below automatic threshold.
- [x] Strong author conflict reduces confidence.
- [x] Language conflict reduces confidence.
- [x] Series conflict reduces confidence.
- [x] Material year conflict reduces confidence.
- [x] Human-readable match/conflict reasons.
- [x] `Exact`, `Strong`, `Possible`, `Weak` confidence classes.
- [x] EPUB queries carry explicit `media_kind = ebook`.
- [x] Classify explicit provider ebook/print/audiobook hints conservatively.
- [x] Known audiobook result for EPUB capped at ≤35%.
- [x] Known print result for EPUB capped at ≤65%.
- [x] Explicit format conflict downgrades even matching ISBN to manual review.
- [x] Unknown provider format remains neutral.
- [x] Compatible known ebook format can add `format match` evidence.
- [x] Show Format/Edition when available.
- [x] Persist known format/binding/edition/media kind in provenance.
- [x] Amazon parses Binding/Edition when returned.
- [x] Hardcover opportunistically consumes existing search-document format/edition hints without requiring them.
- [ ] Canonical provider work-vs-edition IDs — v0.2.0.
- [ ] Provider-specific edition detail retrieval — v0.2.0.
- [ ] Numeric positive/negative score-component breakdown — v0.2.0.

## D. Author comparison normalization — #40 core

- [x] Comparison-only normalization separate from displayed/stored author values.
- [x] `Dinniman, Matt` can compare with `Matt Dinniman`.
- [x] Punctuation/order variants use canonical token comparison.
- [x] Multiple-author punctuation/order test fixture.
- [x] Genuinely unrelated authors still produce conflict evidence.
- [ ] Preserve/compare structured individual author identities when providers expose them — v0.2.1.
- [ ] Separate author/editor/translator/illustrator/narrator roles — v0.2.1/v0.3.0.

## E. Current → Proposed and per-book Apply controls — #10/#11

- [x] Calculate fields that would actually change.
- [x] Show Current → Proposed values for bounded fields.
- [x] Represent long descriptions as add/replace actions.
- [x] Treat no-text/no-cover change as a no-op.
- [x] **Choose fields for this book…**.
- [x] One-off selection starts from global defaults.
- [x] One-off text-field toggles.
- [x] Independent one-off Cover toggle.
- [x] **Apply selected** passes temporary settings only.
- [x] One-off choices do not mutate global defaults.
- [x] Normal Apply still uses global defaults.
- [ ] Field-level source provenance in comparison — v0.2.x.

## F. One-step undo and provenance — #12/#13/#1 groundwork

- [x] Snapshot exact pre-apply custom-metadata bytes.
- [x] Snapshot exact pre-apply custom-cover bytes.
- [x] Refuse mutation if snapshot cannot be created.
- [x] Remove newly-created override on undo when none existed previously.
- [x] Restore prior custom metadata and cover.
- [x] Restore prior Metadata Scraper provenance.
- [x] Persist undo record across restart.
- [x] One undo point per book.
- [x] Bound overall undo set to 20 books.
- [x] Collision-check undo backup names.
- [x] Reject snapshot belonging to another book.
- [x] Save source/ID/ISBN/title/authors/series/language/date/publisher.
- [x] Save format/binding/edition/media kind when known.
- [x] Save score/confidence/reasons/query/fields/cover/plugin version/timestamp.
- [x] Add **Last match details**.
- [x] Cover-only successful change can be undone.
- [ ] Multi-revision history — v0.2.0.
- [ ] Direct exact provider-record refresh — v0.2.0.

## G. Two-phase batch safety — #14/#18/#45

- [x] Current folder only.
- [x] Non-recursive.
- [x] Existing maximum file count preserved.
- [x] Strict 95 / Recommended 90 / Permissive 80 presets.
- [x] Recommended 90 remains default.
- [x] Skip already matched enabled by default.
- [x] Skip matched files before provider requests.
- [x] **Discovery phase performs no metadata/cover writes.**
- [x] Discovery builds in-memory plan only.
- [x] Summary separates Ready / Low-or-no match / Already matched / Search failures.
- [x] Second explicit Apply confirmation required.
- [x] Cancel after discovery causes zero writes.
- [x] Apply phase processes only planned high-confidence entries.
- [x] Final summary separates search vs apply failures.
- [x] Applied batch books retain undo/provenance.
- [ ] Per-row preview/deselect — v0.2.0.
- [ ] Borderline interactive review — v0.2.0.
- [ ] Rich per-book saved report — v0.2.0.
- [ ] Resume interrupted discovery/apply — v0.2.0.

## H. Crash/error isolation — #48 core

- [x] Provider calls protected.
- [x] Malformed provider result discarded rather than crashing valid results.
- [x] KOReader metadata-read exceptions become controlled outcomes.
- [x] Metadata-write exceptions become controlled failures.
- [x] Cover-write exceptions become controlled failures.
- [x] Updater verifies/stages before mutation and retains rollback.
- [ ] Consolidate remaining wrappers if device testing identifies duplicated failure paths — v0.1.4.

## I. Shared HTTP resilience — #24 core

- [x] One retry for GET/HEAD network failure.
- [x] One retry for HTTP 502/503/504.
- [x] Downloads use same cautious retry model.
- [x] Ordinary POST is not generically duplicated.
- [x] Generic layer does not blindly retry 429.
- [x] Provider-specific cooldown remains authoritative.
- [x] Retry/failure events enter sanitized diagnostics.
- [x] Failed download handles close before cleanup.
- [ ] Provider-specific batch pacing — v0.1.4.

## J. Cover validation and rollback — #25 core

- [x] Validate downloaded file readability.
- [x] Reject implausibly tiny payloads.
- [x] Reject known non-image Content-Type where available.
- [x] Validate JPEG/PNG/WebP binary signatures.
- [x] Validate before touching current custom cover.
- [x] Back up/restore current cover if replacement fails.
- [ ] Decoded dimension/aspect-ratio checks — v0.2.1.
- [ ] Placeholder scoring across candidate covers — v0.2.1.

## K. Diagnostics and provider readiness — #46/#47/#30/#20 core

- [x] Bounded in-memory sanitized event buffer.
- [x] HTTP URLs logged without query values.
- [x] Record provider/search/updater/metadata/cover failures.
- [x] Redact Hardcover token.
- [x] Redact Google API key.
- [x] Redact Amazon Credential ID/secret/Partner Tag.
- [x] Pattern-redact Bearer/common secret forms.
- [x] Generate support bundle without credential values.
- [x] Add **Save support diagnostics…**.
- [x] Provider `status()` hooks do not make a network call simply to render UI.
- [x] Google exposes active cooldown.
- [x] Amazon exposes cached-token readiness.
- [ ] Persist/rotate diagnostics across restarts — v0.1.4.
- [ ] Richer safe device/KOReader runtime metadata — v0.1.4.

## L. SHA-256 updater integrity — #26

- [x] Use KOReader `ffi/sha2`.
- [x] `sha256` path→digest manifest design.
- [x] Require valid digest for every runtime payload except control `update.json`.
- [x] Stage fetched control manifest exactly once.
- [x] Verify each runtime file after download.
- [x] Abort before installed files are touched on missing/malformed/mismatched digest.
- [x] Re-verify staged files immediately before apply.
- [x] Keep backup/rollback after verification.
- [x] `scripts/generate_update_manifest.py`.
- [ ] Freeze final runtime tree.
- [ ] Generate final v0.1.3 manifest hashes.
- [ ] Run manifest `--check` successfully.

## M. Automated regression suites

- [x] `tests/run.lua` — core/provider regressions.
- [x] `tests/hardening.lua` — retry/image/writer/malformed-result isolation.
- [x] `tests/diagnostics.lua` — redaction/support bundle.
- [x] `tests/matcher_safety.lua` — conflict/confidence/author/format behavior.
- [x] `tests/edition_batch.lua` — media-kind/batch gate/Amazon edition extraction.
- [x] `tests/updater_integrity.lua` — SHA-256 updater behavior.
- [x] `tests/lifecycle.lua` — Current→Proposed and exact-byte undo.
- [x] Lua 5.1 syntax check for every `.lua` file.
- [ ] Exact final branch head green after docs/build changes.
- [ ] Exact merged `main` head green.

## N. v0.1.3 release gate

Follow [`v0.1.3-testing.md`](v0.1.3-testing.md).

Automated gate before merge:

- [ ] Lint/static checks green.
- [ ] Deterministic release build succeeds.
- [ ] Release ZIP layout validated.
- [ ] Code review completed with findings fixed.
- [ ] Full regression suite green.
- [ ] Final manifest hashes generated/verified.

Device gate before stable Release publication:

- [ ] Plugin loads on target KOReader.
- [ ] Hardcover regression confirmed.
- [ ] Provider diagnostics/status confirmed.
- [ ] ISBN extraction and confidence sampled.
- [ ] Edition-format conflict behavior sampled.
- [ ] Current→Proposed and per-book selection sampled.
- [ ] Undo works across restart.
- [ ] Support diagnostics reviewed for real secrets.
- [ ] Two-phase batch discovery verified to write nothing before second confirmation.
- [ ] Small batch apply completed.

---

# v0.1.4 — Remaining hardening & supportability

## A. Updater deletion and settings migrations — #27

- [ ] Optional validated `remove` list.
- [ ] Back up removed files before removal.
- [ ] Restore removed files on later failure.
- [ ] Settings schema version.
- [ ] Ordered migration functions.
- [ ] Regression paths from oldest supported settings format.

## B. Provider pacing/status depth — #22/#20

- [ ] Provider-specific minimum request intervals for larger batches.
- [ ] Honor Retry-After/cooldown consistently.
- [ ] Continue healthy providers while another is cooling down.
- [ ] Optional persisted last health/test state.

## C. Persistent diagnostics — #46/#47

- [ ] Bounded persistence model.
- [ ] Timestamp/provider/operation/elapsed/status/result-count metadata.
- [ ] Never persist full provider response bodies by default.
- [ ] Rotation/size cap.
- [ ] Clear log action.
- [ ] Re-redact on export.

## D. Credential UX — #30

- [ ] Mask saved credential identifiers where practical.
- [ ] Validate Amazon credential-version input before save.
- [ ] Never echo secret values in errors.

## E. Settings backup/reset — #29

- [ ] Reset matching settings.
- [ ] Reset provider settings with warning.
- [ ] Reset all plugin settings.
- [ ] Credential-free configuration export by default if backup/export is added.

## F. Stable/prerelease channel — #28

- [ ] Stable remains default.
- [ ] Optional test channel follows published prereleases only, never arbitrary `main`.
- [ ] Clearly label test updates.
- [ ] Easy return to Stable.

---

# v0.2.0 — Metadata lifecycle, interactive review & refresh

## A. Canonical work/edition identity — deeper #6

- [ ] Distinguish provider work-level and edition-level IDs.
- [ ] Prefer exact edition ID/ISBN over same-work text matches.
- [ ] Provider detail retrieval where stable.
- [ ] Keep unknown format neutral.
- [ ] Extend explicit conflict evidence as providers expose reliable edition data.

## B. Exact-record refresh — #1

- [ ] Provider `get_by_id`/detail capability where feasible.
- [ ] Refresh saved provider record before fuzzy search.
- [ ] Stale provider ID offers new search rather than silently selecting another edition.
- [ ] **Refresh metadata**.
- [ ] **Refresh cover only**.
- [ ] Current→Proposed preview before refresh write.

## C. Explainable score components — #42/#44

- [ ] Explicit positive/negative component structure.
- [ ] Human-readable numeric breakdown.
- [ ] Ambiguous-title fixtures.
- [ ] Hard conflicts always override misleading aggregate score/class.

## D. Interactive batch review — deeper #14/#15

- [ ] Keep discovery phase write-free.
- [ ] List proposed entries individually.
- [ ] Allow deselecting a ready row.
- [ ] Borderline Apply/Skip/Search again/Stop flow.
- [ ] Cancel review with zero writes.
- [ ] Preserve two-phase summary as simple/default path.

## E. Resume/report/history — #23/#16/#13

- [ ] Persist batch identity/completed entries safely.
- [ ] Recover after restart/network loss without duplicate writes.
- [ ] Save sanitized per-book batch report.
- [ ] Bounded multi-revision metadata history beyond one-step undo.

## F. Recursive batch — #17

- [ ] Off by default.
- [ ] Preview folder/file count.
- [ ] Hard upper bound.
- [ ] Avoid symlink loops.
- [ ] Require preview before recursive writes.

---

# v0.2.1 — Multi-source quality & normalization

## A. Normalized metadata/source merging — #2/#3

- [ ] Provider-independent normalized record.
- [ ] Field-level provenance.
- [ ] Merge only confidently identical work/edition records.
- [ ] Lower-confidence duplicate cannot silently overwrite stronger populated data.
- [ ] Per-field provider preferences with `Best available` default.

## B. Title/author/role normalization — #7/#40/#41

- [x] v0.1.3 comparison-only author token normalization foundation.
- [ ] Structured individual-author comparison.
- [ ] `Surname, Given` vs `Given Surname` without losing multi-author boundaries when structured data exists.
- [ ] Middle-initial/diacritic policy.
- [ ] Conservative title cleanup.
- [ ] Separate author/editor/translator/illustrator/narrator roles.
- [ ] Never rewrite stored author solely from comparison normalization.

## C. Search cache — #19

- [ ] Cache normalized query+provider+relevant settings for short TTL.
- [ ] Do not long-cache auth errors.
- [ ] Keep cooldown state separate.
- [ ] Invalidate when account settings change.

## D. Cover quality/chooser — #5/#4

- [ ] Collect cover candidates from deduplicated results.
- [ ] Dimension/file-size/aspect-ratio evidence.
- [ ] Reject placeholders.
- [ ] Optional source/dimension chooser.
- [ ] Best-automatically default.

## E. Description/genre/language/series — #37/#38/#39/#8

- [ ] Safe description HTML/whitespace cleanup.
- [ ] Genre dedupe/normalization and subject cap.
- [ ] Expanded ISO language mappings/locale variants.
- [ ] Series-name/index normalization including decimals.

---

# v0.2.2 — File organization & interoperability

## A. Safe file renaming/library organization — #51

This is intentionally delayed until provenance and undo have real-device evidence because path changes can affect KOReader sidecars/history.

### Template engine

- [ ] `{title}`, `{author}`, `{series}`, `{series_index}`, `{year}`, `{isbn}`.
- [ ] Presets: `{title}.epub`, `{author} - {title}.epub`, `{series} {series_index} - {title}.epub`.
- [ ] Optional `{author}/{series}/{series_index} - {title}.epub` organization.
- [ ] Zero-padding without breaking decimal volumes.
- [ ] Preserve original extension.
- [ ] Omit empty segments cleanly.

### Path safety

- [ ] Sanitize separators/control/reserved characters.
- [ ] Conservative filename/path length.
- [ ] Normalize repeated whitespace.
- [ ] Detect destination collisions before moving anything.
- [ ] Detect case-only collisions.
- [ ] Never silently overwrite.

### Preview

- [ ] Always show `old path → new path`.
- [ ] Batch preview before file operations.
- [ ] Separate collision/invalid rows.
- [ ] Allow deselecting rows.
- [ ] Normal metadata Apply never renames unless explicitly requested.

### KOReader preservation

- [ ] Use KOReader-supported relocation mechanisms where available.
- [ ] Preserve `.sdr`, reading progress/history, custom metadata, and custom cover.
- [ ] Migrate plugin provenance/undo/history references.

### Transaction and undo

- [ ] Preflight every source/destination.
- [ ] Transaction-like file+sidecar relocation.
- [ ] Record original/destination paths.
- [ ] **Undo last rename**.
- [ ] Roll back file move if sidecar relocation fails.
- [ ] If rollback fails, surface both paths and never delete either copy silently.

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
- [ ] Never overwrite good embedded metadata from filename guess.
- [ ] Use parsed values as suggestions/fallbacks.

## C. Calibre compatibility — #33

- [ ] Detect useful Calibre title/authors/series/identifiers where KOReader exposes them.
- [ ] Avoid degrading richer existing metadata.
- [ ] Document Calibre-generated EPUB/sidecar behavior.
- [ ] Do not require Calibre.

## D. Offline/manual editor — #49

- [ ] Edit title/authors/series/index/language/keywords/description offline.
- [ ] Choose/remove local cover.
- [ ] Reuse undo/history infrastructure.

## E. OPF/provider links — #31/#32/#34

- [ ] Store canonical public provider URL where available.
- [ ] Never expose authenticated URLs/tokens.
- [ ] OPF export without EPUB modification.
- [ ] OPF import into KOReader custom metadata with preview/undo.

---

# v0.3.0 — Audiobook metadata support — #52

Audiobooks require a first-class media/edition model. v0.1.3's ability to identify an audiobook result is only an EPUB safety safeguard.

## A. Architecture

- [ ] Media kinds: `ebook`, `audiobook-single`, `audiobook-folder`.
- [ ] Keep existing ebook behavior unchanged behind abstraction.
- [ ] Capability checks instead of scattered extension checks.
- [ ] Normalized BookWork/Edition concepts.
- [ ] Audiobook fields: narrator, duration, abridged state, format, track count.

## B. Initial formats

- [ ] `.m4b`.
- [ ] `.mp3`.
- [ ] `.m4a`.
- [ ] Investigate `.ogg`/`.opus` only if metadata handling is dependable.
- [ ] Multi-track audiobook folder.

## C. Local discovery

- [ ] Read title/author/album/series-equivalent tags without modification.
- [ ] Read narrator/performer.
- [ ] Read duration.
- [ ] Read embedded identifiers/ASIN/ISBN.
- [ ] Read embedded cover where accessible.
- [ ] Detect track/disc number.
- [ ] Folder/filename fallback when tags absent.

## D. Multi-track grouping

- [ ] Group supported audio files only with supporting evidence.
- [ ] Detect track numbering/common album title.
- [ ] Calculate total duration.
- [ ] Avoid grouping unrelated music solely by shared folder.
- [ ] User override: **Treat folder as audiobook**.
- [ ] One shared provenance record plus track order.

## E. Audiobook matching

Positive signals:

- [ ] exact audiobook ASIN/provider ID;
- [ ] edition-appropriate ISBN;
- [ ] title/author;
- [ ] narrator;
- [ ] duration tolerance;
- [ ] language;
- [ ] series/volume;
- [ ] audio format/edition;
- [ ] abridged/unabridged state.

Negative signals:

- [ ] conflicting narrator;
- [ ] materially different duration;
- [ ] conflicting language;
- [ ] ebook/print-only edition when audiobook expected;
- [ ] dramatized/full-cast mismatch;
- [ ] abridged/unabridged conflict.

## F. Provider audit

- [ ] Hardcover audiobook/edition fields.
- [ ] Amazon audiobook/ASIN data.
- [ ] Google/Open Library work-level fallback usefulness.
- [ ] Research audiobook-specific official/public APIs before adding a provider.
- [ ] Add response fixtures.

## G. Audiobook cover and organization

- [ ] Reuse validated cover pipeline.
- [ ] Prefer edition-compatible audiobook cover.
- [ ] Shared cover strategy for folder audiobook.
- [ ] Reuse safe rename transaction from v0.2.2.
- [ ] `{author} - {title}.m4b`.
- [ ] `{series} {series_index} - {title}.m4b`.
- [ ] Folder template with preserved track order.
- [ ] Preview every affected path and undo entire rename set.

## H. Ebook ↔ audiobook linking — later sub-milestone

- [ ] Detect same underlying work.
- [ ] Share work-level title/author/series/genres.
- [ ] Keep cover/narrator/duration/format/identifiers edition-specific.
- [ ] Never assume same title+author means same edition.

## I. Direct audio tag writing — explicitly deferred

Before modifying source audio:

- [ ] reliable tag-writing library on KOReader targets;
- [ ] backup strategy;
- [ ] M4B chapter-preservation tests;
- [ ] MP3 ID3-preservation tests;
- [ ] embedded-cover replacement tests;
- [ ] explicit opt-in confirmation;
- [ ] rollback on failure;
- [ ] normal scrape remains non-destructive default.

---

# Later / experimental

## Optional EPUB write-back — #35

- [ ] Disabled by default.
- [ ] Backup first.
- [ ] Preserve manifest/spine/navigation.
- [ ] Validate resulting EPUB container.
- [ ] Explicit confirmation and restore.
- [ ] Never mix source write-back into normal Apply.

# Dependency map

1. Diagnostics/error isolation → safer provider expansion and support.
2. Updater integrity/migrations → safer complex releases.
3. Provenance + canonical edition identity → exact refresh/history/source merging/audiobook linking.
4. Undo/history → safe batch automation and file renaming.
5. Normalized metadata record → field-level source preferences and audiobook support.
6. Safe rename transaction → audiobook folder/track organization.
7. Cover validation → cover chooser and audiobook covers.
8. Media abstraction → audiobook support without destabilizing EPUB behavior.

# Re-scoring policy

Update `ROADMAP.md` scores when real bugs, API changes, usage evidence, prerequisite completion, KOReader capability changes, or new privacy/source-file risks materially change impact/risk/effort.

When scores tie, prefer:

1. higher Risk Reduction;
2. higher User Impact;
3. higher Architectural Leverage;
4. lower dependency/risk count;
5. smaller bounded implementation size.
