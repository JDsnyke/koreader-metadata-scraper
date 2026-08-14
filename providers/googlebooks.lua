local HTTP = require("lib/http")
local U = require("lib/util")

local P = { id = "google", label = "Google Books" }

local function qpart(query)
    local isbn = U.clean_isbn(query.isbn)
    if isbn then return "isbn:" .. isbn end
    local parts = {}
    if U.nonempty(query.title) then table.insert(parts, "intitle:" .. query.title) end
    if U.nonempty(query.author) then table.insert(parts, "inauthor:" .. query.author) end
    return table.concat(parts, " ")
end

function P.search(query, settings)
    local q = qpart(query)
    if q == "" then return {}, "Title, author or ISBN required" end
    local url = "https://www.googleapis.com/books/v1/volumes?q=" .. U.urlencode(q)
        .. "&printType=books&maxResults=8"
    if U.nonempty(settings.google_api_key) then url = url .. "&key=" .. U.urlencode(settings.google_api_key) end
    local res, err = HTTP.json("GET", url)
    if not res then return {}, err end
    if res.code ~= 200 then return {}, "HTTP " .. tostring(res.code) end
    local out = {}
    for _, item in ipairs((res.json and res.json.items) or {}) do
        local v = item.volumeInfo or {}
        local ids = {}
        for _, ident in ipairs(v.industryIdentifiers or {}) do table.insert(ids, ident.identifier) end
        local isbn10, isbn13 = U.find_isbns(ids)
        local images = v.imageLinks or {}
        local cover = images.extraLarge or images.large or images.medium or images.thumbnail or images.smallThumbnail
        if cover then cover = cover:gsub("^http://", "https://") end
        table.insert(out, {
            source = P.id, source_label = P.label, id = item.id,
            title = v.title, subtitle = v.subtitle,
            authors = v.authors or {}, authors_text = U.join(v.authors, "\n"),
            publisher = v.publisher, published_date = v.publishedDate,
            description = v.description, language = v.language,
            keywords = v.categories or {}, keywords_text = U.join(v.categories, "\n"),
            isbn10 = isbn10, isbn13 = isbn13, cover_url = cover,
            raw = item,
        })
    end
    return out
end

return P
