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
function addon:IsValidMacroAnnouncementIdentifier(value)
    return type(value)=='string' and #value<=64 and value:match('^[A-Za-z_][A-Za-z0-9_.-]*$')~=nil
end
-- Cold configuration/import check; no retained lookup registry or polling work.
function addon:AreMacroAnnouncementIdentifiersUnique(entries)
    if type(entries)~='table' then return false end
    local seen={}
    for _,entry in ipairs(entries) do if type(entry)=='table' and entry.type=='macro' then
        if not self:IsValidMacroAnnouncementIdentifier(entry.identifier) or seen[entry.identifier] then return false end
        seen[entry.identifier]=true
    end end
    return true
end
local function outputIdentity(value)
    return type(value)=='string' and value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')~=nil
end
-- Output cards are bounded configuration data; imports never execute callbacks.
function addon:IsValidAnnouncementOutput(value,macro)
    if type(value)~='table' or getmetatable(value)~=nil or not outputIdentity(value.id) then return false end
    local allowed={id=true,announce=true,value=true,announce_sound=true,emote=true,emote_target=true,conditions=true,disabled=true,channel_name=true}
    for key in pairs(value) do if not allowed[key] then return false end end
    if not ({partyraid=true,party=true,raidwarn=true,emote=true,['local']=true,audible=true,gesture=true,say=macro,yell=macro,whisper=macro,channel=macro})[value.announce] then return false end
    if value.disabled~=nil and type(value.disabled)~='boolean' or value.emote_target~=nil and type(value.emote_target)~='boolean' then return false end
    if value.value~=nil and (type(value.value)~='string' or #value.value>4096) then return false end
    if value.announce_sound~=nil and (type(value.announce_sound)~='string' or #value.announce_sound>256) then return false end
    if value.emote~=nil and (type(value.emote)~='string' or #value.emote>64 or not value.emote:match('^[A-Z][A-Z0-9_]*$')) then return false end
    if value.announce=='gesture' and value.emote==nil then return false end
    if value.announce=='audible' and (not value.announce_sound or not value.announce_sound:find('%S')) then return false end
    if value.channel_name~=nil and (type(value.channel_name)~='string' or #value.channel_name==0 or #value.channel_name>256 or value.channel_name:find('[%z\1-\31\127]')) then return false end
    if value.announce=='channel' and value.channel_name==nil then return false end
    if value.conditions~=nil then
        if type(value.conditions)~='table' or not self.RotationData.CheckPortable(value.conditions) then return false end
        local result=self.RotationData.ValidateBody({switch=value.conditions,rotation={},cooldowns={}},{conditions=self.conditionDefinitions})
        if not result.valid or not result.supported then return false end
    end
    return true
end
local function validSeries(owner,value,requireIdentity)
    if getmetatable(value)~=nil or requireIdentity and not outputIdentity(value.id) then return false end
    local allowed={id=true,name=true,type=true,spell=true,item=true,ranked=true,event=true,identifier=true,disabled=true,outputs=true}
    for key in pairs(value) do if not allowed[key] then return false end end
    for _,key in ipairs({'disabled','ranked'}) do if value[key]~=nil and type(value[key])~='boolean' then return false end end
    if value.name~=nil and (type(value.name)~='string' or #value.name>256) then return false end
    local macro=value.type=='macro'
    if macro then
        if not owner:IsValidMacroAnnouncementIdentifier(value.identifier) or value.spell~=nil or value.item~=nil or value.ranked~=nil or value.event~=nil then return false end
    elseif value.type~='spell' and value.type~='pet' and value.type~='item' then return false
    elseif value.identifier~=nil or type(value.event)~='string' or not (owner.events or {})[value.event] then return false
    elseif value.type=='item' then if not owner:IsValidAnnouncementItemReference(value.item) then return false end
    elseif type(value.spell)~='number' or value.spell<=0 or value.spell==math.huge or value.spell%1~=0 then return false end
    local outputs=value.outputs
    if type(outputs)~='table' or getmetatable(outputs)~=nil or #outputs>64 then return false end
    local count,seen=0,{}
    for index,output in pairs(outputs) do
        if type(index)~='number' or index<1 or index%1~=0 or index>#outputs or not owner:IsValidAnnouncementOutput(output,macro) or seen[output.id] then return false end
        count=count+1;seen[output.id]=true
    end
    return count==#outputs
end
function addon:IsValidAnnouncement(value,requireIdentity)
    if type(value)~='table' then return false end
    if value.outputs~=nil then return validSeries(self,value,requireIdentity) end
    if requireIdentity and (type(value.id)~='string' or not value.id:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')) then return false end
    local allowed={name=true,id=true,type=true,spell=true,item=true,ranked=true,disabled=true,event=true,announce=true,value=true,announce_sound=true,emote=true,emote_target=true,conditions=true,identifier=true}
    for key in pairs(value) do if not allowed[key] then return false end end
    local macro=value.type=='macro'
    if macro then
        if not self:IsValidMacroAnnouncementIdentifier(value.identifier) or value.spell~=nil or value.item~=nil or value.ranked~=nil or value.event~=nil then return false end
    elseif value.type~='spell' and value.type~='pet' and value.type~='item' then return false
    elseif value.identifier~=nil or type(value.event)~='string' or not (self.events or {})[value.event] then return false end
    if not ({partyraid=true,party=true,raidwarn=true,emote=true,['local']=true,audible=true,say=true,yell=true,gesture=true,whisper=macro})[value.announce] then return false end
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
    if macro then return true end
    if value.type~='item' then return type(value.spell)=='number' and value.spell>0 and value.spell%1==0 end
    return self:IsValidAnnouncementItemReference(value.item)
end
