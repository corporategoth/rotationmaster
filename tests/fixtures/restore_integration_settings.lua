-- Exact four complete predecessors at c7377a3. No broad normalization.
local records = {}

records["UI/settings_integrations.lua"] = {
    old = [=[
local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:BuildIntegrationSettings(p)
    local profile=p:SettingsData().profile
    p:Heading(L['Lua editor'])
    local entries=self:ListLuaEditorProviders();local selected=profile.lua_editor or 'auto';local known=false
    for _,entry in ipairs(entries) do if entry.value==selected then known=true end end
    if not known then entries[#entries+1]={value=selected,text=selected..' ('..L['Unavailable']..')'} end
    p:Choice('lua_editor',L['Editor'],selected,entries,function(value) profile.lua_editor=value end)
    p:Check('lua_line_numbers',L['Show line numbers'],profile.lua_line_numbers~=false,function(value) profile.lua_line_numbers=value end)
    p:Text(L['Line-number visibility applies to every condition and function code editor.'])
    p:Text(L['Automatic uses an available editor integration, with built-in syntax highlighting as its fallback. Plain text disables highlighting. Apply changes the editor used the next time you open a custom condition.'])
    p:Heading(L['Questie'])
    p:Check('questie_enabled',L['Enable Questie integration'],profile.questie_enabled==true,function(value)
        profile.questie_enabled=value
        p:RunSettingsEffect('questie',function() self:SyncQuestieIntegration() end)
    end)
    local status=self.GetQuestieIntegrationStatus and self:GetQuestieIntegrationStatus() or {state='unavailable'}
    local states={disabled=L['Disabled'],missing=L['Not loaded.'],waiting=L['Waiting for Questie.'],
        incompatible=L['Questie API incompatible.'],available=L['Questie callback connection available.'],
        ['client-restricted']=L['Questie values are restricted by this client.'],
        error=L['Questie integration unavailable after an adapter error.'],unavailable=L['Questie adapter unavailable.']}
    p:Text(states[status.state] or L['Questie adapter unavailable.'])
    if status.version then
        p:Text(string.format(L['Questie version: %s (%s)'],status.version:gsub('|','||'),status.versionStatus=='source-tested' and L['source-tested'] or L['unverified']))
    end
    if status.family then
        p:Text(string.format(L['Client family: %s (%s)'],status.family,status.familyContract=='declared-unverified' and L['declared; unverified'] or L['unsupported']))
    end
    p:Text(L['Native acceptance: unverified. Coverage: recent update receipts only; no quest progress, completion or rotation selection.'])
    p:Text(L['Questie is optional and disabled by default. Apply saves this profile preference. No background polling is used.'])
    p:Button('questie_refresh',L['Refresh Questie status'],function() self:RefreshQuestieIntegration();p:Draw() end)
    p:Heading(L['Supported addons'])
    local inventoryStates={missing=L['Not loaded.'],loaded=L['Loaded; connection not confirmed.'],
        connected=L['Connected'],disabled=L['Disabled'],incompatible=L['Incompatible'],unknown=L['Unknown']}
    for _,entry in ipairs(self.ListIntegrationStatus and self:ListIntegrationStatus() or {}) do
        local label=entry.name
        if entry.version then label=string.format(L['%s (version %s)'],label,entry.version) end
        p:Text(string.format(L['%s: %s'],label,inventoryStates[entry.state] or L['Unknown']))
        if entry.detail then p:Text(entry.detail) end
    end
    p:Text(L['Supported addons are listed even when missing. Loaded addons are only marked connected when their integration is available.'])
end
]=],
    changes = {
        {
            1325,
            3339,
            [=[
    passiveGroup(L['Action bars'],{'ElvUI','Bartender4','ButtonForge','G15Buttons','SyncUI','LUI','Dominos','DiabolicUI','AzeriteUI','Neuron','FarmingBar','TotemTimers','SamyTotemTimers'})
]=],
        },
        {
            835,
            1315,
            [=[
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
]=],
        },
        {
            169,
            741,
            [=[
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
]=],
        },
        {
            83,
            82,
            [=[
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
]=],
        },
    },
}

records["UI/lua_editor.lua"] = {
    old = [=[
local addon_name,addon=...
local providers={}
function addon:ListLuaEditorProviders()
    if self.DiscoverLuaEditorIntegrations then self:DiscoverLuaEditorIntegrations() end
    local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
    local entries={{value='auto',text=L['Automatic']},{value='native',text=L['Built In syntax highlighting']},{value='plain',text=L['Plain text']}}
    local names={};for name in pairs(providers) do names[#names+1]=name end;table.sort(names)
    for _,name in ipairs(names) do entries[#entries+1]={value=name,text=name} end
    return entries
end
local function hideFrame(frame)
    pcall(function() if frame and type(frame.Hide)=='function' then frame:Hide() end end)
end
local function usableFrame(frame)
    local ok,result=pcall(function() return frame and type(frame.SetParent)=='function' and type(frame.SetAllPoints)=='function' and type(frame.Hide)=='function' end)
    return ok and result
end
-- Optional editor addons may register this RM-owned contract. No dependency or
-- undocumented third-party globals are required by the native fallback.
function addon:RegisterLuaEditorProvider(name,create)
    if type(name)~='string' or #name>128 or not name:find('%S') or name=='native' or name=='plain' or name=='auto' or type(create)~='function' then return false end
    providers[name]=create;return true
end
function addon:CreateWorkbenchLuaEditor(parent,changed,valid,preferred)
    if self.DiscoverLuaEditorIntegrations then self:DiscoverLuaEditorIntegrations() end
    preferred=preferred or self.db.profile.lua_editor or 'auto'
    if preferred=='auto' then
        local names={};for name in pairs(providers) do names[#names+1]=name end;table.sort(names);preferred=names[1] or 'native'
    end
    if preferred and providers[preferred] then
        local function setCallbacks(cell,callback,ownerValid)
            cell.changed,cell.valid=callback,ownerValid
            -- Preserve optional nil/false constructor arguments exactly.
            cell.change=type(callback)=='function' and cell.forwardChange or callback
            cell.check=type(ownerValid)=='function' and cell.forwardCheck or ownerValid
        end
        local function callbackLease(callback,ownerValid)
            local cell={active=true}
            cell.forwardChange=function(...) if cell.active and type(cell.changed)=='function' then return cell.changed(...) end end
            cell.forwardCheck=function(...) if cell.active and type(cell.valid)=='function' then return cell.valid(...) end;return false end
            setCallbacks(cell,callback,ownerValid);return cell
        end
        local function retire(cell) cell.active=false;cell.changed=nil;cell.valid=nil end
        local function usable(control)
            return type(control)=='table' and usableFrame(control.frame) and type(control.GetText)=='function'
                and type(control.SetText)=='function' and type(control.Release)=='function'
        end
        local function release(control)
            if type(control)=='table' then if type(control.Release)=='function' then pcall(control.Release,control) end;hideFrame(control.frame) end
        end
        local lease=callbackLease(changed,valid)
        local host=CreateFrame('Frame',nil,parent)
        local factory=providers[preferred]
        local ok,control,constructor=pcall(factory,host,lease.change,lease.check)
        if ok and type(control)=='table' and usable(control) then
            local c={frame=host,provider=preferred,inner=control,edit=control.edit,lastText='',factory=factory,constructor=constructor,preferredInner=control}
            local function fallback()
                local operation=c.operation
                retire(lease);release(c.inner)
                if c.operation~=operation or c.released then return end
                lease=callbackLease(changed,valid)
                local nextControl=c.fallbackInner
                if nextControl then nextControl:Acquire(lease.change,lease.check) else nextControl=addon:CreateWorkbenchLuaEditor(host,lease.change,lease.check,'native') end
                if c.operation~=operation or c.released then if nextControl~=c.inner then release(nextControl) end;return end
                c.fallbackInner=nextControl;c.inner=nextControl;c.provider='native';c.edit=nextControl.edit
                nextControl.frame:SetAllPoints(host);nextControl:SetText(c.lastText);nextControl:SetReadOnly(c.readOnly)
                if c.closeRequested then nextControl:SetCloseHandler(c.closeRequested) end
                if c.context then nextControl:SetContext(c.context) end
            end
            ---@return string
            function c:GetText()
                local operation=self.operation;local current=self.inner
                local read,text=pcall(current.GetText,current)
                if self.operation~=operation then return self.lastText end
                if not read or type(text)~='string' then fallback();text=self.inner:GetText() end
                self.lastText=text;return text
            end
            function c:SetContext(context)
                self.context=context;local operation=self.operation;local current=self.inner
                if current.SetContext and not pcall(current.SetContext,current,context) and self.operation==operation then fallback() end
            end
            function c:SetReadOnly(value)
                self.readOnly=value==true;local operation=self.operation;local current=self.inner
                if type(current.SetReadOnly)=='function' then
                    if not pcall(current.SetReadOnly,current,self.readOnly) and self.operation==operation then fallback() end
                elseif self.readOnly then fallback() end
            end
            function c:SetLineNumbers(visible)
                local operation=self.operation;local current=self.inner
                if current.SetLineNumbers and not pcall(current.SetLineNumbers,current,visible) and self.operation==operation then fallback() end
            end
            function c:SetCloseHandler(callback) self.closeRequested=callback;if self.inner.SetCloseHandler then self.inner:SetCloseHandler(callback) end end
            function c:SetText(text)
                self.lastText=text or '';local operation=self.operation;local current=self.inner
                if not pcall(current.SetText,current,self.lastText) and self.operation==operation then fallback() end
            end
            function c:Acquire(callback,ownerValid)
                if self.closing then error('editor-release-in-progress',0) end
                changed,valid=callback,ownerValid
                local operation={};self.operation=operation
                if not self.released then
                    setCallbacks(lease,changed,valid)
                    if type(self.inner.Acquire)=='function' then self.inner:Acquire(lease.change,lease.check) end
                    return
                end
                retire(lease);lease=callbackLease(changed,valid);self.released=false
                local previous=self.preferredInner
                local canReuse=preferred=='LuaWorkbench' and self.factory==providers[preferred] and type(self.constructor)=='function'
                    and rawget(addon,'CreateLuaWorkbenchControl')==self.constructor and type(previous.Acquire)=='function' and previous.provider=='LuaWorkbench'
                    and addon:IsLuaWorkbenchIntegrationAvailable()
                local created,nextControl,nextConstructor
                if canReuse then created=pcall(previous.Acquire,previous,lease.change,lease.check);nextControl=previous;nextConstructor=self.constructor
                else created,nextControl,nextConstructor=pcall(providers[preferred],host,lease.change,lease.check) end
                if self.operation~=operation then if created and nextControl~=self.inner then release(nextControl) end;return end
                if created and type(nextControl)=='table' and usable(nextControl) then
                    self.inner=nextControl;self.preferredInner=nextControl;self.constructor=nextConstructor;self.factory=providers[preferred]
                    self.provider=preferred;self.edit=nextControl.edit
                    local attached=pcall(function() nextControl.frame:SetParent(host);nextControl.frame:SetAllPoints(host) end)
                    if not attached then fallback() end
                else
                    if created then release(nextControl) end
                    fallback()
                end
                if self.operation~=operation or self.released then return end
                self:SetText(self.lastText);if self.operation~=operation then return end
                self:SetReadOnly(self.readOnly);if self.operation~=operation then return end
                if self.context then self:SetContext(self.context) end
                if self.operation==operation and not self.released then self.inner.frame:Show() end
            end
            function c:Release()
                if self.released then return end
                self.operation={};self.released=true;self.closing=true;retire(lease)
                changed=nil;valid=nil;self.closeRequested=nil;self.context=nil
                local read,text=pcall(self.inner.GetText,self.inner);if read and type(text)=='string' then self.lastText=text end
                release(self.inner);hideFrame(self.frame);self.closing=nil
            end
            local attached=pcall(function() control.frame:SetParent(host);control.frame:SetAllPoints(host) end)
            if not attached then fallback() end
            return c
        end
        retire(lease);if ok then release(control) end;host:Hide()
    end
    local c={frame=CreateFrame('Frame',nil,parent),provider='native',valid=valid,changed=changed}
    c.scroll=self:CreateWorkbenchScrollFrame(c.frame);c.scroll:SetPoint('TOPLEFT',4,-4);c.content=CreateFrame('Frame',nil,c.scroll);c.content:EnableMouse(false);c.scroll:SetScrollChild(c.content);c.edit=CreateFrame('EditBox',nil,c.content);c.edit:SetMultiLine(true);c.edit:SetAutoFocus(false);c.edit:EnableMouse(true);c.edit:SetAltArrowKeyMode(false);c.edit:SetBlinkSpeed(.5);c.edit:SetCountInvisibleLetters(false);c.edit:SetTextColor(1,1,1);c.edit:SetJustifyH('LEFT');c.edit:SetJustifyV('TOP');c.edit:SetFontObject('GameFontHighlightSmall');c.edit:SetTextInsets(6,6,4,4);c.edit:SetMaxLetters(0);c.edit:SetHeight(1);c.edit:SetPoint('TOPLEFT',c.content,'TOPLEFT',0,0)
    -- Let the native EditBox own mouse placement and keyboard navigation.
    -- Focusing it from the covering scroll frame resets placement to the end.
    c.scroll:EnableMouse(false);c.frame:EnableMouseWheel(true)
    -- Only the backing frame fills the viewport. A bottom anchor on the
    -- multiline input would constrain its native text height and caret layout.
    -- Blank-space clicks can focus short/empty text without replacing native
    -- mouse placement or moving an existing insertion point to the end.
    c.content:EnableMouse(true)
    addon:SetUIScript(c.content,'OnMouseDown',function(_,button)
        if button=='LeftButton' and not c.readOnly and not c.released and c.valid() then c.edit:SetFocus()
        elseif button=='RightButton' then local handler=c.edit:GetScript('OnMouseDown');if handler then handler(c.edit,button) end end
    end)
    addon:SetUIScript(c.frame,'OnMouseWheel',function(_,delta) c.scroll.workbenchBar:SetValue(c.scroll.workbenchBar:GetValue()-delta*36) end)
    c.editorDecoration=self:CreateRoundedCardDecoration(c.frame);c.editorDecoration:SetColors(.38,.43,.48,1,.95)
    addon:SetUIScript(c.edit,'OnEditFocusGained',function() c.editorDecoration:SetColors(.45,.7,.85,1,.95) end)
    addon:SetUIScript(c.edit,'OnEditFocusLost',function() c.editorDecoration:SetColors(.38,.43,.48,1,.95) end)
    c.measure=c.frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');c.measure:SetJustifyH('LEFT');c.measure:SetJustifyV('TOP');c.measure:SetWordWrap(true);c.measure:Hide()
    if c.edit.SetFont then c.edit:SetFont('Interface\\AddOns\\'..addon_name..'\\Fonts\\Inconsolata-Regular.ttf',12,'') end
    if c.measure.SetFont then c.measure:SetFont('Interface\\AddOns\\'..addon_name..'\\Fonts\\Inconsolata-Regular.ttf',12,'') end
    function c:Layout(origin)
        if self.layingOut then return end;self.layingOut=true
        self.layoutCounts=self.layoutCounts or {calls=0,width=0,content=0};self.layoutCounts.calls=self.layoutCounts.calls+1
        if origin~='set-text' and origin~='text-changed' and origin~='owner-size' and origin~='line-number-setting' then origin='direct' end
        local counts=self.layoutCounts;counts.origins=counts.origins or {};counts.origins[origin]=(counts.origins[origin] or 0)+1
        if origin=='owner-size' then counts.ownerWidth,counts.ownerHeight=self.frame:GetWidth(),self.frame:GetHeight() end
        -- Native coordinates round through effective UI scale. Rewriting an
        -- almost-identical size reflows EditBox text and can reset its caret.
        local function differs(current,wanted) return math.abs(current-wanted)>.1 end
        -- Keep incoming event counts while coalescing unchanged text geometry.
        -- Cursor and scrolling callbacks continue to own visible gutter updates.
        local frameWidth,frameHeight=self.frame:GetWidth(),self.frame:GetHeight()
        local scale,source=self.frame:GetEffectiveScale(),self:GetText()
        local font,size,flags,measureFont,measureSize,measureFlags
        if self.edit.GetFont then font,size,flags=self.edit:GetFont() end
        if self.measure.GetFont then measureFont,measureSize,measureFlags=self.measure:GetFont() end
        local spacing=self.edit.GetSpacing and self.edit:GetSpacing()
        local measureSpacing=self.measure.GetSpacing and self.measure:GetSpacing()
        local wanted=addon.db.profile.lua_line_numbers~=false
        local last=self.layoutInput
        if last and not differs(last.width,frameWidth) and not differs(last.height,frameHeight) and last.scale==scale and last.source==source
            and last.wanted==wanted and last.setting==self.lineNumberSetting and last.visible==self.lineNumbersVisible
            and last.font==font and last.size==size and last.flags==flags and last.spacing==spacing
            and last.measureFont==measureFont and last.measureSize==measureSize and last.measureFlags==measureFlags and last.measureSpacing==measureSpacing then
            counts.skips=(counts.skips or 0)+1;self.layingOut=nil;return
        end
        -- The shared track sits beyond the viewport. Reserve its space here,
        -- keeping both the text and the track within the editor card.
        if self.RefreshLineNumbers then self:RefreshLineNumbers() end
        local gutter=self.lineNumbersVisible and 56 or 0
        if self.lineNumberLayoutGutter~=gutter then self.lineNumberLayoutGutter=gutter;self.scroll:SetPoint('TOPLEFT',4+gutter,-4) end
        local scrollWidth=math.max(1,frameWidth-32-gutter);local width=scrollWidth;local height=math.max(1,frameHeight-8)
        if differs(self.scroll:GetWidth(),scrollWidth) or differs(self.scroll:GetHeight(),height) then self.scroll:SetSize(scrollWidth,height) end
        if differs(self.edit:GetWidth(),width) then self.layoutCounts.width=self.layoutCounts.width+1;self.edit:SetWidth(width) end
        -- Hover hit geometry gives this font a fixed height. Let it measure
        -- the complete new source before sizing the backing scroll child.
        self.measure:SetHeight(0);self.measure:SetWidth(math.max(1,width-12));self.measure:SetText(source);local editHeight=math.max(height,self.measure:GetStringHeight()+16)
        -- Multiline EditBoxes own their text height. Size a backing frame
        -- without a bottom anchor on the edit, preserving native text layout.
        if differs(self.content:GetWidth(),width) or differs(self.content:GetHeight(),editHeight) then self.layoutCounts.content=self.layoutCounts.content+1;self.content:SetSize(width,editHeight) end
        self.scroll:UpdateWorkbenchScroll();if self.RefreshLineNumbers then self:RefreshLineNumbers() end
        self.layoutInput={width=frameWidth,height=frameHeight,scale=scale,source=source,wanted=wanted,setting=self.lineNumberSetting,visible=self.lineNumbersVisible,
            font=font,size=size,flags=flags,spacing=spacing,measureFont=measureFont,measureSize=measureSize,measureFlags=measureFlags,measureSpacing=measureSpacing}
        self.layingOut=nil
    end
    ---@return string
    function c:GetText()
        -- FAIAP's cached GetText can lag a keystroke until its coloring update.
        -- Apply and callback switches must always read the current source.
        if self.syntax then local text=self.syntax.decode(self.nativeGetText(self.edit));return type(text)=='string' and text or '' end
        return self.edit:GetText() or ''
    end
    function c:SetText(text) self.setting=true;self.edit:SetText(text or '');self.readOnlyText=text or '';self.setting=false;self:Layout('set-text') end
    function c:SetContext(context) self.context=context;if self.UpdateSymbols then self:UpdateSymbols(context) end end
    function c:SetReadOnly(value) self.readOnly=value==true;self.readOnlyText=self:GetText();if self.readOnly then self.edit:ClearFocus();self.edit:Disable() else self.edit:Enable() end end
    function c:SetChanged(callback) self.changed=callback end
    function c:SetCloseHandler(callback) self.closeRequested=callback end
    function c:Acquire(callback,ownerValid)
        if self.closing then error('editor-release-in-progress',0) end
        self.changed,self.valid=callback,ownerValid
        if not self.released then return end
        if self.released then self.layingOut=nil end
        self.released=false;self.readOnly=false;self.readOnlyText=nil;self.changed=callback;self.valid=ownerValid;self.layoutCounts=nil;self.layoutInput=nil
        self.edit:Enable()
        if self.ResetInputTrace then addon.luaInputEditor=self;self:ResetInputTrace() end
        if self.syntax then pcall(self.syntax.enable,self.edit,self.syntaxColors,4) end
        if self.AcquireCompletion then self:AcquireCompletion() end
        if self.RefreshLineNumbers then self:RefreshLineNumbers() end
    end
    function c:Release()
        if self.released then return end
        self.released=true;self.closing=true;self.changed=nil;self.closeRequested=nil;self.context=nil;self.valid=function() return false end
        local failed,why
        local function attempt(callback,...)
            local ok,result=pcall(callback,...);if not ok and not failed then failed,why=true,result end
        end
        if self.ReleaseLineNumbers then attempt(self.ReleaseLineNumbers,self) end
        if self.ReleaseCompletion then attempt(self.ReleaseCompletion,self) end
        attempt(self.edit.ClearFocus,self.edit)
        if self.syntax then pcall(self.syntax.disable,self.edit) end
        self.edit.GetText=self.nativeGetText;self.edit.SetText=self.nativeSetText
        for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do attempt(self.edit.SetScript,self.edit,event,self.nativeScripts[event]) end
        attempt(self.edit.SetText,self.edit,'');attempt(self.measure.SetText,self.measure,'');attempt(self.frame.Hide,self.frame)
        self.layoutInput=nil;self.readOnlyText=nil
        self.closing=nil;if failed then error(why,0) end
    end
    addon:SetUIScript(c.edit,'OnTextChanged',function() if c.released then return end;if c.readOnly and not c.setting and c:GetText()~=c.readOnlyText then c:SetText(c.readOnlyText);return end;c:Layout('text-changed');if not c.setting and not c.released and c.valid() and c.changed then c.changed(c:GetText()) end end)
    addon:SetUIScript(c.frame,'OnSizeChanged',function() c:Layout('owner-size') end)
    addon:SetUIScript(c.edit,'OnMouseWheel',function(_,delta) c.scroll.workbenchBar:SetValue(c.scroll.workbenchBar:GetValue()-delta*36) end);c.edit:EnableMouseWheel(true)
    addon:SetUIScript(c.edit,'OnCursorChanged',function(_,_,y,_,height) local bar=c.scroll.workbenchBar;local top=-y;if top<bar:GetValue() then bar:SetValue(top) elseif top+height>bar:GetValue()+c.scroll:GetHeight() then bar:SetValue(top+height-c.scroll:GetHeight()) end end)
    local function closeEditor(mouse)
        if c.released or not c.valid() then return end
        c.edit:ClearFocus();if c.closeRequested then c.closeRequested(mouse) end
    end
    addon:SetUIScript(c.edit,'OnEscapePressed',function() closeEditor(false) end)
    addon:SetUIScript(c.edit,'OnMouseDown',function(_,button) if button=='RightButton' then closeEditor(true) end end)
    c.edit:SetText('')
    c.nativeGetText=c.edit.GetText;c.nativeSetText=c.edit.SetText;c.nativeScripts={}
    for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do c.nativeScripts[event]=c.edit:GetScript(event) end
    local syntax=preferred~='plain' and self.LuaSyntax
    if syntax then
        local getText,setText=c.edit.GetText,c.edit.SetText;local scripts={};for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do scripts[event]=c.edit:GetScript(event) end
        c.syntaxColors={};for token,color in pairs(syntax.defaultColorTable or {}) do c.syntaxColors[token]=type(color)=='string' and color:gsub('^|c00','|cff') or color end
        local ok=pcall(syntax.enable,c.edit,c.syntaxColors,4)
        if ok then c.syntax=syntax else
            pcall(syntax.disable,c.edit);c.edit.GetText=getText;c.edit.SetText=setText
            for _,event in ipairs({'OnTextChanged','OnTabPressed','OnUpdate'}) do c.edit:SetScript(event,scripts[event]) end
        end
    end
    -- Install the provider handler before post-hooks: native SetScript clears
    -- existing HookScript callbacks, including deferred gutters/diagnostics.
    if self.InstallNativeLuaLineNumbers then
        addon:SetUIScript(c.frame,'OnUpdate',function() if not c.released and c.valid() and c.RefreshLineNumbers and c.lineNumberSetting~=(addon.db.profile.lua_line_numbers~=false) then c:Layout('line-number-setting') end end)
    end
    if self.InstallLuaInputDiagnostics then self:InstallLuaInputDiagnostics(c) end
    if self.InstallRMCodeCompletion then self:InstallRMCodeCompletion(c) end
    if self.InstallNativeLuaLineNumbers then self:InstallNativeLuaLineNumbers(c) end
    c:SetText('');return c
end

-- Each source host owns these three slots; parent frames are not identities.
function addon:AcquireSourceLuaEditor(owner,parent,changed,valid,preferred)
    local operation={};owner.sourceEditorOperation=operation
    if self.DiscoverLuaEditorIntegrations then self:DiscoverLuaEditorIntegrations() end
    if owner.sourceEditorOperation~=operation then return owner.code end
    preferred=preferred or self.db.profile.lua_editor or 'auto'
    local resolved=preferred
    if resolved=='auto' then local names={};for name in pairs(providers) do names[#names+1]=name end;table.sort(names);resolved=names[1] or 'native' end
    if resolved=='LuaWorkbench' and not self:IsLuaWorkbenchIntegrationAvailable() then resolved='native' end
    if owner.sourceEditorOperation~=operation then return owner.code end
    local known=resolved=='native' or resolved=='plain' or resolved=='LuaWorkbench'
    local factory=providers[resolved]
    owner.sourceEditorPool=owner.sourceEditorPool or {}
    local old=owner.code
    local entry=known and owner.sourceEditorPool[resolved]
    local code=entry and entry.factory==factory and entry.control or nil
    -- An unchanged active foreign control retains its original refresh behavior;
    -- released or replaced foreign factories still construct fresh controls.
    if not known and old and not old.released and old.preference==preferred and old.factory==factory then code=old end
    if old and old~=code then
        owner.code=nil
        if not old.released then pcall(old.Release,old) end
        if owner.sourceEditorOperation~=operation then return owner.code end
    end
    if code then
        local ok=pcall(code.Acquire,code,changed,valid)
        if owner.sourceEditorOperation~=operation then return owner.code end
        if not ok then
            if owner.sourceEditorPool[resolved]==entry then owner.sourceEditorPool[resolved]=nil end
            pcall(code.Release,code);code=nil
            if owner.sourceEditorOperation~=operation then return owner.code end
        end
    end
    if not code then
        local ok,created=pcall(self.CreateWorkbenchLuaEditor,self,parent,changed,valid,resolved)
        if owner.sourceEditorOperation~=operation then
            if ok and created~=owner.code then pcall(created.Release,created) end
            return owner.code
        end
        if not ok then error(created,0) end
        code=created
        if known and type(code.Acquire)=='function' and (resolved~='LuaWorkbench' or code.provider=='LuaWorkbench') then owner.sourceEditorPool[resolved]={factory=factory,control=code} end
    end
    code.preference=preferred;owner.code=code
    return code
end
]=],
    changes = {
        {
            23078,
            23077,
            [=[
' end
    if editorDisabled(self,resolved) then resolved='plain]=],
        },
        {
            22894,
            22973,
            [=[
]=],
        },
        {
            22821,
            22892,
            [=[
]=],
        },
        {
            22812,
            22811,
            [=[
resolveEditor(self,]=],
        },
        {
            9699,
            9698,
            [=[
 end
    if editorDisabled(self,'native') then preferred='plain']=],
        },
        {
            1713,
            1741,
            [=[
)]=],
        },
        {
            1630,
            1703,
            [=[
,]=],
        },
        {
            1615,
            1628,
            [=[
]=],
        },
        {
            1604,
            1613,
            [=[
]=],
        },
        {
            1599,
            1602,
            [=[
r(s]=],
        },
        {
            1593,
            1596,
            [=[
resolveEdi]=],
        },
        {
            1580,
            1582,
            [=[
]=],
        },
        {
            46,
            45,
            [=[

-- Only RM-owned choices have persisted enable switches; extensions retain
-- their existing registration contract and remain available to Automatic.
local function editorDisabled(self,name)
    local profile=self.db and self.db.profile
    local disabled=profile and profile.lua_editor_disabled
    return (name=='native' or name=='LuaWorkbench') and type(disabled)=='table' and disabled[name]==true
end
local function resolveEditor(self,preferred)
    if preferred=='auto' then
        local names={};for name in pairs(providers) do if not editorDisabled(self,name) then names[#names+1]=name end end
        table.sort(names);preferred=names[1] or 'native'
    end
    if editorDisabled(self,preferred) then return 'plain' end
    return preferred
end]=],
        },
    },
}

records["Core/profile_data.lua"] = {
    old = [=[
local _,addon=...
local scalar={rotationFallbackID='string',lua_editor='string',lua_line_numbers='boolean',questie_enabled='boolean',version='number',enable='boolean',poll='number',ignore_mana='boolean',ignore_range='boolean',effect='string',magnification='number',setpoint='string',xoffs='number',yoffs='number',loglevel='number',detailed_profiling='boolean',disable_autoswitch='boolean',live_config_update='number',spell_history='number',combat_history='number',damage_history='number',disable_buttons='boolean',rotation_view='string',preview_spells='number',preview_vertical='boolean',preview_locked='boolean',preview_opacity='number',preview_icon_size='number'}
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
]=],
    changes = {
        {
            6101,
            6100,
            [=[
 end
        elseif key=='lua_editor_disabled' then
            if type(item)~='table' or getmetatable(item)~=nil then return false end
            for name,disabled in pairs(item) do if (name~='native' and name~='LuaWorkbench') or disabled~=true then return false end]=],
        },
    },
}

records["UI/settings_collections.lua"] = {
    old = [=[
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
    local scopes={Integrations={profile={'lua_editor','lua_line_numbers','questie_enabled'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
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
]=],
    changes = {
        {
            2508,
            2507,
            [=[
','lua_editor_disabled]=],
        },
    },
}

for _, record in pairs(records) do
    local source = record.old

    for _, change in ipairs(record.changes) do
        source = source:sub(1, change[1] - 1) .. change[3] .. source:sub(change[2] + 1)
    end

    record.new = source
    record.changes = nil
end

return function(path, source)
    source = dofile('tests/fixtures/restore_integration_pills.lua')(path, source)
    local record = assert(records[path], 'unsupported integration settings inverse path')
    assert(source == record.new, 'integration settings inverse requires exact complete successor: ' .. path)
    return record.old
end
