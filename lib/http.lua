local JSON = require("json")
local http = require("socket.http")
local ltn12 = require("ltn12")
local socket = require("socket")
local socketutil = require("socketutil")

local M = {}

local function perform(req, block_timeout, total_timeout)
    block_timeout = block_timeout or 10
    total_timeout = total_timeout or 30
    socketutil:set_timeout(block_timeout, total_timeout)
    local ok, code, headers, status = pcall(function()
        return socket.skip(1, http.request(req))
    end)
    socketutil:reset_timeout()
    if not ok then return nil, nil, tostring(code) end
    if headers == nil then return nil, nil, status or code end
    return tonumber(code), headers, status
end

function M.request(method, url, headers, body)
    local sink = {}
    headers = headers or {}
    local req = {
        method = method or "GET",
        url = url,
        headers = headers,
        sink = ltn12.sink.table(sink),
    }
    if body then
        req.source = ltn12.source.string(body)
        headers["Content-Length"] = headers["Content-Length"] or tostring(#body)
    end
    local code, resp_headers, err = perform(req)
    if not code then return nil, err end
    return {
        code = code,
        headers = resp_headers,
        body = table.concat(sink),
    }
end

function M.json(method, url, headers, body_table)
    headers = headers or {}
    headers["Accept"] = headers["Accept"] or "application/json"
    local body
    if body_table ~= nil then
        body = JSON.encode(body_table)
        headers["Content-Type"] = headers["Content-Type"] or "application/json"
    end
    local res, err = M.request(method, url, headers, body)
    if not res then return nil, err end
    local decoded
    if res.body and res.body ~= "" then
        local ok
        ok, decoded = pcall(JSON.decode, res.body)
        if not ok then return nil, "Invalid JSON response (HTTP " .. tostring(res.code) .. ")" end
    end
    res.json = decoded
    return res
end

function M.download(url, filepath, headers)
    local fh, ferr = io.open(filepath, "wb")
    if not fh then return nil, ferr end
    local req = {
        method = "GET",
        url = url,
        headers = headers or {},
        sink = ltn12.sink.file(fh),
    }
    local code, _, err = perform(req, 10, 45)
    if not code or code < 200 or code >= 300 then
        os.remove(filepath)
        return nil, err or ("HTTP " .. tostring(code))
    end
    return true
end

return M
