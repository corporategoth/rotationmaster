local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local functions={valid=true,evaluate=true,print=true,widget=true,help=true,on_register=true,on_unregister=true}
local function schema(value,depth)
    if depth>16 then return false end
    if type(value)=='string' then return value=='string' or value=='number' or value=='boolean' or value=='condition' or value=='{ string, { string, number } }' end
    if type(value)~='table' then return false end
    for key,child in pairs(value) do if not (type(key)=='string' or type(key)=='number' and key>=1 and key%1==0) or not schema(child,depth+1) then return false end end;return true
end
function addon:ParseCustomConditionImport(text,codec)
    local decoded,why=codec:Decode(text);if not decoded then return nil,why end
    local value=decoded.value;local name
    if type(value)=='table' and value.format~=nil then if value.format~='RM-CustomCondition' or value.version~=1 or type(value.name)~='string' then return nil,L['Invalid custom condition.'] end;name=value.name;value=value.condition end
    if type(value)~='table' or type(value.description)~='string' or not value.description:find('%S') or not self:IsCategoryIcon(value.icon) or not schema(value.fields,0) then return nil,L['Invalid custom condition.'] end
    for key,child in pairs(value) do
        if functions[key] then if type(child)~='string' then return nil,L['Invalid custom condition.'] end
        elseif key~='description' and key~='icon' and key~='fields' then return nil,L['Invalid custom condition.'] end
    end
    for key in pairs(functions) do if type(value[key])~='string' then return nil,L['Invalid custom condition.'] end end
    return {name=name,condition=self:CopySettingsData(value)}
end
