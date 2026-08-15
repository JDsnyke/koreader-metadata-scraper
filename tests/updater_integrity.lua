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

local function truthy(value, message)
    if not value then error(message or "expected truthy value", 2) end
end

local function eq(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function read_file(path)
    local fh = assert(io.open(path, "rb"))
    local data = fh:read("*all")
    fh:close()
    return data
end

local function write_file(path, data)
    local dir = path:match("^(.*)/[^/]+$")
    if dir then os.execute("mkdir -p " .. string.format("%q", dir)) end
    local fh = assert(io.open(path, "wb"))
    fh:write(data)
    fh:close()
end

local root = os.tmpname() .. "-metadata-updater-test"
os.remove(root)
os.execute("mkdir -p " .. string.format("%q", root))

local manifest
local manifest_body = "MANIFEST-BODY"
local download_content = "GOOD"
local download_calls = 0

package.loaded["datastorage"] = nil
package.loaded["util"] = nil
package.loaded["lib/http"] = nil
package.loaded["ffi/sha2"] = nil
package.loaded["lib/updater"] = nil

package.preload["datastorage"] = function()
    return { getDataDir = function() return root .. "/data" end }
end

package.preload["util"] = function()
    return {
        makePath = function(path)
            os.execute("mkdir -p " .. string.format("%q", path))
            return true
        end,
    }
end

package.preload["ffi/sha2"] = function()
    return {
        sha256 = function(data)
            if data == "GOOD" then return string.rep("a", 64) end
            if data == "ORIGINAL" then return string.rep("c", 64) end
            return string.rep("b", 64)
        end,
    }
end

package.preload["lib/http"] = function()
    return {
        json = function()
            return { code = 200, json = manifest, body = manifest_body }
        end,
        download = function(_, filepath)
            download_calls = download_calls + 1
            write_file(filepath, download_content)
            return true
        end,
    }
end

local Updater = require("lib/updater")

local function reset_plugin(name)
    local plugin_root = root .. "/" .. name
    os.execute("rm -rf " .. string.format("%q", plugin_root))
    os.execute("mkdir -p " .. string.format("%q", plugin_root))
    write_file(plugin_root .. "/main.lua", "ORIGINAL")
    return plugin_root
end

check("updater installs only after SHA-256 verification", function()
    local plugin_root = reset_plugin("good")
    download_content = "GOOD"
    download_calls = 0
    manifest_body = '{"version":"0.1.4"}'
    manifest = {
        version = "0.1.4",
        files = { "main.lua", "update.json" },
        sha256 = { ["main.lua"] = string.rep("a", 64) },
    }

    local ok, err = Updater.install({ tag = "v0.1.4", version = "0.1.4" }, plugin_root)
    truthy(ok, err)
    eq(read_file(plugin_root .. "/main.lua"), "GOOD")
    eq(read_file(plugin_root .. "/update.json"), manifest_body)
    eq(download_calls, 1, "update.json should be staged from the fetched manifest body")
end)

check("SHA-256 mismatch aborts before installed files are touched", function()
    local plugin_root = reset_plugin("mismatch")
    download_content = "BAD"
    download_calls = 0
    manifest_body = '{"version":"0.1.4"}'
    manifest = {
        version = "0.1.4",
        files = { "main.lua", "update.json" },
        sha256 = { ["main.lua"] = string.rep("a", 64) },
    }

    local ok, err = Updater.install({ tag = "v0.1.4", version = "0.1.4" }, plugin_root)
    eq(ok, nil)
    truthy(tostring(err):find("SHA%-256 mismatch") ~= nil)
    eq(read_file(plugin_root .. "/main.lua"), "ORIGINAL")
end)

check("manifest without SHA-256 map is rejected", function()
    local plugin_root = reset_plugin("missing-map")
    download_calls = 0
    manifest = {
        version = "0.1.4",
        files = { "main.lua", "update.json" },
    }

    local ok, err = Updater.install({ tag = "v0.1.4", version = "0.1.4" }, plugin_root)
    eq(ok, nil)
    truthy(tostring(err):find("no SHA%-256 map") ~= nil)
    eq(download_calls, 0)
    eq(read_file(plugin_root .. "/main.lua"), "ORIGINAL")
end)

check("manifest requires a valid digest for every runtime payload", function()
    local plugin_root = reset_plugin("missing-file-hash")
    download_calls = 0
    manifest = {
        version = "0.1.4",
        files = { "main.lua", "lib/http.lua", "update.json" },
        sha256 = { ["main.lua"] = string.rep("a", 64) },
    }

    local ok, err = Updater.install({ tag = "v0.1.4", version = "0.1.4" }, plugin_root)
    eq(ok, nil)
    truthy(tostring(err):find("no valid SHA%-256 for lib/http.lua", 1, false) ~= nil)
    eq(download_calls, 0)
end)

os.execute("rm -rf " .. string.format("%q", root))
io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
