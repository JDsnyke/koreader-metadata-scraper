local Version = require("lib/version")

local M = {}
local MAX_EVENTS = 80
local MAX_LOG_BYTES = 64 * 1024
local events = {}
local persistent_path
local persistent_settings

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

local function clean_field(value, settings)
    local text = M.redact(value or "", settings)
    return text:gsub("[\r\n\t]+", " "):gsub("%s+", " ")
end

local function push_event(entry)
    table.insert(events, entry)
    while #events > MAX_EVENTS do table.remove(events, 1) end
end

local function rotate_if_needed()
    if not persistent_path then return end
    local fh = io.open(persistent_path, "rb")
    if not fh then return end
    local size = fh:seek("end") or 0
    fh:close()
    if size < MAX_LOG_BYTES then return end
    os.remove(persistent_path .. ".1")
    os.rename(persistent_path, persistent_path .. ".1")
end

local function append_persistent(entry)
    if not persistent_path then return end
    rotate_if_needed()
    local fh = io.open(persistent_path, "ab")
    if not fh then return end
    fh:write(table.concat({
        tostring(entry.time or os.time()),
        clean_field(entry.component, persistent_settings),
        clean_field(entry.operation, persistent_settings),
        clean_field(entry.status, persistent_settings),
        tostring(entry.elapsed_ms or ""),
        tostring(entry.result_count or ""),
        clean_field(entry.message, persistent_settings),
    }, "\t"), "\n")
    fh:close()
end

local function load_persistent(settings)
    if not persistent_path then return end
    local fh = io.open(persistent_path, "rb")
    if not fh then return end
    local loaded = {}
    for line in fh:lines() do
        local t, component, operation, status, elapsed, count, message = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
        if t then
            table.insert(loaded, {
                time = tonumber(t) or os.time(),
                component = M.redact(component, settings),
                operation = M.redact(operation, settings),
                status = M.redact(status, settings),
                elapsed_ms = tonumber(elapsed),
                result_count = tonumber(count),
                message = M.redact(message, settings),
            })
        end
    end
    fh:close()
    local first = math.max(1, #loaded - MAX_EVENTS + 1)
    for i = first, #loaded do push_event(loaded[i]) end
end

function M.configure(path, settings)
    persistent_path = type(path) == "string" and path ~= "" and path or nil
    persistent_settings = type(settings) == "table" and settings or nil
    for i = #events, 1, -1 do events[i] = nil end
    load_persistent(persistent_settings)
end

function M.log(component, message, settings, meta)
    settings = type(settings) == "table" and settings or persistent_settings
    meta = type(meta) == "table" and meta or {}
    local entry = {
        time = os.time(),
        component = clean_field(component or "plugin", settings),
        operation = clean_field(meta.operation or "", settings),
        status = clean_field(meta.status or "", settings),
        elapsed_ms = tonumber(meta.elapsed_ms),
        result_count = tonumber(meta.result_count),
        message = clean_field(message or "", settings),
    }
    push_event(entry)
    append_persistent(entry)
end

function M.clear()
    for i = #events, 1, -1 do events[i] = nil end
    if persistent_path then
        os.remove(persistent_path)
        os.remove(persistent_path .. ".1")
    end
end

function M.get_events()
    local out = {}
    for _, event in ipairs(events) do
        table.insert(out, {
            time = event.time,
            component = event.component,
            operation = event.operation,
            status = event.status,
            elapsed_ms = event.elapsed_ms,
            result_count = event.result_count,
            message = event.message,
        })
    end
    return out
end

local function enabled_label(settings, id)
    local enabled = settings and type(settings.enabled) == "table" and settings.enabled[id]
    return enabled and "enabled" or "disabled"
end

local function event_detail(event, settings)
    local details = {}
    if event.operation and event.operation ~= "" then table.insert(details, event.operation) end
    if event.status and event.status ~= "" then table.insert(details, event.status) end
    if event.elapsed_ms then table.insert(details, tostring(event.elapsed_ms) .. "ms") end
    if event.result_count then table.insert(details, tostring(event.result_count) .. " result(s)") end
    local prefix = #details > 0 and (" (" .. table.concat(details, ", ") .. ")") or ""
    return string.format("- %s [%s]%s %s",
        os.date("!%Y-%m-%dT%H:%M:%SZ", event.time),
        M.redact(event.component, settings),
        prefix,
        M.redact(event.message, settings))
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
        "- Update channel: " .. tostring(settings.update_channel or "stable"),
        "- Settings schema: " .. tostring(settings.settings_schema_version or "legacy"),
    }

    if type(settings.provider_health) == "table" then
        table.insert(lines, "")
        table.insert(lines, "Last provider health checks:")
        local ids = {}
        for id in pairs(settings.provider_health) do table.insert(ids, id) end
        table.sort(ids)
        if #ids == 0 then
            table.insert(lines, "- none")
        else
            for _, id in ipairs(ids) do
                local health = settings.provider_health[id]
                table.insert(lines, string.format("- %s: %s at %s%s",
                    tostring(id),
                    health.ok and "OK" or "failed",
                    health.tested_at and os.date("!%Y-%m-%dT%H:%M:%SZ", tonumber(health.tested_at) or 0) or "unknown",
                    health.elapsed_ms and (", " .. tostring(health.elapsed_ms) .. "ms") or ""))
            end
        end
    end

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
        for _, event in ipairs(events) do table.insert(lines, event_detail(event, settings)) end
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
