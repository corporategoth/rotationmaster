local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon
    dofile('tests/fixtures/spell_editbox.lua')(f)
    f.env.BOOKTYPE_SPELL='spell'
    f.env.C_Spell={GetSpellInfo=function(id)
        if id=='Shoot' then id=5019 end
        if id==5019 or id==5020 then return {name='Shoot',spellID=id,iconID=1,subtext=id==5019 and 'Rank 1' or 'Rank 2'} end
    end,GetSpellLink=function(id) return '|Hspell:'..id..'|h[Shoot]|h' end}
    f.load('Platform/spells.lua');f.load('Core/conditions.lua');f.load('Conditions/common.lua');f.load('Conditions/spell.lua')
    return f,a
end
local function node(extra)
    local n={type='SPELL_AUTOREPEAT',spell=5019,ranked=true}
    for k,v in pairs(extra or {}) do n[k]=v end;return n
end
test('auto-repeat condition distinguishes active repetition from current or queued spells',function()
    local f,a=fixture();local active=false
    f.env.C_Spell.IsAutoRepeatSpell=function(id) assert(id==5019);return active end
    f.env.C_Spell.IsCurrentSpell=function() return true end
    assert(a:validateCondition(node(),0),'auto-repeat condition missing or invalid')
    assert(a:evaluateConditionResult(node()).status=='no-match')
    assert(a:evaluateCondition({type='NOT',value=node()}))
    active=true;assert(a:evaluateCondition(node()))
end)
test('rank resolution and cache share the native observation only within one evaluation',function()
    local f,a=fixture();local calls,observed=0,{}
    f.env.C_Spell.IsAutoRepeatSpell=function(id) calls=calls+1;observed[#observed+1]=id;return true end
    assert(a:evaluateCondition({type='AND',value={node(),node()}}) and calls==1,'one pass did not share its observation')
    assert(a:evaluateCondition(node()) and calls==2,'new evaluation reused stale state')
    f.env.C_Spell.GetSpellInfo=function(id) if id=='Shoot' then id=5020 end;return {name='Shoot',spellID=id,iconID=1} end
    assert(a:evaluateCondition(node({ranked=false})) and observed[3]==5020,'non-exact selection bypassed the rank resolver')
    assert(a:evaluateCondition(node()) and observed[4]==5019,'exact rank changed identity')
end)
test('unavailable auto-repeat observations survive NOT and prevent either branch being selected',function()
    local f,a=fixture()
    for _,path in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua'}) do f.load(path) end
    local opaque={};f.env.canaccessvalue=function(v) return v~=opaque end
    for _,case in ipairs({{'missing-api',nil},{'restricted-value',function() return opaque end},{'api-error',function() error('unavailable') end},{'invalid-api-result',function() return nil end}}) do
        f.env.C_Spell.IsAutoRepeatSpell=case[2]
        local result=a:evaluateConditionResult({type='NOT',value=node()})
        assert(result.status=='unavailable' and result.reason==case[1],case[1]..' became a Boolean')
        local visited=0
        local body={rotation={{id='b',type='branch',conditions=node(),onTrue={{id='yes',type='spell',action=5019}},onFalse={{id='no',type='spell',action=5019}}}}}
        local sequence=a:EvaluateRotationSequence(body,function(v) return a:evaluateConditionResult(v) end,function() visited=visited+1 end)
        assert(sequence.status=='unavailable' and sequence.suppressAttack and visited==0,'unavailable guard entered an arm')
    end
end)
test('auto-repeat field validation rejects incomplete identifiers before observing the client',function()
    local f,a=fixture();f.env.C_Spell.IsAutoRepeatSpell=function() error('invalid fields queried the client') end
    for _,id in ipairs({0,-1,1.5,'5019',{},math.huge}) do assert(not a:validateCondition(node({spell=id}),0)) end
    assert(not a:validateCondition({type='SPELL_AUTOREPEAT'},0))
    assert(not a:validateCondition(node({ranked='yes'}),0))
end)
test('auto-repeat uses the shared native spell and exact-rank fields',function()
    local f,a=fixture();local value=node();local top,parent=f.widget('top'),f.widget('parent')
    top:SetUserData('root',value);top:SetUserData('funcs',{print=function() return 'Updated auto-repeat' end});parent:SetUserData('top',top)
    local d=assert(a.conditionDefinitions.SPELL_AUTOREPEAT,'missing auto-repeat declaration');d.widget(parent,0,value)
    local group=parent.children[1];assert(group.layout=='RM-SpellField' and #group.children==3)
    group.children[3]:Fire('OnValueChanged',false)
    assert(value.ranked==false and top.statusText=='Updated auto-repeat')
end)
test('auto-repeat summary supports readable negation and its help includes picker and state guidance',function()
    local f,a=fixture();local d=assert(a.conditionDefinitions.SPELL_AUTOREPEAT,'missing auto-repeat declaration')
    local positive=a:printCondition(node(),0);local negative=a:printCondition({type='NOT',value=node()},0)
    assert(positive:find('is auto%-repeating') and negative:find('is not auto%-repeating'),'auto-repeat summary is not naturally negated')
    local help=f.widget('Help');d.help(help);local text=F.text(help)
    assert(text:find('drag',1,true) and text:find('rank',1,true) and text:find('queued',1,true),'auto-repeat help omits shared picker or state distinction')
end)
finish()
