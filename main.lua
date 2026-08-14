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

local PROVIDERS = {
    hardcover = require("providers/hardcover"),
    amazon = require("providers/amazon"),
    google = require("providers/googlebooks"),
    openlibrary = require("providers/openlibrary"),
}
local DEFAULT_ORDER = { "hardcover", "amazon", "google", "openlibrary" }

local DEFAULTS = {
    enabled = { hardcover = false, amazon = false, google = true, openlibrary = true },
    source_scope = "all",
    hardcover_token = "",
    google_api_key = "",
    amazon_client_id = "",
    amazon_client_secret = "",
    amazon_partner_tag = "",
    amazon_marketplace = "www.amazon.com.au",
    amazon_search_index = "Books",
    replace_existing = true,
    download_cover = true,
    batch_threshold = 90,
    batch_limit = 20,
    fields = {
        title = true, authors = true, series = true, series_index = true,
        language = true, keywords = true, description = true,
    },
    book_links = {},
}

local MARKETPLACES = {
    { "Australia", "www.amazon.com.au" }, { "United States", "www.amazon.com" },
    { "United Kingdom", "www.amazon.co.uk" }, { "Canada", "www.amazon.ca" },
    { "Germany", "www.amazon.de" }, { "France", "www.amazon.fr" },
    { "Italy", "www.amazon.it" }, { "Spain", "www.amazon.es" },
    { "India", "www.amazon.in" }, { "Japan", "www.amazon.co.jp" },
    { "Singapore", "www.amazon.sg" }, { "Netherlands", "www.amazon.nl" },
}

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
    return d
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
    end
    self.ui.menu:registerToMainMenu(self)
    self:installZenContextHook()
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
    local doc = DocumentRegistry:hasProvider(file) and DocumentRegistry:openDocument(file)
    if not doc then return {}, {} end
    local loaded = true
    if doc.loadDocument then loaded = doc:loadDocument(false) end
    local raw = loaded and (doc:getProps() or {}) or {}
    doc:close()
    local effective = BookInfo.extendProps(raw, file)
    return raw, effective
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
            text = label .. (value == current and "  âœ“" or ""),
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
    dialog = ButtonDialog:new{
        title = _("Metadata"), title_align = "center",
        buttons = {
            {{ text = _("Fetch metadata"), align = "left", callback = function() UIManager:close(dialog); self:startForFile(file) end }},
            {{ text = _("Search source") .. ": " .. self:getSourceLabel(), align = "left", callback = function() UIManager:close(dialog); self:showSourceSelector() end }},
            {{ text = _("Settings"), align = "left", callback = function() UIManager:close(dialog); self:showQuickSettings() end }},
        },
    }
    UIManager:show(dialog)
end

function MetadataScraper:showFolderActions(path)
    local dialog
    dialog = ButtonDialog:new{
        title = _("Metadata"), title_align = "center",
        buttons = {
            {{ text = _("Fetch metadata in folder"), align = "left", callback = function() UIManager:close(dialog); self:confirmBatch(path) end }},
            {{ text = _("Search source") .. ": " .. self:getSourceLabel(), align = "left", callback = function() UIManager:close(dialog); self:showSourceSelector() end }},
            {{ text = _("Settings"), align = "left", callback = function() UIManager:close(dialog); self:showQuickSettings() end }},
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
    for _, id in ipairs(DEFAUL_ORDER) do
        local provider = PROVIDERS[id]
        table.insert(rows, {{
            text = provider.label .. (self.settings.enabled[id] and "  âœ“" or ""), align = "left",
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
    local a = self.settings.fields
    local opts = { { "Title", "title" }, { "Authors", "authors" }, { "Series", "series" }, { "Series index", "series_index" }, { "Language", "language" }, { "Keywords / genres", "keywords" }, { "Description", "description" } }
    local rows = {}
    for _, opt in ipairs(opts) do
        table.insert(rows, {{
            text = _(opt[1]) .. (a[opt[2]] and "  âœ“" or ""), align = "left",
            callback = function() aopt[2]] = not a[opt[2]]; self:saveSettings(); UIManager:close(dialog); UIManager:nextTick(function() self:showFieldDialog() end) end,
        }})
    end
    table.insert(rows, {{ text = _("Cover") .. (self.settings.download_cover and "  âœ“" or ""), align = "left", callback = function() self.settings.download_cover = not self.settings.download_cover; self:saveSettings(); UIManager:close(dialog); UIManager:nextTick(function() self:showFieldDialog() end) end }})
    dialog = ButtonDialog:new{ title = _("Metadata fields"), title_align = "center", buttons = rows }
    UIManager:show(dialog)
end

function MetadataScraper:showQuickSettings()
    local dialog
    dialog = ButtonDialog:new{
        title = _("Metadata settings"), title_align = "center",
        buttons = {
            {{ text = _("Providers"), align = "left", callback = function() UIManager:close(dialog); self:showProviderDialog() end }},
            {{ text = _("Search source") .. ": " .. self:getSourceLabel(), align = "left", callback = function() UIManager:close(dialog); self:showSourceSelector() end }},
            {{ text = _("Metadata fields"), align = "left", callback = function() UIManager:close(dialog); self:showFieldDialog() end }},
            {{ text = _("Provider accounts"), align = "left", callback = function() UIManager:close(dialog); self:showAccountsDialog() end }},
            {{ text = _("Replace existing metadata") .. (self.settings.replace_existing and "  âœ“" or ""), align = "left", callback = function() self.settings.replace_existing = not self.settings.replace_existing; self:saveSettings(); UIManager:close(dialog); UIManager:nextTick(function() self:showQuickSettings() end) end }},
        },
    }
    UIManager:show(dialog)
end

function MetadataScraper:showAccountsDialog()
    local dialog
    dialog = ButtonDialog:new{
        title = _("Provider accounts"), title_align = "center",
        buttons = {
            {{ text = _("Hardcover API tokenâ€¦"), align = "left", callback = function() UIManager:close(dialog); self:editHardcover() end }},
            {{ text = _("Amazon Creators APIâ€¦"), align = "left", callback = function() UIManager:close(dialog); self:editAmazon() end }},
            {{ text = _("Amazon marketplace") .. ": " .. self.settings.amazon_marketplace, align = "left", callback = function() UIManager:close(dialog); self:showMarketplaceSelector() end }},
            {{ text = _("Amazon search index") .. ": " .. self.settings.amazon_search_index, align = "left", callback = function() UIManager:close(dialog); self:showAmazonIndexSelector() end }},
            {{ text = _("Google Books API keyâ€¦"), align = "left", callback = function() UIManager:close(dialog); self:editGoogle() end }},
        },
    }
    UIManager:show(dialog)
end

function MetadataScraper:sourceOptions()
    local opts = { { _("All enabled sources"), "all" } }
    for _, id in ipairs(DEFAULT_ORDER) do
        if self.settings.enabled[id] then table.insert(opts, { PROVIDERS[id].label, id }) end
    end
    return opts
end

function MetadataScraper:showSourceSelector()
    self:showSelectDialog(_("Search source"), self:sourceOptions(), self.settings.source_scope, function(v)
        self.settings.source_scope = v; self:saveSettings()
    end)
end

function MetadataScraper:showMarketplaceSelector()
    self:showSelectDialog(_("Amazon marketplace"), MARKETPLACES, self.settings.amazon_marketplace, function(v)
        self.settings.amazon_marketplace = v; self:saveSettings()
    end)
end

function MetadataScraper:showAmazonIndexSelector()
    self:showSelectDialog(_("Amazon search index"), { { "Books", "Books" }, { "Kindle Store", "KindleStore" } }, self.settings.amazon_search_index, function(v)
        self.settings.amazon_search_index = v; self:saveSettings()
    end)
end

function MetadataScraper:editHardcover()
    local dialog
    dialog = MultiInputDialog:new{
        title = _("Hardcover"),
        fields = { { description = _("API token"), text = self.settings.hardcover_token or "", text_type = "password" } },
        buttons = { {
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("Save"), callback = function() local f = dialog:getFields(); self.settings.hardcover_token = f[1] or ""; self:saveSettings(); UIManager:close(dialog) end },
        } },
    }
    UIManager:show(dialog); dialog:onShowKeyboard()
end

function MetadataScraper:editGoogle()
    local dialog
    dialog = MultiInputDialog:new{
        title = _("Google Books"),
        fields = { { description = _("API key (optional)"), text = self.settings.google_api_key or "", text_type = "password" } },
        buttons = { {
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("Save"), callback = function() local f = dialog:getFields(); self.settings.google_api_key = f[1] or ""; self:saveSettings(); UIManager:close(dialog) end },
        } },
    }
    UIManager:show(dialog); dialog:onShowKeyboard()
end

function MetadataScraper:editAmazon()
    local dialog
    dialog = MultiInputDialog:new{
        title = _("Amazon Creators API"),
        fields = {
            { description = _("Credential ID"), text = self.settings.amazon_client_id or "" },
            { description = _("Credential secret"), text = self.settings.amazon_client_secret or "", text_type = "password" },
            { description = _("Partner Tag"), text = self.settings.amazon_partner_tag or "" },
        },
        buttons = { {
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("Save"), callback = function()
                local f = dialog:getFields()
                self.settings.amazon_client_id = f[1] or ""; self.settings.amazon_client_secret = f[2] or ""; self.settings.amazon_partner_tag = f[3] or ""
                self:saveSettings(); UIManager:close(dialog)
            end },
        } },
    }
    UIManager:show(dialog); dialog:onShowKeyboard()
end

function MetadataScraper:startForFile(file)
    if not self:isEpub(file) then return end
    local raw, props = self:getRawProps(file)
    local title = props.title or file:match((ÿç©¹º+–‡•«­†Š