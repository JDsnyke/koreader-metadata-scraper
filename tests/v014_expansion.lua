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

check("result selection preview is guarded and score evidence is not rendered inline", function()
    local data = read_file("main.lua")
    truthy(data:find("local ok, err = pcall(self.showPreview, self, file, raw, query, r)", 1, true), "result preview callback is not protected")
    local start = assert(data:find("function MetadataScraper:showPreview", 1, true))
    local finish = assert(data:find("function MetadataScraper:listEpubs", start, true))
    local block = data:sub(start, finish - 1)
    truthy(block:find('text = _("Match evidence…")', 1, true), "separate match evidence action missing")
    truthy(not block:find('info(_("Score breakdown"), breakdown)', 1, true), "large score breakdown must not render inline in ButtonDialog")
end)


check("metadata document handles close even when property reads throw", function()
    local data = read_file("main.lua")
    local start = assert(data:find("function MetadataScraper:getRawProps", 1, true))
    local finish = assert(data:find("function MetadataScraper:getCurrentFile", start, true))
    local block = data:sub(start, finish - 1)
    truthy(block:find("local doc", 1, true))
    truthy(block:find("pcall(doc.close, doc)", 1, true), "document close is not finally-like")
    local close_pos = assert(block:find("pcall(doc.close, doc)", 1, true))
    local error_pos = assert(block:find("if not ok then", 1, true))
    truthy(close_pos < error_pos, "document must close before read error returns")
end)

check("reset all discards current and historical undo snapshots", function()
    local data = read_file("main.lua")
    local start = assert(data:find("function MetadataScraper:resetAllSettings", 1, true))
    local finish = assert(data:find("function MetadataScraper:clearDiagnostics", start, true))
    local block = data:sub(start, finish - 1)
    truthy(block:find("self.settings.undo_records", 1, true))
    truthy(block:find("self.settings.history_records", 1, true))
    local _, count = block:gsub("Writer%.discard_snapshot", "")
    truthy(count >= 2, "both current and historical snapshots must be discarded")
end)

check("provenance schema reflects expanded v0.1.4 record", function()
    local data = read_file("main.lua")
    truthy(data:find("provenance_version = 2", 1, true))
end)

check("result and refresh previews isolate Writer.preview exceptions", function()
    local data = read_file("main.lua")
    truthy(data:find("pcall(Writer.preview, file, raw, r", 1, true), "result preview is not isolated")
    truthy(data:find("pcall(Writer.preview, file, raw, result", 1, true), "refresh preview is not isolated")
    truthy(data:find('tostring(r.source_label or r.source or _("unknown source"))', 1, true), "source label is not nil-safe")
end)

check("shared Retry-After parser is bounded and case-insensitive", function()
    package.loaded["lib/util"] = nil
    local U = require("lib/util")
    eq(U.retry_after_seconds({headers={["Retry-After"]="42"}}, 30, 100), 42)
    eq(U.retry_after_seconds({headers={["RETRY-AFTER"]="500"}}, 30, 120), 120)
    eq(U.retry_after_seconds({headers={}}, 25, 120), 25)
end)

check("Open Library 429 enters provider cooldown without a second request", function()
    package.loaded["providers/openlibrary"] = nil
    package.loaded["lib/http"] = nil
    local calls = 0
    package.preload["lib/http"] = function()
        return { json=function() calls=calls+1; return {code=429, headers={["retry-after"]="60"}, json={}} end }
    end
    local P = require("providers/openlibrary")
    local out, err = P.search({title="Test"}, {})
    eq(#out, 0); truthy(tostring(err):find("rate limited", 1, true))
    local status, kind = P.status({})
    eq(kind, "cooldown"); truthy(status:find("cooling down", 1, true))
    P.search({title="Test"}, {})
    eq(calls, 1, "cooldown should block the second network request")
    package.preload["lib/http"] = nil; package.loaded["lib/http"] = nil; package.loaded["providers/openlibrary"] = nil
end)

check("support diagnostics include only bounded safe runtime metadata", function()
    local data = read_file("main.lua")
    truthy(data:find("local function safe_runtime_diagnostics", 1, true))
    truthy(data:find('pcall(require, "device")', 1, true))
    truthy(data:find('pcall(require, "version")', 1, true))
    truthy(data:find("runtime.settings_file = self.settings_file", 1, true))
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
