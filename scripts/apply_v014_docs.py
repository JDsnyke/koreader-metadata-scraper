#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def replace_once(path, old, new):
    p = ROOT / path
    data = p.read_text(encoding="utf-8")
    count = data.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, found {count}: {old[:100]!r}")
    p.write_text(data.replace(old, new, 1), encoding="utf-8")

replace_once("README.md",
'''## Install with ZenPM

Metadata Scraper exposes a ZenPM v1 repository manifest directly from this repository. In **ZenPM → Sources → Add repository**, paste this repository URL exactly:

`https://raw.githubusercontent.com/JDsnyke/koreader-metadata-scraper/main/`

ZenPM will read `manifest.json` from that base URL and list **JDsnyke KOReader Plugins → Metadata Scraper**. Use the raw-content base URL above rather than the normal GitHub webpage URL; ZenPM repository sources must resolve `manifest.json` directly.

After adding it, refresh ZenPM sources. Published Metadata Scraper releases can then be installed or updated from the package listing. See [`docs/zenpm.md`](docs/zenpm.md) for repository-format and maintenance details.
''',
'''## Install with ZenPM

Metadata Scraper is being moved to a dedicated static ZenPM repository, following the same base-URL + `manifest.json` model used by the official Zen Labs repository.

Once GitHub Pages is enabled for this repository, add this **base URL** in **ZenPM → Sources → Add repository**:

`https://jdsnyke.github.io/koreader-metadata-scraper/`

Do not append `manifest.json`; ZenPM requests that file from the repository root itself. The previous `raw.githubusercontent.com` source is no longer recommended because the Kindle ZenPM source detector performs a direct web fetch and expects a normal static repository endpoint.

The Pages catalog intentionally tracks only published stable releases. During v0.1.4 development it continues to advertise published v0.1.3 rather than an unreleased branch build. See [`docs/zenpm.md`](docs/zenpm.md) for the repository layout, Pages activation step, and release-maintenance process.
''')

replace_once("README.md",
'''│   ├── matcher.lua
│   ├── updater.lua
│   ├── util.lua
''',
'''│   ├── matcher.lua
│   ├── settings.lua
│   ├── updater.lua
│   ├── util.lua
''')

replace_once("README.md",
'''batch_skip_matched
auto_update_check
''',
'''batch_skip_matched
update_channel
auto_update_check
settings_schema_version
''')

replace_once("CHANGELOG.md",
'''### ZenPM

- Document the canonical ZenPM-compatible repository source URL: `https://raw.githubusercontent.com/JDsnyke/koreader-metadata-scraper/main/`.
- Clarify that users should add the raw-content repository base rather than the normal GitHub webpage URL so ZenPM can resolve `manifest.json`.
''',
'''### ZenPM

- Replace the raw GitHub source recommendation with a Pages-ready static ZenPM repository at `https://jdsnyke.github.io/koreader-metadata-scraper/`, matching ZenPM's base-URL + `manifest.json` repository model.
- Add a human-readable repository landing page plus a stable `manifest.json`, package README, and `versions.json` under `zenpm-repo/`.
- Keep the ZenPM public catalog pinned to the latest actually published stable release while v0.1.4 remains unreleased.
- Record the published v0.1.3 release asset URL, byte size, and GitHub-reported SHA-256 digest in the Pages repository metadata.

### Hardening and supportability

- Add settings schema version 2 with ordered migration helpers for legacy installations.
- Add credential-free settings export plus separate matching/provider/all-settings reset actions.
- Validate Amazon credential version before saving and mask Credential ID/Partner Tag entry fields.
- Persist a bounded, rotated, sanitized diagnostics log across KOReader restarts, including operation, status, elapsed time, and result-count metadata.
- Persist the last provider connection-test status and elapsed time in plugin settings.
- Add conservative per-provider request pacing during larger batch operations without overriding provider-specific Retry-After/cooldown behavior.
- Add rollback-safe updater `remove` support for explicitly obsolete files; unsafe, duplicate, or install/remove-overlap paths fail closed.
- Add Stable and Test update channels. Stable remains the default; Test follows published GitHub prereleases only and never arbitrary `main` commits.
''')

replace_once("ROADMAP.md",
'''\> **Status note:** v0.1.3 is currently being developed on `agent/v0.1.3-reliability-matching`. Nothing in this roadmap implies that unreleased work is merged into `main` or published.
'''.replace('\\>', '>'),
'''> **Status note:** v0.1.3 is published. v0.1.4 is currently being developed on `agent/v0.1.4-navigation-zenpm`; it is not merged or released. The v0.1.4 branch now includes navigation/ZenPM work plus the first remaining hardening tranche (settings migrations, updater removals/channels, persistent diagnostics, provider health, credential validation, settings tools, and batch pacing).
''')

# Mark only items implemented by the current v0.1.4 branch. Leave still-unverified/deferred items unchecked.
checks = {
    "- [ ] Provider-specific batch pacing — v0.1.4.": "- [x] Provider-specific batch pacing — v0.1.4 branch; conservative burst-control floors only, with provider cooldowns still authoritative.",
    "- [ ] Persist/rotate diagnostics across restarts — v0.1.4.": "- [x] Persist/rotate diagnostics across restarts — v0.1.4 branch.",
    "- [ ] Optional validated `remove` list.": "- [x] Optional validated `remove` list.",
    "- [ ] Back up removed files before removal.": "- [x] Back up removed files before removal.",
    "- [ ] Restore removed files on later failure.": "- [x] Restore removed files on later failure.",
    "- [ ] Settings schema version.": "- [x] Settings schema version.",
    "- [ ] Ordered migration functions.": "- [x] Ordered migration functions.",
    "- [ ] Regression paths from oldest supported settings format.": "- [x] Regression paths from oldest supported settings format.",
    "- [ ] Provider-specific minimum request intervals for larger batches.": "- [x] Provider-specific minimum request intervals for larger batches.",
    "- [ ] Optional persisted last health/test state.": "- [x] Optional persisted last health/test state.",
    "- [ ] Bounded persistence model.": "- [x] Bounded persistence model.",
    "- [ ] Timestamp/provider/operation/elapsed/status/result-count metadata.": "- [x] Timestamp/provider/operation/elapsed/status/result-count metadata.",
    "- [ ] Never persist full provider response bodies by default.": "- [x] Never persist full provider response bodies by default.",
    "- [ ] Rotation/size cap.": "- [x] Rotation/size cap.",
    "- [ ] Clear log action.": "- [x] Clear log action.",
    "- [ ] Re-redact on export.": "- [x] Re-redact on export.",
    "- [ ] Mask saved credential identifiers where practical.": "- [x] Mask saved credential identifiers where practical.",
    "- [ ] Validate Amazon credential-version input before save.": "- [x] Validate Amazon credential-version input before save.",
    "- [ ] Reset matching settings.": "- [x] Reset matching settings.",
    "- [ ] Reset provider settings with warning.": "- [x] Reset provider settings with warning.",
    "- [ ] Reset all plugin settings.": "- [x] Reset all plugin settings.",
    "- [ ] Credential-free configuration export by default if backup/export is added.": "- [x] Credential-free configuration export by default.",
    "- [ ] Stable remains default.": "- [x] Stable remains default.",
    "- [ ] Optional test channel follows published prereleases only, never arbitrary `main`.": "- [x] Optional Test channel follows published prereleases only, never arbitrary `main`.",
    "- [ ] Clearly label test updates.": "- [x] Clearly label Test-channel prerelease updates.",
    "- [ ] Easy return to Stable.": "- [x] Easy return to Stable.",
}
for old, new in checks.items():
    replace_once("docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md", old, new)

print("Updated v0.1.4 docs and roadmap tracking")
