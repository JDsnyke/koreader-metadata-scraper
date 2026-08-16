package.path = "./?.lua;./?/init.lua;" .. package.path

local passed, failed = 0, 0
local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then io.write("PASS  " .. name .. "\n"); passed = passed + 1
    else io.stderr:write("FAIL  " .. name .. "\n      " .. tostring(err) .. "\n"); failed = failed + 1 end
end
local function truthy(v, m) if not v then error(m or "expected truthy value", 2) end end
local function eq(a, b, m) if a ~= b then error((m or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end
local function write_file(path, data)
    local dir = path:match("^(.*)/[^/]+$")
    if dir then os.execute("mkdir -p " .. string.format("%q", dir)) end
    local f = assert(io.open(path, "wb")); f:write(data); f:close()
end
local function read_file(path)
    local f = io.open(path, "rb"); if not f then return nil end
    local d = f:read("*all"); f:close(); return d
end

local root = os.tmpname() .. "-metadata-updater-v014"
os.remove(root)
os.execute("mkdir -p " .. string.format("%q", root))
local manifest
local manifest_body = "MANIFEST"
local mode = "install"
local downloads = 0

package.loaded["datastorage"] = nil
package.loaded["util"] = nil
package.loaded["lib/http"] = nil
package.loaded["ffi/sha2"] = nil
package.loaded["lib/updater"] = nil
package.preload["datastorage"] = function() return { getDataDir = function() return root .. "/data" end } end
package.preload["util"] = function() return { makePath = function(p) os.execute("mkdir -p " .. string.format("%q", p)); return true end } end
package.preload["ffi/sha2"] = function()
    return { sha256 = function(data)
        if data == "NEW" then return string.rep("a", 64) end
        return string.rep("b", 64)
    end }
end
package.preload["lib/http"] = function()
    return {
        json = function(_, url)
            if mode == "channels" then
                if url:find("releases%?per_page") then
                    return { code = 200, json = {
                        { tag_name = "v0.1.5-beta.1", name = "v0.1.5 beta 1", prerelease = true, draft = false, assets = {} },
                        { tag_name = "v0.1.3", name = "v0.1.3", prerelease = false, draft = false, assets = {} },
                    } }
                end
                return { code = 200, json = { tag_name = "v0.1.3", name = "v0.1.3", prerelease = false, assets = {} } }
            end
            return { code = 200, json = manifest, body = manifest_body }
        end,
        download = function(_, path)
            downloads = downloads + 1
            write_file(path, "NEW")
            return true
        end,
    }
end

local Updater = require("lib/updater")
local function reset(name)
    local p = root .. "/" .. name
    os.execute("rm -rf " .. string.format("%q", p))
    os.execute("mkdir -p " .. string.format("%q", p))
    write_file(p .. "/main.lua", "ORIGINAL")
    write_file(p .. "/obsolete.lua", "OBSOLETE")
    return p
end

check("stable and Test channels select only their intended release classes", function()
    mode = "channels"
    local stable = assert(Updater.check("stable"))
    eq(stable.version, "0.1.3")
    truthy(not stable.prerelease)
    truthy(not stable.available)
    local test = assert(Updater.check("prerelease"))
    eq(test.version, "0.1.5-beta.1")
    truthy(test.prerelease)
    truthy(test.available)
    eq(test.channel, "prerelease")
end)

check("updater removes explicitly obsolete files after verified install", function()
    mode = "install"; downloads = 0
    local p = reset("remove-good")
    manifest_body = '{"version":"0.1.5"}'
    manifest = {
        version = "0.1.5",
        files = { "main.lua", "update.json" },
        remove = { "obsolete.lua" },
        sha256 = { ["main.lua"] = string.rep("a", 64) },
    }
    local ok, err = Updater.install({ tag = "v0.1.5", version = "0.1.5" }, p)
    truthy(ok, err)
    eq(read_file(p .. "/main.lua"), "NEW")
    eq(read_file(p .. "/obsolete.lua"), nil)
    eq(downloads, 1)
end)

check("failed obsolete-file removal rolls replacement files back", function()
    mode = "install"; downloads = 0
    local p = reset("remove-rollback")
    manifest_body = '{"version":"0.1.5"}'
    manifest = {
        version = "0.1.5",
        files = { "main.lua", "update.json" },
        remove = { "obsolete.lua" },
        sha256 = { ["main.lua"] = string.rep("a", 64) },
    }
    local original_remove = os.remove
    os.remove = function(path)
        if path == p .. "/obsolete.lua" then return nil, "simulated removal failure" end
        return original_remove(path)
    end
    local ok, err = Updater.install({ tag = "v0.1.5", version = "0.1.5" }, p)
    os.remove = original_remove
    eq(ok, nil)
    truthy(tostring(err):find("Could not remove obsolete file", 1, true))
    eq(read_file(p .. "/main.lua"), "ORIGINAL", "replacement should roll back")
    eq(read_file(p .. "/obsolete.lua"), "OBSOLETE", "obsolete file should remain")
end)

check("unsafe or overlapping removal entries fail closed before downloads", function()
    mode = "install"; downloads = 0
    local p = reset("remove-invalid")
    manifest = {
        version = "0.1.5",
        files = { "main.lua", "update.json" },
        remove = { "../outside.lua" },
        sha256 = { ["main.lua"] = string.rep("a", 64) },
    }
    local ok, err = Updater.install({ tag = "v0.1.5", version = "0.1.5" }, p)
    eq(ok, nil)
    truthy(tostring(err):find("Unsafe path in update remove list", 1, true))
    eq(downloads, 0)
end)

os.execute("rm -rf " .. string.format("%q", root))
io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
