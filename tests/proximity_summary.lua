local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local inverse,old,repaired=dofile('tests/fixtures/restore_proximity_summary_repairs.lua')
local previousInverse=inverse;local restoreZone=dofile('tests/fixtures/restore_zone_text_repairs.lua')
inverse=function(text,body)if not body then text=restoreZone(text) end;return previousInverse(text,body)end
local newKey='the number of %s members%s within %s yards of %s'
local oldKey='number of %s members%s within %d yards'
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function fixture()
 local f=F.new(11,2,'SHAMAN');local a,e=f.addon,f.env;local s={units={player={x=0,y=0},party1={x=12.25,y=0}}}
 e.PARTY='Party';e.UnitExists=function(unit) return s.units[unit]~=nil end
 e.IsInRaid=function(...) assert(select('#',...)==0);return false end;e.IsInGroup=function(...) assert(select('#',...)==0);return true end
 e.UnitPlayerOrPetInParty=function(unit,...) assert(select('#',...)==0);return s.units[unit]~=nil end
 e.UnitPosition=function(unit,...) assert(select('#',...)==0);local u=s.units[unit];if u then return u.y,u.x,0,1 end end
 f.libraries['LibRangeCheck-3.0'].GetRange=function() error('readable coordinates must not query a range estimate') end
 for _,path in ipairs({'Diagnostics/errors.lua','Data/plain.lua','Data/tags.lua','Data/rotation_tree.lua','Core/rotation_sequence.lua','Core/conditions.lua','Conditions/common.lua','Conditions/spatial.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 return f,a,s
end
local function node(tag) return {type=tag or 'PROXIMITY',unit='player',operator='EQUALS',value=2,distance=12.5} end
local function known(a,v)
 assert(a.conditionDefinitions[v.type].valid(0,v));assert(a:evaluateConditionResult(v).status=='match' and a:evaluateConditionResult({type='NOT',value=v}).status=='no-match');local selected
 local body={rotation={{id='guard',type='branch',conditions=v,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}};assert(a:EvaluateRotationSequence(body,function(n) return a:evaluateConditionResult(n) end,function(n) selected=n.id;return true end).status=='complete' and selected=='yes')
end
local function mount(a,value,definition)
 definition=definition or a.conditionDefinitions.PROXIMITY;local parent=a:CreateConditionGroup();parent:SetWidth(640);local state={prints=0,statuses=0};local top={};local funcs={}
 function top:GetUserData(key) if key=='root' then return value elseif key=='funcs' then return funcs end end
 function funcs:print(root,spec) assert(root==value and spec==7);state.prints=state.prints+1;return definition.print(spec,value) end
 function top:SetStatusText(text) state.statuses=state.statuses+1;state.status=text end
 parent:SetUserData('top',top);definition.widget(parent,7,value);a:configure_frame(parent);parent:DoLayout();return parent.children[3],parent,state
end
local function clear(distance)
 distance.editbox:SetText('');distance.editbox:GetScript('OnTextChanged')(distance.editbox,true);distance.editbox:GetScript('OnEnterPressed')(distance.editbox)
end

test('fractional summary describes the exact inclusive radius used by real membership and branches',function()
 local _,a=fixture();local v=node();known(a,v);assert(a:printCondition(v,0):find('within 12.5 yards',1,true))
 v.distance=12;v.value=1;known(a,v);assert(a:printCondition(v,0):find('within 12 yards',1,true))
end)
test('zero fractional and whole radii retain their values without changing configured numeric fields',function()
 local _,a,s=fixture();for _,radius in ipairs({0,.5,12.5,40}) do local v=node();v.distance=radius;s.units.party1.x=radius;known(a,v);assert(a:printCondition(v,0):find('within '..radius..' yards',1,true) and v.distance==radius) end
end)
test('native user clear stores nil and displays the existing placeholder before status refresh',function()
 local _,a=fixture();local v=node();local distance,parent,state=mount(a,v);assert(distance:GetText()=='12.5');clear(distance)
 assert(v.distance==nil and state.prints==1 and state.statuses==1 and state.status:find('<distance>',1,true));assert(not a.conditionDefinitions.PROXIMITY.valid(0,v),'placeholder silently completed field');parent:Release()
end)
test('new locale contract retains group pet unit and negation choices without consuming the old integer key',function()
 local f,a=fixture();f.translations[newKey]='GROUP=%s PETS=%s RADIUS=%s UNIT=%s';f.translations[oldKey]='WRONG OLD FORMAT %s %s %d';a.units.player='you {unit} 50%'
 for _,same in ipairs({false,true}) do for _,pets in ipairs({false,true}) do local v=node();v.samegroup=same;v.includepets=pets
  local expected='GROUP='..(same and 'Party' or 'Raid or Party')..' PETS='..(pets and ' (including pets)' or '')..' RADIUS=12.5';local positive=a:printCondition(v,0);local negative=a:printCondition({type='NOT',value=v},0)
  assert(positive:find(expected,1,true) and negative:find(expected,1,true) and positive:find('you {unit} 50%',1,true));assert(negative:find('is not equal to',1,true) and a:printCondition({type='NOT',value={type='NOT',value=v}},0)==positive)
 end end
end)
test('summary performs no native queries or saved-data writes even when distance is unconfigured',function()
 local f,a=fixture();local marker={};local v=node();v.sentinel=marker;local before=a:CopySettingsData(v)
 for _,name in ipairs({'UnitExists','UnitPosition','IsInGroup','IsInRaid','UnitPlayerOrPetInParty'}) do f.env[name]=function() error('summary queried '..name) end end
 a:printCondition(v,0);assert(v.sentinel==marker and a:SettingsDataEqual(v,before));v.distance=nil;assert(a:printCondition(v,0):find('<distance>',1,true))
end)
test('retired distance callbacks cannot mutate their old or recycled field owners',function()
 local _,a=fixture();local oldValue=node();local distance,parent,state=mount(a,oldValue);local stale=distance.events.OnEnterPressed;parent:Release()
 local fresh=node();fresh.distance=9;local _,owner,nextState=mount(a,fresh);stale(distance,'OnEnterPressed','');assert(oldValue.distance==12.5 and fresh.distance==9 and state.prints==0 and nextState.prints==0);owner:Release()
end)
test('strict single-body inverse preserves the entire spatial module and complete historical export',function()
 local _,a=fixture();local text=read('Conditions/spatial.lua');assert(a:FunctionSourceHash(inverse(text))=='fc0022e0','spatial differs from5fbad46 beyond PROXIMITY print');assert(inverse(repaired,true)==old and not pcall(inverse,old,true) and not pcall(inverse,repaired..' ',true) and not pcall(inverse,text..text))
 local source=a:GetBuiltinConditionSource('PROXIMITY');if source.print==repaired then source.print=inverse(source.print,true) else assert(source.print==old) end;assert(a:FunctionSourceHash(source)=='2004f0b7','unrelated PROXIMITY fields params or bindings changed')
 for name,hash in pairs({RangeCheck='272f05e0',booleanRead='3b3ceeb2',color='158ebd8f',finite='9e1e3ece',helpers='9485f785',protectedRead='cc49d134',rcf='a7ab75e4'}) do local id='builtin:Conditions/spatial.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules['Conditions/spatial.lua'](name))) end
end)
test('archived raw source keeps the integer locale contract truncation and stored source unchanged',function()
 local f,a=fixture();local source=a:GetBuiltinConditionSource('PROXIMITY');source.print=old;assert(a:FunctionSourceHash(source)=='2004f0b7');local before=a:CopySettingsData(source);a.db.global.custom_conditions={RAW=source};a:RegisterCondition('RAW',assert(a:CompileCustomCondition('RAW',source)));f.translations[oldKey]='OLD %s %s %d';f.translations[newKey]='UNUSED %s %s %s %s'
 local v=node('RAW');assert(a:printCondition(v,0):find('OLD Raid or Party  12',1,true));v.distance=nil;assert(not pcall(a.printCondition,a,v,0));assert(a:SettingsDataEqual(source,before) and a.db.global.custom_conditions.RAW==source)
end)
test('actual current exported copy displays fractional and cleared native values through unchanged bindings',function()
 local _,a=fixture();local source=a:GetBuiltinConditionSource('PROXIMITY');assert(source.print==repaired,'PROXIMITY catalog pending');local before=a:CopySettingsData(source);a:RegisterCondition('COPY_PROXIMITY',assert(a:CompileCustomCondition('COPY_PROXIMITY',source)))
 local v=node('COPY_PROXIMITY');known(a,v);assert(a:printCondition(v,0):find('within 12.5 yards',1,true));local distance,parent,state=mount(a,v,a.conditionDefinitions.COPY_PROXIMITY);clear(distance);assert(v.distance==nil and state.status:find('<distance>',1,true));parent:Release();assert(a:SettingsDataEqual(source,before))
end)
finish()
