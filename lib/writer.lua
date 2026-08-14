local DocSettings = require("docsettings")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local U = require("lib/util")

local M = {}
local SUPPORTED = { "title", "authors", "series", "series_index", "language", "keywords", "description" }

local function shallow_copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end

function M.write(file, original_props, result, fields, replace_existing)
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

function M.write_cover(file, image_file)
    local existing = DocSettings:findCustomCoverFile(file)
    if existing then os.remove(existing) end
    local ok = DocSettings:flushCustomCover(file, image_file)
    if ok then
        UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
        UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
    end
    return ok
end

return M
