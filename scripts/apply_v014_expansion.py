#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def write(path, text):
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 anchor, found {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Matcher: structured explainable score components.
# ---------------------------------------------------------------------------
matcher = read("lib/matcher.lua")
matcher = replace_once(matcher,
'''local function add_reason(reasons, label)\n    table.insert(reasons, label)\nend\n''',
'''local function add_reason(reasons, label)\n    table.insert(reasons, label)\nend\n\nlocal function add_component(components, label, delta, cap, detail)\n    table.insert(components, {\n        label = label,\n        delta = delta,\n        cap = cap,\n        detail = detail,\n    })\nend\n''', "matcher component helper")
matcher = replace_once(matcher,
'''    local reasons = {}\n    local query_isbn = U.canonical_isbn(query.isbn)\n''',
'''    local reasons = {}\n    local components = {}\n    local query_isbn = U.canonical_isbn(query.isbn)\n''', "matcher components init")
matcher = replace_once(matcher,
'''    if isbn_matches(query, r) then\n        add_reason(reasons, "ISBN exact")\n        if has_format_conflict then\n            add_reason(reasons, "format conflict")\n            if qkind == "ebook" and rkind == "audiobook" then return 35, reasons end\n            return 65, reasons\n        end\n        if qkind and rkind and qkind == rkind then add_reason(reasons, "format match") end\n        return 100, reasons\n    end\n''',
'''    if isbn_matches(query, r) then\n        add_reason(reasons, "ISBN exact")\n        add_component(components, "ISBN exact", 100)\n        if has_format_conflict then\n            add_reason(reasons, "format conflict")\n            if qkind == "ebook" and rkind == "audiobook" then\n                add_component(components, "format conflict", nil, 35, qkind .. " vs " .. rkind)\n                return 35, reasons, components\n            end\n            add_component(components, "format conflict", nil, 65, qkind .. " vs " .. rkind)\n            return 65, reasons, components\n        end\n        if qkind and rkind and qkind == rkind then\n            add_reason(reasons, "format match")\n            add_component(components, "format match", 0, nil, qkind)\n        end\n        return 100, reasons, components\n    end\n''', "matcher exact ISBN")
matcher = replace_once(matcher,
'''    local isbn_conflict = query_isbn and result_isbn and query_isbn ~= result_isbn\n    if isbn_conflict then add_reason(reasons, "ISBN conflict") end\n''',
'''    local isbn_conflict = query_isbn and result_isbn and query_isbn ~= result_isbn\n    if isbn_conflict then\n        add_reason(reasons, "ISBN conflict")\n        add_component(components, "ISBN conflict", nil, 35)\n    end\n''', "matcher isbn conflict")
matcher = replace_once(matcher,
'''            score = score + 72\n            add_reason(reasons, "title exact")\n''',
'''            score = score + 72\n            add_reason(reasons, "title exact")\n            add_component(components, "title exact", 72)\n''', "matcher title exact")
matcher = replace_once(matcher,
'''            score = score + 60\n            add_reason(reasons, "title close")\n''',
'''            score = score + 60\n            add_reason(reasons, "title close")\n            add_component(components, "title close", 60)\n''', "matcher title close")
matcher = replace_once(matcher,
'''            local similarity = U.token_similarity(qtitle, rtitle)\n            score = score + math.floor(similarity * 62)\n            if similarity >= 0.75 then add_reason(reasons, "title similar") end\n''',
'''            local similarity = U.token_similarity(qtitle, rtitle)\n            local points = math.floor(similarity * 62)\n            score = score + points\n            if points ~= 0 then add_component(components, "title similarity", points, nil, string.format("%.0f%%", similarity * 100)) end\n            if similarity >= 0.75 then add_reason(reasons, "title similar") end\n''', "matcher title fuzzy")
matcher = replace_once(matcher,
'''            score = score + 23\n            add_reason(reasons, "author exact")\n''',
'''            score = score + 23\n            add_reason(reasons, "author exact")\n            add_component(components, "author exact", 23)\n''', "matcher author exact")
matcher = replace_once(matcher,
'''            score = score + 20\n            add_reason(reasons, "author close")\n''',
'''            score = score + 20\n            add_reason(reasons, "author close")\n            add_component(components, "author close", 20)\n''', "matcher author close")
matcher = replace_once(matcher,
'''            score = score + math.floor(similarity * 20)\n            if similarity >= 0.6 then\n                add_reason(reasons, "author similar")\n            elseif similarity < 0.2 then\n                score = math.max(0, score - 25)\n                add_reason(reasons, "author conflict")\n            end\n''',
'''            local points = math.floor(similarity * 20)\n            score = score + points\n            if points ~= 0 then add_component(components, "author similarity", points, nil, string.format("%.0f%%", similarity * 100)) end\n            if similarity >= 0.6 then\n                add_reason(reasons, "author similar")\n            elseif similarity < 0.2 then\n                local before = score\n                score = math.max(0, score - 25)\n                add_component(components, "author conflict", score - before)\n                add_reason(reasons, "author conflict")\n            end\n''', "matcher author fuzzy")
matcher = replace_once(matcher,
'''            score = score + 3\n            add_reason(reasons, "language")\n        elseif qlang and rlang and qlang ~= rlang then\n            score = math.max(0, score - 12)\n            add_reason(reasons, "language conflict")\n''',
'''            score = score + 3\n            add_reason(reasons, "language")\n            add_component(components, "language", 3)\n        elseif qlang and rlang and qlang ~= rlang then\n            local before = score\n            score = math.max(0, score - 12)\n            add_reason(reasons, "language conflict")\n            add_component(components, "language conflict", score - before, nil, qlang .. " vs " .. rlang)\n''', "matcher language")
matcher = replace_once(matcher,
'''            score = score + 4\n            add_reason(reasons, "series exact")\n''',
'''            score = score + 4\n            add_reason(reasons, "series exact")\n            add_component(components, "series exact", 4)\n''', "matcher series exact")
matcher = replace_once(matcher,
'''                score = score + 2\n                add_reason(reasons, "series similar")\n            elseif similarity < 0.25 then\n                score = math.max(0, score - 8)\n                add_reason(reasons, "series conflict")\n''',
'''                score = score + 2\n                add_reason(reasons, "series similar")\n                add_component(components, "series similar", 2)\n            elseif similarity < 0.25 then\n                local before = score\n                score = math.max(0, score - 8)\n                add_reason(reasons, "series conflict")\n                add_component(components, "series conflict", score - before)\n''', "matcher series")
matcher = replace_once(matcher,
'''            score = score + 2\n            add_reason(reasons, "year")\n        elseif math.abs(qyear - ryear) > 5 then\n            score = math.max(0, score - 5)\n            add_reason(reasons, "year conflict")\n        elseif math.abs(qyear - ryear) > 2 then\n            score = math.max(0, score - 2)\n''',
'''            score = score + 2\n            add_reason(reasons, "year")\n            add_component(components, "year", 2)\n        elseif math.abs(qyear - ryear) > 5 then\n            local before = score\n            score = math.max(0, score - 5)\n            add_reason(reasons, "year conflict")\n            add_component(components, "year conflict", score - before)\n        elseif math.abs(qyear - ryear) > 2 then\n            local before = score\n            score = math.max(0, score - 2)\n            add_component(components, "year difference", score - before)\n''', "matcher year")
matcher = replace_once(matcher,
'''            score = score + 3\n            add_reason(reasons, "format match")\n        else\n            add_reason(reasons, "format conflict")\n            if qkind == "ebook" and rkind == "audiobook" then\n                score = math.min(math.max(0, score - 45), 35)\n            else\n                score = math.min(math.max(0, score - 25), 65)\n            end\n''',
'''            score = score + 3\n            add_reason(reasons, "format match")\n            add_component(components, "format match", 3, nil, qkind)\n        else\n            add_reason(reasons, "format conflict")\n            local before = score\n            if qkind == "ebook" and rkind == "audiobook" then\n                score = math.min(math.max(0, score - 45), 35)\n                add_component(components, "format conflict", score - before, 35, qkind .. " vs " .. rkind)\n            else\n                score = math.min(math.max(0, score - 25), 65)\n                add_component(components, "format conflict", score - before, 65, qkind .. " vs " .. rkind)\n            end\n''', "matcher format")
matcher = replace_once(matcher,
'''    if isbn_conflict then score = math.min(score, 35) end\n\n    return math.min(99, score), reasons\nend\n''',
'''    if isbn_conflict then score = math.min(score, 35) end\n\n    if score > 99 then\n        add_component(components, "non-ISBN maximum", nil, 99)\n        score = 99\n    end\n    return score, reasons, components\nend\n''', "matcher final score")
matcher = replace_once(matcher,
'''    local ok, score, reasons = pcall(M.score, query, r)\n    if not ok or type(score) ~= "number" then return false end\n    r.score = score\n    r.match_reasons = type(reasons) == "table" and reasons or {}\n''',
'''    local ok, score, reasons, components = pcall(M.score, query, r)\n    if not ok or type(score) ~= "number" then return false end\n    r.score = score\n    r.match_reasons = type(reasons) == "table" and reasons or {}\n    r.score_components = type(components) == "table" and components or {}\n''', "matcher rescore")
write("lib/matcher.lua", matcher)


# ---------------------------------------------------------------------------
# Settings schema v3: persistent history state, omitted from safe exports.
# ---------------------------------------------------------------------------
settings = read("lib/settings.lua")
settings = settings.replace("SCHEMA_VERSION = 2", "SCHEMA_VERSION = 3", 1)
settings = replace_once(settings,
'''    undo_records = true,\n    provider_health = true,\n''',
'''    undo_records = true,\n    history_records = true,\n    provider_health = true,\n''', "settings runtime history")
settings = replace_once(settings,
'''    if schema < 2 then\n        out.update_channel = normalize_channel(out.update_channel)\n        if type(out.provider_health) ~= "table" then out.provider_health = {} end\n        schema = 2\n    end\n\n    out.update_channel = normalize_channel(out.update_channel)\n    if type(out.provider_health) ~= "table" then out.provider_health = {} end\n''',
'''    if schema < 2 then\n        out.update_channel = normalize_channel(out.update_channel)\n        if type(out.provider_health) ~= "table" then out.provider_health = {} end\n        schema = 2\n    end\n\n    if schema < 3 then\n        if type(out.history_records) ~= "table" then out.history_records = {} end\n        schema = 3\n    end\n\n    out.update_channel = normalize_channel(out.update_channel)\n    if type(out.provider_health) ~= "table" then out.provider_health = {} end\n    if type(out.history_records) ~= "table" then out.history_records = {} end\n''', "settings migration v3")
write("lib/settings.lua", settings)


# ---------------------------------------------------------------------------
# Google Books: exact saved-record retrieval by volume ID.
# ---------------------------------------------------------------------------
google = read("providers/googlebooks.lua")
google = replace_once(google,
'''local function request(q, settings, max_results)\n    if not U.nonempty(settings.google_api_key) then\n        return nil, "Google Books API key required. Add one under Provider accounts."\n    end\n    local url = "https://www.googleapis.com/books/v1/volumes?q=" .. U.urlencode(q)\n        .. "&printType=books&maxResults=" .. tostring(max_results or 8)\n        .. "&key=" .. U.urlencode(settings.google_api_key)\n    return HTTP.json("GET", url, {\n        ["User-Agent"] = Version.user_agent(),\n    })\nend\n''',
'''local function request_url(url, settings)\n    if not U.nonempty(settings.google_api_key) then\n        return nil, "Google Books API key required. Add one under Provider accounts."\n    end\n    local separator = url:find("?", 1, true) and "&" or "?"\n    url = url .. separator .. "key=" .. U.urlencode(settings.google_api_key)\n    return HTTP.json("GET", url, {\n        ["User-Agent"] = Version.user_agent(),\n    })\nend\n\nlocal function request(q, settings, max_results)\n    local url = "https://www.googleapis.com/books/v1/volumes?q=" .. U.urlencode(q)\n        .. "&printType=books&maxResults=" .. tostring(max_results or 8)\n    return request_url(url, settings)\nend\n\nlocal function normalize_item(item)\n    if type(item) ~= "table" then return nil end\n    local v = item.volumeInfo or {}\n    local ids = {}\n    for _, ident in ipairs(v.industryIdentifiers or {}) do table.insert(ids, ident.identifier) end\n    local isbn10, isbn13 = U.find_isbns(ids)\n    local images = v.imageLinks or {}\n    local cover = images.extraLarge or images.large or images.medium or images.thumbnail or images.smallThumbnail\n    if cover then cover = cover:gsub("^http://", "https://") end\n    return {\n        source = P.id, source_label = P.label, id = item.id,\n        title = v.title, subtitle = v.subtitle,\n        authors = v.authors or {}, authors_text = U.join(v.authors, "\\n"),\n        publisher = v.publisher, published_date = v.publishedDate,\n        description = v.description, language = v.language,\n        keywords = v.categories or {}, keywords_text = U.join(v.categories, "\\n"),\n        isbn10 = isbn10, isbn13 = isbn13, cover_url = cover,\n        raw = item,\n    }\nend\n''', "google request helper")
old_loop = '''    local out = {}\n    for _, item in ipairs((res.json and res.json.items) or {}) do\n        local v = item.volumeInfo or {}\n        local ids = {}\n        for _, ident in ipairs(v.industryIdentifiers or {}) do table.insert(ids, ident.identifier) end\n        local isbn10, isbn13 = U.find_isbns(ids)\n        local images = v.imageLinks or {}\n        local cover = images.extraLarge or images.large or images.medium or images.thumbnail or images.smallThumbnail\n        if cover then cover = cover:gsub("^http://", "https://") end\n        table.insert(out, {\n            source = P.id, source_label = P.label, id = item.id,\n            title = v.title, subtitle = v.subtitle,\n            authors = v.authors or {}, authors_text = U.join(v.authors, "\\n"),\n            publisher = v.publisher, published_date = v.publishedDate,\n            description = v.description, language = v.language,\n            keywords = v.categories or {}, keywords_text = U.join(v.categories, "\\n"),\n            isbn10 = isbn10, isbn13 = isbn13, cover_url = cover,\n            raw = item,\n        })\n    end\n    return out\nend\n'''
new_loop = '''    local out = {}\n    for _, item in ipairs((res.json and res.json.items) or {}) do\n        local normalized = normalize_item(item)\n        if normalized then table.insert(out, normalized) end\n    end\n    return out\nend\n\nfunction P.get_by_id(id, settings)\n    id = U.trim(tostring(id or ""))\n    if id == "" then return nil, "Saved Google Books volume ID is missing" end\n    local now = os.time()\n    if now < cooldown_until then\n        return nil, "Rate limited by Google Books; retry in about " .. tostring(math.max(1, cooldown_until - now)) .. " seconds"\n    end\n    local res, err = request_url("https://www.googleapis.com/books/v1/volumes/" .. U.urlencode(id), settings)\n    if not res then return nil, err end\n    local rate_error = handle_rate_limit(res)\n    if rate_error then return nil, rate_error end\n    if res.code == 404 then return nil, "Saved Google Books record no longer exists" end\n    if res.code ~= 200 then\n        local detail = error_details(res)\n        return nil, detail\n    end\n    backoff_step = 0\n    cooldown_until = 0\n    local record = normalize_item(res.json)\n    if not record or tostring(record.id or "") ~= id then return nil, "Google Books returned an unexpected saved record" end\n    return record\nend\n'''
google = replace_once(google, old_loop, new_loop, "google normalize loop")
write("providers/googlebooks.lua", google)


# ---------------------------------------------------------------------------
# Main UI/lifecycle expansion.
# ---------------------------------------------------------------------------
main = read("main.lua")
main = replace_once(main,
'''    book_links = {},\n    undo_records = {},\n}\n''',
'''    book_links = {},\n    undo_records = {},\n    history_records = {},\n}\n''', "main defaults history")
main = replace_once(main,
'''    d.book_links = {}\n    d.undo_records = {}\n    d.provider_health = {}\n''',
'''    d.book_links = {}\n    d.undo_records = {}\n    d.history_records = {}\n    d.provider_health = {}\n''', "main clone history")
main = replace_once(main,
'''        self.settings.book_links = saved.book_links or {}\n        self.settings.undo_records = saved.undo_records or {}\n        self.settings.provider_health = saved.provider_health or {}\n''',
'''        self.settings.book_links = saved.book_links or {}\n        self.settings.undo_records = saved.undo_records or {}\n        self.settings.history_records = saved.history_records or {}\n        self.settings.provider_health = saved.provider_health or {}\n''', "main load history")

main = replace_once(main,
'''local function confidence_label(value)\n    local labels = {\n        Exact = _("Exact"), Strong = _("Strong"), Possible = _("Possible"), Weak = _("Weak"),\n    }\n    return labels[value] or tostring(value or _("Unknown"))\nend\n''',
'''local function confidence_label(value)\n    local labels = {\n        Exact = _("Exact"), Strong = _("Strong"), Possible = _("Possible"), Weak = _("Weak"),\n    }\n    return labels[value] or tostring(value or _("Unknown"))\nend\n\nlocal function score_breakdown_text(components)\n    local parts = {}\n    for _, component in ipairs(type(components) == "table" and components or {}) do\n        local label = tostring(component.label or _("evidence"))\n        if component.delta ~= nil and tonumber(component.delta) ~= 0 then\n            local delta = tonumber(component.delta) or 0\n            label = label .. " " .. (delta > 0 and "+" or "") .. tostring(delta)\n        end\n        if component.cap ~= nil then label = label .. " ≤" .. tostring(component.cap) end\n        if component.detail and tostring(component.detail) ~= "" then label = label .. " (" .. tostring(component.detail) .. ")" end\n        table.insert(parts, label)\n    end\n    return table.concat(parts, "; ")\nend\n\nlocal function empty_field_selection()\n    return { title = false, authors = false, series = false, series_index = false, language = false, keywords = false, description = false }\nend\n''', "main score helpers")

# User-facing updater failure redaction.
main = main.replace('text = _("Update failed.") .. "\\n" .. tostring(err)', 'text = _("Update failed.") .. "\\n" .. Diagnostics.redact(err, self.settings)')

# Add refresh actions to book context.
main = replace_once(main,
'''    if self.settings.book_links[file] then\n        table.insert(rows, {{ text = _("Last match details"), align = "left", callback = function() self:showLastMatchDetails(file) end }})\n    end\n''',
'''    if self.settings.book_links[file] then\n        table.insert(rows, {{ text = _("Last match details"), align = "left", callback = function() self:showLastMatchDetails(file) end }})\n        local link = self.settings.book_links[file]\n        local provider = link and PROVIDERS[link.source]\n        if provider and type(provider.get_by_id) == "function" and link.id then\n            table.insert(rows, {{ text = _("Refresh saved metadata"), align = "left", callback = function() self:refreshSavedRecord(file, false) end }})\n            table.insert(rows, {{ text = _("Refresh saved cover only"), align = "left", callback = function() self:refreshSavedRecord(file, true) end }})\n        end\n    end\n    local older = self.settings.history_records and self.settings.history_records[file]\n    if type(older) == "table" and #older > 0 then\n        table.insert(rows, {{ text = string.format(_("Metadata history (%d older)"), #older), align = "left", callback = function() self:showMetadataHistory(file) end }})\n    end\n''', "book actions refresh/history")

# Replace undo management block with bounded multi-revision history.
old_undo = '''function MetadataScraper:pruneUndoRecords()\n    local records = self.settings.undo_records or {}\n    local ordered = {}\n    for file, record in pairs(records) do\n        table.insert(ordered, { file = file, created_at = tonumber(record.created_at) or 0 })\n    end\n    table.sort(ordered, function(a, b) return a.created_at < b.created_at end)\n    while #ordered > 20 do\n        local oldest = table.remove(ordered, 1)\n        local record = records[oldest.file]\n        if record then Writer.discard_snapshot(record.snapshot or record) end\n        records[oldest.file] = nil\n    end\nend\n\nfunction MetadataScraper:storeUndoRecord(file, snapshot, previous_link)\n    self.settings.undo_records = self.settings.undo_records or {}\n    local old = self.settings.undo_records[file]\n    if old then Writer.discard_snapshot(old.snapshot or old) end\n    self.settings.undo_records[file] = {\n        snapshot = snapshot,\n        previous_book_link = previous_link,\n        had_previous_link = previous_link ~= nil,\n        created_at = os.time(),\n    }\n    self:pruneUndoRecords()\nend\n'''
new_undo = '''function MetadataScraper:discardHistoryForFile(file)\n    self.settings.history_records = self.settings.history_records or {}\n    for _, record in ipairs(self.settings.history_records[file] or {}) do\n        Writer.discard_snapshot(record.snapshot or record)\n    end\n    self.settings.history_records[file] = nil\nend\n\nfunction MetadataScraper:pruneHistoryRecords()\n    self.settings.history_records = self.settings.history_records or {}\n    local all = {}\n    for file, records in pairs(self.settings.history_records) do\n        if type(records) == "table" then\n            while #records > 4 do\n                local record = table.remove(records, 1)\n                Writer.discard_snapshot(record.snapshot or record)\n            end\n            for index, record in ipairs(records) do\n                table.insert(all, { file = file, index = index, created_at = tonumber(record.created_at) or 0, record = record })\n            end\n        end\n    end\n    table.sort(all, function(a, b) return a.created_at < b.created_at end)\n    while #all > 30 do\n        local oldest = table.remove(all, 1)\n        local records = self.settings.history_records[oldest.file]\n        if records then\n            for i, record in ipairs(records) do\n                if record == oldest.record then\n                    Writer.discard_snapshot(record.snapshot or record)\n                    table.remove(records, i)\n                    break\n                end\n            end\n            if #records == 0 then self.settings.history_records[oldest.file] = nil end\n        end\n    end\nend\n\nfunction MetadataScraper:archiveUndoRecord(file, record)\n    if type(record) ~= "table" then return end\n    self.settings.history_records = self.settings.history_records or {}\n    self.settings.history_records[file] = self.settings.history_records[file] or {}\n    table.insert(self.settings.history_records[file], record)\n    self:pruneHistoryRecords()\nend\n\nfunction MetadataScraper:pruneUndoRecords()\n    local records = self.settings.undo_records or {}\n    local ordered = {}\n    for file, record in pairs(records) do\n        table.insert(ordered, { file = file, created_at = tonumber(record.created_at) or 0 })\n    end\n    table.sort(ordered, function(a, b) return a.created_at < b.created_at end)\n    while #ordered > 20 do\n        local oldest = table.remove(ordered, 1)\n        local record = records[oldest.file]\n        if record then Writer.discard_snapshot(record.snapshot or record) end\n        records[oldest.file] = nil\n        self:discardHistoryForFile(oldest.file)\n    end\nend\n\nfunction MetadataScraper:storeUndoRecord(file, snapshot, previous_link)\n    if type(snapshot) ~= "table" then return end\n    self.settings.undo_records = self.settings.undo_records or {}\n    local old = self.settings.undo_records[file]\n    if old then self:archiveUndoRecord(file, old) end\n    self.settings.undo_records[file] = {\n        snapshot = snapshot,\n        previous_book_link = previous_link,\n        had_previous_link = previous_link ~= nil,\n        created_at = os.time(),\n    }\n    self:pruneUndoRecords()\nend\n'''
main = replace_once(main, old_undo, new_undo, "main multi history")

# Provenance stores score component details.
main = replace_once(main,
'''        score = r.score,\n        confidence = r.confidence,\n        match_reasons = U.copy(r.match_reasons),\n''',
'''        score = r.score,\n        confidence = r.confidence,\n        match_reasons = U.copy(r.match_reasons),\n        score_components = U.copy(r.score_components),\n''', "provenance score components")
main = replace_once(main,
'''    if link.match_reasons and #link.match_reasons > 0 then\n        table.insert(lines, _("Match reasons") .. ": " .. U.join(link.match_reasons, ", "))\n    end\n''',
'''    if link.match_reasons and #link.match_reasons > 0 then\n        table.insert(lines, _("Match reasons") .. ": " .. U.join(link.match_reasons, ", "))\n    end\n    local breakdown = score_breakdown_text(link.score_components)\n    if breakdown ~= "" then table.insert(lines, _("Score breakdown") .. ": " .. breakdown) end\n''', "last match score breakdown")

# Undo promotion + history display + exact refresh.
main = replace_once(main,
'''            Writer.discard_snapshot(snapshot)\n            self.settings.undo_records[file] = nil\n            if record.had_previous_link then\n                self.settings.book_links[file] = record.previous_book_link\n            else\n                self.settings.book_links[file] = nil\n            end\n            self:saveSettings()\n            UIManager:show(InfoMessage:new{ text = _("Previous metadata and cover restored.") })\n''',
'''            Writer.discard_snapshot(snapshot)\n            local history = self.settings.history_records and self.settings.history_records[file]\n            local previous_undo = type(history) == "table" and table.remove(history) or nil\n            if type(history) == "table" and #history == 0 then self.settings.history_records[file] = nil end\n            self.settings.undo_records[file] = previous_undo\n            if record.had_previous_link then\n                self.settings.book_links[file] = record.previous_book_link\n            else\n                self.settings.book_links[file] = nil\n            end\n            self:saveSettings()\n            local remaining = previous_undo and _(" An older revision is still available to undo.") or ""\n            UIManager:show(InfoMessage:new{ text = _("Previous metadata and cover restored.") .. remaining })\n''', "undo history promotion")

insert_before_apply = '''function MetadataScraper:applyResult(file, raw, result, quiet, query, options)\n'''
refresh_block = '''function MetadataScraper:showMetadataHistory(file)\n    local history = self.settings.history_records and self.settings.history_records[file] or {}\n    local current = self.settings.undo_records and self.settings.undo_records[file]\n    local lines = { _("Metadata revision history"), "" }\n    if current then\n        table.insert(lines, _("Current undo point") .. ": " .. os.date("%Y-%m-%d %H:%M:%S", tonumber(current.created_at) or os.time()))\n    end\n    for i = #history, 1, -1 do\n        local record = history[i]\n        table.insert(lines, string.format(_("Older revision %d: %s"), #history - i + 1, os.date("%Y-%m-%d %H:%M:%S", tonumber(record.created_at) or os.time())))\n    end\n    table.insert(lines, "")\n    table.insert(lines, _("Use Undo last metadata update repeatedly to walk backward through these revisions."))\n    UIManager:show(InfoMessage:new{ text = table.concat(lines, "\\n") })\nend\n\nfunction MetadataScraper:showRefreshPreview(file, raw, query, result, cover_only)\n    local dialog\n    local fields = cover_only and empty_field_selection() or self.settings.fields\n    local changes, preview_err = Writer.preview(file, raw, result, fields, self.settings.replace_existing)\n    local rows = {\n        {{ text = _("Exact saved provider record") .. ": " .. tostring(result.source_label or result.source), align = "left", enabled = false }},\n    }\n    if cover_only then\n        table.insert(rows, {{ text = _("Refresh mode") .. ": " .. _("cover only"), align = "left", enabled = false }})\n    elseif changes then\n        table.insert(rows, {{ text = _("Current → Proposed"), align = "left", enabled = false }})\n        if #changes == 0 then\n            table.insert(rows, {{ text = _("No selected text fields need changing."), align = "left", enabled = false }})\n        else\n            for _, change in ipairs(changes) do\n                local label = _(PREVIEW_LABELS[change.key] or change.key)\n                local text = change.key == "description"\n                    and (label .. ": " .. (change.action == "add" and _("add description") or _("replace description")))\n                    or (label .. ": " .. display_value(change.current) .. " → " .. display_value(change.proposed))\n                table.insert(rows, {{ text = text, align = "left", enabled = false }})\n            end\n        end\n    else\n        table.insert(rows, {{ text = _("Change preview unavailable") .. ": " .. Diagnostics.redact(preview_err, self.settings), align = "left", enabled = false }})\n    end\n    table.insert(rows, {{ text = _("Cover") .. ": " .. (result.cover_url and _("available") or _("not available")), align = "left", enabled = false }})\n    table.insert(rows, {\n        { text = _("Cancel"), callback = function() UIManager:close(dialog) end },\n        { text = _("Apply refresh"), callback = function()\n            UIManager:close(dialog)\n            self:applyResult(file, raw, result, false, query, {\n                fields = fields,\n                download_cover = cover_only and true or self.settings.download_cover,\n                replace_existing = self.settings.replace_existing,\n            })\n        end },\n    })\n    dialog = ButtonDialog:new{ title = cover_only and _("Refresh saved cover") or _("Refresh saved metadata"), title_align = "center", buttons = rows }\n    UIManager:show(dialog)\nend\n\nfunction MetadataScraper:refreshSavedRecord(file, cover_only)\n    local link = self.settings.book_links and self.settings.book_links[file]\n    local provider = link and PROVIDERS[link.source]\n    if not link or not provider or type(provider.get_by_id) ~= "function" or not link.id then\n        UIManager:show(InfoMessage:new{ text = _("This saved match does not support exact-record refresh yet.") })\n        return\n    end\n    NetworkMgr:runWhenOnline(function()\n        local busy = InfoMessage:new{ text = _("Refreshing saved provider record…") }\n        UIManager:show(busy); UIManager:forceRePaint()\n        local ok, result, err = pcall(provider.get_by_id, link.id, self.settings)\n        UIManager:close(busy)\n        if not ok or type(result) ~= "table" then\n            local message = Diagnostics.redact(ok and err or result, self.settings)\n            Diagnostics.log(provider.label, message, self.settings, { operation = "refresh", status = "error" })\n            UIManager:show(InfoMessage:new{\n                text = _("The exact saved provider record could not be refreshed.") .. "\\n" .. message\n                    .. "\\n\\n" .. _("Use Fetch metadata to search again; Metadata Scraper will not silently substitute a different edition."),\n            })\n            return\n        end\n        if tostring(result.id or "") ~= tostring(link.id) or result.source ~= link.source then\n            UIManager:show(InfoMessage:new{ text = _("Provider returned a different record; refresh was cancelled.") })\n            return\n        end\n        Diagnostics.log(provider.label, "exact saved record refreshed", self.settings, { operation = "refresh", status = "ok", result_count = 1 })\n        local raw = self:getRawProps(file)\n        local query = U.copy(link.query or {})\n        query.media_kind = query.media_kind or "ebook"\n        self:showRefreshPreview(file, raw, query, result, cover_only == true)\n    end)\nend\n\n'''
main = replace_once(main, insert_before_apply, refresh_block + insert_before_apply, "refresh functions")

# Preview score breakdown.
main = replace_once(main,
'''    info(_("Confidence"), confidence_label(r.confidence))\n    if r.also_sources and #r.also_sources > 0 then info(_("Also found on"), U.join(r.also_sources, ", ")) end\n''',
'''    info(_("Confidence"), confidence_label(r.confidence))\n    local breakdown = score_breakdown_text(r.score_components)\n    if breakdown ~= "" then info(_("Score breakdown"), breakdown) end\n    if r.also_sources and #r.also_sources > 0 then info(_("Also found on"), U.join(r.also_sources, ", ")) end\n''', "preview score breakdown")

# Interactive batch review.
old_show_plan = '''function MetadataScraper:showBatchPlan(plan)\n    if #plan.apply == 0 then\n        UIManager:show(InfoMessage:new{\n            text = string.format(_("Batch discovery complete.\\n\\nReady to apply: 0\\nLow/no match: %d\\nAlready matched: %d\\nSearch failures: %d\\n\\nNo metadata was changed."),\n                plan.skipped, plan.already_matched, plan.failed),\n        })\n        return\n    end\n\n    local box\n    box = ConfirmBox:new{\n        text = string.format(_("Batch discovery complete.\\n\\nReady to apply: %d\\nLow/no match: %d\\nAlready matched: %d\\nSearch failures: %d\\n\\nApply the %d proposed high-confidence matches now?"),\n            #plan.apply, plan.skipped, plan.already_matched, plan.failed, #plan.apply),\n        ok_text = _("Apply"),\n        ok_callback = function()\n            UIManager:close(box)\n            self:applyBatchPlan(plan)\n        end,\n    }\n    UIManager:show(box)\nend\n'''
new_show_plan = '''local function selected_batch_count(plan)\n    local selected = 0\n    for _, entry in ipairs(plan.apply or {}) do\n        if entry.selected ~= false then selected = selected + 1 end\n    end\n    return selected\nend\n\nfunction MetadataScraper:showBatchReview(plan)\n    local dialog\n    local function render()\n        local rows = {}\n        for _, entry in ipairs(plan.apply or {}) do\n            local r = entry.result or {}\n            local title = tostring(r.title or (entry.query and entry.query.title) or entry.file)\n            local source = tostring(r.source_label or r.source or "")\n            local marker = entry.selected == false and "○ " or "✓ "\n            local text = marker .. title .. "\\n" .. tostring(r.score or 0) .. "% " .. confidence_label(r.confidence) .. " · " .. source\n            table.insert(rows, {{\n                text = text, align = "left",\n                callback = function()\n                    entry.selected = entry.selected == false\n                    UIManager:close(dialog)\n                    UIManager:nextTick(render)\n                end,\n            }})\n        end\n        local selected = selected_batch_count(plan)\n        table.insert(rows, {\n            { text = _("Back"), callback = function() UIManager:close(dialog); self:showBatchPlan(plan) end },\n            { text = string.format(_("Apply selected (%d)"), selected), callback = function()\n                if selected == 0 then\n                    UIManager:show(InfoMessage:new{ text = _("No proposed matches are selected. No metadata was changed.") })\n                    return\n                end\n                UIManager:close(dialog)\n                self:applyBatchPlan(plan)\n            end },\n        })\n        dialog = ButtonDialog:new{ title = _("Review batch matches"), title_align = "center", buttons = rows }\n        UIManager:show(dialog)\n    end\n    render()\nend\n\nfunction MetadataScraper:showBatchPlan(plan)\n    if #plan.apply == 0 then\n        UIManager:show(InfoMessage:new{\n            text = string.format(_("Batch discovery complete.\\n\\nReady to apply: 0\\nLow/no match: %d\\nAlready matched: %d\\nSearch failures: %d\\n\\nNo metadata was changed."),\n                plan.skipped, plan.already_matched, plan.failed),\n        })\n        return\n    end\n\n    local selected = selected_batch_count(plan)\n    local dialog\n    dialog = ButtonDialog:new{\n        title = _("Batch discovery complete"),\n        title_align = "center",\n        buttons = {\n            {{ text = string.format(_("Selected: %d of %d ready · Low/no match: %d · Already matched: %d · Search failures: %d"),\n                selected, #plan.apply, plan.skipped, plan.already_matched, plan.failed), align = "left", enabled = false }},\n            {{ text = _("Review proposed matches…"), align = "left", callback = function() UIManager:close(dialog); self:showBatchReview(plan) end }},\n            {\n                { text = _("Cancel"), callback = function() UIManager:close(dialog) end },\n                { text = string.format(_("Apply selected (%d)"), selected), callback = function()\n                    if selected == 0 then\n                        UIManager:show(InfoMessage:new{ text = _("No proposed matches are selected. No metadata was changed.") })\n                        return\n                    end\n                    UIManager:close(dialog)\n                    self:applyBatchPlan(plan)\n                end },\n            },\n        },\n    }\n    UIManager:show(dialog)\nend\n'''
main = replace_once(main, old_show_plan, new_show_plan, "interactive batch plan")

main = replace_once(main,
'''                    table.insert(plan.apply, {\n                        file = file,\n                        raw = raw,\n                        query = q,\n                        result = best,\n                        options = batch_options,\n                    })\n''',
'''                    table.insert(plan.apply, {\n                        file = file,\n                        raw = raw,\n                        query = q,\n                        result = best,\n                        options = batch_options,\n                        selected = true,\n                    })\n''', "batch selected default")

old_apply_batch = '''function MetadataScraper:applyBatchPlan(plan)\n    NetworkMgr:runWhenOnline(function()\n        local applied, failed = 0, 0\n        for i, entry in ipairs(plan.apply or {}) do\n            local title = (entry.result and entry.result.title) or (entry.query and entry.query.title) or entry.file\n            local busy = InfoMessage:new{ text = string.format(_("Applying %d/%d\\n%s"), i, #plan.apply, tostring(title or "")) }\n            UIManager:show(busy); UIManager:forceRePaint()\n            local ok = self:applyResult(entry.file, entry.raw, entry.result, true, entry.query, entry.options or plan.options)\n            UIManager:close(busy)\n            if ok then applied = applied + 1 else failed = failed + 1 end\n        end\n        UIManager:show(InfoMessage:new{\n            text = string.format(_("Batch complete.\\nApplied: %d\\nNot applied: %d\\nAlready matched: %d\\nSearch failures: %d\\nApply failures: %d"),\n                applied, plan.skipped or 0, plan.already_matched or 0, plan.failed or 0, failed),\n        })\n    end)\nend\n'''
new_apply_batch = '''function MetadataScraper:applyBatchPlan(plan)\n    NetworkMgr:runWhenOnline(function()\n        local applied, failed, review_skipped = 0, 0, 0\n        local selected = selected_batch_count(plan)\n        local position = 0\n        for _, entry in ipairs(plan.apply or {}) do\n            if entry.selected == false then\n                review_skipped = review_skipped + 1\n            else\n                position = position + 1\n                local title = (entry.result and entry.result.title) or (entry.query and entry.query.title) or entry.file\n                local busy = InfoMessage:new{ text = string.format(_("Applying %d/%d\\n%s"), position, selected, tostring(title or "")) }\n                UIManager:show(busy); UIManager:forceRePaint()\n                local ok = self:applyResult(entry.file, entry.raw, entry.result, true, entry.query, entry.options or plan.options)\n                UIManager:close(busy)\n                if ok then applied = applied + 1 else failed = failed + 1 end\n            end\n        end\n        UIManager:show(InfoMessage:new{\n            text = string.format(_("Batch complete.\\nApplied: %d\\nLow/no match: %d\\nReview skipped: %d\\nAlready matched: %d\\nSearch failures: %d\\nApply failures: %d"),\n                applied, plan.skipped or 0, review_skipped, plan.already_matched or 0, plan.failed or 0, failed),\n        })\n    end)\nend\n'''
main = replace_once(main, old_apply_batch, new_apply_batch, "apply selected batch")

# Main menu refresh/history actions after Last match details.
main = replace_once(main,
'''            {\n                text = _("Last match details"),\n                enabled_func = function()\n                    local f = self:getCurrentFile()\n                    return f and self.settings.book_links and self.settings.book_links[f] ~= nil\n                end,\n                keep_menu_open = true,\n                callback = function() self:showLastMatchDetails(self:getCurrentFile()) end,\n            },\n''',
'''            {\n                text = _("Last match details"),\n                enabled_func = function()\n                    local f = self:getCurrentFile()\n                    return f and self.settings.book_links and self.settings.book_links[f] ~= nil\n                end,\n                keep_menu_open = true,\n                callback = function() self:showLastMatchDetails(self:getCurrentFile()) end,\n            },\n            {\n                text = _("Refresh saved metadata"),\n                enabled_func = function()\n                    local f = self:getCurrentFile()\n                    local link = f and self.settings.book_links and self.settings.book_links[f]\n                    return link and PROVIDERS[link.source] and type(PROVIDERS[link.source].get_by_id) == "function" and link.id ~= nil\n                end,\n                keep_menu_open = true,\n                callback = function() self:refreshSavedRecord(self:getCurrentFile(), false) end,\n            },\n            {\n                text = _("Refresh saved cover only"),\n                enabled_func = function()\n                    local f = self:getCurrentFile()\n                    local link = f and self.settings.book_links and self.settings.book_links[f]\n                    return link and PROVIDERS[link.source] and type(PROVIDERS[link.source].get_by_id) == "function" and link.id ~= nil\n                end,\n                keep_menu_open = true,\n                callback = function() self:refreshSavedRecord(self:getCurrentFile(), true) end,\n            },\n            {\n                text = _("Metadata history"),\n                enabled_func = function()\n                    local f = self:getCurrentFile()\n                    local history = f and self.settings.history_records and self.settings.history_records[f]\n                    return type(history) == "table" and #history > 0\n                end,\n                keep_menu_open = true,\n                callback = function() self:showMetadataHistory(self:getCurrentFile()) end,\n            },\n''', "main menu refresh/history")
write("main.lua", main)


# ---------------------------------------------------------------------------
# Tests: new capabilities and source-level safety guards.
# ---------------------------------------------------------------------------
test = r'''package.path = "./?.lua;./?/init.lua;" .. package.path

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
'''
write("tests/v014_expansion.lua", test)

# Add suite to CI after v014 roadmap tests.
workflow = read(".github/workflows/lua-checks.yml")
workflow = replace_once(workflow,
'''          lua5.1 tests/v014_roadmap.lua\n''',
'''          lua5.1 tests/v014_roadmap.lua\n          lua5.1 tests/v014_expansion.lua\n''', "CI expansion test")
write(".github/workflows/lua-checks.yml", workflow)

# Update checklist to record expedited roadmap work accurately.
checklist = read("docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md")
checklist = checklist.replace("- [ ] Continue healthy providers while another is cooling down.", "- [x] Continue healthy providers while another is cooling down — provider failures/cooldowns remain isolated per provider and do not abort the search loop.", 1)
checklist = checklist.replace("- [ ] Never echo secret values in errors.", "- [x] Never intentionally echo configured secret values in provider/updater refresh errors; user-visible failure paths use diagnostics redaction.", 1)
checklist = checklist.replace("- [ ] Explicit positive/negative component structure.", "- [x] Explicit positive/negative component structure — expedited to v0.1.4.", 1)
checklist = checklist.replace("- [ ] Human-readable numeric breakdown.", "- [x] Human-readable numeric breakdown in match preview/provenance — expedited to v0.1.4.", 1)
checklist = checklist.replace("- [ ] List proposed entries individually.", "- [x] List proposed ready entries individually — expedited to v0.1.4.", 1)
checklist = checklist.replace("- [ ] Allow deselecting a ready row.", "- [x] Allow deselecting a ready row before Apply — expedited to v0.1.4.", 1)
checklist = checklist.replace("- [ ] Cancel review with zero writes.", "- [x] Cancel review with zero writes — expedited to v0.1.4.", 1)
checklist = checklist.replace("- [ ] Preserve two-phase summary as simple/default path.", "- [x] Preserve two-phase summary as simple/default path — expedited to v0.1.4.", 1)
checklist = checklist.replace("- [ ] Bounded multi-revision metadata history beyond one-step undo.", "- [x] Bounded multi-revision metadata history beyond one-step undo — expedited to v0.1.4; repeated Undo walks backward through retained revisions.", 1)
checklist = checklist.replace("- [ ] Provider `get_by_id`/detail capability where feasible.", "- [~] Provider `get_by_id`/detail capability where feasible — Google Books exact volume-ID refresh expedited to v0.1.4; other providers remain future work.", 1)
checklist = checklist.replace("- [ ] Stale provider ID offers new search rather than silently selecting another edition.", "- [x] Stale supported provider ID reports failure and directs the user to a new search instead of silently selecting another edition — expedited to v0.1.4.", 1)
checklist = checklist.replace("- [ ] **Refresh metadata**.", "- [~] **Refresh metadata** — exact saved Google Books records supported in v0.1.4; broader providers remain v0.2.0.", 1)
checklist = checklist.replace("- [ ] **Refresh cover only**.", "- [~] **Refresh cover only** — exact saved Google Books records supported in v0.1.4; broader providers remain v0.2.0.", 1)
checklist = checklist.replace("- [ ] Current→Proposed preview before refresh write.", "- [x] Current→Proposed preview before supported exact-record refresh write — expedited to v0.1.4.", 1)
write("docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md", checklist)

# Changelog and README notes.
changelog = read("CHANGELOG.md")
anchor = "## [0.1.4] - Unreleased\n"
addition = '''## [0.1.4] - Unreleased\n\n### Expedited roadmap foundations\n\n- Added structured positive/negative/cap score components and a human-readable numeric score breakdown in match preview and saved provenance.\n- Added an interactive, write-free batch review screen where ready matches can be individually deselected before the second Apply confirmation.\n- Expanded one-step Undo into a bounded revision chain: up to four older snapshots per book and 30 older snapshots globally, with repeated Undo walking backward through retained revisions.\n- Added exact saved-record refresh capability for Google Books volume IDs, including **Refresh saved metadata** and **Refresh saved cover only** with Current → Proposed review. A missing/stale saved ID never silently falls back to a fuzzy replacement.\n- Hardened additional user-visible updater/refresh error paths through diagnostics redaction.\n'''
changelog = replace_once(changelog, anchor, addition, "changelog expansion")
write("CHANGELOG.md", changelog)

readme = read("README.md")
readme_anchor = "## Highlights in v0.1.3\n"
readme_insert = '''## v0.1.4 development additions\n\nThe current v0.1.4 development branch also includes foundations pulled forward from the later roadmap: explainable numeric match-score components, an interactive batch review/deselect step, bounded multi-revision Undo history, and exact saved Google Books record refresh for metadata or cover-only updates. These remain unreleased until v0.1.4 is finalized.\n\n'''
readme = replace_once(readme, readme_anchor, readme_insert + readme_anchor, "README development additions")
write("README.md", readme)

print("Applied v0.1.4 roadmap expansion")
