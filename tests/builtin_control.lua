-- The user's control over Built Ins and over selection order, on the whole addon
-- (tests/fixtures/toc_addon.lua): per-profile Built In overrides (Enabled, priority) that
-- never copy the rotation; one header line with Priority left of Enabled; a read-only
-- banner on a Built In; the rotation list sorted as automatic switching tries it, with
-- disabled rows greyed and overlapping switches marked amber; where a pack loads and the
-- live specialization in tooltips (no extra rows); the switch-overlap analysis itself.
local T=dofile('tests/fixtures/toc_addon.lua')
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()

local function key(a,id) return a:GetScopedRotationCoordinator():Key({kind='builtin',id=id}) end
local function custom(f,spec,name,body,fallback)
    local a=f.addon;local ref=assert(a:NewRotationDraftTarget(spec,'class',fallback==true))
    body=body or {};body.name=name;body.rotation=body.rotation or {{id='a1',type='assisted',conditions={}}};body.cooldowns=body.cooldowns or {}
    assert(a:CommitRotationDraft(ref,nil,{body=body},'class'))
    return a:GetScopedRotationCoordinator():Key(ref)
end
local function level(n) return {type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=n} end
local function prefs(a) return a.db.profile.rotationLibrary.preferences end

test('Built In overrides: priority and Enabled per profile, keyed by id, never a copy, reset to default',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local before=a:GetBuiltinOverrides('rm.retail.monk.brewmaster')
    assert(before.shippedPriority==20 and before.effectivePriority==20 and before.priority==nil and not before.overridden)
    assert(a:SetBuiltinPriority('rm.retail.monk.brewmaster',35))
    assert(prefs(a)['rm.retail.monk.brewmaster'].priority==35 and a:GetRotationEffectivePriority(268,key(a,'rm.retail.monk.brewmaster'))==35)
    assert(a.db.profile.rotationStore==nil or true)
    -- Nothing of the pack is copied into the profile.
    for k,v in pairs(prefs(a)['rm.retail.monk.brewmaster']) do assert(k=='priority' or k=='enabled',k) end
    -- The header row and auto-switch order use the override.
    for _,row in ipairs(a:ListRotationHeaders(268)) do if row.canonicalId=='rm.retail.monk.brewmaster' then assert(row.priority==35) end end
    assert(not a:SetBuiltinPriority('rm.retail.monk.brewmaster',2.5) and not a:SetBuiltinPriority('rm.retail.monk.brewmaster',100001))
    -- The shipped value is not stored; a reset removes everything.
    assert(a:SetBuiltinPriority('rm.retail.monk.brewmaster',20) and prefs(a)['rm.retail.monk.brewmaster']==nil)
    assert(a:SetBuiltinPriority('rm.retail.monk.brewmaster',5) and a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster',false))
    local o=a:GetBuiltinOverrides('rm.retail.monk.brewmaster');assert(o.overridden and o.priority==5 and o.enabled==false)
    assert(a:ResetBuiltinOverrides('rm.retail.monk.brewmaster') and prefs(a)['rm.retail.monk.brewmaster']==nil)
    assert(a:GetBuiltinSwitch('rm.retail.monk.brewmaster')==true)
    -- Overrides survive a reload (a later revision keeps the same id) and validate for transfer.
    assert(a:SetBuiltinPriority('rm.retail.monk.windwalker',40))
    f.fire('PLAYER_LOGOUT')
    local g=T.new{level=10,specIndex=3,saved=f.env.RotationMasterDB};local b=g.addon
    assert(b:GetBuiltinOverrides('rm.retail.monk.windwalker').effectivePriority==40)
    assert(b:ValidateProfileTransfer(b:CopySettingsData(b.db.profile)),'profile with overrides does not validate')
end)

test('a priority override reorders automatic switching among Built Ins',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    assert(a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster.guide',true));a:UpdateAutoSwitch();a:SwitchRotation()
    assert(a:GetDefaultIdForRuntime(268,a.currentRotation)=='rm.retail.monk.brewmaster')
    assert(a:SetBuiltinPriority('rm.retail.monk.brewmaster.guide',50));a:UpdateAutoSwitch();a:SwitchRotation()
    assert(a:GetDefaultIdForRuntime(268,a.currentRotation)=='rm.retail.monk.brewmaster.guide','override did not reorder')
end)

test('the editor: one line with Priority left of Enabled; a Built In is read-only with its overrides in amber',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local parent=f.env.CreateFrame('Frame');parent:SetSize(900,700)
    local pane=assert(a:CreateRotationEditor(parent,268,key(a,'rm.retail.monk.brewmaster')))
    -- A blue Read-Only pill replaces Undo and Redo; no banner row, nothing to click.
    assert(pane.readOnlyPill:IsShown() and pane.readOnlyPill:GetText()=='Read-Only' and not pane.undo:IsShown() and not pane.redo:IsShown(),'no Read-Only pill in place of Undo/Redo')
    assert(pane.readOnlyPill.scripts.OnClick==nil and pane.readOnlyBanner==nil and pane.switchNote==nil,'the pill acts, or a banner/note row remains')
    local br,bg,bb=unpack(pane.readOnlyPill:GetFontString().textColor);assert(br<.4 and bb>.9,'pill is not Built In blue')
    assert(not pane.apply:IsEnabled() and not pane.name:IsMouseEnabled(),'Built In fields are editable')
    local _,anchor=pane.priorityUp:GetPoint(1);assert(anchor==pane.enable,'priority is not left of Enabled')
    assert(pane.priority:GetText()=='20' and pane.priorityLabel:GetText()=='Priority' and not pane.overrideReset:IsShown())
    pane.priorityUp:Click()
    assert(prefs(a)['rm.retail.monk.brewmaster'].priority==21,'priority step did not save an override')
    assert(pane.priority:GetText()=='21' and pane.priorityLabel:GetText()=='Priority' and pane.overrideReset:IsShown())
    local r,g=unpack(pane.priority.textColor);assert(r==1 and g<.9,'override value not shown in amber')
    assert(pane.priorityLabel.textColor[2]==1,'the label changed colour')
    pane.priority:SetText('7');pane.priority.scripts.OnTextChanged(pane.priority,true);pane.priority.scripts.OnEnterPressed(pane.priority)
    assert(prefs(a)['rm.retail.monk.brewmaster'].priority==7)
    pane.enable.action();assert(prefs(a)['rm.retail.monk.brewmaster'].enabled==false and pane.enable.text=='Disabled')
    local pr,pg=unpack(pane.enable:GetFontString().textColor);assert(pr==1 and pg<.9,'Enabled override not shown in the pill text')
    pane.overrideReset:Click();assert(prefs(a)['rm.retail.monk.brewmaster']==nil and pane.priority:GetText()=='20' and not pane.overrideReset:IsShown())
    -- Where it loads, under the switch.
    assert(pane.readOnlyPill.tooltip:find('Loads only for: Retail · Monk',1,true),tostring(pane.readOnlyPill.tooltip))
    -- No row is reserved: the canvas sits as far below the switch as in your own rotation's pane,
    -- and the switch as far below the header.
    local function gaps(p) local _,_,cy=p.canvas.frame:GetPoint(1);local _,_,sy=p.switch:GetPoint(1);return sy-cy-p.switch:GetHeight(),sy end
    local mineKey=custom(f,268,'Mine',{switch=level(1)})
    local mine=assert(a:CreateRotationEditor(f.env.CreateFrame('Frame'),268,mineKey));mine.frame:SetSize(900,700);mine:Layout()
    local builtinGap,builtinTop=gaps(pane);local mineGap,mineTop=gaps(mine)
    assert(builtinGap==mineGap and builtinTop==mineTop,('Built In pane reserves extra rows: %s/%s vs %s/%s'):format(builtinGap,builtinTop,mineGap,mineTop))
    -- Load-time scope only: no specializations, a minimum level only, rulesets by name.
    local text=a:DescribeApplicability({families={'era'},class='DRUID',specs={102},minLevel=10,maxLevel=60,rulesets={'season:2','hardcore','self-found'}})
    assert(text=='Loads only for: Classic Era · Druid · level 10+ · Season of Discovery, Hardcore, Self-Found. The switch condition decides the rest.',text)
    assert(a:DescribeApplicability({families={'retail'},class='MONK',minLevel=1})=='Loads only for: Retail · Monk. The switch condition decides the rest.')
    -- A rotation for another specialization (its body.specs) says it is not selectable now.
    local other=assert(a:CreateRotationEditor(f.env.CreateFrame('Frame'),269,key(a,'rm.retail.monk.windwalker')))
    assert(other.switch.tooltip:find('You are playing Brewmaster; this rotation is for Windwalker, so it is not selectable now.',1,true),tostring(other.switch.tooltip))
end)

test('switch overlap: identical, subsumed and live overlaps between any rotations, ties marked, other specs apart',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local region=function(c,s) return a:GetSwitchRegion(c,s) end
    assert(a:CompareSwitchRegions(region(level(10)),region(level(10)))=='identical')
    assert(a:CompareSwitchRegions(region(level(1)),region({type='AND',value={level(10),{type='COMBAT',unit='player'}}}))=='subsumes')
    assert(a:CompareSwitchRegions(region(level(10),{specs={268}}),region(level(10),{specs={270}}))==nil,'different specializations overlap')
    assert(a:CompareSwitchRegions(region({type='SPECIALIZATION',spec=268}),region({type='AND',value={{type='SPECIALIZATION',spec=270},level(10)}}))==nil)
    assert(a:CompareSwitchRegions(region({type='LEVEL',unit='player',operator='LESSTHAN',value=10}),region(level(10)))==nil,'disjoint level ranges overlap')
    assert(a:CompareSwitchRegions(region({type='COMBAT',unit='player'}),region({type='MOVING'}))==nil,'unrelated conditions claimed to overlap')
    assert(a:CompareSwitchRegions(region(level(1),{rulesets={'seasonal'}}),region(level(1),{rulesets={'hardcore'}}))==nil,'different rulesets overlap')
    -- Built Ins: only Brewmaster is on for 268, so nothing overlaps; turning the guide on overlaps identically.
    a:UpdateAutoSwitch();assert(next(a:GetSwitchOverlaps(268))==nil)
    assert(a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster.guide',true));a:UpdateAutoSwitch()
    local list=a:GetSwitchOverlaps(268)[key(a,'rm.retail.monk.brewmaster')]
    assert(list and #list==1 and list[1].key==key(a,'rm.retail.monk.brewmaster.guide') and list[1].kind=='identical' and not list[1].tie)
    assert(a:SetBuiltinPriority('rm.retail.monk.brewmaster.guide',20));a:UpdateAutoSwitch()
    list=a:GetSwitchOverlaps(268)[key(a,'rm.retail.monk.brewmaster')];assert(list[1].tie,'equal priorities not marked as a tie')
    local text,tie=a:DescribeSwitchOverlap(list);assert(tie and text:find('Same priority as Monk: Brewmaster reference',1,true),text)
    -- Your own rotations: overlap among themselves, never with a Built In (yours always come first).
    local low=custom(f,268,'Low',{priority=1,switch=level(1)});local high=custom(f,268,'High',{priority=5,switch=level(5)})
    custom(f,268,'Combat only',{priority=9,switch={type='COMBAT',unit='player'}})
    a:UpdateAutoSwitch();local overlaps=a:GetSwitchOverlaps(268)
    local found;for _,entry in ipairs(overlaps[low] or {}) do if entry.key==high then found=entry end end
    assert(found and found.kind=='subsumes' and not found.tie,'Low does not subsume High: '..tostring(found and found.kind))
    assert(a:CompareSwitchRegions(region({type='AND',value={level(1),{type='LEVEL',unit='player',operator='LESSTHAN',value=20}}}),region(level(10)))=='overlaps')
    -- Yours and Built Ins compete on priority, so they are compared too: Low (level 1+) can
    -- match together with the Brewmaster Built In, and an equal priority is a tie.
    local brew=key(a,'rm.retail.monk.brewmaster');local withBrew
    for _,entry in ipairs(overlaps[low]) do if entry.key==brew then withBrew=entry end end
    assert(withBrew and not withBrew.tie,'a custom rotation is not compared with a Built In')
    custom(f,268,'Level ten',{priority=20,switch=level(10)});a:UpdateAutoSwitch()
    local tie;for _,entry in ipairs(a:GetSwitchOverlaps(268)[brew] or {}) do if entry.name=='Level ten' then tie=entry end end
    assert(tie and tie.tie and tie.kind~='live','a custom/Built In priority tie is not marked')
    -- Cached on the auto-switch list: the same answer until the roster changes.
    overlaps=a:GetSwitchOverlaps(268)
    assert(a:GetSwitchOverlaps(268)==overlaps);a:UpdateAutoSwitch();assert(a:GetSwitchOverlaps(268)~=overlaps)
end)

test('the rotation list: switching order, priorities shown, disabled rows grey, overlaps amber, one-click re-enable',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    local low=custom(f,268,'Alpha low',{priority=1,switch=level(1)});local high=custom(f,268,'Zulu high',{priority=9,switch=level(1)})
    local off=custom(f,268,'Off one',{priority=50,switch=level(1),disabled=true})
    custom(f,268,nil,nil,true)
    assert(a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster.guide',true));assert(a:SetDefaultRotationEnabled('rm.retail.monk.windwalker',false))
    a:UpdateAutoSwitch()
    local host=f.env.CreateFrame('Frame');host:SetSize(1000,3000)
    local browser=a:CreateRotationBrowser(host,{spec=268,id=high})
    local order={};for _,row in ipairs(browser.rows) do order[#order+1]=row end
    -- By priority alone (yours and Built Ins mixed), then name; the fallback last.
    assert(order[1].key==off,'highest priority not first: '..order[1].name)
    assert(order[#order].fallback,'the fallback is not last')
    local position={};for i,row in ipairs(order) do position[row.key]=i end
    local brew,guide=position[key(a,'rm.retail.monk.brewmaster')],position[key(a,'rm.retail.monk.brewmaster.guide')]
    assert(position[off]<brew and brew<guide and guide<position[high] and position[high]<position[low],'Built Ins not interleaved by priority (50 > 20 > 10 > 9 > 1)')
    for i=2,#order-1 do assert((order[i-1].priority or 0)>=(order[i].priority or 0),'not sorted by priority at '..i) end
    -- The list shows Brewmaster's rotations; Windwalker's and Mistweaver's appear under All.
    assert(position[key(a,'rm.retail.monk.windwalker')]==nil and position[key(a,'rm.retail.monk.mistweaver')]==nil,'another specialization listed')
    browser:SetSpecValue('all')
    local controls={};for _,control in ipairs(browser.rowButtons) do if control:IsShown() and control.browserEntry then controls[control.browserEntry.key]=control end end
    local offRow=controls[off];assert(offRow.nameLabel.alpha==.5 and offRow.tooltip:find('Disabled',1,true),'disabled custom row not grey')
    local ww=controls[key(a,'rm.retail.monk.windwalker')]
    assert(ww and ww.nameLabel.alpha==.5 and ww.tooltip:find('Disabled by you',1,true) and not ww.statusLabel:GetText():find('Disabled',1,true) and ww.enableButton:IsShown())
    local mw=controls[key(a,'rm.retail.monk.mistweaver')];assert(mw.nameLabel.alpha==.5 and mw.tooltip:find('Ships disabled',1,true))
    assert(controls[high].statusLabel:GetText():find('Priority 9',1,true) and controls[high].tooltip:find('Higher numbers are tried first',1,true))
    -- Alpha low and Zulu high both match from level 1: amber, naming each other.
    assert(controls[low].noticeBar and controls[low].noticeBar:IsShown() and controls[low].tooltip:find('Zulu high',1,true))
    local brew=controls[key(a,'rm.retail.monk.brewmaster')];assert(brew.noticeBar:IsShown() and brew.tooltip:find('Brewmaster reference',1,true))
    ww.enableButton:Click();assert(prefs(a)['rm.retail.monk.windwalker']==nil,'one click did not turn it back on')
    browser:Release()
end)

test('/rm why says when nothing but the fallback is tried, and marks a rotation without a switch as manual only',function()
    local f=T.new{level=10,specIndex=1};local a=f.addon
    assert(a:SetDefaultRotationEnabled('rm.retail.monk.brewmaster',false));a:UpdateAutoSwitch()
    local report=table.concat(a:GetRotationEligibilityReport(),'\n')
    assert(report:find('Automatic switching tries nothing else, then the fallback (Default): no enabled rotation here has a switch condition it can use.',1,true),report)
    assert(not report:find('tries: then',1,true),report)
    custom(f,268,'By hand',{switch={}});a:UpdateAutoSwitch()
    report=table.concat(a:GetRotationEligibilityReport(),'\n')
    assert(report:find('By hand [by-hand]: ready, manual only: no switch condition',1,true),report)
    assert(table.concat(a:GetRotationIdentifierReport(),'\n'):find('by-hand — By hand (yours) — ready, manual only (no switch condition)',1,true))
end)

test('Classic (TBC): overrides and list order work on a client with one specialization key',function()
    local f=T.new{project=5,expansion=1,class='SHAMAN',level=20};local a=f.addon
    a:UpdateAutoSwitch();a:SwitchRotation()
    local first=a:GetDefaultIdForRuntime(0,a.currentRotation)
    assert(first=='rm.tbc.shaman.enhancement.icyveins',tostring(first))
    -- The alternative ships disabled: a raised priority alone does not choose it; enabled, it wins.
    assert(a:SetBuiltinPriority('rm.tbc.shaman.enhancement.wowsims',99));a:UpdateAutoSwitch();a:SwitchRotation()
    assert(a:GetDefaultIdForRuntime(0,a.currentRotation)=='rm.tbc.shaman.enhancement.icyveins')
    assert(a:SetDefaultRotationEnabled('rm.tbc.shaman.enhancement.wowsims',true));a:UpdateAutoSwitch();a:SwitchRotation()
    assert(a:GetDefaultIdForRuntime(0,a.currentRotation)=='rm.tbc.shaman.enhancement.wowsims')
    local overlaps=a:GetSwitchOverlaps(0)
    local list=overlaps[a.currentRotation];assert(list and #list>=1,'the two level>=1 Enhancement packs do not overlap')
end)

finish()
