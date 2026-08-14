local HTTP = require("lib/http")
local U = require("lib/util")

local P = { id = "openlibrary", label = "Open Library" }

function P.search(query)
    local args = {
        "limit=8",
        "fields=" .. U.urlencode("key,title,author_name,cover_i,first_publish_year,isbn,subject,language,publisher,publish_date,number_of_pages_median,edition_key,series"),
    }
    local isbn = U.clean_isbn(query.isbn)
    if isbn then
        table.insert(args, "isbn=" .. U.urlencode(isbn))
    else
        if U.nonempty(query.title) then table.insert(args, "title=" .. U.urlencode(query.title)) end
        if U.nonempty(query.author) then table.insert(args, "author=" .. U.urlencode(query.author)) end
    end
    local res, err = HTTP.json("GET", "https://openlibrary.org/search.json?" .. table.concat(args, "&"))
    if not res then return {}, err end
    if res.code ~= 200 then return {}, "HTTP " .. tostring(res.code) end
    local out = {}
    for _, d in ipairs((res.json and res.json.docs) or {}) do
        local isbn10, isbn13 = U.find_isbns(d.isbn)
        local cover = d.cover_i and ("https://covers.openlibrary.org/b/id/" .. tostring(d.cover_i) .. "-L.jpg?default=false") or nil
        table.insert(out, {
            source = P.id, source_label = P.label, id = d.key,
            title = d.title,
            authors = d.author_name or {}, authors_text = U.join(d.author_name, "\n"),
            series = U.first(d.series),
            publisher = U.first(d.publisher),
            published_date = U.first(d.publish_date) or d.first_publish_year,
            language = U.language_code(U.first(d.language)),
            keywords = d.subject or {}, keywords_text = U.join(d.subject, "\n", 12),
            isbn10 = isbn10, isbn13 = isbn13, cover_url = cover,
            pages = d.number_of_pages_median,
            raw = d,
        })
    end
    return out
end

return P
