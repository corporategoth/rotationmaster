-- Player-facing handling of the archive of rotations saved by a release before 2.0 (the upgrade in
-- Core/rotation_migration.lua parks them unowned). Owns the one-time chat notice, the settings banner state and the
-- bulk "adopt everything" action. It never decides an owner itself: adoption goes through addon:PlanRotationAdoption
-- and addon:ApplyRotationAdoption. Flags live in the profile (legacyArchiveNoticed, legacyArchiveBannerDismissed).
-- Loaded from RotationMaster.toc after Core/rotation_migration.lua; the UI (UI/legacy_archive_banner.lua,
-- UI/rotation_adoption.lua) is the caller.

local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Rotations saved by a release before 2.0 have no recorded owner, so the
-- upgrade archives them (Core/rotation_migration.lua) and none of them runs
-- until it is adopted. This file is what tells the player, once, and what
-- adopts many at once. It never decides an owner itself: every adoption goes
-- through addon:PlanRotationAdoption / ApplyRotationAdoption, the same
-- ownership code a single adoption uses, and the caller names the scope.

-- Counts what the current profile and character still hold in the archive of pre-2.0 rotations.
-- @return table|nil  { total = number, profile = number, character = number }; nil while the rotation store is not
--   ready.
-- @return string|nil  The reason when the first return is nil; nil otherwise.
--
-- Rows without a body (orphan source components) are not rotations and are not counted.
function addon:GetLegacyArchiveSummary()
    if not self.ListUnassignedRotations then
        return nil, 'missing-archive-reader'
    end

    local rows, why = self:ListUnassignedRotations()

    if not rows then
        return nil, why
    end

    local summary = { total = 0, profile = 0, character = 0 }

    for _, row in ipairs(rows) do
        if row.hasBody then
            summary.total = summary.total + 1
            summary[row.kind] = (summary[row.kind] or 0) + 1
        end
    end

    return summary
end

-- Prints the one-time chat message about the archive: once per profile, and only while something is waiting.
-- @return boolean  True when the message was printed; false otherwise.
--
-- Nothing is recorded when nothing was said, so a later archive (an old profile imported or copied in) is still
-- announced once.
function addon:ShowLegacyArchiveNotice()
    local profile = self.db and self.db.profile

    if type(profile) ~= 'table' or profile.legacyArchiveNoticed == true then
        return false
    end

    local summary = self:GetLegacyArchiveSummary()

    if not summary or summary.total == 0 then
        return false
    end

    profile.legacyArchiveNoticed = true

    self:print(
        L['%d rotations from before version 2 are waiting in an archive and do not run until you adopt them. Open Rotation Master, choose Rotations, then Recover unassigned rotations.'],
        summary.total
    )

    return true
end

-- Returns the settings-window banner state: shown while rotations wait, until the player dismisses it.
-- @return number|nil  How many rotations are waiting; nil when the banner is dismissed or nothing waits.
--
-- Dismissing hides the banner only; the archive stays.
function addon:GetLegacyArchiveBanner()
    local profile = self.db and self.db.profile

    if type(profile) ~= 'table' or profile.legacyArchiveBannerDismissed == true then
        return nil
    end

    local summary = self:GetLegacyArchiveSummary()

    if not summary or summary.total == 0 then
        return nil
    end

    return summary.total
end

-- Records that the player dismissed the banner; nothing else is touched, so the archive and the chat notice are
-- unaffected.
function addon:DismissLegacyArchiveBanner()
    local profile = self.db and self.db.profile

    if type(profile) == 'table' then
        profile.legacyArchiveBannerDismissed = true
    end
end

-- Adopts every unassigned rotation that has a body.
-- @param scope string  The owner scope, 'class' or 'character', exactly as a single adoption.
-- @param options table|nil  options.spec limits the adoption to one specialization key of the archive.
-- @return table|nil  { adopted = number, skipped = number, failed = { { kind, spec, id, name, reason }, ... },
--   references = table[] }; nil when the scope is invalid or the archive cannot be read.
-- @return string|nil  The reason ('invalid-owner-scope' or the archive reader's reason) when the first return is nil;
--   nil otherwise.
--
-- Each rotation is planned and applied on its own, so a refusal (a collision, an invalid body) leaves the others
-- adopted and is reported, never forced.
function addon:AdoptAllUnassignedRotations(scope, options)
    if scope ~= 'class' and scope ~= 'character' then
        return nil, 'invalid-owner-scope'
    end

    local rows, why = self:ListUnassignedRotations()

    if not rows then
        return nil, why
    end

    local only = options and options.spec
    local result = { adopted = 0, skipped = 0, failed = {}, references = {} }

    for _, row in ipairs(rows) do
        if only == nil or row.spec == only then
            if not row.hasBody then
                result.skipped = result.skipped + 1
            else
                local plan, reason = self:PlanRotationAdoption(row.selection, scope)
                local ok, reference

                if plan then
                    ok, reference = self:ApplyRotationAdoption(plan)

                    if not ok then
                        reason = reference
                    end
                end

                if ok then
                    result.adopted = result.adopted + 1
                    result.references[#result.references + 1] = reference
                else
                    result.failed[#result.failed + 1] = {
                        kind = row.kind,
                        spec = row.spec,
                        id = row.id,
                        name = row.name,
                        reason = reason,
                    }
                end
            end
        end
    end

    return result
end

-- Say it on the first world entry after the upgrade, once the chat frame and
-- the rotation store are ready; a profile with nothing waiting says nothing.
local frame

if type(CreateFrame) == 'function' then
    local ok, created = pcall(CreateFrame, 'Frame')

    if
        ok
        and type(created) == 'table'
        and type(created.RegisterEvent) == 'function'
        and type(created.SetScript) == 'function'
    then
        frame = created

        created:SetScript('OnEvent', function()
            addon:ShowLegacyArchiveNotice()
        end)

        pcall(created.RegisterEvent, created, 'PLAYER_ENTERING_WORLD')
    end
end

addon.legacyArchiveNoticeFrame = frame
