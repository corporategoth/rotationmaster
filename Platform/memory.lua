-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Feeds your own successful casts to the remembered auras (Platform/auras.lua) and cooldowns (Platform/spells.lua) of
-- "Remember hidden buffs and cooldowns". UNIT_SPELLCAST_SUCCEEDED for the player keeps its spell id readable unless
-- the spell is flagged secret (SecretWhenUnitSpellCastRestricted); a hidden id is ignored. Loaded from
-- RotationMaster.toc after Platform/cooldown_viewer.lua.
local _, addon = ...
local platform = addon.Platform

if type(CreateFrame) == 'function' then
    local events = CreateFrame('Frame')

    if not pcall(events.RegisterUnitEvent, events, 'UNIT_SPELLCAST_SUCCEEDED', 'player') then
        pcall(events.RegisterEvent, events, 'UNIT_SPELLCAST_SUCCEEDED')
    end

    events:SetScript('OnEvent', function(_, _, unit, _, spell)
        if not platform:CanReadValue(unit) or unit ~= 'player' then
            return
        end

        local now = type(GetTime) == 'function' and GetTime() or 0

        if platform.NoteAuraCast then
            platform:NoteAuraCast(spell, now)
        end
        if platform.NoteCooldownCast then
            platform:NoteCooldownCast(spell, now)
        end
    end)
end
