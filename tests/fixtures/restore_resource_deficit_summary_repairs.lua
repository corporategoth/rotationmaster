-- Strict test-only inverse of exactly POWER and POINT print signs from efad377
-- (the current bodies also carry the deficit spelling and "point total").
local old={
 ["POWER"]='\n'..[=[
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s power defecit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s power"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    ]=],
 ["POINT"]='\n'..[=[
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s point defecit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s points"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    ]=],
}
local repaired={
 ["POWER"]='\n'..[=[
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s power deficit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), -value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s power"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    ]=],
 ["POINT"]='\n'..[=[
        if value.value ~= nil and value.value < 0 then
            return Functions.presentation.compareString(value.operator, string.format(L["%s point deficit"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), -value.value)
        else
            return Functions.presentation.compareString(value.operator, string.format(L["%s point total"], Functions.presentation.nullable(addon.unitsPossessive[value.unit], L["<unit>"])), Functions.presentation.nullable(value.value))
        end
    ]=],
}
local function inverse(text,tag)
 assert(type(text)=='string')
 if tag then assert(repaired[tag] and text==repaired[tag],'unexpected deficit summary body');return old[tag] end
 text=dofile('tests/fixtures/restore_point_tbc_transport.lua')(text,'Conditions/stats.lua')
 for _,name in ipairs({'POWER','POINT'}) do
  local from,to='print = function(_, value)'..repaired[name]..'end,','print = function(_, value)'..old[name]..'end,'
  local first,last=text:find(from,1,true);assert(first and not text:find(from,last+1,true),'missing or duplicate deficit summary '..name)
  text=text:sub(1,first-1)..to..text:sub(last+1)
 end
 return text
end
return inverse,old,repaired
