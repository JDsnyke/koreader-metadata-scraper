package.path = "./?.lua;./?/init.lua;" .. package.path

local passed, failed = 0, 0

local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then
        io.write("PASS  " .. name .. "\n")
        passed = passed + 1
    else
        io.stderr:write("FAIL  " .. name .. "\n      " .. tostring(err) .. "\n")
        failed = failed + 1
    end
end

local function eq(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function truthy(value, message)
    if not value then error(message or "expected truthy value", 2) end
end

local function read_file(path)
    local fh = io.open(path, "rb")
    if not fh then return nil end
    local data = fh:read("*all")
    fh:close()
    return data
end

local function write_file(path, data)
    local fh = assert(io.open(path, "wb"))
    fh:write(data)
    fh:close()
end

local metadata_path
local cover_path
local custom_props = {}

package.preload["docsettings"] = function()
    return {
        findCustomMetadataFile = function() return metadata_path end,
        findCustomCoverFile = function() return cover_path end,
        openSettingsFile = function()
            return {
                readSetting = function(_, key, default)
                    if key == "custom_props" then return custom_props end
                    return default
                end,
            }
        end,
    }
end

package.preload["ui/event"] = function()
    return { new = function(_, name, file) return { name = name, file = file } end }
end

package.preload["ui/uimanager"] = function()
    return { broadcastEvent = function() end }
end

package.preload["lib/http"] = function()
    return { validate_image_file = function() return true, {} end }
end

local function load_writer()
    package.loaded["lib/writer"] = nil
    package.loaded["docsettings"] = nil
    package.loaded["ui/event"] = nil
    package.loaded["ui/uimanager"] = nil
    package.loaded["lib/http"] = nil
    return require("lib/writer")
end

check("preview shows only fields that will actually change", function()
    metadata_path = "custom.lua"
    cover_path = nil
    custom_props = { title = "Old title", authors = "Existing Author" }
    local Writer = load_writer()

    local changes = assert(Writer.preview("book.epub", {}, {
        title = "New title",
        authors = { "New Author" },
        series = "Series",
    }, { title = true, authors = true, series = true }, false))

    eq(#changes, 1)
    eq(changes[1].key, "series")
    eq(changes[1].action, "add")

    changes = assert(Writer.preview("book.epub", {}, {
        title = "New title",
        authors = { "New Author" },
        series = "Series",
    }, { title = true, authors = true, series = true }, true))

    eq(#changes, 3)
    eq(changes[1].key, "title")
    eq(changes[1].action, "replace")
end)

check("snapshot and restore preserve exact custom metadata and cover bytes", function()
    local root = os.tmpname() .. "_lifecycle"
    assert(os.execute("mkdir -p " .. string.format("%q", root)) == 0)
    metadata_path = root .. "/custom_metadata.lua"
    cover_path = root .. "/cover.jpg"
    custom_props = {}
    write_file(metadata_path, "ORIGINAL METADATA BYTES")
    write_file(cover_path, "ORIGINAL COVER BYTES")

    local Writer = load_writer()
    local snapshot = assert(Writer.snapshot("book.epub", root))
    truthy(snapshot.metadata_backup)
    truthy(snapshot.cover_backup)

    write_file(metadata_path, "CHANGED METADATA")
    write_file(cover_path, "CHANGED COVER")

    local ok, err = Writer.restore_snapshot("book.epub", snapshot)
    truthy(ok, err)
    eq(read_file(metadata_path), "ORIGINAL METADATA BYTES")
    eq(read_file(cover_path), "ORIGINAL COVER BYTES")

    Writer.discard_snapshot(snapshot)
    os.remove(metadata_path)
    os.remove(cover_path)
    os.execute("rm -rf " .. string.format("%q", root))
end)

check("undo removes overrides that did not exist before apply", function()
    local root = os.tmpname() .. "_lifecycle_empty"
    assert(os.execute("mkdir -p " .. string.format("%q", root)) == 0)
    metadata_path = nil
    cover_path = nil
    custom_props = {}

    local Writer = load_writer()
    local snapshot = assert(Writer.snapshot("new-book.epub", root))
    eq(snapshot.metadata_path, nil)
    eq(snapshot.cover_path, nil)

    metadata_path = root .. "/new_custom.lua"
    cover_path = root .. "/new_cover.jpg"
    write_file(metadata_path, "NEW OVERRIDE")
    write_file(cover_path, "NEW COVER")

    local ok, err = Writer.restore_snapshot("new-book.epub", snapshot)
    truthy(ok, err)
    eq(read_file(metadata_path), nil)
    eq(read_file(cover_path), nil)

    Writer.discard_snapshot(snapshot)
    os.execute("rm -rf " .. string.format("%q", root))
end)

check("snapshot cannot be restored onto a different book", function()
    local root = os.tmpname() .. "_lifecycle_mismatch"
    assert(os.execute("mkdir -p " .. string.format("%q", root)) == 0)
    metadata_path = nil
    cover_path = nil
    custom_props = {}

    local Writer = load_writer()
    local snapshot = assert(Writer.snapshot("book-a.epub", root))
    local ok, err = Writer.restore_snapshot("book-b.epub", snapshot)
    eq(ok, nil)
    truthy(tostring(err):find("does not match", 1, true) ~= nil)
    Writer.discard_snapshot(snapshot)
    os.execute("rm -rf " .. string.format("%q", root))
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
