local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
test('readonly condition sessions allow inspection but reject every mutation path',function()
    local a={};for _,file in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/condition_draft.lua','Core/condition_editor.lua'}) do assert(loadfile(file))('rotationmaster',a) end
    local original={type='CUSTOM',value=1}
    local s=assert(a:NewConditionEditSession(0,original,nil,{readOnly=true}))
    assert(not s:Command('Remove',{}) and not s:Apply() and not s:Undo() and not s:Redo())
    assert(s:Snapshot().value==1 and not s:HistoryState().canUndo and original.type=='CUSTOM')
end)
local function fixture()
    local a={}
    for _,file in ipairs({'Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Data/condition_draft.lua','Data/validation.lua','Data/diff.lua','Core/condition_editor.lua'}) do
        assert(loadfile(file))('rotationmaster',a)
    end
    a.conditionDefinitions={SPELL_KNOWN={fields={spell='number'},requiredFields={'spell'}}}
    function a:GetImportValidationOptions() return {conditions=self.conditionDefinitions} end
    function a:validateCondition(root,spec) assert(spec==0);return root.type==nil or root.spell==403 end
    return a
end
test('condition edits apply explicitly and cancellation preserves the original',function()
    local a=fixture();local original={type='SPELL_KNOWN',spell=403}
    local session=assert(a:NewConditionEditSession(0,original))
    assert(session:Command('SetDisabled',{},true));assert(original.disabled==nil)
    local state=session:Snapshot();state.spell=99;assert(session:Snapshot().spell==403)
    assert(session:Apply());assert(original.disabled==true and original.spell==403)
    assert(not session:Apply())
    local another=assert(a:NewConditionEditSession(0,original));assert(another:Command('Remove',{}))
    another:Cancel();assert(not another:Apply() and original.spell==403)
end)
test('schema and semantic errors never partially replace saved fields',function()
    local a=fixture();local original={type='SPELL_KNOWN',spell=403}
    local session=assert(a:NewConditionEditSession(0,original))
    assert(session:Command('Replace',{}, {type='SPELL_KNOWN',spell='typo'}))
    assert(not session:Apply());assert(original.spell==403)
    assert(session:Command('Replace',{}, {type='SPELL_KNOWN',spell=99}))
    assert(not session:Apply());assert(original.spell==403)
    assert(session:Command('Replace',{}, {type='SPELL_KNOWN',spell=403,disabled={future=true}}))
    assert(not session:Apply());assert(original.disabled==nil)
    assert(not session:Command('Apply',{}))
end)
test('another editor changing saved data blocks a stale apply',function()
    local a=fixture();local original={type='SPELL_KNOWN',spell=403}
    local session=assert(a:NewConditionEditSession(0,original))
    assert(session:Command('SetDisabled',{},true));original.spell=8042
    local ok,why=session:Apply();assert(not ok and why=='condition-changed-externally')
    assert(original.spell==8042 and original.disabled==nil)
end)
test('validation cannot mutate the staged candidate or write executable data into SavedVariables',function()
    local a=fixture();local original={type='SPELL_KNOWN',spell=403}
    local session=assert(a:NewConditionEditSession(0,original))
    function a:validateCondition(value) value.spell=8042;return true end
    local ok,why=session:Apply();assert(not ok and why=='validation-mutated-condition')
    assert(original.spell==403 and session:Snapshot().spell==403)
    function a:validateCondition(value) value.code=function() end;return true end
    assert(not session:Apply());assert(original.code==nil)
end)
test('custom body rotation fields are ordinary condition data rather than rotation envelopes',function()
    local a=fixture();a.conditionDefinitions.CUSTOM={fields={body={rotation='number[]',cooldowns='number[]'}}}
    function a:validateCondition() return true end
    local original={type='CUSTOM',body={rotation={1,2},cooldowns={3,4}}}
    local session=assert(a:NewConditionEditSession(0,original))
    assert(session:Apply(),'unchanged custom field names collided with envelope diff semantics')
    session=assert(a:NewConditionEditSession(0,original));original.body.rotation[1]=9
    local ok,why=session:Apply();assert(not ok and why=='condition-changed-externally')
end)
test('a removed or replaced owning rotation cannot receive a stale Apply',function()
    local a=fixture();local original={type='SPELL_KNOWN',spell=403};local exists=true
    local session=assert(a:NewConditionEditSession(0,original,function() return exists end))
    assert(session:Command('SetDisabled',{},true));exists=false
    local ok,why=session:Apply();assert(not ok and why=='condition-target-missing' and original.disabled==nil)
    exists=true
    function a:validateCondition() exists=false;return true end
    ok,why=session:Apply();assert(not ok and why=='condition-target-missing' and original.disabled==nil)
end)
test('stacked history restores field and structural edits without changing saved data',function()
    local a=fixture();local original={type='SPELL_KNOWN',spell=403}
    local session=assert(a:NewConditionEditSession(0,original))
    assert(session:Command('Replace',{}, {type='SPELL_KNOWN',spell=8042}))
    assert(session:Command('Wrap',{},'NOT'));assert(session:Command('Remove',{'value'}))
    assert(session:Undo());assert(session:Snapshot().value.spell==8042)
    assert(session:Undo());assert(session:Snapshot().spell==8042)
    assert(session:Undo());assert(session:Snapshot().spell==403)
    assert(not session:Undo());assert(session:Redo());assert(session:Snapshot().spell==8042)
    assert(session:Redo());assert(session:Redo());assert(next(session:Snapshot().value)==nil)
    assert(not session:Redo());assert(original.spell==403 and original.value==nil)
end)
test('failed and unchanged commands retain redo while a new edit discards its branch',function()
    local a=fixture();local session=assert(a:NewConditionEditSession(0,{type='SPELL_KNOWN',spell=403}))
    assert(session:Command('SetDisabled',{},true));assert(session:Undo())
    assert(not session:Command('Move',{},1));assert(session:Command('Replace',{},session:Snapshot()))
    assert(session:HistoryState().canRedo);assert(session:Redo());assert(session:Snapshot().disabled)
    assert(session:Undo());assert(session:Command('Wrap',{},'NOT'))
    assert(not session:HistoryState().canRedo and not session:Redo())
    assert(session:Undo());assert(session:Snapshot().spell==403)
end)
test('history is bounded and closed drafts cannot undo or redo',function()
    local a=fixture();local original={type='SPELL_KNOWN',spell=403}
    local session=assert(a:NewConditionEditSession(0,original))
    for i=1,120 do assert(session:Command('Replace',{}, {type='SPELL_KNOWN',spell=i})) end
    local count=0;while session:Undo() do count=count+1 end
    assert(count==100 and session:Snapshot().spell==20)
    session:Cancel();assert(not session:Undo() and not session:Redo())
    assert(not session:HistoryState().canUndo and not session:HistoryState().canRedo)
    assert(original.spell==403)
end)
test('undo does not replace the saved baseline or bypass stale apply checks',function()
    local a=fixture();local original={type='SPELL_KNOWN',spell=403}
    local session=assert(a:NewConditionEditSession(0,original))
    assert(session:Command('Remove',{}));assert(session:Undo())
    original.spell=8042
    local ok,why=session:Apply();assert(not ok and why=='condition-changed-externally')
    assert(original.spell==8042)
end)
test('batch card commands and named groups apply as a single undoable data edit',function()
    local a=fixture();function a:validateCondition() return true end
    local original={type='AND',value={{type='SPELL_KNOWN',spell=403},{type='SPELL_KNOWN',spell=8042}}}
    local session=assert(a:NewConditionEditSession(0,original))
    local ok,paths=session:Command('GroupSelection',{{'value',1},{'value',2}},'OR');assert(ok and paths[1][2]==1)
    assert(session:Undo());assert(#session:Snapshot().value==2)
    assert(session:Redo());assert(session:Command('SetName',{'value',1},'Combat gates'))
    assert(session:Apply());assert(original.value[1].name=='Combat gates' and #original.value[1].value==2)
end)
test('large edit history sheds old states before retaining an unbounded string corpus',function()
    local a=fixture();local session=assert(a:NewConditionEditSession(0,{}))
    for i=1,110 do assert(session:Command('Replace',{}, {type='OPAQUE',text=string.rep('x',200000),n=i})) end
    local count=0;while session:Undo() do count=count+1 end
    assert(count>1 and count<100)
end)
finish()
