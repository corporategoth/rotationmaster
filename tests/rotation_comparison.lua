local F=dofile('tests/fixtures/addon.lua')
local make=dofile('tests/fixtures/rotation_data.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon
    local data,envelope=make();a.RotationData=data
    f.load('UI/settings_transfer.lua');f.load('Data/diff.lua');f.load('Data/visual_comparison.lua');f.load('Core/rotation_library.lua');f.load('UI/rotation_reference.lua');f.load('UI/rotation_comparison.lua')
    -- Pure report tests inject the detached scoped service boundary. Actual
    -- store authority and ownership are covered by rotation_scope_ui.lua.
    dofile('tests/fixtures/rotation_header_backend.lua')(a,f.env.DEFAULT,f.env.NEW)
    local coordinator={}
    function coordinator:CheckReady() return true end
    function a:GetScopedRotationCoordinator() return coordinator end
    function a:GetRotationOwnerContext() return {class='SHAMAN',character='Fixture - Realm'} end
    function a:GetRotationRecordSnapshot(spec,value)
        local reference,why=self:ResolveRotationReference(spec,value);if not reference then return nil,why end
        local body=self.db.profile.rotations[spec][reference.address.id];if not body then return nil,'unknown-rotation' end
        return {body=data.CopyData(body)},{profile=self.db.profile,body=body,baseline=data.CopyData(body)}
    end
    function coordinator:TokenCurrent(token)
        return token.profile==a.db.profile and a:SettingsDataEqual(token.body,token.baseline)
    end
    return f,envelope
end
test('comparison text preserves direction, false values, moves and incomplete status',function()
    local f,envelope=fixture();local left,right=envelope(),envelope()
    left.body.disabled=false;right.body.disabled=true
    local result=f.addon.RotationData.DiffRotations(left,right)
    local text=f.addon:FormatRotationComparison(result)
    assert(text:find('false',1,true) and text:find('true',1,true) and text:find('$.body.disabled',1,true))
    result.complete=false
    assert(f.addon:FormatRotationComparison(result):find('incomplete',1,true))
    result.valid=false
    assert(f.addon:FormatRotationComparison(result):find('could not',1,true))
end)
test('comparison report shows three directions and overlapping edits without merging',function()
    local f=fixture()
    local change={kind='changed',path='$.body.rotation[one].action',before=403,after=974}
    local part={valid=true,complete=true,changes={change},diagnostics={}}
    local result={valid=true,complete=true,sourceChanges=part,customChanges=part,currentDifferences=part,
        conflicts={{path=change.path}},diagnostics={}}
    local text=f.addon:FormatRotationComparison(result)
    assert(text:find('Changes in the Built In rotation',1,true) and text:find('Your changes',1,true))
    assert(text:find('Differences from',1,true) and text:find('Overlapping field edits',1,true))
    assert(change.after==974 and #part.changes==1)
end)
test('long values and native markup are bounded and cannot impersonate report text',function()
    local f=fixture()
    local result={valid=true,complete=true,changes={},diagnostics={}}
    for i=1,500 do result.changes[i]={kind='changed',path='$.'..string.rep('x',4000),before=false,
        after='|cffff0000'..string.rep('s',10000)} end
    local text=f.addon:FormatRotationComparison(result)
    assert(#text<=65536 and text:find('truncated',1,true))
    assert(text:find('||cffff0000',1,true),'WoW color markup was not escaped')
end)
test('comparison chooser refreshes a read-only report and Copy keeps the full selection',function()
    local f=fixture();local a=f.addon
    local lib=f.env.LibStub;f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','comparison requested retired GUI');return lib(name,...) end
    a.HideOnEscape=function() end
    a.db.profile.rotations={[0]={mine={name='Mine',rotation={}},other={name='Other',rotation={}}}}
    a.GetEditableRotation=function(self,spec,id) return self.db.profile.rotations[spec][id] end
    a.GetSourcedRotationView=function() return nil end
    a.ListDefaultRotations=function() return {} end
    local compared={}
    a.BuildRotationComparison=function(_,spec,id,target)
        compared[#compared+1]=target.address and target.address.id or target.id
        local left={body={rotation={{id='step',type='spell',action=403,conditions={}}}}}
        local right={body={rotation={{id='step',type='spell',action=8042,conditions={}}}}}
        local result=a.RotationData.DiffRotations(left,right)
        result.views={{key='current',left=left,right=right,diff=a.RotationData.DiffRotations(left,right)}}
        return result
    end
    a.Platform={GetSpellInfo=function(_,id) return {name=id==403 and 'Lightning Bolt' or 'Earth Shock',spellID=id,iconID=id} end,
        GetSpellLink=function(_,id) return '|Hspell:'..id..'|h[Named spell]|h' end}
    a.printCondition=function() return 'Readable conditions' end
    local frame=a:ShowRotationComparison(0,'mine')
    local chooser,copy,report
    for _,widget in ipairs(frame.children) do
        if widget.type=='RM-Selector' and widget.caption:GetText()=='Compare against' then chooser=widget end
        if widget.type=='RM-ConditionButton' then copy=widget end
        if widget.kind=='MultiLineEditBox' then report=widget end
    end
    assert(chooser and copy and not report and #compared==1,'the primary comparison must be graphical')
    assert(F.text(frame):find('Always',1,true),'step cards were not rendered')
    local function count(w)
        local n=w.type=='RM-ConditionLink' and 1 or 0
        for _,child in ipairs(w.children or {}) do n=n+count(child) end
        return n
    end
    assert(count(frame)==2,'before/after native spell identities were not paired')
    assert(#chooser.list==1 and chooser.list[1]=='Other · Class','self is offered as a comparison target')
    chooser:Fire('OnValueChanged',1);assert(#compared==2 and compared[2]=='other')
    local details=copy:Fire('OnClick');report=details.input
    assert(report and details.chrome,'diagnostic details were not available separately')
    local original=report:GetText();report:SetText('edited');report.scripts.OnTextChanged(report,true);assert(report:GetText()==original)
    details.copy:Click();assert(report.focused and report.cursor==0 and report.selection[1]==0 and report.selection[2]==-1)
    report.scripts.OnTextChanged(report,false);assert(report.selection[2]==-1,'unchanged text reset copy selection')
    assert(a.db.profile.rotations[0].mine.name=='Mine')
end)
test('copyable text reports keep keyboard navigation inside the visible page',function()
    local f=fixture();local d=f.addon:CreateWorkbenchTextReport(500,300)
    d:SetReport('Report',string.rep('line\n',300))
    local cursor=d.input.scripts.OnCursorChanged;assert(cursor,'report has no native caret scrolling')
    cursor(d.input,0,-500,2,14);assert(d.scroll.workbenchBar:GetValue()==514-d.scroll:GetHeight())
    cursor(d.input,0,-20,2,14);assert(d.scroll.workbenchBar:GetValue()==20)
end)
test('comparison windows release and reopen without stale actions reaching the new owner',function()
    local f=fixture();local a=f.addon;local comparisons,reports=0,0
    a.db.profile.rotations={[0]={mine={name='Mine'},other={name='Other'}}}
    a.GetEditableRotation=function(self,spec,id) return self.db.profile.rotations[spec][id] end
    a.GetSourcedRotationView=function() end;a.ListDefaultRotations=function() return {} end
    a.BuildRotationComparison=function() comparisons=comparisons+1;return {valid=true,complete=true,changes={},diagnostics={},views={}} end
    a.ShowComparisonReport=function() reports=reports+1 end
    local d=a:ShowRotationComparison(0,'mine');local oldChooser,oldCopy=d.chooser.events.OnValueChanged,d.copy.events.OnClick
    local oldUpdate=d.frame.scripts.OnUpdate;local root=d.graph;d:Hide();assert(not root.rmActive and #d.children==0)
    assert(a:ShowRotationComparison(0,'mine')==d and d.graph.rmActive and comparisons==2)
    oldChooser(d.chooser,'OnValueChanged',1);oldCopy(d.copy,'OnClick');oldUpdate();assert(comparisons==2 and reports==0 and d.frame:IsShown())
    local update=d.frame.scripts.OnUpdate;a.db.profile={rotations={}};d.copy:Fire('OnClick');assert(reports==0)
    update();assert(not d.frame:IsShown() and not d.active and #d.children==0)
end)
test('failed comparison rendering leaves every allocated child owned for cleanup',function()
    local f=fixture();local a=f.addon;local root=a:CreateConditionGroup();local allocated={}
    a.Platform={GetSpellInfo=function(_,id) return {name='Named spell',spellID=id,iconID=id} end,GetSpellLink=function(_,id) return '|Hspell:'..id..'|h[Named spell]|h' end}
    local stop=a:ObserveConditionWidgets(function(widget) allocated[#allocated+1]=widget end)
    a.CreateConditionReference=function() error('injected condition rendering failure') end
    local left={body={rotation={{id='a',type='spell',action=403,conditions={}}}}};local right=a.RotationData.CopyData(left);right.body.rotation[1].action=974
    local ok=pcall(a.RenderRotationComparison,a,root,{left=left,right=right,diff=a.RotationData.DiffRotations(left,right)},0)
    stop();assert(not ok);a:ReleaseConditionWidget(root)
    for _,widget in ipairs(allocated) do assert(not widget.rmActive,'failed renderer orphaned an allocated child: '..widget.type) end
end)
test('whole added steps and unknown table fields show their contents in the report',function()
    local f,envelope=fixture();local left,right=envelope(),envelope()
    right.body.rotation[2]={id='new-step',type='spell',action=974,
        conditions={type='BUFF',unit='focus',spell=324},unknownField={threshold=42}}
    local result=f.addon.RotationData.DiffRotations(left,right)
    local text=f.addon:FormatRotationComparison(result)
    assert(result.complete and text:find('974',1,true) and text:find('324',1,true))
    assert(text:find('BUFF',1,true) and text:find('threshold',1,true) and text:find('42',1,true))
end)
test('graph hides unchanged rows by default and expands them without inventing switch edits',function()
    local f=fixture();local a=f.addon
    local left={body={name='Source',switch={},rotation={{id='a',type='spell',action=403},{id='b',type='spell',action=8042}}}}
    local right={body={name='Clone',switch={},rotation={{id='a',type='spell',action=403},{id='b',type='spell',action=974}}}}
    local view={left=left,right=right,diff=a.RotationData.DiffRotations(left,right)}
    local seen,conditions={},0
    a.CreateRotationStepCard=function(_,_,_,_,position) seen[#seen+1]=position end
    a.CreateConditionReference=function() conditions=conditions+1 end
    local parent=a:CreateConditionGroup()
    a:RenderRotationComparison(parent,view,0)
    assert(#seen==2 and seen[1]==2 and seen[2]==2,'unchanged steps were displayed by default')
    assert(conditions==0,'a name change was presented as a switch condition change')
    assert(F.text(parent):find('Rotation names',1,true) and F.text(parent):find('Source',1,true) and F.text(parent):find('Clone',1,true))
    local toggle
    for _,w in ipairs(parent.children) do if w.type=='RM-CheckBox' then toggle=w end end
    assert(toggle and F.text(parent):find('1 unchanged',1,true),'hidden-step count/toggle missing')
    toggle:Fire('OnValueChanged',true)
    assert(#seen==6,'show unchanged did not include both sides of both steps')
    seen={};a:RenderRotationComparison(parent,{left=left,right=left,diff=a.RotationData.DiffRotations(left,left)},0)
    assert(#seen==0 and F.text(parent):find('No differences.',1,true),'unchanged comparison is not clear')
end)
test('comparison with no other rotations explains the empty roster without comparing to itself',function()
    local f=fixture();local a=f.addon
    a.HideOnEscape=function() end
    a.db.profile.rotations={[0]={mine={name='Mine',rotation={}}}}
    a.GetEditableRotation=function() return a.db.profile.rotations[0].mine end
    a.GetSourcedRotationView=function() end;a.ListDefaultRotations=function() return {} end
    a.BuildRotationComparison=function() error('there is no other target') end
    local frame=a:ShowRotationComparison(0,'mine')
    assert(F.text(frame):find('No other rotations',1,true))
    assert(frame.chooser.disabled and frame.direction.disabled and frame.copy.disabled,'empty comparison controls remain actionable')
end)
test('nested reference and comparison expose branch mode and arm context without evaluating code',function()
    local f=fixture();local a=f.addon
    a.Platform={GetSpellInfo=function(_,id) return {name='Named spell',spellID=id} end,GetSpellLink=function(_,id) return '|Hspell:'..id..'|h[Named spell]|h' end}
    a.printCondition=function() return 'Readable guard' end
    local body={rotation={{id='b',type='branch',name='Combat phase',mode='false',conditions={},
        onTrue={{id='yes',type='spell',action=403}},onFalse={{id='no',type='spell',action=324}}}},cooldowns={}}
    local parent=a:CreateConditionGroup();a:CreateRotationReference(parent,body,0)
    local text=F.text(parent)
    assert(text:find('Always false',1,true) and text:find('Combat phase',1,true) and text:find('True',1,true) and text:find('False',1,true))
    local right=a.RotationData.CopyData(body);right.rotation[1].onTrue[1].action=8042
    parent=a:CreateConditionGroup();a:RenderRotationComparison(parent,{left={body=body},right={body=right},diff=a.RotationData.DiffRotations({body=body},{body=right})},0,false)
    text=F.text(parent);assert(text:find('Combat phase',1,true) and text:find('True',1,true),'changed descendant lost its branch context')
end)
test('reference cards and paired comparisons render through native measured groups without Ace allocation',function()
    local f=fixture();local a=f.addon;local lib=f.env.LibStub;f.env.LibStub=function(name,...) assert(name~='AceGUI-3.0','reference requested retired GUI');return lib(name,...) end
    a.Platform={GetSpellInfo=function(_,id) return {name='Named spell',spellID=id,iconID=id} end,GetSpellLink=function(_,id) return '|Hspell:'..id..'|h[Named spell]|h' end}
    local left={body={switch={},cooldowns={},rotation={{id='a',type='spell',action=403,conditions={}}}}};local right=a.RotationData.CopyData(left);right.body.rotation[1].action=974
    local root=a:CreateConditionGroup();a:CreateRotationReference(root,left.body,0);assert(F.text(root):find('Named spell',1,true));a:ReleaseConditionWidget(root)
    root=a:CreateConditionGroup();a:RenderRotationComparison(root,{key='current',left=left,right=right,diff=a.RotationData.DiffRotations(left,right)},0)
    assert(F.text(root):find('Named spell',1,true));a:ReleaseConditionWidget(root)
end)
finish()
