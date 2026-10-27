-- Tooltip integration (Core/tooltips.lua): item tooltips name the item sets
-- that contain the item; spell and item tooltips name the rotations that use
-- it. Run against the whole-poll fixture (real scoped rotation store, real
-- AceDB, the Shaman starter pack) with fake tooltips and fake registration
-- points. No real client is involved: how the two registration paths behave
-- in the game is established from Blizzard's UI source (see the header of
-- Core/tooltips.lua), not from here.
local F=dofile('tests/fixtures/addon.lua')
local pass,fail=0,0
local function test(name,fn)local ok,err=pcall(fn);if ok then pass=pass+1;print('PASS '..name)else fail=fail+1;print('FAIL '..name..': '..tostring(err))end end
local root=assert(io.popen('pwd'):read('*l'))

-- Fake tooltips --------------------------------------------------------------
local function newTooltip(options)
    options=options or {}
    local t={lines={},shown=0,item=options.item,spell=options.spell}
    function t:AddLine(text,r,g,b,wrap) if options.failAdd then error('AddLine failed') end;self.lines[#self.lines+1]={text=text,r=r,g=g,b=b,wrap=wrap} end
    function t:IsForbidden() return options.forbidden==true end
    function t:Show() self.shown=self.shown+1 end
    function t:GetItem() return 'Item',self.item end
    function t:GetSpell() return 'Spell',self.spell end
    function t:texts() local out={};for _,line in ipairs(self.lines) do out[#out+1]=line.text end;return out end
    return t
end
-- Mainline tooltip: built on the data handler (ProcessInfo exists).
local function mainlineTooltip(options)
    local t=newTooltip(options);function t:ProcessInfo() end
    return t
end
-- Classic tooltip: script handlers only.
local function classicTooltip(options)
    local t=newTooltip(options);t.scripts={}
    function t:HookScript(name,fn) self.scripts[name]=self.scripts[name] or {};table.insert(self.scripts[name],fn) end
    function t:HasScript() return true end
    function t:fire(name) for _,fn in ipairs(self.scripts[name] or {}) do fn(self) end end
    return t
end

local function fixture(options)
    options=options or {}
    local c=assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price',root,true,root,true)({target=false,combat=false,buttons=true,poll=.15})
    local a,e=c.a,c.e
    c.load('Core/tooltips.lua')
    local clock=100
    e.GetTime=function() return clock end
    e.InCombatLockdown=function() return options.combat==true end
    c.advance=function(seconds) clock=clock+seconds end
    c.combat=function(value) e.InCombatLockdown=function() return value end end
    return c,a,e
end
local function custom(a,id,body,existing)
    local reference={kind='custom',address={scope='class',class='SHAMAN',owner='SHAMAN',spec=0,id=id}}
    local token
    if existing then local record,issued=a:GetRotationRecordSnapshot(0,a:GetScopedRotationCoordinator():Key(reference));assert(record);token=issued end
    assert(a:CommitRotationDraft(reference,token,{body=body},'class'))
    return reference
end
local function step(id,spell,extra)
    local s={id=id,type='spell',action=spell,conditions={}}
    for k,v in pairs(extra or {}) do s[k]=v end
    return s
end
local function body(name,rotation,cooldowns,extra)
    local b={name=name,priority=0,rotation=rotation or {},cooldowns=cooldowns or {}}
    for k,v in pairs(extra or {}) do b[k]=v end
    return b
end
local function plain(text) return (text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')) end
local function lines(manager,kind,id)
    local out=manager:Lines(kind,id)
    if not out then return nil end
    local r={};for i,t in ipairs(out) do r[i]=plain(t) end
    return r
end
-- A mainline processor with its registration points recorded.
local function installProcessor(e,mainline)
    local registered={}
    e.TooltipDataProcessor={AddTooltipPostCall=function(kind,fn) registered[#registered+1]={kind=kind,fn=fn} end}
    e.Enum=e.Enum or {};e.Enum.TooltipDataType={Item=0,Spell=1}
    e.GameTooltip=mainline and mainlineTooltip() or classicTooltip()
    e.ItemRefTooltip=mainline and mainlineTooltip() or classicTooltip()
    return registered
end
local function login(a) a.TooltipIntegration:OnEvent('PLAYER_ENTERING_WORLD') end

-- Index building ----------------------------------------------------------------
test('steps in the rotation and cooldown lists index their rotation; a disabled step does not',function()
    local _,a=fixture()
    custom(a,'r1',body('Alpha',{step('a',91403),step('b',91324,{disabled=true})},{step('c',91042)}))
    local m=a.TooltipIntegration
    assert(table.concat(lines(m,'spell',91403),'|')=='Rotation Master rotations: Alpha')
    assert(table.concat(lines(m,'spell',91042),'|')=='Rotation Master rotations: Alpha','a cooldown step counts')
    assert(lines(m,'spell',91324)==nil,'a disabled step is not used')
    assert(lines(m,'spell',91999)==nil,'an unrelated spell shows nothing')
end)

test('branch arms are walked; an arm that can never run is not',function()
    local _,a=fixture()
    custom(a,'r1',body('Alpha',{{id='br',type='branch',mode='true',conditions={},onTrue={step('t',91403)},onFalse={step('f',91324)}}}))
    local m=a.TooltipIntegration
    assert(lines(m,'spell',91403),'the arm that runs')
    assert(lines(m,'spell',91324)==nil,'the arm that never runs')
end)

test('item steps count through an item set and through an inline list; a link or name resolves to the item',function()
    local _,a,e=fixture()
    a.db.profile.itemsets={potions={name='Potions',items={9100118,'item:9100929'}}}
    custom(a,'r1',body('Alpha',{{id='i1',type='item',action='potions',conditions={}},{id='i2',type='item',action={910013444,'|cff1eff00|Hitem:91005509:0|h[Healthstone]|h|r'},conditions={}}}))
    local m=a.TooltipIntegration
    for _,id in ipairs({9100118,9100929,910013444,91005509}) do local out=lines(m,'item',id);assert(out[#out]=='Rotation Master rotations: Alpha','item '..id) end
    assert(lines(m,'item',1)==nil)
end)

test('conditions count only when the setting asks for them, and are found through AND, OR and NOT',function()
    local _,a=fixture()
    a.db.profile.itemsets={}
    local conditions={type='AND',value={{type='NOT',value={type='SPELL_AVAIL',spell=91042}},{type='OR',value={{type='CARRYING',item={9100118},operator='>=',value=1}}}}}
    custom(a,'r1',body('Alpha',{step('a',91403,{conditions=conditions})}))
    local m=a.TooltipIntegration
    assert(lines(m,'spell',91042)==nil and lines(m,'item',9100118)==nil,'off by default')
    a.db.profile.tooltip_conditions=true;a:RefreshTooltipIntegration()
    assert(table.concat(lines(m,'spell',91042),'|')=='Rotation Master rotations: Alpha' and lines(m,'item',9100118),'on: spell and item inside conditions')
    assert(lines(m,'spell',91403),'the step itself still counts')
end)

test('a rotation is named once however many steps use the spell, sorted by priority then name, enabled first',function()
    local _,a=fixture()
    a.db.profile.tooltip_limit=10
    custom(a,'z',body('Zeta',{step('a',91403),step('b',91403)},{step('c',91403)},{priority=5}))
    custom(a,'b',body('beta',{step('a',91403)}))
    custom(a,'a',body('Alpha',{step('a',91403)}))
    custom(a,'off',body('Aardvark',{step('a',91403)},nil,{disabled=true,priority=100}))
    local out=lines(a.TooltipIntegration,'spell',91403)
    assert(out[1]=='Rotation Master rotations: Zeta, Alpha, beta, Aardvark (disabled)',out[1])
end)

test('a disabled custom rotation is dimmed and marked; its name keeps pipes literal',function()
    local _,a=fixture()
    custom(a,'off',body('Off|cffff0000red',{step('a',91403)},nil,{disabled=true}))
    local raw=a.TooltipIntegration:Lines('spell',91403)[1]
    assert(raw:find('|cff8c8c8cOff||cffff0000red (disabled)|r',1,true),raw)
end)

test('Built Ins are indexed from their bodies and honor their enabled state',function()
    local _,a=fixture()
    local rows=a:GetBuiltinStates(0)
    local target
    for _,row in ipairs(rows) do
        if row.state=='enabled' and type(row.body)=='table' then
            for _,s in ipairs(row.body.rotation or {}) do if s.type=='spell' and type(s.action)=='number' and not s.disabled then target=target or {row=row,spell=s.action} end end
        end
    end
    assert(target,'the starter pack has a spell step')
    local m=a.TooltipIntegration
    local on=assert(lines(m,'spell',target.spell),'listed while on')
    assert(on[1]:find(target.row.name,1,true),on[1])
    assert(not on[1]:find('(disabled)',1,true))
    local id=target.row.id
    assert(a:SetDefaultRotationEnabled(id,false))
    m.uses=nil
    local off=assert(lines(m,'spell',target.spell),'still listed while off')
    assert(off[1]:find(target.row.name..' (disabled)',1,true),off[1])
end)

test('the display name helper names the rotation, and a Built In never shows its locale key',function()
    local _,a=fixture()
    a.RotationDisplayName=function(_,name) return 'Shown: '..tostring(name) end
    custom(a,'r1',body('Alpha',{step('a',91403)}))
    assert(lines(a.TooltipIntegration,'spell',91403)[1]=='Rotation Master rotations: Shown: Alpha')
end)

test('item sets: every set that holds the item, personal over shared, sorted, once each',function()
    local _,a=fixture()
    a.db.profile.itemsets={mine={name='Zebra',items={9100118,'item:9100119'}},both={name='Both',items={9100118}}}
    a.db.global.itemsets={shared={name='Apple',items={9100118,{}}},both={name='Shared Both',items={9100118}}}
    local m=a.TooltipIntegration
    local out=lines(m,'item',9100118)
    assert(out[1]=='Rotation Master item sets: Apple, Both, Zebra',out[1])
    assert(lines(m,'item',9100119)[1]=='Rotation Master item sets: Zebra')
    assert(lines(m,'item',9100120)==nil)
    assert(lines(m,'spell',9100118)==nil,'item sets belong to item tooltips only')
end)

test('an item set entry that is a name is retried once the item is cached',function()
    local _,a,e=fixture()
    local cached=false
    e.C_Item=e.C_Item or {}
    e.C_Item.GetItemInfoInstant=function(item) if cached and item=='Major Healing Potion' then return 910013446 end end
    a.db.profile.itemsets={potions={name='Potions',items={'Major Healing Potion'}}}
    local m=a.TooltipIntegration
    assert(lines(m,'item',910013446)==nil and m.sets.incomplete==true)
    cached=true;m:OnEvent('GET_ITEM_INFO_RECEIVED')
    assert(lines(m,'item',910013446)==nil,'not retried at once')
    local clock=1000;e.GetTime=function() clock=clock+10;return clock end
    assert(lines(m,'item',910013446)[1]=='Rotation Master item sets: Potions','retried after the event')
end)

-- Cap ------------------------------------------------------------------------------
test('the cap lists that many names and counts the rest, for rotations and for sets',function()
    local _,a=fixture()
    for i=1,5 do custom(a,'r'..i,body('Rot '..i,{step('a',91403)})) end
    local sets={};for i=1,4 do sets['s'..i]={name='Set '..i,items={9100118}} end
    a.db.profile.itemsets=sets
    local m=a.TooltipIntegration
    assert(lines(m,'spell',91403)[1]=='Rotation Master rotations: Rot 1, Rot 2, Rot 3 (+2 more)',lines(m,'spell',91403)[1])
    assert(lines(m,'item',9100118)[1]=='Rotation Master item sets: Set 1, Set 2, Set 3 (+1 more)')
    a.db.profile.tooltip_limit=2;a:RefreshTooltipIntegration()
    assert(lines(m,'spell',91403)[1]=='Rotation Master rotations: Rot 1, Rot 2 (+3 more)')
    a.db.profile.tooltip_limit=99;a:RefreshTooltipIntegration()
    assert(lines(m,'spell',91403)[1]=='Rotation Master rotations: Rot 1, Rot 2, Rot 3, Rot 4, Rot 5','capped at 20, not unlimited')
    a.db.profile.tooltip_limit='junk';a:RefreshTooltipIntegration()
    assert(a:GetTooltipSettings().limit==3,'an unreadable limit falls back to 3')
end)

-- Toggles -----------------------------------------------------------------------------
test('defaults: on, on, conditions off, three names; each switch removes only its own line',function()
    local _,a=fixture()
    local s=a:GetTooltipSettings()
    assert(s.enabled and s.itemsets and s.rotations and not s.conditions and s.limit==3)
    a.db.profile.itemsets={mine={name='Mine',items={9100118}}}
    custom(a,'r1',body('Alpha',{{id='i',type='item',action='mine',conditions={}}}))
    local m=a.TooltipIntegration
    assert(#m:Lines('item',9100118)==2)
    a.db.profile.tooltip_itemsets=false;a:RefreshTooltipIntegration()
    local out=lines(m,'item',9100118);assert(#out==1 and out[1]:find('rotations'))
    a.db.profile.tooltip_itemsets=true;a.db.profile.tooltip_rotations=false;a:RefreshTooltipIntegration()
    out=lines(m,'item',9100118);assert(#out==1 and out[1]:find('item sets'))
    a.db.profile.tooltips=false;a:RefreshTooltipIntegration()
    assert(m:Lines('item',9100118)==nil,'the master switch beats the others')
    s=a:GetTooltipSettings();assert(not s.enabled and not s.itemsets and not s.rotations)
end)

test('disabled: no index is built and no rotation API is touched',function()
    local _,a=fixture()
    a.db.profile.tooltips=false;a:RefreshTooltipIntegration()
    local calls=0
    for _,name in ipairs({'ListRotationHeaders','GetRotationRecordSnapshot','GetBuiltinStates'}) do
        local original=a[name];a[name]=function(...) calls=calls+1;return original(...) end
    end
    local m=a.TooltipIntegration
    assert(m:Lines('spell',91403)==nil and m:Lines('item',9100118)==nil)
    assert(calls==0 and m.sets==nil and m.uses==nil,'work done while disabled')
end)

-- Freshness ------------------------------------------------------------------------------
test('a rotation edit shows up, within the recheck interval and no sooner',function()
    local c,a=fixture()
    local reference=custom(a,'r1',body('Alpha',{step('a',91403)}))
    local m=a.TooltipIntegration
    assert(lines(m,'spell',91403) and not lines(m,'spell',91324))
    custom(a,'r1',body('Alpha',{step('a',91324)}),true)
    assert(lines(m,'spell',91324)==nil,'served from the index inside the recheck interval')
    c.advance(1.5)
    assert(lines(m,'spell',91324) and lines(m,'spell',91403)==nil,'rebuilt once the roster stamp moved')
    assert(reference)
end)

test('an unchanged roster is not rebuilt however often a tooltip shows',function()
    local c,a=fixture()
    custom(a,'r1',body('Alpha',{step('a',91403)}))
    local m=a.TooltipIntegration
    assert(lines(m,'spell',91403))
    local snapshots,builtins=0,0
    local snapshot,states=a.GetRotationRecordSnapshot,a.GetBuiltinStates
    a.GetRotationRecordSnapshot=function(...) snapshots=snapshots+1;return snapshot(...) end
    a.GetBuiltinStates=function(...) builtins=builtins+1;return states(...) end
    for _=1,10 do c.advance(2);assert(lines(m,'spell',91403)) end
    assert(snapshots==0 and builtins==0,'rebuilt '..snapshots..'/'..builtins)
end)

test('a dependency invalidation (item set or condition write) rebuilds at the next tooltip',function()
    local _,a=fixture()
    a.db.profile.itemsets={mine={name='Mine',items={9100118}}}
    local m=a.TooltipIntegration
    assert(lines(m,'item',9100118)[1]=='Rotation Master item sets: Mine')
    a.db.profile.itemsets.extra={name='Extra',items={9100118}}
    assert(lines(m,'item',9100118)[1]=='Rotation Master item sets: Mine','no notification, no rebuild')
    assert(a:InvalidateRotationDependencies('itemset','extra'))
    assert(lines(m,'item',9100118)[1]=='Rotation Master item sets: Extra, Mine')
end)

test('a different specialization or profile table drops the index',function()
    local _,a=fixture()
    custom(a,'r1',body('Alpha',{step('a',91403)}))
    local m=a.TooltipIntegration
    assert(lines(m,'spell',91403))
    local first=m.uses
    m.uses.spec=-1
    assert(lines(m,'spell',91403) and m.uses~=first,'rebuilt for the current specialization')
    first=m.uses;m.uses.profile={}
    assert(lines(m,'spell',91403) and m.uses~=first,'rebuilt for the current profile')
end)

test('in combat nothing is built or rebuilt; the previous index is served',function()
    local c,a=fixture()
    custom(a,'r1',body('Alpha',{step('a',91403)}))
    local m=a.TooltipIntegration
    c.combat(true)
    assert(lines(m,'spell',91403)==nil and m.uses==nil,'no index yet, none built in combat')
    c.combat(false);assert(lines(m,'spell',91403))
    custom(a,'r1',body('Alpha',{step('a',91324)}),true)
    c.combat(true);c.advance(5)
    local headers=0;local original=a.ListRotationHeaders;a.ListRotationHeaders=function(...) headers=headers+1;return original(...) end
    assert(lines(m,'spell',91403) and lines(m,'spell',91324)==nil and headers==0,'old index served, nothing read')
    c.combat(false)
    assert(lines(m,'spell',91324),'rebuilt after combat')
end)

-- Spell identity ------------------------------------------------------------------------------
test('a base or override spell stands for the other (talents swap one for the other)',function()
    local _,a=fixture()
    a.GetSpellIdRelatives=function(_,id) if id==500 or id==501 then return {id,id==500 and 501 or 500} end return {id} end
    custom(a,'r1',body('Alpha',{step('a',500)}))
    local m=a.TooltipIntegration
    assert(lines(m,'spell',500) and lines(m,'spell',501),'both directions')
    assert(lines(m,'spell',502)==nil)
end)

test('on clients with ranks a hovered rank matches a rank-agnostic step; an exact-rank step needs its own rank',function()
    local _,a,e=fixture()
    e.WOW_PROJECT_ID=5
    a.SpellCatalog.GetAllSpellIds=function(_,id) if id==10 or id==11 or id==12 then return {12,11,10} end end
    custom(a,'any',body('Any rank',{step('a',10)}))
    custom(a,'exact',body('Exact rank',{step('a',10,{ranked=true})}))
    local m=a.TooltipIntegration
    assert(lines(m,'spell',10)[1]=='Rotation Master rotations: Any rank, Exact rank',lines(m,'spell',10)[1])
    assert(lines(m,'spell',12)[1]=='Rotation Master rotations: Any rank',lines(m,'spell',12)[1])
end)

-- Registration paths ----------------------------------------------------------------------------
test('mainline: the processor is used when the tooltip is built on the data handler, and lines are appended',function()
    local _,a,e=fixture()
    local registered=installProcessor(e,true)
    custom(a,'r1',body('Alpha',{step('a',91403)}))
    a.db.profile.itemsets={mine={name='Mine',items={9100118}}}
    login(a)
    assert(#registered==2 and registered[1].kind==0 and registered[2].kind==1 and a.TooltipIntegration.mode=='processor')
    local tip=e.GameTooltip
    registered[2].fn(tip,{id=91403})
    assert(#tip.lines==1 and plain(tip.lines[1].text)=='Rotation Master rotations: Alpha' and tip.lines[1].wrap==true)
    tip.lines={};registered[1].fn(tip,{id=9100118})
    assert(#tip.lines==1 and plain(tip.lines[1].text)=='Rotation Master item sets: Mine')
    assert(tip.shown==0,'the processor path never calls Show')
    local ref=e.ItemRefTooltip;registered[2].fn(ref,{id=91403});assert(#ref.lines==1,'item links in chat too')
end)

test('mainline: other tooltips, forbidden tooltips, unreadable and malformed data add nothing',function()
    local _,a,e=fixture()
    local registered=installProcessor(e,true)
    custom(a,'r1',body('Alpha',{step('a',91403)}))
    login(a)
    local call=registered[2].fn
    local other=mainlineTooltip();call(other,{id=91403});assert(#other.lines==0,'a comparison or foreign tooltip')
    local forbidden=mainlineTooltip({forbidden=true});e.GameTooltip=forbidden;call(forbidden,{id=91403});assert(#forbidden.lines==0)
    e.GameTooltip=mainlineTooltip();local tip=e.GameTooltip
    call(tip,nil);call(tip,{});call(tip,{id='91403'});call(tip,{id=-1});call(tip,{id=1.5});call(tip,{id=0/0});assert(#tip.lines==0)
    local readable=a.Platform.CanReadValue
    a.Platform.CanReadValue=function(_,v) if v==91403 then return false,'restricted-value' end return true end
    call(tip,{id=91403});assert(#tip.lines==0,'a secret ID is never looked up')
    a.Platform.CanReadValue=readable
    call(tip,{id=91403});assert(#tip.lines==1)
end)

test('classic: the processor global exists but the tooltip is not built on it, so the scripts are hooked and the processor is not',function()
    local _,a,e=fixture()
    local registered=installProcessor(e,false)
    custom(a,'r1',body('Alpha',{step('a',91403)}))
    a.db.profile.itemsets={mine={name='Mine',items={9100118}}}
    login(a)
    assert(#registered==0,'the processor must not be used where it never fires for this tooltip')
    assert(a.TooltipIntegration.mode=='scripts')
    local tip=e.GameTooltip
    assert(tip.scripts.OnTooltipSetItem and tip.scripts.OnTooltipSetSpell and tip.scripts.OnTooltipCleared)
    tip.spell=91403;tip:fire('OnTooltipSetSpell')
    assert(#tip.lines==1 and plain(tip.lines[1].text)=='Rotation Master rotations: Alpha' and tip.shown==1,'Show recomputes the size')
    tip:fire('OnTooltipSetSpell');assert(#tip.lines==1,'a second fire adds no second line')
    tip:fire('OnTooltipCleared');tip.lines={};tip.item='|cff1eff00|Hitem:9100118::::::::::::|h[Potion]|h|r';tip:fire('OnTooltipSetItem')
    assert(#tip.lines==1 and plain(tip.lines[1].text)=='Rotation Master item sets: Mine','a cleared tooltip is fresh again')
    local ref=e.ItemRefTooltip;ref.spell=91403;ref:fire('OnTooltipSetSpell');assert(#ref.lines==1)
end)

test('classic: nothing to add means no Show; an unreadable or missing link adds nothing',function()
    local _,a,e=fixture()
    installProcessor(e,false)
    custom(a,'r1',body('Alpha',{step('a',91403)}))
    login(a)
    local tip=e.GameTooltip
    tip.spell=999;tip:fire('OnTooltipSetSpell');assert(#tip.lines==0 and tip.shown==0)
    tip:fire('OnTooltipCleared');tip.item=nil;tip:fire('OnTooltipSetItem');assert(#tip.lines==0)
    tip:fire('OnTooltipCleared');tip.item='not a link';tip:fire('OnTooltipSetItem');assert(#tip.lines==0)
    tip:fire('OnTooltipCleared');a.Platform.CanReadValue=function() return false,'restricted-value' end;tip.spell=91403;tip:fire('OnTooltipSetSpell');assert(#tip.lines==0)
end)

test('a client with neither path installs nothing and does not fail',function()
    local _,a,e=fixture()
    e.TooltipDataProcessor=nil;e.GameTooltip={};e.ItemRefTooltip=nil
    local ok,why=a.TooltipIntegration:Install();assert(ok==false and why=='no-tooltip-api')
    assert(a:GetTooltipSettings().enabled)
    login(a)
end)

test('nothing is registered while the master switch is off at login; turning it on installs once',function()
    local _,a,e=fixture()
    local registered=installProcessor(e,true)
    a.db.profile.tooltips=false;login(a)
    assert(#registered==0 and not a.TooltipIntegration.installed and not a.TooltipIntegration.eventsActive)
    a.db.profile.tooltips=true;a:RefreshTooltipIntegration();assert(#registered==2 and a.TooltipIntegration.eventsActive)
    a:RefreshTooltipIntegration();a:RefreshTooltipIntegration();assert(#registered==2,'never twice')
    a.db.profile.tooltips=false;a:RefreshTooltipIntegration();assert(not a.TooltipIntegration.eventsActive and #registered==2)
    local tip=e.GameTooltip;registered[2].fn(tip,{id=91403});assert(#tip.lines==0,'the retained hook is inert')
end)

test('a failing callback is reported, retires the feature for the session and leaves the tooltip alone',function()
    local _,a,e=fixture()
    local registered=installProcessor(e,true)
    e.GameTooltip=mainlineTooltip({failAdd=true})
    custom(a,'r1',body('Alpha',{step('a',91403)}))
    login(a)
    local before=#a.Diagnostics:GetReports()
    registered[2].fn(e.GameTooltip,{id=91403})
    assert(a.TooltipIntegration.failed==true and #a.Diagnostics:GetReports()==before+1,'reported once')
    local report=a.Diagnostics:GetReports()[#a.Diagnostics:GetReports()]
    assert(report.context.module=='tooltips')
    e.GameTooltip=mainlineTooltip();registered[2].fn(e.GameTooltip,{id=91403});assert(#e.GameTooltip.lines==0,'retired')
end)

test('a tooltip callback never reads the tooltip',function()
    local _,a,e=fixture()
    local registered=installProcessor(e,true)
    custom(a,'r1',body('Alpha',{step('a',91403)}))
    login(a)
    local tip=e.GameTooltip
    local reads={}
    setmetatable(tip,{__index=function(_,key) reads[#reads+1]=key end})
    registered[2].fn(tip,{id=91403})
    for _,key in ipairs(reads) do assert(key=='ProcessInfo' or key=='IsForbidden' or key=='AddLine',tostring(key)) end
end)

-- Settings -------------------------------------------------------------------------------------
test('profile validation accepts the tooltip settings and rejects malformed ones',function()
    local c,a=fixture();a.CopySettingsData=function(_,value) return value end;c.load('Core/profile_data.lua')
    for _,good in ipairs({{tooltips=true},{tooltips=false,tooltip_itemsets=false,tooltip_rotations=false,tooltip_conditions=true},{tooltip_limit=1},{tooltip_limit=20}}) do
        assert(a:ValidateProfileTransfer(good),'rejected a good profile')
    end
    for _,bad in ipairs({{tooltips='yes'},{tooltip_itemsets=1},{tooltip_rotations={}},{tooltip_conditions='no'},{tooltip_limit=0},{tooltip_limit=21},{tooltip_limit=2.5},{tooltip_limit='3'},{tooltip_limit=0/0}}) do
        assert(not a:ValidateProfileTransfer(bad),'accepted a bad profile '..tostring(next(bad)))
    end
end)

test('the defaults are in the shipped profile defaults',function()
    local f=io.open('main.lua');local source=f:read('*a');f:close()
    for _,line in ipairs({'tooltips = true,','tooltip_itemsets = true,','tooltip_rotations = true,','tooltip_conditions = false,','tooltip_limit = 3,'}) do
        assert(source:find(line,1,true),line)
    end
end)

-- Nothing but the game's own event installs the tooltip lines at login (the Settings checkbox only refreshes), so a
-- wrong event name here would leave the feature silently dead.
test('the event frame listens for PLAYER_ENTERING_WORLD and the game dispatching it installs the lines',function()
    local _,a,e=fixture()
    local registered=installProcessor(e,true)
    local frame=a.TooltipIntegration.frame
    assert(frame and frame:IsEventRegistered('PLAYER_ENTERING_WORLD'),'the tooltip frame does not register PLAYER_ENTERING_WORLD')
    assert(#registered==0,'the lines were installed before the world was entered')
    frame.scripts.OnEvent(frame,'PLAYER_ENTERING_WORLD')
    assert(#registered==2 and a.TooltipIntegration.installed,'the frame script does not hand PLAYER_ENTERING_WORLD to the manager')
end)

print(string.format('%d passed, %d failed',pass,fail));os.exit(fail>0 and 1 or 0)
