local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local question='Interface\\Icons\\INV_Misc_QuestionMark'
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function fixture(class,legacy)
 local f=F.new(11,2,class or 'DRUID');local a,e=f.addon,f.env;local s={trace={},mode='ready',icon=123,form=1,count=2}
 local function log(kind,id,...) assert(select('#',...)==0,'extra native args');s.trace[#s.trace+1]=kind..':'..tostring(id) end
 e.GetNumShapeshiftForms=function(...) assert(select('#',...)==0);s.trace[#s.trace+1]='count';return s.count end
 e.GetShapeshiftFormInfo=function(index,...) log('form',index,...);if index==s.stop then return 900+index,false,true,nil end;return 900+index,false,true,index==1 and 123 or 456 end
 e.GetShapeshiftForm=function(...) assert(select('#',...)==0);s.trace[#s.trace+1]='current';return s.form end
 local function info(id,...)
  log('spell',id,...);if s.mode=='throw' then error('metadata failure') elseif s.mode=='missing' then return nil elseif s.mode=='restricted' then return s.opaque end
  return {name=id=='Ghost Wolf' and 'Ghost Wolf label' or 'Form '..id,iconID=s.icon,spellID=type(id)=='number' and id or 2645}
 end
 if legacy then
  e.GetSpellInfo=function(id,...) local r=info(id,...);if r then return r.name,nil,r.iconID,0,0,0,r.spellID end end
  e.GetSpellTexture=function(id,...) log('texture',id,...);return s.icon end
 else e.C_Spell={GetSpellInfo=info};e.GetSpellInfo=nil;e.GetSpellTexture=nil end
 for _,path in ipairs({'Diagnostics/errors.lua','Platform/spells.lua','Core/conditions.lua','Conditions/combat.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 s.opaque={};e.canaccessvalue=function(value) return not rawequal(value,s.opaque) end
 return f,a,s
end
local function mount(a,value,definition)
 definition=definition or a.conditionDefinitions.FORM;local parent=a:CreateConditionGroup();parent:SetWidth(640);local state={prints=0,statuses=0};local top={};local funcs={}
 function top:GetUserData(key) if key=='root' then return value elseif key=='funcs' then return funcs end end
 function funcs:print(root,spec) assert(root==value and spec==7);state.prints=state.prints+1;return definition.print(spec,value) end
 function top:SetStatusText(text) state.statuses=state.statuses+1;state.status=text end
 parent:SetUserData('top',top);definition.widget(parent,7,value);a:configure_frame(parent);parent:DoLayout()
 assert(#parent.children==2 and a:IsConditionWidget(parent.children[1]) and a:IsConditionWidget(parent.children[2]))
 return parent.children[1],parent.children[2],parent,state
end
local function choose(dropdown,key)
 dropdown.button:Click();for _,row in ipairs(dropdown.selector.rows) do if row.menuEntry and row.menuEntry.value==key then row:Click();return end end;error('form choice missing '..key)
end
local function reset(s) s.trace={} end
-- The editor offers forms by spell: stance bar first, then the class's other
-- forms on this client (project 11 is a Mists-family client), and a saved
-- stance-bar slot keeps its own entry, labelled with the form in that slot.
local DRUID_FORMS={5487,1066,768,783,24858,33891,33943,40120,114282}
local function candidates(ids) local t={};for _,id in ipairs(ids) do t[#t+1]='spell:'..id end;local one=table.concat(t,',');return one..','..one end
local function slot(label) return 'Stance bar slot 1 ('..label..')' end

local inverse,old,repaired=dofile('tests/fixtures/restore_form_localization.lua')
local function localized(legacy,label)
 local f,a,s=fixture('SHAMAN',legacy);local e=f.env;s.trace={};s.count=0;s.localized=label or 'Loup fantôme'
 local function info(id,...)
  assert(select('#',...)==0,'extra metadata argument');s.trace[#s.trace+1]='spell:'..tostring(id)
  if s.mode=='throw'then error('selected metadata failed')elseif s.mode=='restricted'then return s.opaque elseif s.mode=='missing'then return nil end
  if id==2645 or id==s.localized then return {name=s.localized,iconID=s.icon,spellID=2645}end
  if id=='Ghost Wolf' and s.override then return{name='Name override',iconID=999999,spellID=999999}end
 end
 if legacy then e.GetSpellInfo=function(id,...)local r=info(id,...);if r then return r.name,nil,r.iconID,0,0,0,r.spellID end end
 else e.C_Spell.GetSpellInfo=info;e.GetSpellInfo=function()error('modern selected failure fell back')end end
 return f,a,s
end
for _,legacy in ipairs({false,true})do
test('localized actual Shaman presentation uses fixed ID with exact arity legacy='..tostring(legacy),function()
 for _,label in ipairs({'Loup fantôme','Geisterwolf','늑대 정령','Ghost Wolf'})do
  local _,a,s=localized(legacy,label);local value={type='FORM',value=1};assert(a.conditionDefinitions.FORM.valid(0,value));reset(s)
  assert(a:printCondition(value,7):find(label,1,true),'summary lost readable localized Ghost Wolf');assert(table.concat(s.trace,',')=='spell:2645')
  reset(s);local icon,dropdown,parent=mount(a,value);assert(dropdown.list['1']==slot(label) and dropdown.list['spell:2645']==label and icon.image:GetTexture()==123 and value.value==1)
  assert(table.concat(s.trace,',')=='count,spell:2645,spell:2645,spell:2645,spell:2645');parent:Release()
 end
end)
end
test('fixed base spell deliberately replaces dynamic English-name override presentation authority',function()
 for _,legacy in ipairs({false,true})do local _,a,s=localized(legacy);s.override=true
  assert(a:printCondition({type='FORM',value=1},7):find(s.localized,1,true));local icon,dropdown,parent=mount(a,{value=1})
  assert(dropdown.list['1']==slot(s.localized) and icon.image:GetTexture()==123);for _,call in ipairs(s.trace)do assert(call~='spell:Ghost Wolf')end;parent:Release()
 end
end)
test('humanoid is lazy and unrelated native form calls remain identical',function()
 local _,a,s=localized();reset(s);assert(a:printCondition({type='FORM',value=0},7):find('humanoid',1,true)and #s.trace==0)
 local _,b,t=fixture('DRUID');reset(t);assert(b:printCondition({type='FORM',value=1},7):find('Form 123',1,true));local icon,dropdown,parent=mount(b,{value=1})
 assert(table.concat(t.trace,',')=='form:1,spell:123,count,form:1,spell:123,form:2,spell:456,'..candidates(DRUID_FORMS)..',form:1,spell:123,form:1'and dropdown.list['spell:456']=='Form 456'and icon.image:GetTexture()==901);parent:Release()
end)
test('selected metadata failures keep placeholders and selection then recover without cache or fallback',function()
 for _,legacy in ipairs({false,true})do for _,mode in ipairs({'missing','throw','restricted'})do
  local _,a,s=localized(legacy);s.mode=mode;local value={type='FORM',value=1}
  assert(a:printCondition(value,7):find('<form>',1,true));local icon,dropdown,parent=mount(a,value)
  assert(dropdown.list['1']==slot('<form>')and icon.image:GetTexture()==question and value.value==1)
  s.mode='ready';dropdown:Fire('OnValueChanged','1');assert(icon.image:GetTexture()==123 and value.value==1);parent:Release()
  local _,choice,owner=mount(a,value);assert(choice.list['1']==slot(s.localized));owner:Release()
 end end
 local _,a,s=localized();local value={value=1}
 for _,texture in ipairs({456,'Interface\\Icons\\Spell_Nature_SpiritWolf'})do s.icon=texture;local image,_,owner=mount(a,value);assert(image.image:GetTexture()==texture);owner:Release()end
 s.icon=nil;local image,choice,owner=mount(a,value);assert(choice.list['1']==slot(s.localized) and image.image:GetTexture()==question);owner:Release()
end)
test('numeric selection engine NOT and real branch remain unchanged',function()
 local f,a,s=localized();f.load('Data/plain.lua');f.load('Data/tags.lua');f.load('Data/rotation_tree.lua');f.load('Core/rotation_sequence.lua')
 local value={type='FORM',value=1};assert(a.conditionDefinitions.FORM.valid(0,value))
 assert(a:evaluateConditionResult(value).status=='match'and a:evaluateConditionResult({type='NOT',value=value}).status=='no-match')
 local selected;local body={rotation={{id='form',type='branch',conditions=value,onTrue={{id='yes',type='spell',action=1}},onFalse={{id='no',type='spell',action=2}}}}}
 a:EvaluateRotationSequence(body,function(n)return a:evaluateConditionResult(n)end,function(n)selected=n.id;return true end);assert(selected=='yes')
 s.form=0;assert(a:evaluateConditionResult(value).status=='no-match'and a:evaluateConditionResult({type='NOT',value=value}).status=='match')
end)
test('native selected choice refreshes summary while retired callback cannot edit next lease',function()
 local _,a,s=localized();local value={type='FORM',value=1};local icon,dropdown,parent,state=mount(a,value)
 choose(dropdown,'0');assert(value.value==0 and state.status:find('humanoid',1,true));choose(dropdown,'1');assert(value.value==1 and state.status:find(s.localized,1,true)and icon.image:GetTexture()==123)
 dropdown.button:Click();local row;for _,r in ipairs(dropdown.selector.rows)do if r.menuEntry and r.menuEntry.value=='0'then row=r end end;assert(row);local stale=row.scripts.OnClick;parent:Release()
 local fresh={value=1};local _,_,owner,nextState=mount(a,fresh);stale(row);assert(fresh.value==1 and value.value==1 and nextState.statuses==0);owner:Release()
end)
test('strict whole module inverse protects all unrelated bytes and existing private identities',function()
 local _,a=localized();local module=read('Conditions/combat.lua');assert(inverse(module));assert(not pcall(inverse,module..'\n-- unrelated'))
 for _,name in ipairs({'print','widget'})do assert(inverse(repaired[name],name)==old[name]and not pcall(inverse,old[name],name)and not pcall(inverse,repaired[name]..' ',name))end
 for name,hash in pairs({character_class='d17cf4c1',color='dbda383d',helpers='9e28e933'})do local id='builtin:Conditions/combat.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules['Conditions/combat.lua'](name)))end
end)
test('current copies repair ID authority while archived complete sources keep English name lookup',function()
 for _,legacy in ipairs({false,true})do local f,a,s=localized(legacy);local source=assert(a:GetBuiltinConditionSource('FORM'))
  assert(source.print==repaired.print and source.widget==repaired.widget,'FORM localization catalog pending')
  local archived=a:CopySettingsData(source);archived.print=inverse(source.print,'print');archived.widget=inverse(source.widget,'widget')
  assert(a:FunctionSourceHash(archived)=='1d0882d3','complete archived FORM export changed')
  local current=assert(a:CompileCustomCondition('COPY_FORM',source));a:RegisterCondition('COPY_FORM',current);local value={type='COPY_FORM',value=1}
  assert(a:printCondition(value,7):find(s.localized,1,true)and a:evaluateConditionResult(value).status=='match');local icon,dropdown,parent=mount(a,value,current);assert(icon.image:GetTexture()==123 and dropdown.list['1']==s.localized);parent:Release()
  s.override=true;local frozen=a:CopySettingsData(archived);a.db.global.custom_conditions={SAVED_FORM=archived}
  local raw=assert(a:CompileCustomCondition('SAVED_FORM',archived));a:RegisterCondition('SAVED_FORM',raw);value.type='SAVED_FORM'
  assert(a:printCondition(value,7):find('Name override',1,true),'archived name authority changed');local oldIcon,oldDrop,oldParent=mount(a,value,raw)
  assert(oldIcon.image:GetTexture()==999999 and oldDrop.list['1']=='Name override');oldParent:Release()
  assert(a:SettingsDataEqual(archived,frozen)and a.db.global.custom_conditions.SAVED_FORM==archived)
 end
end)
finish()
