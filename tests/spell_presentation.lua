local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new()
    f.env.C_Spell={
        GetSpellInfo=function(id) if id==403 then return {name='Lightning Bolt',spellID=403} end end,
        GetSpellLink=function(id) if id==403 then return '|cff71d5ff|Hspell:403|h[Lightning Bolt]|h|r' end end,
    }
    f.load('Platform/client.lua');f.load('Platform/spells.lua')
    return f
end
test('spell labels use native names and links while missing metadata stays explicit',function()
    local f=fixture()
    assert(f.addon:SpellLabel(403):find('|Hspell:403|h[Lightning Bolt]',1,true))
    assert(f.addon:SpellLabel(999):find('Unknown spell',1,true))
    assert(f.addon:SpellLabel('Saved aura name')=='Saved aura name')
end)
test('native hyperlinks support hover/click without replacing existing widget handlers',function()
    local f=fixture();local shown,clicked
    f.env.GameTooltip={SetOwner=function() end,SetHyperlink=function(_,link) shown=link end,Hide=function() shown=nil end}
    f.env.SetItemRef=function(link) clicked=link end
    local frame={scripts={},hooks={}}
    function frame:SetHyperlinksEnabled(v) self.enabled=v end
    function frame:EnableMouse(v) self.mouse=v end
    function frame:SetScript(event,fn) self.scripts[event]=fn end
    function frame:GetScript(event) return self.scripts[event] end
    function frame:HookScript(event,fn) self.hooks[event]=fn end
    local original=function() end;frame.scripts.OnHyperlinkEnter=original
    f.addon:InstallSpellHyperlinks(frame);f.addon:InstallSpellHyperlinks(frame)
    assert(frame.enabled and frame.mouse and frame.scripts.OnHyperlinkEnter==original)
    frame.hooks.OnHyperlinkEnter(frame,'spell:403');assert(shown=='spell:403')
    frame.hooks.OnHyperlinkClick(frame,'spell:403','Lightning Bolt','LeftButton');assert(clicked=='spell:403')
    frame.hooks.OnHyperlinkLeave(frame);assert(shown==nil)
    clicked=nil;frame.hooks.OnHyperlinkClick(frame,'not-a-spell:1');assert(clicked==nil)
end)
test('numeric aura and learned-state descriptions present readable linked spells',function()
    local f=fixture()
    f.load('Core/conditions.lua');f.load('Conditions/known_spell.lua');f.load('Conditions/buffs.lua');f.load('Conditions/debuffs.lua')
    for _,tag in ipairs({'SPELL_KNOWN','BUFF','BUFF_REMAIN','BUFF_STACKS','DEBUFF','DEBUFF_REMAIN','DEBUFF_STACKS'}) do
        local v={spell=403,unit='player',operator='LESSTHAN',value=3}
        local text=f.addon.conditionDefinitions[tag].print(0,v)
        assert(text:find('[Lightning Bolt]',1,true),tag..' exposes raw numeric presentation')
    end
end)
test('plain text removes link brackets but preserves literal brackets supplied in names',function()
    local f=fixture();local text='You know |cff00ffff|Hspell:324|h[Lightning Shield]|h|r'
    assert(f.addon:PlainWorkbenchName(text)=='You know Lightning Shield')
    assert(f.addon:PlainWorkbenchName('Plan [A]')=='Plan [A]')
end)
finish()
