-- Modeled native host, real initialization/library/reference workflows.
-- No complete TOC/vendor boot or actual-client acceptance is claimed.
-- Run default controls with lua5.1 and luajit; --wire requires LuaJIT's bit.
local F=dofile('tests/fixtures/addon.lua')
local new=dofile('tests/fixtures/client_baseline.lua')
local test,finish=F.suite()
local wire=arg and arg[1]=='--wire'
if arg and arg[1] then assert(wire,'only --wire is supported') end
if wire then assert(type(jit)=='table','--wire explicitly requires LuaJIT and its bit module');assert(require('bit')) end
local cases={
 {'era',2,0,'probe'},{'tbc',5,1,'probe'},
 {'progression',11,2,'probe'},{'progression',14,3,'probe'},{'progression',19,4,'probe'},
 {'retail',1,12,'restricted'},{'forever',18,12,'restricted'},{'unknown',999,12,'unsupported'},
}
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local source='rm.tbc.shaman.starter'
for _,case in ipairs(cases)do
 local label=case[1]..'/'..case[2]
 if not wire then
  test('startup uses initial client identity and owned context without optional addons '..label,function()
   local c=new(case);local a,e=c.a,c.e
   assert(c.firstProject==case[2] and c.initialProject==case[2],'family was changed after loading or initialization')
   assert(debug.getinfo(a.GetRotationContext,'S').source=='@Core/rotation_library.lua','synthetic context replaced owned method')
   local context=a:GetRotationContext(0)
   assert(context.family==case[1] and context.combatDataPolicy==case[4] and context.runtimeVerified==false)
   assert(context.class=='SHAMAN' and context.level==11 and context.actionContext=='player')
   assert(a.db.sv==e.RotationMasterDB and a.db.profile and a.db.global and a.db.char)
   assert(next(a.delayed_condition)~=nil and not a.conditionDefinitions.ECS_STAT,'absent extension was installed')
   assert(type(a.longtermCache)=='table' and type(a.unitsInRange)=='table')
   assert(c.optionalAbsent() and _G.RotationMasterDB==c.outerSaved,'fixture wrote host SavedVariables')
  end)
  test('actual Built In browse and independent editable clone stay safe '..label,function()
   local c=new(case);local a=c.a;local before=assert(a.RotationData.CopyData(a:GetDefaultRotation(source).envelope))
   local rows=a:ListDefaultRotations(0);assert(#rows==1 and rows[1].id==source and rows[1].readOnly)
   assert(rows[1].eligible==(case[1]=='tbc'),'foreign-family Built In advice leaked')
   local parent=a:CreateConditionGroup();parent:SetUserData('defaultWholeScroll',true)
   a:CreateDefaultRotationOptions(parent,0,source,function()end)
   assert(F.text(parent):find('Built In',1,true) and #parent.children>2,'actual reference did not render')
   local first,why=a:CloneDefaultRotation(0,source,'First reference');assert(first,why)
   local second=assert(a:CloneDefaultRotation(0,source,'Second reference'))
   local one,two=assert(a:GetEditableRotation(0,first)),assert(a:GetEditableRotation(0,second))
   assert(one~=two and one.rotation[1].id~=two.rotation[1].id)
   one.rotation[1].action=974;one.description='Manual reference edit'
   assert(two.rotation[1].action==403 and equal(a:GetDefaultRotation(source).envelope,before))
   if case[1]~='tbc' then assert(not a:GetRuntimeRotation(0,first) and not a:GetRuntimeRotation(0,second))end
   a:ReleaseConditionWidget(parent)
   assert(c.optionalAbsent() and _G.RotationMasterDB==c.outerSaved)
  end)
  test('declared restricted metadata does not query a legacy fallback '..label,function()
   local c=new(case);local a,e=c.a,c.e;local opaque={};local mode='restricted';local legacy=0
   e.canaccessvalue=function(value)return not rawequal(value,opaque)end
   e.C_Item={GetItemInfo=function()
    if mode=='error' then error('metadata unavailable')end
    if mode=='missing' then return nil end
    if mode=='restricted' then return opaque end
    return 'Recovered item','item:7',nil,nil,nil,nil,nil,nil,nil,77
   end,GetItemInfoInstant=function()return 7,nil,nil,nil,77 end}
   e.GetItemInfo=function()legacy=legacy+1;return 'Wrong fallback','item:7' end
   local provider=a:GetReferenceProvider('Item_EditBox')
   for _,bad in ipairs({'restricted','error','missing'})do
    mode=bad;assert(a:UpdateReferenceItem(7)==nil);assert(provider.info(7)==nil)
    local parent=a:CreateConditionGroup();parent:SetUserData('defaultWholeScroll',true)
    a:CreateDefaultRotationOptions(parent,0,source,function()end);a:ReleaseConditionWidget(parent)
   end
   assert(legacy==0,'failed declared API fell through to unrelated backend')
   mode='ready';local info=assert(a:UpdateReferenceItem(7));assert(info.id==7 and info.name=='Recovered item')
   assert(provider.info(7).name=='Recovered item' and c.optionalAbsent())
  end)
 else
  test('wire codec import and clone use data only and retain policy '..label,function()
   local c=new(case);local a=c.a;local codec=c.codec()
   local executions=0
   a:RegisterCondition('BASELINE_NOEXEC',{description='Data-only test predicate',fields={},customCode=true,
    evaluate=function()executions=executions+1;error('import executed source')end,
    print=function()executions=executions+1;error('reference executed source')end})
   local body={name='Portable reference',rotation={{id='incoming-step',type='stop',conditions={type='BASELINE_NOEXEC'}}},cooldowns={}}
   local text=assert(codec:Encode(body));local decoded=assert(codec:Decode(text));assert(decoded.kind=='legacy' and decoded.original==text)
   local session=a.RotationData.NewImportSession(codec,a:GetImportValidationOptions())
   local candidate=assert(session:Stage(text));assert(candidate.original==text and candidate.validation.resolved)
   local id,why=a:ApplyRotationImport(session,candidate.token,0,'Imported reference');assert(id,why)
   local custom=assert(a:GetEditableRotation(0,id));assert(custom.rotation[1].id~='incoming-step')
   local duplicate=assert(a:DuplicateCustomRotation(0,id,'Independent reference'))
   local copy=assert(a:GetEditableRotation(0,duplicate));custom.description='Edited reference'
   assert(copy~=custom and copy.description==nil and copy.rotation[1].id~=custom.rotation[1].id)
   -- The combat-data policy is retained, but it no longer decides whether a complete rotation runs (3831e918).
   assert(a.Platform:GetCombatDataPolicy()==case[4],'client policy changed: '..tostring(a.Platform:GetCombatDataPolicy()))
   local parent=a:CreateConditionGroup();a:CreateRotationReference(parent,custom,0);a:ReleaseConditionWidget(parent)
   body.rotation[1].conditions.type='MISSING_BASELINE_DEFINITION'
   local unresolved=assert(codec:Encode(body));candidate=assert(session:Stage(unresolved))
   local saved=a:CopySettingsData(a.db.profile)
   local rejected,reason=a:ApplyRotationImport(session,candidate.token,0,'Rejected')
   assert(not rejected and reason=='unresolved-import' and session:GetCandidate().original==unresolved)
   assert(equal(a.db.profile,saved),'failed import mutated saved state')
   local invalid,invalidReason=codec:Decode('RM9:not-supported');assert(not invalid and invalidReason)
   assert(executions==0,'data import/clone/reference executed a custom callback')
   assert(c.optionalAbsent() and _G.RotationMasterDB==c.outerSaved)
  end)
 end
end
finish()
