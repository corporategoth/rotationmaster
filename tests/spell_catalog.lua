local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function setup()
    local f=F.new()
    local ranks={[8042]=1,[8044]=2,[8045]=3}
    f.addon.Platform={GetSpellInfo=function(_,id)
        if id=='Lightning Bolt' then id=403 end
        if ranks[id] then return {name='Earth Shock',subtext='Rank '..ranks[id],iconID=1,spellID=id} end
        if id==403 then return {name='Lightning Bolt',spellID=id} end
        if id==974 then return {name='Earth Shield',spellID=id} end
    end,GetSpellLink=function(_,id) return 'spell:'..id end}
    f.load('Core/spell_catalog.lua')
    return f
end
test('metadata indexing preserves exact rank identities without claiming learned state',function()
    local f=setup();local c=f.addon.SpellCatalog
    c:UpdateSpell(8042);c:UpdateSpell(8045);c:UpdateSpell(8044)
    local ids=c:GetAllSpellIds(8042)
    assert(table.concat(ids,',')=='8045,8044,8042')
    ids[1]=999;assert(c:GetAllSpellIds(8042)[1]==8045)
    assert(c:GetSpellId('Earth Shock','Rank 1')==8042)
    assert(c:GetSpellId('Earth Shock')==8045)
    assert(c:SpellName(8042,false)=='Earth Shock|cFF888888 (Rank 1)|r')
    assert(c:SpellName(8042,true)=='Earth Shock')
    assert(f.addon.specSpells==nil)
    assert(f.libraries['AceGUI-3.0-SpellLoader'].spellList==nil)
end)
test('snapshot replacement clears stale pet and spec entries while indexing offspec and passive metadata',function()
    local f=setup();local a=f.addon;a.currentSpec=0
    local snapshot={player={complete=true,entries={
        {spellID=8042,isPassive=false},{spellID=8044,isPassive=false},
        {spellID=403,isPassive=true},{spellID=974,isPassive=false,isOffSpec=true,offSpecID=264}}},
        pet={complete=true,entries={{spellID=403,isPassive=false}}}}
    function a.Platform:GetSpellBookSnapshot() return snapshot end
    a:RefreshSpellCatalog()
    assert(a.specSpells[0][8042] and not a.specSpells[0][403])
    assert(a.specSpells[264][974] and a.specSpells.pet[403])
    assert(a.specSpellsReverse[0]['Earth Shock']==8044)
    assert(a.SpellCatalog:SpellName(403,true)=='Lightning Bolt')
    snapshot={player={complete=true,entries={{spellID=8045,isPassive=false}}},pet={complete=true,entries={}}}
    a:RefreshSpellCatalog()
    assert(not a.specSpells[0][8042] and a.specSpells[264]==nil and not a.specSpells.pet[403])
    assert(a.specSpellsReverse[0]['Earth Shock']==8045 and a.specSpellsReverse.pet['Lightning Bolt']==nil)
end)
test('unavailable banks remain explicit and cannot reuse old learned state',function()
    local f=setup();local a=f.addon;a.currentSpec=0
    a.specSpells={[0]={[8042]=true},pet={[403]=true}}
    function a.Platform:GetSpellBookSnapshot() return {
        player={complete=false,reason='restricted-value',entries={}},pet={complete=true,entries={}}} end
    a:RefreshSpellCatalog()
    assert(next(a.specSpells[0])==nil and next(a.specSpells.pet)==nil)
    assert(not a.spellBookStatus.player.complete and a.spellBookStatus.player.reason=='restricted-value')
    assert(a.spellBookStatus.pet.complete)
end)
test('unknown passivity and unidentified offspec entries are indexed but never advertised as selectable actions',function()
    local f=setup();local a=f.addon;a.currentSpec=0
    function a.Platform:GetSpellBookSnapshot() return {player={complete=true,entries={
        {spellID=8042},{spellID=8044,isPassive=false,isOffSpec=true}}},pet={complete=true,entries={}}} end
    a:RefreshSpellCatalog()
    assert(next(a.specSpells[0])==nil and a.SpellCatalog:SpellName(8042,true)=='Earth Shock')
end)
test('real condition helpers resolve ranks through the owned catalog with an empty shared loader',function()
    local f=setup();local a=f.addon;local c=a.SpellCatalog
    c:UpdateSpell(8042);c:UpdateSpell(8044)
    f.load('Conditions/common.lua')
    assert(a:Widget_GetSpellId(8042,false)==8044)
    assert(a:Widget_GetSpellId(8042,true)==8042)
    assert(a:Widget_GetSpellLink(8042,true):find('Rank 1',1,true))
    assert(c:GetSpellId('Lightning Bolt')==403)
    assert(c:SpellRank(8044)=='Rank 2' and c:SpellRankNum(8044)==2)
end)
test('native canonical name resolution can discover a new rank without a numeric scanner',function()
    local f=setup();local c=f.addon.SpellCatalog;local info=f.addon.Platform.GetSpellInfo
    f.addon.Platform.GetSpellInfo=function(self,id)
        if id=='Earth Shock' then return {name='Earth Shock',spellID=8044,subtext='Rank 2'} end
        return info(self,id)
    end
    c:UpdateSpell(8042)
    assert(c:GetSpellId(8042)==8044 and c:SpellRank(8044)=='Rank 2')
    assert(c:GetSpellId(8042,'Rank 1')==8042)
    f.addon.Platform.GetSpellInfo=function(_,id)
        if id=='Earth Shock' then return nil,'restricted-value' end
        return info(f.addon.Platform,id)
    end
    local id,why=c:GetSpellId(8042);assert(id==nil and why=='restricted-value')
end)
test('unreadable rank resolution stays unavailable through every real spell predicate and NOT',function()
    local f=setup();local a=f.addon;local info=a.Platform.GetSpellInfo
    a.SpellCatalog:UpdateSpell(8042)
    a.Platform.GetSpellInfo=function(self,id)
        if id=='Earth Shock' then return nil,'restricted-value' end
        return info(self,id)
    end
    f.env.GetSpellInfo=function() return 'Earth Shock' end
    f.env.UnitExists=function() return true end
    local compress=f.libraries.LibCompress
    compress.fcs16init=function() return '' end
    compress.fcs16update=function(_,hash,part) return hash..part end
    compress.fcs16final=function(_,hash) return hash end
    a.isActivePetSpell=function() return true end
    f.load('Core/conditions.lua');f.load('Conditions/common.lua')
    for _,file in ipairs({'spell','petspell','anyspell'}) do f.load('Conditions/'..file..'.lua') end
    for tag in pairs(a.conditionDefinitions) do
        local leaf={type=tag,spell=8042,operator='EQUALS',value=0}
        local result=a:evaluateConditionResult({type='NOT',value=leaf})
        assert(result.status=='unavailable',tag..' became '..result.status)
        assert(result.reason=='restricted-value',tag..': '..tostring(result.reason))
    end
    local id,why=a:Widget_GetSpellId(8042,false)
    assert(id==nil and why=='restricted-value')
end)
test('pet and player metadata refresh tolerates an unavailable current specialization without creating a zero namespace',function()
    local f=setup();local a=f.addon;a.currentSpec=nil
    a.specSpells={[264]={[974]=true}};a.specSpellsReverse={[264]={['Earth Shield']=974}}
    function a.Platform:GetSpellBookSnapshot() return {
        player={complete=true,entries={{spellID=8042,isPassive=false}}},
        pet={complete=true,entries={{spellID=403,isPassive=false}}}} end
    a:RefreshSpellCatalog()
    assert(a.specSpells[0]==nil and a.specSpells[264]==nil and a.specSpells.pet[403])
    assert(a.specSpellsReverse.pet['Lightning Bolt']==403)
    assert(a.SpellCatalog:SpellName(8042,true)=='Earth Shock','reference metadata must remain available')
    a.currentSpec=264;a:RefreshSpellCatalog();assert(a.specSpells[264][8042])
end)
finish()
