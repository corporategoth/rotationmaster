-- Actual Lua structural oracle. No authored/user callbacks are executed.
local export=dofile('tools/export_web_schema.lua')
local data=dofile('tests/fixtures/rotation_data.lua')()
local catalog=export.build();local rows=export.array({})
local function bits(n)
 if n~=n then return '7ff8000000000000'end
 if n==math.huge then return '7ff0000000000000'end;if n==-math.huge then return 'fff0000000000000'end
 local negative=n<0 or n==0 and 1/n<0;n=math.abs(n);local e,m=0,0
 if n~=0 then local f,p=math.frexp(n);if p<=-1022 then m=n/2^-1074 else e=p+1022;m=(f*2-1)*2^52 end end
 return string.format('%08x%08x',(negative and 2147483648 or 0)+e*1048576+math.floor(m/4294967296),m%4294967296)
end
local function typed(value)
 local kind=type(value)
 if kind=='nil'then return {type='nil'}end
 if kind=='function'then return {type='function'}end
 if kind=='number'then return {type='number',bits=bits(value)}end
 if kind=='boolean'then return {type='boolean',value=value}end
 if kind=='string'then return {type='bytes',hex=(value:gsub('.',function(c)return string.format('%02x',c:byte())end))}end
 assert(kind=='table' and not getmetatable(value))
 local keys={};for k in pairs(value)do keys[#keys+1]=k end;table.sort(keys,function(a,b)if type(a)==type(b)then return a<b end;return type(a)=='number'end)
 local entries=export.array({});for _,k in ipairs(keys)do entries[#entries+1]=export.array({typed(k),typed(value[k])})end
 return {type='table',entries=entries}
end
local callbackCalls=0
local function trap()callbackCalls=callbackCalls+1;error('structural oracle invoked executable callback')end
local options={}
for index,case in ipairs(catalog.cases)do
 local f=export.loadCase(index);local definitions={}
 for id,d in pairs(f.addon.definitions)do
  for _,name in ipairs({'valid','evaluate','print','help','widget','on_register','on_unregister'})do d[name]=trap end
  if id~='RUNNER' and id~='RESIST' and id~='IMMUNE' then definitions[id]=d end
 end
 for _,name in ipairs({'IsSpellKnown','UnitExists','UnitHealth','GetSpellInfo','GetItemInfo'})do f.env[name]=trap end
 options[case.id]={conditions=definitions}
end
local function projectIndex(index)
 local result={ok=true,rows=export.array({}),lists=export.array({})}
 for _,source in ipairs(index.rows)do local row={};for _,k in ipairs({'path','section','index','ordinal','depth','parentId','arm','unreachable'})do row[k]=source[k]end;row.path=export.array(row.path);result.rows[#result.rows+1]=row end
 for _,source in ipairs(index.lists)do local row={};for _,k in ipairs({'path','section','depth','parentId','arm','unreachable'})do row[k]=source[k]end;row.path=export.array(row.path);result.lists[#result.lists+1]=row end
 return result
end
local function add(id,kind,input,case,leaf,indexOptions)
 local expected
 if kind=='index'then local index,why=data.IndexRotationSteps(input,indexOptions);expected=index and projectIndex(index) or {ok=false,diagnostic=why}
 else expected=(kind=='envelope' and data.ValidateEnvelope or data.ValidateBody)(input,options[case or 'case-3']);expected.diagnostics=export.array(expected.diagnostics)end
 rows[#rows+1]={id=id,kind=kind,input=typed(input),options=kind=='index' and (indexOptions or {}) or {declarationCase=case or 'case-3'},expected=expected,leaf=leaf}
end
local function body(condition)return {rotation={},cooldowns={},switch=condition}end
local example
example=function(schema)
 if schema=='number'then return 1 elseif schema=='boolean'then return false elseif schema=='string'then return 'example'
 elseif schema=='condition'then return {}elseif schema=='condition[]'then return {{type='NOT',value={}}}end
 if schema[1]then local first=schema[1];if type(first)=='table'then
  if first[1]then return {example(first[1])}end;local value={};for k,v in pairs(first)do value[k]=example(v)end;return value
 end;return example(first)end
 local value={};for k,v in pairs(schema)do value[k]=example(v)end;return value
end
for _,case in ipairs(catalog.cases)do
 for _,record in ipairs(catalog.conditions)do
  local d;for _,candidate in ipairs(record.declarations)do for _,id in ipairs(candidate.cases)do if id==case.id then d=candidate end end end
  local value={type=record.id}
  if d then for key,schema in pairs(d.fields)do value[key]=example(schema)end end
  add(case.id..'/'..record.id,'body',body(value),case.id,record.id)
  if d and #d.requiredFields>0 then local missing={type=record.id};add(case.id..'/'..record.id..'/missing','body',body(missing),case.id)end
 end
end
local function step(id)return {id=id,type='none'}end
add('empty-body','body',body())
add('nil-body','body',nil);add('scalar-body','body',true);add('missing-lists','body',{})
add('switch-not-a-picker-allowlist','body',body({type='SPELL_KNOWN',spell=403}))
add('negative-spell-identity-not-certified','body',body({type='SPELL_KNOWN',spell=-1}))
add('DELETE-unresolved','body',body({type='DELETE'}))
add('custom-opaque','body',body({type='CUSTOM_SOURCE',source='error("NEVER EXECUTE")',future={constructor='inert',['__proto__']='inert'}}))
add('bad-known-leaf-type','body',body({type='SPELL_KNOWN',spell='403'}))
add('ordinary-leaf-unknown-field','body',body({type='SPELL_KNOWN',spell=403,future=true}))
add('named-logic','body',body({type='AND',name='Group',value={{type='NOT',value={type='COMBAT',unit='player'}}}}))
add('empty-logic','body',body({type='AND',value={}}))
add('bad-group-name','body',body({type='AND',name='bad\nname',value={}}))
add('missing-not-value','body',body({type='NOT'}))
add('sparse-group','body',body({type='OR',value={[2]={type='SPELL_KNOWN',spell=403}}}))
add('numeric-string-key-collision','body',{rotation={[1]=step('one'),['1']=step('string')},cooldowns={}})
local branch={id='branch',type='branch',onTrue={step('yes')},onFalse={step('no')}}
for _,mode in ipairs({'evaluate','true','false'})do local b=export.clone(branch);b.mode=mode;add('branch-'..mode,'body',{rotation={b},cooldowns={}});add('index-'..mode,'index',{rotation={b},cooldowns={}})end
local future=export.clone(branch);future.future='retained';add('future-branch-warning','body',{rotation={future},cooldowns={}});add('future-branch-strict-index','index',{rotation={future},cooldowns={}})
local disabled=export.clone(branch);disabled.disabled=false;add('forbidden-branch-appearance','body',{rotation={disabled},cooldowns={}})
add('branch-in-optional','body',{rotation={},cooldowns={branch}})
local duplicate=export.clone(branch);duplicate.mode='true';duplicate.onFalse[1].id='same';add('hidden-arm-duplicate','body',{rotation={duplicate},cooldowns={step('same')}})
add('missing-id-strict','index',{rotation={{type='none'}},cooldowns={}})
add('missing-id-inspection','index',{rotation={{type='none'}},cooldowns={}},nil,nil,{allowMissingIds=true})
for _,size in ipairs({1999,2000,2001})do local b=body();for i=1,size do b.rotation[i]=step('step-'..i)end;add('rows-'..size,'index',b);add('validated-rows-'..size,'body',b)end
for _,depth in ipairs({15,16,17})do local b=body();local list=b.rotation;for i=1,depth do local node={id='branch-'..i,type='branch',onTrue={},onFalse={}};list[1]=node;list=node.onTrue end;list[1]=step('last');add('branch-depth-'..depth,'index',b)end
for _,depth in ipairs({62,63,64,65})do local b=body();b.opaque={};local node=b.opaque;for i=2,depth do node.next={};node=node.next end;add('portable-wrapped-depth-'..depth,'body',b)end
for _,length in ipairs({262143,262144,262145})do local b=body();b.name=string.rep('x',length);add('name-byte-limit-'..length,'body',b)end
for _,n in ipairs({9007199254740991,9007199254740992,0,1.5,math.huge,0/0})do local b=body();b.revision=n;add('revision-'..(n~=n and 'nan' or tostring(n)),'body',b)end
for _,n in ipairs({-100001,-100000,0,100000,100001})do local b=body();b.priority=n;add('priority-'..n,'body',b)end
for _,tags in ipairs({{}, {'one','ONE',' one '},{'é','雪'},{string.char(255)},{'bad\nname'},{string.rep('x',64)},{string.rep('x',65)}})do local b=body();b.tags=tags;add('tags-'..#rows,'body',b)end
for index,tags in ipairs({{'A','a','Ä','ä',' A ',string.char(194,160)},{' A ','B'}})do
 local b=body();b.tags=tags;local before=export.clone(tags)
 add('normalization-vector-acceptance-body-'..index,'body',b)
 local env={format='RotationMaster',schemaVersion=1,id='tags',revision=1,nameKey='Name',descriptionKey='Description',applicability={families={'tbc'},actionContext='player'},body=body(),tags=tags}
 add('normalization-vector-acceptance-envelope-'..index,'envelope',env)
 for i,v in ipairs(before)do assert(tags[i]==v,'validation normalized input')end
end
for _,count in ipairs({64,65})do local b=body();b.tags={};for i=1,count do b.tags[i]='tag-'..i end;add('tag-count-'..count,'body',b)end
local unknown=body();unknown.rotation={{id='effect',type='spell',action=403,effect='user-effect'},{id='itemset',type='item',action='user-set'}};add('unresolved-reference-sets','body',unknown)
for _,type in ipairs({'spell','pet','any','item','none','future'})do local b=body();b.rotation={{id='action',type=type,action=type=='item' and {1,'Item name'} or 403,suppress_attack=false}};add('action-'..type,'body',b)end
for _,case in ipairs({{'assisted-rotation',{{id='blizzard',type='assisted',conditions={type='COMBAT'}}},{}},
 {'assisted-with-action',{{id='blizzard',type='assisted',action=403}},{}},
 {'assisted-in-cooldowns',{},{{id='blizzard',type='assisted'}}},
 {'assisted-in-branch',{{id='gate',type='branch',conditions={type='COMBAT'},onTrue={{id='blizzard',type='assisted'}},onFalse={}}},{}}})do
 local b=body();b.rotation=case[2];b.cooldowns=case[3];add(case[1],'body',b)
end
local colors=body();colors.rotation={{id='color',type='none',color={r=0,g=1,b=.5,a=0}}};add('color-valid','body',colors);colors.rotation[1].color.a=2;add('color-invalid','body',colors)
local many=body();for i=1,150 do many.rotation[i]={id='bad-'..i,type=3,future=true}end;add('diagnostic-cap-still-updates-status','body',many)
local envelope={format='RotationMaster',schemaVersion=1,id='fixture',revision=1,nameKey='Name',descriptionKey='Description',applicability={families={'tbc'},actionContext='player',class='SHAMAN'},body=body()}
add('envelope-basic','envelope',envelope)
for _,version in ipairs({0,2})do local v=export.clone(envelope);v.schemaVersion=version;add('schema-version-'..version,'envelope',v)end
local v=export.clone(envelope);v.future='kept';v.applicability.families={'future'};v.dependencies={'function:unresolved'};add('future-envelope-preserved','envelope',v)
v=export.clone(envelope);v.applicability.universal=true;add('conflicting-scope','envelope',v)
v=export.clone(envelope);v.applicability.minLevel=20;v.applicability.maxLevel=10;v.applicability.specs={0,1};v.applicability.roles={};add('scope-ranges','envelope',v)
v=export.clone(envelope);v.sources={{url='https://example.invalid/reference',title='Inert'}};add('source-reference','envelope',v)
v=export.clone(envelope);v.sources={{url='https://bad space'}};add('source-whitespace','envelope',v)
-- Numeric diagnostic paths use Lua's default %.14g conversion, including
-- scientific notation and ties-to-even. Byte keys remain opaque and truncated
-- only for portable diagnostics, never reparsed as numeric path syntax.
for i,n in ipairs({99999999999999,1e14,1e20,9007199254740992,100000000000005,100000000000015,999999999999995,1e100,1.7976931348623157e308})do
 local b=body();b[n]=true;add('numeric-unknown-body-'..i,'body',b)
 local e=export.clone(envelope);e[n]=true;add('numeric-unknown-envelope-'..i,'envelope',e)
 local k='[100000000000000000000].'..string.rep('x',90)
 b=body();b[k]={[n]=math.huge};add('numeric-portable-body-'..i,'body',b);add('numeric-portable-index-'..i,'index',b)
 e=export.clone(envelope);e[k]={[n]=math.huge};add('numeric-portable-envelope-'..i,'envelope',e)
 b=body();b[n]={[-1]=true};add('numeric-invalid-key-body-'..i,'body',b);add('numeric-invalid-key-index-'..i,'index',b)
 b=body({type='SPELL_KNOWN',spell=403,[n]=true});add('numeric-known-condition-'..i,'body',b)
end
local metadata=body();metadata.metadata={author=1,realm=2,email=3,website=4,version=5}
add('multiple-invalid-metadata-fields','body',metadata)
assert(callbackCalls==0,'structural validator invoked callback/native observation')
print(export.json({cases=rows,callbackCalls=callbackCalls}))
