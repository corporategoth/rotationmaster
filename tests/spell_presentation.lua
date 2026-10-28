local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()

    f.env.C_Spell = {
        GetSpellInfo = function(id)
            if id == 403 then
                return { name = 'Lightning Bolt', spellID = 403 }
            end
        end,
        GetSpellLink = function(id)
            if id == 403 then
                return '|cff71d5ff|Hspell:403|h[Lightning Bolt]|h|r'
            end
        end,
    }

    f.load('Platform/client.lua')
    f.load('Platform/spells.lua')
    return f
end

test('spell labels use native names and links while missing metadata stays explicit', function()
    local f = fixture()
    assert(f.addon:SpellLabel(403):find('|Hspell:403|h[Lightning Bolt]', 1, true))
    assert(f.addon:SpellLabel(999):find('Unknown spell', 1, true))
    assert(f.addon:SpellLabel('Saved aura name') == 'Saved aura name')
end)

test('native hyperlinks support hover/click without replacing existing widget handlers', function()
    local f = fixture()
    local shown, clicked

    f.env.GameTooltip = {
        SetOwner = function() end,
        SetHyperlink = function(_, link)
            shown = link
        end,
        Hide = function()
            shown = nil
        end,
    }

    f.env.SetItemRef = function(link)
        clicked = link
    end

    local frame = { scripts = {}, hooks = {} }

    function frame:SetHyperlinksEnabled(v)
        self.enabled = v
    end

    function frame:EnableMouse(v)
        self.mouse = v
    end

    function frame:SetScript(event, fn)
        self.scripts[event] = fn
    end

    function frame:GetScript(event)
        return self.scripts[event]
    end

    function frame:HookScript(event, fn)
        self.hooks[event] = fn
    end

    local original = function() end
    frame.scripts.OnHyperlinkEnter = original
    f.addon:InstallSpellHyperlinks(frame)
    f.addon:InstallSpellHyperlinks(frame)
    assert(frame.enabled and frame.mouse and frame.scripts.OnHyperlinkEnter == original)
    frame.hooks.OnHyperlinkEnter(frame, 'spell:403')
    assert(shown == 'spell:403')
    frame.hooks.OnHyperlinkClick(frame, 'spell:403', 'Lightning Bolt', 'LeftButton')
    assert(clicked == 'spell:403')
    frame.hooks.OnHyperlinkLeave(frame)
    assert(shown == nil)
    clicked = nil
    frame.hooks.OnHyperlinkClick(frame, 'not-a-spell:1')
    assert(clicked == nil)
end)

test('native spell links retain leading images exact interactions and stale lease protection', function()
    local f = fixture()
    local a = f.addon
    local owner, shown, clicked

    f.env.GameTooltip = {
        SetOwner = function(_, frame)
            owner = frame
        end,
        SetHyperlink = function(_, link)
            shown = link
        end,
        IsOwned = function(_, frame) return owner == frame end,
        Hide = function()
            owner = nil
            shown = nil
        end,
    }

    f.env.SetItemRef = function(link, _, button)
        clicked = { link, button }
    end

    local root = a:CreateConditionGroup()
    local link = a:CreateSpellLabel(root, 403)
    assert(link.type == 'RM-ConditionLink')
    link:SetImage(11)
    link:SetImageSize(24, 24)
    link:SetWidth(180)
    assert(link.image:GetTexture() == 11 and link.label.point[4] >= 24 and link.frame:GetHeight() >= 24)
    link.frame.scripts.OnEnter(link.frame)
    assert(shown == 'spell:403')
    link.frame.scripts.OnClick(link.frame, 'RightButton')
    assert(clicked[1] == 'spell:403' and clicked[2] == 'RightButton')
    local oldEnter, oldLeave = link.frame.scripts.OnEnter, link.frame.scripts.OnLeave
    a:ReleaseConditionWidget(root)
    assert(shown == nil)
    local other = a:CreateConditionGroup()
    local reused = a:CreateSpellLabel(other, 403)
    assert(reused == link and not reused.image:IsShown())
    oldEnter(reused.frame)
    assert(shown == nil)
    reused.frame.scripts.OnEnter(reused.frame)
    assert(shown == 'spell:403')
    oldLeave(reused.frame)
    assert(shown == 'spell:403')
    a:ReleaseConditionWidget(other)
    assert(shown == nil)
end)

test('numeric aura and learned-state descriptions present readable linked spells', function()
    local f = fixture()
    f.load('Core/conditions.lua')
    f.load('Conditions/known_spell.lua')
    f.load('Conditions/buffs.lua')
    f.load('Conditions/debuffs.lua')

    for _, tag in ipairs({
        'SPELL_KNOWN',
        'BUFF',
        'BUFF_REMAIN',
        'BUFF_STACKS',
        'DEBUFF',
        'DEBUFF_REMAIN',
        'DEBUFF_STACKS',
    }) do
        local v = { spell = 403, unit = 'player', operator = 'LESSTHAN', value = 3 }
        local text = f.addon.conditionDefinitions[tag].print(0, v)
        assert(text:find('[Lightning Bolt]', 1, true), tag .. ' exposes raw numeric presentation')
    end
end)

test('plain text removes link brackets but preserves literal brackets supplied in names', function()
    local f = fixture()
    local text = 'You know |cff00ffff|Hspell:324|h[Lightning Shield]|h|r'
    assert(f.addon:PlainWorkbenchName(text) == 'You know Lightning Shield')
    assert(f.addon:PlainWorkbenchName('Plan [A]') == 'Plan [A]')
end)

finish()
