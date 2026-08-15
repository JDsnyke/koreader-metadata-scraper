local Version = require("lib/version")

local M = {}
local MAX_EVENTS = 80
local events = {}

local SECRET_KEYS = {
    "hardcover_token",
    "google_api_key",
    "amazon_client_id",
    "amazon_client_secret",
    "amazon_partner_tag",
}

local function escape_pattern(value)
    return tostring(value):gsub("([^%w])", "%%%1")
end

local function configured(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

function M.redact(value, settings)
    local text = tostring(value or "")

    for _, key in ipairs(SECRET_KEYS) do
        local secret = settings and settings[key]
        if configured(secret) then
            text = text:gsub(escape_pattern(secret), "[REDACTED]")
        end
    end

    text = text:gsub("([Bb]earer)%s+[%w%._~%+/%-=]+", "%1 [REDACTED]")
    text = text:gsub("([?&][Kk][Ee][Yy]=)[^&%s]+", "%1[REDACTED]")
    text = text:gsub("([?&][Tt][Oo][Kk][Ee][Nn]=)[^&%s]+", "%1[REDACTED]")
    text = text:gsub("([Cc]lient[_%-]?[Ss]ecret%s*[:=]%s*)[^,%s]+", "%1[REDACTED]")
    text = text:gsub("([Aa][Pp][Ii][_%-%s]?[Kk][Ee][Yy]%s*[:=]%s*)[^,%s]+", "%1[REDACTED]")

    return text
end

function M.sanitize_url(url)
    local text = tostring(url or "")
    local base = text:match("^([^?]+)") or text
    if text:find("?", 1, true) then return base .. "?[redacted]" end
    return base
end

function M.log(component, message, settings)
    local entry = {
        time = os.time(),
        component = M.redact(component or "plugin", settings),
        message = M.redact(message or "", settings),
    }
    table.insert(events, entry)
    while #events > MAX_EVENTS do table.remove(events, 1) end
end

function M.clear()
    for i = #events, 1, -1 do events[i] = nil end
end

function M.get_events()
    local out = {}
    for _, event in ipairs(events) do
        table.insert(out, {
            time = event.time,
            component = event.component,
            message = event.message,
        })
    end
    return out
end

local function enabled_label(settings, id)
    local enabled = settings and type(settings.enabled) == "table" and settings.enabled[id]
    return enabled and "enabled" or "disabled"
end

function M.bundle(settings, extra)
    settings = type(settings) == "table" and settings or {}
    local lines = {
        "Metadata Scraper support diagnostics",
        "Plugin version: " .. tostring(Version.VERSION),
        "Generated: " .. os.date("!%Y-%m-%dT%H:%M:%SZ"),
        "",
        "Provider configuration (secrets are never included):",
        "- Hardcover: " .. enabled_label(settings, "hardcover") .. ", token " .. (configured(settings.hardcover_token) and "configured" or "missing"),
        "- Amazon: " .. enabled_label(settings, "amazon")
            .. ", credentials " .. ((configured(settings.amazon_client_id) and configured(settings.amazon_client_secret)) and "configured" or "missing")
            .. ", marketplace " .. tostring(settings.amazon_marketplace or "unset")
            .. ", credential version " .. tostring(settings.amazon_credential_version or "auto/legacy"),
        "- Google Books: " .. enabled_label(settings, "google") .. ", API key " .. (configured(settings.google_api_key) and "configured" or "missing"),
        "- Open Library: " .. enabled_label(settings, "openlibrary"),
        "- Search scope: " .. tostring(settings.source_scope or "all"),
    }

    if type(extra) == "table" then
        table.insert(lines, "")
        table.insert(lines, "Runtime information:")
        local keys = {}
        for key in pairs(extra) do table.insert(keys, tostring(key)) end
        table.sort(keys)
        for _, key in ipairs(keys) do
            table.insert(lines, "- " .. key .. ": " .. M.redact(extra[key], settings))
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Recent sanitized events:")
    if #events == 0 then
        table.insert(lines, "- none")
    else
        for _, event in ipairs(events) do
            table.insert(lines, string.format("- %s [%s] %s",
                os.date("!%Y-%m-%dT%H:%M:%SZ", event.time),
                event.component,
                M.redact(event.message, settings)))
        end
    end

    return table.concat(lines, "\n")
end

function M.write_bundle(filepath, settings, extra)
    local fh, err = io.open(filepath, "wb")
    if not fh then return nil, err end
    local ok, write_err = fh:write(M.bundle(settings, extra))
    fh:close()
    if not ok then return nil, write_err or "Could not write diagnostics file" end
    return true
end

return M
