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

check("EPUB searches carry explicit ebook media kind", function()
    local data = read_file("main.lua")
    local _, count = data:gsub('media_kind = "ebook"', "")
    truthy(count >= 2, "manual and batch EPUB queries should both identify as ebooks")
end)

check("batch discovery is a no-write phase with second apply gate", function()
    local data = read_file("main.lua")
    truthy(data:find("This first phase makes no metadata or cover changes", 1, true), "no-write discovery warning missing")
    truthy(data:find("Batch discovery complete", 1, true), "batch discovery summary missing")
    truthy(data:find("function MetadataScraper:showBatchPlan", 1, true), "batch plan UI missing")
    truthy(data:find("function MetadataScraper:applyBatchPlan", 1, true), "second-phase batch apply missing")
    truthy(not data:find("Fetch and automatically apply the best match", 1, true), "legacy immediate-write batch prompt remains")
end)

check("batch plan freezes write settings used by Apply", function()
    local data = read_file("main.lua")
    truthy(data:find("replace_existing = self.settings.replace_existing", 1, true), "batch write mode is not frozen")
    truthy(data:find("download_cover = self.settings.download_cover", 1, true), "batch cover preference is not frozen")
    truthy(data:find("fields = U.copy(self.settings.fields)", 1, true), "batch field selection is not frozen")
    truthy(data:find("entry.options", 1, true), "batch Apply does not use frozen options")
end)

check("provenance records edition evidence", function()
    local data = read_file("main.lua")
    truthy(data:find("format = r.format", 1, true))
    truthy(data:find("binding = r.binding", 1, true))
    truthy(data:find("edition = r.edition", 1, true))
    truthy(data:find("media_kind = r.media_kind", 1, true))
end)

check("merged provider edition evidence is re-scored", function()
    package.loaded["lib/matcher"] = nil
    local Matcher = require("lib/matcher")
    local results = {
        {
            source = "primary",
            source_label = "Primary",
            id = "a",
            title = "Example Book",
            authors = { "Example Author" },
            authors_text = "Example Author",
            isbn13 = "9780306406157",
        },
        {
            source = "secondary",
            source_label = "Secondary",
            id = "b",
            title = "Example Book",
            authors = { "Example Author" },
            authors_text = "Example Author",
            isbn13 = "9780306406157",
            binding = "Paperback",
            media_kind = "print",
        },
    }
    Matcher.rank({
        title = "Example Book",
        author = "Example Author",
        isbn = "9780306406157",
        media_kind = "ebook",
    }, results, { primary = 1, secondary = 2 })
    eq(#results, 1)
    eq(results[1].media_kind, "print")
    eq(results[1].score, 65)
    eq(results[1].confidence, "Weak")
    truthy(table.concat(results[1].match_reasons or {}, ","):find("format conflict", 1, true) ~= nil)
end)

check("Amazon SearchItems binding becomes edition evidence", function()
    package.loaded["providers/amazon"] = nil
    package.loaded["lib/http"] = {
        json = function(method, url)
            if url:find("/auth/o2/token", 1, true) then
                return { code = 200, json = { access_token = "test-token", expires_in = 3600 } }
            end
            return {
                code = 200,
                json = {
                    searchResult = {
                        items = {{
                            asin = "B000TEST",
                            itemInfo = {
                                title = { displayValue = "Example Book" },
                                byLineInfo = { contributors = {{ roleType = "author", name = "Example Author" }} },
                                contentInfo = { edition = { displayValue = "Kindle Edition" } },
                                classifications = { binding = { displayValue = "Kindle Edition" } },
                                externalIds = {},
                            },
                            images = {},
                        }},
                    },
                },
            }
        end,
    }
    local Amazon = require("providers/amazon")
    Amazon.reset_token_cache()
    local results = assert(Amazon.search({ title = "Example Book" }, {
        amazon_client_id = "id",
        amazon_client_secret = "secret",
        amazon_credential_version = "3.3",
        amazon_partner_tag = "tag-20",
        amazon_marketplace = "www.amazon.com.au",
        amazon_search_index = "Books",
    }))
    eq(#results, 1)
    eq(results[1].binding, "Kindle Edition")
    eq(results[1].edition, "Kindle Edition")
    eq(results[1].media_kind, "ebook")
end)

check("Amazon print binding is classified as print", function()
    local U = require("lib/util")
    eq(U.format_kind("Paperback"), "print")
    eq(U.format_kind("Hardcover"), "print")
    eq(U.format_kind("Unabridged Audiobook"), "audiobook")
    eq(U.format_kind("Kindle Edition"), "ebook")
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
