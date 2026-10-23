-- Offline trusted declaration export only. Never loaded by the addon/browser.
-- Fixed fixture cases describe observed declarations, never native availability.
local F=dofile('tests/fixtures/addon.lua')
local inventory=dofile('tests/fixtures/catalog_inventory.lua')
local checkDeclaration=dofile('tests/fixtures/declarations.lua')
local M={}
local arrays=setmetatable({},{__mode='k'})
local function array(value) arrays[value]=true;return value end
local function sorted(value)local out={};for k in pairs(value)do out[#out+1]=k end;table.sort(out);return out end
local function quote(value)return '"'..value:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
local function json(value)
 local kind=type(value)
 if kind=='string'then return quote(value)end
 if kind=='boolean'then return tostring(value)end
 if kind=='number'then assert(value==value and value<math.huge and value>-math.huge);return string.format('%.17g',value)end
 assert(kind=='table' and getmetatable(value)==nil,'only plain declaration data may be exported')
 local out={}
 if arrays[value] or #value>0 then for _,v in ipairs(value)do out[#out+1]=json(v)end;return '['..table.concat(out,',')..']'end
 for _,key in ipairs(sorted(value))do assert(type(key)=='string');out[#out+1]=quote(key)..':'..json(value[key])end
 return '{'..table.concat(out,',')..'}'
end
local function clone(value)
 if type(value)~='table'then assert(type(value)=='string' or type(value)=='boolean' or type(value)=='number');return value end
 assert(not getmetatable(value));local out={};for k,v in pairs(value)do out[k]=clone(v)end;return out
end
local function sha(path)
 assert(path:match('^[A-Za-z0-9_./%-]+$'),'fixed source path required')
 local pipe=assert(io.popen('sha256sum '..path,'r'));local line=assert(pipe:read('*l'));assert(pipe:close())
 local hash=line:match('^([0-9a-f]+) ');assert(hash and #hash==64,'source hash failed');return hash
end
local mob={RUNNER=true,RESIST=true,IMMUNE=true}
function M.loadCase(index)
 local case=assert(inventory.branches[index]);local f=F.new(unpack(case[1]));local a=f.addon;a.delayed_condition={};local providerCalls=0
 if case[3]then f.env.MI2_GetMobData=function()providerCalls=providerCalls+1;error('declaration export queried MobInfo runtime data')end end
 -- F.new's RegisterCondition stores arrays only; no on_register/valid/UI hooks.
 for line in io.lines('RotationMaster.toc')do if line:match('^Conditions/')then f.load(line)end end
 assert(providerCalls==0,'declaration export queried provider runtime data')
 return f
end
function M.build()
 local owner={};assert(loadfile('Data/builtin_sources.lua'))('rotationmaster',owner)
 local curated=owner.BuiltinSourceCatalog.conditions;local records,byID={},{}
 local output={format='RotationMasterDeclarativeCatalog',version=1,nativeAvailability='unverified',
  cases=array({}),conditions=array(records),logical=array({'AND','OR','NOT'}),uiOnly=array({'DELETE'}),sourceFiles={}}
 local inputs={'Data/plain.lua','Data/validation.lua','Data/rotation_tree.lua','Data/rotation_revision.lua','Data/tags.lua',
  'Data/builtin_sources.lua','Core/conditions.lua','Core/custom_condition_data.lua','tests/fixtures/addon.lua',
  'tests/fixtures/catalog_inventory.lua','tests/fixtures/declarations.lua','tools/export_web_schema.lua','RotationMaster.toc'}
 for id,entry in pairs(curated)do
  assert(not ({AND=true,OR=true,NOT=true,DELETE=true})[id],'pseudo condition leaked into curated catalog')
  byID[id]={id=id,module=entry.module,declarations=array({})}
 end
 for index,case in ipairs(inventory.branches)do
  local id='case-'..index;local f=M.loadCase(index);local definitions={}
  output.cases[#output.cases+1]={id=id,project=case[1][1],expansion=case[1][2],class=case[1][3],mobInfoProbe=case[3]==true}
  for tag,d in pairs(f.addon.definitions)do definitions[tag]={definition=d,provider=mob[tag] and 'MobInfo2' or nil}end
  for provider,rows in pairs(f.addon.delayed_condition)do for tag,d in pairs(rows)do assert(not definitions[tag]);definitions[tag]={definition=d,provider=provider}end end
  for tag,row in pairs(definitions)do
   local record=assert(byID[tag],'noncurated condition: '..tag);local definition=row.definition
   local valid,why=checkDeclaration(definition.fields);assert(valid,tag..':'..tostring(why))
   local variant=definition.builtinSourceVariant;local curatedEntry=curated[tag]
   if variant then assert(curatedEntry.variants and curatedEntry.variants[variant],'unknown authored source variant')else assert(not curatedEntry.variants,'missing authored source variant')end
   local fields=clone(definition.fields);local sourceRequired=definition.requiredFields or {};local count,maxIndex=0,0
   assert(type(sourceRequired)=='table' and not getmetatable(sourceRequired),'invalid requiredFields container')
   for key in pairs(sourceRequired)do assert(type(key)=='number' and key>=1 and key%1==0,'invalid requiredFields list key');count=count+1;if key>maxIndex then maxIndex=key end end
   assert(count==maxIndex,'sparse requiredFields list')
   local required=array(clone(sourceRequired));local seen={}
   for _,name in ipairs(required)do assert(type(name)=='string' and fields[name]~=nil and not seen[name],'invalid requiredFields');seen[name]=true end
   local signature=json(fields)..'|'..json(required)..'|'..tostring(variant)..'|'..tostring(row.provider)
   local found
   for _,entry in ipairs(record.declarations)do if entry.signature==signature then found=entry end end
   if not found then
    for _,entry in ipairs(record.declarations)do assert(entry.builtinSourceVariant~=variant,'unmarked ambiguous declaration: '..tag)end
    found={fields=fields,requiredFields=required,cases=array({}),builtinSourceVariant=variant,provider=row.provider,signature=signature};record.declarations[#record.declarations+1]=found
   end
   found.cases[#found.cases+1]=id
  end
 end
 for _,id in ipairs(sorted(byID))do local record=byID[id];assert(#record.declarations>0,'unobserved curated identity: '..id)
  table.sort(record.declarations,function(a,b)return (a.builtinSourceVariant or '')<(b.builtinSourceVariant or '')end)
  for _,entry in ipairs(record.declarations)do entry.signature=nil end
  records[#records+1]=record
 end
 assert(#records==124,'review curated declaration inventory deliberately')
 for _,id in ipairs(sorted(curated))do local path=curated[id].module;local found=false;for _,v in ipairs(inputs)do if v==path then found=true end end;if not found then inputs[#inputs+1]=path end end
 for _,path in ipairs(inputs)do output.sourceFiles[path]=sha(path)end
 return output
end
M.json=json;M.array=array;M.clone=clone
if arg and arg[0]=='tools/export_web_schema.lua'then print(json(M.build()))end
return M
