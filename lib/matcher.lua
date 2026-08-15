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

function M.score(query, r)
    query = type(query) == "table" and query or {}
    r = type(r) == "table" and r or {}

    local reasons = {}
    local query_isbn = U.canonical_isbn(query.isbn)
    local result_isbn = canonical_result_isbn(r)
    if isbn_matches(query, r) then
        add_reason(reasons, "ISBN exact")
        return 100, reasons
    end

    local isbn_conflict = query_isbn and result_isbn and query_isbn ~= result_isbn
    if isbn_conflict then add_reason(reasons, "ISBN conflict") end

    local qtitle = U.normalize(query.title)
    local rtitle = U.normalize(r.title)
    local score = 0
    if qtitle ~= "" and rtitle ~= "" then
        if qtitle == rtitle then
            score = score + 72
            add_reason(reasons, "title exact")
        elseif qtitle:find(rtitle, 1, true) or rtitle:find(qtitle, 1, true) then
            score = score + 60
            add_reason(reasons, "title close")
        else
            local similarity = U.token_similarity(qtitle, rtitle)
            score = score + math.floor(similarity * 62)
            if similarity >= 0.75 then add_reason(reasons, "title similar") end
        end
    end

    local qa = U.normalize(query.author)
    local ra = U.normalize(r.authors_text or U.join(r.authors, " "))
    if qa ~= "" and ra ~= "" then
        if qa == ra then
            score = score + 23
            add_reason(reasons, "author exact")
        elseif qa:find(ra, 1, true) or ra:find(qa, 1, true) then
            score = score + 20
            add_reason(reasons, "author close")
        else
            local similarity = U.token_similarity(qa, ra)
            score = score + math.floor(similarity * 20)
            if similarity >= 0.6 then
                add_reason(reasons, "author similar")
            elseif similarity < 0.2 then
                score = math.max(0, score - 25)
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
        elseif qlang and rlang and qlang ~= rlang then
            score = math.max(0, score - 12)
            add_reason(reasons, "language conflict")
        end
    end

    local qseries = U.normalize(query.series)
    local rseries = U.normalize(r.series)
    if qseries ~= "" and rseries ~= "" then
        if qseries == rseries then
            score = score + 4
            add_reason(reasons, "series exact")
        else
            local similarity = U.token_similarity(qseries, rseries)
            if similarity >= 0.75 then
                score = score + 2
                add_reason(reasons, "series similar")
            elseif similarity < 0.25 then
                score = math.max(0, score - 8)
                add_reason(reasons, "series conflict")
            end
        end
    end

    local qyear = U.year(query.published_date or query.year)
    local ryear = U.year(r.published_date)
    if qyear and ryear then
        if qyear == ryear then
            score = score + 2
            add_reason(reasons, "year")
        elseif math.abs(qyear - ryear) > 5 then
            score = math.max(0, score - 5)
            add_reason(reasons, "year conflict")
        elseif math.abs(qyear - ryear) > 2 then
            score = math.max(0, score - 2)
        end
    end

    -- A contradictory ISBN is stronger evidence than fuzzy textual agreement.
    -- Keep the result visible for manual review, but never allow it near the
    -- default automatic batch threshold.
    if isbn_conflict then score = math.min(score, 35) end

    return math.min(99, score), reasons
end

local function dedupe_key(r)
    local isbn = canonical_result_isbn(r)
    if isbn then return "isbn:" .. isbn end

    local title = U.normalize(r.title)
    local author = U.normalize(U.first(r.authors) or r.authors_text)
    if title ~= "" then return "book:" .. title .. "|" .. author end

    return "source:" .. tostring(r.source or "") .. ":" .. tostring(r.id or r)
end

local function is_empty_array(v)
    return type(v) ~= "table" or #v == 0
end

local function merge_missing(primary, extra)
    local scalar_fields = {
        "subtitle", "series", "series_index", "description", "published_date", "language",
        "isbn10", "isbn13", "cover_url", "publisher", "pages",
    }
    for _, key in ipairs(scalar_fields) do
        if (primary[key] == nil or primary[key] == "") and extra[key] ~= nil and extra[key] ~= "" then
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

function M.rank(query, results, source_priority)
    source_priority = source_priority or {}
    if type(results) ~= "table" then return {} end

    -- Treat every provider result as untrusted input. A malformed record should be
    -- discarded rather than preventing healthy provider results from being shown.
    local valid = {}
    for _, r in ipairs(results) do
        if type(r) == "table" then
            local ok, score, reasons = pcall(M.score, query, r)
            if ok and type(score) == "number" then
                r.score = score
                r.match_reasons = type(reasons) == "table" and reasons or {}
                table.insert(valid, r)
            end
        end
    end

    table.sort(valid, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        local pa = source_priority[a.source] or 99
        local pb = source_priority[b.source] or 99
        if pa ~= pb then return pa < pb end
        return tostring(a.title or "") < tostring(b.title or "")
    end)

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

    for i = #results, 1, -1 do results[i] = nil end
    for _, r in ipairs(deduped) do table.insert(results, r) end
    return results
end

return M
