package.path = "./?.lua;./?/init.lua;" .. package.path

local passed, failed = 0, 0

local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then
        io.write("PASS  " .. name .. "\n")
        passed = passed + 1
    else
        io.stderr:write("FAIL  " .. name .. "\n      " .. tostring(err) .. "\n")
        failed = failed + 1
    end
end

local function eq(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function truthy(value, message)
    if not value then error(message or "expected truthy value", 2) end
end

local function read_file(path)
    local fh = assert(io.open(path, "rb"))
    local data = fh:read("*all")
    fh:close()
    return data
end

check("legacy settings migrate without losing user choices", function()
    local Settings = require("lib/settings")
    local migrated, original = Settings.migrate({
        source_scope = "hardcover",
        batch_threshold = 95,
        enabled = { hardcover = true },
        hardcover_token = "secret",
    })
    eq(original, 0)
    eq(migrated.settings_schema_version, Settings.SCHEMA_VERSION)
    eq(migrated.update_channel, "stable")
    truthy(type(migrated.provider_health) == "table")
    eq(migrated.source_scope, "hardcover")
    eq(migrated.batch_threshold, 95)
    eq(migrated.hardcover_token, "secret")
end)

check("settings export omits credentials and per-book runtime state", function()
    local Settings = require("lib/settings")
    local exported = Settings.safe_export({
        settings_schema_version = 2,
        update_channel = "prerelease",
        hardcover_token = "hardcover-secret",
        google_api_key = "google-secret",
        amazon_client_id = "client-secret-id",
        amazon_client_secret = "client-secret",
        amazon_partner_tag = "partner-secret",
        source_scope = "all",
        enabled = { openlibrary = true },
        book_links = { ["book.epub"] = { id = "1" } },
        undo_records = { ["book.epub"] = { created_at = 1 } },
        provider_health = { google = { ok = true } },
        last_update_check = 123,
    })
    eq(exported.update_channel, "prerelease")
    eq(exported.source_scope, "all")
    truthy(exported.enabled.openlibrary)
    eq(exported.hardcover_token, nil)
    eq(exported.google_api_key, nil)
    eq(exported.amazon_client_id, nil)
    eq(exported.amazon_client_secret, nil)
    eq(exported.amazon_partner_tag, nil)
    eq(exported.book_links, nil)
    eq(exported.undo_records, nil)
    eq(exported.provider_health, nil)
    eq(exported.last_update_check, nil)
end)

check("Amazon credential version validation is explicit", function()
    local Settings = require("lib/settings")
    truthy(Settings.valid_amazon_credential_version(""))
    truthy(Settings.valid_amazon_credential_version("3.1"))
    truthy(Settings.valid_amazon_credential_version("3.2"))
    truthy(Settings.valid_amazon_credential_version("3.3"))
    truthy(not Settings.valid_amazon_credential_version("3.4"))
    truthy(not Settings.valid_amazon_credential_version("auto"))
end)

check("main UI wires remaining v0.1.4 safety controls", function()
    local data = read_file("main.lua")
    truthy(data:find("Settings tools", 1, true), "settings tools UI missing")
    truthy(data:find("Test (prereleases)", 1, true), "prerelease channel UI missing")
    truthy(data:find("Diagnostics.configure", 1, true), "persistent diagnostics configuration missing")
    truthy(data:find("BATCH_PROVIDER_INTERVAL", 1, true), "batch pacing policy missing")
    truthy(data:find("valid_amazon_credential_version", 1, true), "Amazon credential-version validation missing")
end)

check("ZenPM Pages tree tracks the published stable release", function()
    local site_manifest = read_file("zenpm-repo/manifest.json")
    local versions = read_file("zenpm-repo/packages/metadata-scraper/versions.json")
    truthy(site_manifest:find('"url": "https://jdsnyke.github.io/koreader-metadata-scraper/"', 1, true))
    truthy(site_manifest:find('"version": "0.1.3"', 1, true), "Pages manifest must not advertise unreleased v0.1.4")
    truthy(site_manifest:find('"versions_url": "packages/metadata-scraper/versions.json"', 1, true))
    truthy(versions:find("metadata_scraper_koreader_v0.1.3.zip", 1, true))
    truthy(versions:find("sha256:ccb18681158f80dd41af824b954b2fd2333995502b206295f3b60c00c9723a3a", 1, true))
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
