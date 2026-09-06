# ZenPM repository support

Metadata Scraper uses the same basic repository model as the official Zen Labs repository: a normal static HTTPS site whose root contains `manifest.json`.

ZenPM treats the URL entered by the user as a **repository base URL** and requests `<base>/manifest.json`. The Kindle ZenPM frontend must be able to fetch that file and parse `repo.name` before it will add the source.

## Intended repository URL for users

The intended public source is:

`https://jdsnyke.github.io/koreader-metadata-scraper/`

In ZenPM, open **Sources → Add repository** and paste the base URL above. Do **not** append `manifest.json` yourself.

The previous `raw.githubusercontent.com` source is not the preferred long-term endpoint. A dedicated static Pages origin more closely matches the official `https://repo.zen-labs.org/` repository design.

## Current deployment prerequisite

The static repository tree is ready, but GitHub Pages must be enabled once at repository-admin level before an Actions deployment can work.

Required one-time repository setting:

**Settings → Pages → Source: GitHub Actions**

A normal workflow `GITHUB_TOKEN` cannot create/enable the Pages site for this repository. Attempts to self-enable through `actions/configure-pages` fail with `Resource not accessible by integration`.

For release hygiene, a predictably failing Pages workflow should **not** remain on `main`. After Pages is enabled manually, re-add a small durable workflow that:

1. checks out the repository;
2. configures Pages;
3. uploads only `zenpm-repo/`;
4. deploys it with `actions/deploy-pages`.

Until that one-time repository setting is completed, the static repository files can still be prepared and validated in source control without generating permanent red Actions runs.

## Static repository tree

The source tree for the intended Pages site lives under `zenpm-repo/`:

```text
zenpm-repo/
├── index.html
├── manifest.json
└── packages/
    └── metadata-scraper/
        ├── README.md
        └── versions.json
```

`zenpm-repo/manifest.json` should track the **latest published stable release**, not arbitrary commits on `main` or an unreleased feature branch. `versions.json` records the corresponding GitHub release asset URL, size, and digest.

The root `manifest.json` mirrors the deployed repository metadata so release/ZenPM lints can catch drift before publication.

## Release maintenance

For every published stable release:

1. Build and publish the GitHub release asset.
2. Verify the actual release asset name, byte size, and SHA-256 digest.
3. Update `zenpm-repo/manifest.json` to the published version.
4. Add the release to `zenpm-repo/packages/metadata-scraper/versions.json`.
5. Keep unreleased branch builds out of the public stable ZenPM catalog.
6. Run the ZenPM and release lints before merging the repository-index update.
7. If Pages is enabled and a deploy workflow exists, require that deployment to pass.
8. If Pages is not enabled, keep the deployment workflow absent until the repository-admin prerequisite is completed.

## Re-enabling the Pages workflow later

When Pages has been enabled at repository level, create `.github/workflows/zenpm-pages.yml` as a durable workflow and confirm a successful deployment before advertising the Pages URL as live.

After deployment, verify that these paths return successfully:

- `/manifest.json`
- `/packages/metadata-scraper/README.md`
- `/packages/metadata-scraper/versions.json`

Then ZenPM should show:

- Repository: **JDsnyke KOReader Plugins**
- Application: **Metadata Scraper**
- Platform: **KOReader**
