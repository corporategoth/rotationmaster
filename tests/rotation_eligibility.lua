-- Why a rotation can or cannot be selected, said in plain words.
--
-- The user's report (Retail 12.0.5, a level-4 Monk): a custom fallback with a
-- single "Blizzard's suggestion" step, no conditions and no cooldowns, was
-- refused by /rm set Default. Below level 10 a Retail character has chosen no
-- specialization: GetSpecialization() answers the class's initial spec, an
-- index past GetNumSpecializationsForClassID (Blizzard's UnitUtil
-- IsInitialSpec), with its own spec ID (Monk 1450, Shaman 1444). RM runs and
-- stores rotations under that ID, but the editor offered only the class's
-- chosen specs and silently opened on the first of them, so the fallback was
-- saved under a spec RM never reads at that level. The editor now offers the
-- initial spec as its own entry, "No specialization (levels 1-9)", with its
-- own rotations; class-wide Built Ins (no specs selector) apply there too.
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local root=assert(io.popen('pwd'):read('*l'))
local DEFAULT -- the addon's global, read from the fixture's environment

-- Retail specialization API for a character of `classID` at `index` (5 is the
-- initial spec below level 10).
local SPECS={[10]={{268,'Brewmaster'},{270,'Mistweaver'},{269,'Windwalker'},initial={1450,'Initial'}},
    [7]={{262,'Elemental'},{263,'Enhancement'},{264,'Restoration'},initial={1444,'Initial'}}}
local function retailSpecs(env,classID,index,options)
    options=options or {}
    local list=SPECS[classID]
    local function info(i) local entry=i==5 and list.initial or list[i];if entry then return entry[1],options.unnamed and '' or entry[2],'',1,'DAMAGER' end end
    env.C_SpecializationInfo={GetSpecialization=function() return index end,GetSpecializationInfo=info,
        GetNumSpecializationsForClassID=function(class) return #SPECS[class] end}
    env.GetSpecializationInfoForClassID=function(class,i) local entry=SPECS[class][i];if entry then return entry[1],entry[2],'',1,'DAMAGER' end end
    env.UnitClass=function() return 'Class','TOKEN',options.playerClass or classID end
end

test('Retail below level 10: the editor offers the initial spec RM runs, and /rm why names it',function()
    local f=F.new(1,12,'MONK');f.load('Platform/client.lua');f.load('Platform/specializations.lua');f.load('UI/settings_setup.lua');f.load('Core/rotation_selection.lua')
    local a=f.addon;a.db.char=a.db.char or {};a.db.char.specs=a.db.char.specs or {}
    retailSpecs(f.env,10,5);f.env.UnitLevel=function() return 4 end
    local selection=assert(a.Platform:GetRotationSpecialization())
    assert(selection.key==1450 and selection.index==5,'runtime spec '..tostring(selection.key))
    local function listed() local ids={};for _,entry in ipairs(a:GetRotationEditorSpecs(10)) do ids[#ids+1]=entry.id..'='..entry.name end;return table.concat(ids,',') end
    assert(listed()=='268=Brewmaster,270=Mistweaver,269=Windwalker,1450=No specialization (levels 1-9)',listed())
    a.currentSpec=selection.key;assert(a:GetUnofferedRotationSpec()==nil)
    local report=table.concat(a:GetRotationEligibilityReport(),'\n')
    assert(report:find('Specialization: No specialization (levels 1-9) (1450), level 4',1,true),report)
    assert(not report:find('have not chosen',1,true),report)
    -- After choosing Windwalker at 10 the initial entry stays offered (its
    -- rotations are kept) and RM runs Windwalker.
    retailSpecs(f.env,10,3);a.currentSpec=a.Platform:GetRotationSpecialization().key
    assert(a.currentSpec==269 and listed()=='268=Brewmaster,270=Mistweaver,269=Windwalker,1450=No specialization (levels 1-9)')
    -- The live initial spec ID wins over the known one; another class's list
    -- carries that class's initial spec.
    retailSpecs(f.env,10,5);local info=f.env.C_SpecializationInfo.GetSpecializationInfo
    f.env.C_SpecializationInfo.GetSpecializationInfo=function(i) if i==5 then return 9999,'Initial' end;return info(i) end
    assert(a.Platform:GetRotationSpecializations(10)[4].id==9999)
    assert(a.Platform:GetRotationSpecializations(7)[4].id==1444)
    assert(a.Platform:IsInitialSpecialization(1450) and not a.Platform:IsInitialSpecialization(269))
    -- Forever names one specialization per class and has no initial stage.
    local forever=F.new(18,12,'MONK');forever.load('Platform/client.lua');forever.load('Platform/specializations.lua')
    forever.env.C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return 1450,'Monk' end,GetNumSpecializationsForClassID=function() return 1 end}
    forever.env.GetSpecializationInfoForClassID=function() return 1450,'Monk' end;forever.env.UnitClass=function() return 'Monk','MONK',10 end
    assert(#forever.addon.Platform:GetRotationSpecializations(10)==1 and not forever.addon.Platform:IsInitialSpecialization(1450))
end)

-- Whole poll on the real addon (TOC-order fixture), Retail rules: secret
-- cooldown times, Blizzard's Assisted Combat, and the initial spec 1444.
local SECRET=setmetatable({},{__tostring=function() return 'secret' end})
local function wholePoll()
    local c=assert(loadfile('tests/fixtures/wholepoll_shaman.lua'))('price',root,true,root,true)({target=true,combat=true,buttons=true,poll=.15})
    c.load('Platform/assisted_combat.lua')
    local a,e=c.a,c.e
    e.issecretvalue=function(v) return rawequal(v,SECRET) end;e.canaccessvalue=function(v) return not rawequal(v,SECRET) end
    a.Platform.secretsUnrestricted=false
    a.Platform.CanReadValue=function(_,v) if rawequal(v,SECRET) then return false,'restricted-value' end;return true end
    local state={next=8042}
    e.C_AssistedCombat={IsAvailable=function() return true,'' end,GetNextCastSpell=function() return state.next end,GetRotationSpells=function() return {} end,GetActionSpell=function() return nil end}
    e.C_Spell.GetSpellCooldown=function() return {startTime=SECRET,duration=SECRET,modRate=SECRET,isEnabled=true,isActive=false,isOnGCD=false} end
    local warnings={};a.warn=function(_,format,...) warnings[#warnings+1]=string.format(format,...) end
    a.info=function() end
    DEFAULT=e.DEFAULT
    return c,a,e,warnings,state
end
local function save(a,spec,id,body)
    local reference={kind='custom',address={scope='class',class='SHAMAN',owner='SHAMAN',spec=spec,id=id}}
    assert(a:CommitRotationDraft(reference,nil,{body=body},'class'))
end
local function assisted() return {name='Default',priority=0,cooldowns={},rotation={{id='blizzard',type='assisted',conditions={}}}} end
local function enterInitialSpec(a)
    -- The editor's specs as Retail lists them, the initial spec included.
    a.GetRotationEditorSpecs=function() return {{id=262,name='Elemental'},{id=263,name='Enhancement'},{id=264,name='Restoration'},{id=1444,name='No specialization (levels 1-9)',initial=true}} end
    a:DisableRotation();a.currentSpec=1444;a.manualRotation=false
end

test('repro: a one-step Blizzard suggestion fallback saved under a chosen spec is refused below level 10, and the reason says so',function()
    local c,a,_,warnings=wholePoll();local fallback=a.db.profile.rotationFallbackID
    enterInitialSpec(a)
    save(a,262,fallback,assisted()) -- where the browser used to open, and the user's fallback landed
    a:HandleCommand('set '..DEFAULT)
    assert(a.currentRotation==nil,'refused fallback became active')
    local text=table.concat(warnings,'\n');if os.getenv('RM_SHOW') then print(text) end
    assert(text:find('The fallback rotation is unavailable',1,true),text)
    assert(text:find('no fallback rotation is saved for No specialization (levels 1-9) (there is one for Elemental).',1,true),'reason not named: '..text)
    assert(text:find('/rm why',1,true))
    c.tick()
end)

test('a level-4 Retail fallback with one Blizzard suggestion step, saved under the initial spec, is active and highlights',function()
    local c,a,_,warnings,state=wholePoll();local fallback=a.db.profile.rotationFallbackID
    enterInitialSpec(a)
    save(a,1444,fallback,assisted());a:HandleCommand('set '..DEFAULT)
    assert(a.currentRotation==DEFAULT,'fallback refused: '..table.concat(warnings,'\n'))
    for _=1,3 do c.tick() end
    assert(a.currentSpell==8042 and a:IsGlowing(8042),'suggestion not highlighted: '..tostring(a.currentSpell))
    state.next=403;c.tick();assert(a.currentSpell==403)
    assert(#warnings==0,table.concat(warnings,'\n'))
    assert(a:ExplainRotationRefusal(1444,DEFAULT)==nil)
end)

test('below level 10 an initial-spec rotation auto-selects and a chosen-spec one does not; at 10 the chosen spec applies',function()
    local _,a,_,warnings=wholePoll()
    enterInitialSpec(a)
    local function switched(name) local body={name=name,priority=10,switch={type='COMBAT',unit='player'},cooldowns={},rotation={{id='blizzard',type='assisted',conditions={}}}};return body end
    save(a,1444,'starter',switched('Starter'));save(a,262,'elemental',switched('Elemental only'))
    a.db.profile.disable_autoswitch=false
    a:UpdateAutoSwitch();a:SwitchRotation()
    assert(a.currentRotation and a:GetRotationName(a.currentRotation)=='Starter','below 10: '..tostring(a.currentRotation and a:GetRotationName(a.currentRotation))..' '..table.concat(warnings,'; '))
    assert(a:ExplainRotationRefusal(1444,'elemental')~=nil,'a chosen-spec rotation is selectable below 10')
    -- Level 10, Elemental chosen.
    a:DisableRotation();a.currentSpec=262;a.manualRotation=false;a:UpdateAutoSwitch();a:SwitchRotation()
    assert(a.currentRotation and a:GetRotationName(a.currentRotation)=='Elemental only','at 10: '..tostring(a.currentRotation))
end)

test('a class-wide Built In (no specs selector) applies below level 10; one for a chosen spec does not',function()
    local _,a=wholePoll();enterInitialSpec(a)
    local function row(spec,id) for _,entry in ipairs(a:ListDefaultRotations(spec)) do if entry.id==id then return entry end end end
    local classWide=assert(row(1444,'rm.tbc.shaman.starter'))
    assert(classWide.applicability.specs==nil and classWide.eligible,'class-wide pack not eligible in the initial spec: '..tostring(classWide.eligibilityReason))
    assert(row(262,'rm.tbc.shaman.starter').eligible)
    -- The same pack aimed at a chosen spec is held back below 10 and offered at 10;
    -- a pack aimed at the initial spec (specs={1444}) is the reverse.
    local view=row(1444,'rm.tbc.shaman.starter')
    local function envelope(id,specs) local e={format='RotationMaster',schemaVersion=1,id=id,revision=1,nameKey='N',descriptionKey='D',
        applicability={families={'tbc'},actionContext='player',class='SHAMAN',specs=specs},body=view.envelope.body};return e end
    assert(a:RegisterDefaultRotation(envelope('test.elemental',{262})));assert(a:RegisterDefaultRotation(envelope('test.initial',{1444})))
    assert(a:InitializeRotationLibrary())
    local elemental,initial=row(1444,'test.elemental'),row(1444,'test.initial')
    assert(not elemental.eligible and elemental.eligibilityReason=='specialization-mismatch' and initial.eligible)
    assert(row(262,'test.elemental').eligible and not row(262,'test.initial').eligible)
end)

-- Retail keeps health secret (Core/condition_support.lua): a cooldown that
-- reads it is unresolved. This client models that declaration.
local function secretHealth(c,a)
    if type(a.GetConditionSupport)~='function' then c.load('Core/condition_support.lua') end
    a.conditionDefinitions.HEALTHPCT.supported=function() return 'secret-health' end
    a.conditionRegistryVersion=(a.conditionRegistryVersion or 0)+1
end
local function brokenCooldown()
    return {name='Broken cooldown',priority=5,switch={type='COMBAT',unit='player'},
        rotation={{id='bolt',type='spell',action=403,conditions={}}},
        cooldowns={{id='shock',type='spell',action=8042,conditions={type='HEALTHPCT',unit='target',operator='LESSTHAN',value=0.2}}}}
end

test('a refused rotation names the step and the reason in plain words, for set by name and for the fallback',function()
    local c,a,_,warnings=wholePoll();secretHealth(c,a)
    local fallback=a.db.profile.rotationFallbackID
    local body=brokenCooldown();body.name='Default';body.switch={}
    save(a,0,fallback,body);save(a,0,'broken',brokenCooldown())
    a:DisableRotation();a.manualRotation=false;a:HandleCommand('set '..DEFAULT)
    local text=table.concat(warnings,'\n');if os.getenv('RM_SHOW') then print(text) end
    assert(text:find('Cooldown 1 (Spell 8042): Health Percentage',1,true) or text:find('Cooldown 1 (Spell 8042): ',1,true),text)
    assert(text:find('health is secret on this client',1,true),text)
    warnings[#warnings]=nil;warnings[#warnings]=nil
    a:HandleCommand('set Broken cooldown')
    text=table.concat(warnings,'\n')
    assert(text:find('Rotation Broken cooldown cannot be selected',1,true) and text:find('Cooldown 1',1,true),'set by name: '..text)
    local why,code=a:ExplainRotationRefusal(0,DEFAULT);assert(code=='invalid-fallback' and why:find('Cooldown 1',1,true))
    -- A Branch child carries its own place.
    local nested={name='Nested',priority=1,switch={},cooldowns={},rotation={{id='b',type='branch',conditions={},onTrue={},
        onFalse={{id='inner',type='spell',action=324,conditions={type='HEALTHPCT',unit='player',operator='LESSTHAN',value=0.5}}}}}}
    save(a,0,'nested',nested)
    why=a:ExplainRotationRefusal(0,'nested');assert(why and why:find('Rotation step 1 › No 1 (Spell 324)',1,true),tostring(why))
    -- Disabled is not a validation issue, and says so.
    local disabled=assisted();disabled.name='Off';disabled.disabled=true;save(a,0,'off',disabled)
    assert(a:ExplainRotationRefusal(0,'off')=='it is disabled')
    c.tick()
end)

test('/rm why lists every rotation with its first blocking issue, in a copyable window when long',function()
    local c,a=wholePoll();secretHealth(c,a)
    save(a,0,'broken',brokenCooldown())
    local shown;a.ShowConditionText=function(_,text,heading) shown={text=text,heading=heading} end
    local printed={};a.print=function(_,format,...) printed[#printed+1]=select('#',...)>0 and string.format(format,...) or format end
    a:HandleCommand('why')
    assert(shown and shown.heading=='Why rotations are or are not selected','long report not windowed')
    assert(#printed==1 and printed[1]:find('window',1,true))
    if os.getenv('RM_SHOW') then print(shown.text) end
    local lines={};for line in shown.text:gmatch('[^\n]+') do lines[#lines+1]=line end
    assert(lines[1]:find('^Specialization: ') and lines[2]:find('^Active rotation: '),shown.text)
    assert(shown.text:find('Fallback (Default): cannot be selected, no fallback rotation is saved for',1,true),shown.text)
    assert(shown.text:find('Broken cooldown [broken-cooldown]: cannot be selected, Cooldown 1 (Spell 8042): ',1,true),shown.text)
    assert(shown.text:find('Copy of Shaman: early leveling [copy-of-shaman-early-leveling]: ready',1,true),shown.text)
    -- The roster rows carry the same first issue for the browser's red marker.
    local broken,ready
    for _,row in ipairs(a:ListRotationHeaders(0)) do if row.name=='Broken cooldown' then broken=row elseif row.name=='Copy of Shaman: early leveling' then ready=row end end
    assert(broken.problem and broken.problem.code=='unsupported-condition' and broken.problem.path=='$.body.cooldowns[1].conditions.type' and broken.validationState=='unresolved')
    assert(ready.problem==nil and ready.validationState=='valid')
    -- A short report goes to chat.
    a.GetRotationEligibilityReport=function() return {'one','two'} end
    shown=nil;printed={};a:HandleCommand('why');assert(not shown and #printed==2 and printed[1]=='one')
end)

-- The editor marks the Rotation and Cooldowns tabs from the validation it
-- already ran, so a cooldown problem shows while the rotation list is in view.
local HEALTH={fields={unit='string',operator='string',value='number'},description='Health Percentage'}
local function editor(rotations,builtinBody)
    local f=F.new();local a=f.addon;local _,create=dofile('tests/fixtures/native_ui.lua')(f.env)
    dofile('tests/fixtures/spell_editbox.lua')(f,create)
    a.db.profile.rotations={[0]=rotations};a.configPaneGeneration=1
    a.conditionDefinitions={HEALTHPCT=HEALTH}
    local options={conditions=a.conditionDefinitions,support=function(tag) if tag=='HEALTHPCT' then return 'secret-health' end end}
    function a:GetEditableRotation(spec,id) return self.db.profile.rotations[spec] and self.db.profile.rotations[spec][id] end
    function a:GetDefaultIdForRuntime(_,id) if id=='builtin' then return 'pack' end end
    function a:ListDefaultRotations() return {{id='pack',runtimeKey='builtin',name='Pack',description='Preview',enabled=true,envelope={body=builtinBody}}} end
    function a:GetImportValidationOptions() return options end
    function a:GetRotationValidationOptions() return options end
    function a:validateCondition() return true end
    a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.EvaluateNextAction=function() end
    for _,file in ipairs({'Platform/spells.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/rotation_draft.lua','Data/validation.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','Core/rotation_tags.lua','Core/rotation_canvas.lua','Core/condition_support.lua','Core/rotation_selection.lua','UI/window.lua',
        'UI/rotation_cards.lua','UI/rotation_canvas.lua','UI/color_picker.lua','UI/rotation_effect_fields.lua','UI/rotation_fields.lua','UI/rotation_navigation.lua','UI/rotation_metadata.lua','UI/rotation_view.lua','UI/rotation_editor.lua'}) do f.load(file) end
    dofile('tests/fixtures/rotation_header_backend.lua')(a,f.env.DEFAULT,f.env.NEW)
    local parent=create('Frame');parent:SetSize(740,600)
    return a,parent
end
local function health(unit) return {type='HEALTHPCT',unit=unit or 'target',operator='LESSTHAN',value=0.2} end
local function marked(button) return button.problemText~=nil and button.problemEdges and button.problemEdges[1]:IsShown() end
local function cardFor(pane,id) for _,card in ipairs(pane.canvas.cards) do if card.model and card.model.id==id and card.frame:IsShown() then return card end end end

test('editor: a cooldown-only issue marks Cooldowns red and leaves Rotation green, with the issue in the tooltip',function()
    local a,parent=editor({mine={name='Mine',switch={},rotation={{id='green',type='spell',action=403,conditions={}}},
        cooldowns={{id='broken',type='spell',action=8042,conditions=health()}}}})
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'))
    assert(pane.view.section=='rotation' and cardFor(pane,'green') and not cardFor(pane,'green').model.invalid,'rotation card not green')
    assert(marked(pane.contentTabs.cooldowns),'Cooldowns tab not marked')
    assert(pane.contentTabs.cooldowns.tooltip:find('Cooldown 1 (Spell 8042): Health Percentage is not available on this client (health is secret on this client)',1,true),pane.contentTabs.cooldowns.tooltip)
    assert(not marked(pane.contentTabs.rotation) and pane.contentTabs.rotation.problemText==nil,'Rotation tab marked')
    assert(pane.validationButton:IsShown() and pane.validationButton:GetText():find('Cooldown 1',1,true),pane.validationButton:GetText())
    -- Fixing the cooldown clears the mark and restores the plain tab.
    assert(pane:Command('Remove','broken'))
    assert(not marked(pane.contentTabs.cooldowns) and pane.contentTabs.cooldowns.tooltip==nil and not pane.validationButton:IsShown())
end)

test('editor: a broken Branch or Stop child marks Rotation red from either tab and reds its branch card',function()
    local a,parent=editor({mine={name='Mine',switch={},cooldowns={},rotation={{id='branch',type='branch',conditions={},
        onTrue={{id='fine',type='none',conditions={}}},onFalse={{id='stop',type='none',conditions=health('player')}}}}}})
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'))
    assert(marked(pane.contentTabs.rotation) and pane.contentTabs.rotation.tooltip:find('Rotation step 1 › No 1 (Stop)',1,true),tostring(pane.contentTabs.rotation.tooltip))
    assert(not marked(pane.contentTabs.cooldowns))
    assert(cardFor(pane,'stop').model.invalid and cardFor(pane,'branch').model.invalid and not cardFor(pane,'fine').model.invalid)
    pane:SelectContent('cooldowns');assert(marked(pane.contentTabs.rotation),'the mark left with the rotation list')
end)

test('editor: a Built In viewed read-only is marked the same way',function()
    local a,parent=editor({},{name='Pack',switch={},rotation={{id='green',type='spell',action=403,conditions={}}},cooldowns={{id='broken',type='spell',action=8042,conditions=health()}}})
    local pane=assert(a:CreateRotationEditor(parent,0,'builtin'))
    assert(pane.workspace.readOnly and marked(pane.contentTabs.cooldowns) and not marked(pane.contentTabs.rotation))
end)

-- After Apply the pane shows the applied state even when refreshing advice
-- was superseded by a rotation transition it started (in game: an automatic
-- switch to the edited rotation, or a restored manual choice). Before, the
-- pane skipped its redraw then: Apply and View Changes stayed enabled and the
-- yellow change marks stayed on cards already saved. Client-independent.
local function unsavedMarks(pane)
    local list={}
    local function check(name,control) if control and control.unsavedMark and control.unsavedMark:IsShown() then list[#list+1]=name end end
    check('name',pane.name);check('switch',pane.switch);check('info',pane.info)
    for _,card in ipairs(pane.canvas.cards) do if card.model and card.frame:IsShown() then check(card.model.id,card.frame) end end
    return table.concat(list,',')
end
test('editor: after Apply the buttons grey out and change marks clear, even when advice is superseded',function()
    local a,parent=editor({mine={name='Mine',switch={},rotation={{id='a',type='spell',action=403,conditions={}}},cooldowns={}}})
    local pane=assert(a:CreateRotationEditor(parent,0,'mine'));local saves=0;pane.onSaved=function() saves=saves+1 end
    a.SwitchRotation=function() a:BeginActiveRotationTransition() end -- what an automatic switch does to the advice lease
    for round,edit in ipairs({function() return pane:Command('UpdateStep','a',{disabled=true}) end,
        function() pane:StageField('a','name','Bolt','','Name');return true end,
        function() pane.name:SetText('Renamed');pane.name.scripts.OnTextChanged(pane.name,true);return true end}) do
        assert(edit())
        assert(pane.apply:IsEnabled() and pane.viewChanges:IsEnabled() and unsavedMarks(pane)~='','round '..round..': edit not pending')
        pane.apply:Click()
        assert(not pane:HasUnsavedChanges(),'round '..round..': still dirty')
        assert(not pane.apply:IsEnabled(),'round '..round..': Apply still enabled')
        assert(not pane.viewChanges:IsEnabled(),'round '..round..': View Changes still enabled')
        assert(unsavedMarks(pane)=='','round '..round..': marks remain on '..unsavedMarks(pane))
        assert(saves==round,'round '..round..': roster not refreshed')
    end
    local saved=a:GetEditableRotation(0,'mine')
    assert(saved.rotation[1].disabled==true and saved.rotation[1].name=='Bolt' and saved.name=='Renamed','applied values not saved')
    assert(pane:Command('UpdateStep','a',{disabled=false}) and pane.apply:IsEnabled() and unsavedMarks(pane)=='a','a later edit is not pending')
end)

finish()
