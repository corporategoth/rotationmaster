-- Strict inverse of the Unit2a stock settings safety boundaries only.
local changes={
 ['UI/settings_draft.lua']={bytes=6286,hash='5d36c531',edits={
  {from=[====[profile=addon:CopySettingsData(addon.StockSettings.DraftProfile(addon.db.profile))]====],to=[====[profile=addon:CopySettingsData(addon.db.profile)]====]},
 }},
 ['UI/settings_collections.lua']={bytes=7014,hash='4830ca6f',edits={
  {from=[====[if compare then compare(values[current],values[id]) else self:ShowCollectionComparison(p,kind,values[current],values[id]) end]====],to=[====[self:ShowCollectionComparison(p,kind,values[current],values[id])]====]},
  {from=[====[function addon:CollectionFooter(p,kind,values,current,duplicate,transfer,compare)]====],to=[====[function addon:CollectionFooter(p,kind,values,current,duplicate,transfer)]====]},
 }},
 ['UI/settings_profiles.lua']={bytes=9505,hash='7bb2cd86',edits={
  {from=[====[        local ok,why=pcall(function() if operation=='CopyProfile' and not stockOK(saved(name)) then error(L['Invalid stock targets; data preserved.'],0) end;db[operation](db,name);if after then after() end end)]====],to=[====[        local ok,why=pcall(function() db[operation](db,name);if after then after() end end)]====]},
  {from=[====[if source then if not stockOK(saved(source)) then db:SetProfile(previous);error(L['Invalid stock targets; data preserved.'],0) end;db:CopyProfile(source) elseif imported then]====],to=[====[if source then db:CopyProfile(source) elseif imported then]====]},
  {from=[====[            local source=p.profileSource;local imported=p.importProfile;local previous=db:GetCurrentProfile()
            if source and not stockOK(saved(source)) then return end;p.selectAfterProfileChange=name]====],to=[====[            local source=p.profileSource;local imported=p.importProfile;local previous=db:GetCurrentProfile();p.selectAfterProfileChange=name]====]},
  {from=[====[        end},function(left,right)
            local first,second=saved(left.name),saved(right.name)
            if not first or not second then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            if stockOK(first) and stockOK(second) then self:ShowCollectionComparison(p,'profile',{name=left.name,profile=first},{name=right.name,profile=second}) end
        end)
    p:Heading(L['Profiles']);]====],to=[====[        end})
    p:Heading(L['Profiles']);]====]},
  {from=[====[                    if not stockOK(target) then return false,L['Invalid stock targets; data preserved.'] end
                    if target~=selected or not self:SettingsDataEqual(baseline,self:CopySettingsData(target)) then]====],to=[====[                    if target~=selected or not self:SettingsDataEqual(baseline,self:CopySettingsData(target)) then]====]},
  {from=[====[            if selected and not stockOK(selected) then return end
            local baseline=selected and self:CopySettingsData(selected)]====],to=[====[            local baseline=selected and self:CopySettingsData(selected)]====]},
  {from=[====[action=function() if not stockOK(saved(selectedName)) then return end;p.previousSelection=p.selection;p.profileSource=selectedName;]====],to=[====[action=function() p.previousSelection=p.selection;p.profileSource=selectedName;]====]},
  {from=[====[    local function saved(name) return name==db:GetCurrentProfile() and db.profile or db.profiles[name] end
    local function stockOK(profile)
        if self.StockSettings.CheckProfile(profile) then return true end
        p:Message(L['Invalid stock targets; data preserved.']);return false
    end
    local function change(operation,name,after)
        if operation=='CopyProfile' and not stockOK(saved(name)) then return false end]====],to=[====[    local function change(operation,name,after)]====]},
 }},
}
return function(text,path)
 local spec=assert(changes[path],'unknown stock UI safety source path')
 for _,edit in ipairs(spec.edits)do
  local a,b=text:find(edit.from,1,true);assert(a and not text:find(edit.from,b+1,true),'stock UI safety inverse source differs')
  text=text:sub(1,a-1)..edit.to..text:sub(b+1)
 end
 local hash=0;for i=1,#text do hash=(hash*33+text:byte(i))%4294967296 end
 assert(#text==spec.bytes and string.format('%08x',hash)==spec.hash,'unrelated stock UI safety source delta')
 return text
end
