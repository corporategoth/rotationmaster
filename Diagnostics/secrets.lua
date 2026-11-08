-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- /rm debug secrets [reset]: an in-game probe of what the client hides and of the workarounds that depend on it, shown
-- in the copyable report window so a tester can paste it back. It checks the restriction state, button geometry, the
-- player aura list, the range bracket, the swing timer, Cooldown frames fed by duration objects, curve alphas, the
-- Cooldown Manager presence, the target cast bar shield, unit rank reads, enemies targeting you, movement, and lists
-- which conditions were unavailable how often (addon.unavailableConditionCounts, Core/conditions.lua). Every probe is
-- guarded and reports "secret", "error" or the plain value; nothing is compared that could be secret. Loaded from
-- RotationMaster.toc after Diagnostics/raid_marks.lua.
local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Describes a value for the report: "secret", "nil", or its plain text.
-- @param value any  The value.
-- @return string  The description.
local function show(value)
    if type(issecretvalue) == 'function' and issecretvalue(value) then
        return 'secret'
    end
    if value == nil then
        return 'nil'
    end

    return tostring(value)
end

-- Calls a function under pcall and describes its first returns.
-- @param fn any  The function; a non-function reports "missing".
-- @param ... any  Its arguments.
-- @return string  The description of up to three returns, or "error: ..." / "missing".
local function probe(fn, ...)
    if type(fn) ~= 'function' then
        return 'missing'
    end

    local ok, a, b, c = pcall(fn, ...)

    if not ok then
        return 'error: ' .. tostring(a)
    end

    return show(a) .. (b ~= nil and (', ' .. show(b)) or '') .. (c ~= nil and (', ' .. show(c)) or '')
end

-- Builds the probe report lines.
-- @return table  The lines.
function addon:BuildSecretsDiagnostic()
    local lines, platform = {}, self.Platform
    local client = platform:GetClientInfo()

    -- Appends one "key: value" line.
    -- @param key string  The label.
    -- @param value any  The value, described by show unless it is already a string.
    local function add(key, value)
        lines[#lines + 1] = key .. ': ' .. (type(value) == 'string' and value or show(value))
    end

    add('client', tostring(client.family) .. ' / ' .. tostring(client.combatDataPolicy))
    add('time', probe(GetTime))
    add('C_Secrets.HasSecretRestrictions', probe(C_Secrets and C_Secrets.HasSecretRestrictions))
    add('C_Secrets.ShouldAurasBeSecret', probe(C_Secrets and C_Secrets.ShouldAurasBeSecret))
    add('C_Secrets.ShouldCooldownsBeSecret', probe(C_Secrets and C_Secrets.ShouldCooldownsBeSecret))

    local restricted, types = C_RestrictedActions, Enum and Enum.AddOnRestrictionType

    if type(restricted) == 'table' and type(types) == 'table' then
        for _, name in ipairs({ 'Combat', 'Encounter', 'ChallengeMode', 'PvPMatch', 'Map', 'Chat' }) do
            if types[name] ~= nil then
                add('restriction.' .. name, probe(restricted.IsAddOnRestrictionActive, types[name]))
            end
        end
    end

    local button = rawget(_G, 'ActionButton1')

    if type(button) == 'table' then
        add('ActionButton1:GetWidth', probe(button.GetWidth, button))
        add('ActionButton1:GetEffectiveScale', probe(button.GetEffectiveScale, button))
    end

    local count, secretFields = 0, 0

    for index = 1, 40 do
        local ok, aura = pcall(
            C_UnitAuras and C_UnitAuras.GetAuraDataByIndex or function() end,
            'player',
            index,
            'HELPFUL'
        )

        if not ok or aura == nil then
            break
        end

        count = count + 1

        if
            type(issecretvalue) == 'function' and (issecretvalue(aura.spellId) or issecretvalue(aura.expirationTime))
        then
            secretFields = secretFields + 1
        end
    end

    add('player HELPFUL auras listed', count .. ' (' .. secretFields .. ' with secret fields)')

    add('GetUnitAuraInstanceIDs(player, HELPFUL)', probe(function()
        local ids = C_UnitAuras.GetUnitAuraInstanceIDs('player', 'HELPFUL')
        return type(ids) == 'table' and #ids or ids
    end))

    -- Every own-buff check of the active rotation: Blizzard's secrecy level for the spell, what the game returns for it
    -- now (nil, a table, or a secret), and RM's answer, so a tester can see which checks the game still answers in combat.
    local body, seen, listed = self.GetLeanPlanRotation and self:GetLeanPlanRotation(), {}, 0

    -- Collects the own-buff spells of a condition tree.
    -- @param node any  A condition node.
    local function collect(node)
        if type(node) ~= 'table' then
            return
        end

        if
            (node.type == 'BUFF' or node.type == 'DEBUFF') and node.unit == 'player' and type(node.spell) == 'number'
        then
            if not seen[node.spell] and listed < 12 then
                seen[node.spell], listed = node, listed + 1
            end
        end

        if type(node.value) == 'table' then
            if node.value.type then
                collect(node.value)
            else
                for _, child in ipairs(node.value) do
                    collect(child)
                end
            end
        end
    end

    -- Collects from a step list, recursing into branches.
    -- @param steps table|nil  The steps.
    local function walk(steps)
        for _, step in pairs(steps or {}) do
            if type(step) == 'table' then
                collect(step.conditions)
                walk(step.onTrue)
                walk(step.onFalse)
            end
        end
    end

    if body then
        walk(body.cooldowns)
        walk(body.rotation)
    end

    add('lean plan folded leaves', show(self.leanStats and self.leanStats.folded))
    add('cooldowns handed to the game', show(self.leanStats and self.leanStats.handedOff))
    add('cooldowns left out in combat', show(self.leanStats and self.leanStats.hiddenInCombat))

    for spell, node in pairs(seen) do
        local info = platform:GetSpellInfo(spell)
        local outcome = self:evaluateConditionResult(node)

        add(
            'own aura ' .. spell .. ' ' .. tostring(info and info.name),
            'secrecy '
                .. probe(C_Secrets and C_Secrets.GetSpellAuraSecrecy, spell)
                .. '; GetPlayerAuraBySpellID '
                .. probe(function()
                    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spell)

                    if aura == nil then
                        return 'nil'
                    end

                    return type(issecretvalue) == 'function' and issecretvalue(aura) and 'secret' or type(aura)
                end)
                .. '; RM '
                .. tostring(outcome.status)
                .. (outcome.reason and (' ' .. outcome.reason) or '')
        )
    end

    add('LibRangeCheck target', probe(function()
        return LibStub('LibRangeCheck-3.0'):GetRange('target')
    end))

    local spells = platform.GetSpellRangeBounds and platform:GetSpellRangeBounds('target')
    add('spell range bracket target', spells and (show(spells.minimum) .. ' - ' .. show(spells.maximum)) or 'none')

    add(
        'swing main / off',
        show(platform.GetLastSwingDuration and platform:GetLastSwingDuration(false)) .. ' / ' .. show(
            platform.GetLastSwingDuration and platform:GetLastSwingDuration(true)
        )
    )

    add('Cooldown:SetCooldownFromDurationObject(GCD)', probe(function()
        local frame = CreateFrame('Cooldown', nil, UIParent, 'CooldownFrameTemplate')
        frame:Hide()
        local duration = C_Spell.GetSpellCooldownDuration(61304, false)
        frame:SetCooldownFromDurationObject(duration, true)
        return 'ok'
    end))

    add('curve alpha (player health < 50%) on a texture', probe(function()
        local alpha = platform:GetGateAlphas({ unit = 'player', kind = 'health', operator = 'LESSTHAN', value = 50 })
        local texture = UIParent:CreateTexture(nil, 'ARTWORK')
        texture:Hide()
        texture:SetAlpha(alpha)
        return alpha == nil and 'no curve API' or 'ok'
    end))

    add('Texture:SetAlphaFromBoolean', probe(function()
        local texture = UIParent:CreateTexture(nil, 'ARTWORK')
        texture:Hide()
        texture:SetAlphaFromBoolean(true, 1, 0)
        return 'ok'
    end))

    local tracked = 0

    for _, name in ipairs({ 'BuffIconCooldownViewer', 'BuffBarCooldownViewer' }) do
        local viewer = rawget(_G, name)

        if type(viewer) == 'table' and viewer.GetChildren then
            tracked = tracked + select('#', viewer:GetChildren())
        end
    end

    add('Cooldown Manager buff items', tracked)

    local spellBar = rawget(_G, 'TargetFrameSpellBar')
    local shield = type(spellBar) == 'table' and (spellBar.BorderShield or spellBar.Shield)

    if type(shield) == 'table' then
        add('TargetFrameSpellBar shield shown', probe(shield.IsShown, shield))
    end

    add('UnitCastingInfo(target) name, notInterruptible', probe(function()
        local name, _, _, _, _, _, _, flag = UnitCastingInfo('target')
        return name, flag
    end))

    add('UnitClassification(target)', probe(UnitClassification, 'target'))
    add('UnitIsBossMob(target)', probe(UnitIsBossMob, 'target'))
    add('UnitLevel(target)', probe(UnitLevel, 'target'))
    add('enemies targeting you', probe(platform.GetEnemiesTargetingPlayer, platform))
    add('GetUnitSpeed(player)', probe(GetUnitSpeed, 'player'))

    add('movement observation', probe(function()
        local record = platform:GetPlayerMovementObservation()
        return record and record.speed, record and record.estimated
    end))

    add('C_Spell.IsSpellUsable(GCD spell)', probe(C_Spell and C_Spell.IsSpellUsable, 61304))
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Unavailable condition answers since the last reset (type: reason = count):'
    local rows = {}

    for tag, reasons in pairs(self.unavailableConditionCounts or {}) do
        for reason, total in pairs(reasons) do
            rows[#rows + 1] = { tag .. ': ' .. reason, total }
        end
    end

    table.sort(rows, function(a, b) return a[2] > b[2] or a[2] == b[2] and a[1] < b[1] end)

    for index = 1, math.min(#rows, 40) do
        lines[#lines + 1] = '  ' .. rows[index][1] .. ' = ' .. rows[index][2]
    end

    if #rows == 0 then
        lines[#lines + 1] = '  none'
    end

    return lines
end

-- Runs /rm debug secrets: shows the report in the copyable window, or clears the counts with "reset".
-- @param rest string|nil  "reset" to clear the unavailable answer counts.
function addon:RunSecretsDiagnostic(rest)
    if rest == 'reset' then
        for tag in pairs(self.unavailableConditionCounts or {}) do
            self.unavailableConditionCounts[tag] = nil
        end

        self:print(L['Secret value counts cleared.'])
        return
    end

    local lines = self:BuildSecretsDiagnostic()

    if self.ShowConditionText then
        self:ShowConditionText(table.concat(lines, '\n'), L['Secret value probe'])
    else
        for _, line in ipairs(lines) do
            self:print('%s', line)
        end
    end
end
