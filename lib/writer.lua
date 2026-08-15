local DocSettings = require("docsettings")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local U = require("lib/util")
local HTTP = require("lib/http")

local M = {}
local SUPPORTED = { "title", "authors", "series", "series_index", "language", "keywords", "description" }

local function shallow_copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

local function read_file(path)
    local fh = io.open(path, "rb")
    if not fh then return nil end
    local data = fh:read("*all")
    fh:close()
    return data
end

local function write_file(path, data)
    local fh = io.open(path, "wb")
    if not fh then return nil end
    local ok = fh:write(data)
    fh:close()
    return ok and true or nil
end

local function write_metadata(file, original_props, result, fields, replace_existing)
    original_props = type(original_props) == "table" and original_props or {}
    result = type(result) == "table" and result or {}
    fields = type(fields) == "table" and fields or {}

    local existing_file = DocSettings:findCustomMetadataFile(file)
    local ds = existing_file and DocSettings.openSettingsFile(existing_file) or DocSettings.openSettingsFile()
    if not existing_file then
        local original = shallow_copy(original_props)
        original.display_title = nil
        ds:saveSetting("doc_props", original)
    elseif not ds:readSetting("doc_props") then
        local original = shallow_copy(original_props)
        original.display_title = nil
        ds:saveSetting("doc_props", original)
    end

    local custom = ds:readSetting("custom_props", {})
    if type(custom) ~= "table" then custom = {} end
    local incoming = {
        title = result.title,
        authors = result.authors_text or U.join(result.authors, "\n"),
        series = result.series,
        series_index = result.series_index and tostring(result.series_index) or nil,
        language = U.language_code(result.language),
        keywords = result.keywords_text or U.join(result.keywords, "\n"),
        description = result.description,
    }
    for _, key in ipairs(SUPPORTED) do
        if fields[key] and incoming[key] and tostring(incoming[key]) ~= "" then
            local current = custom[key] or original_props[key]
            if replace_existing or not current or tostring(current) == "" then
                custom[key] = incoming[key]
            end
        end
    end
    ds:saveSetting("custom_props", custom)
    local ok = ds:flushCustomMetadata(file)
    if ok then
        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
        UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
    end
    return ok
end

function M.write(file, original_props, result, fields, replace_existing)
    local ok, written = pcall(write_metadata, file, original_props, result, fields, replace_existing)
    if not ok then return nil, tostring(written) end
    return written
end

local function write_cover(file, image_file)
    -- Validate before touching an existing custom cover. This catches HTML error
    -- pages, JSON responses, tiny placeholders, and otherwise invalid downloads.
    local valid, validation = HTTP.validate_image_file(image_file)
    if not valid then return nil, validation end

    local existing = DocSettings:findCustomCoverFile(file)
    local backup

    -- KOReader's flushCustomCover copies the new image but does not remove a cover
    -- with a different extension. Preserve the old bytes before removing it so a
    -- failed replacement never destroys a user's existing custom cover.
    if existing then
        backup = read_file(existing)
        if backup == nil then return nil, "Could not back up the existing custom cover" end
        local removed = os.remove(existing)
        if not removed then return nil, "Could not remove the existing custom cover" end
    end

    local ok = DocSettings:flushCustomCover(file, image_file)
    if not ok then
        if existing and backup then
            if not write_file(existing, backup) then
                return nil, "Cover replacement failed and the previous cover could not be restored"
            end
        end
        return nil, "KOReader could not install the custom cover"
    end

    UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
    UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
    return true
end

function M.write_cover(file, image_file)
    local ok, written, err = pcall(write_cover, file, image_file)
    if not ok then return nil, tostring(written) end
    return written, err
end

return M
