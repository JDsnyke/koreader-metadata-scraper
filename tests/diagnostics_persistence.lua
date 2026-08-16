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

local settings = {
    enabled = { hardcover = true, amazon = false, google = true, openlibrary = true },
    hardcover_token = "hardcover-persist-secret",
    google_api_key = "google-persist-secret",
    update_channel = "stable",
    settings_schema_version = 2,
    provider_health = {},
}

local path = os.tmpname() .. ".log"
os.remove(path)
os.remove(path .. ".1")

check("diagnostics persist sanitized operation metadata across reload", function()
    package.loaded["lib/diagnostics"] = nil
    local Diagnostics = require("lib/diagnostics")
    Diagnostics.configure(path, settings)
    Diagnostics.log("Google Books", "request failed key=google-persist-secret", settings, {
        operation = "search",
        status = "error",
        elapsed_ms = 321,
        result_count = 0,
    })

    package.loaded["lib/diagnostics"] = nil
    Diagnostics = require("lib/diagnostics")
    Diagnostics.configure(path, settings)
    local events = Diagnostics.get_events()
    truthy(#events == 1, "expected persisted event to reload")
    truthy(events[1].operation == "search")
    truthy(events[1].status == "error")
    truthy(events[1].elapsed_ms == 321)
    truthy(events[1].result_count == 0)
    local bundle = Diagnostics.bundle(settings)
    truthy(not bundle:find("google%-persist%-secret"), "persistent diagnostics leaked API key")
    truthy(bundle:find("321ms", 1, true), "elapsed time missing from bundle")
end)

check("persistent diagnostics rotate and clear cleanly", function()
    package.loaded["lib/diagnostics"] = nil
    local Diagnostics = require("lib/diagnostics")
    Diagnostics.configure(path, settings)
    local payload = string.rep("x", 1200)
    for i = 1, 70 do
        Diagnostics.log("provider", payload .. tostring(i), settings, { operation = "batch", status = "ok" })
    end
    local rotated = io.open(path .. ".1", "rb")
    truthy(rotated ~= nil, "expected bounded diagnostics rotation")
    if rotated then rotated:close() end
    Diagnostics.clear()
    truthy(io.open(path, "rb") == nil, "current diagnostics log should be removed")
    truthy(io.open(path .. ".1", "rb") == nil, "rotated diagnostics log should be removed")
end)

os.remove(path)
os.remove(path .. ".1")
io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
