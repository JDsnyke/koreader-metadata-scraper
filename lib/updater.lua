local DataStorage = require("datastorage")
local util = require("util")

local HTTP = require("lib/http")

local M = {
    CURRENT_VERSION = "0.1.1",
    release_api = "https://api.github.com/repos/JDsnyke/koreader-metadata-scraper/releases/latest",
    raw_base = "https://raw.githubusercontent.com/JDsnyke/koreader-metadata-scraper/",
}

local HEADERS = {
    ["Accept"] = "application/vnd.github+json",
    ["User-Agent"] = "KOReader-Metadata-Scraper/0.1.1",
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

function M.check()
    local res, err = HTTP.json("GET", M.release_api, HEADERS)
    if not res then return nil, err end
    if res.code ~= 200 then return nil, github_error(res) end
    local data = res.json or {}
    local tag = tostring(data.tag_name or "")
    if tag == "" then return nil, "Latest GitHub release has no tag" end
    local version = tag:gsub("^v", "")
    local asset_url
    for _, asset in ipairs(data.assets or {}) do
        if tostring(asset.name or ""):match("metadata_scraper_koreader_v?[%d%.]+%.zip$") then
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
        available = M.compare_versions(version, M.CURRENT_VERSION) > 0,
    }
end

local function valid_relpath(path)
    if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" then return false end
    if path:find("\\", 1, true) then return false end
    if path:match("^%.%./") or path:match("/%.%./") or path:match("/%.%.$") or path == ".." then return false end
    return path:match("^[%w%._%-%/]+$") ~= nil
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

local function manifest_url(tag)
    return M.raw_base .. tag .. "/update.json"
end

local function raw_url(tag, path)
    return M.raw_base .. tag .. "/" .. path
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
    if type(manifest.files) ~= "table" or #manifest.files == 0 then
        return nil, "Release manifest contains no files"
    end

    local cache_root = DataStorage:getDataDir() .. "/cache/metadata_scraper/updater"
    local stage_root = cache_root .. "/stage-" .. release.version
    local backup_root = cache_root .. "/backup-" .. M.CURRENT_VERSION
    util.makePath(stage_root)
    util.makePath(backup_root)

    -- Download everything before touching the installed plugin.
    for _, path in ipairs(manifest.files) do
        if not valid_relpath(path) then return nil, "Unsafe path in update manifest: " .. tostring(path) end
        local dest = stage_root .. "/" .. path
        local dir = dirname(dest)
        if dir then util.makePath(dir) end
        local ok, err = HTTP.download(raw_url(release.tag, path), dest, {
            ["User-Agent"] = HEADERS["User-Agent"],
            ["Accept"] = "application/octet-stream",
        })
        if not ok then return nil, "Download failed for " .. path .. ": " .. tostring(err) end
    end

    local applied = {}
    local existed = {}

    -- Back up current files before replacing any of them.
    for _, path in ipairs(manifest.files) do
        local target = plugin_root .. "/" .. path
        local old = read_file(target)
        if old ~= nil then
            existed[path] = true
            local ok, err = write_file(backup_root .. "/" .. path, old)
            if not ok then return nil, "Could not back up " .. path .. ": " .. tostring(err) end
        end
    end

    -- Apply staged files. If anything fails, roll back files already touched.
    for _, path in ipairs(manifest.files) do
        local target = plugin_root .. "/" .. path
        local temp_target = target .. ".update-new"
        local ok, err = copy_file(stage_root .. "/" .. path, temp_target)
        if ok then
            ok, err = os.rename(temp_target, target)
        end
        if not ok then
            os.remove(temp_target)
            for _, done in ipairs(applied) do
                local done_target = plugin_root .. "/" .. done
                if existed[done] then
                    copy_file(backup_root .. "/" .. done, done_target)
                else
                    os.remove(done_target)
                end
            end
            return nil, "Could not install " .. path .. ": " .. tostring(err)
        end
        table.insert(applied, path)
    end

    return true
end

return M
