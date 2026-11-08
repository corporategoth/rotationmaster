-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Cooldown Manager presence: an item's auraInstanceID is secret (or a number) while its aura is up and nil while it is
-- down; the unit is remembered from when it was up; items map to spells through their cooldown info.
local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()
local SECRET = setmetatable({}, { __tostring = function() return 'secret' end })

local function fixture()
    local f = F.new(18, 12)
    local e, a = f.env, f.addon
    local hooks = {}

    local function item(cooldownID)
        local frame = { cooldownID = cooldownID }

        function frame:HookScript(event, fn)
            hooks[#hooks + 1] = { self, event, fn }
        end

        return frame
    end

    local buff, debuff = item(11), item(12)
    e.BuffIconCooldownViewer = { GetChildren = function() return buff, debuff end }
    e.InCombatLockdown = function() return false end
    e.issecretvalue = function(v) return v == SECRET end

    e.C_CooldownViewer = {
        GetCooldownViewerCooldownInfo = function(id)
            if id == 11 then
                return { spellID = 774, linkedSpellIDs = { 155777 } }
            end
            if id == 12 then
                return { spellID = 8921, overrideSpellID = 164812 }
            end
        end,
    }

    f.load('Platform/cooldown_viewer.lua')
    local readable = a.Platform.CanReadValue
    a.Platform.CanReadValue = function(p, v) return v ~= SECRET and readable(p, v) end
    return a.Platform, buff, debuff, hooks
end

test('item presence maps to every spell the item tracks, per unit', function()
    local p, buff, debuff, hooks = fixture()
    buff.auraInstanceID, buff.auraDataUnit = SECRET, 'player'
    debuff.auraInstanceID, debuff.auraDataUnit = 42, 'target'
    p:RefreshCooldownViewer()
    assert(#hooks == 4, 'items hooked once each for show and hide')
    assert(p:GetCooldownViewerPresence(774, 'player') == true and p:GetCooldownViewerPresence(155777, 'player') == true)

    assert(
        p:GetCooldownViewerPresence(8921, 'target') == true and p:GetCooldownViewerPresence(164812, 'target') == true
    )

    assert(p:GetCooldownViewerPresence(774, 'target') == nil, 'not tracked on that unit')
    buff.auraInstanceID, buff.auraDataUnit = nil, nil
    p:ReadCooldownViewerItem(buff)
    assert(p:GetCooldownViewerPresence(774, 'player') == false, 'down, on the unit it was last up on')
    p:RefreshCooldownViewer()
    assert(#hooks == 4, 'no second hook')
end)

test('an item never seen up has no unit and answers nothing', function()
    local p, buff = fixture()
    p:RefreshCooldownViewer()
    assert(p:GetCooldownViewerPresence(774, 'player') == nil)
    assert(buff)
end)

finish()
