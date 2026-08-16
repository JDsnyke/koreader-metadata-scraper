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

local Diagnostics = require("lib/diagnostics")

local settings = {
    enabled = { hardcover = true, amazon = true, google = true, openlibrary = true },
    source_scope = "all",
    hardcover_token = "hardcover-super-secret",
    google_api_key = "google-super-secret",
    amazon_client_id = "amazon-id-secret",
    amazon_client_secret = "amazon-client-secret",
    amazon_partner_tag = "partner-secret",
    amazon_marketplace = "www.amazon.com.au",
    amazon_credential_version = "3.3",
}

check("URL sanitization removes query parameters", function()
    eq(
        Diagnostics.sanitize_url("https://example.test/books?q=title&key=secret"),
        "https://example.test/books?[redacted]"
    )
end)

check("diagnostic redaction removes configured credentials", function()
    local text = Diagnostics.redact(
        "Bearer hardcover-super-secret key=google-super-secret client_secret=amazon-client-secret amazon-id-secret partner-secret",
        settings
    )
    truthy(not text:find("hardcover%-super%-secret"))
    truthy(not text:find("google%-super%-secret"))
    truthy(not text:find("amazon%-client%-secret"))
    truthy(not text:find("amazon%-id%-secret"))
    truthy(not text:find("partner%-secret"))
    truthy(text:find("%[REDACTED%]") ~= nil)
end)

check("support bundle contains configuration state but never credential values", function()
    Diagnostics.clear()
    Diagnostics.log("Hardcover", "Authorization: Bearer hardcover-super-secret", settings)
    Diagnostics.log("Google", "https://example.test?q=book&key=google-super-secret", settings)
    local bundle = Diagnostics.bundle(settings, { koreader = "2026.07", device = "test device" })

    truthy(bundle:find("Metadata Scraper support diagnostics", 1, true) ~= nil)
    truthy(bundle:find("Plugin version: 0.1.4", 1, true) ~= nil)
    truthy(bundle:find("Hardcover: enabled, token configured", 1, true) ~= nil)
    truthy(bundle:find("Amazon: enabled, credentials configured", 1, true) ~= nil)
    truthy(bundle:find("Google Books: enabled, API key configured", 1, true) ~= nil)
    truthy(bundle:find("koreader: 2026.07", 1, true) ~= nil)

    for _, secret in ipairs({
        settings.hardcover_token,
        settings.google_api_key,
        settings.amazon_client_id,
        settings.amazon_client_secret,
        settings.amazon_partner_tag,
    }) do
        truthy(not bundle:find(secret, 1, true), "bundle leaked configured credential")
    end
end)

check("support bundle can be written to disk", function()
    local path = os.tmpname() .. ".txt"
    local ok, err = Diagnostics.write_bundle(path, settings, { test = "yes" })
    truthy(ok, err)
    local fh = assert(io.open(path, "rb"))
    local data = fh:read("*all")
    fh:close()
    os.remove(path)
    truthy(data:find("test: yes", 1, true) ~= nil)
    truthy(not data:find(settings.google_api_key, 1, true))
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
