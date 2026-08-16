local HTTP = require("lib/http")
local U = require("lib/util")
local Version = require("lib/version")

local P = { id = "google", label = "Google Books" }
local cooldown_until = 0
local backoff_step = 0

local function qpart(query)
    local isbn = U.clean_isbn(query.isbn)
    if isbn then return "isbn:" .. isbn end
    local parts = {}
    if U.nonempty(query.title) then table.insert(parts, "intitle:" .. query.title) end
    if U.nonempty(query.author) then table.insert(parts, "inauthor:" .. query.author) end
    return table.concat(parts, " ")
end

local function error_details(res)
    local e = res and res.json and res.json.error
    local message = e and e.message or ("HTTP " .. tostring(res and res.code or "?"))
    local reason
    if e and type(e.errors) == "table" and e.errors[1] then reason = e.errors[1].reason end
    if reason and reason ~= "" then return reason .. ": " .. message, reason end
    return message, reason
end

local function retry_after_seconds(res, reason)
    local headers = (res and res.headers) or {}
    local header = headers["retry-after"] or headers["Retry-After"]
    local seconds = tonumber(header)
    if seconds and seconds > 0 then return math.min(seconds, 3600) end
    if reason == "dailyLimitExceeded" or reason == "quotaExceeded" then return 3600 end
    backoff_step = math.min(backoff_step + 1, 6)
    return math.min(30 * (2 ^ (backoff_step - 1)), 900)
end

local function request(q, settings, max_results)
    if not U.nonempty(settings.google_api_key) then
        return nil, "Google Books API key required. Add one under Provider accounts."
    end
    local url = "https://www.googleapis.com/books/v1/volumes?q=" .. U.urlencode(q)
        .. "&printType=books&maxResults=" .. tostring(max_results or 8)
        .. "&key=" .. U.urlencode(settings.google_api_key)
    return HTTP.json("GET", url, {
        ["User-Agent"] = Version.user_agent(),
    })
end

local function handle_rate_limit(res)
    if res.code ~= 429 and res.code ~= 403 then return nil end
    local detail, reason = error_details(res)
    local quota_error = res.code == 429 or reason == "rateLimitExceeded"
        or reason == "userRateLimitExceeded" or reason == "quotaExceeded"
        or reason == "dailyLimitExceeded"
    if not quota_error then return nil end
    local wait = retry_after_seconds(res, reason)
    cooldown_until = os.time() + wait
    return detail .. " (cooldown " .. tostring(wait) .. "s)"
end

function P.status(settings)
    if not U.nonempty(settings and settings.google_api_key) then
        return "credentials missing", "missing"
    end
    local remaining = cooldown_until - os.time()
    if remaining > 0 then
        return "cooling down " .. tostring(math.max(1, remaining)) .. "s", "cooldown"
    end
    return "ready", "ready"
end

function P.search(query, settings)
    local now = os.time()
    if now < cooldown_until then
        local remaining = math.max(1, cooldown_until - now)
        return {}, "Rate limited by Google Books; retry in about " .. tostring(remaining) .. " seconds"
    end

    local q = qpart(query)
    if q == "" then return {}, "Title, author or ISBN required" end
    local res, err = request(q, settings, 8)
    if not res then return {}, err end

    local rate_error = handle_rate_limit(res)
    if rate_error then return {}, rate_error end

    if res.code ~= 200 then
        local detail = error_details(res)
        return {}, detail
    end
    backoff_step = 0
    cooldown_until = 0

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

function P.test(settings)
    local now = os.time()
    if now < cooldown_until then
        return false, "Cooling down for about " .. tostring(math.max(1, cooldown_until - now)) .. "s"
    end
    local res, err = request("intitle:test", settings, 1)
    if not res then return false, err end
    local rate_error = handle_rate_limit(res)
    if rate_error then return false, rate_error end
    if res.code ~= 200 then
        local detail = error_details(res)
        return false, detail
    end
    backoff_step = 0
    cooldown_until = 0
    return true, "API key accepted"
end

return P
