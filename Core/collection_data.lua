local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:ParseItemSetImport(text,codec)
    if type(text)~='string' or #text>131072 then return nil,L['Invalid item list.'] end
    local decoded=codec:Decode(text);local result
    if decoded then
        local value=decoded.value
        if type(value)~='table' or value.format~='RM-ItemSet' or value.version~=1 or type(value.items)~='table' or type(value.name)~='string' or #value.name>256 or not value.name:find('%S') then return nil,L['Invalid item list.'] end
        result={name=value.name,items=value.items}
    else
        result={items={}}
        for line in (text:gsub(',','\n')..'\n'):gmatch('(.-)\n') do
            local value=line:match('^%s*(.-)%s*$');if value~='' then result.items[#result.items+1]=tonumber(value) or value end
        end
    end
    local count=0
    for key,item in pairs(result.items) do
        if type(key)~='number' or key<1 or key%1~=0 or key>#result.items or not (type(item)=='number' and item>0 and item%1==0 or type(item)=='string' and #item>0 and #item<=1024 and not tonumber(item)) then return nil,L['Invalid item list.'] end;count=count+1
    end
    if count~=#result.items or count>256 then return nil,L['Invalid item list.'] end
    return result
end
