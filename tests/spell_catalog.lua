local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function setup()
    local f=F.new()
    local ranks={[8042]=1,[8044]=2,[8045]=3}
    f.addon.Platform.GetSpellInfo=function(_,id)
        if id=='Lightning Bolt' then id=403 end
        if ranks[id] then return {name='Earth Shock',subtext='Rank '..ranks[id],iconID=1,spellID=id} end
        if id==403 then return {name='Lightning Bolt',spellID=id} end
        if id==974 then return {name='Earth Shield',spellID=id} end
    end
    f.addon.Platform.GetSpellLink=function(_,id) return 'spell:'..id end
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
    assert(f.libraries['AceGUI-3.0-SpellLoader']==nil)
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
-- These controls load the real catalog with counted standard operations;
-- no substitute cache implementation or learned-state shortcut is supplied.
local function countedCatalog()
    local f=F.new();local metadata={
        [1]={name='Shock',subtext='Rank 1',iconID=1,spellID=1},
        [2]={name='Shock',subtext='Rank 2',iconID=2,spellID=2},
        [3]={name='Other',subtext='',iconID=3,spellID=3}}
    local counts={sort=0,rank=0,info=0,link=0};local hookSort,hookLink
    local native={};for key,value in pairs(table) do native[key]=value end
    native.sort=function(values,compare)
        counts.sort=counts.sort+1;table.sort(values,compare)
        if hookSort then hookSort(values) end
    end
    f.env.table=native
    f.env.tonumber=function(...) counts.rank=counts.rank+1;return tonumber(...) end
    f.addon.Platform.GetSpellInfo=function(_,id) counts.info=counts.info+1;return metadata[id] end
    f.addon.Platform.GetSpellLink=function(_,id) counts.link=counts.link+1;if hookLink then hookLink(id) end;return 'spell:'..id end
    f.load('Core/spell_catalog.lua')
    return f,f.addon.SpellCatalog,metadata,counts,function(sort,link) hookSort,hookLink=sort,link end
end
test('warm static groups avoid repeated sorting and rank parsing but every result is fresh',function()
    local _,c,_,counts=countedCatalog();c:UpdateSpell(1);c:UpdateSpell(2)
    local first=c:GetAllSpellIds('Shock');local sorted,parsed=counts.sort,counts.rank
    assert(sorted==1 and parsed>0);first[1]=999;first.extra='caller'
    for _=1,12 do local next=c:GetAllSpellIds(1);assert(next[1]==2 and next[2]==1 and next~=first and next.extra==nil) end
    assert(counts.sort==sorted,'unchanged group sorted again')
    assert(counts.rank==parsed,'unchanged ranks parsed again')
end)
test('only affected metadata ordering changes invalidate; same rank icon and link refresh remains live',function()
    local _,c,m,counts=countedCatalog();c:UpdateSpell(1);c:UpdateSpell(2);c:UpdateSpell(3)
    c:GetAllSpellIds('Shock');c:GetAllSpellIds('Other');local sorted=counts.sort
    m[1].iconID=77;c:UpdateSpell(1);assert(counts.link==4 and counts.info==4)
    c:GetAllSpellIds('Shock');c:GetAllSpellIds('Other');assert(counts.sort==sorted,'unchanged metadata order invalidated')
    m[1].subtext='Rank 3';c:UpdateSpell(1);assert(c:GetAllSpellIds('Shock')[1]==1);assert(counts.sort==sorted+1)
    c:GetAllSpellIds('Other');assert(counts.sort==sorted+1,'unrelated group invalidated')
    m[1].name='Other';c:UpdateSpell(1);assert(table.concat(c:GetAllSpellIds('Shock'),',')=='2');assert(table.concat(c:GetAllSpellIds('Other'),',')=='1,3')
    m[2].name='Other';c:UpdateSpell(2);local empty=c:GetAllSpellIds('Shock');assert(type(empty)=='table' and #empty==0);empty[1]=99;assert(#c:GetAllSpellIds('Shock')==0)
end)
test('case-insensitive groups retain numeric rank and ID tie order including absent ranks',function()
    local _,c,m=countedCatalog();m[4]={name='SHOCK',subtext='Rank 2',spellID=4};m[5]={name='Shock',spellID=5};m[6]={name='Shock',subtext='',spellID=6}
    for _,id in ipairs({1,2,4,5,6})do c:UpdateSpell(id) end
    assert(table.concat(c:GetAllSpellIds('sHoCk'),',')=='4,2,1,6,5')
    m[4].subtext='Rank 1';c:UpdateSpell(4);assert(table.concat(c:GetAllSpellIds('Shock'),',')=='2,4,1,6,5')
end)
test('native canonical rank queries and failures remain fresh after group warming',function()
    local f,c,m,counts=countedCatalog();c:UpdateSpell(1);c:UpdateSpell(2);c:GetAllSpellIds('Shock')
    local base=f.addon.Platform.GetSpellInfo;local selected,failed=1,false
    f.addon.Platform.GetSpellInfo=function(self,id) if id=='Shock' then counts.info=counts.info+1;if failed then return nil,'restricted-value' end;return m[selected] end;return base(self,id) end
    local before=counts.info;assert(c:GetSpellId(1)==1);assert(counts.info==before+2,'canonical name/numeric refresh skipped')
    selected=2;assert(c:GetSpellId(1)==2)
    failed=true;local value,why=c:GetSpellId(1);assert(value==nil and why=='restricted-value')
    failed=false;m[4]={name='Shock',subtext='Rank 4',spellID=4};selected=4;assert(c:GetSpellId(1)==4);assert(c:GetAllSpellIds('Shock')[1]==4)
    assert(f.addon.specSpells==nil,'metadata became learned state')
end)
test('reentrant link metadata updates cannot leave their intermediate ordered group cached',function()
    local _,c,m,_,hooks=countedCatalog();c:UpdateSpell(1);c:UpdateSpell(2);c:GetAllSpellIds('Shock')
    local armed=true
    hooks(nil,function(id)if id==1 and armed then armed=false;m[1].subtext='Rank 3';c:UpdateSpell(1);assert(c:GetAllSpellIds('Shock')[1]==1);m[1].subtext='Rank 1' end end)
    c:UpdateSpell(1);assert(table.concat(c:GetAllSpellIds('Shock'),',')=='2,1','outer metadata publication reused nested ordering')
end)
test('reentrant sort updates cannot publish stale groups or expose private ordered storage',function()
    local _,c,m,_,hooks=countedCatalog();c:UpdateSpell(1);c:UpdateSpell(2)
    local armed=true;local captured
    hooks(function(values)captured=values;if armed then armed=false;m[4]={name='Shock',subtext='Rank 4',spellID=4};c:UpdateSpell(4) end end)
    local old=c:GetAllSpellIds('Shock');assert(table.concat(old,',')=='2,1')
    local current=c:GetAllSpellIds('Shock');assert(table.concat(current,',')=='4,2,1');captured[1]=999;current[2]=888
    assert(table.concat(c:GetAllSpellIds('Shock'),',')=='4,2,1','sort/caller storage escaped into private cache')
end)
test('unknown and failed IDs retry metadata without caching absence',function()
    local _,c,m,counts=countedCatalog();assert(c:GetAllSpellIds(99)==nil);assert(c:GetAllSpellIds(99)==nil);assert(counts.info==2 and counts.sort==0)
    m[99]={name='Arrival',subtext='Rank 1',spellID=99};assert(c:GetAllSpellIds(99)[1]==99);local ids=c:GetAllSpellIds('Arrival');ids[1]=1;assert(c:GetAllSpellIds(99)[1]==99)
end)
test('name removal invalidates before link callback reads or errors without repairing partial publication',function()
    local _,c,m,_,hooks=countedCatalog();c:UpdateSpell(1);c:UpdateSpell(2);c:GetAllSpellIds('Shock')
    m[1].name='Moved';local observed
    hooks(nil,function(id)if id==1 then observed=c:GetAllSpellIds('Shock');error('link-marker') end end)
    local ok,why=pcall(c.UpdateSpell,c,1);assert(not ok and tostring(why):find('link-marker',1,true))
    assert(table.concat(observed,',')=='2','old group remained cached during callback')
    assert(table.concat(c:GetAllSpellIds(1),',')=='2','partial baseline membership was repaired or hidden')
    assert(c:GetAllSpellIds('Moved')==nil)
end)
test('later rank changes invalidate historical groups retained by reentrant name publication',function()
    local _,c,m,counts,hooks=countedCatalog()
    m[1]={name='Old',subtext='Rank 1',spellID=1}
    m[2]={name='Intermediate',subtext='Rank 5',spellID=2}
    c:UpdateSpell(1);c:UpdateSpell(2);c:UpdateSpell(3)
    c:GetAllSpellIds('Other')
    local armed=true
    hooks(nil,function(id)
        if id==1 and armed then
            armed=false;m[1]={name='Intermediate',subtext='Rank 7',spellID=1}
            c:UpdateSpell(1);assert(table.concat(c:GetAllSpellIds('Intermediate'),',')=='1,2')
            m[1]={name='Final',subtext='Rank 1',spellID=1}
        end
    end)
    m[1]={name='Final',subtext='Rank 1',spellID=1};c:UpdateSpell(1)
    assert(table.concat(c:GetAllSpellIds('Intermediate'),',')=='2,1')
    assert(table.concat(c:GetAllSpellIds('Old'),',')=='')
    local sorted,info,links=counts.sort,counts.info,counts.link
    m[1]={name='Final',subtext='Rank 9',spellID=1};c:UpdateSpell(1)
    assert(table.concat(c:GetAllSpellIds('Intermediate'),',')=='1,2',
        'historical group retained stale order after current-name rank refresh')
    assert(counts.sort==sorted+1,'historical group did not rebuild exactly once')
    c:GetAllSpellIds('Other');c:GetAllSpellIds('Old');c:GetAllSpellIds('Intermediate')
    assert(counts.sort==sorted+1,'rank update invalidated an unrelated or removed group')
    assert(counts.info==info+1 and counts.link==links+1,'native metadata observations changed')
end)
finish()
