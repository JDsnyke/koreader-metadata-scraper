local HTTP = require("lib/http")
local U = require("lib/util")
local Version = require("lib/version")

local P = { id = "amazon", label = "Amazon" }

local TOKEN_ENDPOINTS = {
    ["3.1"] = "https://api.amazon.com/auth/o2/token",
    ["3.2"] = "https://api.amazon.co.uk/auth/o2/token",
    ["3.3"] = "https://api.amazon.co.jp/auth/o2/token",
}

-- Legacy fallback for installations created before credential version was stored.
local FE = { ["www.amazon.com.au"] = true, ["www.amazon.co.jp"] = true, ["www.amazon.sg"] = true }
local NA = { ["www.amazon.com"] = true, ["www.amazon.ca"] = true, ["www.amazon.com.mx"] = true, ["www.amazon.com.br"] = true }

local token_cache = { value = nil, expiry = 0, key = nil }

local function credential_version(settings)
    local version = U.trim(tostring(settings.amazon_credential_version or ""))
    if TOKEN_ENDPOINTS[version] then return version, false end
    if FE[settings.amazon_marketplace] then return "3.3", true end
    if NA[settings.amazon_marketplace] then return "3.1", true end
    return "3.2", true
end

local function token_endpoint(settings)
    local version, inferred = credential_version(settings)
    return TOKEN_ENDPOINTS[version], version, inferred
end

local function cache_key(settings, endpoint)
    return table.concat({
        tostring(settings.amazon_client_id or ""),
        tostring(settings.amazon_client_secret or ""),
        tostring(endpoint or ""),
    }, "\0")
end

local function clear_token_cache()
    token_cache.value = nil
    token_cache.expiry = 0
    token_cache.key = nil
end

local function amazon_error(res)
    local body = res and res.json or {}
    local message = body.message or body.error_description or body.error
    if message and message ~= "" then return tostring(message) end
    return "HTTP " .. tostring(res and res.code or "?")
end

local function get_token(settings, force_refresh)
    if not U.nonempty(settings.amazon_client_id) or not U.nonempty(settings.amazon_client_secret) then
        return nil, "Amazon Creators API credentials are not configured"
    end

    local endpoint, version, inferred = token_endpoint(settings)
    local key = cache_key(settings, endpoint)
    if not force_refresh and token_cache.value and token_cache.key == key
            and token_cache.expiry > os.time() + 90 then
        return token_cache.value, nil, version, inferred
    end

    local res, err = HTTP.json("POST", endpoint, {
        ["User-Agent"] = Version.user_agent(),
    }, {
        grant_type = "client_credentials",
        client_id = settings.amazon_client_id,
        client_secret = settings.amazon_client_secret,
        scope = "creatorsapi::default",
    })
    if not res then return nil, err end
    if res.code ~= 200 or not res.json or not res.json.access_token then
        clear_token_cache()
        return nil, "Amazon authentication failed: " .. amazon_error(res)
    end

    token_cache.value = res.json.access_token
    token_cache.expiry = os.time() + (tonumber(res.json.expires_in) or 3600)
    token_cache.key = key
    return token_cache.value, nil, version, inferred
end

function P.status(settings)
    settings = settings or {}
    if not U.nonempty(settings.amazon_client_id) or not U.nonempty(settings.amazon_client_secret)
            or not U.nonempty(settings.amazon_partner_tag) then
        return "credentials missing", "missing"
    end
    local endpoint = token_endpoint(settings)
    local key = cache_key(settings, endpoint)
    if token_cache.value and token_cache.key == key and token_cache.expiry > os.time() + 90 then
        return "ready · token cached", "ready"
    end
    return "configured · not tested", "configured"
end

local function display_value(v)
    if type(v) ~= "table" then return v end
    return v.displayValue or v.DisplayValue or v.value
end

local function build_body(query, settings)
    local body = {
        marketplace = settings.amazon_marketplace,
        partnerTag = settings.amazon_partner_tag,
        searchIndex = settings.amazon_search_index or "Books",
        itemCount = 8,
        resources = {
            "images.primary.large",
            "itemInfo.title",
            "itemInfo.byLineInfo",
            "itemInfo.contentInfo",
            "itemInfo.externalIds",
            "itemInfo.classifications",
        },
    }
    if U.nonempty(query.title) then body.title = query.title end
    if U.nonempty(query.author) then body.author = query.author end
    if not body.title and not body.author then body.keywords = U.clean_isbn(query.isbn) or query.isbn end
    return body
end

local function request_search(query, settings, access)
    return HTTP.json("POST", "https://creatorsapi.amazon/catalog/v1/searchItems", {
        ["Authorization"] = "Bearer " .. access,
        ["x-marketplace"] = settings.amazon_marketplace,
        ["User-Agent"] = Version.user_agent(),
    }, build_body(query, settings))
end

function P.search(query, settings)
    if not U.nonempty(settings.amazon_partner_tag) then return {}, "Amazon Partner Tag is not configured" end
    local access, err = get_token(settings)
    if not access then return {}, err end

    local res, reqerr = request_search(query, settings, access)
    if not res then return {}, reqerr end

    -- A cached token can be revoked or rejected before its advertised expiry.
    -- Refresh it once on authentication failure and retry the idempotent search.
    if res.code == 401 then
        clear_token_cache()
        access, err = get_token(settings, true)
        if not access then return {}, err end
        res, reqerr = request_search(query, settings, access)
        if not res then return {}, reqerr end
    end

    if res.code ~= 200 then return {}, amazon_error(res) end
    local root = res.json or {}
    local sr = root.searchResult or root.SearchResult or {}
    local items = sr.items or sr.Items or {}
    local out = {}
    for _, item in ipairs(items) do
        local ii = item.itemInfo or item.ItemInfo or {}
        local title = display_value(ii.title or ii.Title)
        local by = ii.byLineInfo or ii.ByLineInfo or {}
        local contribs = by.contributors or by.Contributors or {}
        local authors = {}
        for _, c in ipairs(contribs) do
            local role = tostring(c.roleType or c.RoleType or ""):lower()
            if role == "" or role == "author" then
                local name = c.name or c.Name
                if name then table.insert(authors, name) end
            end
        end
        if #authors == 0 then
            for _, c in ipairs(contribs) do if c.name or c.Name then table.insert(authors, c.name or c.Name) end end
        end
        local content = ii.contentInfo or ii.ContentInfo or {}
        local classifications = ii.classifications or ii.Classifications or {}
        local binding = display_value(classifications.binding or classifications.Binding)
        local edition = display_value(content.edition or content.Edition)
        local extids = ii.externalIds or ii.ExternalIds or {}
        local allids = {}
        local isbns = extids.isbns or extids.ISBNs or {}
        for _, x in ipairs(isbns.displayValues or isbns.DisplayValues or {}) do table.insert(allids, x) end
        local eans = extids.eans or extids.EANs or {}
        for _, x in ipairs(eans.displayValues or eans.DisplayValues or {}) do table.insert(allids, x) end
        local isbn10, isbn13 = U.find_isbns(allids)
        local langs = content.languages or content.Languages or {}
        local langvals = langs.displayValues or langs.DisplayValues or {}
        local first_lang = U.first(langvals)
        if type(first_lang) == "table" then first_lang = first_lang.displayValue or first_lang.DisplayValue end
        local pubdate = display_value(content.publicationDate or content.PublicationDate)
        local images = item.images or item.Images or {}
        local primary = images.primary or images.Primary or {}
        local large = primary.large or primary.Large or {}
        table.insert(out, {
            source = P.id,
            source_label = "Amazon " .. tostring(settings.amazon_marketplace or ""),
            id = item.asin or item.ASIN,
            title = title,
            authors = authors, authors_text = U.join(authors, "\n"),
            language = U.language_code(first_lang),
            published_date = pubdate,
            isbn10 = isbn10, isbn13 = isbn13,
            binding = binding,
            format = binding,
            edition = edition,
            media_kind = U.format_kind(binding) or U.format_kind(edition),
            cover_url = large.url or large.URL,
            raw = item,
        })
    end
    return out
end

function P.test(settings)
    if not U.nonempty(settings.amazon_partner_tag) then
        return false, "Partner Tag is not configured"
    end
    local access, err, version, inferred = get_token(settings)
    if not access then return false, err end
    local suffix = inferred and " (inferred; save credential version for portability)" or ""
    return true, "OAuth token OK · credential v" .. tostring(version) .. suffix
end

P.reset_token_cache = clear_token_cache

return P
