-- The rotation editor's "not on your action bars" warning (UI/rotation_cards.lua,
-- UI/rotation_editor.lua): computed from the button index when the scene is
-- built and when the index changes, amber and apart from red invalid data.
-- The index is modelled here (GetStepBinding / WatchButtonIndex); the real
-- index is exercised by tests/skip_unbound.lua.
local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local KEG,TIGER_PALM=121253,100780
local function body() return {name='Mine',switch={},
    rotation={{id='keg',type='spell',action=KEG,conditions={}},{id='tp',type='spell',action=TIGER_PALM,conditions={}},
        {id='blizzard',type='assisted',conditions={}},{id='stop',type='stop',conditions={}},
        {id='branch',type='branch',conditions={},onTrue={{id='inner',type='spell',action=KEG,conditions={}}},onFalse={}}},
    cooldowns={{id='cd',type='spell',action=KEG,conditions={}},{id='cdok',type='spell',action=TIGER_PALM,conditions={}}}} end
local function fixture()
    local f=F.new();local a=f.addon;local frames,create=dofile('tests/fixtures/native_ui.lua')(f.env);f.nativeFrames=frames
    dofile('tests/fixtures/spell_editbox.lua')(f,create)
    a.db.profile.rotations={[0]={mine=body()}};a.configPaneGeneration=1
    function a:GetEditableRotation(spec,id) return self.db.profile.rotations[spec] and self.db.profile.rotations[spec][id] end
    function a:GetDefaultIdForRuntime(_,id) if id=='builtin' then return 'pack' end end
    function a:ListDefaultRotations() return {{id='pack',runtimeKey='builtin',name='Mine',description='Preview',enabled=true,envelope={body=body()}}} end
    function a:GetImportValidationOptions() return {} end
    function a:validateCondition() return true end
    a.UpdateAutoSwitch=function() end;a.SwitchRotation=function() end;a.EvaluateNextAction=function() end
    -- The modelled index: which actions are on a bar, and who watches it.
    local bars={[TIGER_PALM]=true};local watchers={};local calls=0
    function a:GetStepBinding(step)
        calls=calls+1
        if step.type=='assisted' then if bars[KEG] then return true end;return false,{KEG} end
        if step.type~='spell' or step.action==nil then return nil end
        return bars[step.action]==true
    end
    function a:WatchButtonIndex(key,callback) watchers[key]=callback end
    local index={bars=bars,watchers=watchers,calls=function() return calls end}
    function index.rescan() for _,callback in pairs(watchers) do callback() end end
    local tones={}
    local decorate=nil
    for _,file in ipairs({'Platform/spells.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/rotation_draft.lua','Data/validation.lua','Core/rotation_editor.lua','Core/rotation_workspace.lua','Core/rotation_tags.lua','Core/rotation_canvas.lua','UI/window.lua'}) do f.load(file) end
    decorate=a.CreateRoundedCardDecoration
    a.CreateRoundedCardDecoration=function(self,frame)
        local decoration=decorate(self,frame);local set=decoration.SetColors
        decoration.SetColors=function(d,r,g,b,...) tones[frame]={r,g,b};return set(d,r,g,b,...) end
        return decoration
    end
    for _,file in ipairs({'UI/rotation_cards.lua','UI/rotation_canvas.lua','UI/color_picker.lua','UI/rotation_effect_fields.lua','UI/rotation_fields.lua','UI/rotation_navigation.lua','UI/rotation_metadata.lua','UI/rotation_view.lua','UI/rotation_editor.lua'}) do local h=io.open(file);if h then h:close();f.load(file) end end
    dofile('tests/fixtures/rotation_header_backend.lua')(a,f.env.DEFAULT,f.env.NEW)
    local parent=create('Frame');parent:SetSize(740,600)
    return f,parent,index,tones
end
local function visibleCard(pane,id) for _,c in ipairs(pane.canvas.cards) do if c.model and c.model.id==id and c.frame:IsShown() then return c end end end
local function card(pane,id)
    local snapshot=pane.workspace:Snapshot();local section='rotation'
    for _,step in ipairs(snapshot.cooldowns or {}) do if step.id==id then section='cooldowns';break end end
    if pane.view.section~=section then pane:SelectContent(section) end
    return visibleCard(pane,id)
end
local AMBER={1,.72,.25}
local function amber(tones,c) local t=tones[c.frame];return t and t[1]==AMBER[1] and t[2]==AMBER[2] and t[3]==AMBER[3] end
local STEP_TEXT="Not on your action bars, so it can't be highlighted. It is skipped."

test('a step on no bar wears the amber warning row and tooltip; a bound step, Stop and Branch do not',function()
    local f,parent,index,tones=fixture()
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local keg,tp=card(pane,'keg'),card(pane,'tp')
    assert(keg.unbound:IsShown() and keg.unbound:GetText()==STEP_TEXT,'warning row missing: '..tostring(keg.unbound:GetText()))
    assert(keg.unbound.tooltip:find('this step is skipped and the next step is used instead'),'step tooltip')
    assert(amber(tones,keg),'border is not amber')
    assert(not tp.unbound:IsShown() and not amber(tones,tp),'bound step warned')
    assert(not card(pane,'stop').unbound:IsShown(),'Stop warned')
    assert(not card(pane,'branch').unbound:IsShown(),'Branch warned')
    assert(card(pane,'inner').unbound:IsShown(),'a step inside a branch was not warned')
    -- The row takes its own height: the warned card is taller by the row.
    assert(keg.model.height==tp.model.height+f.addon.RotationCardNoticeHeight,'heights '..keg.model.height..' vs '..tp.model.height)
end)

test('Blizzard\'s suggestion names the suggestion spells on no bar',function()
    local f,parent=fixture()
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local c=card(pane,'blizzard')
    assert(c.unbound:IsShown() and c.unbound:GetText():find('Some suggestions are not on your action bars'),tostring(c.unbound:GetText()))
    assert(c.unbound.tooltip:find('Blizzard can suggest',1,true) and c.unbound.tooltip:find(tostring(KEG),1,true),c.unbound.tooltip)
end)

test('cooldown cards warn too, with the cooldown wording',function()
    local f,parent,_,tones=fixture()
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local cd=card(pane,'cd')
    assert(cd.unbound:IsShown() and cd.unbound:GetText()==STEP_TEXT and amber(tones,cd))
    assert(cd.unbound.tooltip:find('this cooldown is never shown or announced'),cd.unbound.tooltip)
    assert(not card(pane,'cdok').unbound:IsShown())
end)

test('binding the spell (a rescan) clears the warning, and unbinding brings it back',function()
    local f,parent,index,tones=fixture()
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(card(pane,'keg').unbound:IsShown())
    index.bars[KEG]=true;index.rescan()
    assert(not card(pane,'keg').unbound:IsShown() and not amber(tones,card(pane,'keg')),'warning stayed after binding')
    assert(not card(pane,'blizzard').unbound:IsShown(),'suggestion warning stayed')
    index.bars[KEG]=nil;index.rescan()
    assert(card(pane,'keg').unbound:IsShown(),'warning did not return')
end)

test('a rescan that changes nothing does not repaint; a closed editor stops watching',function()
    local f,parent,index=fixture()
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local before=card(pane,'keg');local generation=pane.canvas.generation
    index.rescan()
    assert(pane.canvas.generation==generation and card(pane,'keg')==before,'an unchanged rescan repainted the canvas')
    pane:Release()
    assert(next(index.watchers)==nil,'released editor still watching the index')
    local calls=index.calls();index.rescan();assert(index.calls()==calls,'a closed editor judged bindings')
end)

test('a focused input defers the repaint to the next render',function()
    local f,parent,index=fixture()
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    local generation=pane.canvas.generation
    f.env.GetCurrentKeyBoardFocus=function() return pane.name end
    index.bars[KEG]=true;index.rescan()
    assert(pane.canvas.generation==generation,'repainted under a focused input')
    f.env.GetCurrentKeyBoardFocus=function() return nil end
    pane:Render();assert(not card(pane,'keg').unbound:IsShown(),'next render did not pick up the change')
end)

test('compact cards show the warning as an icon with the same tooltip',function()
    local f,parent=fixture()
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    card(pane,'keg').expand:Click()
    local c=card(pane,'keg')
    assert(c.model.compact and c.unbound:IsShown() and c.unbound:GetText()=='','compact warning')
    assert(c.unbound.tooltip:find("this step is skipped"),'compact tooltip')
end)

test('Built In read-only views show the warning',function()
    local f,parent=fixture()
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'builtin'))
    assert(pane.workspace.readOnly,'not a read-only view')
    assert(card(pane,'keg').unbound:IsShown() and not card(pane,'tp').unbound:IsShown())
end)

test('without a button index (no buttons.lua) nothing is warned',function()
    local f,parent=fixture()
    f.addon.GetStepBinding=nil
    local pane=assert(f.addon:CreateRotationEditor(parent,0,'mine'))
    assert(not card(pane,'keg').unbound:IsShown())
end)
finish()
