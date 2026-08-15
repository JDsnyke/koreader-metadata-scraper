# Roadmap

This roadmap is the planning source of truth for Metadata Scraper for KOReader. It is intentionally broader than the current release branch and includes metadata lifecycle, batch workflows, file organization, interoperability, and audiobook support.

> **Status note:** v0.1.3 is currently being developed on `agent/v0.1.3-reliability-matching`. The roadmap below does not imply that unreleased work is merged into `main`.

## Prioritization model

Ideas are ranked with a weighted, repeatable score rather than by intuition alone.

**Priority Score = 6 × User Impact + 5 × Risk Reduction + 4 × Architectural Leverage + 3 × Breadth + 2 × Feasibility**

Each factor is scored from 1 to 5, giving a maximum score of 100.

| Factor | Weight | 1 | 3 | 5 |
|---|---:|---|---|---|
| User Impact | 30% | niche convenience | meaningful workflow improvement | major improvement to core use |
| Risk Reduction | 25% | little safety/reliability effect | prevents common failure/mismatch | materially prevents data loss, bad matches, or broken updates |
| Architectural Leverage | 20% | isolated feature | reusable component | unlocks several future capabilities |
| Breadth | 15% | affects a narrow edge case | helps one major workflow | benefits most users/workflows/providers |
| Feasibility | 10% | large/uncertain/high-risk build | moderate effort | small, bounded, low-risk implementation |

A higher score means “more valuable to prioritize,” not “must be implemented first.” Dependencies, release risk, and required real-device testing can move an item to a later release.

### Priority bands

- **90–100 — Critical / foundational**
- **80–89 — High**
- **70–79 — Medium-high**
- **60–69 — Medium**
- **Below 60 — Opportunistic / later**

## Ranked backlog

| Rank | ID | Idea | Score | U | R | L | B | F | Planned release |
|---:|---:|---|---:|---:|---:|---:|---:|---:|---|
| 1 | #48 | Crash/error isolation | **98** | 5 | 5 | 5 | 5 | 4 | v0.1.4 |
| 2 | #26 | Updater SHA-256 integrity verification | **96** | 5 | 5 | 5 | 5 | 3 | v0.1.4 |
| 3 | #42 | Search confidence safeguards | **96** | 5 | 5 | 5 | 5 | 3 | v0.2.0 |
| 4 | #46 | Provider-specific diagnostic logs | **96** | 5 | 5 | 5 | 5 | 3 | v0.1.4 |
| 5 | #6 | Exact-edition awareness | **94** | 5 | 5 | 5 | 5 | 2 | v0.2.0 |
| 6 | #51 | Safe file renaming and library organization | **94** | 5 | 5 | 5 | 5 | 2 | v0.2.2 |
| 7 | #47 | Copy diagnostics/support bundle | **93** | 5 | 4 | 5 | 5 | 4 | v0.1.4 |
| 8 | #12 | Undo last metadata change | **92** | 5 | 5 | 4 | 5 | 3 | v0.2.0 |
| 9 | #1 | Refresh previously matched metadata | **91** | 5 | 4 | 5 | 5 | 3 | v0.2.0 |
| 10 | #14 | Batch preview before writing | **90** | 5 | 5 | 4 | 5 | 2 | v0.2.0 |
| 11 | #24 | Better HTTP resilience | **90** | 4 | 5 | 5 | 5 | 3 | v0.1.4 |
| 12 | #27 | Updater deletion/migration support | **90** | 4 | 5 | 5 | 5 | 3 | v0.1.4 |
| 13 | #25 | Cover download validation | **88** | 4 | 5 | 4 | 5 | 4 | v0.1.4 |
| 14 | #22 | Per-provider rate controls | **86** | 4 | 5 | 4 | 5 | 3 | v0.1.4 |
| 15 | #2 | Metadata source merging | **84** | 5 | 3 | 5 | 5 | 2 | v0.2.1 |
| 16 | #30 | Credential masking and validation | **84** | 4 | 5 | 3 | 5 | 4 | v0.1.4 |
| 17 | #10 | Current vs proposed result details | **83** | 5 | 4 | 3 | 5 | 3 | v0.2.0 |
| 18 | #40 | Better author normalization | **83** | 4 | 4 | 4 | 5 | 4 | v0.2.1 |
| 19 | #44 | Explain-score details | **83** | 4 | 4 | 4 | 5 | 4 | v0.2.0 |
| 20 | #52 | Audiobook metadata support | **82** | 5 | 3 | 5 | 5 | 1 | v0.3.0 |
| 21 | #23 | Network-resilient batch resume | **81** | 4 | 5 | 4 | 4 | 2 | v0.2.0 |
| 22 | #20 | Provider cooldown/status UI | **79** | 4 | 4 | 3 | 5 | 4 | v0.1.4 |
| 23 | #7 | Better title cleaning | **78** | 4 | 3 | 4 | 5 | 4 | v0.2.1 |
| 24 | #19 | Search/session cache | **78** | 4 | 3 | 4 | 5 | 4 | v0.2.1 |
| 25 | #41 | Multi-author role handling | **78** | 4 | 4 | 4 | 4 | 3 | v0.2.1 |
| 26 | #50 | Use filename as search / filename parser | **78** | 4 | 3 | 4 | 5 | 4 | v0.2.2 |
| 27 | #5 | Cover quality detection | **76** | 4 | 4 | 3 | 4 | 4 | v0.2.1 |
| 28 | #11 | Select fields at apply time | **76** | 4 | 4 | 3 | 4 | 4 | v0.2.0 |
| 29 | #13 | Metadata history | **76** | 4 | 4 | 4 | 4 | 2 | v0.2.0 |
| 30 | #29 | Backup/restore/reset settings | **76** | 4 | 4 | 3 | 4 | 4 | v0.1.4 |
| 31 | #33 | Calibre compatibility awareness | **76** | 4 | 4 | 4 | 4 | 2 | v0.2.2 |
| 32 | #37 | Description cleanup | **76** | 4 | 3 | 3 | 5 | 5 | v0.2.1 |
| 33 | #43 | Confidence classes | **76** | 4 | 3 | 3 | 5 | 5 | v0.2.1 |
| 34 | #15 | Review borderline matches | **74** | 4 | 4 | 3 | 4 | 3 | v0.2.0 |
| 35 | #18 | Skip already matched books | **74** | 4 | 3 | 3 | 5 | 4 | v0.2.0 |
| 36 | #8 | Series intelligence | **73** | 4 | 3 | 4 | 4 | 3 | v0.2.1 |
| 37 | #36 | Additional metadata fields | **72** | 4 | 3 | 3 | 5 | 3 | v0.2.1 |
| 38 | #49 | Offline/manual metadata editing | **72** | 4 | 3 | 3 | 5 | 3 | v0.2.2 |
| 39 | #16 | Better batch summary/export | **71** | 4 | 3 | 3 | 4 | 4 | v0.2.0 |
| 40 | #38 | Genre normalization | **69** | 4 | 2 | 3 | 5 | 4 | v0.2.1 |
| 41 | #3 | Per-field source preference | **68** | 4 | 2 | 4 | 4 | 3 | v0.2.1 |
| 42 | #28 | Stable/prerelease update channels | **67** | 3 | 3 | 4 | 4 | 3 | v0.1.4 |
| 43 | #9 | Search again using quick controls | **66** | 4 | 2 | 3 | 4 | 4 | v0.2.1 |
| 44 | #35 | Optional EPUB write-back | **66** | 3 | 5 | 3 | 3 | 1 | Later / experimental |
| 45 | #39 | Language normalization improvements | **65** | 3 | 3 | 3 | 4 | 4 | v0.2.1 |
| 46 | #4 | Cover chooser | **64** | 4 | 2 | 3 | 4 | 3 | v0.2.1 |
| 47 | #45 | Configurable batch threshold presets | **63** | 3 | 3 | 2 | 4 | 5 | v0.2.0 |
| 48 | #31 | Direct provider URL/ID display | **62** | 3 | 2 | 3 | 4 | 5 | v0.2.2 |
| 49 | #34 | OPF import/export | **62** | 3 | 3 | 4 | 3 | 2 | v0.2.2 |
| 50 | #21 | Provider priorities | **60** | 3 | 2 | 3 | 4 | 4 | v0.2.1 |
| 51 | #17 | Recursive batch mode | **53** | 3 | 2 | 2 | 3 | 4 | v0.2.0 |
| 52 | #32 | Open/copy provider page | **48** | 3 | 1 | 2 | 3 | 4 | v0.2.2 |

## Release themes

### v0.1.3 — Reliability & Matching

Current development branch. The goal is to establish a safe baseline before broadening the feature surface.

Primary themes:
- central versioning and version-drift prevention;
- provider diagnostics;
- automatic ISBN extraction and checksum validation;
- ISBN-10/ISBN-13 canonical matching;
- cross-provider result deduplication;
- stronger scoring and match explanations;
- safer cover replacement;
- Amazon token-cache/authentication hardening;
- regression tests and Lua CI.

Release gate: complete the real-device checklist in `docs/v0.1.3-testing.md` before merge/release.

### v0.1.4 — Hardening, updater integrity, and supportability

Focus on reducing the probability and blast radius of failures.

Key ranked items:
- #48 crash/error isolation;
- #26 SHA-256 updater integrity verification;
- #46 provider-specific diagnostic logs;
- #47 sanitized diagnostics/support bundle;
- #24 transient HTTP resilience;
- #27 updater deletion/migration support;
- #25 cover download validation;
- #22 provider-specific rate controls;
- #30 credential masking/validation;
- #20 provider cooldown/status UI;
- #29 settings backup/reset;
- #28 stable/prerelease update channels.

### v0.2.0 — Metadata lifecycle, review, and undo

Move from “search and apply” to a safer metadata lifecycle.

Key ranked items:
- #6 exact-edition awareness;
- #12 undo last metadata change;
- #1 refresh previously matched metadata;
- #14 batch preview before writing;
- #42 confidence safeguards;
- #10 current-vs-proposed comparison;
- #44 explain-score details;
- #23 resumable batch operations;
- #15 borderline-match review;
- #13 metadata history;
- #11 apply selected fields;
- #18 skip already matched books;
- #16 batch summary/export;
- #45 batch threshold presets;
- #17 optional recursive batch mode.

### v0.2.1 — Multi-source quality and normalization

Improve metadata quality after the lifecycle model is stable.

Key ranked items:
- #2 multi-source metadata merging;
- #40 author normalization;
- #41 multi-author role handling;
- #7 title cleaning;
- #19 search/session cache;
- #5 cover quality detection;
- #37 description cleanup;
- #43 confidence classes;
- #8 series intelligence;
- #36 additional metadata fields;
- #38 genre normalization;
- #3 per-field source preferences;
- #9 quick search refinement;
- #39 language normalization;
- #4 cover chooser;
- #21 provider priorities.

### v0.2.2 — File organization and interoperability

Add safe file/folder operations only after metadata provenance and undo are mature.

Key ranked items:
- #51 safe file renaming and library organization;
- #50 filename parsing/search bootstrap;
- #33 Calibre compatibility awareness;
- #49 offline/manual metadata editing;
- #31 provider URL/ID display;
- #34 OPF import/export;
- #32 open/copy provider page.

File operations must preserve KOReader sidecars, reading progress, custom metadata, and custom covers. No silent overwrite is permitted.

### v0.3.0 — Audiobook metadata support

Treat audiobook support as a first-class format architecture, not an EPUB special case.

Initial scope:
- `.m4b`, `.mp3`, `.m4a`, with `.ogg`/`.opus` considered where practical;
- single-file and multi-track folder audiobooks;
- title, author, narrator, series, series number, language, publisher, date, description, genres, ISBN, ASIN/provider IDs, duration, and cover;
- audiobook-specific edition matching using narrator, duration, format, identifiers, and abridged/unabridged state;
- shared metadata for multi-track folders;
- safe audiobook/folder renaming templates;
- no direct destructive audio tag writing in the first milestone.

Direct media-file tag writing, playback integration, and ebook↔audiobook work linking should be staged after read-only metadata support is proven.

### Later / experimental

- #35 direct EPUB write-back remains explicitly opt-in and experimental.
- Other low-priority features can be pulled forward only when they unblock a higher-ranked item or solve a demonstrated user problem.

## Planning rules

1. **Safety before automation.** Any feature that can rename, delete, overwrite, or write into source files must have preview, validation, collision handling, and rollback/undo where feasible.
2. **Provider failures stay isolated.** One provider must not crash or block healthy providers.
3. **Exact identifiers beat fuzzy text.** Valid ISBN/provider IDs remain the strongest matching evidence.
4. **Edition conflicts must reduce confidence.** Conflicting author, language, narrator, format, series, or identifier data should lower scores rather than be ignored.
5. **No silent destructive behavior.** Batch writes, file renames, source-file writes, and future audio tag writes require explicit user-visible controls.
6. **Release branches require CI and device validation.** Automated tests are necessary but not sufficient for KOReader/Kindle UI and filesystem behavior.
7. **Credentials never enter logs/support bundles.** Diagnostic output must redact tokens, secrets, API keys, and authorization headers.
8. **Roadmap scores are recalculated when evidence changes.** If usage reports, bugs, API changes, or implementation discoveries alter impact/risk/effort, the factor scores should be updated rather than preserving the old rank.

## Detailed implementation checklist

See [`docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md`](docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md) for release-by-release engineering tasks, acceptance criteria, test gates, and the detailed file-renaming and audiobook plans.
