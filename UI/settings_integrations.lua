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
        local questieRow=readonly(questie);questieRow.help='Help.Integrations.questie_enabled'
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
        if row.help then
            local help=p:Acquire('integrationHelp',function()return addon:CreateWorkbenchHelpButton(p.child,L['Help'])end)
            help:SetParent(frame);help:ClearAllPoints();help:SetPoint('TOPLEFT',positions[4]+statusWidth-24,-10-pill:GetHeight()-6);help:Enable();p.fields['integration_help_'..row.id]=help
            addon:SetUIScript(help,'OnClick',p:Guard(function()
                local show=self.ShowWorkbenchHelp
                if current()and type(show)=='function'then show(self,row.name,{{title=row.name,text=L[row.help]}},p.frame)end
            end))
            height=math.max(height,10+pill:GetHeight()+6+24+6)
        end
        if row.native then
            local surface,available=p.surface,p.width;p.surface=frame;p.width=available-20;p.y=height
            local syntax=p:Check('lua_native_highlighting',L['Syntax highlighting'],highlighting(profile),function(value)
                local liveRows,liveByID=editors();if not liveRows or not current()then return end
                local active=effective(liveRows,liveByID);profile.lua_native_highlighting=value==true
                if active=='native'then profile.lua_editor=value and'native'or'plain'end;p:Draw()
            end)
            syntax:ClearAllPoints();syntax:SetPoint('TOPLEFT',10,-height)
            height=height+34;p.surface=surface;p.width=available
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
