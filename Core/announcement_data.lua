local _,addon=...
function addon:IsValidAnnouncementItemReference(items)
    if type(items)=='string' then return #items>0 and #items<=128 end
    if type(items)~='table' or #items==0 or #items>256 then return false end
    local count=0
    for key,item in pairs(items) do
        if type(key)~='number' or key<1 or key%1~=0 or key>#items or not (type(item)=='number' and item>0 and item<math.huge and item%1==0 or type(item)=='string' and #item>0 and #item<=1024) then return false end;count=count+1
    end
    return count==#items
end
function addon:IsValidAnnouncement(value,requireIdentity)
    if type(value)~='table' then return false end
    if requireIdentity and (type(value.id)~='string' or not value.id:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')) then return false end
    local allowed={name=true,id=true,type=true,spell=true,item=true,ranked=true,disabled=true,event=true,announce=true,value=true,announce_sound=true,emote=true,emote_target=true,conditions=true}
    for key in pairs(value) do if not allowed[key] then return false end end
    if value.type~='spell' and value.type~='pet' and value.type~='item' then return false end
    if type(value.event)~='string' or not (self.events or {})[value.event] then return false end
    if not ({partyraid=true,party=true,raidwarn=true,emote=true,['local']=true,audible=true,say=true,yell=true,gesture=true})[value.announce] then return false end
    for _,key in ipairs({'disabled','ranked'}) do if value[key]~=nil and type(value[key])~='boolean' then return false end end
    if value.name~=nil and (type(value.name)~='string' or #value.name>256) then return false end
    if value.value~=nil and (type(value.value)~='string' or #value.value>4096) then return false end
    if value.announce_sound~=nil and (type(value.announce_sound)~='string' or #value.announce_sound>256) then return false end
    if value.emote_target~=nil and type(value.emote_target)~='boolean' then return false end
    if value.emote~=nil and (type(value.emote)~='string' or #value.emote>64 or not value.emote:match('^[A-Z][A-Z0-9_]*$')) then return false end
    if value.announce=='gesture' and value.emote==nil then return false end
    if value.announce=='audible' and (not value.announce_sound or not value.announce_sound:find('%S')) then return false end
    if value.conditions~=nil then
        if type(value.conditions)~='table' or not self.RotationData.CheckPortable(value.conditions) then return false end
        local result=self.RotationData.ValidateBody({switch=value.conditions,rotation={},cooldowns={}},{conditions=self.conditionDefinitions})
        if not result.valid or not result.supported then return false end
    end
    if value.type~='item' then return type(value.spell)=='number' and value.spell>0 and value.spell%1==0 end
    return self:IsValidAnnouncementItemReference(value.item)
end
