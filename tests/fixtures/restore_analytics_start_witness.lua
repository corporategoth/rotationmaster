-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict additive START-witness inverse; every original whole-source proof stays unchanged.
local rows = {
    ['Platform/analytics_casts.lua'] = {
        bytes = 21326,
        hash = '1c0b1021',
        oldBytes = 18603,
        oldHash = '58d88fbc',
        changes = {
            {
                at = 3742,
                current = [====[

  -- BEGIN ANALYTICS START WITNESS SNAPSHOT
  startWitness=status=='complete'and copy(s.startWitness)or nil,
  -- END ANALYTICS START WITNESS SNAPSHOT]====],
                previous = [====[]====],
            },
            {
                at = 11746,
                current = [====[-- BEGIN ANALYTICS START WITNESS
-- Optional event-local diagnostics, never a cast-kind authority. No raw tuple
-- or identity is retained; two bounded cast reads straddle the repeat query.
local function startWitness(s,key,spell)
 local ok,result=pcall(function()
  if key==nil or spell<=0 then return 'unknown' end
  local casting=call(s,function()return UnitCastingInfo end)
  local spells=call(s,function()return C_Spell end)
  if type(casting)~='function'or type(spells)~='table'then return 'unknown' end
  local repeatSpell=call(s,function()return spells.IsAutoRepeatSpell end)
  if type(repeatSpell)~='function'then return 'unknown' end
  local function same()
   if not rawequal(call(s,function()return UnitCastingInfo end),casting)then return false end
   if not rawequal(call(s,function()return C_Spell end),spells)then return false end
   return rawequal(call(s,function()return spells.IsAutoRepeatSpell end),repeatSpell)
  end
  local function observe()
   ---@type any
   local tuple=call(s,function()
    local name,_,_,_,_,trade,castID,_,spellID=casting('player')
    return{name=name,trade=trade,key=castID,spell=spellID}
   end)
   local name,trade,id,action=read(s,tuple.name),read(s,tuple.trade),read(s,tuple.key),read(s,tuple.spell)
   if not same()then return 'unknown' end
   if type(name)~='string'or#name==0 or type(trade)~='boolean'or type(id)~='string'or#id<1 or#id>128
    or not finite(action)or action<=0 or action>2147483647 or action%1~=0 then return 'unknown' end
   if id~=key or action~=spell then return 'mismatch' end
   if trade then return 'excluded' end
   return 'matched'
  end
  local first=observe();if first~='matched'then return first end
  local repeatValue=read(s,call(s,repeatSpell,spell))
  if not same()or type(repeatValue)~='boolean'then return 'unknown' end
  if repeatValue then return 'excluded' end
  return observe()
 end)
 fence(s)
 if not rawequal(active,s)or s.phase~='running'then fail('retired-operation')end
 return ok and result or 'unknown'
end
-- END ANALYTICS START WITNESS
]====],
                previous = [====[]====],
            },
            {
                at = 14396,
                current = [====[PT
  -- BEGIN ANALYTICS START WITNESS RECEIPT
  local witness
  if event=='UNIT_SPELLCAST_START'then witness=startWitness(s,key,spell)end
  -- END ANALYTICS START WITNESS RECEI]====],
                previous = [====[]====],
            },
            {
                at = 15335,
                current = [====[

  -- BEGIN ANALYTICS START WITNESS COUNT
  if witness then
   local counts=s.startWitness;counts.observed=counts.observed+1;counts[witness]=counts[witness]+1
  end
  -- END ANALYTICS START WITNESS COUNT]====],
                previous = [====[]====],
            },
            {
                at = 16378,
                current = [====[

 -- BEGIN ANALYTICS START WITNESS SESSION
 s.startWitness={observed=0,matched=0,mismatch=0,excluded=0,unknown=0}
 -- END ANALYTICS START WITNESS SESSION]====],
                previous = [====[]====],
            },
        },
    },
    ['UI/analytics_capture.lua'] = {
        bytes = 10418,
        hash = '0427940d',
        oldBytes = 9682,
        oldHash = '605a47d3',
        changes = {
            {
                at = 7929,
                current = [====[-- BEGIN ANALYTICS START WITNESS REPORT
 if type(snapshot.startWitness)=='table'then
  local counts=snapshot.startWitness
  local function count(value)
   return type(value)=='number'and value==value and value>=0 and value<=4096 and value%1==0 and tostring(value)or '?'
  end
  lines[#lines+1]=string.format(L['START witness rows: observed=%s matched=%s mismatch=%s excluded=%s unknown=%s (not ordinary proof).'],count(counts.observed),count(counts.matched),count(counts.mismatch),count(counts.excluded),count(counts.unknown))
  lines[#lines+1]=L['START witnesses compare current cast identity and non-autorepeat classification only; they do not classify ordinary casts or enable scoring.']
 end
 -- END ANALYTICS START WITNESS REPORT
 ]====],
                previous = [====[]====],
            },
        },
    },
}

local function hash(s)
    local n = 0

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return string.format('%08x', n)
end

return function(text, path)
    text = dofile('tests/fixtures/restore_workbench_resize.lua')(text, path)
    local r = rows[path]

    if not r or not text:find('-- BEGIN ANALYTICS START WITNESS', 1, true) then
        return text
    end

    assert(#text == r.bytes and hash(text) == r.hash, 'unrelated START-witness source: ' .. path)

    for i = #r.changes, 1, -1 do
        local c = r.changes[i]
        assert(text:sub(c.at, c.at + #c.current - 1) == c.current, 'START-witness inverse mismatch')
        text = text:sub(1, c.at - 1) .. c.previous .. text:sub(c.at + #c.current)
    end

    assert(#text == r.oldBytes and hash(text) == r.oldHash, 'START-witness predecessor mismatch')
    return text
end
