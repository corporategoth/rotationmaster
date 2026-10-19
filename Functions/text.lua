local _,addon=...
local string=string

-- Canonical text implementations; preserve the original captured string table.
local text={}
addon.Functions=addon.Functions or {}
addon.Functions.text=text

text.split = function(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

text.wrap = function(str, limit)
    limit = limit or 72
    local here = 1

    -- the "".. is there because :gsub returns multiple values
    return ""..str:gsub("(%s+)()(%S+)()",
            function(_, st, word, fi)
                if fi-here > limit then
                    here = st
                    return "\n"..word
                end
            end)
end

text.trim = function(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="split" then return addon.Functions.text.split end
        if name=="trim" then return addon.Functions.text.trim end
        if name=="wrap" then return addon.Functions.text.wrap end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Functions/text.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Functions/text.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
