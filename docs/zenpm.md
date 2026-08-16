# ZenPM repository support

Metadata Scraper uses the same basic repository model as the official Zen Labs repository: a normal static HTTPS site whose root contains `manifest.json`.

ZenPM treats the URL entered by the user as a **repository base URL** and requests `<base>/manifest.json`. The Kindle ZenPM frontend must be able to fetch that file and parse `repo.name` before it will add the source.

## Repository URL for users

The intended public source is:

`https://jdsnyke.github.io/koreader-metadata-scraper/`

In ZenPM, open **Sources → Add repository** and paste the base URL above. Do **not** append `manifest.json` yourself.

The previous `raw.githubusercontent.com` source is no longer recommended. Although it can expose JSON in a browser, the ZenPM Kindle source detector performs a direct web fetch from the entered base URL; a dedicated static Pages origin more closely matches the official `https://repo.zen-labs.org/` repository design and avoids relying on GitHub's raw-content host as an application repository endpoint.

After adding the source, refresh ZenPM. The listing should show:

- Repository: **JDsnyke KOReader Plugins**
- Application: **Metadata Scraper**
- Platform: **KOReader**

The package maps to `metadata_scraper.koplugin` through the ZenPM `plugin_module` field.

## Static repository tree

The source tree for the Pages site lives under `zenpm-repo/`:

```text
zenpm-repo/
├── index.html
├── manifest.json
└── packages/
    └── metadata-scraper/
        ├── README.md
        └── versions.json
```

`zenpm-repo/manifest.json` intentionally tracks the **latest published stable release**, not whatever unreleased version is being developed on a branch. `versions.json` records the corresponding GitHub release asset URL, size, and digest.

For the v0.1.4 development branch, the public catalog therefore remains on published v0.1.3 until v0.1.4 is actually released.

## GitHub Pages deployment

`.github/workflows/zenpm-pages.yml` deploys only `zenpm-repo/` when Pages content changes on `main`.

GitHub Pages must first be enabled for the repository with **Settings → Pages → Source: GitHub Actions**. That repository-level setting cannot be enabled by the normal `GITHUB_TOKEN` used by a workflow. Once Pages is enabled and the workflow exists on `main`, the intended repository root is:

`https://jdsnyke.github.io/koreader-metadata-scraper/`

## Release maintenance

For every published stable release:

1. Build and publish the GitHub release asset.
2. Verify the actual release asset name, byte size, and SHA-256 digest.
3. Update `zenpm-repo/manifest.json` to the published version.
4. Add the release to `zenpm-repo/packages/metadata-scraper/versions.json`.
5. Keep unreleased branch builds out of the public stable ZenPM catalog.
6. Run the ZenPM and release lints before merging the repository-index update.

The root `manifest.json` is kept compatible as repository metadata, but the Pages deployment source of truth is `zenpm-repo/`.
