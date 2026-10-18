local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local channels={{value='audible',text=L['Audible']},{value='partyraid',text=L['Raid or Party']},{value='party',text=L['Party Only']},{value='raidwarn',text=L['Raid Warning']},{value='emote',text=L['Emote']},{value='local',text=L['Local Only']}}
local types={{value='spell',text=L['Spell']},{value='pet',text=L['Pet Spell']},{value='item',text=L['Item']}}
function addon:BuildAnnounceSettings(p)
    local store=p:SettingsData()
    local values=store.profile.announces or {};local events={};for id,text in pairs(self.events or {}) do events[#events+1]={value=id,text=text} end;table.sort(events,function(a,b) return a.text<b.text end)
    local refreshRoster
    local function update(entry,key,value) entry[key]=value;if refreshRoster then refreshRoster(entry) end end
    local function drawAction(prefix,entry)
        p:Choice(prefix..'type',L['Action Type'],entry.type,types,function(v) entry.type=v;entry.spell=nil;entry.item=nil;entry.ranked=nil;p:Draw() end)
        local field=entry.type=='item' and 'item' or 'spell'
        if entry.type=='item' then p:ItemSequence(prefix..'action',entry.item,function(v) update(entry,'item',v) end)
        else p:Spell(prefix..'action',L['Spell'],entry.spell,entry.type=='pet' and BOOKTYPE_PET or addon.currentSpec,function(v) update(entry,'spell',v) end);p:InlineCheck(prefix..'action',prefix..'ranked',L['Use this exact spell rank'],entry.ranked,function(v) update(entry,'ranked',v) end) end
        p:Choice(prefix..'event',L['Event'],entry.event,events,function(v) update(entry,'event',v) end)
        p:Choice(prefix..'channel',L['Announce'],entry.announce,channels,function(v) update(entry,'announce',v);p:Draw() end)
        if entry.announce=='audible' then p:Sound(prefix,L['Sound'],entry.announce_sound,function(v) update(entry,'announce_sound',v) end) else p:Edit(prefix..'text',L['Text'],entry.value or '',nil,function(v) update(entry,'value',v) end) end
    end
    local function itemInfo(value)
        if type(value)=='string' then local set=(store.profile.itemsets or {})[value] or (store.global.itemsets or {})[value];local info=set and set.items and self:GetReferenceProvider('item').info(tonumber(set.items[1]) or self:GetReferenceProvider('item').resolve(set.items[1]));return {name=set and set.name or L['Item Set'],icon=info and info.icon} end
        local id=type(value)=='table' and value[1] or value;return self:GetReferenceProvider('item').info(tonumber(id) or self:GetReferenceProvider('item').resolve(id))
    end
    refreshRoster=function(entry)
        local info=entry.type=='item' and itemInfo(entry.item) or self.Platform:GetSpellInfo(entry.spell)
        for i,value in ipairs(values) do if value==entry then p:UpdateRosterEntry(i,{text=self:SettingsNonempty(entry.name) or info and info.name or entry.type=='item' and L['Item data loading'] or L['Unknown spell'],icon=info and (info.icon or info.iconID),search=(entry.value or '')..' '..(entry.event or '')..' '..(entry.announce or '')});break end end
    end
    local entries={};for i,entry in ipairs(values) do local info=entry.type=='item' and itemInfo(entry.item) or self.Platform:GetSpellInfo(entry.spell);entries[#entries+1]={value=i,text=self:SettingsNonempty(entry.name) or info and info.name or entry.type=='item' and L['Item'] or L['Unknown spell'],icon=info and (info.icon or info.iconID),search=(entry.value or '')..' '..(entry.event or '')..' '..(entry.announce or '')} end
    if not values[p.selection] and not p.creating then p.selection=entries[1] and entries[1].value end
    local function addAnnouncement()
            local entry=p.newAnnounce;local field=entry.type=='item' and 'item' or 'spell'
            local valid
            if entry.type=='item' then local item=entry.item;local set=type(item)=='string' and ((store.profile.itemsets or {})[item] or (store.global.itemsets or {})[item]);valid=type(item)=='table' and #item>0 or set and type(set.items)=='table' and #set.items>0
            else valid=self:SettingsPositiveID(tostring(entry[field] or '')) end
            if not valid or not self:IsValidAnnouncement(entry) then p:Message(L['Choose an action first.']);return end
            store.profile.announces=store.profile.announces or {};store.profile.announces[#store.profile.announces+1]=self:CopySettingsData(entry);store.profile.announces[#store.profile.announces].id=self:uuid();p.selection=#store.profile.announces;p.creating=false;p.newAnnounce=nil;p:Draw()
    end
    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,{newText=L['Add announcement'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.emptyDismissed=false;p:Draw() end})
    local selected=not p.creating and values[p.selection] or nil
    local named={};for _,row in ipairs(entries) do named[row.value]=self:CopySettingsData(values[row.value]);named[row.value].name=row.text end
    self:CollectionFooter(p,'announcement',named,selected and p.selection or nil,
        {key='duplicate',text=L['Duplicate'],icon='copy',enabled=selected~=nil,action=function() local copy=self:CopySettingsData(selected);copy.id=self:uuid();values[#values+1]=copy;p.selection=#values;p:Draw() end},
        {key='transfer',text=L['Import/Export'],icon='transfer',action=function()
            local codec=self:NewRotationCodec();local text,why='',nil;if selected then text,why=codec:Encode({format='RM-Announcement',version=1,announcement=selected});if not text then p:Message(why);return end end
            self:ShowSettingsTextTransfer(p,L['Announces'],text,function(input,settings)
                local decoded,errorText=codec:Decode(input);local wrapper=decoded and decoded.value;local entry=wrapper and wrapper.announcement
                if type(wrapper)~='table' or wrapper.format~='RM-Announcement' or wrapper.version~=1 or not self:IsValidAnnouncement(entry) then return false,errorText or L['Invalid announcement.'] end
                entry=self:CopySettingsData(entry);entry.id=settings.mode=='replace' and selected and selected.id or self:uuid();entry.value=entry.value or '';store.profile.announces=store.profile.announces or {}
                if settings.mode=='replace' and selected then entry.name=selected.name;store.profile.announces[p.selection]=entry else entry.name=settings.name; store.profile.announces[#store.profile.announces+1]=entry;p.selection=#store.profile.announces end;p.creating=false;p.newAnnounce=nil;return true
            end,{canReplace=selected~=nil,selectedName=selected and (self:SettingsNonempty(selected.name) or named[p.selection].name),fallbackName=L['Imported announcement'],originalName=function(input) local decoded=codec:Decode(input);local entry=decoded and type(decoded.value)=='table' and decoded.value.announcement;if type(entry)=='table' then if self:SettingsNonempty(entry.name) then return entry.name end;local info=entry.type=='item' and itemInfo(entry.item) or self.Platform:GetSpellInfo(entry.spell);return info and info.name end end})
        end})
    p:Heading(L['Announces'])
    for i,entry in ipairs(values) do if i==p.selection and not p.creating then
        local title=self:SettingsNonempty(entry.name) or entry.type=='item' and (itemInfo(entry.item) and itemInfo(entry.item).name or L['Item data loading']) or self:PlainWorkbenchName(self:SpellLabel(entry.spell))
        p:Section('announce'..i,title,function()
            p:Edit('entry'..i..'name',L['Name'],entry.name or '',nil,function(value) update(entry,'name',value) end);drawAction('entry'..i,entry)
        end)
        local enabled=p:Acquire('announceEnabled',function() return self:CreateWorkbenchPill(p.child,'',88) end);enabled:ClearAllPoints();enabled:SetPoint('TOPRIGHT',-30,-4);enabled:SetSize(88,18);enabled:SetText(entry.disabled and L['Disabled'] or L['Enabled']);enabled:SetSelected(not entry.disabled);p.fields['enabled'..i]=enabled;self:SetUIScript(enabled,'OnClick',p:Guard(function() if p:FlushEdits() then entry.disabled=not entry.disabled;p:Draw() end end))
        p.fields['delete'..i]=self:SettingsTopDelete(p,function() table.remove(values,i);p:Draw() end)
    end
    end
    if p.creating or #values==0 and p:CanAutoCreateCollection('profile','announces') then
        p.newAnnounce=p.newAnnounce or {type='spell',event='SUCCEEDED',announce='partyraid',value=''}
        p:Edit('new_name',L['Name'],p.newAnnounce.name or '',nil,function(value) p.newAnnounce.name=value end);drawAction('new_',p.newAnnounce);p:CreationActions(addAnnouncement,function() p.newAnnounce=nil;p.creating=false;p.selection=p.previousSelection;p.emptyDismissed=true;p:Draw() end)
    end
end
