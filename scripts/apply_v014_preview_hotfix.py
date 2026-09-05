from pathlib import Path

p = Path('main.lua')
s = p.read_text()

old = '''local function score_breakdown_text(components)\n    local parts = {}\n    for _, component in ipairs(type(components) == "table" and components or {}) do\n        local label = tostring(component.label or _("evidence"))\n        if component.delta ~= nil and tonumber(component.delta) ~= 0 then\n            local delta = tonumber(component.delta) or 0\n            label = label .. " " .. (delta > 0 and "+" or "") .. tostring(delta)\n        end\n        if component.cap ~= nil then label = label .. " ≤" .. tostring(component.cap) end\n        if component.detail and tostring(component.detail) ~= "" then label = label .. " (" .. tostring(component.detail) .. ")" end\n        table.insert(parts, label)\n    end\n    return table.concat(parts, "; ")\nend\n'''
new = '''local function score_breakdown_text(components, max_chars)\n    local parts = {}\n    for _, component in ipairs(type(components) == "table" and components or {}) do\n        if type(component) == "table" then\n            local label = tostring(component.label or _("evidence"))\n            if component.delta ~= nil and tonumber(component.delta) ~= 0 then\n                local delta = tonumber(component.delta) or 0\n                label = label .. " " .. (delta > 0 and "+" or "") .. tostring(delta)\n            end\n            if component.cap ~= nil then label = label .. " ≤" .. tostring(component.cap) end\n            if component.detail and tostring(component.detail) ~= "" then label = label .. " (" .. tostring(component.detail) .. ")" end\n            table.insert(parts, label)\n        elseif component ~= nil then\n            table.insert(parts, tostring(component))\n        end\n    end\n    local text = table.concat(parts, "; ")\n    max_chars = tonumber(max_chars) or 480\n    if #text > max_chars then text = text:sub(1, math.max(1, max_chars - 1)) .. "…" end\n    return text\nend\n'''
assert old in s, 'score_breakdown_text block not found')
s = s.replace(old, new, 1)

old = '''        table.insert(rows, {{\n            text = text, align = "left",\n            callback = function() UIManager:close(dialog); self:showPreview(file, raw, query, r) end,\n        }})\n'''
new = '''        table.insert(rows, {{\n            text = text, align = "left",\n            callback = function()\n                UIManager:close(dialog)\n                local ok, err = pcall(self.showPreview, self, file, raw, query, r)\n                if not ok then\n                    local message = Diagnostics.redact(err or "Result preview failed", self.settings)\n                    Diagnostics.log("Result preview", message, self.settings, { operation = "preview", status = "error" })\n                    UIManager:show(InfoMessage:new{\n                        text = _("Could not open this metadata result safely.") .. "\\n" .. tostring(message),\n                    })\n                end\n            end,\n        }})\n'''
assert old in s, 'showResults callback block not found')
s = s.replace(old, new, 1)

old = '''    info(_("Confidence"), confidence_label(r.confidence))\n    local breakdown = score_breakdown_text(r.score_components)\n    if breakdown ~= "" then info(_("Score breakdown"), breakdown) end\n    if r.also_sources and #r.also_sources > 0 then info(_("Also found on"), U.join(r.also_sources, ", ")) end\n'''
new = '''    info(_("Confidence"), confidence_label(r.confidence))\n    if r.also_sources and #r.also_sources > 0 then info(_("Also found on"), U.join(r.also_sources, ", ")) end\n'''
assert old in s, 'inline score breakdown block not found')
s = s.replace(old, new, 1)

needle = '''    if r.match_reasons and #r.match_reasons > 0 then info(_("Match"), U.join(r.match_reasons, ", ")) end\n    info(_("Cover"), r.cover_url and _("available") or _("not available"))\n\n    local changes, change_err = Writer.preview(file, raw, r, self.settings.fields, self.settings.replace_existing)\n'''
replacement = '''    if r.match_reasons and #r.match_reasons > 0 then info(_("Match"), U.join(r.match_reasons, ", ")) end\n    info(_("Cover"), r.cover_url and _("available") or _("not available"))\n    if type(r.score_components) == "table" and #r.score_components > 0 then\n        table.insert(rows, {{\n            text = _("Match evidence…"), align = "left",\n            callback = function()\n                local breakdown = score_breakdown_text(r.score_components, 1200)\n                UIManager:show(InfoMessage:new{\n                    text = _("Match evidence") .. "\\n\\n" .. (breakdown ~= "" and breakdown or _("No score evidence available.")),\n                })\n            end,\n        }})\n    end\n\n    local changes, change_err = Writer.preview(file, raw, r, self.settings.fields, self.settings.replace_existing)\n'''
assert needle in s, 'showPreview evidence insertion point not found')
s = s.replace(needle, replacement, 1)

old = '''    local breakdown = score_breakdown_text(link.score_components)\n    if breakdown ~= "" then table.insert(lines, _("Score breakdown") .. ": " .. breakdown) end\n'''
new = '''    local breakdown = score_breakdown_text(link.score_components, 220)\n    if breakdown ~= "" then table.insert(lines, _("Score breakdown") .. ": " .. breakdown) end\n'''
assert old in s, 'last match breakdown block not found')
s = s.replace(old, new, 1)

p.write_text(s)

p = Path('tests/v014_expansion.lua')
s = p.read_text()
insert = '''\ncheck("result selection preview is guarded and score evidence is not rendered inline", function()\n    local data = read_file("main.lua")\n    truthy(data:find("local ok, err = pcall(self.showPreview, self, file, raw, query, r)", 1, true), "result preview callback is not protected")\n    local start = assert(data:find("function MetadataScraper:showPreview", 1, true))\n    local finish = assert(data:find("function MetadataScraper:listEpubs", start, true))\n    local block = data:sub(start, finish - 1)\n    truthy(block:find('text = _("Match evidence…")', 1, true), "separate match evidence action missing")\n    truthy(not block:find('info(_("Score breakdown"), breakdown)', 1, true), "large score breakdown must not render inline in ButtonDialog")\nend)\n'''
marker = '\nio.write(string.format("\\n%d passed, %d failed\\n", passed, failed))\n'
assert marker in s, 'test footer not found'
s = s.replace(marker, insert + marker, 1)
p.write_text(s)

p = Path('CHANGELOG.md')
s = p.read_text()
needle = '## [0.1.4] - Unreleased\n'
assert needle in s
addition = '''## [0.1.4] - Unreleased\n\n### Result preview stability\n\n- Fixed a Kindle/KOReader crash regression when selecting a metadata search result after numeric score-component rendering was added.\n- Moved detailed numeric score evidence out of the main result `ButtonDialog` into a bounded **Match evidence…** view.\n- Protected the result-selection preview callback so unexpected provider/detail rendering errors are logged and shown as a controlled message instead of escaping through KOReader UI.\n'''
s = s.replace(needle, addition, 1)
p.write_text(s)

print('Applied result preview crash hotfix')
