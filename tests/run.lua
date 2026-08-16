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

check("central version and user agent", function()
    local Version = require("lib/version")
    eq(Version.VERSION, "0.1.4")
    eq(Version.user_agent(), "KOReader-Metadata-Scraper/0.1.4")
end)

check("runtime files do not carry stale release versions", function()
    local paths = {
        "_meta.lua",
        "main.lua",
        "lib/updater.lua",
        "providers/amazon.lua",
        "providers/googlebooks.lua",
        "providers/hardcover.lua",
        "providers/openlibrary.lua",
    }
    for _, path in ipairs(paths) do
        local data = read_file(path)
        truthy(not data:find("KOReader%-Metadata%-Scraper/0%.1%.1"), path .. " has stale 0.1.1 user agent")
        truthy(not data:find("KOReader%-Metadata%-Scraper/0%.1%.2"), path .. " has stale 0.1.2 user agent")
        truthy(not data:find("Metadata Scraper 0%.1%.1"), path .. " has stale 0.1.1 display version")
        truthy(not data:find("Metadata Scraper 0%.1%.2"), path .. " has stale 0.1.2 display version")
    end
    truthy(read_file("update.json"):find('"version": "0.1.4"', 1, true), "manifest version is not 0.1.4")
end)

check("v0.1.4 safety and navigation controls remain wired in the UI", function()
    local data = read_file("main.lua")
    truthy(data:find("Choose fields for this book", 1, true), "per-book field selector missing")
    truthy(data:find("batch_skip_matched", 1, true), "skip-matched batch setting missing")
    truthy(data:find("Strict (95%)", 1, true), "strict batch preset missing")
    truthy(data:find("Recommended (90%)", 1, true), "recommended batch preset missing")
    truthy(data:find("Permissive (80%)", 1, true), "permissive batch preset missing")
end)

check("ISBN extraction from EPUB-style identifiers", function()
    local U = require("lib/util")
    local isbn10, isbn13 = U.extract_isbns("urn:isbn:978-0-14-032872-1; ISBN 0-14-032872-6")
    eq(isbn10, "0140328726")
    eq(isbn13, "9780140328721")
    eq(U.canonical_isbn(isbn10), isbn13)
end)

check("ISBN extraction from nested identifier tables", function()
    local U = require("lib/util")
    local isbn10, isbn13 = U.extract_isbns({ scheme = "ISBN", values = { "9780140328721", "0140328726" } })
    eq(isbn10, "0140328726")
    eq(isbn13, "9780140328721")
end)

check("matcher deduplicates ISBN-10 and ISBN-13 results", function()
    local Matcher = require("lib/matcher")
    local results = {
        {
            source = "hardcover", source_label = "Hardcover", id = "1",
            title = "Matilda", authors = { "Roald Dahl" }, authors_text = "Roald Dahl",
            isbn13 = "9780140328721",
        },
        {
            source = "google", source_label = "Google Books", id = "2",
            title = "Matilda", authors = { "Roald Dahl" }, authors_text = "Roald Dahl",
            isbn10 = "0140328726", description = "A description",
        },
    }
    Matcher.rank({ title = "Matilda", author = "Roald Dahl", isbn = "9780140328721" }, results, { hardcover = 1, google = 2 })
    eq(#results, 1)
    eq(results[1].score, 100)
    eq(results[1].confidence, "Exact")
    eq(results[1].description, "A description")
    eq(results[1].also_sources[1], "Google Books")
    eq(results[1].match_reasons[1], "ISBN exact")
end)

check("matcher keeps same title by different authors separate", function()
    local Matcher = require("lib/matcher")
    local results = {
        { source = "a", id = "1", title = "Home", authors = { "Alice Writer" }, authors_text = "Alice Writer" },
        { source = "b", id = "2", title = "Home", authors = { "Bob Writer" }, authors_text = "Bob Writer" },
    }
    Matcher.rank({ title = "Home" }, results, { a = 1, b = 2 })
    eq(#results, 2)
end)

check("Hardcover accepts raw and already-prefixed bearer tokens", function()
    package.loaded["providers/hardcover"] = nil
    package.loaded["lib/http"] = { json = function() error("network should not be called") end }
    package.preload["json"] = function()
        return { decode = function() return {} end }
    end
    local Hardcover = require("providers/hardcover")
    eq(Hardcover._authorization_header("abc123"), "Bearer abc123")
    eq(Hardcover._authorization_header("Bearer abc123"), "Bearer abc123")
    eq(Hardcover.status({ hardcover_token = "" }), "token missing")
    eq(Hardcover.status({ hardcover_token = "abc123" }), "configured · not tested")
end)

check("Hardcover normalizes Typesense hit documents", function()
    package.loaded["providers/hardcover"] = nil
    package.loaded["lib/http"] = { json = function() error("network should not be called") end }
    package.preload["json"] = function()
        return { decode = function() return {} end }
    end
    local Hardcover = require("providers/hardcover")
    local docs = assert(Hardcover._normalize_results({
        hits = {
            { document = { id = 42, title = "Dungeon Crawler Carl" } },
        },
    }))
    eq(#docs, 1)
    eq(docs[1].title, "Dungeon Crawler Carl")
end)

check("Amazon token cache follows credential version, not marketplace", function()
    package.loaded["providers/amazon"] = nil
    local token_calls = {}
    local search_calls = 0
    package.loaded["lib/http"] = {
        json = function(method, url, headers, body)
            if url:find("/auth/o2/token", 1, true) then
                table.insert(token_calls, url)
                return { code = 200, json = { access_token = "token-" .. tostring(#token_calls), expires_in = 3600 } }
            end
            if url == "https://creatorsapi.amazon/catalog/v1/searchItems" then
                search_calls = search_calls + 1
                return { code = 200, json = { searchResult = { items = {} } } }
            end
            error("unexpected URL: " .. tostring(url))
        end,
    }
    local Amazon = require("providers/amazon")
    Amazon.reset_token_cache()
    local settings = {
        amazon_client_id = "id",
        amazon_client_secret = "secret",
        amazon_credential_version = "3.3",
        amazon_partner_tag = "tag-20",
        amazon_marketplace = "www.amazon.com.au",
        amazon_search_index = "Books",
    }
    eq(Amazon.status(settings), "configured · not tested")
    Amazon.search({ title = "test" }, settings)
    eq(Amazon.status(settings), "ready · token cached")
    Amazon.search({ title = "test" }, settings)
    eq(#token_calls, 1, "same credential should reuse token")
    eq(token_calls[1], "https://api.amazon.co.jp/auth/o2/token")

    settings.amazon_marketplace = "www.amazon.com"
    Amazon.search({ title = "test" }, settings)
    eq(#token_calls, 1, "marketplace change should reuse globally valid token")

    settings.amazon_credential_version = "3.1"
    Amazon.search({ title = "test" }, settings)
    eq(#token_calls, 2, "credential version change should refresh token")
    eq(token_calls[2], "https://api.amazon.com/auth/o2/token")
    truthy(search_calls >= 4)
end)

check("Amazon status reports missing configuration", function()
    package.loaded["providers/amazon"] = nil
    package.loaded["lib/http"] = { json = function() error("network should not be called") end }
    local Amazon = require("providers/amazon")
    eq(Amazon.status({}), "credentials missing")
end)

check("Amazon refreshes a cached token once after HTTP 401", function()
    package.loaded["providers/amazon"] = nil
    local token_calls, search_calls = 0, 0
    package.loaded["lib/http"] = {
        json = function(method, url, headers, body)
            if url:find("/auth/o2/token", 1, true) then
                token_calls = token_calls + 1
                return { code = 200, json = { access_token = "token-" .. tostring(token_calls), expires_in = 3600 } }
            end
            search_calls = search_calls + 1
            if search_calls == 2 then return { code = 401, json = { message = "expired" } } end
            return { code = 200, json = { searchResult = { items = {} } } }
        end,
    }
    local Amazon = require("providers/amazon")
    Amazon.reset_token_cache()
    local settings = {
        amazon_client_id = "id",
        amazon_client_secret = "secret",
        amazon_credential_version = "3.3",
        amazon_partner_tag = "tag-20",
        amazon_marketplace = "www.amazon.com.au",
        amazon_search_index = "Books",
    }
    Amazon.search({ title = "first" }, settings)
    local list, err = Amazon.search({ title = "second" }, settings)
    truthy(type(list) == "table")
    eq(err, nil)
    eq(token_calls, 2)
    eq(search_calls, 3)
end)

check("Google Books honors 429 Retry-After and exposes cooldown status", function()
    package.loaded["providers/googlebooks"] = nil
    local calls = 0
    package.loaded["lib/http"] = {
        json = function(method, url, headers)
            calls = calls + 1
            eq(headers["User-Agent"], "KOReader-Metadata-Scraper/0.1.3")
            return {
                code = 429,
                headers = { ["Retry-After"] = "120" },
                json = {
                    error = {
                        message = "Quota exceeded",
                        errors = { { reason = "rateLimitExceeded" } },
                    },
                },
            }
        end,
    }
    local Google = require("providers/googlebooks")
    local settings = { google_api_key = "key" }
    eq(Google.status({}), "credentials missing")
    eq(Google.status(settings), "ready")
    local list, err = Google.search({ title = "test" }, settings)
    eq(#list, 0)
    truthy(err:find("cooldown 120s", 1, true))
    eq(calls, 1)
    local status = Google.status(settings)
    truthy(status:find("cooling down", 1, true))
    list, err = Google.search({ title = "test" }, settings)
    eq(#list, 0)
    truthy(err:find("retry in about", 1, true))
    eq(calls, 1, "cooldown should prevent a second HTTP request")
end)

check("Open Library reports ready without credentials", function()
    package.loaded["providers/openlibrary"] = nil
    package.loaded["lib/http"] = { json = function() error("network should not be called") end }
    local OpenLibrary = require("providers/openlibrary")
    eq(OpenLibrary.status({}), "ready · no credentials")
end)

check("cover replacement restores old cover on write failure", function()
    local old_path = os.tmpname() .. ".jpg"
    local new_path = os.tmpname() .. ".png"
    local fh = assert(io.open(old_path, "wb")); fh:write("OLD-COVER"); fh:close()
    fh = assert(io.open(new_path, "wb")); fh:write("NEW-COVER"); fh:close()

    package.loaded["lib/writer"] = nil
    package.loaded["docsettings"] = nil
    package.loaded["ui/event"] = nil
    package.loaded["ui/uimanager"] = nil
    package.preload["docsettings"] = function()
        return {
            findCustomCoverFile = function() return old_path end,
            flushCustomCover = function() return nil end,
        }
    end
    package.preload["ui/event"] = function() return { new = function(_, name, file) return { name = name, file = file } end } end
    package.preload["ui/uimanager"] = function() return { broadcastEvent = function() end } end

    local Writer = require("lib/writer")
    eq(Writer.write_cover("book.epub", new_path), nil)
    eq(read_file(old_path), "OLD-COVER")
    os.remove(old_path)
    os.remove(new_path)
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
