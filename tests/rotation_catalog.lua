local F=dofile('tests/fixtures/addon.lua')
local make=dofile('tests/fixtures/rotation_data.lua')
local test,finish=F.suite()
local function fixture(state, generator)
    local data,envelope,validation=make()
    local addon={RotationData=data}
    assert(loadfile('Data/catalog.lua'))('rotationmaster',addon)
    local n=0
    local catalog=assert(data.NewCatalog({state=state or {},validation=validation,newId=generator or function()
        n=n+1;return 'new-id-'..n
    end}))
    return catalog,envelope,data
end
test('built-ins remain visible when disabled and getters never expose their source tables',function()
    local c,envelope=fixture()
    local source=envelope();assert(c:RegisterBuiltin(source))
    source.body.rotation[1].action=999
    local view=c:Get(source.id)
    assert(view.builtin and view.readOnly and view.enabled and view.envelope.body.rotation[1].action==403)
    view.envelope.body.rotation[1].action=999
    assert(c:Get(source.id).envelope.body.rotation[1].action==403)
    assert(c:SetEnabled(source.id,false))
    local rows=c:List();assert(#rows==1 and rows[1].readOnly and rows[1].enabled==false)
    rows[1].applicability.class='MAGE'
    assert(c:Get(source.id).envelope.applicability.class=='SHAMAN')
end)
test('all user mutation paths reject built-in ownership',function()
    local c,envelope=fixture();local source=envelope();assert(c:RegisterBuiltin(source))
    for _,method in ipairs({'Save','Rename','Delete','AddCustom'}) do
        local ok,reason
        if method=='Save' then ok,reason=c:Save(source.id,source)
        elseif method=='Rename' then ok,reason=c:Rename(source.id,'changed')
        elseif method=='Delete' then ok,reason=c:Delete(source.id)
        else ok,reason=c:AddCustom(source) end
        assert(ok==false and reason=='read-only',method)
    end
    assert(c:Get(source.id).envelope.nameKey=='Shaman Leveling')
end)
test('a clone has fresh rotation and step IDs, an independent baseline and saved lineage',function()
    local state={}
    local c,envelope=fixture(state)
    local source=envelope();source.body.cooldowns={{id='cooldown-1',type='spell',action=974}}
    assert(c:RegisterBuiltin(source))
    local id=assert(c:Clone(source.id,'My leveling rotation'))
    local clone=c:Get(id)
    assert(not clone.builtin and not clone.readOnly and clone.envelope.id==id and id~=source.id)
    assert(clone.envelope.nameKey=='My leveling rotation')
    local step=clone.envelope.body.rotation[1]
    assert(step.id~='step-1' and clone.envelope.body.cooldowns[1].id~='cooldown-1')
    assert(clone.lineage.sourceId==source.id and clone.lineage.sourceRevision==1)
    assert(clone.lineage.stepOrigins[step.id]=='step-1')
    assert(state.custom[id] and state.lineage[id].baseline.body.rotation[1].action==403)
    clone.envelope.body.rotation[1].action=974;assert(c:Save(id,clone.envelope))
    assert(c:Get(id).envelope.body.rotation[1].action==974)
    assert(c:Get(source.id).envelope.body.rotation[1].action==403)
    assert(c:Get(id).lineage.baseline.body.rotation[1].action==403)
end)
test('source revisions preserve preferences and never overwrite clones',function()
    local c,envelope=fixture()
    local source=envelope();assert(c:RegisterBuiltin(source))
    local id=assert(c:Clone(source.id));assert(c:SetEnabled(source.id,false))
    local clone=c:Get(id);clone.envelope.body.rotation[1].action=974;assert(c:Save(id,clone.envelope))
    local update=envelope();update.revision=2;update.body.rotation[1].action=529
    assert(c:RegisterBuiltin(update))
    assert(c:Get(source.id).envelope.revision==2 and not c:Get(source.id).enabled)
    assert(c:Get(id).envelope.body.rotation[1].action==974)
    assert(c:Get(id).lineage.sourceRevision==1 and c:Get(id).lineage.baseline.revision==1)
end)
test('cloning a custom clone preserves the original source mapping and baseline',function()
    local c,envelope=fixture();local source=envelope();assert(c:RegisterBuiltin(source))
    local first=assert(c:Clone(source.id));local second=assert(c:Clone(first))
    local view=c:Get(second);local stepId=view.envelope.body.rotation[1].id
    assert(view.lineage.sourceId==source.id and view.lineage.sourceRevision==1)
    assert(view.lineage.stepOrigins[stepId]=='step-1' and view.lineage.baseline.id==source.id)
    assert(view.lineage.clonedFrom==first)
end)
test('ID collisions fail atomically without creating partial SavedVariables records',function()
    local state={}
    local c,envelope=fixture(state,function() return 'step-1' end)
    local source=envelope();assert(c:RegisterBuiltin(source))
    local id,reason=c:Clone(source.id)
    assert(id==nil and reason=='id-collision')
    assert(next(state.custom)==nil and next(state.lineage)==nil)
end)
test('withdrawal preserves a visible read-only entry and excludes advice',function()
    local c,envelope=fixture();local source=envelope();assert(c:RegisterBuiltin(source))
    assert(c:WithdrawBuiltin(source.id,'replaced by a reviewed pack'))
    local rows=c:List()
    assert(#rows==1 and rows[1].withdrawn and not rows[1].enabled and rows[1].readOnly)
    assert(rows[1].withdrawalReason=='replaced by a reviewed pack')
    assert(c:SetEnabled(source.id,true)==false)
end)
test('unsupported built-ins and invalid saved customs remain inspectable without data deletion',function()
    local state={custom={broken={unexpected=true}}}
    local c,envelope=fixture(state)
    local source=envelope();source.body.rotation[1].conditions={type='FUTURE_CONDITION'}
    assert(c:RegisterBuiltin(source))
    local view=c:Get(source.id)
    assert(view.readOnly and not view.validation.resolved and view.envelope.body.rotation[1].conditions.type=='FUTURE_CONDITION')
    assert(#c:List()==2 and c:Get('broken').validation.valid==false)
    assert(state.custom.broken.unexpected==true)
end)
test('packaged source stays inspectable when a registered condition schema becomes incompatible',function()
    local data,envelope,validation=make();local a={RotationData=data};assert(loadfile('Data/catalog.lua'))('rotationmaster',a)
    validation.conditions.SPELL_KNOWN.fields.spell='string'
    local c=assert(data.NewCatalog({validation=validation,state={}}));local source=envelope()
    assert(c:RegisterBuiltin(source),'current condition schema prevented retaining a structurally valid packaged source')
    local view=c:Get(source.id);assert(view.readOnly and not view.validation.valid and not view.enabled)
    assert(view.envelope.body.rotation[1].conditions.spell==403 and #c:List()==1)
    source.id='custom';assert(not c:AddCustom(source),'strict custom validation was weakened')
end)
test('custom rename, disable and delete affect only the user-owned saved record',function()
    local state={}
    local c,envelope=fixture(state);local source=envelope();assert(c:RegisterBuiltin(source))
    local id=assert(c:Clone(source.id));assert(c:Rename(id,'Renamed'))
    assert(c:SetEnabled(id,false));assert(not c:Get(id).enabled)
    assert(c:Get(id).envelope.body.name=='Renamed')
    assert(c:Delete(id));assert(c:Get(id)==nil and state.custom[id]==nil and state.lineage[id]==nil)
    assert(c:Get(source.id).envelope.body.rotation[1].action==403)
end)
test('explicit ownership references preserve both entries when a saved ID collides with a new built-in',function()
    local c,envelope=fixture()
    local source=envelope();local custom=envelope();custom.body.rotation[1].action=974
    assert(c:AddCustom(custom));assert(c:RegisterBuiltin(source))
    assert(#c:List()==2)
    local reference={kind='custom',id=source.id}
    local view=c:Get(reference)
    assert(view.envelope.body.rotation[1].action==974 and not view.readOnly)
    assert(c:Get(source.id).envelope.body.rotation[1].action==403)
    assert(c:Rename(reference,'My existing custom'))
    assert(c:Get(reference).envelope.body.name=='My existing custom')
    assert(c:Delete({kind='builtin',id=source.id})==false)
end)
test('invalid saved metadata never escapes through list summaries or becomes enabled',function()
    local cycle={};cycle.self=cycle
    local state={custom={broken={nameKey=cycle,revision=0/0,body={}}}}
    local c=fixture(state)
    local rows=c:List()
    assert(#rows==1 and rows[1].enabled==false and rows[1].validation.valid==false)
    assert(rows[1].nameKey==nil and rows[1].revision==nil and state.custom.broken.nameKey==cycle)
end)
test('changing enabled state preserves unrelated saved preferences',function()
    local state={preferences={['rm.tbc.shaman.leveling']={enabled=true,intent='single'}}}
    local c,envelope=fixture(state);local source=envelope();assert(c:RegisterBuiltin(source))
    assert(c:SetEnabled(source.id,false))
    assert(state.preferences[source.id].intent=='single')
end)
test('malformed state namespaces are refused without replacing saved values',function()
    local data=select(3,fixture())
    for _,state in ipairs({false,{preferences=false},{custom='bad'},{lineage=12}}) do
        local catalog,reason=data.NewCatalog({state=state})
        assert(catalog==nil and reason=='invalid-catalog-state')
    end
end)
test('an explicit missing built-in reference never resolves to a custom with the same ID',function()
    local c,envelope=fixture();local source=envelope();assert(c:AddCustom(source))
    assert(c:Get({kind='builtin',id=source.id})==nil)
    assert(c:Get({kind='custom',id=source.id}).builtin==false)
end)
test('invalid lineage stays saved and prevents cloning with a fabricated new baseline',function()
    local state={}
    local c,envelope=fixture(state);local source=envelope();assert(c:RegisterBuiltin(source))
    local id=assert(c:Clone(source.id));state.lineage[id]=12
    local clone,reason=c:Clone(id)
    assert(clone==nil and reason=='invalid-lineage' and state.lineage[id]==12)
    assert(c:Get(id).lineage==nil and c:Get(id).lineageError.code=='invalid-lineage')
end)
test('saving an explicit repair cannot propagate a corrupt previous revision',function()
    local c,envelope,data=fixture()
    local repaired=envelope();repaired.id='custom-id'
    local state={custom={['custom-id']={revision=0/0}}}
    local loader={RotationData=data};assert(loadfile('Data/catalog.lua'))('rotationmaster',loader)
    local store=assert(data.NewCatalog({state=state}))
    assert(store:Save('custom-id',repaired))
    assert(data.CheckPortable(state.custom['custom-id']) and state.custom['custom-id'].revision==1)
end)
test('incomplete source baselines and origins outside the baseline block cloning',function()
    local state={}
    local c,envelope=fixture(state);local source=envelope();assert(c:RegisterBuiltin(source))
    local id=assert(c:Clone(source.id))
    local baseline=state.lineage[id].baseline
    state.lineage[id].baseline={id=source.id,revision=1}
    assert(c:Get(id).lineageError and c:Clone(id)==nil)
    assert(state.lineage[id].baseline.body==nil,'corrupt source evidence was rewritten')
    state.lineage[id].baseline=baseline
    local body,origins=baseline.body,state.lineage[id].stepOrigins
    baseline.schemaVersion=99;baseline.body=nil;state.lineage[id].stepOrigins={}
    assert(c:Get(id).lineageError and c:Clone(id)==nil,'unknown baseline schema bypassed structure checks')
    baseline.schemaVersion=1;baseline.body=body;state.lineage[id].stepOrigins=origins
    local stepId=state.custom[id].body.rotation[1].id
    state.lineage[id].stepOrigins[stepId]='not-in-baseline'
    assert(c:Get(id).lineageError and c:Clone(id)==nil)
end)
test('a saved key and embedded identity mismatch stays disabled without changing either value',function()
    local _,envelope=fixture();local source=envelope();source.id='different'
    local state={custom={saved=source}}
    local c=fixture(state)
    local view=c:Get('saved')
    assert(not view.validation.valid and not view.enabled and view.validation.executionStatus=='unavailable')
    assert(c:Clone('saved')==nil and state.custom.saved.id=='different')
end)
test('portable but malformed summary fields are omitted while the full source remains inspectable',function()
    local _,envelope=fixture();local source=envelope()
    source.id='broken';source.nameKey='';source.revision=0;source.applicability='bad';source.tags=42
    local c=fixture({custom={broken=source}})
    local row=c:List()[1]
    assert(row.nameKey==nil and row.revision==nil and row.applicability==nil and row.tags==nil)
    assert(c:Get('broken').envelope.applicability=='bad' and source.tags==42)
end)
test('malformed preference entries cannot run metatable callbacks during reads or toggles',function()
    local pref=setmetatable({}, {__index=function() error('preference callback executed') end,
        __newindex=function() error('preference mutation callback executed') end})
    local state={preferences={['rm.tbc.shaman.leveling']=pref}}
    local c,envelope=fixture(state);local source=envelope();assert(c:RegisterBuiltin(source))
    assert(c:List()[1].enabled==false)
    local ok,reason=c:SetEnabled(source.id,true)
    assert(ok==false and reason=='invalid-preference' and state.preferences[source.id]==pref)
end)
test('nested clone allocates fresh IDs and retains lineage for branches and both arms',function()
    local c,envelope=fixture();local source=envelope()
    local original=source.body.rotation[1]
    source.body.rotation={{id='branch',type='branch',mode='false',conditions={},onTrue={original},
        onFalse={{id='false-step',type='spell',action=324,conditions={}}}}}
    assert(c:RegisterBuiltin(source));local id=assert(c:Clone(source.id,'Nested copy'))
    local copy=c:Get(id);local b=copy.envelope.body.rotation[1]
    assert(b.id~='branch' and b.onTrue[1].id~='step-1' and b.onFalse[1].id~='false-step')
    assert(copy.lineage.stepOrigins[b.id]=='branch' and copy.lineage.stepOrigins[b.onTrue[1].id]=='step-1'
        and copy.lineage.stepOrigins[b.onFalse[1].id]=='false-step')
    assert(b.mode=='false' and source.body.rotation[1].onTrue[1].id=='step-1')
    local again=assert(c:Clone(id,'Another copy'));local descendant=c:Get(again)
    assert(descendant.lineage.stepOrigins[descendant.envelope.body.rotation[1].onFalse[1].id]=='false-step')
end)
test('nested source identity collision fails before saving a partially cloned catalog entry',function()
    local state={};local n=0
    local c,envelope=fixture(state,function() n=n+1;return n==1 and 'new-copy' or 'nested-source' end)
    local source=envelope();source.body.rotation={{id='branch',type='branch',onTrue={{id='nested-source',type='stop'}},onFalse={}}}
    assert(c:RegisterBuiltin(source));local id,why=c:Clone(source.id,'Collision')
    assert(not id and why=='id-collision' and next(state.custom)==nil and next(state.lineage)==nil)
end)
test('cloning reserves a removed nested baseline ID even when no current source mapping retains it',function()
    local state={};local n=0;local c,envelope,data=fixture(state,function() n=n+1;return n==1 and 'new-root' or 'removed-nested' end)
    local baseline=envelope();baseline.body.rotation={{id='branch',type='branch',conditions={},onTrue={{id='removed-nested',type='spell',action=403}},onFalse={}}}
    local current=data.CopyData(baseline);current.id='custom-tree';current.body.rotation={{id='user-added',type='spell',action=324}}
    state.custom['custom-tree']=current
    state.lineage['custom-tree']={sourceId=baseline.id,sourceKind='builtin',sourceRevision=1,baseline=baseline,stepOrigins={}}
    local id,why=c:Clone('custom-tree','Copy')
    assert(not id and why=='id-collision' and state.custom['new-root']==nil,'historical identity was reassigned to a new user step')
end)
finish()
