local JSON = require("json")
local http = require("socket.http")
local ltn12 = require("ltn12")
local socket = require("socket")
local socketutil = require("socketutil")
local Diagnostics = require("lib/diagnostics")

local M = {}

local TRANSIENT_STATUS = {
    [502] = true,
    [503] = true,
    [504] = true,
}

local function copy_headers(headers)
    local out = {}
    for k, v in pairs(headers or {}) do out[k] = v end
    return out
end

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

local function retry_delay(opts, attempt)
    local base = tonumber(opts and opts.retry_delay) or 0.35
    if base <= 0 then return end
    socket.sleep(math.min(base * attempt, 1.5))
end

local function default_retries(method, opts)
    if opts and opts.retries ~= nil then return math.max(0, tonumber(opts.retries) or 0) end
    method = tostring(method or "GET"):upper()
    if method == "GET" or method == "HEAD" then return 1 end
    return 0
end

local function log_http(method, url, message)
    Diagnostics.log("HTTP", tostring(method) .. " " .. Diagnostics.sanitize_url(url) .. " " .. tostring(message))
end

function M.is_transient_status(code)
    return TRANSIENT_STATUS[tonumber(code)] == true
end

function M.request(method, url, headers, body, opts)
    method = tostring(method or "GET"):upper()
    opts = opts or {}
    local retries = default_retries(method, opts)
    local last_err

    for attempt = 0, retries do
        local sink = {}
        local request_headers = copy_headers(headers)
        local req = {
            method = method,
            url = url,
            headers = request_headers,
            sink = ltn12.sink.table(sink),
        }
        if body then
            req.source = ltn12.source.string(body)
            request_headers["Content-Length"] = request_headers["Content-Length"] or tostring(#body)
        end

        local code, resp_headers, err = perform(req, opts.block_timeout, opts.total_timeout)
        if code then
            local res = {
                code = code,
                headers = resp_headers,
                body = table.concat(sink),
            }
            if code < 200 or code >= 400 then log_http(method, url, "-> HTTP " .. tostring(code)) end
            if attempt < retries and M.is_transient_status(code) then
                log_http(method, url, "retrying transient HTTP " .. tostring(code) .. " (" .. tostring(attempt + 1) .. "/" .. tostring(retries) .. ")")
                retry_delay(opts, attempt + 1)
            else
                return res
            end
        else
            last_err = err
            log_http(method, url, "network error: " .. tostring(err))
            if attempt < retries and opts.retry_network ~= false then
                log_http(method, url, "retrying network failure (" .. tostring(attempt + 1) .. "/" .. tostring(retries) .. ")")
                retry_delay(opts, attempt + 1)
            else
                return nil, last_err
            end
        end
    end

    return nil, last_err or "Request failed"
end

function M.json(method, url, headers, body_table, opts)
    headers = copy_headers(headers)
    headers["Accept"] = headers["Accept"] or "application/json"
    local body
    if body_table ~= nil then
        body = JSON.encode(body_table)
        headers["Content-Type"] = headers["Content-Type"] or "application/json"
    end
    local res, err = M.request(method, url, headers, body, opts)
    if not res then return nil, err end
    local decoded
    if res.body and res.body ~= "" then
        local ok
        ok, decoded = pcall(JSON.decode, res.body)
        if not ok then
            log_http(method, url, "invalid JSON response (HTTP " .. tostring(res.code) .. ")")
            return nil, "Invalid JSON response (HTTP " .. tostring(res.code) .. ")"
        end
    end
    res.json = decoded
    return res
end

local function file_size(filepath)
    local fh = io.open(filepath, "rb")
    if not fh then return nil end
    local size = fh:seek("end")
    fh:close()
    return size
end

local function read_prefix(filepath, length)
    local fh = io.open(filepath, "rb")
    if not fh then return nil end
    local data = fh:read(length or 16)
    fh:close()
    return data
end

local function image_type_from_magic(prefix)
    if type(prefix) ~= "string" then return nil end
    if #prefix >= 3 and prefix:byte(1) == 0xFF and prefix:byte(2) == 0xD8 and prefix:byte(3) == 0xFF then
        return "jpeg"
    end
    if prefix:sub(1, 8) == "\137PNG\r\n\26\n" then return "png" end
    if prefix:sub(1, 4) == "RIFF" and prefix:sub(9, 12) == "WEBP" then return "webp" end
    return nil
end

function M.validate_image_file(filepath, headers)
    local size = file_size(filepath)
    if not size then return nil, "Downloaded cover cannot be read" end
    if size < 128 then return nil, "Downloaded cover is too small to be a valid image" end

    local content_type
    if type(headers) == "table" then
        content_type = headers["content-type"] or headers["Content-Type"]
        if type(content_type) == "string" then
            content_type = content_type:lower():match("^%s*([^;]+)")
            if content_type and content_type ~= "application/octet-stream" and not content_type:match("^image/") then
                return nil, "Downloaded cover returned non-image Content-Type: " .. content_type
            end
        end
    end

    local image_type = image_type_from_magic(read_prefix(filepath, 16))
    if not image_type then
        return nil, "Downloaded cover is not a supported JPEG, PNG, or WebP image"
    end

    return true, {
        size = size,
        image_type = image_type,
        content_type = content_type,
    }
end

function M.download(url, filepath, headers, opts)
    opts = opts or {}
    local retries = opts.retries ~= nil and math.max(0, tonumber(opts.retries) or 0) or 1
    local last_err

    for attempt = 0, retries do
        local fh, ferr = io.open(filepath, "wb")
        if not fh then return nil, ferr end
        local req = {
            method = "GET",
            url = url,
            headers = copy_headers(headers),
            sink = ltn12.sink.file(fh),
        }
        local code, resp_headers, err = perform(req, opts.block_timeout or 10, opts.total_timeout or 45)
        -- ltn12 closes the file on a normal completed transfer, but a socket/error
        -- path may exit before the sink receives its final nil chunk.
        pcall(function() fh:close() end)

        if code and code >= 200 and code < 300 then
            return true, {
                code = code,
                headers = resp_headers,
                size = file_size(filepath),
            }
        end

        os.remove(filepath)
        last_err = err or ("HTTP " .. tostring(code))
        log_http("GET", url, code and ("download -> HTTP " .. tostring(code)) or ("download network error: " .. tostring(err)))
        local can_retry = attempt < retries and (not code or M.is_transient_status(code))
        if can_retry then
            log_http("GET", url, "retrying download (" .. tostring(attempt + 1) .. "/" .. tostring(retries) .. ")")
            retry_delay(opts, attempt + 1)
        else
            return nil, last_err
        end
    end

    return nil, last_err or "Download failed"
end

return M
