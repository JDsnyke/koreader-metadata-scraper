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

local function contains(values, wanted)
    for _, value in ipairs(values or {}) do
        if value == wanted then return true end
    end
    return false
end

local Matcher = require("lib/matcher")

check("conflicting ISBN caps otherwise exact title and author", function()
    local score, reasons = Matcher.score({
        title = "Matilda",
        author = "Roald Dahl",
        isbn = "9780140328721",
    }, {
        title = "Matilda",
        authors = { "Roald Dahl" },
        authors_text = "Roald Dahl",
        isbn13 = "9780306406157",
    })
    truthy(score <= 35, "conflicting ISBN must remain far below auto-apply threshold")
    truthy(contains(reasons, "ISBN conflict"))
    truthy(Matcher.confidence(score, reasons) == "Weak")
end)

check("missing result ISBN does not falsely create an ISBN conflict", function()
    local score, reasons = Matcher.score({
        title = "Matilda",
        author = "Roald Dahl",
        isbn = "9780140328721",
    }, {
        title = "Matilda",
        authors = { "Roald Dahl" },
        authors_text = "Roald Dahl",
    })
    truthy(score >= 90)
    truthy(not contains(reasons, "ISBN conflict"))
    truthy(Matcher.confidence(score, reasons) == "Strong")
end)

check("language conflict keeps textual match below default batch threshold", function()
    local score, reasons = Matcher.score({
        title = "Matilda",
        author = "Roald Dahl",
        language = "en",
    }, {
        title = "Matilda",
        authors = { "Roald Dahl" },
        authors_text = "Roald Dahl",
        language = "fr",
    })
    truthy(score < 90)
    truthy(contains(reasons, "language conflict"))
end)

check("strong author conflict penalizes exact title", function()
    local score, reasons = Matcher.score({
        title = "Home",
        author = "Alice Writer",
    }, {
        title = "Home",
        authors = { "Completely Different" },
        authors_text = "Completely Different",
    })
    truthy(score < 70)
    truthy(contains(reasons, "author conflict"))
    truthy(Matcher.confidence(score, reasons) == "Weak")
end)

check("strong series conflict prevents automatic acceptance", function()
    local score, reasons = Matcher.score({
        title = "The Beginning",
        author = "Example Author",
        series = "Alpha Chronicles",
    }, {
        title = "The Beginning",
        authors = { "Example Author" },
        authors_text = "Example Author",
        series = "Omega Saga",
    })
    truthy(score < 90)
    truthy(contains(reasons, "series conflict"))
end)

check("exact ISBN remains authoritative even when text differs", function()
    local score, reasons = Matcher.score({
        title = "Local Metadata Title",
        author = "Local Author",
        isbn = "9780140328721",
    }, {
        title = "Provider Edition Title",
        authors = { "Provider Author" },
        authors_text = "Provider Author",
        isbn13 = "9780140328721",
    })
    truthy(score == 100)
    truthy(contains(reasons, "ISBN exact"))
    truthy(Matcher.confidence(score, reasons) == "Exact")
end)

check("rank attaches confidence class to provider results", function()
    local results = {{
        source = "test",
        id = "1",
        title = "Matilda",
        authors = { "Roald Dahl" },
        authors_text = "Roald Dahl",
    }}
    Matcher.rank({ title = "Matilda", author = "Roald Dahl" }, results, { test = 1 })
    truthy(results[1].confidence == "Strong")
end)

check("middling clean evidence is classified Possible", function()
    truthy(Matcher.confidence(75, { "title similar", "author similar" }) == "Possible")
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
