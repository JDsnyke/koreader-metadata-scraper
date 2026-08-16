#!/usr/bin/env python3
from pathlib import Path

path = Path("main.lua")
text = path.read_text(encoding="utf-8")


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    text = text.replace(old, new, 1)


replace_once(
'''    local apply_fields = type(options.fields) == "table" and options.fields or self.settings.fields
    local apply_cover = options.download_cover
    if apply_cover == nil then apply_cover = self.settings.download_cover end

    local changes, preview_err = Writer.preview(file, raw, result, apply_fields, self.settings.replace_existing)
''',
'''    local apply_fields = type(options.fields) == "table" and options.fields or self.settings.fields
    local apply_cover = options.download_cover
    if apply_cover == nil then apply_cover = self.settings.download_cover end
    local replace_existing = options.replace_existing
    if replace_existing == nil then replace_existing = self.settings.replace_existing end

    local changes, preview_err = Writer.preview(file, raw, result, apply_fields, replace_existing)
''',
"freeze apply write mode",
)

replace_once(
'''    if #changes > 0 then
        ok, write_err = Writer.write(file, raw, result, apply_fields, self.settings.replace_existing)
    end

    if not ok then
        Writer.discard_snapshot(snapshot)
        Diagnostics.log("Metadata writer", write_err or "Could not write KOReader custom metadata", self.settings)
        if not quiet then
            UIManager:show(InfoMessage:new{ text = _("Could not write KOReader custom metadata.") .. (write_err and ("\\n" .. tostring(write_err)) or "") })
        end
        return false
    end
''',
'''    if #changes > 0 then
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
            recovery_note = "\\n" .. _("Automatic rollback could not be confirmed. The recovery snapshot was retained under Undo last metadata update.")
            Diagnostics.log("Metadata rollback", restore_err or "Could not restore user-facing snapshot", self.settings)
        end
        Diagnostics.log("Metadata writer", write_err or "Could not write KOReader custom metadata", self.settings)
        if not quiet then
            UIManager:show(InfoMessage:new{
                text = _("Could not write KOReader custom metadata.")
                    .. (write_err and ("\\n" .. tostring(write_err)) or "") .. recovery_note,
            })
        end
        return false
    end
''',
"retain snapshot on metadata rollback uncertainty",
)

replace_once(
'''    local text_applied = #changes > 0
    local applied_any = text_applied or cover_ok == true
    if applied_any then
        self:storeUndoRecord(file, snapshot, previous_link)
        self:recordLink(file, result, query, changes, cover_ok)
    else
        Writer.discard_snapshot(snapshot)
    end

    if wants_cover and not cover_ok then
        Diagnostics.log("Cover writer", cover_err or "Could not save custom cover", self.settings)
    end
''',
'''    local text_applied = #changes > 0
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
''',
"protect cover-only recovery snapshot",
)

replace_once(
'''        local threshold = tonumber(self.settings.batch_threshold) or 90
        local plan = {
            apply = {},
            skipped = 0,
            already_matched = 0,
            failed = 0,
            total = count,
            threshold = threshold,
        }
''',
'''        local threshold = tonumber(self.settings.batch_threshold) or 90
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
''',
"freeze batch options",
)

replace_once(
'''                    table.insert(plan.apply, {
                        file = file,
                        raw = raw,
                        query = q,
                        result = best,
                    })
''',
'''                    table.insert(plan.apply, {
                        file = file,
                        raw = raw,
                        query = q,
                        result = best,
                        options = batch_options,
                    })
''',
"attach batch options",
)

replace_once(
'''            local ok = self:applyResult(entry.file, entry.raw, entry.result, true, entry.query)
''',
'''            local ok = self:applyResult(entry.file, entry.raw, entry.result, true, entry.query, entry.options or plan.options)
''',
"apply frozen batch options",
)

path.write_text(text, encoding="utf-8")
print("Applied v0.1.3 RC fixes to main.lua")
