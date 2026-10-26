local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local restore=dofile('tests/fixtures/restore_main_unused_capture.lua')
local restoreActive=dofile('tests/fixtures/restore_main_qualifiers.lua')
local function fixture(modern)
 local h=assert(io.open('tests/startup.lua'));local source=h:read('*a');h:close()
 local prefix=source:sub(1,assert(source:find('\nlocal function initialize',1,true))-1)
 return assert(loadstring(prefix..'\nreturn fixture','@unused-main-capture-startup'))()(modern,true)
end
for _,modern in ipairs({false,true}) do
 test((modern and 'modern' or 'legacy')..' actual main selects unused canonical isint once during load without calling it',function()
  local _,a,load=fixture(modern);local legacyReads,canonicalReads,calls=0,0,0
  local values=a.Functions.values;local leaf=values.isint
  rawset(a,'isint',nil);setmetatable(a,{__index=function(_,key)
   if key=='isint' then legacyReads=legacyReads+1;error('LEGACY_UNUSED_ISINT_FIELD_READ') end
  end})
  values.isint=nil;setmetatable(values,{__index=function(_,key)
   if key=='isint' then
    canonicalReads=canonicalReads+1
    assert(a.savedVariableName=='RotationMasterDB' and a.pretty_name==nil and a.OnInitialize==nil,'unused selection moved out of its module-load boundary')
    return function(...) calls=calls+1;return leaf(...) end
   end
  end})
  load('main.lua')
  assert(legacyReads==0 and canonicalReads==1 and calls==0,'unused capture changed its field authority, count or call behavior')
  values.isint=function() calls=calls+1;error('UNUSED_CAPTURE_CALLED') end
  assert(type(a.OnInitialize)=='function' and a.pretty_name=='Rotation Master' and canonicalReads==1 and calls==0,'main did not complete its ordinary load')
 end)
end
test('absent unused canonical member remains a nil selection without fallback or invocation',function()
 local _,a,load=fixture(true);local reads=0;a.Functions.values.isint=nil
 setmetatable(a.Functions.values,{__index=function(_,key) if key=='isint' then reads=reads+1;return nil end end})
 rawset(a,'isint',nil);setmetatable(a,{__index=function(_,key) assert(key~='isint','unused capture added a legacy fallback') end})
 load('main.lua');assert(reads==1 and type(a.OnInitialize)=='function','nil selection became an invocation or eager requirement')
end)
finish()
