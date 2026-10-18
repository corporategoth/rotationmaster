local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local f=F.new()
for _, name in ipairs({'buffs','anyspell','combat','misc','character','stats'}) do
    f.load('Conditions/'..name..'.lua')
end
local d=f.addon.definitions
for _, tag in ipairs({'BUFF','BUFF_REMAIN','BUFF_STACKS','ANYSPELL_COOLDOWN','ANYSPELL_REMAIN','ANYSPELL_CHARGES'}) do
    test(tag..' help renders own-buff/rank fields', function()
        local frame=f.widget('Frame'); d[tag].help(frame)
        assert(#frame.children>0)
        assert(#F.text(frame)>30)
    end)
end
test('threat count uses enemy record threat, not a nested addon', function()
    f.addon.unitsInRange={
        {enemy=true,threat=0}, {enemy=true,threat=2}, {enemy=false,threat=3}, {enemy=true},
    }
    assert(d.THREAT_COUNT.evaluate({operator='EQUALS',threat=3,value=1}))
    assert(not d.THREAT_COUNT.evaluate({operator='EQUALS',threat=3,value=2}))
end)
test('instance none matches outside and does not match dungeon', function()
    f.env.IsInInstance=function() return false,'none' end
    assert(d.INSTANCE.evaluate({value='none'},nil))
    assert(not d.INSTANCE.evaluate({value='party'},nil))
    f.env.IsInInstance=function() return true,'party' end
    assert(d.INSTANCE.evaluate({value='party'},nil))
    assert(not d.INSTANCE.evaluate({value='none'},nil))
end)
for _, tag in ipairs({'MOVING','PET','OUTDOORS','INCONTROL','STEALTHED'}) do
    test(tag..' has useful parameterless help', function()
        assert(type(d[tag].help)=='function', 'missing help')
        local frame=f.widget('Frame');d[tag].help(frame);assert(#F.text(frame)>30)
    end)
end
test('time in combat reports seconds and elapsed comparisons', function()
    local c=d.TIME_IN_COMBAT
    f.addon.combatStart=95
    assert(c.evaluate({operator='EQUALS',value=5},{},100))
    assert(not c.evaluate({operator='LESSTHAN',value=5},{},100))
    f.addon.combatStart=nil
    assert(not c.evaluate({operator='GREATERTHAN',value=0},{},100))
    local frame=f.widget('Frame');c.help(frame)
    assert(not F.text(frame):find('Unit',1,true),'time condition has no unit parameter')
    assert(f.translations['Time Since Combat Start'],'description is untranslated')
    assert(f.translations['Time in combat is %s %s seconds'],'summary is untranslated')
end)
test('condition summaries do not expose accidental addon member tokens', function()
    for _, pair in ipairs({{'THREAT',{unit='target',threat=2}}, {'POINT',{unit='player',operator='EQUALS',value=3}}}) do
        local text=d[pair[1]].print(0,pair[2]);assert(not text:find('addon%.'))
    end
end)
finish()
