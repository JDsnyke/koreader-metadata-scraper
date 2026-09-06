local DataStorage = require("datastorage")
local util = require("util")
local sha256 = require("ffi/sha2").sha256

local HTTP = require("lib/http")
local Version = require("lib/version")

local M = {
    CURRENT_VERSION = Version.VERSION,
    release_api = "https://api.github.com/repos/JDsnyke/koreader-metadata-scraper/releases/latest",
    releases_api = "https://api.github.com/repos/JDsnyke/koreader-metadata-scraper/releases?per_page=30",
    raw_base = "https://raw.githubusercontent.com/JDsnyke/koreader-metadata-scraper/",
}

local HEADERS = {
    ["Accept"] = "application/vnd.github+json",
    ["User-Agent"] = Version.user_agent(),
}

local function version_parts(v)
    local out = {}
    v = tostring(v or ""):gsub("^v", "")
    for n in v:gmatch("(%d+)") do table.insert(out, tonumber(n) or 0) end
    return out
end

function M.compare_versions(a, b)
    local A, B = version_parts(a), version_parts(b)
    for i = 1, math.max(#A, #B) do
        local av, bv = A[i] or 0, B[i] or 0
        if av < bv then return -1 end
        if av > bv then return 1 end
    end
    return 0
end

local function github_error(res)
    local msg = res and res.json and res.json.message
    if msg and msg ~= "" then return msg end
    return "HTTP " .. tostring(res and res.code or "?")
end

local function release_info(data, channel)
    data = type(data) == "table" and data or {}
    local tag = tostring(data.tag_name or "")
    if tag == "" then return nil, "GitHub release has no tag" end
    local version = tag:gsub("^v", "")
    local asset_url
    for _, asset in ipairs(data.assets or {}) do
        if tostring(asset.name or ""):match("metadata_scraper_koreader_v?[%d%.%-%a]+%.zip$") then
            asset_url = asset.browser_download_url
            break
        end
    end
    return {
        tag = tag,
        version = version,
        name = data.name or tag,
        notes = data.body or "",
        page_url = data.html_url,
        asset_url = asset_url,
        prerelease = data.prerelease == true,
        channel = channel or "stable",
        available = M.compare_versions(version, M.CURRENT_VERSION) > 0,
    }
end

function M.check(channel)
    channel = channel == "prerelease" and "prerelease" or "stable"
    if channel == "stable" then
        local res, err = HTTP.json("GET", M.release_api, HEADERS)
        if not res then return nil, err end
        if res.code ~= 200 then return nil, github_error(res) end
        return release_info(res.json, channel)
    end

    local res, err = HTTP.json("GET", M.releases_api, HEADERS)
    if not res then return nil, err end
    if res.code ~= 200 then return nil, github_error(res) end
    for _, data in ipairs(res.json or {}) do
        if type(data) == "table" and data.draft ~= true and data.prerelease == true then
            return release_info(data, channel)
        end
    end
    return nil, "No published Metadata Scraper prerelease is available"
end

local function valid_relpath(path)
    if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" then return false end
    if path:find("\\", 1, true) then return false end
    if path:match("^%.%./") or path:match("/%.%./") or path:match("/%.%.$") or path == ".." then return false end
    return path:match("^[%w%._%-%/]+$") ~= nil
end

local function valid_sha256(value)
    return type(value) == "string" and #value == 64 and value:match("^[0-9a-fA-F]+$") ~= nil
end

local function dirname(path)
    return path:match("^(.*)/[^/]+$")
end

local function read_file(path)
    local fh = io.open(path, "rb")
    if not fh then return nil end
    local data = fh:read("*all")
    fh:close()
    return data
end

local function write_file(path, data)
    local dir = dirname(path)
    if dir then util.makePath(dir) end
    local fh, err = io.open(path, "wb")
    if not fh then return nil, err end
    local ok, write_err = fh:write(data)
    fh:close()
    if not ok then return nil, write_err end
    return true
end

local function copy_file(src, dst)
    local data = read_file(src)
    if data == nil then return nil, "Could not read " .. tostring(src) end
    return write_file(dst, data)
end

local function file_sha256(path)
    local data = read_file(path)
    if data == nil then return nil, "Could not read " .. tostring(path) .. " for SHA-256 verification" end
    local ok, digest = pcall(sha256, data)
    if not ok then return nil, tostring(digest) end
    if not valid_sha256(digest) then return nil, "SHA-256 implementation returned an invalid digest" end
    return digest:lower()
end

local function manifest_url(tag)
    return M.raw_base .. tag .. "/update.json"
end

local function raw_url(tag, path)
    return M.raw_base .. tag .. "/" .. path
end

local function validate_manifest(manifest)
    if type(manifest.files) ~= "table" or #manifest.files == 0 then
        return nil, "Release manifest contains no files"
    end
    if type(manifest.sha256) ~= "table" then
        return nil, "Release manifest contains no SHA-256 map"
    end

    local installed = {}
    for _, path in ipairs(manifest.files) do
        if not valid_relpath(path) then return nil, "Unsafe path in update manifest: " .. tostring(path) end
        if installed[path] then return nil, "Duplicate path in update manifest: " .. tostring(path) end
        installed[path] = true
        -- update.json is the signed-by-transport control document itself. It is
        -- written from the exact response body already parsed below, avoiding a
        -- self-referential hash requirement.
        if path ~= "update.json" then
            local expected = manifest.sha256[path]
            if not valid_sha256(expected) then
                return nil, "Release manifest has no valid SHA-256 for " .. tostring(path)
            end
        end
    end

    if manifest.remove ~= nil and type(manifest.remove) ~= "table" then
        return nil, "Release manifest remove list must be an array"
    end
    local removals = {}
    for _, path in ipairs(manifest.remove or {}) do
        if not valid_relpath(path) then return nil, "Unsafe path in update remove list: " .. tostring(path) end
        if removals[path] then return nil, "Duplicate path in update remove list: " .. tostring(path) end
        if installed[path] then return nil, "Update manifest cannot install and remove the same path: " .. tostring(path) end
        removals[path] = true
    end
    return true
end

function M.install(release, plugin_root)
    if type(release) ~= "table" or not release.tag or not release.version then
        return nil, "Invalid release information"
    end
    if type(plugin_root) ~= "string" or plugin_root == "" then
        return nil, "Could not determine plugin directory"
    end

    local manifest_res, manifest_err = HTTP.json("GET", manifest_url(release.tag), HEADERS)
    if not manifest_res then return nil, manifest_err end
    if manifest_res.code ~= 200 then
        return nil, "Update manifest: " .. github_error(manifest_res)
    end
    local manifest = manifest_res.json or {}
    if tostring(manifest.version or "") ~= tostring(release.version) then
        return nil, "Release manifest version does not match the GitHub release"
    end
    local manifest_ok, manifest_validation_err = validate_manifest(manifest)
    if not manifest_ok then return nil, manifest_validation_err end

    local cache_root = DataStorage:getDataDir() .. "/cache/metadata_scraper/updater"
    local stage_root = cache_root .. "/stage-" .. release.version
    local backup_root = cache_root .. "/backup-" .. M.CURRENT_VERSION
    util.makePath(stage_root)
    util.makePath(backup_root)

    -- Download and verify everything before touching the installed plugin.
    for _, path in ipairs(manifest.files) do
        local dest = stage_root .. "/" .. path
        local dir = dirname(dest)
        if dir then util.makePath(dir) end

        local ok, err
        if path == "update.json" then
            ok, err = write_file(dest, manifest_res.body or "")
        else
            ok, err = HTTP.download(raw_url(release.tag, path), dest, {
                ["User-Agent"] = HEADERS["User-Agent"],
                ["Accept"] = "application/octet-stream",
            })
        end
        if not ok then return nil, "Download failed for " .. path .. ": " .. tostring(err) end

        if path ~= "update.json" then
            local actual, hash_err = file_sha256(dest)
            if not actual then
                os.remove(dest)
                return nil, "Could not verify " .. path .. ": " .. tostring(hash_err)
            end
            local expected = tostring(manifest.sha256[path]):lower()
            if actual ~= expected then
                os.remove(dest)
                return nil, "SHA-256 mismatch for " .. path
            end
        end
    end

    local existed = {}
    local backup_paths = {}
    local function back_up(path)
        if backup_paths[path] then return true end
        backup_paths[path] = true
        local old = read_file(plugin_root .. "/" .. path)
        if old ~= nil then
            existed[path] = true
            local ok, err = write_file(backup_root .. "/" .. path, old)
            if not ok then return nil, "Could not back up " .. path .. ": " .. tostring(err) end
        end
        return true
    end

    -- Back up current files that may be replaced or removed before mutation.
    for _, path in ipairs(manifest.files) do
        local ok, err = back_up(path)
        if not ok then return nil, err end
    end
    for _, path in ipairs(manifest.remove or {}) do
        local ok, err = back_up(path)
        if not ok then return nil, err end
    end

    -- Re-verify staged payloads immediately before applying them. This is cheap
    -- for plugin-sized files and catches local cache corruption between stages.
    for _, path in ipairs(manifest.files) do
        if path ~= "update.json" then
            local actual, hash_err = file_sha256(stage_root .. "/" .. path)
            if not actual then return nil, "Could not re-verify " .. path .. ": " .. tostring(hash_err) end
            if actual ~= tostring(manifest.sha256[path]):lower() then
                return nil, "Staged SHA-256 changed for " .. path
            end
        end
    end

    local touched = {}
    local function rollback()
        for i = #touched, 1, -1 do
            local path = touched[i]
            local target = plugin_root .. "/" .. path
            if existed[path] then
                copy_file(backup_root .. "/" .. path, target)
            else
                os.remove(target)
            end
        end
    end

    -- Apply staged files. If anything fails, roll back every path already touched.
    for _, path in ipairs(manifest.files) do
        local target = plugin_root .. "/" .. path
        local temp_target = target .. ".update-new"
        local ok, err = copy_file(stage_root .. "/" .. path, temp_target)
        if ok then ok, err = os.rename(temp_target, target) end
        if not ok then
            os.remove(temp_target)
            rollback()
            return nil, "Could not install " .. path .. ": " .. tostring(err)
        end
        table.insert(touched, path)
    end

    -- Remove explicitly obsolete files only after all replacements succeed.
    -- Only regular readable files are considered present, so the updater never
    -- recursively deletes directories from a manifest entry.
    for _, path in ipairs(manifest.remove or {}) do
        if existed[path] then
            local target = plugin_root .. "/" .. path
            local ok, err = os.remove(target)
            if not ok then
                rollback()
                return nil, "Could not remove obsolete file " .. path .. ": " .. tostring(err)
            end
            table.insert(touched, path)
        end
    end

    return true
end

return M
