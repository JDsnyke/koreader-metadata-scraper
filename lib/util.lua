local M = {}

function M.trim(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.nonempty(s)
    return type(s) == "string" and M.trim(s) ~= ""
end

function M.copy(t)
    local out = {}
    if type(t) == "table" then
        for k, v in pairs(t) do out[k] = v end
    end
    return out
end

function M.array(v)
    if type(v) == "table" then return v end
    if v == nil or v == "" then return {} end
    return { v }
end

function M.join(values, sep, maxn)
    local out = {}
    for _, v in ipairs(M.array(values)) do
        if M.nonempty(tostring(v)) then
            table.insert(out, M.trim(tostring(v)))
            if maxn and #out >= maxn then break end
        end
    end
    return table.concat(out, sep or ", ")
end

function M.split_lines(s)
    local out = {}
    if type(s) ~= "string" then return out end
    for v in s:gmatch("[^\n]+") do
        v = M.trim(v)
        if v ~= "" then table.insert(out, v) end
    end
    return out
end

function M.urlencode(s)
    s = tostring(s or "")
    return (s:gsub("([^%w%-%._~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

function M.normalize(s)
    s = tostring(s or ""):lower()
    s = s:gsub("[%p%c]", " "):gsub("%s+", " ")
    return M.trim(s)
end

local function token_set(s)
    local set, n = {}, 0
    for tok in M.normalize(s):gmatch("%S+") do
        if not set[tok] then set[tok], n = true, n + 1 end
    end
    return set, n
end

function M.token_similarity(a, b)
    local A, na = token_set(a)
    local B, nb = token_set(b)
    if na == 0 or nb == 0 then return 0 end
    local intersection, union = 0, 0
    local seen = {}
    for k in pairs(A) do
        seen[k] = true
        union = union + 1
        if B[k] then intersection = intersection + 1 end
    end
    for k in pairs(B) do
        if not seen[k] then union = union + 1 end
    end
    if union == 0 then return 0 end
    return intersection / union
end

-- Comparison-only author canonicalization. Sorting normalized tokens makes
-- "Dinniman, Matt" equivalent to "Matt Dinniman" without trying to guess whether
-- a comma means surname-first notation or separates multiple authors. Stored and
-- displayed author text is never rewritten from this helper.
function M.normalize_author(s)
    local tokens = {}
    for tok in M.normalize(s):gmatch("%S+") do table.insert(tokens, tok) end
    table.sort(tokens)
    return table.concat(tokens, " ")
end

function M.author_similarity(a, b)
    local na = M.normalize_author(a)
    local nb = M.normalize_author(b)
    if na == "" or nb == "" then return 0 end
    if na == nb then return 1 end
    return M.token_similarity(na, nb)
end

-- Return a broad media kind only when a provider value is explicit enough to be
-- useful as edition evidence. Unknown/ambiguous values intentionally return nil.
function M.format_kind(v)
    local s = M.normalize(v)
    if s == "" then return nil end

    local audio_markers = {
        "audiobook", "audio book", "audible", "audio cd", "audio compact disc",
        "mp3 cd", "mp3 audiobook", "unabridged", "abridged", "full cast",
    }
    for _, marker in ipairs(audio_markers) do
        if s:find(marker, 1, true) then return "audiobook" end
    end

    local ebook_markers = { "ebook", "e book", "kindle", "digital book", "electronic book" }
    for _, marker in ipairs(ebook_markers) do
        if s:find(marker, 1, true) then return "ebook" end
    end

    local print_markers = {
        "paperback", "hardcover", "hardback", "mass market", "library binding",
        "board book", "spiral bound", "print book",
    }
    for _, marker in ipairs(print_markers) do
        if s:find(marker, 1, true) then return "print" end
    end

    return nil
end

local function raw_isbn(v)
    if not v then return nil end
    local s = tostring(v):upper():gsub("[^0-9X]", "")
    if #s == 10 or #s == 13 then return s end
end

local function valid_isbn10(s)
    if type(s) ~= "string" or #s ~= 10 or not s:match("^%d%d%d%d%d%d%d%d%d[%dX]$") then return false end
    local sum = 0
    for i = 1, 10 do
        local c = s:sub(i, i)
        local n = c == "X" and 10 or tonumber(c)
        sum = sum + n * (11 - i)
    end
    return sum % 11 == 0
end

local function valid_isbn13(s)
    if type(s) ~= "string" or #s ~= 13 or not s:match("^%d%d%d%d%d%d%d%d%d%d%d%d%d$") then return false end
    local sum = 0
    for i = 1, 13 do
        local n = tonumber(s:sub(i, i)) or 0
        sum = sum + n * (i % 2 == 0 and 3 or 1)
    end
    return sum % 10 == 0
end

function M.clean_isbn(v)
    local s = raw_isbn(v)
    if not s then return nil end
    if #s == 10 and valid_isbn10(s) then return s end
    if #s == 13 and valid_isbn13(s) then return s end
end

local function isbn13_from_isbn10(v)
    local s = M.clean_isbn(v)
    if not s or #s ~= 10 then return nil end
    local base = "978" .. s:sub(1, 9)
    local sum = 0
    for i = 1, 12 do
        local n = tonumber(base:sub(i, i)) or 0
        sum = sum + n * (i % 2 == 0 and 3 or 1)
    end
    return base .. tostring((10 - (sum % 10)) % 10)
end

function M.canonical_isbn(v)
    local s = M.clean_isbn(v)
    if not s then return nil end
    if #s == 13 then return s end
    return isbn13_from_isbn10(s)
end

function M.find_isbns(values)
    local isbn10, isbn13
    for _, v in ipairs(M.array(values)) do
        local s = M.clean_isbn(v)
        if s then
            if #s == 13 and not isbn13 then isbn13 = s end
            if #s == 10 and not isbn10 then isbn10 = s end
        end
    end
    return isbn10, isbn13
end

local function append_identifier_strings(value, out, depth)
    depth = depth or 0
    if depth > 4 then return end
    if type(value) == "string" or type(value) == "number" then
        table.insert(out, tostring(value))
    elseif type(value) == "table" then
        for _, v in pairs(value) do append_identifier_strings(v, out, depth + 1) end
    end
end

function M.extract_isbns(value)
    local strings = {}
    append_identifier_strings(value, strings)
    local isbn10, isbn13

    local function consider(candidate)
        local s = M.clean_isbn(candidate)
        if s then
            if #s == 13 and not isbn13 then isbn13 = s end
            if #s == 10 and not isbn10 then isbn10 = s end
        end
    end

    for _, raw in ipairs(strings) do
        consider(raw)
        for tagged in raw:gmatch("[Ii][Ss][Bb][Nn][%s%-%_:]*([0-9Xx%-%s]+)") do
            consider(tagged)
        end
        for urn in raw:gmatch("[Uu][Rr][Nn]:[Ii][Ss][Bb][Nn]:([0-9Xx%-]+)") do
            consider(urn)
        end
        for candidate in raw:gmatch("[0-9Xx][0-9Xx%-%s]+") do
            consider(candidate)
        end
        if isbn10 and isbn13 then break end
    end

    return isbn10, isbn13
end

function M.first(v)
    if type(v) == "table" then return v[1] end
    return v
end

function M.get(t, ...)
    local cur = t
    for i = 1, select("#", ...) do
        if type(cur) ~= "table" then return nil end
        cur = cur[select(i, ...)]
    end
    return cur
end

function M.safe_filename(s)
    s = tostring(s or "cover")
    s = s:gsub("[^%w%._%-]", "_")
    if #s > 80 then s = s:sub(1, 80) end
    return s
end

function M.ext_from_url(url)
    local path = tostring(url or ""):match("^[^?]+") or ""
    local ext = path:match("%.([%a%d]+)$")
    ext = ext and ext:lower() or "jpg"
    if ext ~= "jpg" and ext ~= "jpeg" and ext ~= "png" and ext ~= "webp" then ext = "jpg" end
    return ext
end

function M.language_code(v)
    if type(v) == "table" then v = v[1] end
    if type(v) ~= "string" then return nil end
    local s = v:lower():gsub("_", "-")
    local map = {
        eng = "en", fre = "fr", fra = "fr", ger = "de", deu = "de", spa = "es",
        ita = "it", por = "pt", nld = "nl", dut = "nl", jpn = "ja", zho = "zh",
        chi = "zh", rus = "ru", sin = "si", tam = "ta", hin = "hi",
        english = "en", french = "fr", german = "de", spanish = "es", italian = "it",
        portuguese = "pt", dutch = "nl", japanese = "ja", chinese = "zh", russian = "ru",
        sinhala = "si", tamil = "ta", hindi = "hi",
    }
    return map[s] or s
end

function M.year(v)
    if type(v) == "number" then
        local n = math.floor(v)
        if n >= 1000 and n <= 9999 then return n end
    end
    if type(v) ~= "string" then return nil end
    local y = tonumber(v:match("(%d%d%d%d)"))
    if y and y >= 1000 and y <= 9999 then return y end
end

return M
