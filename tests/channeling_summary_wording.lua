local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(path)local h=assert(io.open(path));local s=h:read('*a');h:close();return s end
local prefix=assert(read('tests/casting_conditions.lua'):match('^(.-)\ntest%('));local fixture=assert(loadstring(prefix..'\nreturn fixture'))()
local function setup()
 local f,a,s=fixture();for _,tag in ipairs({'CHANNELING','CHANNELING_SPELL'})do a:RegisterCondition('COPY_'..tag,assert(a:CompileCustomCondition('COPY_'..tag,a:GetBuiltinConditionSource(tag))))end
 return f,a,s
end
local function prints(a,v,p,n)assert(a:printCondition(v,0)==p);assert(a:printCondition({type='NOT',value=v},0)==n);assert(a:printCondition({type='NOT',value={type='NOT',value=v}},0)==p)end
for _,tag in ipairs({'CHANNELING','CHANNELING_SPELL'})do test(tag..' nonplayer built-in and current exported copy describe channeling and keep native kind',function()
 local _,a,s=setup()
 for _,id in ipairs({tag,'COPY_'..tag})do for _,unit in ipairs({'target','focus','pet'})do
  local v={type=id,unit=unit,spell='Arcane Missiles'};assert(a:evaluateConditionResult(v).status=='match')
  local suffix=tag=='CHANNELING_SPELL'and' Arcane Missiles'or''
  prints(a,v,a.units[unit]..' is currently channeling'..suffix,a.units[unit]..' is not currently channeling'..suffix)
 end end
 assert(s.calls.channel and not s.calls.cast)
end)end
test('player phrasing and current nil placeholders preserve existing behavior without new native queries',function()
 local f,a=setup()
 for _,tag in ipairs({'CHANNELING','COPY_CHANNELING'})do prints(a,{type=tag,unit='player'},'you are currently channeling','you are not currently channeling')end
 for _,tag in ipairs({'CHANNELING_SPELL','COPY_CHANNELING_SPELL'})do prints(a,{type=tag,unit='player',spell='Arcane Missiles'},'you are currently channeling Arcane Missiles','you are not currently channeling Arcane Missiles')
  local p=a:printCondition({type=tag,unit='target'},0);assert(p:find('<spell>',1,true))
 end
 for _,name in ipairs({'UnitExists','UnitCastingInfo','UnitChannelInfo'})do f.env[name]=function()error('summary queried '..name)end end
 prints(a,{type='CHANNELING',unit='target'},'your target is currently channeling','your target is not currently channeling')
end)
test('new nonplayer whole translations reorder unit spell and primary negation while leaving data opaque',function()
 local f,a=setup();local literal='Spell {{!blue|red}} 50% {spell}'
 f.translations['%s {{!is|is not}} currently channeling']='%s: {{!CHANNEL|NO_CHANNEL}}'
 f.translations['{unit} {{!is|is not}} currently channeling {spell}']='{spell} -> {unit}: {{!CHANNEL|NO_CHANNEL}}'
 for _,tag in ipairs({'CHANNELING','COPY_CHANNELING'})do prints(a,{type=tag,unit='target'},'your target: CHANNEL','your target: NO_CHANNEL')end
 for _,tag in ipairs({'CHANNELING_SPELL','COPY_CHANNELING_SPELL'})do prints(a,{type=tag,unit='target',spell=literal},literal..' -> your target: CHANNEL',literal..' -> your target: NO_CHANNEL')end
end)
local inverse,oldPrint,newPrint=dofile('tests/fixtures/restore_channeling_summary_wording.lua')
finish()
