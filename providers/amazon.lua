local HTTP = require("lib/http")
local U = require("lib/util")

local P = { id = "amazon", label = "Amazon" }
local token, token_expiry

local FE = { ["www.amazon.com.au"] = true, ["www.amazon.co.jp"] = true, ["www.amazon.sg"] = true }
local NA = { ["www.amazon.com"] = true, ["www.amazon.ca"] = true, ["www.amazon.com.mx"] = true, ["www.amazon.com.br"] = true }

local function token_endpoint(marketplace)
    if FE[marketplace] then return "https://api.amazon.co.jp/auth/o2/token" end
    if NA[marketplace] then return "https://api.amazon.com/auth/o2/token" end
    return "https://api.amazon.co.uk/auth/o2/token"
end

local function get_token(settings)
    if token and token_expiry and token_expiry > os.time() + 90 then return token end
    if not U.nonempty(settings.amazon_client_id) or not U.nonempty(settings.amazon_client_secret) then
        return nil, "Amazon Creators API credentials are not configured"
    end
    local res, err = HTTP.json("POST", token_endpoint(settings.amazon_marketplace), nil, {
        grant_type = "client_credentials",
        client_id = settings.amazon_client_id,
        client_secret = settings.amazon_client_secret,
        scope = "creatorsapi::default",
    })
    if not res then return nil, err end
    if res.code ~= 200 or not res.json or not res.json.access_token then
        return nil, "Amazon authentication failed (HTTP " .. tostring(res.code) .. ")"
    end
    token = res.json.access_token
    token_expiry = os.time() + (tonumber(res.json.expires_in) or 3600)
    return token
end

local function display_value(v)
    if type(v) ~= "table" then return v end
    return v.displayValue or v.DisplayValue or v.value
end

function P.search(query, settings)
    if not U.nonempty(settings.amazon_partner_tag) then return {}, "Amazon Partner Tag is not configured" end
    local access, err = get_token(settings)
    if not access then return {}, err end
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

    local res, reqerr = HTTP.json("POST", "https://creatorsapi.amazon/catalog/v1/searchItems", {
        ["Authorization"] = "Bearer " .. access,
        ["x-marketplace"] = settings.amazon_marketplace,
    }, body)
    if not res then return {}, reqerr end
    if res.code ~= 200 then return {}, "HTTP " .. tostring(res.code) end
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
            cover_url = large.url or large.URL,
            raw = item,
        })
    end
    return out
end

return P
