local U = require("lib/util")
local M = {}

local function isbn_matches(query, r)
    local q = U.clean_isbn(query.isbn)
    if not q then return false end
    return q == U.clean_isbn(r.isbn13) or q == U.clean_isbn(r.isbn10)
end

function M.score(query, r)
    if isbn_matches(query, r) then return 100 end
    local qtitle = U.normalize(query.title)
    local rtitle = U.normalize(r.title)
    local score = 0
    if qtitle ~= "" and rtitle ~= "" then
        if qtitle == rtitle then
            score = score + 72
        elseif qtitle:find(rtitle, 1, true) or rtitle:find(qtitle, 1, true) then
            score = score + 60
        else
            score = score + math.floor(U.token_similarity(qtitle, rtitle) * 62)
        end
    end
    local qa = U.normalize(query.author)
    local ra = U.normalize(r.authors_text or U.join(r.authors, " "))
    if qa ~= "" and ra ~= "" then
        if qa == ra then score = score + 23
        elseif qa:find(ra, 1, true) or ra:find(qa, 1, true) then score = score + 20
        else score = score + math.floor(U.token_similarity(qa, ra) * 20) end
    end
    if query.language and r.language and U.language_code(query.language) == U.language_code(r.language) then
        score = score + 5
    end
    return math.min(100, score)
end

function M.rank(query, results, source_priority)
    source_priority = source_priority or {}
    for _, r in ipairs(results) do r.score = M.score(query, r) end
    table.sort(results, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        local pa = source_priority[a.source] or 99
        local pb = source_priority[b.source] or 99
        if pa ~= pb then return pa < pb end
        return tostring(a.title or "") < tostring(b.title or "")
    end)
    return results
end

return M
