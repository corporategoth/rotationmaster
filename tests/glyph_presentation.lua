local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path) local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local function fixture(legacy)
 local f=F.new(11,2,'SHAMAN');local a,e=f.addon,f.env;local s={link='|Hitem:101|h[Glyph of Test]|h',mode='ready',calls=0,kind=7}
 e.UnitClass=function() return 'Shaman','SHAMAN',7 end;e.GetBuildInfo=function() return '3.4.0','1','',30400 end
 local function info(id,...) assert(select('#',...)==0 and type(id)=='number','display native item/arity changed');s.calls=s.calls+1;s.last=id
  if s.mode=='throw' then error('display metadata failed') elseif s.mode=='missing' then return nil end
  local link=s.link;if s.mode=='secret-link' then link=s.opaque elseif s.mode=='nil-link' then link=nil elseif s.mode=='empty-link' then link='' end
  return s.mode=='secret-name' and s.opaque or 'Glyph of Test',link,1,1,1,'Glyph','Shaman',1,'',123
 end
 local function instant(id) id=tonumber(id) or tonumber(type(id)=='string' and id:match('item:(%d+)'));if id then return id,'Glyph','Shaman','',123,16,s.kind end end
 if legacy then e.GetItemInfo=info;e.GetItemInfoInstant=instant else e.C_Item={GetItemInfo=info,GetItemInfoInstant=instant};e.GetItemInfo=nil;e.GetItemInfoInstant=nil end
 e.GetNumGlyphSockets=function() return 1 end;e.GetGlyphSocketInfo=function() return true,1,9001,1 end
 e.C_Spell={GetSpellInfo=function() return {name='Glyph of Test',spellID=9001,iconID=123} end}
 e.GameTooltip={IsOwned=function() return false end,IsVisible=function() return false end,Hide=function() end}
 for _,path in ipairs({'Platform/spells.lua','Diagnostics/errors.lua','Core/conditions.lua','Conditions/common.lua','Conditions/character.lua','Data/builtin_sources.lua','Core/builtin_sources.lua','Core/custom_authoring.lua','Core/function_data.lua'}) do f.load(path) end
 e.loadstring=function(code,name) local fn,why=loadstring(code,name);if fn then setfenv(fn,e) end;return fn,why end
 dofile('tests/fixtures/spell_editbox.lua')(f);s.opaque={};e.canaccessvalue=function(v) return not rawequal(v,s.opaque) end
 return f,a,s
end
local function mount(a,value,definition)
 definition=definition or a.conditionDefinitions.GLYPH;local parent=a:CreateConditionGroup();parent:SetWidth(640);local state={prints=0,statuses=0};local top={};local funcs={}
 function top:GetUserData(key) if key=='root' then return value elseif key=='funcs' then return funcs end end
 function funcs:print(root,spec) assert(root==value and spec==7);state.prints=state.prints+1;return definition.print(spec,value) end
 function top:SetStatusText(text) state.statuses=state.statuses+1;state.status=text end
 parent:SetUserData('top',top);definition.widget(parent,7,value);a:configure_frame(parent);parent:DoLayout();return parent.children[1].children[2],parent,state
end
local function enter(item,text) item:SetFocus();item.editbox:SetText(text);item.editbox:GetScript('OnEnterPressed')(item.editbox) end

test('modern-only selected summary uses exact one-argument item metadata without unrelated observations',function()
 local f,a,s=fixture();local value={type='GLYPH',item=101};assert(a.conditionDefinitions.GLYPH.valid(0,value));s.calls=0
 f.env.UnitClass=function() error('summary read class') end;f.env.C_Item.GetItemInfoInstant=function() error('summary read classification') end;f.env.GetNumGlyphSockets=function() error('summary read sockets') end
 assert(a:printCondition(value,7):find(s.link,1,true) and s.calls==1 and s.last==101 and value.item==101)
 value.item=nil;s.calls=0;assert(a:printCondition(value,7):find('<glyph>',1,true) and s.calls==0)
end)
test('failed missing restricted or missing-link metadata renders placeholder without native fallback',function()
 for _,mode in ipairs({'throw','missing','secret-name','secret-link','nil-link','empty-link'}) do local f,a,s=fixture();s.mode=mode;f.env.GetItemInfo=function() error('modern metadata fell back to legacy') end
  local value={type='GLYPH',item=101};assert(a:printCondition(value,7):find('<glyph>',1,true) and value.item==101 and s.calls==1,mode..' lost placeholder')
 end
end)
test('summary observes recovered and changed live links without memoizing a failure',function()
 local _,a,s=fixture();local value={type='GLYPH',item=101};s.mode='throw';assert(a:printCondition(value,7):find('<glyph>',1,true));s.mode='ready';assert(a:printCondition(value,7):find(s.link,1,true));s.link='|cffabcdef|Hitem:101|h[New exact link]|h|r';assert(a:printCondition(value,7):find(s.link,1,true) and s.calls==3)
end)
test('actual native typed selection refreshes status with the newly selected item link',function()
 local _,a,s=fixture();local marker={};local value={type='GLYPH',item=101,sentinel=marker};local item,parent,state=mount(a,value);assert(item:GetReferenceID()==101)
 s.link='|Hitem:102|h[New Glyph]|h';enter(item,'102');assert(value.item==102 and item:GetReferenceID()==102 and value.sentinel==marker and state.prints==1 and state.statuses==1 and state.status and state.status:find(s.link,1,true),'new selected item status was not refreshed')
 s.kind=8;enter(item,'103');assert(value.item==102 and state.statuses==1,'wrong-class selection changed saved item or summary');parent:Release()
end)
test('retired native input callback cannot refresh or edit a recycled glyph owner',function()
 local _,a=fixture();local old={type='GLYPH',item=101};local item,parent,state=mount(a,old);local stale=item.events.OnEnterPressed;parent:Release()
 local fresh={type='GLYPH',item=102};local nextItem,owner,nextState=mount(a,fresh);assert(nextItem==item);stale(item,'OnEnterPressed','103');assert(old.item==101 and fresh.item==102 and state.prints==0 and nextState.prints==0);owner:Release()
end)
test('legacy-only metadata retains exact link and failed display does not change configured item',function()
 local _,a,s=fixture(true);local value={type='GLYPH',item=101};assert(a:printCondition(value,7):find(s.link,1,true) and s.calls==1);s.mode='throw';assert(a:printCondition(value,7):find('<glyph>',1,true) and value.item==101)
end)
local inverse,old,repaired=dofile('tests/fixtures/restore_glyph_presentation_repairs.lua')
test('exact summary inverse preserves every other character callback and four private identities',function()
 local _,a=fixture();local text=read('Conditions/character.lua');assert(a:FunctionSourceHash(inverse(text))=='56c3b024','character changed beyond GLYPH print from242faee');assert(inverse(repaired,true)==old and not pcall(inverse,old,true) and not pcall(inverse,repaired..' ',true) and not pcall(inverse,text..text))
 for name,hash in pairs({character_class='f9f4e4b5',unit_class_num='33645816',color='3f9fe631',helpers='2e9a81e7'}) do local id='builtin:Conditions/character.lua:'..name;assert(a:FunctionSourceHash(a.builtinFunctions[id].source)==hash and rawequal(a:ResolveFunctionBinding(id),a.builtinSourceModules['Conditions/character.lua'](name))) end
end)
test('actual current editable summary clone uses modern link and retains complete other export fields',function()
 local _,a,s=fixture();local source=assert(a:GetBuiltinConditionSource('GLYPH'));assert(source.print==repaired,'GLYPH catalog pending');local restored=a:CopySettingsData(source);restored.print=inverse(restored.print,true);assert(a:FunctionSourceHash(restored)=='b29d153e','unrelated complete GLYPH source changed')
 local before=a:CopySettingsData(source);local copy=assert(a:CompileCustomCondition('COPY_GLYPH',source));a:RegisterCondition('COPY_GLYPH',copy);local value={type='COPY_GLYPH',item=101};assert(copy.valid(0,value));assert(a:printCondition(value,7):find(s.link,1,true));local item,parent,state=mount(a,value,copy);s.link='|Hitem:102|h[New Glyph]|h';enter(item,'102');assert(value.item==102 and state.statuses==1 and state.status:find(s.link,1,true));parent:Release();assert(a:SettingsDataEqual(source,before))
end)
test('archived raw summary retains legacy global dispatch and saved source without rewriting',function()
 local f,a,s=fixture(true);local source=a:GetBuiltinConditionSource('GLYPH');source.print=old;assert(a:FunctionSourceHash(source)=='b29d153e');local before=a:CopySettingsData(source);a.db.global.custom_conditions={RAW_GLYPH=source};a:RegisterCondition('RAW_GLYPH',assert(a:CompileCustomCondition('RAW_GLYPH',source)))
 local value={type='RAW_GLYPH',item=101};assert(a:printCondition(value,7):find(s.link,1,true));local marker={};f.env.GetItemInfo=function() error(marker) end;local ok,why=pcall(a.printCondition,a,value,7);assert(not ok and why==marker,'raw legacy authority changed');assert(a:SettingsDataEqual(source,before) and a.db.global.custom_conditions.RAW_GLYPH==source)
end)
test('summary leaves classification validity localized matching and unavailable socket data unchanged',function()
 local f,a=fixture();local v={type='GLYPH',item=101};assert(a.conditionDefinitions.GLYPH.valid(0,v));assert(a:evaluateConditionResult(v).status=='match');a:printCondition(v,7);assert(a:evaluateConditionResult(v).status=='match')
 f.env.GetGlyphSocketInfo=function() return false,1,9001,1 end;assert(a:evaluateConditionResult(v).status=='no-match');f.env.GetNumGlyphSockets=nil;assert(a:evaluateConditionResult({type='NOT',value=v}).status=='unavailable');assert(v.item==101)
end)
finish()
