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

local function reset_http_modules()
    package.loaded["lib/http"] = nil
    package.loaded["json"] = nil
    package.loaded["socket.http"] = nil
    package.loaded["ltn12"] = nil
    package.loaded["socket"] = nil
    package.loaded["socketutil"] = nil
end

local request_handler
local sleep_calls = 0

package.preload["json"] = function()
    return {
        encode = function() return "{}" end,
        decode = function() return {} end,
    }
end

package.preload["ltn12"] = function()
    return {
        sink = {
            table = function(target)
                return function(chunk)
                    if chunk then table.insert(target, chunk) end
                    return 1
                end
            end,
            file = function(fh)
                return function(chunk)
                    if chunk then fh:write(chunk) else fh:close() end
                    return 1
                end
            end,
        },
        source = {
            string = function(body)
                local sent = false
                return function()
                    if sent then return nil end
                    sent = true
                    return body
                end
            end,
        },
    }
end

package.preload["socket"] = function()
    return {
        skip = function(n, ...)
            local values = { ... }
            return unpack(values, n + 1)
        end,
        sleep = function() sleep_calls = sleep_calls + 1 end,
    }
end

package.preload["socketutil"] = function()
    return {
        set_timeout = function() end,
        reset_timeout = function() end,
    }
end

package.preload["socket.http"] = function()
    return {
        request = function(req)
            return request_handler(req)
        end,
    }
end

local function load_http()
    package.loaded["lib/http"] = nil
    package.loaded["socket.http"] = nil
    package.loaded["ltn12"] = nil
    package.loaded["socket"] = nil
    package.loaded["socketutil"] = nil
    return require("lib/http")
end

check("GET retries one transient HTTP failure", function()
    local calls = 0
    sleep_calls = 0
    request_handler = function(req)
        calls = calls + 1
        if calls == 1 then return 1, 503, {}, "Service Unavailable" end
        req.sink("ok")
        req.sink(nil)
        return 1, 200, { ["content-type"] = "text/plain" }, "OK"
    end
    local HTTP = load_http()
    local res = assert(HTTP.request("GET", "https://example.test", nil, nil, { retry_delay = 0 }))
    eq(res.code, 200)
    eq(res.body, "ok")
    eq(calls, 2)
    eq(sleep_calls, 0)
end)

check("POST does not retry transient status by default", function()
    local calls = 0
    request_handler = function()
        calls = calls + 1
        return 1, 503, {}, "Service Unavailable"
    end
    local HTTP = load_http()
    local res = assert(HTTP.request("POST", "https://example.test", nil, "{}", { retry_delay = 0 }))
    eq(res.code, 503)
    eq(calls, 1)
end)

check("HTTP 429 is never treated as a generic transient retry", function()
    local calls = 0
    request_handler = function()
        calls = calls + 1
        return 1, 429, {}, "Too Many Requests"
    end
    local HTTP = load_http()
    local res = assert(HTTP.request("GET", "https://example.test", nil, nil, { retry_delay = 0 }))
    eq(res.code, 429)
    eq(calls, 1)
end)

check("cover validation accepts PNG magic and rejects HTML", function()
    request_handler = function() return 1, 200, {}, "OK" end
    local HTTP = load_http()
    local png = os.tmpname() .. ".png"
    local html = os.tmpname() .. ".jpg"

    local fh = assert(io.open(png, "wb"))
    fh:write("\137PNG\r\n\26\n" .. string.rep("x", 256))
    fh:close()
    fh = assert(io.open(html, "wb"))
    fh:write("<html>" .. string.rep("x", 256) .. "</html>")
    fh:close()

    local ok, meta = HTTP.validate_image_file(png, { ["content-type"] = "image/png" })
    truthy(ok)
    eq(meta.image_type, "png")

    local bad, err = HTTP.validate_image_file(html, { ["content-type"] = "text/html" })
    eq(bad, nil)
    truthy(tostring(err):find("non%-image") ~= nil)

    os.remove(png)
    os.remove(html)
end)

check("writer validates new cover before touching existing cover", function()
    request_handler = function() return 1, 200, {}, "OK" end
    local HTTP = load_http()
    package.loaded["lib/http"] = HTTP
    package.loaded["lib/writer"] = nil
    package.loaded["docsettings"] = nil
    package.loaded["ui/event"] = nil
    package.loaded["ui/uimanager"] = nil

    local touched_existing = false
    package.preload["docsettings"] = function()
        return {
            findCustomCoverFile = function()
                touched_existing = true
                return nil
            end,
        }
    end
    package.preload["ui/event"] = function()
        return { new = function(_, name, file) return { name = name, file = file } end }
    end
    package.preload["ui/uimanager"] = function()
        return { broadcastEvent = function() end }
    end

    local invalid = os.tmpname() .. ".jpg"
    local fh = assert(io.open(invalid, "wb"))
    fh:write("<html>" .. string.rep("error", 50) .. "</html>")
    fh:close()

    local Writer = require("lib/writer")
    local ok, err = Writer.write_cover("book.epub", invalid)
    eq(ok, nil)
    truthy(err ~= nil)
    eq(touched_existing, false, "existing cover should not be inspected before validation")
    os.remove(invalid)
end)

check("writer converts KOReader metadata exceptions into controlled failures", function()
    request_handler = function() return 1, 200, {}, "OK" end
    local HTTP = load_http()
    package.loaded["lib/http"] = HTTP
    package.loaded["lib/writer"] = nil
    package.loaded["docsettings"] = nil
    package.loaded["ui/event"] = nil
    package.loaded["ui/uimanager"] = nil

    package.preload["docsettings"] = function()
        return {
            findCustomMetadataFile = function() error("simulated KOReader metadata failure") end,
        }
    end
    package.preload["ui/event"] = function()
        return { new = function(_, name, file) return { name = name, file = file } end }
    end
    package.preload["ui/uimanager"] = function()
        return { broadcastEvent = function() end }
    end

    local Writer = require("lib/writer")
    local ok, err = Writer.write("book.epub", {}, {}, {}, true)
    eq(ok, nil)
    truthy(tostring(err):find("simulated KOReader metadata failure", 1, true) ~= nil)
end)

check("matcher discards malformed provider records instead of crashing", function()
    package.loaded["lib/matcher"] = nil
    local Matcher = require("lib/matcher")
    local results = {
        false,
        "bad",
        { source = "good", id = "1", title = "Matilda", authors = { "Roald Dahl" }, authors_text = "Roald Dahl" },
        { source = "other", id = "2", title = setmetatable({}, { __tostring = function() error("bad title") end }) },
    }
    local ranked = Matcher.rank({ title = "Matilda", author = "Roald Dahl" }, results, { good = 1 })
    truthy(type(ranked) == "table")
    eq(#ranked, 1)
    eq(ranked[1].source, "good")
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
