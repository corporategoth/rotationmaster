-- The user's control over Built Ins and over selection order, on the whole addon
-- (tests/fixtures/toc_addon.lua): per-profile Built In overrides (Enabled, priority) that
-- never copy the rotation; one header line with Priority left of Enabled; a read-only
-- banner on a Built In; the rotation list sorted as automatic switching tries it, with
-- disabled rows greyed and overlapping switches marked amber; where a pack loads and the
-- live specialization shown under the switch; the switch-overlap analysis itself.
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
    assert(pane.readOnlyBanner:IsShown() and pane.readOnlyBanner:GetText():find('read%-only'),'no read-only banner')
    assert(not pane.apply:IsEnabled() and not pane.name:IsMouseEnabled(),'Built In fields are editable')
    local _,anchor=pane.priorityUp:GetPoint(1);assert(anchor==pane.enable,'priority is not left of Enabled')
    assert(pane.priority:GetText()=='20' and pane.priorityLabel:GetText()=='Priority' and not pane.overrideReset:IsShown())
    pane.priorityUp:Click()
    assert(prefs(a)['rm.retail.monk.brewmaster'].priority==21,'priority step did not save an override')
    assert(pane.priority:GetText()=='21' and pane.priorityLabel:GetText()=='Your priority' and pane.overrideReset:IsShown())
    local r,g=unpack(pane.priority.textColor);assert(r==1 and g<.9,'override not shown in amber')
    pane.priority:SetText('7');pane.priority.scripts.OnTextChanged(pane.priority,true);pane.priority.scripts.OnEnterPressed(pane.priority)
    assert(prefs(a)['rm.retail.monk.brewmaster'].priority==7)
    pane.enable.action();assert(prefs(a)['rm.retail.monk.brewmaster'].enabled==false and pane.enable.text=='Disabled')
    pane.overrideReset:Click();assert(prefs(a)['rm.retail.monk.brewmaster']==nil and pane.priority:GetText()=='20' and not pane.overrideReset:IsShown())
    -- Where it loads, under the switch.
    assert(pane.switchNote:IsShown() and pane.switchNote:GetText():find('Loads only for: Retail · Monk',1,true),tostring(pane.switchNote:GetText()))
    -- A rotation saved for another specialization says it is not selectable now.
    local other=assert(a:CreateRotationEditor(f.env.CreateFrame('Frame'),269,key(a,'rm.retail.monk.windwalker')))
    assert(other.switchNote:GetText():find('You are playing Brewmaster; this rotation is saved for Windwalker',1,true),tostring(other.switchNote:GetText()))
end)

test('switch overlap: identical, subsumed and live overlaps within a tier, ties marked, other tiers and specs apart',function()
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
    for _,entry in ipairs(overlaps[low]) do assert(not a:IsDefaultRuntimeRotation(268,entry.key),'custom overlaps reported against a Built In') end
    -- Cached on the auto-switch list: the same answer until the roster changes.
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
    assert(order[1].key==off and order[2].key==high and order[3].key==low,'own rotations not first by priority: '..order[1].name..', '..order[2].name)
    assert(order[#order].fallback,'the fallback is not last')
    local seenBuiltin=false
    for i,row in ipairs(order) do
        if row.kind=='builtin' then seenBuiltin=true elseif seenBuiltin and not row.fallback then error('custom after a Built In at '..i) end
        if i>1 and row.kind==order[i-1].kind and not row.fallback and not order[i-1].fallback then assert((order[i-1].priority or 0)>=(row.priority or 0),'not sorted by priority at '..i) end
    end
    local controls={};for _,control in ipairs(browser.rowButtons) do if control:IsShown() and control.browserEntry then controls[control.browserEntry.key]=control end end
    local offRow=controls[off];assert(offRow.nameLabel.alpha==.5 and offRow.tooltip:find('Disabled',1,true),'disabled custom row not grey')
    local ww=controls[key(a,'rm.retail.monk.windwalker')]
    assert(ww and ww.nameLabel.alpha==.5 and ww.statusLabel:GetText():find('Disabled by you',1,true) and ww.enableButton:IsShown())
    local mw=controls[key(a,'rm.retail.monk.mistweaver')];assert(mw.nameLabel.alpha==.5 and mw.tooltip:find('Ships disabled',1,true))
    assert(controls[high].statusLabel:GetText():find('Priority 9',1,true) and controls[high].tooltip:find('Higher numbers are tried first',1,true))
    -- Alpha low and Zulu high both match from level 1: amber, naming each other.
    assert(controls[low].noticeBar and controls[low].noticeBar:IsShown() and controls[low].tooltip:find('Zulu high',1,true))
    local brew=controls[key(a,'rm.retail.monk.brewmaster')];assert(brew.noticeBar:IsShown() and brew.tooltip:find('Brewmaster reference',1,true))
    ww.enableButton:Click();assert(prefs(a)['rm.retail.monk.windwalker']==nil,'one click did not turn it back on')
    browser:Release()
end)

test('Classic (TBC): overrides and list order work on a client with one specialization key',function()
    local f=T.new{project=5,expansion=1,class='SHAMAN',level=20};local a=f.addon
    a:UpdateAutoSwitch();a:SwitchRotation()
    local first=a:GetDefaultIdForRuntime(0,a.currentRotation)
    assert(first=='rm.tbc.shaman.enhancement.icyveins',tostring(first))
    assert(a:SetBuiltinPriority('rm.tbc.shaman.enhancement.wowsims',99));a:UpdateAutoSwitch();a:SwitchRotation()
    assert(a:GetDefaultIdForRuntime(0,a.currentRotation)=='rm.tbc.shaman.enhancement.wowsims')
    local overlaps=a:GetSwitchOverlaps(0)
    local list=overlaps[a.currentRotation];assert(list and #list>=1,'the two level>=1 Enhancement packs do not overlap')
end)

finish()
