local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function nonempty(text) if text:find('%S') and #text<=50 then return text end end
function addon:BuildProfileSettings(p)
    local db=self.db;local current=db:GetCurrentProfile();local names=db:GetProfiles();table.sort(names)
    local entries,values={},{};for _,name in ipairs(names) do entries[#entries+1]={value=name,text=name};values[name]=name==current and db.profile or db.profiles and db.profiles[name] or {} end
    if not values[p.selection] and not p.creating then p.selection=current end
    local function overlay(destination,incoming) for key,value in pairs(incoming) do if (key=='color' or key=='minimap' or key=='preview_window') and type(value)=='table' and type(destination[key])=='table' then for field,entry in pairs(value) do destination[key][field]=self:CopySettingsData(entry) end else destination[key]=self:CopySettingsData(value) end end end
    local function saved(name) return name==db:GetCurrentProfile() and db.profile or db.profiles[name] end
    local function change(operation,name,after)
        if self.DisableRotation then self:DisableRotation() end
        local depth=self.rotationProfileChangeDepth or 0;self.rotationProfileChangeDepth=depth+1
        local ok,why=pcall(function() db[operation](db,name);if after then after() end end)
        self.rotationProfileChangeDepth=depth
        if invalidateDependencies then invalidateDependencies(addon,'all',nil) end
        if self.RotationProfileChanged then self:RotationProfileChanged()
        elseif self.EnableRotation then self:EnableRotation() end
        if not ok then p:Message(tostring(why));return false end
        p.profile=db.profile;p.selection=p.selectAfterProfileChange or db:GetCurrentProfile();p.selectAfterProfileChange=nil;p:Draw();if self.RefreshConfiguration then self:RefreshConfiguration() end;return true
    end
    p:UseRoster(entries,p.selection,function(name) p.selection=name;p.creating=false;p:Draw() end,{new=function() p.previousSelection=p.selection;p.creating=true;p.newProfileName='';p.profileSource=nil;p.importProfile=nil;p:Draw() end})
    local selected=not p.creating and values[p.selection] or nil;local selectedName=p.selection
    local compareValues={};for name,value in pairs(values) do compareValues[name]={name=name,profile=value} end
    self:CollectionFooter(p,'profile',compareValues,selected and selectedName or nil,
        {key='duplicate',text=L['Duplicate'],icon='copy',enabled=selected~=nil,action=function() p.previousSelection=p.selection;p.profileSource=selectedName;p.newProfileName=string.format(L['Copy of %s'],selectedName);p.creating=true;p:Draw() end},
        {key='transfer',text=L['Import/Export'],icon='transfer',action=function()
            local codec=self:NewRotationCodec();local text,why='',nil
            if selected then
                local portable=self:ProfileToPortable(selected);if not portable then p:Message(L['Invalid profile.']);return end
                text,why=codec:Encode({format='RM-Profile',version=1,name=selectedName,profile=portable});if not text then p:Message(why);return end
            end
            local baseline=selected and self:CopySettingsData(selected)
            self:ShowSettingsTextTransfer(p,L['Profiles'],text,function(input,settings)
                local decoded,errorText=codec:Decode(input);local wrapper=decoded and decoded.value;local candidate=type(wrapper)=='table' and self:ProfileFromPortable(wrapper.profile,{preserveLegacyBodies=true})
                if type(wrapper)~='table' or wrapper.format~='RM-Profile' or wrapper.version~=1 or type(candidate)~='table' then return false,errorText or L['Invalid profile.'] end
                local plan,migrationError=self:PlanRotationProfileMigration(candidate,candidate.rotationFallbackID or DEFAULT)
                if not plan then return false,migrationError end
                local migrated,why=self:ApplyRotationProfileMigration(plan);if not migrated or not self:ValidateProfileTransfer(candidate) then return false,why or L['Invalid profile.'] end
                if settings.mode=='replace' and selected then
                    local target=selectedName==db:GetCurrentProfile() and db.profile or db.profiles[selectedName]
                    if target~=selected or not self:SettingsDataEqual(baseline,self:CopySettingsData(target)) then return false,L['The selected profile changed. Reopen the import window.'] end
                    if selectedName==db:GetCurrentProfile() then return change('ResetProfile',nil,function() overlay(db.profile,candidate) end) end
                    db.profiles[selectedName]=self:CopySettingsData(candidate);p.selection=selectedName;return true
                end
                for _,name in ipairs(db:GetProfiles()) do if name==settings.name then return false,L['This name is already in use.'] end end
                p.importProfile=candidate;p.profileSource=nil;p.newProfileName=settings.name;p.previousSelection=p.selection;p.creating=true;return true
            end,{canReplace=selected~=nil,selectedName=selectedName,fallbackName=L['Imported profile'],help={heading=L['Profiles'],owner=selectedName,brief=L['Help.Transfers.profile_brief'],briefs=self:TransferHelpBriefs(),
                valid=function()
                    if not selected then return true end
                    local target=selectedName==db:GetCurrentProfile() and db.profile or db.profiles[selectedName]
                    return target==selected and self:SettingsDataEqual(target,baseline)
                end,
                sections=function(dialog)return {{title=L['Import/Export'],text=L['Help.Transfers.profile_overview']},{title=L['Destination'],text=dialog.mode=='replace' and L['Help.Transfers.profile_replace'] or L['Help.Transfers.profile_new']}}end},originalName=function(input) local decoded=codec:Decode(input);return decoded and type(decoded.value)=='table' and decoded.value.name end})
        end},function(left,right)
            local first,second=saved(left.name),saved(right.name)
            if not first or not second then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            self:ShowCollectionComparison(p,'profile',{name=left.name,profile=first},{name=right.name,profile=second})
        end)
    p:Text(L['Profile changes apply immediately. Rotations and settings belong to the active profile.'])
    if p.creating then
        p:Edit('new_name',L['New profile name'],p.newProfileName or '',nil,function(text) p.newProfileName=text end)
        p:CreationActions(function()
            local name=nonempty(p.newProfileName or '');if not name then p:Message(L['Enter a profile name first.']);return end
            for _,existing in ipairs(db:GetProfiles()) do if existing==name then p:Message(L['This name is already in use.']);return end end
            local source=p.profileSource;local imported=p.importProfile;local previous=db:GetCurrentProfile()
            p.selectAfterProfileChange=name
            local ok=change('SetProfile',name,function() if source then db:CopyProfile(source) elseif imported then overlay(db.profile,imported) end;db:SetProfile(previous);p.creating=false;p.importProfile=nil;p.profileSource=nil end)
            if ok then p.newProfileName=nil end
        end,function() p.creating=false;p.selection=p.previousSelection or current;p.profileSource=nil;p.importProfile=nil;p.newProfileName=nil;p:Draw() end);p.fields.new=p.fields.apply;return
    end
    if selected then
        p:Heading(selectedName)
        local active=p:Button('activate',selectedName==current and L['Active profile'] or L['Activate profile'],function() change('SetProfile',selectedName) end);if selectedName==current then active:Disable() end
        local rows,recovery=self:GetProfileRotationHeaders(selected)
        local summary={};for _,row in ipairs(rows or {}) do summary[#summary+1]=row.name end;table.sort(summary)
        p:Text(not rows and string.format(L['Rotation data requires recovery: %s'],recovery) or #summary>0 and table.concat(summary,'\n') or L['No rotations in this profile.'])
        local others={};for _,entry in ipairs(entries) do if entry.value~=current then others[#others+1]=entry end end
        -- Keep explicit copying into the active profile available, with its
        -- existing replacement confirmation and runtime lifecycle.
        local copy=p:Choice('copy',L['Copy from profile'],nil,others,function(name) p:Confirm(string.format(L['Replace the current profile with %s?'],name),function() change('CopyProfile',name) end) end);if #others==0 then copy:Disable() end
        local reset=p:Button('reset',L['Reset current profile'],function() p:Confirm(L['Reset this profile to its defaults? Custom rotations and settings in it will be replaced.'],function() change('ResetProfile') end) end);if selectedName~=current then reset:Disable() end
        local trash=self:SettingsTopDelete(p,function() p:Confirm(string.format(L['Delete profile %s? This cannot be undone.'],selectedName),function() db:DeleteProfile(selectedName);p.selection=current;p:Draw() end) end);if selectedName==current or selectedName=='Default' then trash:Disable() end
        -- Compatibility for existing direct current-profile callers; sidebar
        -- selection is inspection, activation is always explicit.
        p.fields.current=p.fields.activate
    end
end
function addon:BuildAboutSettings(p)
    local getter=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local function meta(key) if type(getter)=='function' then local ok,value=pcall(getter,addon_name,key);if ok and type(value)=='string' and value~='' then return value end end end
    p:Heading(addon.pretty_name or L['Rotation Master']);p:Text(meta('Notes') or L['Browse, view and edit rotations.'])
    for _,entry in ipairs({{'Version','Version'},{'Author','Author'},{'X-License','License'},{'X-Credits','Credits'},{'X-Localizations','Localizations'}}) do
        local value=meta(entry[1]);if value then if value:find('@',1,true) then value=L['Development'] end;p:Text(L[entry[2]]..': '..value) end
    end
    p:Heading(L['Links'])
    for _,entry in ipairs({{'X-Website','Website'},{'X-Discord','Discord'},{'X-Email','Email'}}) do local value=meta(entry[1]);if value then
        local c=p:Edit(entry[1],L[entry[2]],value,nil,function() end)
        addon:SetUIScript(c,'OnEditFocusGained',p:Guard(function() c:SetCursorPosition(0);c:HighlightText(0,-1) end))
        addon:SetUIScript(c,'OnTextChanged',p:Guard(function(_,user) if user then c:SetText(value) end end))
    end end
    p:Heading(L['Commands']);p:Text('/rm config\n/rm errors\n/rm help')
end
