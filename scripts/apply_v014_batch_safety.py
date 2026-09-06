from pathlib import Path

# Matcher automatic-eligibility gate: aggregate score can never override a hard conflict.
p = Path('lib/matcher.lua')
s = p.read_text()
needle = '''function M.confidence(score, reasons)\n    score = tonumber(score) or 0\n    local set = reason_set(reasons)\n\n    if set["ISBN exact"] and score == 100 and not set["format conflict"] then return "Exact" end\n    if set["ISBN conflict"] or set["format conflict"] then return "Weak" end\n\n    local hard_conflict = set["author conflict"] or set["language conflict"] or set["series conflict"]\n    if score >= 90 and not hard_conflict then return "Strong" end\n    if score >= 65 and not set["author conflict"] then return "Possible" end\n    return "Weak"\nend\n\n'''
addition = needle + '''local AUTO_BLOCKING_REASONS = {\n    "ISBN conflict", "format conflict", "author conflict", "language conflict", "series conflict",\n}\n\nfunction M.auto_eligible(result, threshold)\n    if type(result) ~= "table" then return false end\n    local score = tonumber(result.score) or 0\n    threshold = tonumber(threshold) or 90\n    if score < threshold then return false end\n\n    local set = reason_set(result.match_reasons)\n    for _, reason in ipairs(AUTO_BLOCKING_REASONS) do\n        if set[reason] then return false end\n    end\n\n    local confidence = result.confidence or M.confidence(score, result.match_reasons)\n    return confidence ~= "Weak"\nend\n\n'''
if needle not in s: raise SystemExit('matcher confidence block not found')
s = s.replace(needle, addition, 1)
p.write_text(s)

# Provider runtime-state resets.
for path, marker, insert in [
    ('providers/googlebooks.lua', '\nreturn P\n', '\nfunction P.reset_runtime_state()\n    cooldown_until = 0\n    backoff_step = 0\nend\n\nreturn P\n'),
    ('providers/openlibrary.lua', '\nreturn P\n', '\nfunction P.reset_runtime_state()\n    cooldown_until = 0\nend\n\nreturn P\n'),
    ('providers/hardcover.lua', '\nP._authorization_header = authorization_header\n', '\nfunction P.reset_runtime_state()\n    cooldown_until = 0\nend\n\nP._authorization_header = authorization_header\n'),
]:
    p = Path(path); s = p.read_text()
    if marker not in s: raise SystemExit(f'{path}: return/export marker missing')
    p.write_text(s.replace(marker, insert, 1))

p = Path('providers/amazon.lua')
s = p.read_text()
old = '''P.reset_token_cache = clear_token_cache\n\nreturn P\n'''
new = '''P.reset_token_cache = clear_token_cache\nfunction P.reset_runtime_state()\n    clear_token_cache()\n    cooldown_until = 0\nend\n\nreturn P\n'''
if old not in s: raise SystemExit('Amazon export block missing')
p.write_text(s.replace(old, new, 1))

# Main: clear runtime state on credential changes/resets and enforce auto eligibility.
p = Path('main.lua')
s = p.read_text()
old = '''            self.settings.provider_health = {}\n            if PROVIDERS.amazon.reset_token_cache then PROVIDERS.amazon.reset_token_cache() end\n            self:saveSettings()\n'''
new = '''            self.settings.provider_health = {}\n            for _, provider in pairs(PROVIDERS) do\n                if type(provider.reset_runtime_state) == "function" then provider.reset_runtime_state() end\n            end\n            self:saveSettings()\n'''
if old not in s: raise SystemExit('resetProviderSettings runtime block not found')
s = s.replace(old, new, 1)

old = '''                self.settings.hardcover_token = dlg:getFields()[1] or ""\n                self.settings.enabled.hardcover = U.nonempty(self.settings.hardcover_token)\n                self:saveSettings(); UIManager:close(dlg)\n'''
new = '''                self.settings.hardcover_token = dlg:getFields()[1] or ""\n                self.settings.enabled.hardcover = U.nonempty(self.settings.hardcover_token)\n                if type(PROVIDERS.hardcover.reset_runtime_state) == "function" then PROVIDERS.hardcover.reset_runtime_state() end\n                self:saveSettings(); UIManager:close(dlg)\n'''
if old not in s: raise SystemExit('Hardcover editor save block missing')
s = s.replace(old, new, 1)

old = '''                self.settings.google_api_key = dlg:getFields()[1] or ""\n                self.settings.enabled.google = U.nonempty(self.settings.google_api_key)\n                self:saveSettings(); UIManager:close(dlg)\n'''
new = '''                self.settings.google_api_key = dlg:getFields()[1] or ""\n                self.settings.enabled.google = U.nonempty(self.settings.google_api_key)\n                if type(PROVIDERS.google.reset_runtime_state) == "function" then PROVIDERS.google.reset_runtime_state() end\n                self:saveSettings(); UIManager:close(dlg)\n'''
if old not in s: raise SystemExit('Google editor save block missing')
s = s.replace(old, new, 1)

old = '''                if PROVIDERS.amazon.reset_token_cache then PROVIDERS.amazon.reset_token_cache() end\n                self:saveSettings(); UIManager:close(dlg)\n'''
new = '''                if type(PROVIDERS.amazon.reset_runtime_state) == "function" then PROVIDERS.amazon.reset_runtime_state()\n                elseif PROVIDERS.amazon.reset_token_cache then PROVIDERS.amazon.reset_token_cache() end\n                self:saveSettings(); UIManager:close(dlg)\n'''
if old not in s: raise SystemExit('Amazon editor reset block missing')
s = s.replace(old, new, 1)

# Reset all should clear provider runtime state too.
old = '''            self.settings = clone_defaults()\n            if PROVIDERS.amazon.reset_token_cache then PROVIDERS.amazon.reset_token_cache() end\n            self:saveSettings()\n'''
new = '''            self.settings = clone_defaults()\n            for _, provider in pairs(PROVIDERS) do\n                if type(provider.reset_runtime_state) == "function" then provider.reset_runtime_state() end\n            end\n            self:saveSettings()\n'''
if old not in s: raise SystemExit('resetAll provider reset block missing')
s = s.replace(old, new, 1)

# Track high-scoring but conflict-blocked matches separately from low/no match.
old = '''            failed = 0,\n            total = count,\n            threshold = threshold,\n'''
new = '''            failed = 0,\n            manual_review = 0,\n            total = count,\n            threshold = threshold,\n'''
if old not in s: raise SystemExit('batch plan counters block missing')
s = s.replace(old, new, 1)

old = '''                if best and (best.score or 0) >= threshold then\n                    table.insert(plan.apply, {\n'''
new = '''                if best and Matcher.auto_eligible(best, threshold) then\n                    table.insert(plan.apply, {\n'''
if old not in s: raise SystemExit('batch score gate missing')
s = s.replace(old, new, 1)

old = '''                elseif all_attempted_providers_failed(self:providerOrder(), errors or {}, counts or {}) then\n                    plan.failed = plan.failed + 1\n                else\n                    plan.skipped = plan.skipped + 1\n                end\n'''
new = '''                elseif best and (tonumber(best.score) or 0) >= threshold then\n                    -- High aggregate score with hard conflict evidence is deliberately\n                    -- held for manual review instead of being auto-applied.\n                    plan.manual_review = plan.manual_review + 1\n                elseif all_attempted_providers_failed(self:providerOrder(), errors or {}, counts or {}) then\n                    plan.failed = plan.failed + 1\n                else\n                    plan.skipped = plan.skipped + 1\n                end\n'''
if old not in s: raise SystemExit('batch fallback decision block missing')
s = s.replace(old, new, 1)

# Summary strings: include manual review count in both no-ready and normal paths.
old = '''            text = string.format(_("Batch discovery complete.\\n\\nReady to apply: 0\\nLow/no match: %d\\nAlready matched: %d\\nSearch failures: %d\\n\\nNo metadata was changed."),\n                plan.skipped, plan.already_matched, plan.failed),\n'''
new = '''            text = string.format(_("Batch discovery complete.\\n\\nReady to apply: 0\\nManual review required: %d\\nLow/no match: %d\\nAlready matched: %d\\nSearch failures: %d\\n\\nNo metadata was changed."),\n                plan.manual_review or 0, plan.skipped, plan.already_matched, plan.failed),\n'''
if old not in s: raise SystemExit('empty batch summary missing')
s = s.replace(old, new, 1)

old = '''            {{ text = string.format(_("Selected: %d of %d ready · Low/no match: %d · Already matched: %d · Search failures: %d"),\n                selected, #plan.apply, plan.skipped, plan.already_matched, plan.failed), align = "left", enabled = false }},\n'''
new = '''            {{ text = string.format(_("Selected: %d of %d ready · Manual review: %d · Low/no match: %d · Already matched: %d · Search failures: %d"),\n                selected, #plan.apply, plan.manual_review or 0, plan.skipped, plan.already_matched, plan.failed), align = "left", enabled = false }},\n'''
if old not in s: raise SystemExit('normal batch summary missing')
s = s.replace(old, new, 1)

old = '''            text = string.format(_("Batch complete.\\nApplied: %d\\nLow/no match: %d\\nReview skipped: %d\\nAlready matched: %d\\nSearch failures: %d\\nApply failures: %d"),\n                applied, plan.skipped or 0, review_skipped, plan.already_matched or 0, plan.failed or 0, failed),\n'''
new = '''            text = string.format(_("Batch complete.\\nApplied: %d\\nManual review required: %d\\nLow/no match: %d\\nReview skipped: %d\\nAlready matched: %d\\nSearch failures: %d\\nApply failures: %d"),\n                applied, plan.manual_review or 0, plan.skipped or 0, review_skipped, plan.already_matched or 0, plan.failed or 0, failed),\n'''
if old not in s: raise SystemExit('batch completion summary missing')
s = s.replace(old, new, 1)
p.write_text(s)

# Tests.
p = Path('tests/v014_expansion.lua')
s = p.read_text()
insert = r'''
check("automatic batch eligibility rejects hard conflicts even above threshold", function()
    package.loaded["lib/matcher"] = nil
    local Matcher = require("lib/matcher")
    local query = { title="Shared Title", author="Correct Author", language="en", series="Saga", year=2020, media_kind="ebook" }
    local result = { title="Shared Title", authors={"Correct Author"}, authors_text="Correct Author", language="fr", series="Saga", published_date="2020", media_kind="ebook" }
    local score, reasons = Matcher.score(query, result)
    result.score = score; result.match_reasons = reasons; result.confidence = Matcher.confidence(score, reasons)
    truthy(score >= 90, "fixture must prove a misleading aggregate score can exceed default threshold")
    eq(result.confidence, "Possible")
    eq(Matcher.auto_eligible(result, 90), false)
end)

check("permissive threshold still allows clean conflict-free Possible matches", function()
    package.loaded["lib/matcher"] = nil
    local Matcher = require("lib/matcher")
    eq(Matcher.auto_eligible({score=85, confidence="Possible", match_reasons={"title exact", "author similar"}}, 80), true)
    eq(Matcher.auto_eligible({score=85, confidence="Possible", match_reasons={"title exact", "language conflict"}}, 80), false)
end)

check("batch discovery uses conflict-aware automatic eligibility", function()
    local data = read_file("main.lua")
    truthy(data:find("Matcher.auto_eligible(best, threshold)", 1, true))
    truthy(data:find("plan.manual_review = plan.manual_review + 1", 1, true))
    truthy(data:find("Manual review required", 1, true))
end)

check("credential changes clear stale provider runtime cooldown state", function()
    local main = read_file("main.lua")
    truthy(main:find("PROVIDERS.hardcover.reset_runtime_state", 1, true))
    truthy(main:find("PROVIDERS.google.reset_runtime_state", 1, true))
    truthy(main:find("PROVIDERS.amazon.reset_runtime_state", 1, true))
    truthy(read_file("providers/openlibrary.lua"):find("function P.reset_runtime_state", 1, true))
end)
'''
marker = '\nio.write(string.format("\\n%d passed, %d failed\\n", passed, failed))\n'
if marker not in s: raise SystemExit('test footer missing')
s = s.replace(marker, '\n' + insert + marker, 1)
p.write_text(s)

# Docs/changelog.
p = Path('docs/ROADMAP_IMPLEMENTATION_CHECKLIST.md')
s = p.read_text()
s = s.replace('- [ ] Hard conflicts always override misleading aggregate score/class.', '- [x] Hard conflicts always override misleading aggregate score/class for automatic batch eligibility; high-scoring conflicted results are counted as manual-review-required instead of auto-applied.', 1)
p.write_text(s)

p = Path('CHANGELOG.md')
s = p.read_text()
needle = '### Additional stability and provider hardening\n\n'
if needle not in s: raise SystemExit('changelog stability section missing')
addition = '''### Additional stability and provider hardening\n\n- Prevent a high aggregate score from overriding hard ISBN/format/author/language/series conflicts during batch auto-apply; these are now explicitly counted as manual-review-required.\n- Clear provider-local cooldown/token runtime state when provider credentials are changed or reset, avoiding stale-account cooldowns until restart.\n'''
s = s.replace(needle, addition, 1)
p.write_text(s)

print('Applied v0.1.4 batch eligibility hardening')
