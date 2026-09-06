local M = {
    SCHEMA_VERSION = 3,
}

local SECRET_KEYS = {
    hardcover_token = true,
    google_api_key = true,
    amazon_client_id = true,
    amazon_client_secret = true,
    amazon_partner_tag = true,
}

local RUNTIME_STATE_KEYS = {
    book_links = true,
    undo_records = true,
    history_records = true,
    provider_health = true,
    last_update_check = true,
}

local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do out[copy(key, seen)] = copy(item, seen) end
    return out
end

local function normalize_channel(value)
    if value == "prerelease" then return "prerelease" end
    return "stable"
end

function M.valid_amazon_credential_version(value)
    value = tostring(value or ""):match("^%s*(.-)%s*$") or ""
    return value == "" or value == "3.1" or value == "3.2" or value == "3.3"
end

function M.migrate(saved)
    if type(saved) ~= "table" then
        return { settings_schema_version = M.SCHEMA_VERSION }, 0
    end

    local out = copy(saved)
    local original = tonumber(out.settings_schema_version) or 0
    local schema = original

    if schema < 1 then
        if out.batch_skip_matched == nil then out.batch_skip_matched = true end
        schema = 1
    end

    if schema < 2 then
        out.update_channel = normalize_channel(out.update_channel)
        if type(out.provider_health) ~= "table" then out.provider_health = {} end
        schema = 2
    end

    if schema < 3 then
        if type(out.history_records) ~= "table" then out.history_records = {} end
        schema = 3
    end

    out.update_channel = normalize_channel(out.update_channel)
    if type(out.provider_health) ~= "table" then out.provider_health = {} end
    if type(out.history_records) ~= "table" then out.history_records = {} end
    out.settings_schema_version = M.SCHEMA_VERSION
    return out, original
end

function M.safe_export(settings)
    local out = {}
    for key, value in pairs(type(settings) == "table" and settings or {}) do
        if not SECRET_KEYS[key] and not RUNTIME_STATE_KEYS[key] then
            out[key] = copy(value)
        end
    end
    out.settings_schema_version = M.SCHEMA_VERSION
    out.update_channel = normalize_channel(out.update_channel)
    return out
end

function M.mask_identifier(value)
    value = tostring(value or "")
    if value == "" then return "missing" end
    local n = #value
    if n <= 4 then return string.rep("•", n) end
    return string.rep("•", math.min(8, n - 4)) .. value:sub(-4)
end

return M
