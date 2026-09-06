from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise SystemExit(f"{label}: pattern not found in {path}")
    p.write_text(s.replace(old, new, 1))

# ---------------------------------------------------------------------------
# main.lua: close document handles reliably, clean history snapshots on reset,
# harden result/refresh previews, bump provenance schema, add safe runtime info.
# ---------------------------------------------------------------------------
p = Path('main.lua')
s = p.read_text()

old = '''function MetadataScraper:getRawProps(file)\n    local ok, raw, effective = pcall(function()\n        local doc = DocumentRegistry:hasProvider(file) and DocumentRegistry:openDocument(file)\n        if not doc then return {}, {} end\n        local loaded = true\n        if doc.loadDocument then loaded = doc:loadDocument(false) end\n        local props = loaded and (doc:getProps() or {}) or {}\n        doc:close()\n        return props, BookInfo.extendProps(props, file)\n    end)\n    if not ok then\n        Diagnostics.log("KOReader metadata", raw, self.settings)\n        return {}, {}\n    end\n    return raw or {}, effective or {}\nend\n'''
new = '''function MetadataScraper:getRawProps(file)\n    local doc\n    local ok, raw, effective = pcall(function()\n        if not DocumentRegistry:hasProvider(file) then return {}, {} end\n        doc = DocumentRegistry:openDocument(file)\n        if not doc then return {}, {} end\n        local loaded = true\n        if doc.loadDocument then loaded = doc:loadDocument(false) end\n        local props = loaded and (doc:getProps() or {}) or {}\n        return props, BookInfo.extendProps(props, file)\n    end)\n\n    -- Close outside the protected metadata-read body so getProps/extendProps\n    -- exceptions cannot leak an open document handle on long batch runs.\n    if doc and type(doc.close) == "function" then\n        local closed, close_err = pcall(doc.close, doc)\n        if not closed then\n            Diagnostics.log("KOReader document close", close_err or "Could not close document", self.settings, {\n                operation = "metadata-read", status = "error",\n            })\n        end\n    end\n\n    if not ok then\n        Diagnostics.log("KOReader metadata", raw, self.settings, { operation = "metadata-read", status = "error" })\n        return {}, {}\n    end\n    return raw or {}, effective or {}\nend\n'''
if old not in s: raise SystemExit('getRawProps block not found')
s = s.replace(old, new, 1)

old = '''            for _, record in pairs(self.settings.undo_records or {}) do\n                Writer.discard_snapshot(record.snapshot or record)\n            end\n            Diagnostics.clear()\n'''
new = '''            for _, record in pairs(self.settings.undo_records or {}) do\n                Writer.discard_snapshot(record.snapshot or record)\n            end\n            for _, records in pairs(self.settings.history_records or {}) do\n                if type(records) == "table" then\n                    for _, record in ipairs(records) do\n                        Writer.discard_snapshot(record.snapshot or record)\n                    end\n                end\n            end\n            Diagnostics.clear()\n'''
if old not in s: raise SystemExit('resetAll snapshot cleanup block not found')
s = s.replace(old, new, 1)

s = s.replace('        provenance_version = 1,\n', '        provenance_version = 2,\n', 1)

old = '''        local r = results[i]\n        local author = U.join(r.authors, ", ", 2)\n        local secondary = r.source_label or r.source\n        if r.also_sources and #r.also_sources > 0 then\n            secondary = secondary .. " +" .. tostring(#r.also_sources)\n        end\n        if r.published_date then secondary = secondary .. " · " .. tostring(r.published_date) end\n        if r.media_kind then secondary = secondary .. " · " .. tostring(r.media_kind) end\n        local text = tostring(r.title or _("Untitled"))\n'''
new = '''        local r = type(results[i]) == "table" and results[i] or {}\n        local author = U.join(r.authors, ", ", 2)\n        local secondary = tostring(r.source_label or r.source or _("unknown source"))\n        if type(r.also_sources) == "table" and #r.also_sources > 0 then\n            secondary = secondary .. " +" .. tostring(#r.also_sources)\n        end\n        if r.published_date then secondary = secondary .. " · " .. tostring(r.published_date) end\n        if r.media_kind then secondary = secondary .. " · " .. tostring(r.media_kind) end\n        local text = tostring(r.title or _("Untitled"))\n'''
if old not in s: raise SystemExit('showResults normalization block not found')
s = s.replace(old, new, 1)

old = '''    info(_("Author"), U.join(r.authors, ", "))\n    if r.series then info(_("Series"), r.series .. (r.series_index and (" #" .. tostring(r.series_index)) or "")) end\n    info(_("Published"), r.published_date)\n    info(_("Language"), r.language)\n    info("ISBN-13", r.isbn13); info("ISBN-10", r.isbn10)\n    info(_("Format"), r.format or r.binding or r.media_kind)\n    info(_("Edition"), r.edition)\n    info(_("Source"), (r.source_label or r.source) .. " · " .. tostring(r.score or 0) .. "%")\n'''
new = '''    r = type(r) == "table" and r or {}\n    info(_("Author"), U.join(r.authors, ", "))\n    if r.series then info(_("Series"), tostring(r.series) .. (r.series_index and (" #" .. tostring(r.series_index)) or "")) end\n    info(_("Published"), r.published_date)\n    info(_("Language"), r.language)\n    info("ISBN-13", r.isbn13); info("ISBN-10", r.isbn10)\n    info(_("Format"), r.format or r.binding or r.media_kind)\n    info(_("Edition"), r.edition)\n    info(_("Source"), tostring(r.source_label or r.source or _("unknown source")) .. " · " .. tostring(r.score or 0) .. "%")\n'''
if old not in s: raise SystemExit('showPreview header block not found')
s = s.replace(old, new, 1)

old = '''    local changes, change_err = Writer.preview(file, raw, r, self.settings.fields, self.settings.replace_existing)\n    if changes then\n'''
new = '''    local preview_ok, changes, change_err = pcall(Writer.preview, file, raw, r, self.settings.fields, self.settings.replace_existing)\n    if not preview_ok then\n        change_err = Diagnostics.redact(changes or "Metadata preview failed", self.settings)\n        changes = nil\n        Diagnostics.log("Result preview", change_err, self.settings, { operation = "preview", status = "error" })\n    end\n    if changes then\n'''
if old not in s: raise SystemExit('showPreview Writer.preview block not found')
s = s.replace(old, new, 1)

old = '''    local fields = cover_only and empty_field_selection() or self.settings.fields\n    local changes, preview_err = Writer.preview(file, raw, result, fields, self.settings.replace_existing)\n    local rows = {\n'''
new = '''    local fields = cover_only and empty_field_selection() or self.settings.fields\n    local preview_ok, changes, preview_err = pcall(Writer.preview, file, raw, result, fields, self.settings.replace_existing)\n    if not preview_ok then\n        preview_err = Diagnostics.redact(changes or "Refresh preview failed", self.settings)\n        changes = nil\n        Diagnostics.log("Refresh preview", preview_err, self.settings, { operation = "refresh-preview", status = "error" })\n    end\n    local rows = {\n'''
if old not in s: raise SystemExit('showRefreshPreview Writer.preview block not found')
s = s.replace(old, new, 1)

# Add safe runtime diagnostics helper immediately before saveSupportDiagnostics.
needle = '''function MetadataScraper:saveSupportDiagnostics()\n    local cache_dir = DataStorage:getDataDir() .. "/cache/metadata_scraper"\n'''
replacement = '''local function safe_runtime_diagnostics()\n    local info = {\n        lua = _VERSION or "unknown",\n        plugin_root = PLUGIN_ROOT,\n        target = "KOReader 2026.07+",\n    }\n    if type(jit) == "table" then\n        info.luajit = jit.version\n        info.runtime_os = jit.os\n        info.runtime_arch = jit.arch\n    end\n    local ok_device, Device = pcall(require, "device")\n    if ok_device and type(Device) == "table" then\n        local model = Device.model or Device.device_model\n        if type(model) == "string" and model ~= "" then info.device_model = model end\n        if type(Device.isKindle) == "function" then\n            local ok_kindle, is_kindle = pcall(Device.isKindle, Device)\n            if ok_kindle then info.device_family = is_kindle and "Kindle" or "non-Kindle" end\n        end\n    end\n    local ok_version, koreader_version = pcall(require, "version")\n    if ok_version and type(koreader_version) == "string" then info.koreader_version = koreader_version end\n    return info\nend\n\nfunction MetadataScraper:saveSupportDiagnostics()\n    local cache_dir = DataStorage:getDataDir() .. "/cache/metadata_scraper"\n'''
if needle not in s: raise SystemExit('saveSupportDiagnostics insertion point not found')
s = s.replace(needle, replacement, 1)

old = '''    local ok, err = Diagnostics.write_bundle(filepath, self.settings, {\n        plugin_root = PLUGIN_ROOT,\n        settings_file = self.settings_file,\n        target = "KOReader 2026.07+",\n    })\n'''
new = '''    local runtime = safe_runtime_diagnostics()\n    runtime.settings_file = self.settings_file\n    local ok, err = Diagnostics.write_bundle(filepath, self.settings, runtime)\n'''
if old not in s: raise SystemExit('support diagnostics extra block not found')
s = s.replace(old, new, 1)

p.write_text(s)

# ---------------------------------------------------------------------------
# util.lua: one consistent bounded numeric Retry-After parser.
# ---------------------------------------------------------------------------
p = Path('lib/util.lua')
s = p.read_text()
needle = '''function M.urlencode(s)\n    s = tostring(s or "")\n    return (s:gsub("([^%w%-%._~])", function(c)\n        return string.format("%%%02X", string.byte(c))\n    end))\nend\n\n'''
addition = '''function M.urlencode(s)\n    s = tostring(s or "")\n    return (s:gsub("([^%w%-%._~])", function(c)\n        return string.format("%%%02X", string.byte(c))\n    end))\nend\n\nfunction M.retry_after_seconds(res, fallback, maximum)\n    local headers = type(res) == "table" and type(res.headers) == "table" and res.headers or {}\n    local header = headers["retry-after"] or headers["Retry-After"]\n    if header == nil then\n        for key, value in pairs(headers) do\n            if tostring(key):lower() == "retry-after" then header = value; break end\n        end\n    end\n    local seconds = tonumber(header)\n    maximum = math.max(1, tonumber(maximum) or 3600)\n    fallback = math.max(1, tonumber(fallback) or 30)\n    if seconds and seconds > 0 then return math.min(maximum, math.max(1, math.floor(seconds + 0.5))) end\n    return math.min(maximum, fallback)\nend\n\n'''
if needle not in s: raise SystemExit('util urlencode block not found')
s = s.replace(needle, addition, 1)
p.write_text(s)

# ---------------------------------------------------------------------------
# Google: use shared Retry-After parser.
# ---------------------------------------------------------------------------
p = Path('providers/googlebooks.lua')
s = p.read_text()
old = '''    local headers = (res and res.headers) or {}\n    local header = headers["retry-after"] or headers["Retry-After"]\n    local seconds = tonumber(header)\n    if seconds and seconds > 0 then return math.min(seconds, 3600) end\n    if reason == "dailyLimitExceeded" or reason == "quotaExceeded" then return 3600 end\n'''
new = '''    local headers = (res and res.headers) or {}\n    local header = headers["retry-after"] or headers["Retry-After"]\n    if header ~= nil then return U.retry_after_seconds(res, 30, 3600) end\n    if reason == "dailyLimitExceeded" or reason == "quotaExceeded" then return 3600 end\n'''
if old not in s: raise SystemExit('Google retry-after block not found')
s = s.replace(old, new, 1)
p.write_text(s)

# ---------------------------------------------------------------------------
# Open Library: provider-local cooldown honoring Retry-After.
# ---------------------------------------------------------------------------
p = Path('providers/openlibrary.lua')
s = p.read_text()
s = s.replace('local P = { id = "openlibrary", label = "Open Library" }\n\nlocal function request(url)\n    return HTTP.json("GET", url, {\n        ["User-Agent"] = Version.user_agent(),\n    })\nend\n', '''local P = { id = "openlibrary", label = "Open Library" }\nlocal cooldown_until = 0\n\nlocal function cooldown_error()\n    local remaining = cooldown_until - os.time()\n    if remaining > 0 then return "Open Library is cooling down; retry in about " .. tostring(math.max(1, remaining)) .. " seconds" end\nend\n\nlocal function request(url)\n    local blocked = cooldown_error()\n    if blocked then return nil, blocked end\n    local res, err = HTTP.json("GET", url, {\n        ["User-Agent"] = Version.user_agent(),\n    })\n    if not res then return nil, err end\n    if res.code == 429 then\n        local wait = U.retry_after_seconds(res, 30, 1800)\n        cooldown_until = os.time() + wait\n        return nil, "Open Library rate limited the request (cooldown " .. tostring(wait) .. "s)"\n    end\n    if res.code >= 200 and res.code < 300 then cooldown_until = 0 end\n    return res\nend\n''', 1)
s = s.replace('function P.status()\n    return "ready · no credentials", "ready"\nend\n', '''function P.status()\n    local remaining = cooldown_until - os.time()\n    if remaining > 0 then return "cooling down " .. tostring(math.max(1, remaining)) .. "s", "cooldown" end\n    return "ready · no credentials", "ready"\nend\n''', 1)
p.write_text(s)

# ---------------------------------------------------------------------------
# Hardcover: provider-local cooldown honoring Retry-After on GraphQL POST.
# ---------------------------------------------------------------------------
p = Path('providers/hardcover.lua')
s = p.read_text()
s = s.replace('local ENDPOINT = "https://api.hardcover.app/v1/graphql"\n', 'local ENDPOINT = "https://api.hardcover.app/v1/graphql"\nlocal cooldown_until = 0\n', 1)
old = '''local function graphql(token, query, variables)\n    local authorization = authorization_header(token)\n    if not authorization then return nil, "Hardcover API token is not configured" end\n    local res, err = HTTP.json("POST", ENDPOINT, {\n'''
new = '''local function graphql(token, query, variables)\n    local authorization = authorization_header(token)\n    if not authorization then return nil, "Hardcover API token is not configured" end\n    local remaining = cooldown_until - os.time()\n    if remaining > 0 then return nil, "Hardcover is cooling down; retry in about " .. tostring(math.max(1, remaining)) .. " seconds" end\n    local res, err = HTTP.json("POST", ENDPOINT, {\n'''
if old not in s: raise SystemExit('Hardcover graphql start not found')
s = s.replace(old, new, 1)
old = '''    if not res then return nil, err end\n    if res.code ~= 200 then return nil, "HTTP " .. tostring(res.code) end\n'''
new = '''    if not res then return nil, err end\n    if res.code == 429 then\n        local wait = U.retry_after_seconds(res, 30, 1800)\n        cooldown_until = os.time() + wait\n        return nil, "Hardcover rate limited the request (cooldown " .. tostring(wait) .. "s)"\n    end\n    if res.code ~= 200 then return nil, "HTTP " .. tostring(res.code) end\n    cooldown_until = 0\n'''
if old not in s: raise SystemExit('Hardcover response code block not found')
s = s.replace(old, new, 1)
old = '''function P.status(settings)\n    if not U.nonempty(settings and settings.hardcover_token) then\n        return "token missing", "missing"\n    end\n    return "configured · not tested", "configured"\nend\n'''
new = '''function P.status(settings)\n    if not U.nonempty(settings and settings.hardcover_token) then\n        return "token missing", "missing"\n    end\n    local remaining = cooldown_until - os.time()\n    if remaining > 0 then return "cooling down " .. tostring(math.max(1, remaining)) .. "s", "cooldown" end\n    return "configured · not tested", "configured"\nend\n'''
if old not in s: raise SystemExit('Hardcover status block not found')
s = s.replace(old, new, 1)
p.write_text(s)

# ---------------------------------------------------------------------------
# Amazon: provider-local cooldown for token/search 429s.
# ---------------------------------------------------------------------------
p = Path('providers/amazon.lua')
s = p.read_text()
s = s.replace('local token_cache = { value = nil, expiry = 0, key = nil }\n', 'local token_cache = { value = nil, expiry = 0, key = nil }\nlocal cooldown_until = 0\n', 1)
needle = '''local function amazon_error(res)\n    local body = res and res.json or {}\n    local message = body.message or body.error_description or body.error\n    if message and message ~= "" then return tostring(message) end\n    return "HTTP " .. tostring(res and res.code or "?")\nend\n\n'''
replacement = needle + '''local function cooldown_error()\n    local remaining = cooldown_until - os.time()\n    if remaining > 0 then return "Amazon Creators API is cooling down; retry in about " .. tostring(math.max(1, remaining)) .. " seconds" end\nend\n\nlocal function apply_rate_limit(res)\n    if not res or res.code ~= 429 then return nil end\n    local wait = U.retry_after_seconds(res, 30, 1800)\n    cooldown_until = os.time() + wait\n    return "Amazon Creators API rate limited the request (cooldown " .. tostring(wait) .. "s)"\nend\n\n'''
if needle not in s: raise SystemExit('Amazon error helper block not found')
s = s.replace(needle, replacement, 1)
old = '''local function get_token(settings, force_refresh)\n    if not U.nonempty(settings.amazon_client_id) or not U.nonempty(settings.amazon_client_secret) then\n'''
new = '''local function get_token(settings, force_refresh)\n    local blocked = cooldown_error()\n    if blocked then return nil, blocked end\n    if not U.nonempty(settings.amazon_client_id) or not U.nonempty(settings.amazon_client_secret) then\n'''
if old not in s: raise SystemExit('Amazon get_token start not found')
s = s.replace(old, new, 1)
old = '''    if not res then return nil, err end\n    if res.code ~= 200 or not res.json or not res.json.access_token then\n'''
new = '''    if not res then return nil, err end\n    local rate_error = apply_rate_limit(res)\n    if rate_error then clear_token_cache(); return nil, rate_error end\n    if res.code ~= 200 or not res.json or not res.json.access_token then\n'''
if old not in s: raise SystemExit('Amazon token response block not found')
s = s.replace(old, new, 1)
# On successful auth reset cooldown.
s = s.replace('    token_cache.value = res.json.access_token\n', '    cooldown_until = 0\n    token_cache.value = res.json.access_token\n', 1)
old = '''    local endpoint = token_endpoint(settings)\n    local key = cache_key(settings, endpoint)\n'''
new = '''    local remaining = cooldown_until - os.time()\n    if remaining > 0 then return "cooling down " .. tostring(math.max(1, remaining)) .. "s", "cooldown" end\n    local endpoint = token_endpoint(settings)\n    local key = cache_key(settings, endpoint)\n'''
# Replace only status occurrence after credentials check; first matching occurrence is in status, because get_token has endpoint with extra vars.
if old not in s: raise SystemExit('Amazon status endpoint block not found')
s = s.replace(old, new, 1)
old = '''function P.search(query, settings)\n    if not U.nonempty(settings.amazon_partner_tag) then return {}, "Amazon Partner Tag is not configured" end\n'''
new = '''function P.search(query, settings)\n    local blocked = cooldown_error()\n    if blocked then return {}, blocked end\n    if not U.nonempty(settings.amazon_partner_tag) then return {}, "Amazon Partner Tag is not configured" end\n'''
if old not in s: raise SystemExit('Amazon search start not found')
s = s.replace(old, new, 1)
old = '''    if res.code ~= 200 then return {}, amazon_error(res) end\n    local root = res.json or {}\n'''
new = '''    local rate_error = apply_rate_limit(res)\n    if rate_error then return {}, rate_error end\n    if res.code ~= 200 then return {}, amazon_error(res) end\n    cooldown_until = 0\n    local root = res.json or {}\n'''
if old not in s: raise SystemExit('Amazon search response block not found')
s = s.replace(old, new, 1)
p.write_text(s)

# ---------------------------------------------------------------------------
# Tests: add concrete stability/cooldown regressions to existing permanent suite.
# ---------------------------------------------------------------------------
p = Path('tests/v014_expansion.lua')
s = p.read_text()
insert = r'''
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
'''
marker = '\nio.write(string.format("\\n%d passed, %d failed\\n", passed, failed))\n'
if marker not in s: raise SystemExit('v014_expansion footer not found')
s = s.replace(marker, '\n' + insert + marker, 1)
p.write_text(s)

# ---------------------------------------------------------------------------
# Documentation/checklist/changelog.
# ---------------------------------------------------------------------------
p = Path('docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md')
s = p.read_text()
s = s.replace('- [ ] Numeric positive/negative score-component breakdown — v0.2.0.', '- [x] Numeric positive/negative score-component breakdown — expedited to v0.1.4; detailed evidence moved to a bounded separate view after Kindle device feedback.', 1)
s = s.replace('- [ ] Multi-revision history — v0.2.0.', '- [x] Multi-revision history — expedited to v0.1.4 with bounded per-book/global history.', 1)
s = s.replace('- [ ] Direct exact provider-record refresh — v0.2.0.', '- [~] Direct exact provider-record refresh — Google Books exact volume refresh expedited to v0.1.4; other providers remain future work.', 1)
s = s.replace('- [ ] Per-row preview/deselect — v0.2.0.', '- [x] Per-row preview/deselect — ready-match review/deselect expedited to v0.1.4.', 1)
s = s.replace('- [ ] Honor Retry-After/cooldown consistently.', '- [x] Honor numeric Retry-After/cooldown consistently across Google Books, Hardcover, Amazon Creators API, and Open Library; provider-local cooldown blocks repeated requests while active.', 1)
s = s.replace('- [ ] Richer safe device/KOReader runtime metadata — v0.1.4.', '- [x] Richer safe device/KOReader runtime metadata — Lua/LuaJIT runtime, architecture/OS, optional KOReader version, and non-secret device family/model are collected defensively for support bundles.', 1)
s = s.replace('- [ ] Consolidate remaining wrappers if device testing identifies duplicated failure paths — v0.1.4.', '- [x] Consolidate high-risk result/refresh preview wrappers identified by device testing; preview rendering and Writer.preview failures now degrade to controlled diagnostics rather than escaping through KOReader UI.', 1)
p.write_text(s)

p = Path('CHANGELOG.md')
s = p.read_text()
needle = '## [0.1.4] - Unreleased\n\n'
if needle not in s: raise SystemExit('changelog heading not found')
addition = '''## [0.1.4] - Unreleased\n\n### Additional stability and provider hardening\n\n- Close KOReader document handles even when metadata reads or effective-property expansion throws, preventing leaked handles during repeated/batch scans.\n- Reset-all now deletes both the current undo snapshot set and older multi-revision history snapshots.\n- Bump saved match provenance to schema v2 for the expanded v0.1.4 record.\n- Harden search-result and saved-refresh previews against malformed/nil provider fields and isolate `Writer.preview` exceptions.\n- Add consistent bounded numeric `Retry-After` cooldown handling to Hardcover, Amazon Creators API, Google Books, and Open Library.\n- Expand sanitized support diagnostics with defensively collected Lua/LuaJIT, runtime architecture/OS, optional KOReader version, and non-secret device family/model information.\n\n'''
s = s.replace(needle, addition, 1)
p.write_text(s)

print('Applied v0.1.4 stability round two')
