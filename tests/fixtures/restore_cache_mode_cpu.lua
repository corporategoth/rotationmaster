-- Strict inverse of only the copyable CPU mode context added after efad377.
local block = [=[ -- BEGIN CACHE MODE CONTEXT
 local mode=field(owner,'GetCacheDiagnosticMode')
 if type(mode)=='function' then
  local ok,loaded,requested,pending=pcall(mode,owner)
  local function known(value) return readable(value) and type(value)=='string' and (value=='cached' or value=='direct') end
  if ok and known(loaded) and known(requested) and readable(pending) and type(pending)=='boolean' then
   result=result..' observation-cache='..loaded..' requested='..requested..' reload='..tostring(pending)
  else result=result..' observation-cache=unavailable' end
 end
 return result
 -- END CACHE MODE CONTEXT
]=]

local before = [=[ return 'config='..(config==true and 'shown' or config==false and 'hidden' or 'unavailable')..' combat='..combat..' poll='..interval('poll')..' live='..interval('live_config_update')
]=]

local after = [=[ local result='config='..(config==true and 'shown' or config==false and 'hidden' or 'unavailable')..' combat='..combat..' poll='..interval('poll')..' live='..interval('live_config_update')
]=]

return function(text)
    local first, last = text:find(block, 1, true)
    assert(first and not text:find(block, last + 1, true), 'unexpected CPU cache-mode block')
    text = text:sub(1, first - 1) .. text:sub(last + 1)
    first, last = text:find(after, 1, true)
    assert(first and not text:find(after, last + 1, true), 'unexpected CPU context return')
    text = text:sub(1, first - 1) .. before .. text:sub(last + 1)
    local hash = 0

    for i = 1, #text do
        hash = (hash * 33 + text:byte(i)) % 4294967296
    end

    assert(#text == 20939 and string.format('%08x', hash) == '79535cfc', 'CPU changed beyond cache-mode context')
    return text
end
