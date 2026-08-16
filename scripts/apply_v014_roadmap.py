#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path, old, new):
    p = ROOT / path
    data = p.read_text(encoding="utf-8")
    count = data.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, found {count}: {old[:80]!r}")
    p.write_text(data.replace(old, new, 1), encoding="utf-8")


replace_once("main.lua",
'''local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local _ = require("gettext")
''',
'''local lfs = require("libs/libkoreader-lfs")
local socket = require("socket")
local util = require("util")
local _ = require("gettext")
''')

replace_once("main.lua",
'''local Updater = require("lib/updater")
local Version = require("lib/version")
local Diagnostics = require("lib/diagnostics")
''',
'''local Updater = require("lib/updater")
local Version = require("lib/version")
local Settings = require("lib/settings")
local Diagnostics = require("lib/diagnostics")
''')

replace_once("main.lua",
'''local DEFAULT_ORDER = { "hardcover", "amazon", "google", "openlibrary" }

local DEFAULTS = {
''',
'''local DEFAULT_ORDER = { "hardcover", "amazon", "google", "openlibrary" }
-- These are conservative burst-control floors for batch mode, not claims about
-- provider API quotas. Provider Retry-After/cooldown handling remains authoritative.
local BATCH_PROVIDER_INTERVAL = {
    hardcover = 0.35,
    amazon = 0.50,
    google = 0.35,
    openlibrary = 0.25,
}

local DEFAULTS = {
    settings_schema_version = Settings.SCHEMA_VERSION,
    update_channel = "stable",
    provider_health = {},
''')

replace_once("main.lua",
'''    d.book_links = {}
    d.undo_records = {}
    return d
end
''',
'''    d.book_links = {}
    d.undo_records = {}
    d.provider_health = {}
    return d
end
''')

replace_once("main.lua",
'''local function provider_status_text(provider, settings)
    if not provider or type(provider.status) ~= "function" then return nil end
    local ok, text = pcall(provider.status, settings)
    if ok and text and tostring(text) ~= "" then return tostring(text) end
end
''',
'''local function provider_status_text(provider, id, settings)
    local text
    if provider and type(provider.status) == "function" then
        local ok, value = pcall(provider.status, settings)
        if ok and value and tostring(value) ~= "" then text = tostring(value) end
    end
    local health = settings and type(settings.provider_health) == "table" and settings.provider_health[id]
    if type(health) == "table" and health.tested_at then
        local last = health.ok and "last test ✓" or "last test ✗"
        text = text and (text .. " · " .. last) or last
    end
    return text
end
''')

replace_once("main.lua",
'''    local saved = self.settings_store:readSetting("config")
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
''',
'''    local saved_raw = self.settings_store:readSetting("config")
    local saved, migrated_from = Settings.migrate(saved_raw)
    if type(saved_raw) == "table" then
        for k, v in pairs(saved) do self.settings[k] = v end
        self.settings.enabled = U.copy(DEFAULTS.enabled)
        for k, v in pairs(saved.enabled or {}) do self.settings.enabled[k] = v end
        self.settings.fields = U.copy(DEFAULTS.fields)
        for k, v in pairs(saved.fields or {}) do self.settings.fields[k] = v end
        self.settings.book_links = saved.book_links or {}
        self.settings.undo_records = saved.undo_records or {}
        self.settings.provider_health = saved.provider_health or {}
        if migrated_from < Settings.SCHEMA_VERSION then self:saveSettings() end
    end
    local diagnostics_dir = DataStorage:getDataDir() .. "/cache/metadata_scraper"
    util.makePath(diagnostics_dir)
    Diagnostics.configure(diagnostics_dir .. "/diagnostics.log", self.settings)
    self.ui.menu:registerToMainMenu(self)
''')

replace_once("main.lua", 'local release, err = Updater.check()\n', 'local release, err = Updater.check(self.settings.update_channel)\n')

replace_once("main.lua",
'''    local text = string.format(_("Metadata Scraper %s is available.\\n\\nInstalled: %s\\n\\nDownload and install it now?"),
        release.version, Updater.CURRENT_VERSION)
''',
'''    local text = string.format(_("Metadata Scraper %s is available.\\n\\nInstalled: %s\\n\\nDownload and install it now?"),
        release.version, Updater.CURRENT_VERSION)
    if release.prerelease then
        text = text .. _("\\n\\nThis is a prerelease from the Test update channel.")
    end
''')

replace_once("main.lua",
'''        if not release then
            Diagnostics.log("Updater", err or "Update check failed", self.settings)
            if not silent then UIManager:show(InfoMessage:new{ text = _("Update check failed.") .. "\\n" .. tostring(err) }) end
            return
        end
''',
'''        if not release then
            Diagnostics.log("Updater", err or "Update check failed", self.settings, { operation = "check", status = "error" })
            if not silent then
                local prefix = self.settings.update_channel == "prerelease"
                    and _("No published Test-channel update is available.")
                    or _("Update check failed.")
                UIManager:show(InfoMessage:new{ text = prefix .. "\\n" .. tostring(err) })
            end
            return
        end
''')

replace_once("main.lua", 'local status = provider_status_text(provider, self.settings)\n', 'local status = provider_status_text(provider, id, self.settings)\n')

replace_once("main.lua",
'''            {{ text = _("Google Books API key…"), align = "left", callback = function() self:editGoogle() end }},
            {{ text = _("Check for updates…"), align = "left", callback = function() self:checkForUpdates(false) end }},
''',
'''            {{ text = _("Google Books API key…"), align = "left", callback = function() self:editGoogle() end }},
            {{ text = _("Update channel") .. ": " .. self:getUpdateChannelLabel(), align = "left", callback = function() self:showUpdateChannelSelector() end }},
            {{ text = _("Settings tools…"), align = "left", callback = function() self:showSettingsTools() end }},
            {{ text = _("Check for updates…"), align = "left", callback = function() self:checkForUpdates(false) end }},
''')

insert_marker = '''function MetadataScraper:sourceOptions()
'''
settings_tools = r'''function MetadataScraper:getUpdateChannelLabel()
    return self.settings.update_channel == "prerelease" and _("Test (prereleases)") or _("Stable")
end

function MetadataScraper:showUpdateChannelSelector()
    self:showSelectDialog(_("Update channel"), {
        { _("Stable"), "stable" },
        { _("Test (prereleases)"), "prerelease" },
    }, self.settings.update_channel or "stable", function(value)
        self.settings.update_channel = value == "prerelease" and "prerelease" or "stable"
        self.settings.last_update_check = 0
        self:saveSettings()
    end)
end

function MetadataScraper:exportSafeSettings()
    local cache_dir = DataStorage:getDataDir() .. "/cache/metadata_scraper"
    util.makePath(cache_dir)
    local filepath = cache_dir .. "/settings_export.lua"
    os.remove(filepath)
    local store = LuaSettings:open(filepath)
    store:saveSetting("config", Settings.safe_export(self.settings))
    store:flush()
    UIManager:show(InfoMessage:new{
        text = _("Credential-free settings exported to:") .. "\n" .. filepath
            .. "\n\n" .. _("Provider secrets, per-book provenance, undo records, health state, and update timestamps are omitted."),
    })
end

function MetadataScraper:resetMatchingSettings()
    local box
    box = ConfirmBox:new{
        text = _("Reset search, metadata-field, write-mode, and batch preferences to their defaults? Provider credentials and per-book undo/provenance will be kept."),
        ok_text = _("Reset"),
        ok_callback = function()
            UIManager:close(box)
            self.settings.source_scope = DEFAULTS.source_scope
            self.settings.replace_existing = DEFAULTS.replace_existing
            self.settings.download_cover = DEFAULTS.download_cover
            self.settings.batch_threshold = DEFAULTS.batch_threshold
            self.settings.batch_limit = DEFAULTS.batch_limit
            self.settings.batch_skip_matched = DEFAULTS.batch_skip_matched
            self.settings.fields = U.copy(DEFAULTS.fields)
            self:saveSettings()
            UIManager:show(InfoMessage:new{ text = _("Matching and batch preferences reset.") })
        end,
    }
    UIManager:show(box)
end

function MetadataScraper:resetProviderSettings()
    local box
    box = ConfirmBox:new{
        text = _("Reset all provider accounts and provider preferences? This removes saved API credentials from Metadata Scraper settings."),
        ok_text = _("Reset providers"),
        ok_callback = function()
            UIManager:close(box)
            self.settings.enabled = U.copy(DEFAULTS.enabled)
            self.settings.hardcover_token = ""
            self.settings.google_api_key = ""
            self.settings.amazon_client_id = ""
            self.settings.amazon_client_secret = ""
            self.settings.amazon_credential_version = ""
            self.settings.amazon_partner_tag = ""
            self.settings.amazon_marketplace = DEFAULTS.amazon_marketplace
            self.settings.amazon_search_index = DEFAULTS.amazon_search_index
            self.settings.provider_health = {}
            if PROVIDERS.amazon.reset_token_cache then PROVIDERS.amazon.reset_token_cache() end
            self:saveSettings()
            UIManager:show(InfoMessage:new{ text = _("Provider settings reset.") })
        end,
    }
    UIManager:show(box)
end

function MetadataScraper:resetAllSettings()
    local box
    box = ConfirmBox:new{
        text = _("Reset all Metadata Scraper settings? This removes provider credentials, preferences, saved match provenance, provider health, and available undo records."),
        ok_text = _("Reset all"),
        ok_callback = function()
            UIManager:close(box)
            for _, record in pairs(self.settings.undo_records or {}) do
                Writer.discard_snapshot(record.snapshot or record)
            end
            Diagnostics.clear()
            self.settings = clone_defaults()
            if PROVIDERS.amazon.reset_token_cache then PROVIDERS.amazon.reset_token_cache() end
            self:saveSettings()
            local diagnostics_dir = DataStorage:getDataDir() .. "/cache/metadata_scraper"
            util.makePath(diagnostics_dir)
            Diagnostics.configure(diagnostics_dir .. "/diagnostics.log", self.settings)
            UIManager:show(InfoMessage:new{ text = _("Metadata Scraper settings reset.") })
        end,
    }
    UIManager:show(box)
end

function MetadataScraper:clearDiagnostics()
    local box
    box = ConfirmBox:new{
        text = _("Clear the persistent and in-memory Metadata Scraper diagnostics log?"),
        ok_text = _("Clear"),
        ok_callback = function()
            UIManager:close(box)
            Diagnostics.clear()
            UIManager:show(InfoMessage:new{ text = _("Diagnostics cleared.") })
        end,
    }
    UIManager:show(box)
end

function MetadataScraper:showSettingsTools()
    local dialog
    dialog = ButtonDialog:new{
        title = _("Settings tools"), title_align = "center",
        buttons = {
            {{ text = _("Export settings (no credentials)…"), align = "left", callback = function() self:exportSafeSettings() end }},
            {{ text = _("Reset matching/batch settings…"), align = "left", callback = function() self:resetMatchingSettings() end }},
            {{ text = _("Reset provider settings…"), align = "left", callback = function() self:resetProviderSettings() end }},
            {{ text = _("Clear diagnostics…"), align = "left", callback = function() self:clearDiagnostics() end }},
            {{ text = _("Reset all plugin settings…"), align = "left", callback = function() self:resetAllSettings() end }},
        },
    }
    UIManager:show(dialog)
end

'''
replace_once("main.lua", insert_marker, settings_tools + insert_marker)

replace_once("main.lua",
'''            { text = self.settings.amazon_client_id or "", hint = _("Credential ID") },
            { text = self.settings.amazon_client_secret or "", hint = _("Credential secret"), text_type = "password" },
            { text = self.settings.amazon_credential_version or "", hint = _("Credential version (3.1 / 3.2 / 3.3)") },
            { text = self.settings.amazon_partner_tag or "", hint = _("Partner Tag") },
''',
'''            { text = self.settings.amazon_client_id or "", hint = _("Credential ID"), text_type = "password" },
            { text = self.settings.amazon_client_secret or "", hint = _("Credential secret"), text_type = "password" },
            { text = self.settings.amazon_credential_version or "", hint = _("Credential version (3.1 / 3.2 / 3.3)") },
            { text = self.settings.amazon_partner_tag or "", hint = _("Partner Tag"), text_type = "password" },
''')

replace_once("main.lua",
'''                local f = dlg:getFields()
                self.settings.amazon_client_id = f[1] or ""
                self.settings.amazon_client_secret = f[2] or ""
                self.settings.amazon_credential_version = U.trim(f[3] or "")
                self.settings.amazon_partner_tag = f[4] or ""
''',
'''                local f = dlg:getFields()
                local credential_version = U.trim(f[3] or "")
                if not Settings.valid_amazon_credential_version(credential_version) then
                    UIManager:show(InfoMessage:new{ text = _("Credential version must be blank, 3.1, 3.2, or 3.3.") })
                    return
                end
                self.settings.amazon_client_id = f[1] or ""
                self.settings.amazon_client_secret = f[2] or ""
                self.settings.amazon_credential_version = credential_version
                self.settings.amazon_partner_tag = f[4] or ""
''')

old_test = '''function MetadataScraper:testProviders()
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
        UIManager:show(InfoMessage:new{ text = table.concat(lines, "\\n") })
    end)
end
'''
new_test = '''function MetadataScraper:testProviders()
    NetworkMgr:runWhenOnline(function()
        local busy = InfoMessage:new{ text = _("Testing metadata providers…") }
        UIManager:show(busy); UIManager:forceRePaint()
        local lines = {}
        self.settings.provider_health = self.settings.provider_health or {}
        for _, id in ipairs(DEFAULT_ORDER) do
            local provider = PROVIDERS[id]
            local good, detail
            local started = socket.gettime()
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
            local elapsed_ms = math.floor((socket.gettime() - started) * 1000 + 0.5)
            detail = Diagnostics.redact(detail or (good and _("OK") or _("Failed")), self.settings)
            self.settings.provider_health[id] = {
                ok = good == true,
                tested_at = os.time(),
                elapsed_ms = elapsed_ms,
                detail = detail,
            }
            Diagnostics.log(provider.label, (good and "diagnostic OK: " or "diagnostic failed: ") .. detail, self.settings, {
                operation = "diagnostic",
                status = good and "ok" or "error",
                elapsed_ms = elapsed_ms,
            })
            table.insert(lines, string.format("%s %s — %s (%dms)",
                good and "✓" or "✗", provider.label, detail, elapsed_ms))
        end
        self:saveSettings()
        UIManager:close(busy)
        UIManager:show(InfoMessage:new{ text = table.concat(lines, "\\n") })
    end)
end
'''
replace_once("main.lua", old_test, new_test)

replace_once("main.lua",
'''        plugin_root = PLUGIN_ROOT,
        target = "KOReader 2026.07+",
''',
'''        plugin_root = PLUGIN_ROOT,
        settings_file = self.settings_file,
        target = "KOReader 2026.07+",
''')

old_search = '''function MetadataScraper:searchProviders(query)
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
'''
new_search = '''function MetadataScraper:paceProvider(id, options)
    if type(options) ~= "table" or not options.batch then return end
    local interval = tonumber(BATCH_PROVIDER_INTERVAL[id]) or 0
    if interval <= 0 then return end
    self._provider_last_request = self._provider_last_request or {}
    local now = socket.gettime()
    local last = tonumber(self._provider_last_request[id])
    if last and now - last < interval then socket.sleep(interval - (now - last)) end
    self._provider_last_request[id] = socket.gettime()
end

function MetadataScraper:searchProviders(query, options)
    local results, errors, counts = {}, {}, {}
    for _, id in ipairs(self:providerOrder()) do
        local enabled = self.settings.enabled[id]
        if self.settings.source_scope ~= "all" then enabled = true end
        if enabled and PROVIDERS[id] then
            local started = socket.gettime()
            self:paceProvider(id, options)
            local ok, list, err = pcall(PROVIDERS[id].search, query, self.settings)
            if ok and type(list) == "table" then
                -- If a strict title+author query returns nothing, retry title-only once.
                if #list == 0 and not err and not query.isbn and U.nonempty(query.title) and U.nonempty(query.author) then
                    local broader = U.copy(query)
                    broader.author = ""
                    self:paceProvider(id, options)
                    local retry_ok, retry_list, retry_err = pcall(PROVIDERS[id].search, broader, self.settings)
                    if retry_ok and type(retry_list) == "table" then
                        list, err = retry_list, retry_err
                    elseif not retry_ok then
                        err = tostring(retry_list)
                    end
                end
                counts[id] = #list
                for _, r in ipairs(list) do table.insert(results, r) end
                if err then errors[id] = Diagnostics.redact(err, self.settings) end
            else
                counts[id] = 0
                errors[id] = Diagnostics.redact(ok and (err or "Unknown error") or tostring(list), self.settings)
            end
            local elapsed_ms = math.floor((socket.gettime() - started) * 1000 + 0.5)
            Diagnostics.log(PROVIDERS[id].label, errors[id] or "search completed", self.settings, {
                operation = "search",
                status = errors[id] and "error" or "ok",
                elapsed_ms = elapsed_ms,
                result_count = counts[id] or 0,
            })
        end
    end
    Matcher.rank(query, results, self:sourcePriority())
    return results, errors, counts
end
'''
replace_once("main.lua", old_search, new_search)

replace_once("main.lua", 'table.insert(lines, label .. ": " .. tostring(errors[id]))\n', 'table.insert(lines, label .. ": " .. Diagnostics.redact(errors[id], self.settings))\n')
replace_once("main.lua", 'local results, errors, counts = self:searchProviders(q)\n', 'local results, errors, counts = self:searchProviders(q, { batch = true })\n')

# Add the new runtime settings helper to the updater file list. Hashes are regenerated later.
update_path = ROOT / "update.json"
manifest = json.loads(update_path.read_text(encoding="utf-8"))
files = manifest.get("files", [])
if "lib/settings.lua" not in files:
    try:
        idx = files.index("lib/matcher.lua") + 1
    except ValueError:
        idx = len(files)
    files.insert(idx, "lib/settings.lua")
manifest["files"] = files
update_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

print("Applied v0.1.4 roadmap integration patch")
