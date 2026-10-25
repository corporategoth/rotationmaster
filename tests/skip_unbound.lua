-- Steps and cooldowns whose action is on no action bar are skipped: RM can
-- only advise by lighting the button that holds an action, so the engine
-- moves on to the next step (main.lua: "the first mapped and ready spell"),
-- and the rotation editor warns on the card (buttons.lua GetStepBinding,
-- UI/rotation_cards.lua). Classic (TBC whole-poll fixture, probe policy),
-- Retail 12 bars, and the restricted Retail client; both engines.
local pass,fail=0,0
local function test(name,fn)local ok,err=pcall(fn);if ok then pass=pass+1;print('PASS '..name)else fail=fail+1;print('FAIL '..name..': '..tostring(err))end end
local root=assert(io.popen('pwd'):read('*l'))

local function whole(engine,options)
    local build=assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('trace',root,true,root,true)
    options=options or {};options.buttons=true;options.target=true;options.poll=.15
    local c=build(options)
    c.a.db.profile.idle_poll=0;assert(c.a:SetEvaluationEngine(engine or 'standard'))
    c.a.print=function() end;c.a.ShowConditionText=function(_,text) c.shown=text end
    c.load('Diagnostics/glow.lua')
    for _=1,4 do c.tick() end
    return c
end
local function custom(a,id,body)
    local reference={kind='custom',address={scope='class',class='SHAMAN',owner='SHAMAN',spec=0,id=id}}
    assert(a:CommitRotationDraft(reference,nil,{body=body},'class'))
end
local function select(c,name) c.a:HandleCommand('set '..name);if c.a.AssistedHighlight then c.a.AssistedHighlight:OnEvent('ROTATIONMASTER_ROTATION') end;for _=1,6 do c.tick() end end
local function spell(id,action,extra) local step={id=id,type='spell',action=action,conditions={}};for k,v in pairs(extra or {}) do step[k]=v end;return step end
-- The Classic fixture's bars: four buttons, slots 1-4 (rebindable here).
local function classicBars(c,ids) c.e.HasAction=function(slot) return ids[slot]~=nil end;c.e.GetActionInfo=function(slot) if ids[slot] then return 'spell',ids[slot] end end;c.a:Fetch();for _=1,3 do c.tick() end end
local LB,FS,LS,ST,CL=403,8042,324,8017,421  -- Lightning Bolt, Earth Shock, Lightning Shield, Rockbiter; Chain Lightning on no bar

-- Retail 12 bars on the same engine (as tests/retail_glow.lua models them).
local BLACKOUT_KICK,TIGER_PALM,KEG=100784,100780,121253
local function retailBars(c,layout)
    local e=c.e
    e.HasAction,e.IsUsableAction,e.GetActionCooldown,e.IsActionInRange=nil,nil,nil,nil
    e.BOOKTYPE_SPELL,e.BOOKTYPE_PET=nil,nil
    e.C_ActionBar={HasAction=function(slot) return layout[slot]~=nil end,
        FindSpellActionButtons=function(id) local slots={};for slot,v in pairs(layout) do if v==id then slots[#slots+1]=slot end end;table.sort(slots);return slots end}
    e.GetActionInfo=function(slot) local id=layout[slot];if id then return 'spell',id end end
    local frames={}
    for i=1,12 do
        local name='ActionButton'..i
        local container=e.CreateFrame('Frame','ActionButtonContainer'..i,e.UIParent)
        local button=e.CreateFrame('CheckButton',name,container);button:SetSize(45,45)
        local attributes={type='action'}
        button.GetAttribute=function(_,key) return attributes[key] end
        button.GetName=function() return name end
        button.action=i;button.GetPagedID=function(self) return self.action end
        e[name]=button;frames[name]=button
    end
    c.a:Fetch()
    return frames
end
local function lit(button) local overlay=type(button.rmOverlays)=='table' and button.rmOverlays.next;return overlay and overlay:IsShown()==true or false end
local function retail(engine,layout,state)
    local c=whole(engine)
    state=state or {};state.cvars=state.cvars or {assistedCombatHighlight='0'}
    local e,a=c.e,c.a
    e.C_AssistedCombat={IsAvailable=function() return true,'' end,GetNextCastSpell=function() return state.next end,
        GetRotationSpells=function() return state.rotation or {BLACKOUT_KICK,TIGER_PALM,KEG} end,GetActionSpell=function() return nil end}
    e.AssistedCombatManager={}
    e.C_CVar={GetCVar=function(name) return state.cvars[name] end,SetCVar=function(name,value) state.cvars[name]=tostring(value)
        if a.AssistedHighlight then a.AssistedHighlight:OnEvent('CVAR_UPDATE',name,tostring(value)) end end}
    e.InCombatLockdown=function() return false end
    c.load('Platform/assisted_combat.lua');c.load('Conditions/assisted.lua');c.load('Core/assisted_highlight.lua')
    a.db.char=a.db.char or {}
    a.AssistedHighlight:OnEvent('PLAYER_ENTERING_WORLD')
    c.frames=retailBars(c,layout or {[1]=BLACKOUT_KICK,[2]=TIGER_PALM})
    return c,state
end
local function litNames(c)
    local names={}
    for name,button in pairs(c.frames) do if lit(button) then names[#names+1]=name end end
    table.sort(names);return table.concat(names,',')
end

-- Engine -------------------------------------------------------------------------
for _,engine in ipairs({'standard','lean'}) do
    test('classic ('..engine..'): an unbound top step is skipped and the next bound step is advised',function()
        local c=whole(engine)
        assert(c.a.Platform:GetClientInfo().family=='tbc' and c.a.Platform:GetClientInfo().combatDataPolicy=='probe')
        custom(c.a,'u',{name='U',priority=0,cooldowns={},rotation={spell('cl',CL),spell('ls',LS)}})
        select(c,'U')
        assert(c.a.currentSpell==LS,'advised '..tostring(c.a.currentSpell))
        assert(c.a:GetEvaluationEngine()==engine,'engine '..c.a:GetEvaluationEngine())
        assert(c.a:GetStepBinding(spell('x',CL))==false and c.a:GetStepBinding(spell('x',LS))==true)
    end)

    test('classic ('..engine..'): binding the spell later makes the step selectable; unbinding skips it again',function()
        local c=whole(engine)
        custom(c.a,'u',{name='U',priority=0,cooldowns={},rotation={spell('cl',CL),spell('ls',LS)}})
        select(c,'U');assert(c.a.currentSpell==LS)
        local watched=0;c.a:WatchButtonIndex('test',function() watched=watched+1 end)
        classicBars(c,{[1]=LB,[2]=FS,[3]=LS,[4]=CL})
        assert(watched==1,'a rescan did not tell its watchers: '..watched)
        assert(c.a.currentSpell==CL,'bound top step not advised: '..tostring(c.a.currentSpell))
        assert(c.a:GetEvaluationEngine()==engine)
        classicBars(c,{[1]=LB,[2]=FS,[3]=LS,[4]=ST})
        assert(c.a.currentSpell==LS,'unbound again but still advised: '..tostring(c.a.currentSpell))
        c.a:WatchButtonIndex('test',nil);classicBars(c,{[1]=LB,[2]=FS,[3]=LS,[4]=ST});assert(watched==2,'an unwatched callback still ran: '..watched)
    end)

    test('classic ('..engine..'): an unbound cooldown is neither announced nor glowed; a bound one is',function()
        local c=whole(engine)
        local glowed={}
        local original=c.a.GlowCooldown
        c.a.GlowCooldown=function(self,id,on,...) if on then glowed[id]=true end;return original(self,id,on,...) end
        custom(c.a,'u',{name='U',priority=0,cooldowns={spell('cdu',CL),spell('cdb',ST)},rotation={spell('ls',LS)}})
        select(c,'U')
        assert(c.a.avail_announced.cdb==ST,'bound cooldown not shown')
        assert(c.a.avail_announced.cdu==nil,'unbound cooldown announced')
        assert(glowed[ST] and not glowed[CL],'unbound cooldown glowed')
    end)

    test('classic ('..engine..'): the preview window skips unbound steps too',function()
        local c=whole(engine,{preview=3})
        local shown={}
        local window=assert(c.a.nextWindow,'no preview window')
        local add=window.AddRecommendation
        window.AddRecommendation=function(self,id,...) shown[#shown+1]=id;return add(self,id,...) end
        custom(c.a,'u',{name='U',priority=0,cooldowns={},rotation={spell('cl',CL),spell('ls',LS),spell('lb',LB),spell('cl2',CL),spell('fs',FS)}})
        for i=#shown,1,-1 do shown[i]=nil end
        c.a:HandleCommand('set U');for i=#shown,1,-1 do shown[i]=nil end;c.tick()
        assert(table.concat(shown,',')==LS..','..LB..','..FS,'preview showed '..table.concat(shown,','))
    end)

    test('classic ('..engine..'): with button highlighting off, bound steps still run and unbound ones are still skipped',function()
        local c=whole(engine)
        c.a.db.profile.disable_buttons=true
        custom(c.a,'u',{name='U',priority=0,cooldowns={},rotation={spell('cl',CL),spell('lb',LB)}})
        select(c,'U')
        assert(c.a.currentSpell==LB,'advised '..tostring(c.a.currentSpell))
        assert(c.a:GetStepBinding(spell('x',LB))==true,'disable_buttons made a bound step look unbound')
    end)

    test('retail ('..engine..'): an unbound top step is skipped and the next bound step glows',function()
        local c=retail(engine)
        custom(c.a,'u',{name='U',priority=0,cooldowns={},rotation={spell('keg',KEG),{id='tp',type='spell',action=TIGER_PALM,conditions={}}}})
        select(c,'U')
        assert(c.a.currentSpell==TIGER_PALM,'advised '..tostring(c.a.currentSpell))
        assert(litNames(c)=='ActionButton2','lit '..litNames(c))
    end)

    test('retail ('..engine..'): a Blizzard suggestion on no bar is skipped in every highlight mode',function()
        for _,mode in ipairs({'rm','both','blizzard'}) do
            local c,state=retail(engine,nil,{next=KEG})
            c.a.db.profile.assisted_highlight=mode
            custom(c.a,'a',{name='A',priority=0,cooldowns={},rotation={{id='blizzard',type='assisted',conditions={}},spell('tp',TIGER_PALM)}})
            select(c,'A')
            assert(c.a.currentSpell==TIGER_PALM,mode..': advised '..tostring(c.a.currentSpell))
            -- The next step is an ordinary spell step: RM lights it in every mode.
            assert(litNames(c)=='ActionButton2',mode..': lit '..litNames(c))
            state.next=BLACKOUT_KICK;for _=1,3 do c.tick() end
            assert(c.a.currentSpell==BLACKOUT_KICK,mode..': bound suggestion not advised: '..tostring(c.a.currentSpell))
            local want=mode=='blizzard' and '' or 'ActionButton1'
            assert(litNames(c)==want,mode..': lit '..litNames(c)..' want '..want)
        end
    end)

    test('retail ('..engine..'): a suggested override whose base spell is on a bar counts as bound',function()
        local OVERRIDE=1249999
        local c=retail(engine,nil,{next=OVERRIDE})
        c.e.C_Spell.GetBaseSpell=function(id) return id==OVERRIDE and TIGER_PALM or id end
        c.e.C_Spell.GetOverrideSpell=function(id) return id==TIGER_PALM and OVERRIDE or id end
        custom(c.a,'a',{name='A',priority=0,cooldowns={},rotation={{id='blizzard',type='assisted',conditions={}},spell('bok',BLACKOUT_KICK)}})
        select(c,'A')
        -- The engine advises the ID that is on the bar (the base spell).
        assert(c.a.currentSpell==TIGER_PALM,'override suggestion skipped: '..tostring(c.a.currentSpell))
        assert(litNames(c)=='ActionButton2','lit '..litNames(c))
    end)
end

test('parity: lean and standard advise the same spell, poll for poll, as bars change',function()
    local traces={}
    for _,engine in ipairs({'standard','lean'}) do
        local c=whole(engine);local trace={}
        custom(c.a,'u',{name='U',priority=0,cooldowns={spell('cdu',CL),spell('cdb',ST)},rotation={spell('cl',CL),spell('ls',LS),spell('lb',LB)}})
        select(c,'U')
        local function note() trace[#trace+1]=tostring(c.a.currentSpell)..'/'..tostring(c.a.avail_announced.cdu)..'/'..tostring(c.a.avail_announced.cdb) end
        note()
        classicBars(c,{[1]=LB,[2]=FS,[4]=CL});note()
        classicBars(c,{[1]=LB,[2]=FS,[3]=LS});note()
        classicBars(c,{[2]=FS});note()
        traces[engine]=table.concat(trace,' ')
        assert(c.a:GetEvaluationEngine()==engine)
    end
    assert(traces.standard==traces.lean,'standard '..traces.standard..' | lean '..traces.lean)
    assert(traces.standard==LS..'/nil/'..ST..' '..CL..'/'..CL..'/nil '..LS..'/nil/nil nil/nil/nil','trace '..traces.standard)
end)

-- What "bound" means -----------------------------------------------------------------
test('binding: Stop, Branch and no-action steps have nothing to check; nothing is judged before a scan',function()
    local c=whole()
    assert(c.a:GetStepBinding({id='s',type='stop',conditions={}})==nil)
    assert(c.a:GetStepBinding({id='b',type='branch',conditions={},onTrue={},onFalse={}})==nil)
    assert(c.a:GetStepBinding({id='e',type='spell',conditions={}})==nil)
    local unbound=c.a:ListUnboundSteps({rotation={{id='s',type='stop',conditions={}},spell('cl',CL),spell('off',CL,{disabled=true}),spell('lb',LB)},cooldowns={spell('cd',CL)}})
    assert(#unbound==2 and unbound[1].step.id=='cl' and unbound[2].step.id=='cd' and unbound[2].section=='cooldowns','unbound '..#unbound)
end)

test('binding: Classic ranks count when any rank is on a bar; a ranked step needs that rank',function()
    local c=whole()
    c.a.SpellCatalog.GetAllSpellIds=function(_,id) if id==CL then return {CL,930} end end
    classicBars(c,{[1]=930})
    assert(c.a:GetStepBinding(spell('x',CL))==true,'another rank on a bar did not count')
    assert(c.a:GetStepBinding(spell('x',CL,{ranked=true}))==false,'a ranked step borrowed another rank')
end)

test('binding: items and item sets bind through a button holding that exact item',function()
    local c=whole()
    local p=c.a.Platform
    local uses={[5512]=234,[5513]=234,[6000]=777}
    p.GetItemUseSpell=function(_,item) local id=tonumber(item);return uses[id] and {spellID=uses[id]} or nil end
    p.GetItemID=function(_,item) return tonumber(item) end
    c.e.HasAction=function(slot) return slot==1 end
    c.e.GetActionInfo=function(slot) if slot==1 then return 'item',5512 end end
    c.a:Fetch()
    assert(c.a:GetStepBinding({id='i',type='item',action={5512},conditions={}})==true,'item on a bar unbound')
    assert(c.a:GetStepBinding({id='i',type='item',action={5513},conditions={}})==false,'a different item with the same use spell borrowed the button')
    c.a.db.profile.itemsets=c.a.db.profile.itemsets or {}
    c.a.db.profile.itemsets.set={name='Potions',items={6000,5512}}
    assert(c.a:GetStepBinding({id='i',type='item',action='set',conditions={}})==true,'item set with one bound item unbound')
    c.a.db.profile.itemsets.none={name='Elixirs',items={6000}}
    assert(c.a:GetStepBinding({id='i',type='item',action='none',conditions={}})==false)
    local unbound=c.a:ListUnboundSteps({rotation={{id='i',type='item',action='none',conditions={}}},cooldowns={}})
    assert(c.a:DescribeUnboundStep(unbound[1])=='Elixirs (step 1)',c.a:DescribeUnboundStep(unbound[1]))
end)

test('binding: Blizzard\'s suggestion lists the known suggestion spells on no bar',function()
    local c=retail('standard',nil,{next=TIGER_PALM})
    local bound,missing=c.a:GetStepBinding({id='a',type='assisted',conditions={}})
    assert(bound==false and #missing==1 and missing[1]==KEG,'missing '..tostring(missing and table.concat(missing,',')))
    c.frames=retailBars(c,{[1]=BLACKOUT_KICK,[2]=TIGER_PALM,[3]=KEG})
    assert(c.a:GetStepBinding({id='a',type='assisted',conditions={}})==true)
    -- A spell the character does not know is never reported.
    local known=c.e.IsSpellKnown;c.e.IsSpellKnown=function(id,...) if id==KEG then return false end;return known(id,...) end
    c.frames=retailBars(c,{[1]=BLACKOUT_KICK,[2]=TIGER_PALM})
    assert(c.a:GetStepBinding({id='a',type='assisted',conditions={}})==true,'an unknown spell was reported')
end)

-- The restricted Retail client: base/override aliases.
local function restricted()
    local M=dofile('tests/fixtures/retail_premade_model_a.lua')
    local f,s=M.new('monk','MONK',268,{policy='restricted'})
    local a,e=f.addon,f.env
    dofile('tests/fixtures/native_ui.lua')(e)
    local create=e.CreateFrame
    e.CreateFrame=function(...)
        local frame=create(...);local texture=frame.CreateTexture
        frame.CreateTexture=function(...) local t=texture(...);t.SetBlendMode=t.SetBlendMode or function() end;t.SetRotation=t.SetRotation or function() end;return t end
        return frame
    end
    e.tinsert,e.tremove=table.insert,table.remove
    f.libraries['LibCustomGlow-1.0']={PixelGlow_Stop=function() end,AutoCastGlow_Stop=function() end,ButtonGlow_Stop=function() end}
    e.C_AddOns.IsAddOnLoaded=function() return false end
    local call=e.LibStub
    e.LibStub=setmetatable({GetLibrary=function(_,name,silent) if silent then local ok,lib=pcall(call,name);return ok and lib or nil end;return call(name) end},
        {__call=function(_,name,silent) return call(name,silent) end})
    f.load('Platform/macros.lua');f.load('Core/presentation.lua');f.load('Functions/collections.lua');f.load('buttons.lua')
    a.uuid=a.uuid or function() return 'overlay' end
    a.ScheduleRepeatingTimer=function() return {} end;a.CancelTimer=function() end
    a.db.global.effects={ping={type='texture',texture='Interface\\Cooldown\\ping4'}}
    a.db.profile.effect='ping';a.db.profile.magnification=1.4;a.db.profile.setpoint='CENTER';a.db.profile.color={r=1,g=1,b=1,a=1}
    return {a=a,e=e,s=s,f=f}
end
test('restricted retail: a step naming the base or the override of the spell on the bar is bound',function()
    local c=restricted()
    assert(c.a.Platform:GetClientInfo().combatDataPolicy=='restricted')
    local OVERRIDE=1249999
    c.s.base={[OVERRIDE]=TIGER_PALM};c.s.override={[TIGER_PALM]=OVERRIDE}
    retailBars(c,{[2]=OVERRIDE})
    assert(c.a:GetStepBinding(spell('x',TIGER_PALM))==true,'base spell step unbound')
    retailBars(c,{[2]=TIGER_PALM})
    assert(c.a:GetStepBinding(spell('x',OVERRIDE))==true,'override spell step unbound')
    assert(c.a:GetStepBinding(spell('x',BLACKOUT_KICK))==false)
end)
-- The Brewmaster Blackout Kick the Icy Veins reference names (205523) and the
-- class spell (100784) are two IDs for one ability: whichever the bar reports,
-- a step naming the other is bound.
local BREW_KICK=205523
local function named(c,names) local info=c.e.C_Spell.GetSpellInfo;c.e.C_Spell.GetSpellInfo=function(id) local r=info(id);if type(r)=='table' and names[id] then r.name=names[id] end;return r end end
local KICK_NAMES={[BLACKOUT_KICK]='Blackout Kick',[BREW_KICK]='Blackout Kick'}
test('restricted retail: the bar holds the class Blackout Kick, the step names the Brewmaster one (a specialization version of the same ability)',function()
    local c=restricted();named(c,KICK_NAMES)
    local frames=retailBars(c,{[1]=BLACKOUT_KICK,[2]=TIGER_PALM})
    assert(c.a:GetStepBinding(spell('x',BREW_KICK))==true,'Brewmaster Blackout Kick unbound with the class one on the bar')
    -- The engine sees it too: the index maps the step\'s ID to the same button.
    assert(c.a:FindSpell({BREW_KICK})==BREW_KICK,'the engine does not find the button')
    assert(c.a:GetSpellButtonNames(BREW_KICK)[1]=='ActionButton1',table.concat(c.a:GetSpellButtonNames(BREW_KICK),','))
    -- And the reverse: the Brewmaster one on the bar, the step names the class one.
    retailBars(c,{[1]=BREW_KICK})
    assert(c.a:GetStepBinding(spell('x',BLACKOUT_KICK))==true,'class Blackout Kick unbound with the Brewmaster one on the bar')
    -- A different ability stays unbound, and so does a spell on no bar.
    assert(c.a:GetStepBinding(spell('x',KEG))==false and c.a:GetStepBinding(spell('x',TIGER_PALM))==false,'an unrelated spell looked bound')
end)
test('restricted retail: a talent override of the spell on the bar, the base of the step, and the client\'s own slot answer',function()
    local c=restricted()
    local TALENT=1250000
    c.s.base={[TALENT]=BLACKOUT_KICK};c.s.override={[BLACKOUT_KICK]=TALENT}
    retailBars(c,{[1]=BLACKOUT_KICK})
    assert(c.a:GetStepBinding(spell('x',TALENT))==true,'a talent override of the bar spell is unbound')
    retailBars(c,{[1]=TALENT})
    assert(c.a:GetStepBinding(spell('x',BLACKOUT_KICK))==true,'the base of the bar spell is unbound')
    -- Unrelated IDs the client still places on a slot (FindSpellActionButtons).
    c.s.base,c.s.override={},{}
    local frames=retailBars(c,{[3]=777001})
    assert(c.a:GetStepBinding(spell('x',777002))==false)
    local find=c.e.C_ActionBar.FindSpellActionButtons
    c.e.C_ActionBar.FindSpellActionButtons=function(id) if id==777002 then return {3} end;return find(id) end
    c.a:Fetch()
    assert(c.a:GetStepBinding(spell('x',777002))==true,'a spell the client places on slot 3 is unbound')
    assert(c.a:ExplainStepBinding(spell('x',777002)).ids[1].how:find('client slots'),'the explanation does not say how')
end)
test('binding: a rescan that is pending, or none yet, judges nothing; the editor asks for a rescan when the scan is old',function()
    local c=restricted();retailBars(c,{[1]=BLACKOUT_KICK})
    assert(c.a:GetStepBinding(spell('x',KEG))==false)
    c.a.fetchPending=true;assert(c.a:GetStepBinding(spell('x',KEG))==nil,'judged while the bars are being rescanned')
    c.a:Fetch();assert(c.a.fetchPending==nil and c.a:GetStepBinding(spell('x',KEG))==false,'Fetch did not clear the pending rescan')
    local asked=0;c.a.ButtonFetch=function() asked=asked+1 end
    assert(not c.a:EnsureFreshButtonIndex(10) and asked==0,'a fresh scan was redone')
    local now=c.e.GetTime();c.e.GetTime=function() return now+60 end
    assert(c.a:EnsureFreshButtonIndex(10) and asked==1,'an old scan was not redone')
end)
test('diagnostic: each unbound step lists its spell IDs, their relatives, how they were looked up, and what is on the bars',function()
    local c=restricted();retailBars(c,{[1]=BLACKOUT_KICK})
    local list=c.a:ListUnboundSteps({rotation={spell('k',KEG),spell('b',BLACKOUT_KICK)},cooldowns={}})
    assert(#list==1 and list[1].step.id=='k')
    local explain=c.a:ExplainStepBinding(list[1].step)
    assert(explain.bound==false and explain.ids[1].id==KEG and explain.ids[1].direct==false and #explain.ids[1].buttons==0)
    local index=c.a:GetIndexedSpellsDiagnostic(10)
    assert(index.total>=1 and index.spells[1].id==BLACKOUT_KICK and index.spells[1].buttons[1]=='ActionButton1' and index.policy=='restricted')
end)
test('binding: before the first scan nothing is judged (no step looks unbound)',function()
    local c=restricted()
    assert(c.a:GetStepBinding(spell('x',BLACKOUT_KICK))==nil,'judged before any scan')
    assert(#c.a:ListUnboundSteps({rotation={spell('x',BLACKOUT_KICK)},cooldowns={}})==0)
end)

-- Reports -------------------------------------------------------------------------------
test('reports: /rm why and /rm debug glow name the skipped steps',function()
    local c=whole()
    custom(c.a,'u',{name='U',priority=0,cooldowns={spell('cdu',CL,{name='Big cooldown'})},rotation={spell('cl',CL),spell('ls',LS)}})
    select(c,'U')
    local why=table.concat(c.a:GetRotationEligibilityReport(),'\n')
    assert(why:find('Skipped, not on your action bars %(they cannot be highlighted%): Spell 421 %(step 1%); Big cooldown %(cooldown%)%.'),why)
    local lines=c.a:BuildGlowDiagnostic()
    local text=table.concat(lines,'\n')
    assert(text:find('skipped, not on your action bars %(cannot be highlighted%): Spell 421 %(step 1%); Big cooldown %(cooldown%)'),text)
    assert(text:find('spell 421 .*mapped=false'),'step mapping missing')
    assert(text:find('not on your action bars: this spell is skipped'),'step reason missing')
    -- Every step bound: no line.
    classicBars(c,{[1]=LB,[2]=FS,[3]=LS,[4]=CL})
    assert(not table.concat(c.a:GetRotationEligibilityReport(),'\n'):find('Skipped, not on your action bars'))
end)

print(pass..' passed, '..fail..' failed');if fail>0 then os.exit(1)end
