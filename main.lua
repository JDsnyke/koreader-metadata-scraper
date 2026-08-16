local BookInfo = require("apps/filemanager/filemanagerbookinfo")
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local DocumentRegistry = require("document/documentregistry")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local NetworkMgr = require("ui/network/manager")
local PathChooser = require("ui/widget/pathchooser")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local _ = require("gettext")

local U = require("lib/util")
local Matcher = require("lib/matcher")
local Writer = require("lib/writer")
local HTTP = require("lib/http")
local Updater = require("lib/updater")
local Version = require("lib/version")
local Diagnostics = require("lib/diagnostics")

local PROVIDERS = {
    hardcover = require("providers/hardcover"),
    amazon = require("providers/amazon"),
    google = require("providers/googlebooks"),
    openlibrary = require("providers/openlibrary"),
}
local DEFAULT_ORDER = { "hardcover", "amazon", "google", "openlibrary" }

local DEFAULTS = {
    enabled = { hardcover = false, amazon = false, google = false, openlibrary = true },
    source_scope = "all",
    hardcover_token = "",
    google_api_key = "",
    amazon_client_id = "",
    amazon_client_secret = "",
    amazon_credential_version = "",
    amazon_partner_tag = "",
    amazon_marketplace = "www.amazon.com.au",
    amazon_search_index = "Books",
    replace_existing = true,
    download_cover = true,
    batch_threshold = 90,
    batch_limit = 20,
    batch_skip_matched = true,
    auto_update_check = true,
    last_update_check = 0,
    fields = {
        title = true, authors = true, series = true, series_index = true,
        language = true, keywords = true, description = true,
    },
    book_links = {},
    undo_records = {},
}

local MARKETPLACES = {
    { "Australia", "www.amazon.com.au" }, { "United States", "www.amazon.com" },
    { "United Kingdom", "www.amazon.co.uk" }, { "Canada", "www.amazon.ca" },
    { "Germany", "www.amazon.de" }, { "France", "www.amazon.fr" },
    { "Italy", "www.amazon.it" }, { "Spain", "www.amazon.es" },
    { "India", "www.amazon.in" }, { "Japan", "www.amazon.co.jp" },
    { "Singapore", "www.amazon.sg" }, { "Netherlands", "www.amazon.nl" },
}

local PREVIEW_LABELS = {
    title = "Title",
    authors = "Authors",
    series = "Series",
    series_index = "Series index",
    language = "Language",
    keywords = "Keywords / genres",
    description = "Description",
}

local FIELD_DEFS = {
    { "title", "Title" }, { "authors", "Authors" }, { "series", "Series" },
    { "series_index", "Series index" }, { "language", "Language" },
    { "keywords", "Keywords / genres" }, { "description", "Description" },
}

local source = debug.getinfo(1, "S").source or ""
if source:sub(1, 1) == "@" then source = source:sub(2) end
local PLUGIN_ROOT = source:match("^(.*)/main%.lua$") or "."

local MetadataScraper = WidgetContainer:extend{
    name = "metadata_scraper",
    is_doc_only = false,
    settings_file = DataStorage:getSettingsDir() .. "/metadata_scraper.lua",
}

local function clone_defaults()
    local d = U.copy(DEFAULTS)
    d.enabled = U.copy(DEFAULTS.enabled)
    d.fields = U.copy(DEFAULTS.fields)
    d.book_links = {}
    d.undo_records = {}
    return d
end

local function display_value(value, limit)
    if value == nil or tostring(value) == "" then return _("empty") end
    local text = tostring(value):gsub("\r", ""):gsub("\n+", ", "):gsub("%s+", " ")
    limit = limit or 62
    if #text > limit then text = text:sub(1, limit - 1) .. "…" end
    return text
end

local function confidence_label(value)
    local labels = {
        Exact = _("Exact"), Strong = _("Strong"), Possible = _("Possible"), Weak = _("Weak"),
    }
    return labels[value] or tostring(value or _("Unknown"))
end

local function provider_status_text(provider, settings)
    if not provider or type(provider.status) ~= "function" then return nil end
    local ok, text = pcall(provider.status, settings)
    if ok and text and tostring(text) ~= "" then return tostring(text) end
end

function MetadataScraper:init()
    self.settings_store = LuaSettings:open(self.settings_file)
    self.settings = clone_defaults()
    local saved = self.settings_store:readSetting("config")
    if type(saved) == "table" then
        for k, v in pairs(saved) do self.settings[k] = v end
        self.settings.enabled = U.copy(DEFAULTS.enabled)
        for k, v in pairs(saved.enabled or {}) do self.settings.enabled[k] = v end
        self.settings.fields = U.copy(DEFAULTS.fields)
        for k, v in pairs(saved.fields or {}) do self.settings.fields[k] = v end
        self.settings.book_links = saved.book_links or {}
        self.settings.undo_records = saved.undo_records or {}
    end
    self.ui.menu:registerToMainMenu(self)
    self:installZenContextHook()
    UIManager:nextTick(function() self:maybeCheckForUpdates() end)
end

function MetadataScraper:onZenUIReady()
    self:installZenContextHook()
end

function MetadataScraper:saveSettings()
    self.settings_store:saveSetting("config", self.settings)
    self.settings_store:flush()
end

function MetadataScraper:onFlushSettings()
    self:saveSettings()
end

function MetadataScraper:maybeCheckForUpdates()
    if not self.settings.auto_update_check then return end
    local last = tonumber(self.settings.last_update_check) or 0
    if os.time() - last < 86400 then return end
    -- Never wake Wi-Fi merely for an automatic check.
    if not NetworkMgr.is_connected then return end
    self:checkForUpdates(true)
end

function MetadataScraper:installUpdate(release)
    local busy = InfoMessage:new{ text = _("Downloading Metadata Scraper update…") }
    UIManager:show(busy); UIManager:forceRePaint()
    local ok, err = Updater.install(release, PLUGIN_ROOT)
    UIManager:close(busy)
    if ok then
        UIManager:show(InfoMessage:new{
            text = string.format(_("Metadata Scraper %s installed.\n\nRestart KOReader to load the new version."), release.version),
        })
    else
        Diagnostics.log("Updater", err or "Unknown update failure", self.settings)
        UIManager:show(InfoMessage:new{ text = _("Update failed.") .. "\n" .. tostring(err) })
    end
end

function MetadataScraper:showUpdateAvailable(release)
    local box
    local text = string.format(_("Metadata Scraper %s is available.\n\nInstalled: %s\n\nDownload and install it now?"),
        release.version, Updater.CURRENT_VERSION)
    box = ConfirmBox:new{
        text = text,
        ok_text = _("Update"),
        ok_callback = function()
            UIManager:close(box)
            self:installUpdate(release)
        end,
    }
    UIManager:show(box)
end

function MetadataScraper:checkForUpdates(silent)
    local function do_check()
        local busy
        if not silent then
            busy = InfoMessage:new{ text = _("Checking for Metadata Scraper updates…") }
            UIManager:show(busy); UIManager:forceRePaint()
        end
        local release, err = Updater.check()
        self.settings.last_update_check = os.time()
        self:saveSettings()
        if busy then UIManager:close(busy) end
        if not release then
            Diagnostics.log("Updater", err or "Update check failed", self.settings)
            if not silent then UIManager:show(InfoMessage:new{ text = _("Update check failed.") .. "\n" .. tostring(err) }) end
            return
        end
        if release.available then
            self:showUpdateAvailable(release)
        elseif not silent then
            UIManager:show(InfoMessage:new{
                text = string.format(_("Metadata Scraper is up to date.\n\nInstalled: %s"), Updater.CURRENT_VERSION),
            })
        end
    end

    if silent then
        do_check()
    else
        NetworkMgr:runWhenOnline(do_check)
    end
end

function MetadataScraper:isEpub(file)
    return type(file) == "string" and file:lower():match("%.epub$") ~= nil
end

function MetadataScraper:installZenContextHook()
    if not rawget(_G, "__ZEN_UI_PLUGIN") then return end
    local fc = self.ui and self.ui.file_chooser
    if not fc or fc._metadata_scraper_context_hook then return end
    local original = fc.showFileDialog
    if type(original) ~= "function" then return end
    fc._metadata_scraper_context_hook = true
    local plugin = self
    fc.showFileDialog = function(fc_self, item)
        if type(item) == "table" then
            local path = item.path or item.file or item.filepath
            if item.is_file and plugin:isEpub(path) then
                local copy = U.copy(item)
                local extra = {}
                for _, row in ipairs(item._zen_extra_buttons or {}) do table.insert(extra, row) end
                table.insert(extra, {{
                    text = _("Metadata"),
                    align = "left",
                    callback = function()
                        if fc_self.file_dialog then UIManager:close(fc_self.file_dialog) end
                        UIManager:nextTick(function() plugin:showBookActions(path) end)
                    end,
                }})
                copy._zen_extra_buttons = extra
                return original(fc_self, copy)
            elseif not item.is_file and path and lfs.attributes(path, "mode") == "directory" then
                local copy = U.copy(item)
                local extra = {}
                for _, row in ipairs(item._zen_extra_buttons or {}) do table.insert(extra, row) end
                table.insert(extra, {{
                    text = _("Metadata"),
                    align = "left",
                    callback = function()
                        if fc_self.file_dialog then UIManager:close(fc_self.file_dialog) end
                        UIManager:nextTick(function() plugin:showFolderActions(path) end)
                    end,
                }})
                copy._zen_extra_buttons = extra
                return original(fc_self, copy)
            end
        end
        return original(fc_self, item)
    end
end

function MetadataScraper:getRawProps(file)
    local ok, raw, effective = pcall(function()
        local doc = DocumentRegistry:hasProvider(file) and DocumentRegistry:openDocument(file)
        if not doc then return {}, {} end
        local loaded = true
        if doc.loadDocument then loaded = doc:loadDocument(false) end
        local props = loaded and (doc:getProps() or {}) or {}
        doc:close()
        return props, BookInfo.extendProps(props, file)
    end)
    if not ok then
        Diagnostics.log("KOReader metadata", raw, self.settings)
        return {}, {}
    end
    return raw or {}, effective or {}
end

function MetadataScraper:getCurrentFile()
    if self.document and self.document.file then return self.document.file end
    if self.ui and self.ui.document and self.ui.document.file then return self.ui.document.file end
end

function MetadataScraper:chooseEpub()
    local chooser
    chooser = PathChooser:new{
        select_directory = false,
        file_filter = function(filename) return self:isEpub(filename) end,
        onConfirm = function(file)
            UIManager:close(chooser)
            self:startForFile(file)
        end,
    }
    UIManager:show(chooser)
end

function MetadataScraper:chooseBatchFolder()
    local chooser
    chooser = PathChooser:new{
        select_directory = true,
        onConfirm = function(path)
            UIManager:close(chooser)
            self:confirmBatch(path)
        end,
    }
    UIManager:show(chooser)
end

function MetadataScraper:showSelectDialog(title, options, current, callback)
    local dialog
    local rows = {}
    for _, opt in ipairs(options) do
        local label, value = opt[1], opt[2]
        table.insert(rows, {{
            text = label .. (value == current and "  ✓" or ""),
            align = "left",
            callback = function()
                UIManager:close(dialog)
                callback(value)
            end,
        }})
    end
    dialog = ButtonDialog:new{ title = title, title_align = "center", buttons = rows }
    UIManager:show(dialog)
end

function MetadataScraper:showBookActions(file)
    local dialog
    local rows = {
        {{ text = _("Fetch metadata"), align = "left", callback = function() self:startForFile(file) end }},
    }
    if self.settings.undo_records[file] then
        table.insert(rows, {{ text = _("Undo last metadata update"), align = "left", callback = function() self:confirmUndo(file) end }})
    end
    if self.settings.book_links[file] then
        table.insert(rows, {{ text = _("Last match details"), align = "left", callback = function() self:showLastMatchDetails(file) end }})
    end
    table.insert(rows, {{ text = _("Search source") .. ": " .. self:getSourceLabel(), align = "left", callback = function() self:showSourceSelector() end }})
    table.insert(rows, {{ text = _("Settings"), align = "left", callback = function() self:showQuickSettings() end }})
    dialog = ButtonDialog:new{ title = _("Metadata"), title_align = "center", buttons = rows }
    UIManager:show(dialog)
end

function MetadataScraper:showFolderActions(path)
    local dialog
    dialog = ButtonDialog:new{
        title = _("Metadata"), title_align = "center",
        buttons = {
            {{ text = _("Fetch metadata in folder"), align = "left", callback = function() self:confirmBatch(path) end }},
            {{ text = _("Search source") .. ": " .. self:getSourceLabel(), align = "left", callback = function() self:showSourceSelector() end }},
            {{ text = _("Settings"), align = "left", callback = function() self:showQuickSettings() end }},
        },
    }
    UIManager:show(dialog)
end

function MetadataScraper:getSourceLabel()
    for _, o in ipairs(self:sourceOptions()) do
        if o[2] == self.settings.source_scope then return o[1] end
    end
    return _("All enabled sources")
end

function MetadataScraper:showProviderDialog()
    local dialog
    local rows = {}
    for _, id in ipairs(DEFAULT_ORDER) do
        local provider = PROVIDERS[id]
        local status = provider_status_text(provider, self.settings)
        local text = provider.label
        if status then text = text .. " · " .. status end
        if self.settings.enabled[id] then text = text .. "  ✓" end
        table.insert(rows, {{
            text = text, align = "left",
            callback = function()
                self.settings.enabled[id] = not self.settings.enabled[id]
                self:saveSettings()
                UIManager:close(dialog)
                UIManager:nextTick(function() self:showProviderDialog() end)
            end,
        }})
    end
    dialog = ButtonDialog:new{ title = _("Providers"), title_align = "center", buttons = rows }
    UIManager:show(dialog)
end

function MetadataScraper:showFieldDialog()
    local dialog
    local rows = {}
    for _, def in ipairs(FIELD_DEFS) do
        local key, label = def[1], _(def[2])
        table.insert(rows, {{
            text = label .. (self.settings.fields[key] and "  ✓" or ""), align = "left",
            callback = function()
                self.settings.fields[key] = not self.settings.fields[key]
                self:saveSettings()
                UIManager:close(dialog)
                UIManager:nextTick(function() self:showFieldDialog() end)
            end,
        }})
    end
    table.insert(rows, {{
        text = _("Cover") .. (self.settings.download_cover and "  ✓" or ""), align = "left",
        callback = function()
            self.settings.download_cover = not self.settings.download_cover
            self:saveSettings(); UIManager:close(dialog)
            UIManager:nextTick(function() self:showFieldDialog() end)
        end,
    }})
    dialog = ButtonDialog:new{ title = _("Metadata fields"), title_align = "center", buttons = rows }
    UIManager:show(dialog)
end

function MetadataScraper:showBatchThresholdSelector()
    self:showSelectDialog(_("Batch confidence threshold"), {
        { _("Strict (95%)"), 95 },
        { _("Recommended (90%)"), 90 },
        { _("Permissive (80%)"), 80 },
    }, tonumber(self.settings.batch_threshold) or 90, function(value)
        self.settings.batch_threshold = value
        self:saveSettings()
    end)
end

function MetadataScraper:showQuickSettings()
    local dialog
    local replace = self.settings.replace_existing and _("Replace existing") or _("Fill missing only")
    local threshold = tonumber(self.settings.batch_threshold) or 90
    dialog = ButtonDialog:new{
        title = _("Metadata Scraper"), title_align = "center",
        buttons = {
            {{ text = _("Search source") .. ": " .. self:getSourceLabel(), align = "left", callback = function() self:showSourceSelector() end }},
            {{ text = _("Providers"), align = "left", callback = function() self:showProviderDialog() end }},
            {{ text = _("Test provider connections…"), align = "left", callback = function() self:testProviders() end }},
            {{ text = _("Save support diagnostics…"), align = "left", callback = function() self:saveSupportDiagnostics() end }},
            {{ text = _("Metadata fields"), align = "left", callback = function() self:showFieldDialog() end }},
            {{ text = _("Write mode") .. ": " .. replace, align = "left", callback = function()
                self.settings.replace_existing = not self.settings.replace_existing; self:saveSettings()
                UIManager:close(dialog); UIManager:nextTick(function() self:showQuickSettings() end)
            end }},
            {{ text = _("Batch threshold") .. ": " .. tostring(threshold) .. "%", align = "left", callback = function() self:showBatchThresholdSelector() end }},
            {{ text = _("Skip already matched in batch") .. (self.settings.batch_skip_matched and "  ✓" or ""), align = "left", callback = function()
                self.settings.batch_skip_matched = not self.settings.batch_skip_matched; self:saveSettings()
                UIManager:close(dialog); UIManager:nextTick(function() self:showQuickSettings() end)
            end }},
            {{ text = _("Hardcover account…"), align = "left", callback = function() self:editHardcover() end }},
            {{ text = _("Amazon account…"), align = "left", callback = function() self:editAmazon() end }},
            {{ text = _("Amazon marketplace") .. ": " .. self.settings.amazon_marketplace, align = "left", callback = function() self:showMarketplaceSelector() end }},
            {{ text = _("Amazon search index") .. ": " .. self.settings.amazon_search_index, align = "left", callback = function() self:showAmazonIndexSelector() end }},
            {{ text = _("Google Books API key…"), align = "left", callback = function() self:editGoogle() end }},
            {{ text = _("Check for updates…"), align = "left", callback = function() self:checkForUpdates(false) end }},
            {{ text = _("Automatic update checks") .. (self.settings.auto_update_check and "  ✓" or ""), align = "left", callback = function()
                self.settings.auto_update_check = not self.settings.auto_update_check; self:saveSettings()
                UIManager:close(dialog); UIManager:nextTick(function() self:showQuickSettings() end)
            end }},
        },
    }
    UIManager:show(dialog)
end

function MetadataScraper:sourceOptions()
    return {
        { _("All enabled sources"), "all" },
        { "Hardcover", "hardcover" }, { "Amazon", "amazon" },
        { "Google Books", "google" }, { "Open Library", "openlibrary" },
    }
end

function MetadataScraper:showSourceSelector()
    self:showSelectDialog(_("Search source"), self:sourceOptions(), self.settings.source_scope, function(v)
        self.settings.source_scope = v
        self:saveSettings()
    end)
end

function MetadataScraper:showMarketplaceSelector()
    self:showSelectDialog(_("Amazon marketplace"), MARKETPLACES, self.settings.amazon_marketplace, function(v)
        self.settings.amazon_marketplace = v
        self:saveSettings()
    end)
end

function MetadataScraper:showAmazonIndexSelector()
    self:showSelectDialog(_("Amazon search index"), {
        { _("Books"), "Books" }, { _("Kindle Store"), "KindleStore" },
    }, self.settings.amazon_search_index, function(v)
        self.settings.amazon_search_index = v
        self:saveSettings()
    end)
end

function MetadataScraper:editHardcover()
    local dlg
    dlg = MultiInputDialog:new{
        title = _("Hardcover"),
        fields = {{
            description = _("API token from Hardcover account settings. Stored locally in KOReader settings."),
            text = self.settings.hardcover_token or "", hint = _("API token"), text_type = "password",
        }},
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dlg) end },
            { text = _("Save"), callback = function()
                self.settings.hardcover_token = dlg:getFields()[1] or ""
                self.settings.enabled.hardcover = U.nonempty(self.settings.hardcover_token)
                self:saveSettings(); UIManager:close(dlg)
            end },
        }},
    }
    UIManager:show(dlg); dlg:onShowKeyboard()
end

function MetadataScraper:editGoogle()
    local dlg
    dlg = MultiInputDialog:new{
        title = _("Google Books"),
        fields = {{
            description = _("API key required for reliable public Google Books searches. Stored locally in KOReader settings."),
            text = self.settings.google_api_key or "", hint = _("API key"), text_type = "password",
        }},
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dlg) end },
            { text = _("Save"), callback = function()
                self.settings.google_api_key = dlg:getFields()[1] or ""
                self.settings.enabled.google = U.nonempty(self.settings.google_api_key)
                self:saveSettings(); UIManager:close(dlg)
            end },
        }},
    }
    UIManager:show(dlg); dlg:onShowKeyboard()
end

function MetadataScraper:editAmazon()
    local dlg
    dlg = MultiInputDialog:new{
        title = _("Amazon Creators API"),
        fields = {
            { text = self.settings.amazon_client_id or "", hint = _("Credential ID") },
            { text = self.settings.amazon_client_secret or "", hint = _("Credential secret"), text_type = "password" },
            { text = self.settings.amazon_credential_version or "", hint = _("Credential version (3.1 / 3.2 / 3.3)") },
            { text = self.settings.amazon_partner_tag or "", hint = _("Partner Tag") },
        },
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dlg) end },
            { text = _("Save"), callback = function()
                local f = dlg:getFields()
                self.settings.amazon_client_id = f[1] or ""
                self.settings.amazon_client_secret = f[2] or ""
                self.settings.amazon_credential_version = U.trim(f[3] or "")
                self.settings.amazon_partner_tag = f[4] or ""
                self.settings.enabled.amazon = U.nonempty(f[1]) and U.nonempty(f[2]) and U.nonempty(f[4])
                if PROVIDERS.amazon.reset_token_cache then PROVIDERS.amazon.reset_token_cache() end
                self:saveSettings(); UIManager:close(dlg)
            end },
        }},
    }
    UIManager:show(dlg); dlg:onShowKeyboard()
end

function MetadataScraper:testProviders()
    NetworkMgr:runWhenOnline(function()
        local busy = InfoMessage:new{ text = _("Testing metadata providers…") }
        UIManager:show(busy); UIManager:forceRePaint()
        local lines = {}
        for _, id in ipairs(DEFAULT_ORDER) do
            local provider = PROVIDERS[id]
            local good, detail
            if type(provider.test) == "function" then
                local ok, result, message = pcall(provider.test, self.settings)
                if ok then
                    good, detail = result == true, message
                else
                    good, detail = false, tostring(result)
                end
            else
                good, detail = false, _("No diagnostic available")
            end
            Diagnostics.log(provider.label, (good and "diagnostic OK: " or "diagnostic failed: ") .. tostring(detail or ""), self.settings)
            table.insert(lines, string.format("%s %s — %s",
                good and "✓" or "✗", provider.label, tostring(detail or (good and _("OK") or _("Failed")))))
        end
        UIManager:close(busy)
        UIManager:show(InfoMessage:new{ text = table.concat(lines, "\n") })
    end)
end

function MetadataScraper:saveSupportDiagnostics()
    local cache_dir = DataStorage:getDataDir() .. "/cache/metadata_scraper"
    util.makePath(cache_dir)
    local filepath = cache_dir .. "/support_diagnostics.txt"
    local ok, err = Diagnostics.write_bundle(filepath, self.settings, {
        plugin_root = PLUGIN_ROOT,
        target = "KOReader 2026.07+",
    })
    if ok then
        UIManager:show(InfoMessage:new{
            text = _("Sanitized support diagnostics saved to:") .. "\n" .. filepath
                .. "\n\n" .. _("API tokens, keys, Amazon secrets, credential IDs, and Partner Tags are not intentionally included."),
        })
    else
        UIManager:show(InfoMessage:new{ text = _("Could not save support diagnostics.") .. "\n" .. tostring(err) })
    end
end

function MetadataScraper:showSearchForm(file, raw, props)
    local dlg
    local authors = (props.authors or ""):gsub("\n", ", ")
    local isbn10, isbn13 = U.extract_isbns(props.identifiers or raw.identifiers)
    local detected_isbn = isbn13 or isbn10 or ""
    dlg = MultiInputDialog:new{
        title = _("Fetch book metadata"),
        fields = {
            { text = props.title or "", hint = _("Title") },
            { text = authors, hint = _("Author") },
            { text = detected_isbn, hint = _("ISBN-10 or ISBN-13") },
        },
        buttons = {{
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dlg) end },
            { text = _("Search"), callback = function()
                local f = dlg:getFields()
                local q = {
                    title = U.trim(f[1] or ""),
                    author = U.trim(f[2] or ""),
                    isbn = U.clean_isbn(f[3]),
                    language = props.language,
                    series = props.series,
                    media_kind = "ebook",
                }
                if q.title == "" and q.author == "" and not q.isbn then
                    UIManager:show(InfoMessage:new{ text = _("Enter a title, author, or ISBN.") }); return
                end
                UIManager:close(dlg)
                self:searchOnline(file, raw, q)
            end },
        }},
    }
    UIManager:show(dlg); dlg:onShowKeyboard()
end

function MetadataScraper:startForFile(file)
    if not self:isEpub(file) then
        UIManager:show(InfoMessage:new{ text = _("Metadata Scraper currently targets EPUB files.") }); return
    end
    local raw, props = self:getRawProps(file)
    self:showSearchForm(file, raw, props)
end

function MetadataScraper:providerOrder()
    if self.settings.source_scope ~= "all" then return { self.settings.source_scope } end
    return DEFAULT_ORDER
end

function MetadataScraper:sourcePriority()
    local p = {}
    for i, id in ipairs(self:providerOrder()) do p[id] = i end
    return p
end

function MetadataScraper:searchProviders(query)
    local results, errors, counts = {}, {}, {}
    for _, id in ipairs(self:providerOrder()) do
        local enabled = self.settings.enabled[id]
        if self.settings.source_scope ~= "all" then enabled = true end
        if enabled and PROVIDERS[id] then
            local ok, list, err = pcall(PROVIDERS[id].search, query, self.settings)
            if ok and type(list) == "table" then
                -- If a strict title+author query returns nothing, retry title-only once.
                if #list == 0 and not err and not query.isbn and U.nonempty(query.title) and U.nonempty(query.author) then
                    local broader = U.copy(query)
                    broader.author = ""
                    local retry_ok, retry_list, retry_err = pcall(PROVIDERS[id].search, broader, self.settings)
                    if retry_ok and type(retry_list) == "table" then
                        list, err = retry_list, retry_err
                    elseif not retry_ok then
                        err = tostring(retry_list)
                    end
                end
                counts[id] = #list
                for _, r in ipairs(list) do table.insert(results, r) end
                if err then errors[id] = err end
            else
                counts[id] = 0
                errors[id] = ok and (err or "Unknown error") or tostring(list)
            end
            if errors[id] then Diagnostics.log(PROVIDERS[id].label, errors[id], self.settings) end
        end
    end
    Matcher.rank(query, results, self:sourcePriority())
    return results, errors, counts
end

function MetadataScraper:searchOnline(file, raw, query)
    NetworkMgr:runWhenOnline(function()
        local busy = InfoMessage:new{ text = _("Searching book sources…") }
        UIManager:show(busy); UIManager:forceRePaint()
        local results, errors, counts = self:searchProviders(query)
        UIManager:close(busy)
        if #results == 0 then
            local lines = { _("No matches found.") }
            for _, id in ipairs(self:providerOrder()) do
                if counts[id] ~= nil or errors[id] then
                    local label = PROVIDERS[id] and PROVIDERS[id].label or id
                    if errors[id] then
                        table.insert(lines, label .. ": " .. tostring(errors[id]))
                    else
                        table.insert(lines, label .. ": " .. tostring(counts[id] or 0) .. " results")
                    end
                end
            end
            UIManager:show(InfoMessage:new{ text = table.concat(lines, "\n") })
            return
        end
        self:showResults(file, raw, query, results)
    end)
end

function MetadataScraper:showResults(file, raw, query, results)
    local dialog
    local rows = {}
    local max = math.min(6, #results)
    for i = 1, max do
        local r = results[i]
        local author = U.join(r.authors, ", ", 2)
        local secondary = r.source_label or r.source
        if r.also_sources and #r.also_sources > 0 then
            secondary = secondary .. " +" .. tostring(#r.also_sources)
        end
        if r.published_date then secondary = secondary .. " · " .. tostring(r.published_date) end
        if r.media_kind then secondary = secondary .. " · " .. tostring(r.media_kind) end
        local text = tostring(r.title or _("Untitled"))
        if author ~= "" then text = text .. "\n" .. author end
        text = text .. "\n" .. tostring(r.score or 0) .. "% " .. confidence_label(r.confidence) .. " · " .. secondary
        table.insert(rows, {{
            text = text, align = "left",
            callback = function() UIManager:close(dialog); self:showPreview(file, raw, query, r) end,
        }})
    end
    table.insert(rows, {{
        text = _("Refine search…"), align = "left",
        callback = function()
            UIManager:close(dialog)
            local _, effective = self:getRawProps(file)
            self:showSearchForm(file, raw, effective)
        end,
    }})
    dialog = ButtonDialog:new{ title = _("Metadata matches"), title_align = "center", buttons = rows }
    UIManager:show(dialog)
end

function MetadataScraper:pruneUndoRecords()
    local records = self.settings.undo_records or {}
    local ordered = {}
    for file, record in pairs(records) do
        table.insert(ordered, { file = file, created_at = tonumber(record.created_at) or 0 })
    end
    table.sort(ordered, function(a, b) return a.created_at < b.created_at end)
    while #ordered > 20 do
        local oldest = table.remove(ordered, 1)
        local record = records[oldest.file]
        if record then Writer.discard_snapshot(record.snapshot or record) end
        records[oldest.file] = nil
    end
end

function MetadataScraper:storeUndoRecord(file, snapshot, previous_link)
    self.settings.undo_records = self.settings.undo_records or {}
    local old = self.settings.undo_records[file]
    if old then Writer.discard_snapshot(old.snapshot or old) end
    self.settings.undo_records[file] = {
        snapshot = snapshot,
        previous_book_link = previous_link,
        had_previous_link = previous_link ~= nil,
        created_at = os.time(),
    }
    self:pruneUndoRecords()
end

function MetadataScraper:recordLink(file, r, query, changes, cover_ok)
    local written_fields = {}
    for _, change in ipairs(changes or {}) do table.insert(written_fields, change.key) end
    self.settings.book_links[file] = {
        provenance_version = 1,
        source = r.source,
        source_label = r.source_label,
        id = r.id,
        isbn10 = r.isbn10,
        isbn13 = r.isbn13,
        canonical_isbn = U.canonical_isbn(r.isbn13) or U.canonical_isbn(r.isbn10),
        title = r.title,
        authors = U.copy(r.authors),
        authors_text = r.authors_text or U.join(r.authors, ", "),
        series = r.series,
        series_index = r.series_index,
        language = r.language,
        published_date = r.published_date,
        publisher = r.publisher,
        format = r.format,
        binding = r.binding,
        edition = r.edition,
        media_kind = r.media_kind,
        score = r.score,
        confidence = r.confidence,
        match_reasons = U.copy(r.match_reasons),
        also_sources = U.copy(r.also_sources),
        query = {
            title = query and query.title or nil,
            author = query and query.author or nil,
            isbn = query and query.isbn or nil,
            language = query and query.language or nil,
            series = query and query.series or nil,
            media_kind = query and query.media_kind or nil,
        },
        written_fields = written_fields,
        cover_applied = cover_ok == true,
        cover_source = cover_ok and r.source or nil,
        plugin_version = Version.VERSION,
        updated_at = os.date("%Y-%m-%d %H:%M:%S"),
    }
    self:saveSettings()
end

function MetadataScraper:showLastMatchDetails(file)
    local link = self.settings.book_links[file]
    if type(link) ~= "table" then
        UIManager:show(InfoMessage:new{ text = _("No Metadata Scraper match is recorded for this book.") })
        return
    end
    local lines = {
        link.title or _("Unknown title"),
        _("Source") .. ": " .. tostring(link.source_label or link.source or _("unknown")),
    }
    if link.id then table.insert(lines, _("Provider ID") .. ": " .. tostring(link.id)) end
    if link.score then
        local score_text = tostring(link.score) .. "%"
        if link.confidence then score_text = score_text .. " · " .. confidence_label(link.confidence) end
        table.insert(lines, _("Match score") .. ": " .. score_text)
    end
    if link.canonical_isbn then table.insert(lines, "ISBN: " .. tostring(link.canonical_isbn)) end
    if link.series then
        table.insert(lines, _("Series") .. ": " .. tostring(link.series) .. (link.series_index and (" #" .. tostring(link.series_index)) or ""))
    end
    if link.format or link.binding or link.media_kind then
        table.insert(lines, _("Format") .. ": " .. tostring(link.format or link.binding or link.media_kind))
    end
    if link.edition then table.insert(lines, _("Edition") .. ": " .. tostring(link.edition)) end
    if link.written_fields and #link.written_fields > 0 then
        table.insert(lines, _("Fields written") .. ": " .. U.join(link.written_fields, ", "))
    end
    if link.match_reasons and #link.match_reasons > 0 then
        table.insert(lines, _("Match reasons") .. ": " .. U.join(link.match_reasons, ", "))
    end
    if link.updated_at then table.insert(lines, _("Matched") .. ": " .. tostring(link.updated_at)) end
    table.insert(lines, _("Plugin") .. ": " .. tostring(link.plugin_version or _("unknown")))
    UIManager:show(InfoMessage:new{ text = table.concat(lines, "\n") })
end

function MetadataScraper:confirmUndo(file)
    local record = self.settings.undo_records and self.settings.undo_records[file]
    if not record then
        UIManager:show(InfoMessage:new{ text = _("No undo snapshot is available for this book.") })
        return
    end
    local box
    box = ConfirmBox:new{
        text = _("Restore the custom metadata and custom cover that existed before the last Metadata Scraper update?"),
        ok_text = _("Undo"),
        ok_callback = function()
            UIManager:close(box)
            local snapshot = record.snapshot or record
            local ok, err = Writer.restore_snapshot(file, snapshot)
            if not ok then
                Diagnostics.log("Metadata undo", err or "Undo failed", self.settings)
                UIManager:show(InfoMessage:new{ text = _("Could not undo the metadata update.") .. "\n" .. tostring(err) })
                return
            end
            Writer.discard_snapshot(snapshot)
            self.settings.undo_records[file] = nil
            if record.had_previous_link then
                self.settings.book_links[file] = record.previous_book_link
            else
                self.settings.book_links[file] = nil
            end
            self:saveSettings()
            UIManager:show(InfoMessage:new{ text = _("Previous metadata and cover restored.") })
        end,
    }
    UIManager:show(box)
end

function MetadataScraper:applyResult(file, raw, result, quiet, query, options)
    options = type(options) == "table" and options or {}
    local apply_fields = type(options.fields) == "table" and options.fields or self.settings.fields
    local apply_cover = options.download_cover
    if apply_cover == nil then apply_cover = self.settings.download_cover end
    local replace_existing = options.replace_existing
    if replace_existing == nil then replace_existing = self.settings.replace_existing end

    local changes, preview_err = Writer.preview(file, raw, result, apply_fields, replace_existing)
    if not changes then
        Diagnostics.log("Metadata preview", preview_err or "Could not calculate proposed changes", self.settings)
        if not quiet then UIManager:show(InfoMessage:new{ text = _("Could not calculate the metadata changes safely.") .. "\n" .. tostring(preview_err) }) end
        return false
    end

    local wants_cover = apply_cover and result.cover_url ~= nil
    if #changes == 0 and not wants_cover then
        if not quiet then UIManager:show(InfoMessage:new{ text = _("No selected metadata fields need changing.") }) end
        return true
    end

    local undo_dir = DataStorage:getDataDir() .. "/cache/metadata_scraper/undo"
    util.makePath(undo_dir)
    local snapshot, snapshot_err = Writer.snapshot(file, undo_dir)
    if not snapshot then
        Diagnostics.log("Metadata undo", snapshot_err or "Could not create undo snapshot", self.settings)
        if not quiet then UIManager:show(InfoMessage:new{ text = _("Metadata was not changed because an undo snapshot could not be created.") .. "\n" .. tostring(snapshot_err) }) end
        return false
    end

    local previous_link = self.settings.book_links[file]
    local ok, write_err = true, nil
    if #changes > 0 then
        ok, write_err = Writer.write(file, raw, result, apply_fields, replace_existing)
    end

    if not ok then
        -- Writer.write has its own lightweight transaction rollback, but keep the
        -- user-facing snapshot until we independently confirm the exact prior state.
        local restored, restore_err = Writer.restore_snapshot(file, snapshot)
        local recovery_note = ""
        if restored then
            Writer.discard_snapshot(snapshot)
        else
            self:storeUndoRecord(file, snapshot, previous_link)
            recovery_note = "\n" .. _("Automatic rollback could not be confirmed. The recovery snapshot was retained under Undo last metadata update.")
            Diagnostics.log("Metadata rollback", restore_err or "Could not restore user-facing snapshot", self.settings)
        end
        Diagnostics.log("Metadata writer", write_err or "Could not write KOReader custom metadata", self.settings)
        if not quiet then
            UIManager:show(InfoMessage:new{
                text = _("Could not write KOReader custom metadata.")
                    .. (write_err and ("\n" .. tostring(write_err)) or "") .. recovery_note,
            })
        end
        return false
    end

    local cover_ok, cover_err
    if wants_cover then
        local cache_dir = DataStorage:getDataDir() .. "/cache/metadata_scraper"
        util.makePath(cache_dir)
        local ext = U.ext_from_url(result.cover_url)
        local tmp = cache_dir .. "/" .. U.safe_filename(tostring(result.source) .. "_" .. tostring(result.id or os.time())) .. "." .. ext
        local downloaded, download_info = HTTP.download(result.cover_url, tmp)
        if downloaded then
            cover_ok, cover_err = Writer.write_cover(file, tmp)
        else
            cover_ok, cover_err = nil, download_info
        end
        os.remove(tmp)
    end

    local text_applied = #changes > 0
    local applied_any = text_applied or cover_ok == true
    local recovery_snapshot_retained = false

    -- A cover-only failure should leave the book exactly as it was. The cover
    -- writer normally restores the prior bytes itself; verify that state from the
    -- user-facing snapshot before discarding the last recovery copy.
    if wants_cover and not cover_ok and not text_applied then
        local restored, restore_err = Writer.restore_snapshot(file, snapshot)
        if restored then
            Writer.discard_snapshot(snapshot)
            snapshot = nil
        else
            self:storeUndoRecord(file, snapshot, previous_link)
            recovery_snapshot_retained = true
            snapshot = nil
            cover_err = tostring(cover_err or _("Could not save custom cover"))
                .. "; " .. _("automatic rollback could not be confirmed; recovery snapshot retained")
            Diagnostics.log("Cover rollback", restore_err or "Could not restore user-facing snapshot", self.settings)
        end
    end

    if applied_any then
        self:storeUndoRecord(file, snapshot, previous_link)
        self:recordLink(file, result, query, changes, cover_ok)
    elseif snapshot then
        Writer.discard_snapshot(snapshot)
    end

    if wants_cover and not cover_ok then
        Diagnostics.log("Cover writer", cover_err or "Could not save custom cover", self.settings)
        if recovery_snapshot_retained then
            Diagnostics.log("Cover recovery", "Recovery snapshot retained for manual Undo", self.settings)
        end
    end

    if not quiet then
        if wants_cover and not cover_ok and text_applied then
            UIManager:show(InfoMessage:new{ text = _("Metadata saved, but the cover could not be saved.") .. (cover_err and ("\n" .. tostring(cover_err)) or "") })
        elseif wants_cover and not cover_ok then
            UIManager:show(InfoMessage:new{ text = _("The cover could not be saved.") .. (cover_err and ("\n" .. tostring(cover_err)) or "") })
        elseif not text_applied and cover_ok then
            UIManager:show(InfoMessage:new{ text = _("Cover saved. You can undo this change from Metadata Scraper.") })
        else
            UIManager:show(InfoMessage:new{ text = _("Metadata saved. You can undo this change from Metadata Scraper.") })
        end
    end
    return applied_any
end

function MetadataScraper:showApplyFieldSelector(file, raw, query, r)
    local selected = U.copy(self.settings.fields)
    local include_cover = self.settings.download_cover
    local dialog

    local function render()
        local rows = {}
        for _, def in ipairs(FIELD_DEFS) do
            local key, label = def[1], _(def[2])
            table.insert(rows, {{
                text = label .. (selected[key] and "  ✓" or ""), align = "left",
                callback = function()
                    selected[key] = not selected[key]
                    UIManager:close(dialog)
                    UIManager:nextTick(render)
                end,
            }})
        end
        table.insert(rows, {{
            text = _("Cover") .. (include_cover and "  ✓" or ""), align = "left",
            callback = function()
                include_cover = not include_cover
                UIManager:close(dialog)
                UIManager:nextTick(render)
            end,
        }})
        table.insert(rows, {
            { text = _("Back"), callback = function() UIManager:close(dialog); self:showPreview(file, raw, query, r) end },
            { text = _("Apply selected"), callback = function()
                UIManager:close(dialog)
                NetworkMgr:runWhenOnline(function()
                    self:applyResult(file, raw, r, false, query, {
                        fields = selected,
                        download_cover = include_cover,
                    })
                end)
            end },
        })
        dialog = ButtonDialog:new{
            title = _("Apply fields for this book"),
            title_align = "center",
            buttons = rows,
        }
        UIManager:show(dialog)
    end

    render()
end

function MetadataScraper:showPreview(file, raw, query, r)
    local dialog
    local rows = {}
    local function info(label, value)
        if value and tostring(value) ~= "" then
            table.insert(rows, {{ text = label .. ": " .. tostring(value), align = "left", enabled = false }})
        end
    end
    info(_("Author"), U.join(r.authors, ", "))
    if r.series then info(_("Series"), r.series .. (r.series_index and (" #" .. tostring(r.series_index)) or "")) end
    info(_("Published"), r.published_date)
    info(_("Language"), r.language)
    info("ISBN-13", r.isbn13); info("ISBN-10", r.isbn10)
    info(_("Format"), r.format or r.binding or r.media_kind)
    info(_("Edition"), r.edition)
    info(_("Source"), (r.source_label or r.source) .. " · " .. tostring(r.score or 0) .. "%")
    info(_("Confidence"), confidence_label(r.confidence))
    if r.also_sources and #r.also_sources > 0 then info(_("Also found on"), U.join(r.also_sources, ", ")) end
    if r.match_reasons and #r.match_reasons > 0 then info(_("Match"), U.join(r.match_reasons, ", ")) end
    info(_("Cover"), r.cover_url and _("available") or _("not available"))

    local changes, change_err = Writer.preview(file, raw, r, self.settings.fields, self.settings.replace_existing)
    if changes then
        if #changes == 0 then
            info(_("Text changes"), _("none with current field/write-mode settings"))
        else
            table.insert(rows, {{ text = _("Current → Proposed"), align = "left", enabled = false }})
            for _, change in ipairs(changes) do
                local label = _(PREVIEW_LABELS[change.key] or change.key)
                local text
                if change.key == "description" then
                    text = label .. ": " .. (change.action == "add" and _("add description") or _("replace description"))
                else
                    text = label .. ": " .. display_value(change.current) .. " → " .. display_value(change.proposed)
                end
                table.insert(rows, {{ text = text, align = "left", enabled = false }})
            end
        end
    else
        info(_("Change preview"), _("unavailable") .. ": " .. tostring(change_err))
    end

    table.insert(rows, {{
        text = _("Choose fields for this book…"), align = "left",
        callback = function() UIManager:close(dialog); self:showApplyFieldSelector(file, raw, query, r) end,
    }})
    table.insert(rows, {
        { text = _("Back"), callback = function() UIManager:close(dialog); self:searchOnline(file, raw, query) end },
        { text = _("Apply"), callback = function()
            UIManager:close(dialog)
            NetworkMgr:runWhenOnline(function() self:applyResult(file, raw, r, false, query) end)
        end },
    })
    dialog = ButtonDialog:new{ title = r.title or _("Book metadata"), title_align = "center", buttons = rows }
    UIManager:show(dialog)
end

function MetadataScraper:listEpubs(path)
    local files = {}
    local ok, iter, obj = pcall(lfs.dir, path)
    if not ok then return files end
    for name in iter, obj do
        if name ~= "." and name ~= ".." then
            local file = path .. "/" .. name
            if lfs.attributes(file, "mode") == "file" and self:isEpub(file) then table.insert(files, file) end
        end
    end
    table.sort(files)
    return files
end

function MetadataScraper:confirmBatch(path)
    local files = self:listEpubs(path)
    if #files == 0 then UIManager:show(InfoMessage:new{ text = _("No EPUB files found in this folder.") }); return end
    local count = math.min(#files, tonumber(self.settings.batch_limit) or 20)
    local skip_note = self.settings.batch_skip_matched
        and _("\n\nBooks already matched by Metadata Scraper will be skipped before provider searches.") or ""
    local box
    box = ConfirmBox:new{
        text = string.format(_("Discover metadata matches for %d EPUBs?\n\nThis first phase makes no metadata or cover changes. Matches at or above %d%% will be proposed for a second confirmation. This scans this folder only, not subfolders."), count, tonumber(self.settings.batch_threshold) or 90) .. skip_note,
        ok_text = _("Discover"),
        ok_callback = function() UIManager:close(box); self:runBatch(files, count) end,
    }
    UIManager:show(box)
end

local function all_attempted_providers_failed(order, errors, counts)
    local attempted, failed = 0, 0
    for _, id in ipairs(order or {}) do
        if counts[id] ~= nil or errors[id] ~= nil then
            attempted = attempted + 1
            if errors[id] and (tonumber(counts[id]) or 0) == 0 then failed = failed + 1 end
        end
    end
    return attempted > 0 and failed == attempted
end

function MetadataScraper:showBatchPlan(plan)
    if #plan.apply == 0 then
        UIManager:show(InfoMessage:new{
            text = string.format(_("Batch discovery complete.\n\nReady to apply: 0\nLow/no match: %d\nAlready matched: %d\nSearch failures: %d\n\nNo metadata was changed."),
                plan.skipped, plan.already_matched, plan.failed),
        })
        return
    end

    local box
    box = ConfirmBox:new{
        text = string.format(_("Batch discovery complete.\n\nReady to apply: %d\nLow/no match: %d\nAlready matched: %d\nSearch failures: %d\n\nApply the %d proposed high-confidence matches now?"),
            #plan.apply, plan.skipped, plan.already_matched, plan.failed, #plan.apply),
        ok_text = _("Apply"),
        ok_callback = function()
            UIManager:close(box)
            self:applyBatchPlan(plan)
        end,
    }
    UIManager:show(box)
end

function MetadataScraper:runBatch(files, count)
    NetworkMgr:runWhenOnline(function()
        local threshold = tonumber(self.settings.batch_threshold) or 90
        local batch_options = {
            fields = U.copy(self.settings.fields),
            download_cover = self.settings.download_cover,
            replace_existing = self.settings.replace_existing,
        }
        local plan = {
            apply = {},
            skipped = 0,
            already_matched = 0,
            failed = 0,
            total = count,
            threshold = threshold,
            options = batch_options,
        }

        for i = 1, count do
            local file = files[i]
            if self.settings.batch_skip_matched and self.settings.book_links[file] then
                plan.already_matched = plan.already_matched + 1
            else
                local raw, props = self:getRawProps(file)
                local isbn10, isbn13 = U.extract_isbns(props.identifiers or raw.identifiers)
                local q = {
                    title = props.title or file:match("([^/]+)%.epub$") or "",
                    author = (props.authors or ""):gsub("\n", ", "),
                    isbn = isbn13 or isbn10,
                    language = props.language,
                    series = props.series,
                    media_kind = "ebook",
                }
                local busy = InfoMessage:new{ text = string.format(_("Discovering %d/%d\n%s"), i, count, q.title) }
                UIManager:show(busy); UIManager:forceRePaint()
                local results, errors, counts = self:searchProviders(q)
                UIManager:close(busy)
                local best = results and results[1]
                if best and (best.score or 0) >= threshold then
                    table.insert(plan.apply, {
                        file = file,
                        raw = raw,
                        query = q,
                        result = best,
                        options = batch_options,
                    })
                elseif all_attempted_providers_failed(self:providerOrder(), errors or {}, counts or {}) then
                    plan.failed = plan.failed + 1
                else
                    plan.skipped = plan.skipped + 1
                end
            end
        end

        self:showBatchPlan(plan)
    end)
end

function MetadataScraper:applyBatchPlan(plan)
    NetworkMgr:runWhenOnline(function()
        local applied, failed = 0, 0
        for i, entry in ipairs(plan.apply or {}) do
            local title = (entry.result and entry.result.title) or (entry.query and entry.query.title) or entry.file
            local busy = InfoMessage:new{ text = string.format(_("Applying %d/%d\n%s"), i, #plan.apply, tostring(title or "")) }
            UIManager:show(busy); UIManager:forceRePaint()
            local ok = self:applyResult(entry.file, entry.raw, entry.result, true, entry.query, entry.options or plan.options)
            UIManager:close(busy)
            if ok then applied = applied + 1 else failed = failed + 1 end
        end
        UIManager:show(InfoMessage:new{
            text = string.format(_("Batch complete.\nApplied: %d\nNot applied: %d\nAlready matched: %d\nSearch failures: %d\nApply failures: %d"),
                applied, plan.skipped or 0, plan.already_matched or 0, plan.failed or 0, failed),
        })
    end)
end

function MetadataScraper:addToMainMenu(menu_items)
    local fields = self.settings.fields
    local enabled = self.settings.enabled
    menu_items.metadata_scraper = {
        text = _("Metadata Scraper"),
        sub_item_table = {
            {
                text = _("Fetch metadata for current book"),
                enabled_func = function() local f = self:getCurrentFile(); return f and self:isEpub(f) end,
                keep_menu_open = true,
                callback = function() self:startForFile(self:getCurrentFile()) end,
            },
            {
                text = _("Undo last metadata update"),
                enabled_func = function()
                    local f = self:getCurrentFile()
                    return f and self.settings.undo_records and self.settings.undo_records[f] ~= nil
                end,
                keep_menu_open = true,
                callback = function() self:confirmUndo(self:getCurrentFile()) end,
            },
            {
                text = _("Last match details"),
                enabled_func = function()
                    local f = self:getCurrentFile()
                    return f and self.settings.book_links and self.settings.book_links[f] ~= nil
                end,
                keep_menu_open = true,
                callback = function() self:showLastMatchDetails(self:getCurrentFile()) end,
            },
            { text = _("Choose EPUB…"), keep_menu_open = true, callback = function() self:chooseEpub() end },
            { text = _("Batch folder…"), keep_menu_open = true, callback = function() self:chooseBatchFolder() end, separator = true },
            {
                text_func = function() return _("Batch threshold") .. ": " .. tostring(tonumber(self.settings.batch_threshold) or 90) .. "%" end,
                keep_menu_open = true,
                callback = function() self:showBatchThresholdSelector() end,
            },
            {
                text = _("Skip already matched in batch"),
                checked_func = function() return self.settings.batch_skip_matched end,
                callback = function() self.settings.batch_skip_matched = not self.settings.batch_skip_matched; self:saveSettings() end,
                separator = true,
            },
            {
                text_func = function()
                    return _("Search source") .. ": " .. self:getSourceLabel()
                end,
                keep_menu_open = true,
                callback = function() self:showSourceSelector() end,
            },
            {
                text = _("Providers"),
                sub_item_table = {
                    { text = "Hardcover", checked_func = function() return enabled.hardcover end, callback = function() enabled.hardcover = not enabled.hardcover; self:saveSettings() end },
                    { text = "Amazon", checked_func = function() return enabled.amazon end, callback = function() enabled.amazon = not enabled.amazon; self:saveSettings() end },
                    { text = "Google Books", checked_func = function() return enabled.google end, callback = function() enabled.google = not enabled.google; self:saveSettings() end },
                    { text = "Open Library", checked_func = function() return enabled.openlibrary end, callback = function() enabled.openlibrary = not enabled.openlibrary; self:saveSettings() end },
                },
            },
            {
                text = _("Provider accounts"),
                sub_item_table = {
                    { text = _("Test provider connections…"), keep_menu_open = true, callback = function() self:testProviders() end },
                    { text = _("Save support diagnostics…"), keep_menu_open = true, callback = function() self:saveSupportDiagnostics() end },
                    { text = _("Hardcover API token…"), keep_menu_open = true, callback = function() self:editHardcover() end },
                    { text = _("Amazon Creators API…"), keep_menu_open = true, callback = function() self:editAmazon() end },
                    { text_func = function() return _("Amazon marketplace") .. ": " .. self.settings.amazon_marketplace end, keep_menu_open = true, callback = function() self:showMarketplaceSelector() end },
                    { text_func = function() return _("Amazon search index") .. ": " .. self.settings.amazon_search_index end, keep_menu_open = true, callback = function() self:showAmazonIndexSelector() end },
                    { text = _("Google Books API key…"), keep_menu_open = true, callback = function() self:editGoogle() end },
                },
            },
            {
                text = _("Metadata fields"),
                sub_item_table = {
                    { text = _("Title"), checked_func = function() return fields.title end, callback = function() fields.title = not fields.title; self:saveSettings() end },
                    { text = _("Authors"), checked_func = function() return fields.authors end, callback = function() fields.authors = not fields.authors; self:saveSettings() end },
                    { text = _("Series"), checked_func = function() return fields.series end, callback = function() fields.series = not fields.series; self:saveSettings() end },
                    { text = _("Series index"), checked_func = function() return fields.series_index end, callback = function() fields.series_index = not fields.series_index; self:saveSettings() end },
                    { text = _("Language"), checked_func = function() return fields.language end, callback = function() fields.language = not fields.language; self:saveSettings() end },
                    { text = _("Keywords / genres"), checked_func = function() return fields.keywords end, callback = function() fields.keywords = not fields.keywords; self:saveSettings() end },
                    { text = _("Description"), checked_func = function() return fields.description end, callback = function() fields.description = not fields.description; self:saveSettings() end },
                    { text = _("Cover"), checked_func = function() return self.settings.download_cover end, callback = function() self.settings.download_cover = not self.settings.download_cover; self:saveSettings() end },
                },
            },
            {
                text = _("Replace existing metadata"),
                checked_func = function() return self.settings.replace_existing end,
                callback = function() self.settings.replace_existing = not self.settings.replace_existing; self:saveSettings() end,
                separator = true,
            },
            {
                text = _("Check for updates…"),
                keep_menu_open = true,
                callback = function() self:checkForUpdates(false) end,
            },
            {
                text = _("Automatic update checks"),
                checked_func = function() return self.settings.auto_update_check end,
                callback = function() self.settings.auto_update_check = not self.settings.auto_update_check; self:saveSettings() end,
                separator = true,
            },
            {
                text = _("About"),
                keep_menu_open = true,
                callback = function()
                    UIManager:show(InfoMessage:new{ text = string.format(_([[Metadata Scraper %s

Target: KOReader 2026.07+

Writes KOReader custom metadata and custom covers in sidecars. EPUB files are never modified.

Hardcover and Amazon require API credentials. Amazon integration uses the supported Creators API, not HTML scraping.]]), Version.VERSION) })
                end,
            },
        },
    }
end

return MetadataScraper
