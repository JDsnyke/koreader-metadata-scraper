local U = require("lib/util")
local M = {}

local function canonical_result_isbn(r)
    return U.canonical_isbn(r.isbn13) or U.canonical_isbn(r.isbn10)
end

local function isbn_matches(query, r)
    local q = U.canonical_isbn(query.isbn)
    if not q then return false end
    return q == U.canonical_isbn(r.isbn13) or q == U.canonical_isbn(r.isbn10)
end

local function add_reason(reasons, label)
    table.insert(reasons, label)
end

local function add_component(components, label, delta, cap, detail)
    table.insert(components, {
        label = label,
        delta = delta,
        cap = cap,
        detail = detail,
    })
end

local function reason_set(reasons)
    local out = {}
    for _, reason in ipairs(reasons or {}) do out[reason] = true end
    return out
end

local function media_kind(value)
    if value == "ebook" or value == "print" or value == "audiobook" then return value end
    return U.format_kind(value)
end

local function result_media_kind(r)
    return media_kind(r.media_kind) or U.format_kind(r.format) or U.format_kind(r.binding) or U.format_kind(r.edition)
end

local function edition_conflict(query, r)
    local qkind = media_kind(query.media_kind or query.format)
    local rkind = result_media_kind(r)
    if qkind and rkind and qkind ~= rkind then return qkind, rkind end
    return qkind, rkind
end

function M.confidence(score, reasons)
    score = tonumber(score) or 0
    local set = reason_set(reasons)

    if set["ISBN exact"] and score == 100 and not set["format conflict"] then return "Exact" end
    if set["ISBN conflict"] or set["format conflict"] then return "Weak" end

    local hard_conflict = set["author conflict"] or set["language conflict"] or set["series conflict"]
    if score >= 90 and not hard_conflict then return "Strong" end
    if score >= 65 and not set["author conflict"] then return "Possible" end
    return "Weak"
end

function M.score(query, r)
    query = type(query) == "table" and query or {}
    r = type(r) == "table" and r or {}

    local reasons = {}
    local components = {}
    local query_isbn = U.canonical_isbn(query.isbn)
    local result_isbn = canonical_result_isbn(r)
    local qkind, rkind = edition_conflict(query, r)
    local has_format_conflict = qkind and rkind and qkind ~= rkind

    if isbn_matches(query, r) then
        add_reason(reasons, "ISBN exact")
        add_component(components, "ISBN exact", 100)
        if has_format_conflict then
            add_reason(reasons, "format conflict")
            if qkind == "ebook" and rkind == "audiobook" then
                add_component(components, "format conflict", nil, 35, qkind .. " vs " .. rkind)
                return 35, reasons, components
            end
            add_component(components, "format conflict", nil, 65, qkind .. " vs " .. rkind)
            return 65, reasons, components
        end
        if qkind and rkind and qkind == rkind then
            add_reason(reasons, "format match")
            add_component(components, "format match", 0, nil, qkind)
        end
        return 100, reasons, components
    end

    local isbn_conflict = query_isbn and result_isbn and query_isbn ~= result_isbn
    if isbn_conflict then
        add_reason(reasons, "ISBN conflict")
        add_component(components, "ISBN conflict", nil, 35)
    end

    local qtitle = U.normalize(query.title)
    local rtitle = U.normalize(r.title)
    local score = 0
    if qtitle ~= "" and rtitle ~= "" then
        if qtitle == rtitle then
            score = score + 72
            add_reason(reasons, "title exact")
            add_component(components, "title exact", 72)
        elseif qtitle:find(rtitle, 1, true) or rtitle:find(qtitle, 1, true) then
            score = score + 60
            add_reason(reasons, "title close")
            add_component(components, "title close", 60)
        else
            local similarity = U.token_similarity(qtitle, rtitle)
            local points = math.floor(similarity * 62)
            score = score + points
            if points ~= 0 then add_component(components, "title similarity", points, nil, string.format("%.0f%%", similarity * 100)) end
            if similarity >= 0.75 then add_reason(reasons, "title similar") end
        end
    end

    local qa = U.normalize_author(query.author)
    local ra = U.normalize_author(r.authors_text or U.join(r.authors, " "))
    if qa ~= "" and ra ~= "" then
        local similarity = U.author_similarity(qa, ra)
        if similarity >= 0.999 then
            score = score + 23
            add_reason(reasons, "author exact")
            add_component(components, "author exact", 23)
        elseif qa:find(ra, 1, true) or ra:find(qa, 1, true) or similarity >= 0.8 then
            score = score + 20
            add_reason(reasons, "author close")
            add_component(components, "author close", 20)
        else
            local points = math.floor(similarity * 20)
            score = score + points
            if points ~= 0 then add_component(components, "author similarity", points, nil, string.format("%.0f%%", similarity * 100)) end
            if similarity >= 0.6 then
                add_reason(reasons, "author similar")
            elseif similarity < 0.2 then
                local before = score
                score = math.max(0, score - 25)
                add_component(components, "author conflict", score - before)
                add_reason(reasons, "author conflict")
            end
        end
    end

    if query.language and r.language then
        local qlang = U.language_code(query.language)
        local rlang = U.language_code(r.language)
        if qlang and rlang and qlang == rlang then
            score = score + 3
            add_reason(reasons, "language")
            add_component(components, "language", 3)
        elseif qlang and rlang and qlang ~= rlang then
            local before = score
            score = math.max(0, score - 12)
            add_reason(reasons, "language conflict")
            add_component(components, "language conflict", score - before, nil, qlang .. " vs " .. rlang)
        end
    end

    local qseries = U.normalize(query.series)
    local rseries = U.normalize(r.series)
    if qseries ~= "" and rseries ~= "" then
        if qseries == rseries then
            score = score + 4
            add_reason(reasons, "series exact")
            add_component(components, "series exact", 4)
        else
            local similarity = U.token_similarity(qseries, rseries)
            if similarity >= 0.75 then
                score = score + 2
                add_reason(reasons, "series similar")
                add_component(components, "series similar", 2)
            elseif similarity < 0.25 then
                local before = score
                score = math.max(0, score - 8)
                add_reason(reasons, "series conflict")
                add_component(components, "series conflict", score - before)
            end
        end
    end

    local qyear = U.year(query.published_date or query.year)
    local ryear = U.year(r.published_date)
    if qyear and ryear then
        if qyear == ryear then
            score = score + 2
            add_reason(reasons, "year")
            add_component(components, "year", 2)
        elseif math.abs(qyear - ryear) > 5 then
            local before = score
            score = math.max(0, score - 5)
            add_reason(reasons, "year conflict")
            add_component(components, "year conflict", score - before)
        elseif math.abs(qyear - ryear) > 2 then
            local before = score
            score = math.max(0, score - 2)
            add_component(components, "year difference", score - before)
        end
    end

    if qkind and rkind then
        if qkind == rkind then
            score = score + 3
            add_reason(reasons, "format match")
            add_component(components, "format match", 3, nil, qkind)
        else
            add_reason(reasons, "format conflict")
            local before = score
            if qkind == "ebook" and rkind == "audiobook" then
                score = math.min(math.max(0, score - 45), 35)
                add_component(components, "format conflict", score - before, 35, qkind .. " vs " .. rkind)
            else
                score = math.min(math.max(0, score - 25), 65)
                add_component(components, "format conflict", score - before, 65, qkind .. " vs " .. rkind)
            end
        end
    end

    -- A contradictory ISBN is stronger evidence than fuzzy textual agreement.
    -- Keep the result visible for manual review, but never allow it near the
    -- default automatic batch threshold.
    if isbn_conflict then score = math.min(score, 35) end

    if score > 99 then
        add_component(components, "non-ISBN maximum", nil, 99)
        score = 99
    end
    return score, reasons, components
end

local function dedupe_key(r)
    local isbn = canonical_result_isbn(r)
    if isbn then return "isbn:" .. isbn end

    local title = U.normalize(r.title)
    local author = U.normalize_author(U.first(r.authors) or r.authors_text)
    if title ~= "" then return "book:" .. title .. "|" .. author end

    return "source:" .. tostring(r.source or "") .. ":" .. tostring(r.id or r)
end

local function is_empty_array(v)
    return type(v) ~= "table" or #v == 0
end

local function mergeable_scalar(value)
    local kind = type(value)
    return (kind == "string" and value ~= "") or kind == "number"
end

local function merge_missing(primary, extra)
    local scalar_fields = {
        "subtitle", "series", "series_index", "description", "published_date", "language",
        "isbn10", "isbn13", "cover_url", "publisher", "pages",
        "format", "binding", "edition", "media_kind",
    }
    for _, key in ipairs(scalar_fields) do
        if (primary[key] == nil or primary[key] == "") and mergeable_scalar(extra[key]) then
            primary[key] = extra[key]
        end
    end

    if is_empty_array(primary.authors) and not is_empty_array(extra.authors) then
        primary.authors = extra.authors
        primary.authors_text = extra.authors_text
    end
    if is_empty_array(primary.keywords) and not is_empty_array(extra.keywords) then
        primary.keywords = extra.keywords
        primary.keywords_text = extra.keywords_text
    end

    primary.also_sources = primary.also_sources or {}
    local label = extra.source_label or extra.source
    if label then
        local seen = {}
        for _, v in ipairs(primary.also_sources) do seen[v] = true end
        local primary_label = primary.source_label or primary.source
        if label ~= primary_label and not seen[label] then table.insert(primary.also_sources, label) end
    end
end

local function rank_sorter(source_priority)
    return function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        local pa = source_priority[a.source] or 99
        local pb = source_priority[b.source] or 99
        if pa ~= pb then return pa < pb end
        return tostring(a.title or "") < tostring(b.title or "")
    end
end

local function rescore(query, r)
    local ok, score, reasons, components = pcall(M.score, query, r)
    if not ok or type(score) ~= "number" then return false end
    r.score = score
    r.match_reasons = type(reasons) == "table" and reasons or {}
    r.score_components = type(components) == "table" and components or {}
    r.confidence = M.confidence(score, r.match_reasons)
    r.media_kind = r.media_kind or result_media_kind(r)
    return true
end

function M.rank(query, results, source_priority)
    source_priority = source_priority or {}
    if type(results) ~= "table" then return {} end

    -- Treat every provider result as untrusted input. A malformed record should be
    -- discarded rather than preventing healthy provider results from being shown.
    local valid = {}
    for _, r in ipairs(results) do
        if type(r) == "table" and rescore(query, r) then
            table.insert(valid, r)
        end
    end

    table.sort(valid, rank_sorter(source_priority))

    local deduped, by_key = {}, {}
    for _, r in ipairs(valid) do
        local ok, key = pcall(dedupe_key, r)
        if ok and key then
            local primary = by_key[key]
            if primary then
                pcall(merge_missing, primary, r)
            else
                by_key[key] = r
                table.insert(deduped, r)
            end
        else
            -- A valid scored result with an unexpected dedupe shape is still useful.
            table.insert(deduped, r)
        end
    end

    -- Deduplication can add previously missing edition/format/language/series
    -- evidence from another provider. Re-score after the merge so display and
    -- automatic batch eligibility always reflect the final merged candidate.
    local rescored = {}
    for _, r in ipairs(deduped) do
        if rescore(query, r) then table.insert(rescored, r) end
    end
    table.sort(rescored, rank_sorter(source_priority))

    for i = #results, 1, -1 do results[i] = nil end
    for _, r in ipairs(rescored) do table.insert(results, r) end
    return results
end

return M
