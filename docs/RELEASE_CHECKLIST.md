# Release checklist

Use this checklist for every stable or prerelease publication.

## Before merge

- [ ] Roadmap status reflects what is actually implemented, partial, and pending.
- [ ] Changelog contains the target version and accurate scope.
- [ ] Runtime version is correct in `lib/version.lua`.
- [ ] Runtime file list in `update.json` is correct.
- [ ] Runtime tree is frozen before final SHA generation.
- [ ] `python3 scripts/generate_update_manifest.py --check` passes.
- [ ] Durable CI is green on the release branch.
- [ ] Real-device checks required for changed KOReader/UI/filesystem behavior are recorded.

## GitHub Actions hygiene

- [ ] List `.github/workflows/`.
- [ ] Keep only durable workflows needed after the release.
- [ ] Remove one-off/temporary workflows before merge.
- [ ] Investigate every failed Action from the release candidate; do not silently ignore failures.
- [ ] Update stale Action major versions when compatible.

Expected durable workflow:

- `lua-checks.yml`

A Pages/ZenPM deployment workflow is optional and should only live on `main` after GitHub Pages has been enabled at repository-admin level. If `actions/configure-pages` fails with `Resource not accessible by integration`, remove/disable the workflow until that prerequisite is completed rather than accepting permanent red runs.

## After merge

- [ ] Exact intended `main` commit passes `Lua checks`.
- [ ] Any optional infrastructure workflow that remains on `main` is green or intentionally disabled with its prerequisite documented.
- [ ] Download the release-candidate artifact produced from the exact green `main` commit.
- [ ] Verify the ZIP checksum against its `.sha256` file.
- [ ] Verify ZIP layout and top-level `metadata_scraper.koplugin/` structure.

## Publish

- [ ] Create tag on the exact green `main` commit.
- [ ] Create GitHub Release from that tag.
- [ ] Upload the exact CI-built ZIP.
- [ ] Confirm GitHub-reported asset size/digest matches expected release metadata.
- [ ] Confirm updater/ZenPM stable metadata points to the published stable asset where applicable.
- [ ] Confirm built-in updater sees the intended release channel/version.

## Post-release cleanup

- [ ] Remove any remaining temporary release branches/workflow files where tooling permits.
- [ ] Confirm `.github/workflows/` still contains only durable workflows.
- [ ] Update roadmap/release wording that still says the published version is unreleased/development-only.
- [ ] Leave future roadmap items explicitly pending/partial rather than carrying release assumptions forward.
