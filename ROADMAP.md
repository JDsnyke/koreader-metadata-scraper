# Roadmap

This is the planning source of truth for Metadata Scraper for KOReader. It is intentionally broader than any single release and includes metadata lifecycle, matching, batch workflows, provider quality, file organization, interoperability, and audiobook support.

GitHub Releases is authoritative for whether a version has actually been published. `CHANGELOG.md` is authoritative for shipped release notes. This roadmap is authoritative for what is still incomplete.

## Status model

Use these terms consistently:

- **Shipped** — implemented, tested/documented, and included in a published stable release.
- **Implemented / release-ready** — code is complete and covered by automated checks, but publication may still be in progress.
- **Partial** — a bounded core/subset is implemented; the remaining scope is still explicitly listed.
- **Pending** — not implemented.

Do not mark an entire roadmap item complete because a prerequisite or narrow subset exists.

## Current release-line audit

### v0.1.3

Published on **2026-08-16**. It established the reliability/matching/lifecycle baseline: ISBN canonicalization, confidence/conflict safeguards, edition-format safety, Current → Proposed preview, one-step Undo, two-phase batch discovery/apply, diagnostics, cover validation, cautious HTTP retries, and SHA-256 updater verification.

### v0.1.4

The v0.1.4 implementation has been merged into the release line and adds the remaining hardening tranche plus several bounded v0.2.0 foundations. Publication state should be checked in GitHub Releases rather than inferred from this file.

Implemented/release-ready in the v0.1.4 code line:

- **#27 Updater deletion/migration support** — validated `remove` paths, backup/rollback, settings schema/migrations.
- **#22 Provider rate controls** — conservative batch pacing plus provider-local cooldown/Retry-After handling.
- **#20 Provider status depth** — persisted last provider test/health state in addition to v0.1.3 readiness UI.
- **#30 Credential UX** — masking/validation improvements and redacted user-visible failure paths.
- **#29 Settings backup/reset tooling** — credential-free export plus matching/provider/all-settings reset actions.
- **#28 Stable/Test update channels** — Stable default; Test follows published prereleases only.
- **#46 Persistent diagnostics** — bounded/rotated sanitized persistence with timing/status/result-count metadata.
- **#47 Support diagnostics expansion** — richer safe runtime/device metadata in exported support bundles.
- **#44 Explain-score details** — structured positive/negative/cap components and numeric breakdown in bounded evidence UI/provenance.
- **#13 Metadata history core** — bounded multi-revision Undo history with repeated Undo through retained revisions.
- **#14 Interactive batch review core** — write-free ready-row review/deselection before Apply.
- **#1 Exact-record refresh core** — saved Google Books volume-ID metadata/cover refresh without fuzzy fallback.
- **#48 Additional hardening** — document-handle cleanup, safer preview isolation, historical snapshot cleanup, provenance v2, and runtime-state resets.
- **ZenPM repository support** — static catalog tree and GitHub Pages deployment workflow.

Still intentionally **partial** after v0.1.4:

- **#1 Refresh previously matched metadata** — Google Books exact saved-record refresh exists; broader providers remain pending.
- **#6 Exact-edition awareness** — ISBN/media-kind/format safeguards exist; canonical provider work-vs-edition identity remains pending.
- **#14/#15 Batch review** — ready rows can be deselected; full borderline Apply/Skip/Search again flow remains pending.
- **#47 Support export** — safe file export/runtime metadata exists; richer copy/share ergonomics can still improve.
- **#25 Cover validation/quality** — signature/content validation exists; dimensions, placeholder detection, and quality selection remain pending.
- **#48 Shared error wrappers** — major user-visible crash paths are isolated; further consolidation is opportunistic and evidence-driven.

## Highest-value pending work after v0.1.4

The roadmap is deliberately **not finished**. The strongest remaining work is:

1. **Canonical work/edition identity (#6)** — distinguish provider work IDs from edition IDs and make exact refresh/provider merging safer.
2. **Broader exact-record refresh (#1)** — Hardcover/Amazon/Open Library where stable IDs/detail APIs are reliable.
3. **Network-resilient batch resume (#23)** — recover after restart/network loss without duplicate writes.
4. **Borderline match review (#15/#14)** — explicit Apply/Skip/Search again/Stop flow for non-auto-eligible rows.
5. **Batch report/export (#16)** — sanitized per-book results and failures.
6. **Multi-source merging and field provenance (#2/#3)** — merge only confidently identical records with field-level source tracking.
7. **Cover quality/chooser (#5/#4)** — dimensions/placeholders/candidate selection.
8. **Normalization quality (#7/#40/#41/#37/#38/#39/#8)** — title, author roles, description, genre, language, series.
9. **Safe file organization (#51/#50)** — only after sidecar/history/undo path migration is proven on-device.
10. **Audiobook support (#52)** — first-class media architecture, not an EPUB special case.

## Prioritization model

**Priority Score = 6 × User Impact + 5 × Risk Reduction + 4 × Architectural Leverage + 3 × Breadth + 2 × Feasibility**

Each factor is scored 1–5; maximum score is 100.

| Factor | Weight | 1 | 3 | 5 |
|---|---:|---|---|---|
| User Impact | 30% | niche convenience | meaningful workflow improvement | major improvement to core use |
| Risk Reduction | 25% | little safety effect | prevents common failure/mismatch | materially prevents data loss/bad matches/broken updates |
| Architectural Leverage | 20% | isolated feature | reusable component | unlocks several future capabilities |
| Breadth | 15% | narrow edge case | one major workflow | most users/workflows/providers |
| Feasibility | 10% | large/uncertain/high-risk | moderate effort | bounded/low-risk |

Priority bands:

- **90–100 — Critical / foundational**
- **80–89 — High**
- **70–79 — Medium-high**
- **60–69 — Medium**
- **Below 60 — Opportunistic / later**

## Ranked backlog

| Rank | ID | Idea | Score | Current status / target |
|---:|---:|---|---:|---|
| 1 | #48 | Crash/error isolation | **98** | **Partial:** major v0.1.3/v0.1.4 paths hardened; deeper shared wrappers only as evidence warrants |
| 2 | #26 | Updater SHA-256 integrity verification | **96** | **Shipped v0.1.3** |
| 3 | #42 | Search confidence safeguards | **96** | **Partial:** strong safeguards shipped; extend with deeper provider edition identity |
| 4 | #46 | Provider-specific diagnostic logs | **96** | **Implemented v0.1.4:** persistent/rotated sanitized diagnostics |
| 5 | #6 | Exact-edition awareness | **94** | **Partial:** ISBN/media-kind/format core shipped; canonical work-vs-edition IDs pending v0.2.0 |
| 6 | #51 | Safe file renaming and library organization | **94** | **Pending v0.2.2** |
| 7 | #47 | Copy/save diagnostics/support bundle | **93** | **Partial:** save/export + richer safe runtime metadata implemented; UX can improve |
| 8 | #12 | Undo last metadata change | **92** | **Implemented:** one-step shipped v0.1.3; bounded multi-revision history added v0.1.4 |
| 9 | #1 | Refresh previously matched metadata | **91** | **Partial:** Google Books exact refresh v0.1.4; other providers pending v0.2.0 |
| 10 | #14 | Batch preview before writing | **90** | **Partial:** two-phase core shipped; ready-row deselection v0.1.4; borderline flow pending |
| 11 | #24 | Better HTTP resilience | **90** | **Implemented core:** transient GET/download retries + provider cooldown handling |
| 12 | #27 | Updater deletion/migration support | **90** | **Implemented v0.1.4** |
| 13 | #25 | Cover download validation | **88** | **Partial:** image validation shipped; dimensions/placeholder quality pending |
| 14 | #22 | Per-provider rate controls | **86** | **Implemented v0.1.4 core** |
| 15 | #2 | Metadata source merging | **84** | **Pending v0.2.1** |
| 16 | #30 | Credential masking and validation | **84** | **Implemented v0.1.4 core**; continue provider-specific UX improvements as needed |
| 17 | #10 | Current vs proposed result details | **83** | **Shipped core v0.1.3**; richer field/source comparison pending v0.2.0 |
| 18 | #40 | Better author normalization | **83** | **Partial:** comparison-only core shipped; role-aware normalization pending v0.2.1 |
| 19 | #44 | Explain-score details | **83** | **Implemented v0.1.4 core**; more fixtures/visual refinement pending |
| 20 | #52 | Audiobook metadata support | **82** | **Pending v0.3.0** |
| 21 | #23 | Network-resilient batch resume | **81** | **Pending v0.2.0** |
| 22 | #20 | Provider cooldown/status UI | **79** | **Implemented v0.1.4 core** including persisted last health/test state |
| 23 | #7 | Better title cleaning | **78** | **Pending v0.2.1** |
| 24 | #19 | Search/session cache | **78** | **Pending v0.2.1** |
| 25 | #41 | Multi-author role handling | **78** | **Pending v0.2.1** |
| 26 | #50 | Use filename as search / filename parser | **78** | **Pending v0.2.2** |
| 27 | #5 | Cover quality detection | **76** | **Pending v0.2.1** |
| 28 | #11 | Select fields at apply time | **76** | **Shipped v0.1.3** |
| 29 | #13 | Metadata history | **76** | **Implemented core v0.1.4:** bounded revision history; richer history UI can follow |
| 30 | #29 | Backup/restore/reset settings | **76** | **Implemented v0.1.4 core**: credential-free export + reset actions |
| 31 | #33 | Calibre compatibility awareness | **76** | **Pending v0.2.2** |
| 32 | #37 | Description cleanup | **76** | **Pending v0.2.1** |
| 33 | #43 | Confidence classes | **76** | **Shipped v0.1.3** |
| 34 | #15 | Review borderline matches | **74** | **Partial:** ready-row review exists; borderline decision flow pending v0.2.0 |
| 35 | #18 | Skip already matched books | **74** | **Shipped v0.1.3 batch core** |
| 36 | #8 | Series intelligence | **73** | **Pending v0.2.1** |
| 37 | #36 | Additional metadata fields | **72** | **Pending v0.2.1** |
| 38 | #49 | Offline/manual metadata editing | **72** | **Pending v0.2.2** |
| 39 | #16 | Better batch summary/export | **71** | **Pending v0.2.0** |
| 40 | #38 | Genre normalization | **69** | **Pending v0.2.1** |
| 41 | #3 | Per-field source preference | **68** | **Pending v0.2.1** |
| 42 | #28 | Stable/prerelease update channels | **67** | **Implemented v0.1.4** |
| 43 | #9 | Search again using quick controls | **66** | **Pending v0.2.1** |
| 44 | #35 | Optional EPUB write-back | **66** | **Pending / experimental** |
| 45 | #39 | Language normalization improvements | **65** | **Pending v0.2.1** |
| 46 | #4 | Cover chooser | **64** | **Pending v0.2.1** |
| 47 | #45 | Configurable batch threshold presets | **63** | **Shipped v0.1.3** |
| 48 | #31 | Direct provider URL/ID display | **62** | **Pending v0.2.2** |
| 49 | #34 | OPF import/export | **62** | **Pending v0.2.2** |
| 50 | #21 | Provider priorities | **60** | **Pending v0.2.1** |
| 51 | #17 | Recursive batch mode | **53** | **Pending v0.2.0** |
| 52 | #32 | Open/copy provider page | **48** | **Pending v0.2.2** |

## Release themes

### v0.1.3 — Reliability, matching, hardening & lifecycle safety

Published baseline. Major delivered foundations include:

- central versioning;
- provider diagnostics/readiness;
- ISBN extraction/validation/canonicalization;
- dedupe and confidence/conflict safeguards;
- comparison-only author normalization;
- edition-format safety for EPUB matching;
- Current → Proposed preview;
- one-off per-book field/cover selection;
- one-step Undo and provenance;
- validated cover replacement;
- cautious HTTP retry behavior;
- sanitized diagnostics/support file;
- SHA-256 updater verification;
- two-phase batch discovery/apply;
- threshold presets and skip-already-matched.

### v0.1.4 — Remaining hardening & supportability + bounded lifecycle pulls

Implemented scope:

- updater removal/migration support;
- settings schema migration;
- provider-specific batch pacing and consistent cooldown state;
- persisted provider health/test status;
- masked/validated credential UX;
- credential-free settings export and reset tools;
- Stable/Test release channels;
- persistent/rotated sanitized diagnostics;
- richer safe runtime/device support metadata;
- additional crash/cleanup hardening;
- numeric score evidence;
- ready-row interactive batch deselection;
- bounded multi-revision Undo history;
- exact saved Google Books refresh;
- Zen/context navigation fixes;
- ZenPM static repository support.

Explicitly **not required to call v0.1.4 complete**:

- cover dimension/placeholder ranking;
- canonical cross-provider work/edition identity;
- non-Google exact refresh;
- batch resume/reporting/borderline search-again flow;
- multi-source merging;
- file renaming;
- audiobook support.

### v0.2.0 — Full metadata lifecycle, exact identity, review & refresh

Remaining primary work:

- #6 canonical provider work-vs-edition identity and reliable detail retrieval;
- #1 exact refresh for additional providers;
- #23 resumable batch operations;
- #15 full borderline review flow;
- #16 sanitized batch report/export;
- #10 richer field/source comparison;
- #17 optional recursive batch mode with strict preview/bounds;
- ambiguous-title/edition fixtures and additional explain-score QA.

Already pulled forward: Google exact refresh, numeric score components, ready-row review/deselection, bounded revision history, no-write batch discovery, per-book field selection, skip-already-matched, threshold presets, and format safeguards.

### v0.2.1 — Multi-source quality & normalization

Pending:

- #2 normalized multi-source metadata merging;
- #3 field-level provenance/source preferences;
- #40/#41 role-aware structured author handling;
- #7 title cleaning;
- #19 search/session cache;
- #5/#4 cover quality and chooser;
- #37 description cleanup;
- #8 series intelligence;
- #36 additional fields;
- #38 genre normalization;
- #9 quick search refinement;
- #39 language normalization;
- #21 provider priorities.

### v0.2.2 — File organization & interoperability

Pending and intentionally delayed until path/sidecar/history behavior is proven on-device:

- #51 safe file renaming/library organization;
- #50 filename parsing/search bootstrap;
- #33 Calibre compatibility awareness;
- #49 offline/manual metadata editor;
- #31/#32 provider link/ID actions;
- #34 OPF import/export.

Any rename/move design must preserve KOReader sidecars, reading progress/history, custom metadata/covers, plugin provenance and undo/history references. No silent overwrite.

### v0.3.0 — Audiobook metadata support

Pending. Treat audiobooks as a first-class media architecture rather than an EPUB special case.

Initial target scope:

- `.m4b`, `.mp3`, `.m4a`; investigate `.ogg`/`.opus` only if dependable;
- single-file and multi-track folder audiobooks;
- title/author/narrator/series/language/publisher/date/description/genres/identifiers/duration/cover;
- audiobook-specific matching using narrator, duration, format, identifiers and abridged state;
- safe folder/shared-metadata model;
- no direct destructive audio-tag writing in the first milestone.

## Planning and release rules

1. **Safety before automation.** Renaming, deletion, source-file writes, and future audio-tag writes require preview, validation, collision protection and rollback/undo where feasible.
2. **Provider failures stay isolated.** One provider must not crash or block healthy providers.
3. **Exact identifiers beat fuzzy text unless explicit edition/media evidence contradicts the expected format.**
4. **Unknown edition data is neutral.** Missing format fields are not evidence of a conflict.
5. **No silent destructive behavior.** Batch writes and future path/source-file operations require explicit user-visible controls.
6. **Release candidates require exact-head CI plus real-device evidence where behavior is device/UI/filesystem specific.**
7. **Credentials never enter logs/support bundles.** Redact tokens, secrets, keys, auth headers, credential IDs and Partner Tags.
8. **Roadmap status must be updated when implementation moves ahead.** Never leave a completed tranche labelled simply as future work.
9. **Partial work stays partial.** Preserve remaining acceptance criteria rather than marking the parent idea complete.
10. **Workflow hygiene is part of release hygiene.** Keep only durable workflows on `main`; temporary one-off workflows must be deleted before merge.
11. **Expediting requires a safety case.** Pull work forward only when bounded, testable and not dependent on unfinished destructive-operation infrastructure.
12. **GitHub Releases is the publication source of truth.** Do not infer release state from a branch name or roadmap sentence.

## Detailed implementation checklist

See [`docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md`](docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md) for engineering tasks, acceptance criteria, test gates, and the detailed file-renaming/audiobook plans.

See [`AGENTS.md`](AGENTS.md) for repository/release/workflow hygiene rules used by coding agents.
