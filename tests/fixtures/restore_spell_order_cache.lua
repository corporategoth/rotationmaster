-- Restore the exact pre-order-cache source before older whole-file proofs.
-- Every replacement is unique; historical retained-activity pins stay unchanged.
local replacements={
 {new=[====[local entries,byName={},{}
-- At most one private ordering per indexed name group. Metadata refresh still
-- observes the provider; only ordering/membership changes retire this view.
local ordered,groupVersion,memberNames={},{},{}
local function invalidateGroup(key)
    ordered[key]=nil;groupVersion[key]=(groupVersion[key] or 0)+1
end
local function copyIDs(ids)
    local result={};for i=1,#ids do result[i]=ids[i] end;return result
end

]====],old=[====[local entries,byName={},{}

]====]},
 {new=[====[function catalog:UpdateSpell(id)
    if type(id)~="number" or id<1 or id==math.huge or id%1~=0 then return nil end
    local info,reason=addon.Platform:GetSpellInfo(id)
    if not info then return nil,reason end
    local old=entries[id]
    if old and old.name~=info.name then
        local oldKey=string.lower(old.name)
        invalidateGroup(oldKey)
        byName[oldKey][id]=nil
        memberNames[id][oldKey]=nil
    end
    local entry={name=info.name,rank=info.subtext,icon=info.iconID,link=addon.Platform:GetSpellLink(id)}
    -- A link provider can reenter and update this ID before outer publication.
    local previous=entries[id]
    if previous and (previous.name~=entry.name or previous.rank~=entry.rank) then
        -- Reentrant publication can leave an ID in more than its current name
        -- group. Every surviving membership sorts against this same entry.
        for member in pairs(memberNames[id]) do invalidateGroup(member) end
    end
    entries[id]=entry
    local key=string.lower(entry.name)
    byName[key]=byName[key] or {}
    if not byName[key][id] then invalidateGroup(key) end
    byName[key][id]=true
    memberNames[id]=memberNames[id] or {}
    memberNames[id][key]=true
    return true
end
]====],old=[====[function catalog:UpdateSpell(id)
    if type(id)~="number" or id<1 or id==math.huge or id%1~=0 then return nil end
    local info,reason=addon.Platform:GetSpellInfo(id)
    if not info then return nil,reason end
    local old=entries[id]
    if old and old.name~=info.name then
        byName[string.lower(old.name)][id]=nil
    end
    local entry={name=info.name,rank=info.subtext,icon=info.iconID,link=addon.Platform:GetSpellLink(id)}
    entries[id]=entry
    local key=string.lower(entry.name)
    byName[key]=byName[key] or {};byName[key][id]=true
    return true
end
]====]},
 {new=[====[function catalog:GetAllSpellIds(spell)
    local name
    if type(spell)=="number" then
        if not entries[spell] then self:UpdateSpell(spell) end
        name=entries[spell] and entries[spell].name
    elseif type(spell)=="string" then name=spell end
    if not name then return nil end
    local key=string.lower(name)
    local group=byName[key]
    if not group then return nil end
    if ordered[key] then return copyIDs(ordered[key]) end
    local version=groupVersion[key]
    local result={}
    for id in pairs(group) do result[#result+1]=id end
    table.sort(result,preferred)
    -- Never publish a stale sort, or expose its private storage to the caller
    -- (or a source-owned sorting hook used during this cold construction).
    if groupVersion[key]==version then ordered[key]=copyIDs(result) end
    return result
end
]====],old=[====[function catalog:GetAllSpellIds(spell)
    local name
    if type(spell)=="number" then
        if not entries[spell] then self:UpdateSpell(spell) end
        name=entries[spell] and entries[spell].name
    elseif type(spell)=="string" then name=spell end
    if not name then return nil end
    local group=byName[string.lower(name)]
    if not group then return nil end
    local result={}
    for id in pairs(group) do result[#result+1]=id end
    table.sort(result,preferred)
    return result
end
]====]},
}
return function(text,path)
 assert(path=='Core/spell_catalog.lua','unknown spell order inverse path')
 for _,entry in ipairs(replacements) do
  local a,b=text:find(entry.new,1,true)
  assert(a,'spell order cache block changed')
  assert(not text:find(entry.new,b+1,true),'duplicate spell order cache block')
  text=text:sub(1,a-1)..entry.old..text:sub(b+1)
 end
 return text
end
