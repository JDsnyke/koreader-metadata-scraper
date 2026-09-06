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

local function read_file(path)
    local fh = assert(io.open(path, "rb"))
    local data = fh:read("*all")
    fh:close()
    return data
end

check("main KOReader plugin actions preserve the Metadata Scraper menu", function()
    local data = read_file("main.lua")
    truthy(data:find('text = _("Fetch metadata for current book")', 1, true), "current-book action missing")
    truthy(data:find('keep_menu_open = true,\n                callback = function() self:startForFile(self:getCurrentFile()) end,', 1, true), "current-book action does not keep plugin menu open")
    truthy(data:find('{ text = _("Choose EPUB…"), keep_menu_open = true', 1, true), "EPUB chooser does not keep plugin menu open")
    truthy(data:find('{ text = _("Batch folder…"), keep_menu_open = true', 1, true), "batch chooser does not keep plugin menu open")
    truthy(data:find('text = _("About"),\n                keep_menu_open = true,', 1, true), "About does not keep plugin menu open")
end)

check("context Metadata actions keep their parent dialog underneath child windows", function()
    local data = read_file("main.lua")
    truthy(not data:find('UIManager:close(dialog); self:startForFile(file)', 1, true), "book action closes its parent before search")
    truthy(not data:find('UIManager:close(dialog); self:showQuickSettings()', 1, true), "context action closes its parent before settings")
    truthy(not data:find('UIManager:close(dialog); self:editHardcover()', 1, true), "Quick Settings closes before Hardcover editor")
    truthy(not data:find('UIManager:close(dialog); self:testProviders()', 1, true), "Quick Settings closes before provider diagnostics")
end)

check("ZenPM documentation exposes a paste-ready Pages source URL", function()
    local source = "https://jdsnyke.github.io/koreader-metadata-scraper/"
    truthy(read_file("README.md"):find(source, 1, true), "README missing ZenPM Pages source URL")
    truthy(read_file("docs/zenpm.md"):find(source, 1, true), "ZenPM guide missing Pages source URL")
    truthy(not read_file("README.md"):find("https://raw.githubusercontent.com/JDsnyke/koreader-metadata-scraper/main/", 1, true), "README still recommends raw GitHub source")
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
