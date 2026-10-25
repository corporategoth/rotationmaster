-- Strict test-only inverse of exactly PROXIMITY.print from5fbad46.
local old='\n'..[=[
        return string.format(Functions.presentation.playerize(value.unit, L["%s {{!have|do not have}} %s"], L["%s {{!has|does not have}} %s"]),
                Functions.presentation.nullable(addon.units[value.unit], L["<unit>"]),
                Functions.presentation.compareString(value.operator,
                        string.format(L["number of %s members%s within %d yards"],
                                (value.samegroup and PARTY or L["Raid or Party"]),
                                (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                                Functions.presentation.nullable(value.distance, L["<distance>"])),
                        Functions.presentation.nullable(value.value)))
    ]=]
local repaired='\n'..[=[
        return Functions.presentation.compareString(value.operator,
                string.format(L["the number of %s members%s within %s yards of %s"],
                        (value.samegroup and PARTY or L["Raid or Party"]),
                        (value.includepets and " (" .. L["including pets"] .. ")" or ""),
                        Functions.presentation.nullable(value.distance, L["<distance>"]),
                        Functions.presentation.nullable(addon.units[value.unit], L["<unit>"])),
                Functions.presentation.nullable(value.value))
    ]=]
local function inverse(text,callback)
 assert(type(text)=='string','proximity summary inverse needs text')
 if callback then assert(text==repaired,'unexpected PROXIMITY print body');return old end
 local from,to='print = function(_, value)'..repaired..'end,','print = function(_, value)'..old..'end,'
 local first,last=text:find(from,1,true);assert(first and not text:find(from,last+1,true),'missing or duplicate PROXIMITY print')
 return text:sub(1,first-1)..to..text:sub(last+1)
end
return inverse,old,repaired
