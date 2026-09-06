# AGENTS.md

Repository guidance for coding agents and future maintenance work.

## Project

Metadata Scraper is a KOReader plugin for EPUB metadata and cover retrieval from Hardcover, Amazon Creators API, Google Books, and Open Library. It writes KOReader custom metadata/cover sidecars and does not rewrite EPUB files in the normal workflow.

Primary real-device target used during development: Kindle Coloursoft on modern `kindlehf` KOReader builds.

## Source of truth

- `ROADMAP.md` — ranked product/engineering backlog and release themes.
- `docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md` — detailed implementation/acceptance checklist.
- `CHANGELOG.md` — shipped release changes.
- `lib/version.lua` — runtime plugin version.
- `update.json` — updater payload manifest and hashes.
- `scripts/build_release.py` — deterministic release ZIP builder.

Do not treat an unchecked roadmap item as implemented merely because adjacent infrastructure exists. Use these status meanings consistently:

- **Done / shipped** — implemented, tested, documented, and included in a published stable release.
- **Implemented / release-ready** — code is complete and green but the target release may not yet be published.
- **Partial** — a bounded core/subset exists; remaining work must stay explicitly listed.
- **Pending** — not implemented.

## Branch and release discipline

1. Do feature or release-preparation work on a branch. Do not merge a broad development branch directly without a final review/gate.
2. Before tagging, the exact intended `main` commit must pass the durable CI workflow.
3. Tag the exact green `main` commit. Do not tag a development branch or an earlier pre-finalization commit.
4. The public GitHub Release asset must be the deterministic ZIP produced from that exact tagged tree.
5. Verify the release ZIP SHA-256 against the built checksum and recorded release/ZenPM metadata.
6. Generate `update.json` SHA-256 values only after runtime files are frozen, then run the manifest check again.
7. Never publish a stable release while required release checks are knowingly failing. Infrastructure-only failures must be understood and either fixed or explicitly separated from the plugin release gate.
8. After publishing, update roadmap/release-status wording so it does not continue to describe the release as unreleased.

## GitHub Actions hygiene

Keep workflow files minimal and durable.

Expected long-lived workflow on `main`:

- `.github/workflows/lua-checks.yml` — syntax, lint, regression, release ZIP and artifact gate.

Optional workflow:

- A GitHub Pages/ZenPM deploy workflow may be added **only after GitHub Pages has been enabled for the repository by a repository administrator**. The normal `GITHUB_TOKEN` cannot create/enable a Pages site for this repository, so do not leave a workflow on `main` that predictably fails at `actions/configure-pages`.

Rules:

- Prefer extending an existing durable workflow over creating a one-off workflow.
- If a temporary workflow is genuinely necessary, create it only on a temporary branch and **delete it before merging that branch**.
- Before every release, list `.github/workflows/` and remove obsolete/duplicate/one-shot workflows.
- Update stale Action major versions when practical and compatible.
- Do not ignore failed Actions. Read the failing job logs and identify whether the failure is code, packaging, configuration, permissions, or external infrastructure.
- If an Action depends on a repository-admin prerequisite that automation cannot satisfy, remove/disable the failing workflow until that prerequisite is completed rather than accepting permanent red runs.
- Historical run entries in the Actions UI are not source files; removing an obsolete workflow file prevents future runs even if old run history remains visible.

## Safety invariants

- Provider failures must stay isolated; one provider must not crash/block healthy providers.
- Never log or export configured credentials, tokens, API keys, Amazon secrets, Partner Tags, or Authorization headers.
- Exact identifiers are strong evidence, but explicit ebook/print/audiobook conflicts must not be ignored.
- Unknown edition/format data is neutral; do not invent conflicts from missing fields.
- Metadata, cover, batch, updater, and future file-operation paths should fail closed where possible and preserve rollback/undo guarantees.
- No silent destructive behavior. Renaming, deletion, EPUB write-back, or future audio-tag writes require preview, collision checks, explicit controls, and rollback where feasible.

## Testing expectations

At minimum for runtime changes:

- Lua 5.1 syntax check for all Lua files.
- Release/static lint.
- `scripts/generate_update_manifest.py --check` when hashes are frozen.
- Relevant regression suites under `tests/`.
- `git diff --check`.

For release candidates, also build and validate the deterministic ZIP and use the exact CI artifact for release publication.

Real-device checks remain necessary for KOReader UI, storage, sidecar, restart persistence, and Kindle-specific behavior. Do not claim real-device validation unless it was actually performed/recorded.

## Roadmap maintenance

When implementation moves ahead of the roadmap, update both `ROADMAP.md` and the detailed checklist in the same change set. Preserve unfinished follow-up work instead of marking an entire idea complete when only its core was expedited.

Prioritize safety/correctness foundations before destructive file operations or audiobook tag writing. File renaming and audiobook support remain later milestones unless their prerequisites and device tests are satisfied.

## Current release notes

v0.1.4 adds substantial hardening and pulls forward several v0.2.0 foundations, including persistent diagnostics/provider health, updater removals/channels, settings migration/reset/export, provider pacing/cooldowns, explainable numeric scoring, interactive ready-row batch review, bounded multi-revision metadata history, and exact saved Google Books refresh.

The broader roadmap is intentionally not complete. Canonical cross-provider work/edition identity, broader exact-record refresh, batch resume/reporting, borderline review, multi-source field merging, cover chooser/quality scoring, normalization work, safe file organization, and audiobook metadata remain pending or partial unless the roadmap says otherwise.
