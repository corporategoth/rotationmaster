local _,addon=...
function addon:IsValidAnnouncement(value,requireIdentity)
    if type(value)~='table' then return false end
    if requireIdentity and (type(value.id)~='string' or not value.id:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')) then return false end
    local allowed={name=true,id=true,type=true,spell=true,item=true,ranked=true,disabled=true,event=true,announce=true,value=true,announce_sound=true}
    for key in pairs(value) do if not allowed[key] then return false end end
    if value.type~='spell' and value.type~='pet' and value.type~='item' then return false end
    if type(value.event)~='string' or not (self.events or {})[value.event] then return false end
    if not ({partyraid=true,party=true,raidwarn=true,emote=true,['local']=true,audible=true,say=true,yell=true})[value.announce] then return false end
    for _,key in ipairs({'disabled','ranked'}) do if value[key]~=nil and type(value[key])~='boolean' then return false end end
    if value.name~=nil and (type(value.name)~='string' or #value.name>256) then return false end
    if value.value~=nil and (type(value.value)~='string' or #value.value>4096) then return false end
    if value.announce_sound~=nil and (type(value.announce_sound)~='string' or #value.announce_sound>256) then return false end
    if value.announce=='audible' and (not value.announce_sound or not value.announce_sound:find('%S')) then return false end
    if value.type~='item' then return type(value.spell)=='number' and value.spell>0 and value.spell%1==0 end
    if type(value.item)=='string' then return #value.item>0 and #value.item<=128 end
    if type(value.item)~='table' or #value.item==0 or #value.item>256 then return false end
    local count=0
    for key,item in pairs(value.item) do
        if type(key)~='number' or key<1 or key%1~=0 or key>#value.item or not (type(item)=='number' and item>0 and item%1==0 or type(item)=='string' and #item>0 and #item<=1024) then return false end;count=count+1
    end
    return count==#value.item
end
