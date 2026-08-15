local DocSettings = require("docsettings")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local U = require("lib/util")
local HTTP = require("lib/http")

local M = {}
local SUPPORTED = { "title", "authors", "series", "series_index", "language", "keywords", "description" }
local snapshot_seq = 0

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

local function file_exists(path)
    if not path then return false end
    local fh = io.open(path, "rb")
    if not fh then return false end
    fh:close()
    return true
end

local function incoming_values(result)
    result = type(result) == "table" and result or {}
    return {
        title = result.title,
        authors = result.authors_text or U.join(result.authors, "\n"),
        series = result.series,
        series_index = result.series_index and tostring(result.series_index) or nil,
        language = U.language_code(result.language),
        keywords = result.keywords_text or U.join(result.keywords, "\n"),
        description = result.description,
    }
end

function M.proposed_values(result)
    return incoming_values(result)
end

local function read_current(file, original_props)
    original_props = type(original_props) == "table" and original_props or {}
    local existing_file = DocSettings:findCustomMetadataFile(file)
    local ds = existing_file and DocSettings.openSettingsFile(existing_file) or nil
    local custom = ds and ds:readSetting("custom_props", {}) or {}
    if type(custom) ~= "table" then custom = {} end

    local current = {}
    for _, key in ipairs(SUPPORTED) do
        local value = custom[key]
        if value == nil or tostring(value) == "" then value = original_props[key] end
        current[key] = value
    end
    return current
end

local function preview_changes(file, original_props, result, fields, replace_existing)
    fields = type(fields) == "table" and fields or {}
    local current = read_current(file, original_props)
    local incoming = incoming_values(result)
    local changes = {}

    for _, key in ipairs(SUPPORTED) do
        local proposed = incoming[key]
        if fields[key] and proposed ~= nil and tostring(proposed) ~= "" then
            local old = current[key]
            local old_empty = old == nil or tostring(old) == ""
            local differs = old_empty or tostring(old) ~= tostring(proposed)
            local should_write = replace_existing or old_empty
            if should_write and differs then
                table.insert(changes, {
                    key = key,
                    current = old,
                    proposed = proposed,
                    action = old_empty and "add" or "replace",
                })
            end
        end
    end
    return changes
end

function M.preview(file, original_props, result, fields, replace_existing)
    local ok, changes = pcall(preview_changes, file, original_props, result, fields, replace_existing)
    if not ok then return nil, tostring(changes) end
    return changes
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
    local incoming = incoming_values(result)
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

local function snapshot_file(path, backup_path)
    local data = read_file(path)
    if data == nil then return nil, "Could not read " .. tostring(path) end
    if not write_file(backup_path, data) then
        return nil, "Could not create undo backup " .. tostring(backup_path)
    end
    return true
end

local function next_snapshot_id(file, backup_root)
    local base = U.safe_filename(file:match("([^/]+)$") or "book")
    local stamp = tostring(os.time())
    while true do
        snapshot_seq = snapshot_seq + 1
        local id = stamp .. "_" .. tostring(snapshot_seq) .. "_" .. base
        if not file_exists(backup_root .. "/" .. id .. ".metadata")
            and not file_exists(backup_root .. "/" .. id .. ".cover") then
            return id
        end
    end
end

local function create_snapshot(file, backup_root)
    if type(backup_root) ~= "string" or backup_root == "" then
        return nil, "Undo backup directory is unavailable"
    end

    local id = next_snapshot_id(file, backup_root)
    local metadata_path = DocSettings:findCustomMetadataFile(file)
    local cover_path = DocSettings:findCustomCoverFile(file)
    local snapshot = {
        file = file,
        created_at = os.time(),
        metadata_path = metadata_path,
        cover_path = cover_path,
    }

    if metadata_path then
        snapshot.metadata_backup = backup_root .. "/" .. id .. ".metadata"
        local ok, err = snapshot_file(metadata_path, snapshot.metadata_backup)
        if not ok then return nil, err end
    end

    if cover_path then
        snapshot.cover_backup = backup_root .. "/" .. id .. ".cover"
        local ok, err = snapshot_file(cover_path, snapshot.cover_backup)
        if not ok then
            if snapshot.metadata_backup then os.remove(snapshot.metadata_backup) end
            return nil, err
        end
    end

    return snapshot
end

function M.snapshot(file, backup_root)
    local ok, snapshot, err = pcall(create_snapshot, file, backup_root)
    if not ok then return nil, tostring(snapshot) end
    return snapshot, err
end

local function restore_one(current_path, original_path, backup_path)
    if original_path then
        if not backup_path then return nil, "Undo backup is missing" end
        local data = read_file(backup_path)
        if data == nil then return nil, "Undo backup cannot be read" end
        if current_path and current_path ~= original_path then
            local removed = os.remove(current_path)
            if not removed then return nil, "Could not remove current override " .. tostring(current_path) end
        end
        if not write_file(original_path, data) then return nil, "Could not restore " .. tostring(original_path) end
    elseif current_path then
        local removed = os.remove(current_path)
        if not removed then return nil, "Could not remove newly-created override " .. tostring(current_path) end
    end
    return true
end

local function restore_snapshot(file, snapshot)
    if type(snapshot) ~= "table" or snapshot.file ~= file then
        return nil, "Undo snapshot does not match this book"
    end

    local current_metadata = DocSettings:findCustomMetadataFile(file)
    local ok, err = restore_one(current_metadata, snapshot.metadata_path, snapshot.metadata_backup)
    if not ok then return nil, "Metadata undo failed: " .. tostring(err) end

    local current_cover = DocSettings:findCustomCoverFile(file)
    ok, err = restore_one(current_cover, snapshot.cover_path, snapshot.cover_backup)
    if not ok then return nil, "Cover undo failed: " .. tostring(err) end

    UIManager:broadcastEvent(Event:new("InvalidateMetadataCache", file))
    UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
    return true
end

function M.restore_snapshot(file, snapshot)
    local ok, restored, err = pcall(restore_snapshot, file, snapshot)
    if not ok then return nil, tostring(restored) end
    return restored, err
end

function M.discard_snapshot(snapshot)
    if type(snapshot) ~= "table" then return end
    if snapshot.metadata_backup then os.remove(snapshot.metadata_backup) end
    if snapshot.cover_backup then os.remove(snapshot.cover_backup) end
end

return M
