# Metadata Scraper for KOReader

A Kindle-friendly KOReader plugin for fetching EPUB metadata and covers from **Hardcover**, **Amazon Creators API**, **Google Books**, and **Open Library**, then saving the selected values as KOReader-native custom metadata.

The plugin does **not** rewrite the EPUB file. Metadata and custom covers are stored through KOReader's own sidecar/settings mechanisms.

> **Release-channel note:** the built-in updater follows the repository's **latest published GitHub Release**, not the `main` branch. `main` can therefore contain a newer fix before that fix is available through **Check for updates**.

## Contents

- [Features](#features)
- [Compatibility](#compatibility)
- [Installation](#installation)
- [Updating an existing installation manually](#updating-an-existing-installation-manually)
- [Configuring credentials](#configuring-credentials)
- [Provider setup](#provider-setup)
- [Using the plugin](#using-the-plugin)
- [Metadata and write behaviour](#metadata-and-write-behaviour)
- [Batch mode](#batch-mode)
- [Built-in update checker and installer](#built-in-update-checker-and-installer)
- [Files, settings, backups and privacy](#files-settings-backups-and-privacy)
- [Troubleshooting](#troubleshooting)
- [Fix history](#fix-history)
- [Release-maintainer checklist](#release-maintainer-checklist)

## Features

- Search one or multiple metadata providers.
- Search by title, author, or ISBN-10/ISBN-13.
- Rank candidate matches and show the strongest results first.
- Preview author, series, publication information, language, ISBN, source, score, and cover availability before applying a match.
- Write KOReader-native custom title, authors, series, series index, language, keywords/genres, description, and cover.
- Choose between replacing existing custom metadata and filling only missing fields.
- Enable or disable individual metadata fields.
- Conservative folder batch mode with a confidence threshold and file limit.
- Zen UI-friendly file/folder context actions.
- Built-in update checking with staged downloads, backup, and rollback.
- Provider-specific error reporting so one unavailable provider does not have to stop the other enabled providers.

## Compatibility

### KOReader

The plugin targets **KOReader 2026.07 (Sailing Walrus)** and newer. It currently targets **EPUB** files.

KOReader 2026.07 includes the `kindlehf` build for modern Kindle firmware. KOReader's own release notes state that Kindle firmware **5.16.3 and later** requires the `kindlehf` package:

https://github.com/koreader/koreader/releases

### Modern Kindle / Coloursoft

For a modern Kindle on firmware **5.16.3+**, use the KOReader **`kindlehf`** package.

A known working setup for this plugin is:

- Kindle Coloursoft
- Kindle firmware 5.19.5
- Vera jailbreak
- KOReader `kindlehf`
- KOReader 2026.07

KindleModding's current KOReader installation guide also specifies `kindlehf` for firmware 5.16.3+:

https://kindlemodding.org/jailbreaking/post-jailbreak/koreader.html

The plugin itself does not depend on Vera, KUAL, KPM, or a particular jailbreak technique once KOReader is already running. It runs inside KOReader.

### USB transfers on Kindle

On Kindle, exit KOReader before trying to use normal USB mass storage. Current KindleModding guidance notes that KOReader itself does not provide USBMS mode; while KOReader is running, a connected USB cable may only charge the device.

## Installation

### Prerequisites

Before installing the plugin:

1. Install and confirm that KOReader itself launches correctly.
2. On firmware 5.16.3+, make sure you installed the `kindlehf` KOReader package.
3. Exit KOReader before connecting the Kindle to a PC or Mac for file copying.
4. Keep a backup of your KOReader settings if you already have an existing installation.

### Fresh installation from a release ZIP

1. Download the Metadata Scraper release ZIP.
2. Extract it on your PC or Mac.
3. Connect the Kindle by USB and open the visible Kindle storage.
4. Open:

   ```text
   koreader/plugins/
   ```

5. Copy the complete plugin folder into that directory.
6. The final layout must be:

   ```text
   koreader/
   └── plugins/
       └── metadata_scraper.koplugin/
           ├── _meta.lua
           ├── main.lua
           ├── README.md
           ├── update.json
           ├── lib/
           │   ├── http.lua
           │   ├── matcher.lua
           │   ├── updater.lua
           │   ├── util.lua
           │   └── writer.lua
           └── providers/
               ├── amazon.lua
               ├── googlebooks.lua
               ├── hardcover.lua
               └── openlibrary.lua
   ```

7. Check that you did **not** accidentally create a nested folder such as:

   ```text
   metadata_scraper.koplugin/metadata_scraper.koplugin/main.lua
   ```

8. Safely eject the Kindle.
9. Start or restart KOReader.
10. If the plugin is not active, check KOReader's plugin-management menu and enable **Metadata Scraper**.

### Internal Kindle paths

Depending on the Kindle/KOReader environment, the same visible storage may internally appear as `/mnt/us`, `/mnt/base-us`, or another mounted path. Do not hard-code an internal path when copying from a PC/Mac; use the visible Kindle storage and place the folder under `koreader/plugins/`.

The built-in updater discovers the plugin directory from the running `main.lua`, so it does not rely on a fixed `/mnt/us` or `/mnt/base-us` path.

### Installing an unreleased fix from `main`

If a fix has been merged into `main` but has not yet been published as a GitHub Release, the built-in updater will not see it yet.

For a manual `main`-branch install:

1. On GitHub, choose **Code → Download ZIP** for this repository.
2. Extract the repository ZIP on your computer.
3. Exit KOReader and connect the Kindle by USB.
4. Copy the plugin runtime files from the repository into:

   ```text
   koreader/plugins/metadata_scraper.koplugin/
   ```

5. Merge the `lib/` and `providers/` directories and replace files with the newer copies.
6. Restart KOReader.

For most users, a proper release ZIP is preferable because it is a known versioned package.

## Updating an existing installation manually

### Normal manual update: copy over and replace

For a normal upgrade, **do not delete the existing folder first**. Exit KOReader, copy the new `metadata_scraper.koplugin` folder over the existing folder, and choose **Merge/Replace** when your operating system asks what to do with files that already exist.

This preserves the directory while replacing changed plugin files.

Your provider credentials and plugin preferences are stored separately in:

```text
koreader/settings/metadata_scraper.lua
```

so replacing the plugin code does not normally remove your credentials.

Recommended manual update procedure:

1. Exit KOReader completely.
2. Connect the Kindle to the PC/Mac.
3. Optional but recommended: back up:

   ```text
   koreader/settings/metadata_scraper.lua
   ```

4. Copy the new:

   ```text
   metadata_scraper.koplugin/
   ```

   over:

   ```text
   koreader/plugins/metadata_scraper.koplugin/
   ```

5. Choose **Merge** and/or **Replace** for existing files.
6. Safely eject the Kindle.
7. Restart KOReader fully so all Lua modules are reloaded.

### When a clean replacement is appropriate

A clean replacement can be useful when:

- an earlier copy was incomplete or corrupted;
- the folder has old files that are no longer part of the plugin;
- the folder layout is wrong;
- troubleshooting indicates that stale plugin files are being loaded.

In that situation, delete only:

```text
koreader/plugins/metadata_scraper.koplugin/
```

then copy in a fresh plugin folder.

Do **not** delete this file unless you intentionally want to reset the plugin configuration:

```text
koreader/settings/metadata_scraper.lua
```

### Manual single-file hotfix

If a fix is explicitly limited to one file, that individual file can be replaced instead of copying the whole plugin. For example, a Hardcover-only provider hotfix can be installed by replacing:

```text
koreader/plugins/metadata_scraper.koplugin/providers/hardcover.lua
```

A full versioned plugin update is still preferred when available because several files may need to stay version-synchronised, especially `_meta.lua`, `lib/updater.lua`, `update.json`, and provider modules.

Always restart KOReader after replacing Lua files.

## Configuring credentials

There are two supported practical ways to configure provider credentials.

### Option 1: configure on the Kindle

Open:

**Tools → Metadata Scraper → Provider accounts**

Available account/configuration entries include:

- **Hardcover API token…**
- **Amazon Creators API…**
- **Amazon marketplace**
- **Amazon search index**
- **Google Books API key…**

Saving valid credential fields through the UI automatically enables Hardcover, Google Books, or Amazon as appropriate.

### Option 2: paste long credentials from a PC or Mac

This is much easier for long API keys and tokens.

1. Open KOReader once with Metadata Scraper installed so its settings file can be created.
2. Exit KOReader completely.
3. Connect the Kindle to the PC/Mac.
4. Back up:

   ```text
   koreader/settings/metadata_scraper.lua
   ```

5. Open the file in a plain-text editor such as VS Code, BBEdit, Sublime Text, Notepad++, or another editor that preserves plain UTF-8 text.
6. Locate the existing settings inside the `config` table and edit the quoted values.

The important setting names are:

```text
hardcover_token
google_api_key
amazon_client_id
amazon_client_secret
amazon_partner_tag
amazon_marketplace
amazon_search_index
enabled
source_scope
```

The exact formatting generated by KOReader's Lua settings serializer can vary. A simplified example looks like this:

```lua
["config"] = {
    ["hardcover_token"] = "YOUR_HARDCOVER_TOKEN",
    ["google_api_key"] = "YOUR_GOOGLE_BOOKS_KEY",
    ["amazon_client_id"] = "YOUR_AMAZON_CREDENTIAL_ID",
    ["amazon_client_secret"] = "YOUR_AMAZON_CREDENTIAL_SECRET",
    ["amazon_partner_tag"] = "YOUR_PARTNER_TAG",
    ["amazon_marketplace"] = "www.amazon.com.au",
    ["amazon_search_index"] = "Books",
    ["source_scope"] = "all",
    ["enabled"] = {
        ["hardcover"] = true,
        ["amazon"] = false,
        ["google"] = true,
        ["openlibrary"] = true,
    },
}
```

Treat that as an illustration. **Edit the values in the existing generated file rather than replacing the whole file with the example.**

Important points when editing manually:

- Keep the surrounding quotes and commas valid Lua syntax.
- Use normal straight quotation marks, not smart/curly quotes.
- Do not add line breaks inside a token or key.
- If you insert credentials manually, also enable the provider under the `enabled` table or enable it afterward from **Metadata Scraper → Providers**.
- Exit KOReader before editing so it does not later overwrite your manual changes with an older in-memory copy.
- Restart KOReader after saving the edited settings file.

## Provider setup

### Open Library

Open Library requires no API credentials and is enabled by default.

It is the simplest provider for confirming that the plugin, network connection, result UI, and metadata writing are functioning before configuring the authenticated providers.

### Hardcover

Hardcover requires an API token from your Hardcover account settings.

Official API documentation:

https://github.com/hardcoverapp/hardcover-docs/blob/main/src/content/docs/api/Getting-Started.mdx

Configure it through:

**Metadata Scraper → Provider accounts → Hardcover API token…**

#### Authorization format

Current Hardcover behaviour requires an HTTP header in this form:

```text
Authorization: Bearer YOUR_TOKEN
```

The current plugin accepts either:

```text
YOUR_TOKEN
```

or:

```text
Bearer YOUR_TOKEN
```

If a raw token is stored, the plugin adds `Bearer ` automatically. If the stored value already starts with `Bearer `, it is preserved so the plugin does not send `Bearer Bearer ...`.

This mirrors the credential-normalisation behaviour used by Hardcover's current official GraphQL Explorer code.

#### Testing the Hardcover token on a PC or Mac

You can test a token independently of KOReader:

```bash
curl -sS 'https://api.hardcover.app/v1/graphql' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'User-Agent: KOReader-Metadata-Scraper-test' \
  --data '{"query":"query { me { id username } }"}'
```

A successful response should contain your Hardcover user information under `data.me`.

#### Hardcover search behaviour

Hardcover's search endpoint is backed by Typesense. Current plugin versions normalise several response forms:

- a flat array of book documents;
- a Typesense response object containing `hits[].document`;
- an array of hit objects;
- JSON-encoded versions of those shapes.

This compatibility layer was added after valid searches such as **Dungeon Crawler Carl** could authenticate correctly but still appear as **No matches found** when the response was wrapped in the Typesense result structure.

If Hardcover returns search IDs but no readable documents, the plugin now reports a diagnostic error instead of silently treating the response as an ordinary zero-result search.

#### Hardcover API notes

Hardcover describes its API as beta and currently documents a rate limit of 60 requests per minute. API behaviour can therefore change and may occasionally require provider updates.

### Google Books

The plugin uses the public Google Books volumes API.

Google's official documentation states that public API requests should identify the application with an API key or OAuth token. This plugin uses an **API key** for public book searches:

https://developers.google.com/books/docs/v1/using

#### Create a Google Books API key

1. Open Google Cloud Console.
2. Create or select a project.
3. Enable the **Books API** for that project if required.
4. Open **APIs & Services → Credentials**.
5. Choose **Create credentials → API key**.
6. For better security, restrict the key to the Books API where practical.
7. Save it in:

   **Metadata Scraper → Provider accounts → Google Books API key…**

Saving a non-empty key through the plugin UI enables Google Books automatically.

#### HTTP 429 / quota handling

Older plugin behaviour could repeatedly surface only `HTTP 429`. Current behaviour is more defensive:

- Google Books is not enabled by default without a configured project API key.
- The plugin exposes Google's returned API error message where possible.
- `Retry-After` is respected when Google sends it.
- Otherwise a bounded exponential cooldown is applied for quota/rate-limit responses.
- Other enabled providers can continue returning results while Google Books is cooling down.

If 429 errors persist even with your own key, check the Google Cloud project, Books API enablement, key restrictions, and the quota/usage information associated with that key.

### Amazon Creators API

Amazon support uses the official **Creators API**. It does **not** scrape Amazon HTML pages.

Official documentation:

https://affiliate-program.amazon.com/creatorsapi/docs/en-us/get-started/using-curl

SearchItems reference:

https://affiliate-program.amazon.com/creatorsapi/docs/en-us/api-reference/operations/search-items

Configure:

- Credential ID
- Credential secret
- Partner Tag
- Marketplace
- Search index (`Books` or `KindleStore`)

The plugin obtains an OAuth 2.0 access token and calls Amazon's `SearchItems` operation.

Amazon's current Creators API documentation groups Australia in the Far East authentication region, whose token endpoint is `api.amazon.co.jp/auth/o2/token`. The plugin handles the regional authentication endpoint based on the selected marketplace.

The default marketplace is:

```text
www.amazon.com.au
```

Currently selectable marketplaces in the plugin are Australia, United States, United Kingdom, Canada, Germany, France, Italy, Spain, India, Japan, Singapore, and the Netherlands.

A Partner Tag needs to be valid for the marketplace being queried. Creators API eligibility and access are controlled by Amazon and cannot be granted by this plugin.

## Using the plugin

### Stock KOReader

Open:

**Tools → Metadata Scraper**

Main actions include:

- **Fetch metadata for current book** — available when the currently open document is an EPUB.
- **Choose EPUB…** — browse for an EPUB from the file manager.
- **Batch folder…** — process EPUBs in a selected folder.
- **Search source** — choose all enabled providers or one specific provider.
- **Providers** — enable/disable providers.
- **Provider accounts** — configure credentials and Amazon options.
- **Metadata fields** — choose which values to write.
- **Replace existing metadata** — toggle replacement versus fill-missing behaviour.
- **Check for updates…** — manually query the latest published release.
- **Automatic update checks** — enable/disable the daily passive check.

### Zen UI

The plugin uses KOReader's native UI components and adds Zen-compatible context actions rather than maintaining an unrelated visual toolkit.

With current Zen UI integration:

- long-press an EPUB and use the **Metadata** action to fetch metadata;
- long-press a folder and use the **Metadata** action to start the bounded folder workflow.

The plugin listens for `ZenUIReady` and reinstalls its file-manager context hook when required.

### Searching one book

The search form is prefilled from KOReader's current effective metadata where available:

- Title
- Author
- Language

An ISBN field is available for manual entry.

You can search using title, author, ISBN, or a combination. ISBN is particularly useful when you need the correct edition.

The plugin ranks returned candidates and displays up to six of the best matches. The result screen includes the source and match score. You can open a candidate preview, go back, or refine the search.

### Provider selection behaviour

When **Search source** is set to **All enabled sources**, only providers enabled under **Providers** are queried.

If you explicitly select one provider as the search source, the plugin attempts that provider directly even if its normal enabled toggle is off. This is useful for testing a provider, but an unconfigured credentialed provider will then return its configuration/authentication error.

## Metadata and write behaviour

KOReader 2026.07 custom metadata supports the following fields used by this plugin:

- Title
- Authors
- Series
- Series index
- Language
- Keywords / genres
- Description
- Custom cover

Publisher, publication date, ISBN, and provider IDs can be shown during matching/preview but are not forced into unsupported KOReader custom metadata properties.

The selected provider ID and available ISBN values are retained in the plugin's own settings under its per-book link data for future use.

### Write modes

**Replace existing metadata** enabled:

- selected plugin fields can replace existing KOReader custom values.

**Replace existing metadata** disabled:

- the plugin fills missing custom values without intentionally replacing existing populated values.

### Field selection

Under **Metadata fields**, each supported field can be independently enabled or disabled. Cover downloading can also be toggled independently.

### Covers

When a selected result has a cover and **Cover** is enabled, the image is downloaded to a temporary cache file and then passed to KOReader's native custom-cover mechanism.

A cover-download failure does not necessarily mean metadata writing failed. The plugin can report **Metadata saved, but the cover could not be downloaded** when the text metadata was successfully written.

## Batch mode

Batch mode is deliberately conservative to reduce accidental mismatches and excessive API traffic.

Defaults:

- current folder only;
- non-recursive;
- maximum 20 EPUB files per run;
- automatic application only when the best candidate score is at least 90%.

For each EPUB, the plugin reads the existing title/author/language metadata, searches the selected providers, ranks matches, and applies only a candidate meeting the configured threshold.

At the end of the run it reports:

- Applied
- Skipped
- Failed

A skipped file normally means the plugin did not find a candidate above the automatic confidence threshold. It is safer to search that book manually than to lower the threshold aggressively.

## Built-in update checker and installer

### Manual check

Open:

**Metadata Scraper → Check for updates…**

The plugin queries:

```text
https://api.github.com/repos/JDsnyke/koreader-metadata-scraper/releases/latest
```

It compares the latest published release tag against its built-in current version.

### Automatic checks

Automatic update checks are enabled by default.

They are intentionally limited:

- at most once every 24 hours;
- they do not switch Wi-Fi on merely to perform the automatic check;
- if networking is already connected, the plugin can silently check the latest release;
- an available update is presented to the user rather than being installed without confirmation.

### What the updater downloads

The updater does not depend on a Kindle `unzip` binary.

For a release such as `v0.1.3`, it downloads the tagged:

```text
update.json
```

and verifies that the manifest version matches the GitHub release version.

The manifest contains the exact plugin file list. The updater then:

1. downloads every listed file to a staging directory;
2. validates that manifest paths are safe relative paths;
3. backs up existing files that will be replaced;
4. replaces files only after the staging downloads have completed;
5. rolls back files already changed if installation fails part-way through;
6. asks the user to restart KOReader after a successful installation.

### Release versus `main`

**Check for updates does not install arbitrary commits from `main`.**

This is intentional. A fix becomes visible to the built-in updater only after a new GitHub Release is published with:

- a `vX.Y.Z` tag;
- a matching version in `update.json`;
- the plugin files present at that tag.

Therefore, if GitHub `main` contains a documented fix but **Check for updates** says you are current, first compare the latest published Release with the repository history. A manual update may be required until that release is published.

### Manual rollback

If a new plugin version causes trouble:

1. Exit KOReader.
2. Back up the current `metadata_scraper.lua` settings file.
3. Copy the previous known-good `metadata_scraper.koplugin` folder over the plugin directory, or delete only the plugin folder and install the previous version cleanly.
4. Leave `koreader/settings/metadata_scraper.lua` in place if you want to retain provider credentials and preferences.
5. Restart KOReader.

The updater also keeps its own staged/backup files under KOReader's data directory, below:

```text
cache/metadata_scraper/updater/
```

These backups are intended for update recovery, not as a replacement for keeping your own configuration backup.

## Files, settings, backups and privacy

### Plugin code

```text
koreader/plugins/metadata_scraper.koplugin/
```

### Plugin configuration

```text
koreader/settings/metadata_scraper.lua
```

This settings file contains provider credentials, provider toggles, metadata-field choices, update preferences, and locally retained provider/ISBN link information.

### Book metadata

The plugin asks KOReader to write custom metadata and covers through KOReader's normal sidecar mechanisms. The exact sidecar location follows the user's KOReader document-metadata configuration.

The original EPUB is not rewritten.

### Credential security

Provider credentials are stored locally as plain configuration values. This plugin does not encrypt them.

Recommended precautions:

- do not commit `metadata_scraper.lua` to a public repository;
- do not include your real token/key in screenshots or bug reports;
- redact credentials from KOReader logs before posting them publicly;
- keep a private backup of the settings file before manual edits or major upgrades.

### Network privacy

When you perform a search, the selected external providers receive the search terms needed for the request. Cover images are downloaded from provider-returned image URLs when cover writing is enabled.

## Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| Metadata Scraper does not appear in KOReader | Wrong plugin folder name, nested folder, plugin not enabled, or KOReader was not restarted | Confirm `koreader/plugins/metadata_scraper.koplugin/main.lua` exists directly, enable the plugin if necessary, and restart KOReader |
| Kindle is connected but the computer does not show normal USB storage while KOReader is open | KOReader/Kindle USBMS behaviour | Exit KOReader back to the Kindle UI, then reconnect USB |
| Hardcover says `Malformed Authorization header` | Older provider code sent a raw token without the required Bearer scheme | Update to the current provider/plugin. Current code accepts either a raw token or `Bearer <token>` and normalises it correctly |
| Hardcover token works with `me { id username }` but common books return `No matches found` | Older Hardcover parser assumed a flat result array and did not handle Typesense `hits[].document` | Update to v0.1.2-era code or newer; the current provider normalises flat, hit-wrapped, and JSON-encoded search results |
| Hardcover works on PC/Mac but not on Kindle | Old plugin file still installed, credential has accidental whitespace/newline, or KOReader was not restarted after replacement | Replace the current `providers/hardcover.lua` or full plugin folder, verify the token line, and fully restart KOReader |
| Google Books returns HTTP 429 | Anonymous/shared quota, project quota, or repeated requests | Configure your own Google Books API key. Current code respects `Retry-After`/cooldown and lets other providers continue |
| Google Books returns 403 | API/key restriction or project configuration issue | Confirm Books API access in the Google Cloud project and review API-key restrictions |
| Google Books is not searched | No API key saved or provider disabled | Save a Google Books API key through Provider accounts or enable Google Books under Providers |
| Amazon authentication fails | Incorrect credentials, Creators API eligibility, wrong Partner Tag, or marketplace mismatch | Confirm Creators API access, Credential ID/secret, marketplace, and that the Partner Tag belongs to the target marketplace |
| Selecting one provider produces a configuration error even though that provider is disabled | Explicit Search source selection overrides the normal provider toggle for that search | Configure the selected provider or switch Search source back to All enabled sources |
| Cover fails but metadata is saved | Cover host/download failed while metadata write succeeded | Retry later, choose another candidate/provider, or disable Cover if text metadata is the priority |
| Built-in updater says the plugin is up to date while GitHub `main` has newer fixes | The updater follows the latest published Release, not `main` | Install the unreleased fix manually or wait until a new Release is published |
| Update fails with a manifest/version error | Release tag and `update.json` do not match, or the release was published incorrectly | Use a manual known-good release and report the release packaging problem |
| Settings disappear after manual update | The settings file was deleted or reset, not merely the plugin folder | Restore the backed-up `koreader/settings/metadata_scraper.lua` file |
| Metadata appears stale in the file manager | KOReader cache/UI has not refreshed as expected | Close/reopen the book or file manager; if necessary restart KOReader |

When reporting a provider problem, include the exact error text and provider name but **redact API keys, Bearer tokens, Amazon secrets, and Partner Tags where appropriate**.

## Fix history

### v0.1.2-era changes

- Fixed Hardcover searches that authenticated successfully but returned no visible candidates because `search.results` was not always a flat array.
- Added normalisation for Typesense `hits[].document`, hit arrays, flat arrays, and JSON-encoded search payloads.
- Added a diagnostic when Hardcover returns IDs without readable result documents.
- Retained the Hardcover Bearer-auth normalisation fix.
- Bumped updater/manifest metadata to 0.1.2.

### Post-v0.1.1 Hardcover auth hotfix

- Corrected Hardcover authentication after live testing showed that `Authorization: Bearer <token>` is required.
- Raw stored tokens are automatically prefixed with `Bearer `.
- Already-prefixed values are accepted without producing `Bearer Bearer ...`.
- Updated the modern Kindle/Coloursoft documentation.

### v0.1.1-era changes

- Added a GitHub Release update checker/downloader.
- Added staged update downloads, backup, rollback, and restart instructions.
- Added automatic update checks at most once every 24 hours without waking Wi-Fi just for the check.
- Changed Google Books to require a project API key in the plugin instead of relying on anonymous/shared quota.
- Improved Google Books 403/429 error reporting.
- Added `Retry-After` support and bounded cooldown/backoff for Google Books quota/rate-limit responses.
- Kept other enabled metadata providers usable when Google Books is throttled.
- Repaired corruption/typos that had slipped into the original repository copy of `main.lua`.

### v0.1.0

Initial device-test release with:

- Hardcover
- Amazon Creators API
- Google Books
- Open Library
- KOReader custom metadata writing
- custom covers
- match ranking
- configurable metadata fields
- bounded folder batch processing
- Zen UI-friendly controls

## Release-maintainer checklist

The built-in updater depends on correctly versioned releases. Before publishing a new version:

1. Update the version in `_meta.lua`.
2. Update `CURRENT_VERSION` in `lib/updater.lua`.
3. Update versioned User-Agent strings where appropriate.
4. Update the version shown in the plugin's **About** text.
5. Update `update.json` so its `version` exactly matches the intended release version.
6. Confirm `update.json` lists every runtime file required by the plugin.
7. Run Lua syntax validation, for example with `texluac -p`, against every `.lua` file.
8. Test at least one normal metadata search and one authenticated provider.
9. Test the update-version comparison.
10. Build the release ZIP with `metadata_scraper.koplugin/` as the plugin directory, avoiding accidental double nesting.
11. Create a Git tag in the form `vX.Y.Z` from the intended release commit.
12. Publish a GitHub Release for that tag.
13. Attach the versioned plugin ZIP, ideally named like:

    ```text
    metadata_scraper_koreader_vX.Y.Z.zip
    ```

14. Confirm the GitHub `/releases/latest` API returns the new release.
15. Confirm the tagged `update.json` is reachable and its version matches the tag without the leading `v`.
16. From an older plugin version, run **Check for updates…**, install the update, restart KOReader, and verify the new version before considering the release complete.

## External documentation

- KOReader releases: https://github.com/koreader/koreader/releases
- KindleModding KOReader installation: https://kindlemodding.org/jailbreaking/post-jailbreak/koreader.html
- Hardcover API Getting Started: https://github.com/hardcoverapp/hardcover-docs/blob/main/src/content/docs/api/Getting-Started.mdx
- Hardcover search guide: https://github.com/hardcoverapp/hardcover-docs/blob/main/src/content/docs/api/guides/Searching.mdx
- Google Books API usage: https://developers.google.com/books/docs/v1/using
- Amazon Creators API authentication: https://affiliate-program.amazon.com/creatorsapi/docs/en-us/get-started/using-curl
- Amazon Creators API SearchItems: https://affiliate-program.amazon.com/creatorsapi/docs/en-us/api-reference/operations/search-items
