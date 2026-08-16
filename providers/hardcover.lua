local JSON = require("json")
local HTTP = require("lib/http")
local U = require("lib/util")
local Version = require("lib/version")

local P = { id = "hardcover", label = "Hardcover" }
local ENDPOINT = "https://api.hardcover.app/v1/graphql"

local function authorization_header(token)
    token = U.trim(tostring(token or ""))
    if token == "" then return nil end
    if token:lower():match("^bearer%s+") then return token end
    return "Bearer " .. token
end

local function graphql(token, query, variables)
    local authorization = authorization_header(token)
    if not authorization then return nil, "Hardcover API token is not configured" end
    local res, err = HTTP.json("POST", ENDPOINT, {
        ["Authorization"] = authorization,
        ["User-Agent"] = Version.user_agent(),
    }, { query = query, variables = variables or {} })
    if not res then return nil, err end
    if res.code ~= 200 then return nil, "HTTP " .. tostring(res.code) end
    if res.json and res.json.errors then
        local e = res.json.errors[1]
        return nil, (type(e) == "table" and e.message) or "GraphQL error"
    end
    return res.json and res.json.data
end

local function normalize_results(value)
    if type(value) == "string" then
        local ok, decoded = pcall(JSON.decode, value)
        if not ok then return nil, "Hardcover returned invalid JSON in search.results" end
        value = decoded
    end
    if type(value) ~= "table" then
        return nil, "Hardcover returned an unsupported search.results type: " .. type(value)
    end

    local source = value
    if type(value.hits) == "table" then source = value.hits end

    local docs = {}
    for _, item in ipairs(source) do
        if type(item) == "table" then
            local doc = type(item.document) == "table" and item.document or item
            if type(doc) == "table" then table.insert(docs, doc) end
        end
    end
    return docs
end

function P.status(settings)
    if not U.nonempty(settings and settings.hardcover_token) then
        return "token missing", "missing"
    end
    return "configured · not tested", "configured"
end

function P.search(query, settings)
    local term = U.clean_isbn(query.isbn)
    if not term then
        term = U.trim((query.title or "") .. " " .. (query.author or ""))
    end
    if term == "" then return {}, "Title, author or ISBN required" end
    local gql = [[
query MetadataScraperSearch($q: String!) {
  search(query: $q, query_type: "Book", per_page: 8, page: 1) {
    ids
    results
  }
}]]
    local data, err = graphql(settings.hardcover_token, gql, { q = term })
    if not data then return {}, err end
    local search = data.search or {}
    local ids = search.ids or {}

    local results, results_err = normalize_results(search.results or {})
    if not results then return {}, results_err end
    local out = {}
    for i, r in ipairs(results) do
        local isbns = r.isbns or {}
        local isbn10, isbn13 = U.find_isbns(isbns)
        local series = nil
        if type(r.featured_series) == "table" then
            series = r.featured_series.name or r.featured_series.series_name
        end
        series = series or U.first(r.series_names)
        local position = r.featured_series_position
        local tags = {}
        for _, v in ipairs(r.genres or {}) do table.insert(tags, type(v) == "table" and (v.name or v.tag) or v) end
        for _, v in ipairs(r.tags or {}) do
            local s = type(v) == "table" and (v.tag or v.name) or v
            if s then table.insert(tags, s) end
        end
        local format = r.format or r.binding or r.edition_format or r.edition_type
        local edition = r.edition or r.edition_name
        table.insert(out, {
            source = P.id, source_label = P.label,
            id = r.id or ids[i], title = r.title, subtitle = r.subtitle,
            authors = r.author_names or {}, authors_text = U.join(r.author_names, "\n"),
            series = series, series_index = position,
            description = r.description, published_date = r.release_year,
            keywords = tags, keywords_text = U.join(tags, "\n", 12),
            isbn10 = isbn10, isbn13 = isbn13,
            format = format, edition = edition,
            media_kind = U.format_kind(format) or U.format_kind(edition),
            cover_url = (type(r.image) == "table" and r.image.url) or r.image_url,
            raw = r,
        })
    end

    if #out == 0 and type(ids) == "table" and #ids > 0 then
        return {}, "Hardcover returned search IDs but no readable result documents"
    end

    local numeric_ids = {}
    for _, r in ipairs(out) do
        local n = tonumber(r.id)
        if n then table.insert(numeric_ids, n) end
    end
    if #numeric_ids > 0 then
        local literals = {}
        for _, n in ipairs(numeric_ids) do table.insert(literals, tostring(n)) end
        local detail_gql = "query { books(where: {id: {_in: [" .. table.concat(literals, ",") .. "]}}) { id title subtitle description release_date image { url } } }"
        local details = graphql(settings.hardcover_token, detail_gql)
        if details and details.books then
            local byid = {}
            for _, b in ipairs(details.books) do byid[tostring(b.id)] = b end
            for _, r in ipairs(out) do
                local b = byid[tostring(r.id)]
                if b then
                    r.description = r.description or b.description
                    r.published_date = r.published_date or b.release_date
                    if not r.cover_url and type(b.image) == "table" then r.cover_url = b.image.url end
                end
            end
        end
    end
    return out
end

function P.test(settings)
    local data, err = graphql(settings.hardcover_token, [[
query MetadataScraperAccountTest {
  me { id username }
}]], {})
    if not data then return false, err end
    local me = type(data.me) == "table" and data.me[1] or nil
    if not me then return false, "Authenticated request returned no account" end
    if U.nonempty(me.username) then return true, "Authenticated as " .. me.username end
    return true, "Authentication OK"
end

P._authorization_header = authorization_header
P._normalize_results = normalize_results

return P
