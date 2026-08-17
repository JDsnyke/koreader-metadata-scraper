package.path = "./?.lua;./?/init.lua;" .. package.path

local passed, failed = 0, 0
local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then io.write("PASS  " .. name .. "\n"); passed = passed + 1
    else io.stderr:write("FAIL  " .. name .. "\n      " .. tostring(err) .. "\n"); failed = failed + 1 end
end
local function truthy(v, m) if not v then error(m or "expected truthy", 2) end end
local function eq(a, b, m) if a ~= b then error((m or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function read_file(path) local f=assert(io.open(path,"rb")); local d=f:read("*all"); f:close(); return d end

check("matcher exposes numeric score components without changing final score", function()
    package.loaded["lib/matcher"] = nil
    local Matcher = require("lib/matcher")
    local score, reasons, components = Matcher.score({ title="Dungeon Crawler Carl", author="Matt Dinniman", media_kind="ebook" }, {
        title="Dungeon Crawler Carl", authors={"Matt Dinniman"}, authors_text="Matt Dinniman", media_kind="ebook"
    })
    eq(score, 98)
    truthy(type(reasons)=="table" and #reasons > 0)
    truthy(type(components)=="table" and #components >= 3)
    local sum = 0
    for _, c in ipairs(components) do if c.delta then sum = sum + c.delta end end
    eq(sum, 98)
end)

check("matcher score components expose hard caps", function()
    package.loaded["lib/matcher"] = nil
    local Matcher = require("lib/matcher")
    local score, _, components = Matcher.score({ isbn="9780306406157", media_kind="ebook" }, {
        isbn13="9780306406157", title="Example", media_kind="audiobook"
    })
    eq(score, 35)
    local capped = false
    for _, c in ipairs(components or {}) do if c.cap == 35 then capped = true end end
    truthy(capped, "expected explicit 35 cap")
end)

check("settings v3 migrates bounded history state and excludes it from export", function()
    package.loaded["lib/settings"] = nil
    local Settings = require("lib/settings")
    eq(Settings.SCHEMA_VERSION, 3)
    local migrated = Settings.migrate({ settings_schema_version=2, history_records=nil, batch_threshold=95 })
    truthy(type(migrated.history_records)=="table")
    eq(migrated.batch_threshold, 95)
    local exported = Settings.safe_export({ settings_schema_version=3, history_records={book={{}}}, batch_threshold=90 })
    eq(exported.history_records, nil)
end)

check("interactive batch review remains write-free until Apply selected", function()
    local data = read_file("main.lua")
    truthy(data:find("function MetadataScraper:showBatchReview", 1, true))
    truthy(data:find("entry.selected = entry.selected == false", 1, true))
    truthy(data:find("if entry.selected == false then", 1, true))
    local review_start = assert(data:find("function MetadataScraper:showBatchReview", 1, true))
    local apply_start = assert(data:find("function MetadataScraper:applyBatchPlan", review_start, true))
    local review = data:sub(review_start, apply_start - 1)
    truthy(not review:find("applyResult", 1, true), "review UI must not mutate metadata")
end)

check("multi-revision undo archives old snapshots and promotes history", function()
    local data = read_file("main.lua")
    truthy(data:find("function MetadataScraper:archiveUndoRecord", 1, true))
    truthy(data:find("if old then self:archiveUndoRecord(file, old) end", 1, true))
    truthy(data:find("local previous_undo = type(history) == \"table\" and table.remove(history) or nil", 1, true))
    truthy(data:find("while #records > 4 do", 1, true), "per-book history bound missing")
    truthy(data:find("while #all > 30 do", 1, true), "global history bound missing")
end)

check("Google Books exact saved-record refresh uses volume ID and refuses stale records", function()
    local response = { code=200, json={ id="VOL123", volumeInfo={ title="Refreshed", authors={"Author"}, language="en" } } }
    local captured
    package.loaded["providers/googlebooks"] = nil
    package.loaded["lib/http"] = nil
    package.preload["lib/http"] = function()
        return { json=function(_, url) captured=url; return response end }
    end
    local Google = require("providers/googlebooks")
    local record, err = Google.get_by_id("VOL123", {google_api_key="SECRET"})
    truthy(record, err)
    eq(record.id, "VOL123")
    truthy(captured:find("/volumes/VOL123?key=", 1, true), "exact volume endpoint not used")
    response = { code=404, json={} }
    local missing, missing_err = Google.get_by_id("MISSING", {google_api_key="SECRET"})
    eq(missing, nil)
    truthy(tostring(missing_err):find("no longer exists", 1, true))
    package.preload["lib/http"] = nil
    package.loaded["lib/http"] = nil
    package.loaded["providers/googlebooks"] = nil
end)

check("refresh UI never silently falls back to fuzzy search", function()
    local data = read_file("main.lua")
    local start = assert(data:find("function MetadataScraper:refreshSavedRecord", 1, true))
    local finish = assert(data:find("function MetadataScraper:applyResult", start, true))
    local block = data:sub(start, finish - 1)
    truthy(block:find("provider.get_by_id", 1, true))
    truthy(not block:find("searchProviders", 1, true))
    truthy(block:find("will not silently substitute a different edition", 1, true))
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
