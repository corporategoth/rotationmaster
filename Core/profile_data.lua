local _,addon=...
local scalar={rotationSpecsMigrated='boolean',unitStateSwitchSeeded='boolean',contextConditionsSeeded='boolean',assistedConditionsSeeded='boolean',assistedSignalConditionsSeeded='boolean',engravingConditionsSeeded='boolean',loadoutConditionsSeeded='boolean',bossModConditionsSeeded='boolean',castProgressConditionsSeeded='boolean',previewHeaderlessGeometry='boolean',rotationFallbackID='string',lua_editor='string',lua_native_highlighting='boolean',lua_line_numbers='boolean',questie_enabled='boolean',encounter_provider='string',preview_masque='boolean',version='number',enable='boolean',poll='number',idle_poll='number',autoswitch_poll='number',ignore_mana='boolean',ignore_range='boolean',effect='string',magnification='number',setpoint='string',xoffs='number',yoffs='number',loglevel='number',detailed_profiling='boolean',disable_autoswitch='boolean',live_config_update='number',spell_history='number',combat_history='number',damage_history='number',disable_buttons='boolean',assisted_highlight='string',rotation_view='string',preview_spells='number',preview_vertical='boolean',preview_locked='boolean',preview_opacity='number',preview_icon_size='number'}
local function dense(value,validate)
    if type(value)~='table' then return false end;local n=0;for key,item in pairs(value) do if type(key)~='number' or key<1 or key%1~=0 or key>#value or not validate(item) then return false end;n=n+1 end;return n==#value
end
local function fields(value,schema)
    if type(value)~='table' then return false end;for key,item in pairs(value) do if type(item)~=schema[key] then return false end end;return true
end
local function specKey(key,encode)
    local number=type(key)=='string' and not encode and key:match('^%d+$') and tonumber(key) or key
    if type(number)~='number' or number<0 or number==math.huge or number%1~=0 then return nil end
    local text=tostring(number)
    if not text:match('^%d+$') or type(key)=='string' and key~=text then return nil end
    return encode and text or number
end
local function specMap(map,encode)
    if type(map)~='table' or getmetatable(map) then return nil end
    local result={}
    for key,value in pairs(map) do local converted=specKey(key,encode);if converted==nil or result[converted]~=nil then return nil end;result[converted]=value end
    return result
end
-- Preserve the whole reference graph while converting only structural spec-map
-- keys. A map aliased through another owner or payload must remain aliased for
-- the pure store validator to reject it; conversion must never hide that defect.
local function scopedStore(addon,state,encode)
    local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
    if not plain(state) or not plain(state.classes) or not plain(state.characters) or not plain(state.legacy) then return nil end
    if encode and not addon.RotationData.ValidateRotationStore(state) then return nil end
    local maps={}
    for _,map in pairs(state.classes) do if not plain(map) then return nil end;maps[map]=true end
    for _,bucket in pairs(state.characters) do if not plain(bucket) or not plain(bucket.specs) then return nil end;maps[bucket.specs]=true end
    for _,kind in ipairs({'rotations','origins','imports','comparisons'}) do
        local map=state.legacy[kind];if map~=nil then if not plain(map) then return nil end;maps[map]=true end
    end
    local seen={};local failed=false
    local function copy(value)
        if type(value)~='table' then return value end
        if not plain(value) then failed=true;return nil end
        if seen[value] then return seen[value] end
        local result={};seen[value]=result
        for key,child in pairs(value) do
            local converted=key
            if maps[value] then converted=specKey(key,encode) end
            if converted==nil or result[converted]~=nil then failed=true;return nil end
            result[converted]=copy(child)
        end
        return result
    end
    local result=copy(state)
    if failed or not encode and not addon.RotationData.ValidateRotationStore(result) then return nil end
    return result
end
-- The desired-stock feature is retired. An existing saved stockTargets map
-- is inert data: copies, transfers and validation carry it unread as long as
-- it is plain table data.
local function validStockTargets(_,profile)
    if type(profile)~='table' then return true end
    local plan=rawget(profile,'stockTargets')
    return plan==nil or type(plan)=='table' and getmetatable(plan)==nil
end
local function validRotationChoices(owner,profile)
    local value=type(profile)=='table' and rawget(profile,'rotationChoicePreferences')
    return value==nil or type(owner.ValidateRotationChoicePreferences)=='function' and owner:ValidateRotationChoicePreferences(value)==true
end
function addon:ValidateProfileTransfer(value)
    if type(value)~='table' then return false end
    if not validStockTargets(self,value) or not validRotationChoices(self,value) then return false end
    local wire=self:ProfileToPortable(value);if not wire or not self.RotationData.CheckPortable(wire) then return false end
    local function stringValue(v) return type(v)=='string' end
    for key,item in pairs(value) do
        if scalar[key] then if type(item)~=scalar[key] then return false end
        elseif key=='rotationTagColors' then
            if type(item)~='table' then return false end;local count=0;for tag,color in pairs(item) do count=count+1;if count>4096 or not self.RotationData.NormalizeRotationTags({tag}) or tag~=tag:lower() or not fields(color,{r='number',g='number',b='number',a='number'}) then return false end;for _,channel in ipairs({'r','g','b','a'}) do local n=color[channel];if type(n)~='number' or n~=n or n<0 or n>1 then return false end end end
        elseif key=='color' then if not fields(item,{r='number',g='number',b='number',a='number'}) then return false end;for _,v in pairs(item) do if v<0 or v>1 then return false end end
        elseif key=='preview_window' then if not fields(item,{point='string',relpoint='string',xoffs='number',yoffs='number'}) then return false end
        elseif key=='minimap' then if not fields(item,{hide='boolean',minimapPos='number',radius='number',lock='boolean',showInCompartment='boolean'}) then return false end
        elseif key=='switch_conditions' or key=='announcement_conditions' or key=='disabled_conditions' or key=='other_conditions_order' then if not dense(item,stringValue) then return false end
        elseif key=='condition_groups' then
            if not dense(item,function(group) return type(group)=='table' and fields(group,{id='string',name='string',conditions='table',icon=type(group.icon)}) and type(group.id)=='string' and type(group.name)=='string' and dense(group.conditions,stringValue) and (group.icon==nil or self:IsCategoryIcon(group.icon)) end) then return false end
        elseif key=='announces' then local seen={};if not self:AreMacroAnnouncementIdentifiersUnique(item) or not dense(item,function(v) if not self:IsValidAnnouncement(v,true) or seen[v.id] then return false end;seen[v.id]=true;return true end) then return false end
        elseif key=='lua_editor_disabled' then
            if type(item)~='table' or getmetatable(item)~=nil then return false end
            local count=0
            for name,disabled in pairs(item) do
                count=count+1
                if count>64 or type(name)~='string' or #name>128 or not name:find('%S') or name=='auto' or name=='plain' or disabled~=true then return false end
            end
        elseif key=='builtinPreferenceRepairs' then
            -- One-time Built In preference repair, done per class token.
            if type(item)~='table' or getmetatable(item)~=nil then return false end
            for class,done in pairs(item) do if type(class)~='string' or not class:match('^%u+$') or #class>32 or done~=true then return false end end
        elseif key=='rotationChoicePreferences' then
            -- Closed optional schema checked before generic recursive copying.
        elseif key=='stockTargets' then
            -- Retired desired-stock data: plain tables only, carried unread.
        elseif key=='itemsets' then
            if type(item)~='table' then return false end;for id,set in pairs(item) do if type(id)~='string' or not fields(set,{name='string',items='table',modified='boolean'}) or type(set.name)~='string' or not dense(set.items,function(v) return type(v)=='string' and #v>0 or type(v)=='number' and v>0 and v%1==0 end) then return false end end
        elseif key=='rotations' then
            if type(item)~='table' then return false end
            for spec,rotations in pairs(item) do
                if type(spec)~='number' or spec<0 or spec%1~=0 or type(rotations)~='table' then return false end
                for id,body in pairs(rotations) do if type(id)~='string' then return false end;local check=self.RotationData.ValidateBody(body,{conditions=self.conditionDefinitions,itemsets=value.itemsets,effects=self.db.global.effects});if not check.valid then return false end end
            end
        elseif key=='rotationStore' then
            if not self.RotationData.ValidateRotationStore(item) then return false end
        elseif key=='rotationLibrary' then
            if type(item)~='table' then return false end
            -- Library preferences and clone provenance are portable data only;
            -- no global definitions, functions or executable imports are loaded.
            for field,rows in pairs(item) do
                if not ({preferences=true,origins=true,comparisons=true,imports=true})[field] or type(rows)~='table' then return false end
                if field=='preferences' then for id,preference in pairs(rows) do if type(id)~='string' or not fields(preference,{enabled='boolean',priority='number'}) or preference.priority~=nil and not self.RotationData.GetRotationPriority(preference.priority) then return false end end
                else for spec,records in pairs(rows) do
                    if type(spec)~='number' or spec<0 or spec%1~=0 or type(records)~='table' then return false end
                    for id,record in pairs(records) do
                        if type(id)~='string' or type(record)~='table' then return false end
                        if field=='origins' and (type(record.manifest)~='table' or type(record.lineage)~='table') then return false end
                        if field=='imports' and (type(record.manifest)~='table' or type(record.sourceId)~='string' or type(record.stepOrigins)~='table') then return false end
                        if field=='comparisons' and (type(record.kind)~='string' or type(record.id)~='string' or type(record.origins)~='table') then return false end
                    end
                end end
            end
        else return false end
    end
    if value.version~=nil and (value.version<1 or value.version>3 or value.version%1~=0) then return false end
    if value.rotationFallbackID~=nil and (#value.rotationFallbackID==0 or #value.rotationFallbackID>128 or not value.rotationFallbackID:find('%S') or value.rotationFallbackID:find('[%z\1-\31\127]')) then return false end
    if value.lua_editor~=nil and (#value.lua_editor>128 or not value.lua_editor:find('%S')) then return false end
    if value.encounter_provider~=nil and value.encounter_provider~='DBM-Core' and value.encounter_provider~='BigWigs' then return false end
    if value.rotation_view~=nil and value.rotation_view~='diagram' and value.rotation_view~='list' then return false end
    if value.preview_spells~=nil and (value.preview_spells<0 or value.preview_spells>5 or value.preview_spells%1~=0) then return false end
    if value.preview_opacity~=nil and (value.preview_opacity<0 or value.preview_opacity>1) then return false end
    if value.preview_icon_size~=nil and (value.preview_icon_size<24 or value.preview_icon_size>160) then return false end
    if value.poll~=nil and (value.poll<.01 or value.poll>5) then return false end
    for _,key in ipairs({'idle_poll','autoswitch_poll'}) do if value[key]~=nil and (value[key]~=value[key] or value[key]<0 or value[key]>60) then return false end end
    if value.magnification~=nil and (value.magnification<.1 or value.magnification>10) then return false end
    for _,key in ipairs({'live_config_update','spell_history','combat_history','damage_history'}) do if value[key]~=nil and value[key]<0 then return false end end
    return true
end
-- Profile specialization maps include spec 0. The shared rotation transport
-- intentionally accepts only positive numeric table keys, so profile wire maps
-- use canonical decimal strings and restore numbers only in these namespaces.
function addon:ProfileToPortable(profile)
    if not validStockTargets(self,profile) or not validRotationChoices(self,profile) then return nil end
    local copy=self:CopySettingsData(profile)
    local function encode(map) return specMap(map,true) end
    if type(copy)=='table' then
        if copy.rotations~=nil then copy.rotations=encode(copy.rotations);if not copy.rotations then return nil end end
        if type(copy.rotationLibrary)=='table' then for _,key in ipairs({'origins','comparisons','imports'}) do if copy.rotationLibrary[key]~=nil then copy.rotationLibrary[key]=encode(copy.rotationLibrary[key]);if not copy.rotationLibrary[key] then return nil end end end end
        if copy.rotationStore~=nil then copy.rotationStore=scopedStore(self,profile.rotationStore,true);if not copy.rotationStore then return nil end end
    end
    return copy
end
function addon:ProfileFromPortable(profile,options)
    if not validStockTargets(self,profile) or not validRotationChoices(self,profile) then return nil end
    local copy=self:CopySettingsData(profile)
    local function decode(map) return specMap(map,false) end
    if type(copy)~='table' then return nil end
    if copy.rotationStore~=nil then copy.rotationStore=scopedStore(self,profile.rotationStore,false);if not copy.rotationStore then return nil end end
    if copy.rotations~=nil then copy.rotations=decode(copy.rotations);if not copy.rotations then return nil end end
    -- Older profile exports can retain an entirely empty default placeholder.
    -- Materialize only its missing empty lists; malformed nonempty records still
    -- go through normal validation and are never silently repaired or removed.
    if not (type(options)=='table' and options.preserveLegacyBodies==true) and type(copy.rotations)=='table' then for _,rotations in pairs(copy.rotations) do
        if type(rotations)=='table' then for _,body in pairs(rotations) do
            if type(body)=='table' and next(body)==nil then body.rotation={};body.cooldowns={} end
        end end
    end end
    if copy.rotationLibrary~=nil then if type(copy.rotationLibrary)~='table' then return nil end;for _,key in ipairs({'origins','comparisons','imports'}) do if copy.rotationLibrary[key]~=nil then copy.rotationLibrary[key]=decode(copy.rotationLibrary[key]);if not copy.rotationLibrary[key] then return nil end end end end
    return copy
end
