local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:IsCategoryIcon(value)
    return type(value)=='string' and #value>0 and #value<=1024 or type(value)=='number' and value>0 and value<math.huge and value%1==0
end
local packagedCategoryIcons={
    ['b3d7df2c-f257-4a2d-961e-66e49336d109']='combat',
    ['b8136123-2bda-4230-a77a-89ea2aed3a1a']='character',
    ['8034819e-26f5-4f4e-9153-d8cab5e65f31']='spell',
    ['fca4ff75-4085-458a-b5bf-27a6b52f2092']='item',
    ['e618608c-92ec-4ae9-9dde-40a397d7beb9']='buff',
    ['fa10aaf8-bc71-480f-9062-c949fd7c74e9']='spatial',
}
local conditionIconRoot='Interface\\AddOns\\'..addon_name..'\\Assets\\Conditions\\'
function addon:GetConditionCategoryIcon(group)
    if type(group)=='table' then
        if self:IsCategoryIcon(group.icon) then return group.icon end
        -- Stable identity survives renames/reordering without inheriting an
        -- indexed AceDB default or changing a saved explicit icon choice.
        local packaged=packagedCategoryIcons[group.id];if packaged then return conditionIconRoot..packaged end
        for _,tag in ipairs(group.conditions or {}) do local definition=(self.conditionDefinitions or {})[tag];if definition and definition.icon then return definition.icon end end
    end
    return conditionIconRoot..'logic'
end
function addon:ParseConditionCategoryImport(text,codec)
    if type(text)~='string' or #text>131072 then return nil,L['Invalid import.'] end
    local decoded=codec and codec:Decode(text);local value=decoded and decoded.value;local result={conditions={}}
    if value then
        if type(value)~='table' or value.format~='RM-ConditionCategory' or value.version~=1 or type(value.conditions)~='table' or value.name~=nil and (type(value.name)~='string' or not value.name:find('%S')) or value.icon~=nil and not self:IsCategoryIcon(value.icon) then return nil,L['Invalid import.'] end
        result.metadata=true;result.name=value.name;result.icon=value.icon
        local count=0;for index,tag in pairs(value.conditions) do if type(index)~='number' or index%1~=0 or index<1 or type(tag)~='string' then return nil,L['Invalid import.'] end;count=count+1 end
        if count~=#value.conditions or count>2000 then return nil,L['Invalid import.'] end
        result.conditions=value.conditions
    else for tag in text:gmatch('[^,%s]+') do result.conditions[#result.conditions+1]=tag;if #result.conditions>2000 then return nil,L['Invalid import.'] end end end
    local seen,unique={},{}
    for _,tag in ipairs(result.conditions) do if not (self.conditionDefinitions or {})[tag] and not (self.conditionSpecials or {})[tag] then return nil,string.format(L['Unknown condition: %s'],tag) end;if not seen[tag] then unique[#unique+1]=tag;seen[tag]=true end end
    result.conditions=unique;return result
end
