-- Strict additive Masque inverse. The complete pre-feature bytes and the
-- complete reconstructed successor are checked before older frozen proofs.
local records={}
records["UI/settings_integrations.lua"]={old=[====[
local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function disabled(profile,id)
    return type(profile.lua_editor_disabled)=='table' and profile.lua_editor_disabled[id]==true
end
local function highlighting(profile)
    if profile.lua_native_highlighting~=nil then return profile.lua_native_highlighting==true end
    return profile.lua_editor~='plain'
end
local function safeName(value)return value:gsub('|','||'):gsub('[%z\1-\31\127]','?')end
local versionStates={loaded=true,connected=true,disabled=true,incompatible=true}
local function versionFor(entry)
    if entry then
        local loaded=entry.loaded
        if loaded==true or loaded==nil and versionStates[entry.state]then return entry.version or''end
    end
    return''
end
local colors={missing={.48,.48,.48},supported={.25,.55,.9},disabled={.85,.25,.25},enabled={.25,.7,.35},selected={1,.8,.2}}
function addon:BuildIntegrationSettings(p)
    local profile=p:SettingsData().profile;local token=p.generation
    local function current()
        return p:Valid(token) and (not p.transactionKeys or p.draft and p.draft.profile==profile)
    end
    -- Compatibility is a cold page snapshot; failures retain the unknown entry.
    local client
    local ok,value=pcall(function()
        local platform=self.Platform;if not current()then return end
        local get=platform and platform.GetClientInfo;if not current()then return end
        if type(get)=='function'then return get(platform)end
    end)
    if not current()then return end
    if ok then client=value end
    local function supported(id)
        local success,state=pcall(function()
            local check=self.GetIntegrationClientSupport;if not current()then return end
            if type(check)=='function'then return check(self,id,client)end
        end)
        if not current()then return end
        return not(success and state=='unsupported')
    end
    local function editors()
        local list=self.ListLuaEditorProviders;if not current()or type(list)~='function'then return end
        local entries=list(self);if not current()then return end
        local rows,byID={},{}
        for _,entry in ipairs(entries)do
            local id=entry.value
            local allowed=supported(id=='LuaWorkbench'and'!!!LuaWorkbench'or id);if not current()then return end
            if allowed and id~='auto' and id~='plain' and id~='native' then
                local available=true
                if id=='LuaWorkbench'then
                    local check=self.IsLuaWorkbenchIntegrationAvailable;if not current()then return end
                    available=type(check)=='function'and check(self)==true
                end
                if not current()then return end
                if not byID[id]then local row={id=id,name=safeName(entry.text),available=available==true};rows[#rows+1]=row;byID[id]=row end
            end
        end
        table.sort(rows,function(a,b)return a.id<b.id end)
        local workbenchAllowed=supported('!!!LuaWorkbench');if not current()then return end
        if workbenchAllowed and not byID.LuaWorkbench then local row={id='LuaWorkbench',name=L['LuaWorkbench'],available=false};rows[#rows+1]=row;byID.LuaWorkbench=row end
        local native={id='native',name=L['Native'],available=true};byID.native=native
        return rows,byID,native
    end
    local function effective(rows,byID)
        local selected=profile.lua_editor or'auto'
        if selected=='auto'then
            for _,row in ipairs(rows)do if row.available and not disabled(profile,row.id)then return row.id end end
        elseif selected~='native'and selected~='plain' then
            local row=byID[selected];if row and row.available and not disabled(profile,selected)then return selected end
        end
        if not disabled(profile,'native')then return'native'end
    end
    local function rememberHighlight(value)
        if profile.lua_native_highlighting==nil then profile.lua_native_highlighting=value end
    end
    local function selection(id,value)return id=='native'and(value and'native'or'plain')or id end
    local function mapWith(id,value)
        local map,n={},0
        for key,on in pairs(profile.lua_editor_disabled or{})do if on==true then map[key]=true;n=n+1 end end
        if value and not map[id]then n=n+1 end
        if n>64 then p:Message(L['Unavailable']);return end
        map[id]=value or nil;return map
    end
    local function choose(id)
        local rows,byID=editors();if not rows or not current()then return end
        local row=byID[id];if not row or not row.available or disabled(profile,id)then return end
        local value=highlighting(profile);rememberHighlight(value);profile.lua_editor=selection(id,value);p:Draw()
    end
    local function enable(id)
        local rows,byID=editors();if not rows or not current()then return end
        local row=byID[id];if not row or not row.available or not disabled(profile,id)then return end
        local selected=effective(rows,byID);local value=highlighting(profile);local map=mapWith(id,false);if not map then return end
        profile.lua_editor_disabled=next(map)and map or nil
        if not selected then rememberHighlight(value);profile.lua_editor=selection(id,value)end
        p:Draw()
    end
    local function disable(id,replacement,wasSelected)
        local rows,byID=editors();if not rows or not current()then return end
        local row=byID[id];if not row or not row.available or disabled(profile,id)then return end
        local selected=effective(rows,byID)
        if wasSelected and selected~=id or not wasSelected and selected==id then return end
        if replacement then
            local target=byID[replacement]
            if not target or replacement==id or not target.available or disabled(profile,replacement)then return end
        elseif wasSelected then
            -- A new enabled alternative requires a fresh explicit handoff choice.
            for other,target in pairs(byID)do if other~=id and target.available and not disabled(profile,other)then return end end
        end
        local value=highlighting(profile);local map=mapWith(id,true);if not map then return end
        rememberHighlight(value);profile.lua_editor_disabled=map
        if wasSelected then profile.lua_editor=replacement and selection(replacement,value)or'plain'end
        p:Draw()
    end
    local function editorAction(id,anchor)
        local rows,byID=editors();if not rows or not current()then return end
        local row=byID[id];if not row or not row.available then return end
        if disabled(profile,id)then enable(id);return end
        local selected=effective(rows,byID)
        if selected~=id then
            p:ShowChoices(anchor,{{value='disable',text=L['Disable']},{value='select',text=L['Select']}},function(value)
                if value=='disable'then disable(id,nil,false)elseif value=='select'then choose(id)end
            end,true)
            return
        end
        local alternatives={}
        for other,target in pairs(byID)do if other~=id and target.available and not disabled(profile,other)then alternatives[#alternatives+1]={value=other,text=target.name}end end
        table.sort(alternatives,function(a,b)return a.value<b.value end)
        if #alternatives==0 then disable(id,nil,true)
        elseif #alternatives==1 then disable(id,alternatives[1].value,true)
        else p:ShowChoices(anchor,alternatives,function(other)disable(id,other,true)end,true)end
    end
    local function inventoryRows()
        local list=self.ListIntegrationStatus;if not current()then return end
        local result=type(list)=='function'and list(self)or{}
        if current()then return result end
    end
    local rows,byID,native=editors();if not rows or not current()then return end
    local inventory=inventoryRows();if not inventory then return end
    local metadata={};for _,entry in ipairs(inventory)do
        local allowed=supported(entry.id);if not current()then return end
        if allowed then metadata[entry.id]=entry end
    end
    local selected=effective(rows,byID)
    local function editorRow(row)
        local entry=metadata[row.id=='LuaWorkbench'and'!!!LuaWorkbench'or row.id]
        return {id='editor_'..row.id,name=row.name,version=row.id=='native'and''or versionFor(entry),
            description=row.id=='native'and L['Built-in Lua editor.']or entry and entry.detail or L['Registered Lua editor provider.'],
            state=not row.available and'missing'or disabled(profile,row.id)and'disabled'or selected==row.id and'selected'or'enabled',
            action=row.available and function(anchor)editorAction(row.id,anchor)end or nil,
            entry=entry,help=row.id=='native'and'Help.Integrations.native_highlighting'or nil,native=row.id=='native'}
    end
    local editorRows={editorRow(native)};local found={}
    for _,row in ipairs(rows)do editorRows[#editorRows+1]=editorRow(row);found[row.id]=true end
    local function readonly(entry)
        return{id=entry.id,name=entry.name,version=versionFor(entry),description=entry.detail or'',state=(entry.state=='missing'or entry.state=='unknown')and'missing'or'supported',entry=entry}
    end
    if metadata.WowLua and not found.WowLua then editorRows[#editorRows+1]=readonly(metadata.WowLua)end
    local groups={{key='integrations_editors',title=L['Lua editor integrations'],rows=editorRows,editorSettings=true}}
    local function group(key,title,ids)
        local list={};for _,id in ipairs(ids)do if metadata[id]then list[#list+1]=readonly(metadata[id])end end
        groups[#groups+1]={key=key,title=title,rows=list}
    end
    group('integrations_conditions',L['Condition data'],{'ExtendedCharacterStats','MobInfo2'})
    group('integrations_notifications',L['Recommendation notifications'],{'WeakAuras'})
    local questieAllowed=supported('Questie');if not current()then return end
    if questieAllowed then
        local questie=metadata.Questie or{id='Questie',name=L['Questie'],state='missing'}
        local questieRow=readonly(questie)
        if questieRow.state~='missing'then
            questieRow.state=profile.questie_enabled==true and'enabled'or'disabled'
            questieRow.action=function()
                if not supported('Questie')or not current()then return end
                local fresh=inventoryRows();if not fresh then return end
                local loaded=false;for _,entry in ipairs(fresh)do if entry.id=='Questie'then loaded=entry.state~='missing'and entry.state~='unknown'end end
                if not loaded then return end
                profile.questie_enabled=not(profile.questie_enabled==true)
                p:RunSettingsEffect('questie',function()self:SyncQuestieIntegration()end);p:Draw()
            end
        end
        groups[#groups+1]={key='integrations_quests',title=L['Quest callbacks'],rows={questieRow}}
    end
    group('integrations_actionbars',L['Action bars'],{'ElvUI','Bartender4','ButtonForge','G15Buttons','SyncUI','LUI','Dominos','DiabolicUI','AzeriteUI','Neuron','FarmingBar','TotemTimers','SamyTotemTimers'})
    -- Measure shared columns once per drawing; description receives the remainder.
    p.width=math.max(340,p.frame:GetWidth()-40);p.child:SetWidth(p.width)
    local measure=p:Acquire('integrationMeasure',function()return p.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')end)
    measure:SetWordWrap(false);measure:SetWidth(0)
    local function width(text)measure:SetText(text or'');return measure:GetStringWidth()end
    local labels={missing=L['Not loaded'],supported=L['Supported'],disabled=L['Disabled'],enabled=L['Enabled'],selected=L['Selected']}
    local nameWidth,versionWidth,statusWidth=width(L['Addon'])+24,width(L['Version']),width(L['Status'])+16
    for _,label in pairs(labels)do statusWidth=math.max(statusWidth,width(label)+18)end
    for _,section in ipairs(groups)do for _,row in ipairs(section.rows)do nameWidth=math.max(nameWidth,width(row.name)+24);versionWidth=math.max(versionWidth,width(row.version))end end
    measure:SetText('');measure:Hide()
    local usable=p.width-20;local gap=8
    statusWidth=math.min(statusWidth,usable*.28);nameWidth=math.min(nameWidth,usable*.30);versionWidth=math.min(versionWidth,usable*.16)
    local descWidth=usable-nameWidth-versionWidth-statusWidth-gap*3
    local positions={10,10+nameWidth+gap,10+nameWidth+versionWidth+gap*2,p.width-10-statusWidth}
    local widths={nameWidth,versionWidth,descWidth,statusWidth}
    local function label(kind,parent,text,x,y,w)
        local c=p:Acquire(kind,function()local f=p.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');f:SetJustifyH('LEFT');f:SetJustifyV('TOP');return f end)
        c:SetParent(parent);c:ClearAllPoints();c:SetPoint('TOPLEFT',x,-y);c:SetWidth(math.max(1,w));c:SetWordWrap(true);if c.SetNonSpaceWrap then c:SetNonSpaceWrap(true)end;if c.SetMaxLines then c:SetMaxLines(0)end;c:SetText(text or'');c:SetTextColor(.9,.92,.94);c:SetHeight(0);c:SetHeight(math.max(18,c:GetStringHeight()));return c
    end
    local function draw(row)
        local top=p.y
        local frame=p:Acquire('integrationCards',function()local c=CreateFrame('Frame',nil,p.child);c:EnableMouse(false);c.decoration=addon:CreateRoundedCardDecoration(c);c.decoration:SetColors(.35,.4,.44,.65,.08);return c end)
        frame:ClearAllPoints();frame:SetPoint('TOPLEFT',0,-top);frame:SetWidth(p.width);p.fields['integration_card_'..row.id]=frame
        local name=p:Acquire('integrationNames',function()return addon:CreateWorkbenchButton(p.child,'',nameWidth-24)end)
        name:SetParent(frame);name:ClearAllPoints();name:SetPoint('TOPLEFT',positions[1],-10);name:SetWidth(math.max(1,nameWidth-24));name.art:Hide();name:SetText(row.name)
        local caption=name:GetFontString();caption:ClearAllPoints();caption:SetPoint('TOPLEFT');caption:SetWidth(math.max(1,nameWidth-24));caption:SetJustifyH('LEFT');caption:SetJustifyV('TOP');caption:SetWordWrap(true)
        name:SetHeight(math.max(18,caption:GetStringHeight()));name:Disable();name:SetAlpha(1);caption:SetTextColor(.9,.92,.94);addon:SetUIScript(name,'OnClick',nil)
        p.fields['integration_name_'..row.id]=name
        if row.entry and type(row.entry.projectURL)=='string'and row.entry.projectURL~=''then
            local id=row.entry.id;name:Enable();caption:SetTextColor(.35,.7,1)
            addon:SetUIScript(name,'OnClick',p:Guard(function()
                local show=self.ShowIntegrationProjectLink
                if current()and type(show)=='function'then show(self,id)end
            end))
        end
        local version=label('integrationLabels',frame,row.version or'',positions[2],10,versionWidth)
        local description=label('integrationLabels',frame,row.description,positions[3],10,descWidth)
        local pill=p:Acquire('integrationPills',function()return addon:CreateWorkbenchPill(p.child,'',statusWidth)end)
        pill:SetParent(frame);pill:ClearAllPoints();pill:SetPoint('TOPLEFT',positions[4],-10);pill:SetWidth(statusWidth);pill:SetText(labels[row.state]);pill:Enable()
        local color=colors[row.state];pill:SetAccent(color[1],color[2],color[3]);pill:SetSelected(true)
        p.fields['integration_status_'..row.id]=pill
        addon:SetUIScript(pill,'OnClick',row.action and p:Guard(function()if p:FlushEdits()and current()then row.action(pill)end end)or nil)
        if not row.action then pill:Disable();pill:SetAlpha(1)end
        local height=math.max(38,name:GetHeight()+20,version:GetHeight()+20,description:GetHeight()+20)
        local contentTop=height
        if row.help then
            local help=p:Acquire('integrationHelp',function()return addon:CreateWorkbenchHelpButton(p.child,L['Help'])end)
            help:SetParent(frame);help:ClearAllPoints();help:SetSize(20,20);help.icon:SetSize(18,18);help:SetPoint('TOPLEFT',positions[4]+statusWidth-20,-(row.native and contentTop or 10+pill:GetHeight()+6));help:Enable();p.fields['integration_help_'..row.id]=help
            addon:SetUIScript(help,'OnClick',p:Guard(function()
                local show=self.ShowWorkbenchHelp
                if current()and type(show)=='function'then show(self,row.name,{{title=row.name,text=L[row.help]}},p.frame)end
            end))
            height=math.max(height,(row.native and contentTop or 10+pill:GetHeight()+6)+20+6)
        end
        if row.native then
            local surface,available=p.surface,p.width;p.surface=frame;p.width=available-20-(row.help and 28 or 0);p.y=contentTop
            local syntax=p:Check('lua_native_highlighting',L['Syntax highlighting'],highlighting(profile),function(value)
                local liveRows,liveByID=editors();if not liveRows or not current()then return end
                local active=effective(liveRows,liveByID);profile.lua_native_highlighting=value==true
                if active=='native'then profile.lua_editor=value and'native'or'plain'end;p:Draw()
            end)
            syntax:ClearAllPoints();syntax:SetPoint('TOPLEFT',10,-contentTop)
            height=math.max(height,contentTop+34);p.surface=surface;p.width=available
        end
        frame:SetHeight(height);p.y=top+height+10
    end
    for _,section in ipairs(groups)do if #section.rows>0 then
        p:Section(section.key,section.title,function()
            if section.editorSettings then
                p:Check('lua_line_numbers',L['Show line numbers'],profile.lua_line_numbers~=false,function(value)profile.lua_line_numbers=value end)
            end
            local height=22
            for i,text in ipairs({L['Addon'],L['Version'],L['Description'],L['Status']})do local c=label('integrationHeadings',p.child,text,positions[i],p.y,widths[i]);height=math.max(height,c:GetHeight()+6)end
            p.y=p.y+height
            for _,row in ipairs(section.rows)do draw(row)end
        end)
    end end
end
]====],changes={
{10914,10913,[====[
local masqueAllowed=supported('Masque');if not current()then return end
    if masqueAllowed then
        local entry=metadata.Masque or{id='Masque',name=L['Masque'],state='missing'}
        local row=readonly(entry)
        local enabled=profile.preview_masque==true
        local loaded=entry.loaded==true or entry.loaded==nil and entry.state~='missing'and entry.state~='unknown'
        row.state=not loaded and'missing'or enabled and'enabled'or'disabled'
        if row.state~='missing'or enabled then
            row.action=function()
                if not supported('Masque')or not current()then return end
                profile.preview_masque=not(profile.preview_masque==true)
                p:RunSettingsEffect('preview_masque',function()self:RefreshPreviewWindow()end);p:Draw()
            end
        end
        groups[#groups+1]={key='integrations_preview',title=L['Preview appearance'],rows={row}}
    end
    ]====]},
}}
records["Core/profile_data.lua"]={old=[====[
local _,addon=...
local scalar={rotationFallbackID='string',lua_editor='string',lua_native_highlighting='boolean',lua_line_numbers='boolean',questie_enabled='boolean',version='number',enable='boolean',poll='number',ignore_mana='boolean',ignore_range='boolean',effect='string',magnification='number',setpoint='string',xoffs='number',yoffs='number',loglevel='number',detailed_profiling='boolean',disable_autoswitch='boolean',live_config_update='number',spell_history='number',combat_history='number',damage_history='number',disable_buttons='boolean',rotation_view='string',preview_spells='number',preview_vertical='boolean',preview_locked='boolean',preview_opacity='number',preview_icon_size='number'}
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
-- Reject malformed optional stock before generic recursive profile copying.
local function validStockTargets(addon,profile)
    if type(profile)~='table' then return true end
    local plan=rawget(profile,'stockTargets')
    return plan==nil or addon.StockTargets.Validate(plan)==true
end
function addon:ValidateProfileTransfer(value)
    if type(value)~='table' then return false end
    if not validStockTargets(self,value) then return false end
    local wire=self:ProfileToPortable(value);if not wire or not self.RotationData.CheckPortable(wire) then return false end
    local function stringValue(v) return type(v)=='string' end
    for key,item in pairs(value) do
        if scalar[key] then if type(item)~=scalar[key] then return false end
        elseif key=='rotationTagColors' then
            if type(item)~='table' then return false end;local count=0;for tag,color in pairs(item) do count=count+1;if count>4096 or not self.RotationData.NormalizeRotationTags({tag}) or tag~=tag:lower() or not fields(color,{r='number',g='number',b='number',a='number'}) then return false end;for _,channel in ipairs({'r','g','b','a'}) do local n=color[channel];if type(n)~='number' or n~=n or n<0 or n>1 then return false end end end
        elseif key=='color' then if not fields(item,{r='number',g='number',b='number',a='number'}) then return false end;for _,v in pairs(item) do if v<0 or v>1 then return false end end
        elseif key=='preview_window' then if not fields(item,{point='string',relpoint='string',xoffs='number',yoffs='number'}) then return false end
        elseif key=='minimap' then if not fields(item,{hide='boolean',minimapPos='number',radius='number',lock='boolean',showInCompartment='boolean'}) then return false end
        elseif key=='switch_conditions' or key=='disabled_conditions' or key=='other_conditions_order' then if not dense(item,stringValue) then return false end
        elseif key=='condition_groups' then
            if not dense(item,function(group) return type(group)=='table' and fields(group,{id='string',name='string',conditions='table',icon=type(group.icon)}) and type(group.id)=='string' and type(group.name)=='string' and dense(group.conditions,stringValue) and (group.icon==nil or self:IsCategoryIcon(group.icon)) end) then return false end
        elseif key=='announces' then local seen={};if not dense(item,function(v) if not self:IsValidAnnouncement(v,true) or seen[v.id] then return false end;seen[v.id]=true;return true end) then return false end
        elseif key=='lua_editor_disabled' then
            if type(item)~='table' or getmetatable(item)~=nil then return false end
            local count=0
            for name,disabled in pairs(item) do
                count=count+1
                if count>64 or type(name)~='string' or #name>128 or not name:find('%S') or name=='auto' or name=='plain' or disabled~=true then return false end
            end
        elseif key=='stockTargets' then
            -- Closed optional schema was checked before copying the profile.
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
                if field=='preferences' then for id,preference in pairs(rows) do if type(id)~='string' or not fields(preference,{enabled='boolean'}) then return false end end
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
    if value.rotation_view~=nil and value.rotation_view~='diagram' and value.rotation_view~='list' then return false end
    if value.preview_spells~=nil and (value.preview_spells<0 or value.preview_spells>5 or value.preview_spells%1~=0) then return false end
    if value.preview_opacity~=nil and (value.preview_opacity<0 or value.preview_opacity>1) then return false end
    if value.preview_icon_size~=nil and (value.preview_icon_size<24 or value.preview_icon_size>160) then return false end
    if value.poll~=nil and (value.poll<.01 or value.poll>5) then return false end
    if value.magnification~=nil and (value.magnification<.1 or value.magnification>10) then return false end
    for _,key in ipairs({'live_config_update','spell_history','combat_history','damage_history'}) do if value[key]~=nil and value[key]<0 then return false end end
    return true
end
-- Profile specialization maps include spec 0. The shared rotation transport
-- intentionally accepts only positive numeric table keys, so profile wire maps
-- use canonical decimal strings and restore numbers only in these namespaces.
function addon:ProfileToPortable(profile)
    if not validStockTargets(self,profile) then return nil end
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
    if not validStockTargets(self,profile) then return nil end
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
]====],changes={
{157,156,[====[
='boolean',preview_masque]====]},
}}
records["UI/settings_collections.lua"]={old=[====[
local addon_name,addon=...
local invalidateDependencies=addon.InvalidateRotationDependencies
if type(invalidateDependencies)~='function' then invalidateDependencies=nil end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:SettingsEntries(values)
    local entries={};for id,value in pairs(values or {}) do if type(value)=='table' then entries[#entries+1]={value=id,text=type(value.name)=='string' and value.name or tostring(id)} end end
    table.sort(entries,function(a,b) if a.text==b.text then return tostring(a.value)<tostring(b.value) end;return a.text<b.text end);return entries
end
function addon:SettingsNonempty(text) if type(text)=='string' and text:find('%S') then return text end end
function addon:SettingsPositiveID(text) local n=tonumber(text);if n and n>0 and n==math.floor(n) then return n end end
function addon:SettingsFlag(list,value,enabled)
    for i=#list,1,-1 do if list[i]==value then table.remove(list,i) end end
    if enabled then list[#list+1]=value end
end
function addon:SettingsContains(list,value) for _,entry in ipairs(list or {}) do if entry==value then return true end end;return false end
function addon:SettingsOrderControls(p,prefix,list,i,changed)
    local function move(destination) local value=table.remove(list,i);table.insert(list,destination,value);changed();p:Draw() end
    p:Actions({{key=prefix..'top',text=L['Move to Top'],icon='chevron-double-down',enabled=i>1,action=function() move(1) end},
        {key=prefix..'up',text=L['Move Up'],icon='up',enabled=i>1,action=function() move(i-1) end},
        {key=prefix..'down',text=L['Move Down'],icon='down',enabled=i<#list,action=function() move(i+1) end},
        {key=prefix..'bottom',text=L['Move to Bottom'],icon='chevron-double-down',enabled=i<#list,action=function() move(#list) end},
        {key=prefix..'remove',text=L['Delete'],icon='trash',action=function() table.remove(list,i);changed();p:Draw() end}})
end
function addon:OpenNativeSettings(parent,key,cached)
    local builders={General=self.BuildGeneralSettings,Profiles=self.BuildProfileSettings,About=self.BuildAboutSettings,
        Announces=self.BuildAnnounceSettings,Effects=self.BuildEffectSettings,ItemSets=self.BuildItemSettings,Conditions=self.BuildConditionSettings,Functions=self.BuildFunctionSettings,Integrations=self.BuildIntegrationSettings}
    local build=builders[key];if not build then return end
    local p=cached or self:CreateSettingsForm(parent)
    local scopes={Integrations={profile={'lua_editor','lua_editor_disabled','lua_native_highlighting','lua_line_numbers','questie_enabled'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
    scopes.Functions={global={'custom_functions'}}
    p.settingsKey=key;p.historyEnabled=key=='ItemSets';p.transactionKeys=scopes[key];p:SetWidth(parent:GetWidth());p:SetHeight(parent:GetHeight());p:Open(function(form) build(self,form) end);return p
end

function addon:CollectionFooter(p,kind,values,current,duplicate,transfer,compare)
    local candidates={};for _,entry in ipairs(self:SettingsEntries(values)) do if entry.value~=current then candidates[#candidates+1]=entry end end
    p:SetRosterActions({{key='new_collection',text=L['New'],icon='plus',action=p.roster.options.new},duplicate,transfer,
        {key='compare',text=L['Compare'],icon='compare',enabled=values[current]~=nil and #candidates>0,action=function()
            p:ShowChoices(p.fields.compare,candidates,function(id) p.fields.compare:SetText(L['Compare']);if id~=current and values[id] and values[current] then if compare then compare(values[current],values[id]) else self:ShowCollectionComparison(p,kind,values[current],values[id]) end end end)
        end}})
end
function addon:SettingsTopDelete(p,action)
    local c=p:Acquire('rootDelete',function() return self:CreateWorkbenchIconButton(p.child,'trash',L['Delete']) end);c:ClearAllPoints();c:SetPoint('TOPRIGHT',0,-4);c.icon:SetVertexColor(1,.25,.25,1);c:Enable();p.fields.delete=c
    self:SetUIScript(c,'OnClick',p:Guard(action));return c
end

-- Deletion is a separate confirmed operation. Resolve existing edits first,
-- then rebuild and read saved data so Apply/Discard cannot leave stale drafts.
function addon:ConfirmSettingsDeletion(p,warning,remove)
    local profile,global,char=self.db.profile,self.db.global,self.db.char
    p:RequestLeave(function()
        if not p.active or self.db.profile~=profile or self.db.global~=global or self.db.char~=char then return end
        p:DiscardSettingsDraft();p:Draw()
        local stockUnrelated=p.settingsKey=='ItemSets'
        local function ownsKey(scope,key)return not (stockUnrelated and scope=='profile' and key=='stockTargets')end
        local expected={};for scope,keys in pairs(p.transactionKeys or {}) do expected[scope]={};for _,key in ipairs(keys) do if ownsKey(scope,key) then expected[scope][key]=self:CopySettingsData(self.db[scope] and self.db[scope][key]) end end end
        local conditionRevision,functionRevision=self.conditionRegistryVersion,self.functionRegistryVersion
        p:Confirm(warning..' '..L['This cannot be undone.'],function()
            if InCombatLockdown and InCombatLockdown() then p:Message(L['Leave combat before applying these settings.']);return end
            for scope,keys in pairs(p.transactionKeys or {}) do for _,key in ipairs(keys) do
                if ownsKey(scope,key) and not self:SettingsDataEqual(self.db[scope] and self.db[scope][key],expected[scope][key]) then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            end end
            if self.conditionRegistryVersion~=conditionRevision or self.functionRegistryVersion~=functionRevision then p:Message(L['Settings changed elsewhere. Cancel to reload them before applying.']);return end
            local called,ok,why=pcall(remove)
            if not called or not ok then p:Message(tostring(called and why or ok));return end
            p:DiscardSettingsDraft();p.emptyDismissed=true;p:Draw()
            if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end
            if self.ButtonFetch then self:ButtonFetch() end
        end)
    end)
end
function addon:DeleteSavedCustomCondition(key)
    local source=(self.db.global.custom_conditions or {})[key]
    if not source then return false,'definition-changed' end
    -- Unregister can run trusted cleanup hooks. A failure must retain its saved
    -- source and registered definition, rather than leaving an orphaned runtime.
    local definition=self.conditionDefinitions and self.conditionDefinitions[key]
    local ok,why=pcall(self.UnregisterCondition,self,key)
    if not ok then if self.conditionDefinitions then local changed=not rawequal(self.conditionDefinitions[key],definition);self.conditionDefinitions[key]=definition;if changed and invalidateDependencies then invalidateDependencies(addon,'condition',key) end end;return false,why end
    self.db.global.custom_conditions[key]=nil
    if self.RefreshConditionConsumers then self:RefreshConditionConsumers() end
    return true
end
]====],changes={
{2593,2592,[====[
','preview_masque]====]},
}}
for _,record in pairs(records)do
 local source=record.old
 for _,change in ipairs(record.changes)do source=source:sub(1,change[1]-1)..change[3]..source:sub(change[2]+1)end
 record.new=source;record.changes=nil
end
return function(path,source)
 source=dofile('tests/fixtures/restore_catalog_cleanup.lua')(source,path)
 source=dofile('tests/fixtures/restore_bossmod_integration.lua')(source,path)
 if path=='Core/profile_data.lua'and source:find('local function validRotationChoices',1,true)then source=dofile('tests/fixtures/restore_rotation_choice_preferences.lua')(source,path)end
 source=dofile('tests/fixtures/restore_general_preview.lua')(path,source)
 local record=records[path]
 if not record or source==record.old then return source end
 assert(source==record.new,'Masque inverse requires exact complete successor: '..path)
 return record.old
end
