-- Actual chat/menu/AceDB/scoped publication boundaries; no live client required.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local startup=read('tests/startup.lua')
local common=assert(startup:match('(local function fixture%(modern, absentThreat%).-)\ntest%('))
local persistent=assert(startup:match('(local function persistentFixture%(saved,folder,scoped%).-)\n%-%- WoW SavedVariables'))
persistent=persistent:gsub("    load%('main.lua'%)\n",'')
persistent=persistent:gsub("load%('Core/rotation_library.lua'%)",[[do local h=io.open('Core/rotation_choice_preferences.lua');if h then h:close();load('Core/rotation_choice_preferences.lua') end end;load('Core/rotation_library.lua')]])
persistent=persistent:gsub("    addon.GetRotationContext=function%(%)",[[    load('main.lua')
    addon.GetRotationContext=function()]])
local make=assert(loadstring(common..'\n'..persistent..'\nreturn persistentFixture','@choice-real-main-fixture'))()
local function fixture(saved)
 local e,a,_,load=make(saved,nil,true);a.currentSpec=0;a.db.profile.disable_autoswitch=false
 a.info=function()end;a.warn=function()end;a.debug=function()end;a.verbose=function()end
 a.RemoveAllCurrentGlows=function()end;a.DestroyAllGlows=function()end;a.EnableRotationTimer=function()end;a.DisableRotationTimer=function()end
 a.rotationValidConditions=function()return true end;a.evaluateCondition=function()return false end
 e.LibStub('AceConsole-3.0').GetArgs=function(_,s)return s:match('^(%S+)'),(s:find(' ',1,true)or #s)+1 end
 a:InstallRotationProfileLifecycle();a.RefreshConfiguration=function()end;a.Fetch=function()end;a.ButtonFetch=function()end
 load('UI/settings_draft.lua')
 local reference={kind='custom',address={scope='class',class='SHAMAN',owner='SHAMAN',spec=0,id='choice'}}
 local body={name='Choice',rotation={},cooldowns={},switch={}}
 local function save(r,b,scope)local old,token=a:GetRotationRecordSnapshot(r.address.spec,r);return a:CommitRotationDraft(r,old and token or nil,{body=b or body},scope)end
 if not a:GetRotationRecordSnapshot(0,reference)then assert(save(reference))end
 local key=assert(a:GetScopedRotationCoordinator():Key(reference))
 return e,a,reference,key,save,load
end
local function entry(a)local p=a.db.profile.rotationChoicePreferences;return p and p.entries[1]end
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function select(a)a:HandleCommand('set Choice');assert(a.manualRotation and a.currentRotation);assert(entry(a),'manual choice was not persisted')end
local function copy(v)local out={};for k,x in pairs(v)do out[k]=type(x)=='table'and copy(x)or x end;return out end

test('manual chat persists detached stable spec0 reference without changing body revision',function()
 local _,a,r,key=fixture();local before=copy(a:GetRotationRecordSnapshot(0,r).body);select(a)
 local row=assert(entry(a));assert(row.spec==0 and row.family=='tbc'and row.actionContext=='player'and row.character==a.db.keys.char and equal(row.reference,r));assert(a.currentRotation==key)
 assert(equal(before,a:GetRotationRecordSnapshot(0,r).body));r.address.id='poison';assert(row.reference.address.id=='choice')
end)
test('saved choice restores after fresh actual AceDB startup and bypasses switch predicate only',function()
 local e,a,r=fixture();select(a);local saved={RotationMasterDB=copy(e.RotationMasterDB)}
 local _,b=fixture(saved);b:SwitchRotation();assert(b.manualRotation and equal(b:ResolveRotationReference(0,b.currentRotation),r))
end)
test('Auto removes only current domain and same-ID selection does not restart effects',function()
 local _,a=fixture();select(a);local calls=0;a.EnableRotationTimer=function()calls=calls+1 end;a:HandleCommand('set '..a.currentRotation);assert(calls==0 and entry(a))
 a:HandleCommand('set auto');assert(not a.manualRotation and not entry(a))
end)
test('actual minimap selection shares persistence and Auto path',function()
 local e,a,_,key=fixture();local rows={};e.UIDropDownMenu_CreateInfo=function()return{}end;e.UIDropDownMenu_AddButton=function(row)rows[#rows+1]=copy(row)end
 e.minimapInitialize();local choose,auto;for _,row in ipairs(rows)do if row.arg1==key then choose=row elseif row.text=='Automatic Switching'then auto=row end end
 assert(choose and auto);choose.func(nil,key);assert(entry(a)and a.manualRotation);auto.func(nil,nil);assert(not entry(a)and not a.manualRotation)
end)
test('profile switching restores only that profile and reset returns to Auto',function()
 local _,a,r=fixture();select(a);a.db:SetProfile('Other');assert(not a.manualRotation and not entry(a));a.db:SetProfile('Default');assert(a.manualRotation and equal(a:ResolveRotationReference(0,a.currentRotation),r));a.db:ResetProfile();assert(not a.manualRotation and not entry(a))
end)
test('specialization and unavailable context suspend then restore exact domain',function()
 local _,a,r=fixture();select(a);local selected=2;a.Platform.GetRotationSpecialization=function()return{key=selected}end;a.UpdateSpecSpells=function()end;a.ButtonFetch=function()end
 a:UpdateSkill();assert(not a.manualRotation and entry(a).spec==0);selected=0;a:UpdateSkill();assert(a.manualRotation and equal(a:ResolveRotationReference(0,a.currentRotation),r))
 local context=a.GetRotationContext;a.GetRotationContext=function(self,spec)local c=context(self,spec);c.actionContext='vehicle';return c end
 a:InvalidateRotationChoiceContext();a:SwitchRotation();assert(not a.manualRotation and entry(a).actionContext=='player')
 a.GetRotationContext=context;a:InvalidateRotationChoiceContext();a:SwitchRotation();assert(a.manualRotation and equal(a:ResolveRotationReference(0,a.currentRotation),r))
end)
test('actual in-combat control and vehicle notifications reconcile before advice resumes',function()
 local _,a,r=fixture();select(a);a.inCombat=true;local context=a.GetRotationContext;local vehicle=true;local observed
 a.GetRotationContext=function(self,spec)local c=context(self,spec);c.actionContext=vehicle and'vehicle'or'player';return c end
 a.EvaluateNextAction=function(self)observed=self.manualRotation end
 a:PLAYER_CONTROL_GAINED('PLAYER_CONTROL_GAINED');assert(observed==false and not a.manualRotation,'old player choice resumed in vehicle context')
 vehicle=false;a:VEHICLE_UPDATE('VEHICLE_UPDATE');assert(a.manualRotation and equal(a:ResolveRotationReference(0,a.currentRotation),r))
end)
test('public context-method and character-key replacement retire cached domain authority',function()
 for _,replace in ipairs({'method','character'})do
  local _,a=fixture();select(a);a:SwitchRotation();local original=a.GetRotationContext
  if replace=='method'then a.GetRotationContext=function(self,spec)local c=original(self,spec);c.actionContext='vehicle';return c end else a.db.keys.char='Other - Realm'end
  a:SwitchRotation();assert(not a.manualRotation and entry(a),'stale cached domain survived replacement')
 end
end)
test('disabled desired body suspends without losing preference and restores latest revision',function()
 local _,a,r,_,save=fixture();select(a);local b=copy(a:GetRotationRecordSnapshot(0,r).body);b.disabled=true;assert(save(r,b));a:SwitchRotation();assert(not a.manualRotation and entry(a))
 b.disabled=nil;b.description='Latest';assert(save(r,b));a:SwitchRotation();assert(a.manualRotation and a:GetRuntimeRotation(0,a.currentRotation).description=='Latest')
end)
test('exact Move retargets preference but equal-ID peer deletion does not',function()
 local _,a,r,_,save=fixture();select(a);local peer=copy(r);peer.address.scope='character';peer.address.owner=a.db.keys.char;assert(save(peer,{name='Peer',rotation={},cooldowns={}}))
 local _,pt=a:GetRotationRecordSnapshot(0,peer);assert(a:DeleteRotationRecord(peer,pt));assert(equal(entry(a).reference,r))
 local old,token=a:GetRotationRecordSnapshot(0,r);local moved=assert(a:CommitRotationDraft(r,token,{body=old.body},'character'));assert(equal(entry(a).reference,moved))
end)
test('exact Delete clears desired reference and reused ID cannot resurrect it',function()
 local _,a,r,_,save=fixture();select(a);local _,token=a:GetRotationRecordSnapshot(0,r);assert(a:DeleteRotationRecord(r,token));assert(not entry(a));assert(save(r));a:SwitchRotation();assert(not a.manualRotation)
end)
test('failed ownership move preserves original preference',function()
 local _,a,r,_,save=fixture();select(a);local peer=copy(r);peer.address.scope='character';peer.address.owner=a.db.keys.char;assert(save(peer))
 local old,token=a:GetRotationRecordSnapshot(0,r);assert(not a:CommitRotationDraft(r,token,{body=old.body},'character'));assert(equal(entry(a).reference,r))
end)
test('reentrant manual timer selection wins saved choice',function()
 local _,a,r,_,save=fixture();local other=copy(r);other.address.id='other';assert(save(other,{name='Other',rotation={},cooldowns={}}));local inside=false
 a.EnableRotationTimer=function(self)if not inside then inside=true;self:HandleCommand('set Other')end end;a:HandleCommand('set Choice');assert(a:GetRuntimeRotation(0,a.currentRotation).name=='Other'and equal(entry(a).reference,other))
end)
test('diagnostic stop is not cleared or activated by restoration',function()
 local _,a=fixture();select(a);a.currentRotation=nil;a.manualRotation=false;a.adviceErrorReport=17;a:InvalidateRotationChoiceContext();a:SwitchRotation();assert(not a.currentRotation and a.adviceErrorReport==17)
end)
test('ordinary selection callbacks do not query context or scan preferences again',function()
 local _,a=fixture();local context=a.GetRotationContext;local blocked=false
 a.GetRotationContext=function(self,spec)assert(not blocked,'hot context query');return context(self,spec)end
 select(a);a:SwitchRotation();blocked=true
 for i=1,12 do a:SwitchRotation()end;assert(a.manualRotation and entry(a))
end)
test('closed optional profile transfer round trips numeric spec0 without materializing absence',function()
 local _,a,_,_,_,load=fixture();load('Core/profile_data.lua');select(a)
 local p={version=2,rotationChoicePreferences=copy(a.db.profile.rotationChoicePreferences)};assert(a:ValidateProfileTransfer(p));local wire=assert(a:ProfileToPortable(p));local out=assert(a:ProfileFromPortable(wire));assert(equal(out,p)and out.rotationChoicePreferences.entries[1].spec==0)
 assert(a:ProfileToPortable({version=2}).rotationChoicePreferences==nil)
 for _,mutate in ipairs({function(x)x.extra=true end,function(x)x.entries[1].spec='0'end,function(x)x.entries[1].reference.address.owner='foreign'end,function(x)x.entries[2]=x.entries[1]end,function(x)setmetatable(x.entries,{})end,function(x)x.entries[1].intent='aoe'end})do local invalid=copy(p);mutate(invalid.rotationChoicePreferences);assert(not a:ValidateProfileTransfer(invalid));assert(not a:ProfileToPortable(invalid)and not a:ProfileFromPortable(invalid))end
end)
test('builtin disable suspends desired choice and re-enable restores only eligible source',function()
 local _,a=fixture();local row
 for _,h in ipairs(a:ListRotationHeaders(0))do if h.kind=='builtin'then row=h;break end end;assert(row)
 local pack=a:GetRuntimeRotation(0,row.key);assert(pack);a:HandleCommand('set '..pack.name);assert(entry(a).reference.kind=='builtin')
 local id=entry(a).reference.id;assert(a:SetDefaultRotationEnabled(id,false));a:SwitchRotation();assert(not a.manualRotation and entry(a)and a.rotationChoiceSuspended)
 assert(a:SetDefaultRotationEnabled(id,true));a:SwitchRotation();assert(a.manualRotation and a:ResolveRotationReference(0,a.currentRotation).id==id)
end)
test('foreign character and family cannot restore another domain',function()
 for _,field in ipairs({'character','family','class'})do
  local _,a=fixture();select(a);local original=a.GetRotationContext
  if field=='character'then a.db.keys.char='Other - Realm'else a.GetRotationContext=function(self,spec)local c=original(self,spec);c[field]=field=='family'and'era'or'MAGE';return c end end
  a:InvalidateRotationChoiceContext();a:SwitchRotation();assert(not a.manualRotation and entry(a))
 end
end)
test('actual profile copy transfers desired data and resolves current ownership afresh',function()
 local _,a,r=fixture();select(a);a.db:SetProfile('Copied');a.db:CopyProfile('Default');assert(a.manualRotation and equal(a:ResolveRotationReference(0,a.currentRotation),r))
end)
test('broker suspension display uses cached state without provider queries',function()
 local e,a,r,_,save=fixture();select(a);local body=copy(a:GetRotationRecordSnapshot(0,r).body);body.disabled=true;assert(save(r,body));a:SwitchRotation();assert(a.rotationChoiceSuspended)
 local lines={};a.GetRotationContext=function()error('tooltip provider query')end;e.broker.OnTooltipShow({SetText=function()end,AddLine=function(_,line)lines[#lines+1]=line end})
 assert(lines[#lines]=='Saved manual choice is unavailable in the current context.')
end)
local function interceptStore(a,callback)
 local data=a.RotationData;local construct=data.NewRotationStore
 data.NewRotationStore=function(options)
  local store,why,guard=construct(options);local commit=store.Commit
  store.Commit=function(self,...)local ok,reason=commit(self,...);if ok then callback()end;return ok,reason end
  return store,why,guard
 end
 assert(a:BindRotationProfile());data.NewRotationStore=construct
end
test('post-Store newer explicit Auto wins over old Move retarget',function()
 local _,a,r=fixture();select(a);local once=false
 interceptStore(a,function()if not once then once=true;a:HandleCommand('set auto')end end)
 local old,token=a:GetRotationRecordSnapshot(0,r);assert(a:CommitRotationDraft(r,token,{body=old.body},'character'));assert(once and not entry(a))
end)
test('post-Store profile replacement cannot publish preferences into either profile',function()
 local _,a,r=fixture();select(a);local original=a.db.profile;local before=copy(original.rotationChoicePreferences)
 interceptStore(a,function()a.db.profile={enable=false}end)
 local old,token=a:GetRotationRecordSnapshot(0,r);assert(a:CommitRotationDraft(r,token,{body=old.body},'character'))
 assert(equal(original.rotationChoicePreferences,before)and not a.db.profile.rotationChoicePreferences)
end)
test('post-Store nested Delete wins and does not resurrect old moved choice',function()
 local _,a,r=fixture();select(a);local once=false
 local moved=copy(r);moved.address.scope='character';moved.address.owner=a.db.keys.char
 interceptStore(a,function()if not once then once=true;local _,token=a:GetRotationRecordSnapshot(0,moved);assert(a:DeleteRotationRecord(moved,token))end end)
 local old,token=a:GetRotationRecordSnapshot(0,r);assert(a:CommitRotationDraft(r,token,{body=old.body},'character'));assert(once and not entry(a))
end)
test('post-Store nested Move clears only the old desired address when target disappeared',function()
 local _,a,r=fixture();select(a);local once=false;local moved=copy(r);moved.address.scope='character';moved.address.owner=a.db.keys.char
 interceptStore(a,function()if not once then once=true;local old,token=a:GetRotationRecordSnapshot(0,moved);assert(a:CommitRotationDraft(moved,token,{body=old.body},'class'))end end)
 local old,token=a:GetRotationRecordSnapshot(0,r);assert(a:CommitRotationDraft(r,token,{body=old.body},'character'));assert(once and not entry(a));assert(a:GetRotationRecordSnapshot(0,r))
end)
test('nested scoped Delete and exact-ID recreation cannot inherit old moved choice',function()
 local _,a,r=fixture();select(a);local once=false;local moved=copy(r);moved.address.scope='character';moved.address.owner=a.db.keys.char
 interceptStore(a,function()if not once then once=true;local _,token=a:GetRotationRecordSnapshot(0,moved);assert(a:DeleteRotationRecord(moved,token));assert(a:CommitRotationDraft(moved,nil,{body={name='Reused ID',rotation={},cooldowns={}}},'character'))end end)
 local old,token=a:GetRotationRecordSnapshot(0,r);assert(a:CommitRotationDraft(r,token,{body=old.body},'character'));assert(once and a:GetRotationRecordSnapshot(0,moved).body.name=='Reused ID'and not entry(a))
end)
test('same-ID content edit preserves preference root identity and latest body revision',function()
 local _,a,r,_,save=fixture();select(a);local root=a.db.profile.rotationChoicePreferences;local body=copy(a:GetRotationRecordSnapshot(0,r).body);body.description='Edited';assert(save(r,body))
 assert(a.db.profile.rotationChoicePreferences==root and a:GetRotationRecordSnapshot(0,r).body.revision==2)
end)
test('nested failed scoped operation does not advance successful-publication authority',function()
 local _,a,r=fixture();select(a);local once=false;local moved=copy(r);moved.address.scope='character';moved.address.owner=a.db.keys.char
 interceptStore(a,function()if not once then once=true;assert(not a:CommitRotationDraft(moved,nil,{body={name='Collision',rotation={},cooldowns={}}},'character'))end end)
 local old,token=a:GetRotationRecordSnapshot(0,r);assert(a:CommitRotationDraft(r,token,{body=old.body},'character'));assert(once and equal(entry(a).reference,moved))
end)
test('successful Store move finalizes choice before existing post-save copying can throw',function()
 local _,a,r=fixture();select(a);interceptStore(a,function()a.RotationData.CopyData=function()error('existing post-save copy failure')end end)
 local old,token=a:GetRotationRecordSnapshot(0,r);local ok=pcall(a.CommitRotationDraft,a,r,token,{body=old.body},'character');assert(not ok)
 assert(entry(a).reference.address.scope=='character','successful Store move left stale desired address')
end)
test('same-profile coordinator retirement after Store success rejects old finalizer authority',function()
 local _,a,r=fixture();select(a);local before=copy(a.db.profile.rotationChoicePreferences);local once=false
 interceptStore(a,function()if not once then once=true;assert(a:BindRotationProfile())end end)
 local old,token=a:GetRotationRecordSnapshot(0,r);assert(a:CommitRotationDraft(r,token,{body=old.body},'character'));assert(once and equal(before,a.db.profile.rotationChoicePreferences))
end)
test('newer root or same-root preference mutation cannot be overwritten by Move finish',function()
 for _,replace in ipairs({false,true})do
  local _,a,r=fixture();select(a);local preferred
  interceptStore(a,function()
   if replace then a.db.profile.rotationChoicePreferences=copy(a.db.profile.rotationChoicePreferences)end
   a.db.profile.rotationChoicePreferences.entries[1].reference={kind='builtin',id='newer-request'};preferred=copy(a.db.profile.rotationChoicePreferences)
  end)
  local old,token=a:GetRotationRecordSnapshot(0,r);assert(a:CommitRotationDraft(r,token,{body=old.body},'character'));assert(equal(preferred,a.db.profile.rotationChoicePreferences))
 end
end)
test('explicit Auto preserves another action-context desired choice',function()
 local _,a,r,_,save=fixture()
 -- A bare rotation joins the vehicle domain only by requiring it in its switch.
 a:RegisterCondition('ACTION_CONTEXT',{fields={context='string'},requiredFields={'context'},valid=function()return true end,evaluate=function()return false end,print=function()return ''end,widget=function()end,help=function()end})
 assert(save(r,{name='Choice',rotation={},cooldowns={},switch={type='ACTION_CONTEXT',context='vehicle'}}))
 select(a);local context=a.GetRotationContext
 a.GetRotationContext=function(self,spec)local c=context(self,spec);c.actionContext='vehicle';return c end;a:HandleCommand('set Choice');assert(#a.db.profile.rotationChoicePreferences.entries==2)
 a.GetRotationContext=context;a:InvalidateRotationChoiceContext();a:SwitchRotation();a:HandleCommand('set auto')
 assert(#a.db.profile.rotationChoicePreferences.entries==1 and entry(a).actionContext=='vehicle'and not a.manualRotation)
end)
test('unrelated malformed preferences cannot block managed Move or Delete',function()
 local _,a,r=fixture();a.db.profile.rotationChoicePreferences={version=1,entries=false};local old,token=a:GetRotationRecordSnapshot(0,r)
 local moved=assert(a:CommitRotationDraft(r,token,{body=old.body},'character'));local _,nextToken=a:GetRotationRecordSnapshot(0,moved);assert(a:DeleteRotationRecord(moved,nextToken));assert(a.db.profile.rotationChoicePreferences.entries==false)
end)
test('finalizer uses no public copying, notification or string-index callbacks',function()
 local _,a,r=fixture();select(a);local calls=0
 -- Scope has its own existing public copying after Store success. Isolate the
 -- new source-held finalizer itself from those unchanged boundaries.
 local scope=a:GetScopedRotationCoordinator();local prepare,complete
 for i=1,40 do local name,value=debug.getupvalue(scope.Delete,i);if not name then break end;if name=='prepareChoicePublication'then prepare=value elseif name=='finishChoicePublication'then complete=value end end
 assert(prepare and complete);local ticket=assert(prepare(a.db.profile,r,nil))
 a.RotationData.CopyData=function()calls=calls+1;error('post-write public copy')end
 a.InvalidateRotationChoiceContext=function()calls=calls+1;error('post-write notification')end
 local mt=getmetatable('');local index=mt.__index;local poison={};setmetatable(poison,{__index=function()calls=calls+1;error('string lookup callback')end});mt.__index=poison
 local ok,result=pcall(complete,ticket,true);mt.__index=index
 assert(ok and result and calls==0 and not entry(a))
end)
test('failed or throwing Store commit cannot write a prepared choice change',function()
 for _,throws in ipairs({false,true})do
  local _,a,r=fixture();select(a);local before=copy(a.db.profile.rotationChoicePreferences);local data=a.RotationData;local construct=data.NewRotationStore
  data.NewRotationStore=function(options)local store,why,guard=construct(options);store.Commit=function()if throws then error('commit failure')end;return nil,'commit failure'end;return store,why,guard end
  assert(a:BindRotationProfile());data.NewRotationStore=construct;local old,token=a:GetRotationRecordSnapshot(0,r)
  local ok,result=pcall(a.CommitRotationDraft,a,r,token,{body=old.body},'character');assert(not ok or not result);assert(equal(before,a.db.profile.rotationChoicePreferences))
 end
end)
test('unavailable context is cached until a cold invalidation and cannot assume a family',function()
 local _,a=fixture();select(a);local context=a.GetRotationContext;local calls=0
 a.GetRotationContext=function(self,spec)calls=calls+1;local c=context(self,spec);c.family='unknown';return c end;a:InvalidateRotationChoiceContext();a:SwitchRotation();assert(not a.manualRotation and entry(a))
 -- Disable automatic selection here so the control counts only new preference
 -- work, not the existing automatic candidate pass/provider observations.
 a.db.profile.disable_autoswitch=true;calls=0;for i=1,12 do a:SwitchRotation()end;assert(calls==0)
end)
if jit then test('new desired choice survives actual profile wire codec without execution authority',function()
 local _,a,_,_,_,load=fixture();load('Core/profile_data.lua');select(a);local p={version=2,rotationChoicePreferences=copy(a.db.profile.rotationChoicePreferences)}
 local data,deps=dofile('tests/fixtures/codec.lua')();local codec=assert(data.NewCodec(deps));local wire=assert(a:ProfileToPortable(p))
 local text=assert(codec:Encode({format='RM-Profile',version=1,profile=wire}));local out=assert(a:ProfileFromPortable(assert(codec:Decode(text)).value.profile))
 assert(a:ValidateProfileTransfer(out)and equal(out,p)and out.rotationChoicePreferences.entries[1].spec==0)
end)end
test('cold unhandled restoration cannot forward a token retired by the switching-mode read',function()
 local _,a=fixture();a:SwitchRotation();local selected=a.currentRotation;local reached=false
 a.db.profile.disable_autoswitch=nil
 setmetatable(a.db.profile,{__index=function(_,key)if key=='disable_autoswitch'then reached=true;a:BeginActiveRotationTransition();return true end end})
 a:InvalidateRotationChoiceContext();local _,token=a:SwitchRotation()
 assert(reached and token==nil,'superseded cold-restoration token escaped');assert(a.currentRotation==selected)
end)
finish()
