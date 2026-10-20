local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local controllable={native=true,LuaWorkbench=true}
local function disabled(profile,id)
    return controllable[id] and type(profile.lua_editor_disabled)=='table' and profile.lua_editor_disabled[id]==true
end
-- This page alone uses aligned cards. The native form still owns pooling,
-- drawing leases, history and the ordinary Apply/Discard transaction.
local function columns(width)
    local control=96;local text=math.max(1,width-20-control-12)
    local name=math.floor(text*.35);local version=math.floor(text*.20)
    return name,version,text-name-version-12,control
end
local function displayName(value)
    return value:gsub('|','||'):gsub('[%z\1-\31\127]','?')
end
local function card(p,id,name,version,description,controls,options)
    local top,width,surface=p.y,p.width,p.surface
    local frame=p:Acquire('integrationCards',function()
        local c=CreateFrame('Frame',nil,p.child);c:EnableMouse(false)
        c.decoration=addon:CreateRoundedCardDecoration(c);c.decoration:SetColors(.35,.4,.44,.65,.08);return c
    end)
    frame:ClearAllPoints();frame:SetPoint('TOPLEFT',0,-top);frame:SetWidth(width)
    p.fields['integration_card_'..id]=frame
    p.surface=frame;p.width=width-20;p.y=10
    local nameWidth,versionWidth,descriptionWidth,controlWidth=columns(width)
    local height=54
    local function text(value,x,w)
        local t=p:Acquire('integrationLabels',function()local f=p.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');f:SetJustifyH('LEFT');f:SetJustifyV('TOP');return f end)
        t:ClearAllPoints();t:SetPoint('TOPLEFT',10+x,-10);t:SetWidth(math.max(1,w));t:SetWordWrap(true);t:SetText(value or '');t:SetTextColor(.9,.92,.94);t:SetHeight(0)
        local h=math.max(20,t:GetStringHeight());t:SetHeight(h);height=math.max(height,h+20)
    end
    text(name,0,nameWidth);text(version or L['Unknown'],nameWidth+6,versionWidth)
    text(description,nameWidth+versionWidth+12,descriptionWidth)
    if controls then controls(function(c,row)
        c:ClearAllPoints();c:SetPoint('TOPLEFT',width-controlWidth-10,-10-(row or 0)*28);c:SetWidth(controlWidth)
        if c.rmCheck then c:GetFontString():SetWidth(controlWidth-22) end
        height=math.max(height,38+(row or 0)*28)
    end)end
    p.y=height
    if options then
        -- Standard form fields use their existing local offsets inside the card.
        local body=p:Acquire('integrationOptions',function()local c=CreateFrame('Frame',nil,p.child);c:EnableMouse(false);return c end)
        body:ClearAllPoints();body:SetPoint('TOPLEFT',10,-height-6);body:SetWidth(p.width)
        p.surface=body;p.y=0;options();body:SetHeight(p.y);height=height+p.y+16
    end
    frame:SetHeight(height)
    p.surface=surface;p.width=width;p.y=top+height+10
    return frame
end
function addon:BuildIntegrationSettings(p)
    local profile=p:SettingsData().profile
    local inventory,byID=self.ListIntegrationStatus and self:ListIntegrationStatus() or {},{}
    for _,entry in ipairs(inventory)do byID[entry.id]=entry end
    local states={missing=L['Not loaded.'],loaded=L['Loaded; connection not confirmed.'],connected=L['Connected'],disabled=L['Disabled'],incompatible=L['Incompatible'],unknown=L['Unknown']}
    local function description(entry)return (states[entry.state] or L['Unknown'])..(entry.detail and '\n'..entry.detail or '')end
    local function title(text)
        p:Heading(text)
        local nameWidth,versionWidth,descriptionWidth,controlWidth=columns(p.width)
        local columns={{L['Addon'],10,nameWidth},{L['Version'],16+nameWidth,versionWidth},
            {L['Description / status'],22+nameWidth+versionWidth,descriptionWidth},{L['Enable / Select'],p.width-controlWidth-10,controlWidth}}
        local height=24
        for _,column in ipairs(columns)do
            local label=p:Acquire('integrationHeadings',function()return p.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')end)
            label:ClearAllPoints();label:SetPoint('TOPLEFT',column[2],-p.y);label:SetWidth(column[3]);label:SetWordWrap(true);label:SetJustifyH('LEFT');label:SetJustifyV('TOP');label:SetText(column[1]);label:SetHeight(0)
            local h=math.max(20,label:GetStringHeight());label:SetHeight(h);height=math.max(height,h+6)
        end
        p.y=p.y+height
    end
    local function setEnabled(id,value)
        if disabled(profile,profile.lua_editor)then profile.lua_editor='plain' end
        local map={};for key,on in pairs(profile.lua_editor_disabled or {})do map[key]=on end
        map[id]=not value or nil;profile.lua_editor_disabled=next(map) and map or nil
        if not value and profile.lua_editor==id then profile.lua_editor='plain' end
        p:Draw()
    end
    local function editor(id,name,available,entry)
        local selection=profile.lua_editor or 'auto'
        if disabled(profile,selection) then selection='plain' end
        local selected=selection==id
        local enabled=not disabled(profile,id)
        local status=available and (enabled and L['Enabled'] or L['Disabled']) or L['Unavailable']
        if entry then status=status..'\n'..(states[entry.state] or L['Unknown'])end
        if entry and entry.detail then status=status..'\n'..entry.detail end
        card(p,'editor_'..id,name,entry and entry.version or nil,status,function(place)
            if controllable[id] then
                local c=p:Check('integration_enable_'..id,L['Enabled'],enabled,function(value)
                    setEnabled(id,value)
                end);place(c,0)
            end
            local button=p:Button('integration_select_'..id,selected and L['Selected'] or L['Select'],function()
                if available and not disabled(profile,id)then profile.lua_editor=id;p:Draw()end
            end);place(button,controllable[id] and 1 or 0)
            if not available or not enabled or selected then button:Disable() end
        end)
    end
    p:Heading(L['Editor settings'])
    local selection=profile.lua_editor or 'auto';if disabled(profile,selection)then selection='plain' end
    for _,entry in ipairs({{'plain',L['None (plain editor)']},{'auto',L['Automatic']},{'native',L['Built In syntax highlighting']}})do
        local id,name=entry[1],entry[2]
        local button=p:Button('integration_select_'..id,(selection==id and L['Selected']..': ' or '')..name,function()
            if not disabled(profile,id)then profile.lua_editor=id;p:Draw()end
        end)
        if selection==id or disabled(profile,id)then button:Disable()end
    end
    p:Check('integration_enable_native',L['Enable built-in syntax highlighting'],not disabled(profile,'native'),function(value)setEnabled('native',value)end)
    p:Check('lua_line_numbers',L['Show line numbers'],profile.lua_line_numbers~=false,function(value)profile.lua_line_numbers=value end)
    p:Text(L['Baseline plain editor; always available.'])
    p:Text(L['Automatic uses an enabled available provider, then enabled built-in highlighting, otherwise None (plain editor).'])
    p:Text(L['Line-number visibility applies to every condition and function code editor.'])
    p:Text(L['Apply changes the editor used the next time a source editor opens. Enable an editor before selecting it.'])
    title(L['Lua editor integrations'])
    local entries=self:ListLuaEditorProviders();local found={}
    for _,entry in ipairs(entries)do if entry.value~='auto' and entry.value~='plain' and entry.value~='native' then
        found[entry.value]=true
        local available=entry.value~='LuaWorkbench' or self.IsLuaWorkbenchIntegrationAvailable and self:IsLuaWorkbenchIntegrationAvailable()==true
        editor(entry.value,displayName(entry.text),available==true,entry.value=='LuaWorkbench' and byID['!!!LuaWorkbench'] or nil)
    end end
    if not found.LuaWorkbench then editor('LuaWorkbench',L['LuaWorkbench'],false,byID['!!!LuaWorkbench']) end
    local wow=byID.WowLua;if wow then card(p,wow.id,wow.name,wow.version,description(wow)) end
    local function passiveGroup(name,ids)
        title(name);for _,id in ipairs(ids)do local entry=byID[id];if entry then card(p,id,entry.name,entry.version,description(entry))end end
    end
    passiveGroup(L['Condition data'],{'ExtendedCharacterStats','MobInfo2'})
    passiveGroup(L['Recommendation notifications'],{'WeakAuras'})
    title(L['Quest callbacks'])
    local questie=byID.Questie or {id='Questie',name=L['Questie'],state='unknown'}
    card(p,'Questie',questie.name,questie.version,description(questie),function(place)
        place(p:Check('questie_enabled',L['Enabled'],profile.questie_enabled==true,function(value)
            profile.questie_enabled=value;p:RunSettingsEffect('questie',function()self:SyncQuestieIntegration()end)
        end))
    end,function()
        local status=self.GetQuestieIntegrationStatus and self:GetQuestieIntegrationStatus() or {state='unavailable'}
        local labels={disabled=L['Disabled'],missing=L['Not loaded.'],waiting=L['Waiting for Questie.'],incompatible=L['Questie API incompatible.'],available=L['Questie callback connection available.'],['client-restricted']=L['Questie values are restricted by this client.'],error=L['Questie integration unavailable after an adapter error.'],unavailable=L['Questie adapter unavailable.']}
        p:Text(labels[status.state] or L['Questie adapter unavailable.'])
        if status.version then p:Text(string.format(L['Questie version: %s (%s)'],status.version:gsub('|','||'),status.versionStatus=='source-tested' and L['source-tested'] or L['unverified']))end
        if status.family then p:Text(string.format(L['Client family: %s (%s)'],status.family,status.familyContract=='declared-unverified' and L['declared; unverified'] or L['unsupported']))end
        p:Text(L['Native acceptance: unverified. Coverage: recent update receipts only; no quest progress, completion or rotation selection.'])
        p:Text(L['Questie is optional and disabled by default. Apply saves this profile preference. No background polling is used.'])
        p:Button('questie_refresh',L['Refresh Questie status'],function()self:RefreshQuestieIntegration();p:Draw()end)
    end)
    passiveGroup(L['Action bars'],{'ElvUI','Bartender4','ButtonForge','G15Buttons','SyncUI','LUI','Dominos','DiabolicUI','AzeriteUI','Neuron','FarmingBar','TotemTimers','SamyTotemTimers'})
    p:Text(L['Supported addons are listed even when missing. Loaded addons are only marked connected when their integration is available.'])
end
