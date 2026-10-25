-- Retail TALENT: the talent picker and the evaluation, driven with a Retail class
-- tree modeled on Blizzard's generated API documentation and talent window
-- (tests/fixtures/retail_traits.lua). No real client was available: this proves
-- the addon against that model, not against the game.
local F=dofile('tests/fixtures/addon.lua')
local Tree=dofile('tests/fixtures/retail_traits.lua')
local test,finish=F.suite()

local function client(state,options)
    options=options or {}
    local f=F.new(1,12,'MAGE');local e=f.env
    local frames={}
    local native=e.CreateFrame
    e.CreateFrame=function(...)
        local frame=native(...);frame.events={};frames[#frames+1]=frame
        local setScript=frame.SetScript
        function frame:SetScript(kind,fn) if kind=='OnEvent' then self.onEvent=fn end;if setScript then return setScript(self,kind,fn) end end
        function frame:RegisterEvent(event) self.events[event]=true end
        function frame:RegisterUnitEvent(event) self.events[event]=true end
        return frame
    end
    local model=Tree.install(e,state)
    for _,path in ipairs({'Platform/spells.lua','Platform/talents.lua','Core/build_context.lua','Core/conditions.lua',
        'Conditions/common.lua','Conditions/character.lua','Conditions/talent.lua'}) do f.load(path) end
    f.addon.definitions=f.addon.conditionDefinitions or f.addon.definitions
    local function fire(event,...) for _,frame in ipairs(frames) do if frame.events[event] and frame.onEvent then frame.onEvent(frame,event,...) end end end
    return f,f.addon,e,fire,model
end
local function status(a,value,negated)
    local result=a:evaluateConditionResult(negated and {type='NOT',value=value} or value)
    return result.status,result.reason
end
local function talent(node,operator,rank,entry,spell)
    return {type='TALENT',layout='traits',node=node,entry=entry,spell=spell,operator=operator,value=rank}
end
local function names(group) local out={};for index,t in ipairs(group.talents) do out[index]=t.name end;return out end
local function has(list,name) for _,v in ipairs(list) do if v==name then return true end end return false end
local function groupNamed(groups,name) for _,g in ipairs(groups) do if g.name==name then return g end end end
local function child(parent,label)
    for _,w in ipairs(parent.children) do if (w.caption and w.caption:GetText() or w.label)==label then return w end end
end
local function editor(f,value,spec)
    local parent,top=f.widget('parent'),f.widget('top')
    top:SetUserData('root',value);top:SetUserData('funcs',{print=function() return 'Updated condition' end})
    parent:SetUserData('top',top)
    f.addon.definitions.TALENT.widget(parent,spec or 0,value)
    return parent,top
end
local ARCANE,FIRE,FROST=Tree.SPECS.Arcane,Tree.SPECS.Fire,Tree.SPECS.Frost

test('the played specialization lists its class and specialization talents and only its own hero trees, by name with icon',function()
    local f,a=client({spec=FIRE});local p=a.Platform
    local groups,meta=p:GetTraitTalents();assert(groups,tostring(meta));assert(meta.source=='active')
    assert(#groups==3 and groups[1].name==nil and groups[2].name=='Frostfire' and groups[3].name=='Sunfury',#groups)
    local main=names(groups[1])
    for _,wanted in ipairs({'Arcane Intellect','Blink','Shimmer','Ice Block','Pyroblast','Combustion','Phoenix Flames','Kindling',"Alexstrasza's Fury"}) do
        assert(has(main,wanted),'missing '..wanted)
    end
    for _,other in ipairs({'Arcane Surge','Arcane Missiles','Frozen Orb','Glacial Spike'}) do assert(not has(main,other),'another specialization listed: '..other) end
    for _,group in ipairs(groups) do for _,t in ipairs(group.talents) do
        assert(t.name and t.icon and t.spellID and t.node,'a talent lacks name, icon, spell or node') end end
    assert(groupNamed(groups,'Spellslinger')==nil,'a hero tree this specialization cannot choose was listed')
    assert(has(names(groups[2]),'Frostfire Bolt') and has(names(groups[3]),'Sunfury Execution'))
    assert(meta.hero and #meta.hero==2)
end)

test('choice nodes list each entry, tiered nodes list one talent, and the hero selection node is not a talent',function()
    local f,a=client({spec=FIRE});local groups=a.Platform:GetTraitTalents()
    local shimmer,blink,tier,kindling
    for _,t in ipairs(groups[1].talents) do
        if t.name=='Shimmer' then shimmer=t elseif t.name=='Blink' then blink=t elseif t.name:find('Improved Frost Nova',1,true) then tier=t elseif t.name=='Kindling' then kindling=t end
    end
    assert(shimmer and blink and shimmer.node==2002 and blink.node==2002 and shimmer.entry and blink.entry and shimmer.entry~=blink.entry)
    assert(kindling and kindling.node==2204 and kindling.entry)
    assert(tier and tier.node==2004 and tier.entry==nil,'a tiered node became a choice')
    local count=0;for _,t in ipairs(groups[1].talents) do if t.node==2004 then count=count+1 end end
    assert(count==1,'tiered node listed '..count..' times')
    for _,group in ipairs(groups) do for _,t in ipairs(group.talents) do assert(t.node~=2400,'hero selection node listed') end end
end)

test('hero talents of subtrees the specialization cannot choose are dropped even when the client reports them visible',function()
    local f,a=client({spec=FIRE,leakHero=true});local groups=a.Platform:GetTraitTalents()
    assert(groupNamed(groups,'Spellslinger')==nil and groupNamed(groups,'Frostfire') and groupNamed(groups,'Sunfury'))
    -- Without the client's answer the visible nodes are all there is to go on.
    f,a=client({spec=FIRE,leakHero=true});f.env.C_ClassTalents.GetHeroTalentSpecsForClassSpec=function() error('unavailable') end
    assert(groupNamed(a.Platform:GetTraitTalents(),'Spellslinger'),'no fallback without the hero list')
end)

test('another specialization is read from the view loadout, never in combat, and the played one never touches it',function()
    local state={spec=FIRE};local f,a,e=client(state);local p=a.Platform
    local groups,meta=p:GetTraitTalents(FROST);assert(groups,tostring(meta))
    assert(meta.source=='view' and state.viewSpec==FROST and state.viewLevel>=80 and state.calls.InitializeViewLoadout==1)
    local main=names(groups[1])
    assert(has(main,'Frozen Orb') and has(main,'Glacial Spike') and has(main,'Blink') and not has(main,'Pyroblast') and not has(main,'Arcane Surge'))
    assert(groupNamed(groups,'Frostfire') and groupNamed(groups,'Spellslinger') and not groupNamed(groups,'Sunfury'))
    p:GetTraitTalents(FIRE);assert(state.calls.InitializeViewLoadout==1,'the played specialization used the view loadout')
    p:GetTraitTalents();assert(state.calls.InitializeViewLoadout==1)
    state.combat=true
    local value,why=p:GetTraitTalents(ARCANE);assert(value==nil and why=='in-combat' and state.calls.InitializeViewLoadout==1,tostring(why))
    assert(p:GetTraitTalents(),'the played specialization is listable in combat')
    state.combat=false
    for _,bad in ipairs({0,-1,1.5}) do assert(p:GetTraitTalents(bad)~=nil,'an invalid specialization should fall back to the played one') end
    e.C_ClassTalents.GetTraitTreeForSpec=function() return nil end
    value,why=p:GetTraitTalents(ARCANE);assert(value==nil and why=='talent-tree-unavailable',tostring(why))
    e.C_ClassTalents.GetTraitTreeForSpec=function() error('gone') end
    value,why=p:GetTraitTalents(ARCANE);assert(value==nil and why=='api-error',tostring(why))
    e.C_ClassTalents.InitializeViewLoadout=nil;e.C_ClassTalents.GetTraitTreeForSpec=function() return Tree.TREE end
    value,why=p:GetTraitTalents(ARCANE);assert(value==nil and why=='missing-api',tostring(why))
end)

test('an unreadable or failing talent API is a reason, never an empty list or a guess',function()
    local state={spec=FIRE};local f,a,e=client(state);local p=a.Platform
    local opaque={}
    e.canaccessvalue=function(v) return v~=opaque end
    local nodes=e.C_Traits.GetTreeNodes
    e.C_Traits.GetTreeNodes=function(...) return opaque end
    local value,why=p:GetTraitTalents();assert(value==nil and why=='restricted-value',tostring(why))
    e.C_Traits.GetTreeNodes=nodes
    state.errors={GetNodeInfo=true};value,why=p:GetTraitTalents();assert(value==nil and why=='api-error','failing node reads should be a reason: '..tostring(why))
    state.errors=nil;state.noConfig=true
    value,why=p:GetTraitTalents();assert(value==nil and why=='talent-config-unavailable',tostring(why))
    state.noConfig=false;e.C_Traits.GetDefinitionInfo=function() return {spellID=opaque} end
    value,why=p:GetTraitTalents();assert(value==nil and why=='restricted-value','secret spell IDs must not be listed: '..tostring(why))
end)

test('TALENT compares ranks for the played specialization: purchased, granted, choice entry, tiers and hero trees',function()
    local state={spec=FIRE};local f,a,e,fire=client(state)
    assert(status(a,talent(2201,'EQUALS',1))=='match','a granted talent has rank one')
    assert(status(a,talent(2203,'EQUALS',2))=='match' and status(a,talent(2203,'EQUALS',1))=='no-match')
    assert(status(a,talent(2202,'GREATERTHANOREQUALS',1))=='match')
    local entry2002,entry2204=Tree.entryID({id=2002},2),Tree.entryID({id=2204},2)
    assert(status(a,talent(2002,'GREATERTHANOREQUALS',1,entry2002))=='match','chosen choice entry')
    assert(status(a,talent(2002,'GREATERTHANOREQUALS',1,Tree.entryID({id=2002},1)))=='no-match','unchosen choice entry')
    assert(status(a,talent(2204,'EQUALS',1,entry2204))=='match')
    assert(status(a,talent(2411,'EQUALS',1))=='match','the chosen hero tree')
    assert(status(a,talent(2431,'EQUALS',1))=='no-match' and status(a,talent(2431,'EQUALS',0))=='match','an unchosen hero tree has rank zero')
    -- Talents of the other specializations are real talents the character does not have.
    assert(status(a,talent(2301,'EQUALS',0))=='match' and status(a,talent(2301,'GREATERTHAN',0))=='no-match')
    assert(status(a,talent(2301,'GREATERTHAN',0),true)=='match','NOT of another specialization\'s talent')
    local st,why=status(a,talent(999999,'GREATERTHAN',0),true);assert(st=='unavailable' and why=='talent-node-unavailable',tostring(why))
end)

test('evaluation reads each node once per talent change, in and out of combat, and keeps secrets unavailable',function()
    local state={spec=FIRE};local f,a,e,fire=client(state)
    local value=talent(2202,'GREATERTHANOREQUALS',1)
    assert(status(a,value)=='match');local reads=state.calls.GetNodeInfo
    for _=1,50 do status(a,value) end
    assert(state.calls.GetNodeInfo==reads,'node re-read without a talent change')
    state.purchased[2202]=nil;fire('TRAIT_CONFIG_UPDATED',Tree.ACTIVE);assert(status(a,value)=='no-match')
    state.purchased[2202]=1;fire('PLAYER_TALENT_UPDATE');assert(status(a,value)=='match')
    state.spec=FROST;state.purchased={[2301]=1};fire('PLAYER_SPECIALIZATION_CHANGED','player')
    assert(status(a,talent(2301,'EQUALS',1))=='match' and status(a,value)=='no-match','spec change not followed')
    local opaque={};e.canaccessvalue=function(v) return v~=opaque end
    state.purchased={[2301]={rank=opaque,entry=1}};fire('TRAIT_CONFIG_UPDATED',Tree.ACTIVE)
    local st,why=status(a,talent(2301,'GREATERTHAN',0),true);assert(st=='unavailable' and why=='restricted-value',tostring(why))
end)

test('a saved spell finds the talent again when the node ID is no longer its own',function()
    local state={spec=FIRE};local f,a,e,fire=client(state)
    local COMBUSTION,KINDLING=190319,155148
    -- Node IDs renumbered: the saved ones are gone or hold something else.
    assert(status(a,talent(777777,'EQUALS',1,nil,COMBUSTION))=='match','missing node')
    assert(status(a,talent(2203,'EQUALS',1,nil,COMBUSTION))=='match','node now holds another talent')
    assert(status(a,talent(2301,'EQUALS',0,nil,COMBUSTION))=='no-match','the moved talent is read, not the old node (rank 1, not 0)')
    assert(status(a,talent(2204,'EQUALS',1,424242,KINDLING))=='match','renumbered choice entry')
    local st,why=status(a,talent(777777,'GREATERTHAN',0,nil,999),true);assert(st=='unavailable' and why=='talent-node-unavailable',tostring(why))
    -- A reference that still holds does not build the index.
    local before=state.calls.GetTreeNodes or 0
    assert(status(a,talent(2202,'EQUALS',1,nil,COMBUSTION))=='match' and (state.calls.GetTreeNodes or 0)==before,'index built for a valid reference')
    -- The index is rebuilt after a talent change.
    state.purchased[2202]=nil;fire('TRAIT_CONFIG_UPDATED');assert(status(a,talent(777777,'EQUALS',0,nil,COMBUSTION))=='match')
    -- Reading failures are reasons, not a search.
    state.errors={GetNodeInfo=true};fire('TRAIT_CONFIG_UPDATED')
    st,why=status(a,talent(2202,'EQUALS',1,nil,COMBUSTION),true);assert(st=='unavailable' and why=='api-error',tostring(why))
end)

test('stored references: old node/entry values stay valid and evaluate as before; a spell is optional and checked',function()
    local state={spec=FIRE};local f,a=client(state);local d=a.definitions.TALENT
    local old={type='TALENT',layout='traits',node=2202,operator='GREATERTHANOREQUALS',value=1}
    local choice={type='TALENT',layout='traits',node=2002,entry=Tree.entryID({id=2002},2),operator='EQUALS',value=1}
    assert(d.valid(0,old) and d.valid(0,choice))
    assert(a:evaluateCondition(old) and a:evaluateCondition(choice))
    local withSpell={layout='traits',node=2202,spell=190319,operator='EQUALS',value=1};assert(d.valid(0,withSpell))
    for _,bad in ipairs({{spell=0},{spell=1.5},{spell='x'},{spell=2^40}}) do
        local v={layout='traits',node=2202,operator='EQUALS',value=1};for k,x in pairs(bad) do v[k]=x end
        assert(not d.valid(0,v),'accepted a malformed spell')
    end
        assert(d.fields.spell=='number')
    local text=d.print(0,withSpell);assert(text:find('Combustion',1,true),text)
    -- A node gone from the tree is still named by its spell.
    text=d.print(0,{layout='traits',node=777777,spell=190319,operator='EQUALS',value=1});assert(text:find('Combustion',1,true),text)
    text=d.print(0,{layout='traits',node=777777,operator='EQUALS',value=1});assert(text:find('777777',1,true),text)
end)

test('editing a rotation for another specialization shows that specialization\'s talents with icons, and the played one\'s on request',function()
    local state={spec=FIRE};local f,a,e=client(state)
    local value={};local parent,top=editor(f,value,FROST)
    assert(state.viewSpec==FROST,'the rotation\'s specialization was not loaded')
    local specs=assert(child(parent,'Specialization'));specs.configure()
    assert(specs.value==FROST and #specs.order==3 and specs.list[FIRE].text=='Fire' and specs.list[FIRE].icon,'specialization list')
    local trees=assert(child(parent,'Talent Tree'));trees.configure()
    assert(trees.value==1 and trees.list[1]=='Talents' and trees.list[2]=='Frostfire' and trees.list[3]=='Spellslinger',tostring(trees.list[3]))
    local picker=assert(child(parent,'Talent'));picker.configure();assert(not picker.disabled,'the talent list starts disabled')
    local frostOrb
    for index,entry in ipairs(picker.list) do assert(entry.text and entry.icon,'list entry without icon') if entry.text=='Frozen Orb' then frostOrb=index end end
    assert(frostOrb and #picker.order==#picker.list)
    picker:Fire('OnValueChanged',frostOrb)
    assert(value.layout=='traits' and value.node==2301 and value.entry==nil and value.spell==84714 and value.tree==nil and value.talent==nil)
    assert(value.operator=='GREATERTHANOREQUALS' and value.value==1 and a.definitions.TALENT.valid(0,value) and top.statusText=='Updated condition')
    -- The default comparison is shown, not only stored.
    local operator,rank=parent.children[#parent.children].children[1],parent.children[#parent.children].children[2]
    operator.configure();assert(operator.value=='GREATERTHANOREQUALS' and tostring(rank.text)=='1','defaults picked for the talent are not displayed: '..tostring(operator.value)..' '..tostring(rank.text))
    -- Switching to the played specialization reloads the list.
    specs:Fire('OnValueChanged',FIRE);picker.configure()
    local combustion;for index,entry in ipairs(picker.list) do if entry.text=='Combustion' then combustion=index end end
    assert(combustion and picker.value==nil)
    assert(value.node==2301,'viewing another list changed the saved talent')
    -- A hero talent is reached through its tree; a choice is written with its entry.
    trees:Fire('OnValueChanged',1);picker.configure()
    local kindling;for index,entry in ipairs(picker.list) do if entry.text:find('Kindling',1,true) then kindling=index end end
    picker:Fire('OnValueChanged',kindling);assert(value.node==2204 and value.entry and value.spell==155148)
    trees:Fire('OnValueChanged',2);picker.configure();assert(picker.list[1].text=='Frostfire Bolt')
    picker:Fire('OnValueChanged',1);assert(value.node==2411 and value.spell==431044 and value.entry==nil)
    -- A hand-typed node no longer goes with the spell of the picked talent.
    local nodeBox=assert(child(parent,'Talent Node ID'));nodeBox:Fire('OnEnterPressed','2202');assert(value.node==2202 and value.spell==nil)
    local entryBox=assert(child(parent,'Choice Entry ID'));entryBox:Fire('OnEnterPressed','77');assert(value.entry==77 and value.spell==nil)
end)

test('reopening a saved talent selects it; a talent of another specialization still opens, named, and the list follows the rotation',function()
    local state={spec=FIRE};local f,a=client(state)
    local value={layout='traits',node=2203,spell=257541,operator='EQUALS',value=2}
    local parent=editor(f,value,FIRE);local trees,picker=child(parent,'Talent Tree'),child(parent,'Talent')
    trees.configure();picker.configure();assert(trees.value==1 and picker.list[picker.value].text=='Phoenix Flames')
    parent=editor(f,{layout='traits',node=2301,spell=84714,operator='EQUALS',value=1},FIRE)
    picker=child(parent,'Talent');picker.configure();assert(picker.value==nil and #picker.order>0,'a talent of another specialization broke the list')
    assert(picker.disabled==false)
    parent=editor(f,{layout='traits',node=2301,spell=84714,operator='EQUALS',value=1},FROST)
    picker=child(parent,'Talent');picker.configure();assert(picker.list[picker.value].text=='Frozen Orb')
    assert(a.definitions.TALENT.print(FIRE,{layout='traits',node=2301,spell=84714,operator='EQUALS',value=1}):find('Frozen Orb',1,true))
end)

test('the picker says why another specialization cannot be listed and keeps node IDs usable',function()
    local state={spec=FIRE,combat=true};local f,a=client(state)
    local value={};local parent=editor(f,value,FROST)
    assert(F.text(parent):find('during combat',1,true),F.text(parent))
    local picker=child(parent,'Talent');picker.configure();assert(picker.disabled==true)
    local nodeBox=assert(child(parent,'Talent Node ID'));nodeBox:Fire('OnEnterPressed','2301')
    assert(value.node==2301 and a.definitions.TALENT.valid(0,value))
    state.combat=false;f=client({spec=FIRE,errors={GetTreeNodes=true}})
    parent=editor(f,{},FIRE);assert(F.text(parent):find('cannot be listed right now',1,true))
end)

test('Forever and the classic clients keep their pickers: one tree per class, no specialization list',function()
    local f=F.new(18,12,'MAGE');local e=f.env
    Tree.install(e,{spec=FIRE})
    for _,path in ipairs({'Platform/spells.lua','Platform/talents.lua','Core/build_context.lua','Core/conditions.lua','Conditions/common.lua','Conditions/character.lua','Conditions/talent.lua'}) do f.load(path) end
    f.addon.definitions=f.addon.conditionDefinitions or f.addon.definitions
    local groups,meta=f.addon.Platform:GetTraitTalents(FROST);assert(groups and meta.source=='active' and f.env.C_ClassTalents.InitializeViewLoadout and true,'Forever has one tree per class')
    local parent=editor(f,{},FROST);assert(child(parent,'Specialization')==nil)
end)

finish()
