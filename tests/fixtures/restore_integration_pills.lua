-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Exact complete dc36b2b predecessors; reject any unreviewed successor bytes.
local records = {}

records["UI/settings_integrations.lua"] = {
    old = [=[
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
]=],
    changes = {
        {
            10518,
            10517,
            [=[
,function(value)
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
    end end]=],
        },
        {
            10517,
            10516,
            [=[
,highlighting(profile]=],
        },
        {
            10515,
            10514,
            [=[
surface,p.width;p.surface=frame;p.width=available-20-(row.help and 28 or 0);p.y=contentTop
            local syntax=p:Check('lua_native_highlighting',L['Syntax highlighting]=],
        },
        {
            10514,
            10513,
            [=[
=p]=],
        },
        {
            10505,
            10504,
            [=[
row.entry.projectURL~=''then
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
            local surface,]=],
        },
        {
            10504,
            10503,
            [=[
tring'and]=],
        },
        {
            10503,
            10502,
            [=[
f row.entry and type(row.entry.projectURL)==']=],
        },
        {
            10501,
            10500,
            [=[
Cards',function()local c=CreateFrame('Frame',nil,p.child);c:EnableMouse(false);c.decoration=addon:CreateRoundedCardDecoration(c);c.decoration:SetColors(.35,.4,.44,.65,.08);return c end)
        frame:ClearAllPoints();frame:SetPoint('TOPLEFT',0,-top);frame:SetWidth(p.width);p.fields['integration_card_'..row.id]=frame
        local name=p:Acquire('integrationNames',function()return addon:CreateWorkbenchButton(p.child,'',nameWidth-24)end)
        name:SetParent(frame);name:ClearAllPoints();name:SetPoint('TOPLEFT',positions[1],-10);name:SetWidth(math.max(1,nameWidth-24));name.art:Hide();name:SetText(row.name)
        local caption=name:GetFontString();caption:ClearAllPoints();caption:SetPoint('TOPLEFT');caption:SetWidth(math.max(1,nameWidth-24));caption:SetJustifyH('LEFT');caption:SetJustifyV('TOP');caption:SetWordWrap(true)
        name:SetHeight(math.max(18,caption:GetStringHeight()));name:Disable();name:SetAlpha(1);caption:SetTextColor(.9,.92,.94);addon:SetUIScript(name,'OnClick',nil)
        p.fields['integration_name_'..row.id]=name
       ]=],
        },
        {
            10489,
            10489,
            [=[
e(']=],
        },
        {
            10487,
            10486,
            [=[
n c:SetMaxLines(0)end;c:SetText(text or'');c:SetTextColor(.9,.92,.94);c:SetHeight(0);c:SetHeight(math.max(18,c:GetStringHeight()));return c
    end
    local function draw(row)
        local top=p.y
        local frame=p:Acqu]=],
        },
        {
            10484,
            10483,
            [=[
c:SetNonSpaceWrap(true)end;if c.SetMaxLines ]=],
        },
        {
            10480,
            10479,
            [=[
idths={nameWidth,versionWidth,descWidth,statusWidth}
    local function label(kind,parent,text,x,y,w)
        local c=p:Acquire(kind,function()local f=p.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');f:SetJustifyH('LEFT');f:SetJustifyV('TOP');return f end)
        c:SetParent(parent);c:ClearAllPoints();c:SetPoint('TOPLEFT',x,-y);c:SetWidth(math.max(1,w));c:SetWordWrap(true);if c.SetNonSpaceWrap t]=],
        },
        {
            10478,
            10477,
            [=[
=L['Selected']}
    local nameWidth,versionWidth,statusWidth=width(L['Addon'])+24,width(L['Version']),width(L['Status'])+16
    for _,label in pairs(labels)do statusWidth=math.max(statusWidth,width(label)+18)end
    for _,section in ipairs(groups)do for _,row in ipairs(section.rows)do nameWidth=math.max(nameWidth,width(row.name)+24);versionWidth=math.max(versionWidth,width(row.version))end end
    measure:SetText('');measure:Hide()
    local usable=p.width-20;local gap=8
    statusWidth=math.min(statusWidth,usable*.28);nameWidth=math.min(nameWidth,usable*.30);versionWidth=math.min(versionWidth,usable*.16)
    local descWidth=usable-nameWidth-versionWidth-statusWidth-gap*3
    local positions={10,10+nameWidth+gap,10+nameWidth+versionWidth+gap*2,p.width-10-statusWidth}
    local]=],
        },
        {
            10468,
            10472,
            [=[
'],sel]=],
        },
        {
            10460,
            10465,
            [=[
]=],
        },
        {
            10447,
            10458,
            [=[
b]=],
        },
        {
            10445,
            10445,
            [=[
=L['En]=],
        },
        {
            10442,
            10442,
            [=[
bl]=],
        },
        {
            10424,
            10440,
            [=[
]=],
        },
        {
            10421,
            10421,
            [=[
d'],]=],
        },
        {
            10419,
            10419,
            [=[
=L['Disabl]=],
        },
        {
            10416,
            10416,
            [=[
abl]=],
        },
        {
            10404,
            10413,
            [=[
]=],
        },
        {
            10401,
            10402,
            [=[
'],]=],
        },
        {
            10389,
            10388,
            [=[
text or'');return measure:GetStringWidth()end
    local labels={missing=L['Not loaded'],supported=]=],
        },
        {
            10384,
            10383,
            [=[
Acquire('integrationMeasure',function()return p.child:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')end)
    measure:SetWordWrap(false);measure:SetWidth(0)
    local function width(text)measure:Set]=],
        },
        {
            10382,
            10381,
            [=[
-- Measure shared columns once per drawing; description receives the remainder.
    p.width=math.max(340,p.frame:GetWidth()-40);p.child:SetWidth(p.width)
    local measure=]=],
        },
        {
            10096,
            10205,
            [=[
]=],
        },
        {
            10051,
            10093,
            [=[
]=],
        },
        {
            10036,
            10049,
            [=[
]=],
        },
        {
            10032,
            10034,
            [=[
]=],
        },
        {
            9922,
            10029,
            [=[
]=],
        },
        {
            9237,
            9916,
            [=[
]=],
        },
        {
            9233,
            9235,
            [=[
s_]=],
        },
        {
            9214,
            9221,
            [=[
]=],
        },
        {
            9209,
            9212,
            [=[
up(]=],
        },
        {
            9200,
            9206,
            [=[
d
    g]=],
        },
        {
            9187,
            9197,
            [=[
]=],
        },
        {
            9176,
            9185,
            [=[
]=],
        },
        {
            9172,
            9174,
            [=[
]=],
        },
        {
            9165,
            9170,
            [=[
]=],
        },
        {
            9164,
            9163,
            [=[
Row}}
]=],
        },
        {
            9154,
            9157,
            [=[
{q]=],
        },
        {
            9144,
            9152,
            [=[
]=],
        },
        {
            9142,
            9142,
            [=[
ow]=],
        },
        {
            9132,
            9140,
            [=[
]=],
        },
        {
            9107,
            9128,
            [=[
s]=],
        },
        {
            9055,
            9097,
            [=[
]=],
        },
        {
            8898,
            9043,
            [=[
]=],
        },
        {
            8894,
            8896,
            [=[
]=],
        },
        {
            8883,
            8891,
            [=[
s',]=],
        },
        {
            8865,
            8878,
            [=[
_q]=],
        },
        {
            8859,
            8863,
            [=[
]=],
        },
        {
            8847,
            8848,
            [=[
]=],
        },
        {
            8835,
            8845,
            [=[
y=']=],
        },
        {
            8833,
            8833,
            [=[
{k]=],
        },
        {
            8832,
            8831,
            [=[
+1]]=],
        },
        {
            8831,
            8830,
            [=[
p]=],
        },
        {
            8827,
            8829,
            [=[
[#gro]=],
        },
        {
            8822,
            8825,
            [=[
up]=],
        },
        {
            8820,
            8820,
            [=[
gr]=],
        },
        {
            8790,
            8810,
            [=[
]=],
        },
        {
            8778,
            8777,
            [=[
;p:Draw()
            end]=],
        },
        {
            8704,
            8704,
            [=[
stie_enabled==true)
                ]=],
        },
        {
            8702,
            8701,
            [=[
e.q]=],
        },
        {
            8699,
            8700,
            [=[
not(profi]=],
        },
        {
            8663,
            8662,
            [=[
                if not loaded then return end
    ]=],
        },
        {
            8661,
            8661,
            [=[
stie'then loaded=entry.state~='missing'and entry.state~='unknown'end end]=],
        },
        {
            8659,
            8658,
            [=[
 fresh=inventoryRows();if not fresh then return end
                local loaded=false;for _,entry in ipairs(fresh)do if entry.id=='Q]=],
        },
        {
            8656,
            8656,
            [=[
)
                if not supported('Questie')or not current()then return end
                loc]=],
        },
        {
            8646,
            8646,
            [=[
 and'enabled'or'disabled'
            questieRow.action=]=],
        },
        {
            8601,
            8616,
            [=[
=]=],
        },
        {
            8598,
            8599,
            [=[
t]=],
        },
        {
            8597,
            8596,
            [=[

            questieRow.st]=],
        },
        {
            8594,
            8594,
            [=[
Row.state~='missing'th]=],
        },
        {
            8572,
            8586,
            [=[
if ]=],
        },
        {
            8545,
            8560,
            [=[
]=],
        },
        {
            8526,
            8537,
            [=[
ly]=],
        },
        {
            8508,
            8523,
            [=[
d]=],
        },
        {
            8505,
            8506,
            [=[
Row=re]=],
        },
        {
            8483,
            8497,
            [=[
l ]=],
        },
        {
            8481,
            8480,
            [=[
    lo]=],
        },
        {
            8469,
            8473,
            [=[
g]=],
        },
        {
            8467,
            8467,
            [=[
missi]=],
        },
        {
            8427,
            8427,
            [=[
]=],
        },
        {
            8412,
            8415,
            [=[
metadata]=],
        },
        {
            8394,
            8393,
            [=[
    ]=],
        },
        {
            8385,
            8392,
            [=[
owed then]=],
        },
        {
            8382,
            8382,
            [=[
urrent()then return end
    if questieA]=],
        },
        {
            8380,
            8379,
            [=[
ie');if not]=],
        },
        {
            8372,
            8373,
            [=[
]=],
        },
        {
            8371,
            8370,
            [=[
d]=],
        },
        {
            8369,
            8369,
            [=[
]=],
        },
        {
            8368,
            8367,
            [=[
eAllowed=suppor]=],
        },
        {
            8366,
            8365,
            [=[
local ques]=],
        },
        {
            8313,
            8312,
            [=[
'integrations_notifications',]=],
        },
        {
            8300,
            8307,
            [=[
g]=],
        },
        {
            8237,
            8236,
            [=[
'integrations_conditions',]=],
        },
        {
            8224,
            8231,
            [=[
g]=],
        },
        {
            8216,
            8215,
            [=[
    groups[#groups+1]={key=key,title=title,rows=list}
    ]=],
        },
        {
            8159,
            8202,
            [=[
]]=],
        },
        {
            8155,
            8156,
            [=[
metadata[]=],
        },
        {
            8154,
            8153,
            [=[
only]=],
        },
        {
            8152,
            8152,
            [=[
]=],
        },
        {
            8150,
            8150,
            [=[
list[#list+1]=re]=],
        },
        {
            8135,
            8144,
            [=[
]=],
        },
        {
            8124,
            8130,
            [=[
a]=],
        },
        {
            8119,
            8122,
            [=[
da]=],
        },
        {
            8115,
            8117,
            [=[
if met]=],
        },
        {
            8078,
            8087,
            [=[
={}]=],
        },
        {
            8077,
            8076,
            [=[
local lis]=],
        },
        {
            8059,
            8061,
            [=[
key,titl]=],
        },
        {
            8046,
            8053,
            [=[
g]=],
        },
        {
            8024,
            8025,
            [=[
}}]=],
        },
        {
            8016,
            8022,
            [=[
gs=tru]=],
        },
        {
            8014,
            8014,
            [=[
]=],
        },
        {
            7966,
            8011,
            [=[
]=],
        },
        {
            7874,
            7964,
            [=[
]=],
        },
        {
            7863,
            7872,
            [=[
S]=],
        },
        {
            7706,
            7856,
            [=[
]=],
        },
        {
            7693,
            7704,
            [=[
Rows]=],
        },
        {
            7339,
            7686,
            [=[
]=],
        },
        {
            7327,
            7336,
            [=[
w]=],
        },
        {
            7319,
            7325,
            [=[
,r]=],
        },
        {
            7290,
            7290,
            [=[
=]=],
        },
        {
            6995,
            7284,
            [=[
]=],
        },
        {
            6933,
            6993,
            [=[
]=],
        },
        {
            6921,
            6931,
            [=[
]=],
        },
        {
            6913,
            6919,
            [=[
]=],
        },
        {
            6608,
            6906,
            [=[
]=],
        },
        {
            6607,
            6606,
            [=[
s]=],
        },
        {
            6594,
            6594,
            [=[
ey=]=],
        },
        {
            6593,
            6592,
            [=[
al groups={{]=],
        },
        {
            6592,
            6591,
            [=[
n editorRows[#editorRows+1]=readonly(metadata.WowLua)end
    lo]=],
        },
        {
            6588,
            6589,
            [=[
airs(rows)do editorRows[#editorRows+1]=editorRow(row);found[row.id]=true end
    local function readonly(entry)
        return{id=entry.id,name=entry.name,version=versionFor(entry),description=entry.detail or'',state=(entry.state=='missing'or entry.state=='unknown')and'missing'or'supported',entry=entry}
    end
    if metadata.WowLua and not found.WowLua t]=],
        },
        {
            6587,
            6586,
            [=[
local editorRows={editorRow(native)};local found={}
    for _,row in i]=],
        },
        {
            6574,
            6573,
            [=[
 or nil,
            entry=entry,help=row.id=='native'and'Help.Integrations.native_highlighting'or nil,native=row.id=='native'}]=],
        },
        {
            6570,
            6569,
            [=[
anchor)editorAction(row.id,anchor]=],
        },
        {
            6569,
            6568,
            [=[
d'or selected==row.id and'selected'or'enabled',
            action=row.available and function]=],
        },
        {
            6554,
            6562,
            [=[
d'd]=],
        },
        {
            6550,
            6552,
            [=[
a]=],
        },
        {
            6547,
            6546,
            [=[
row.]=],
        },
        {
            6522,
            6526,
            [=[
g']=],
        },
        {
            6520,
            6520,
            [=[
ssi]=],
        },
        {
            6517,
            6518,
            [=[
 and'm]=],
        },
        {
            6511,
            6514,
            [=[
lab]=],
        },
        {
            6507,
            6509,
            [=[
row.ava]=],
        },
        {
            6506,
            6505,
            [=[
state=not]=],
        },
        {
            6497,
            6501,
            [=[
]=],
        },
        {
            6481,
            6487,
            [=[
.'],]=],
        },
        {
            6476,
            6479,
            [=[
e]=],
        },
        {
            6473,
            6473,
            [=[
.']or entry and entry.detail or L['Registered Lua editor prov]=],
        },
        {
            6466,
            6466,
            [=[
 ]=],
        },
        {
            6455,
            6463,
            [=[
L]=],
        },
        {
            6448,
            6452,
            [=[
]=],
        },
        {
            6445,
            6446,
            [=[
t-]=],
        },
        {
            6442,
            6442,
            [=[
w.id=='native'and L['Bu]=],
        },
        {
            6427,
            6439,
            [=[
=]=],
        },
        {
            6424,
            6425,
            [=[
ptio]=],
        },
        {
            6423,
            6422,
            [=[
descr]=],
        },
        {
            6410,
            6409,
            [=[
,]=],
        },
        {
            6409,
            6408,
            [=[
entry]=],
        },
        {
            6408,
            6407,
            [=[
=row.id=='native'and''or versionFor]=],
        },
        {
            6400,
            6404,
            [=[
vers]=],
        },
        {
            6357,
            6393,
            [=[
w]=],
        },
        {
            6351,
            6355,
            [=[
=r]=],
        },
        {
            6348,
            6349,
            [=[
nam]=],
        },
        {
            6345,
            6344,
            [=[
row.]=],
        },
        {
            6329,
            6340,
            [=[
]=],
        },
        {
            6311,
            6327,
            [=[
]=],
        },
        {
            6309,
            6308,
            [=[
urn {id='edi]=],
        },
        {
            6308,
            6307,
            [=[
aWorkbench'or row.id]
        re]=],
        },
        {
            6307,
            6306,
            [=[
ench'and'!!!L]=],
        },
        {
            6306,
            6305,
            [=[
entry=metadata[row.id=='LuaWork]=],
        },
        {
            6288,
            6290,
            [=[
ID)
    local function editorRow(row)]=],
        },
        {
            6287,
            6286,
            [=[
ows,b]=],
        },
        {
            6286,
            6285,
            [=[
ed=effective(]=],
        },
        {
            6285,
            6284,
            [=[
d
    end
    local selec]=],
        },
        {
            6279,
            6282,
            [=[
 ]=],
        },
        {
            6273,
            6272,
            [=[
tadata[entry.id]]=],
        },
        {
            6271,
            6270,
            [=[
llowed then ]=],
        },
        {
            6270,
            6269,
            [=[
ot current()then return end
        if ]=],
        },
        {
            6268,
            6268,
            [=[
);if ]=],
        },
        {
            6266,
            6265,
            [=[
allowed=supported(entry.]=],
        },
        {
            6227,
            6247,
            [=[
]=],
        },
        {
            6174,
            6225,
            [=[
]=],
        },
        {
            6159,
            6170,
            [=[
]=],
        },
        {
            6151,
            6157,
            [=[
ve]=],
        },
        {
            6143,
            6148,
            [=[
]=],
        },
        {
            6121,
            6120,
            [=[
local inventory=inventoryRows();if not inventory then return end
    local metadata={};]=],
        },
        {
            6104,
            6111,
            [=[
]=],
        },
        {
            6101,
            6102,
            [=[
ur]=],
        },
        {
            6097,
            6099,
            [=[
]=],
        },
        {
            6095,
            6095,
            [=[
r]=],
        },
        {
            6072,
            6088,
            [=[
]=],
        },
        {
            6057,
            6070,
            [=[
]=],
        },
        {
            6056,
            6055,
            [=[
rren]=],
        },
        {
            6053,
            6054,
            [=[
not c]=],
        },
        {
            6049,
            6048,
            [=[
s();if not rows]=],
        },
        {
            6031,
            6042,
            [=[
]=],
        },
        {
            6028,
            6029,
            [=[
ve]=],
        },
        {
            6022,
            6025,
            [=[
,byID,na]=],
        },
        {
            6021,
            6020,
            [=[
row]=],
        },
        {
            6010,
            6009,
            [=[
or{}
        if current()then return result end
    end]=],
        },
        {
            6008,
            6008,
            [=[
function'and list(self]=],
        },
        {
            6007,
            6006,
            [=[
;if not current()then return end
        local result=type(list)==]=],
        },
        {
            6005,
            6005,
            [=[
Statu]=],
        },
        {
            6004,
            6003,
            [=[
o]=],
        },
        {
            6002,
            6001,
            [=[
Integra]=],
        },
        {
            6001,
            6000,
            [=[
lf.Lis]=],
        },
        {
            5999,
            5998,
            [=[
       local list=]=],
        },
        {
            5998,
            5997,
            [=[
yRows()
]=],
        },
        {
            5987,
            5994,
            [=[
ven]=],
        },
        {
            5984,
            5984,
            [=[
l function ]=],
        },
        {
            5979,
            5982,
            [=[
loc]=],
        },
        {
            5966,
            5965,
            [=[

        if #alternatives==0 then disable(id,nil,true)
        elseif #alternatives==1 then disable(id,alternatives[1].value,true)
        else p:ShowChoices(anchor,alternatives,function(other)disable(id,other,true)end,true)end]=],
        },
        {
            5962,
            5961,
            [=[
table.sort(alternatives,function(a,b)return a.value<b.value ]=],
        },
        {
            5812,
            5948,
            [=[
]=],
        },
        {
            5806,
            5808,
            [=[
me}]=],
        },
        {
            5795,
            5804,
            [=[
.n]=],
        },
        {
            5792,
            5793,
            [=[
]=],
        },
        {
            5790,
            5790,
            [=[
rg]=],
        },
        {
            5789,
            5788,
            [=[
e=other,text=t]=],
        },
        {
            5786,
            5786,
            [=[
rnatives+1]={va]=],
        },
        {
            5785,
            5784,
            [=[
t]=],
        },
        {
            5784,
            5783,
            [=[
ves[#a]=],
        },
        {
            5781,
            5782,
            [=[
nat]=],
        },
        {
            5779,
            5779,
            [=[
alte]=],
        },
        {
            5771,
            5772,
            [=[
other]=],
        },
        {
            5736,
            5735,
            [=[
other~=id and target.]=],
        },
        {
            5728,
            5731,
            [=[
pairs(byID)do]=],
        },
        {
            5727,
            5726,
            [=[
in]=],
        },
        {
            5726,
            5725,
            [=[
other,target]=],
        },
        {
            5725,
            5724,
            [=[
for]=],
        },
        {
            5652,
            5715,
            [=[
={}]=],
        },
        {
            5648,
            5650,
            [=[
ve]=],
        },
        {
            5645,
            5644,
            [=[
n]=],
        },
        {
            5643,
            5643,
            [=[
]=],
        },
        {
            5622,
            5640,
            [=[
al]=],
        },
        {
            5612,
            5615,
            [=[
]=],
        },
        {
            5588,
            5591,
            [=[
]=],
        },
        {
            5574,
            5586,
            [=[
]=],
        },
        {
            5573,
            5572,
            [=[
tur]=],
        },
        {
            5568,
            5571,
            [=[
r]=],
        },
        {
            5549,
            5551,
            [=[
tr]=],
        },
        {
            5540,
            5546,
            [=[
]=],
        },
        {
            5537,
            5538,
            [=[
]=],
        },
        {
            5535,
            5535,
            [=[
        ]=],
        },
        {
            5531,
            5530,
            [=[
if value=='disable'then disable(id,nil,false)elseif value=='select'then choose(id)end
]=],
        },
        {
            5497,
            5497,
            [=[
ct',text=L['Select']}}]=],
        },
        {
            5492,
            5494,
            [=[
='se]=],
        },
        {
            5491,
            5490,
            [=[
{valu]=],
        },
        {
            5490,
            5489,
            [=[
}]=],
        },
        {
            5487,
            5487,
            [=[
]=],
        },
        {
            5481,
            5482,
            [=[
Dis]=],
        },
        {
            5478,
            5477,
            [=[
text=]=],
        },
        {
            5473,
            5476,
            [=[
]=],
        },
        {
            5471,
            5471,
            [=[
]=],
        },
        {
            5454,
            5466,
            [=[
s]=],
        },
        {
            5453,
            5452,
            [=[
d]=],
        },
        {
            5444,
            5451,
            [=[
]=],
        },
        {
            5441,
            5442,
            [=[
ue]=],
        },
        {
            5439,
            5438,
            [=[
es(anchor,{{v]=],
        },
        {
            5438,
            5437,
            [=[
wChoi]=],
        },
        {
            5432,
            5436,
            [=[
p:Sh]=],
        },
        {
            5323,
            5413,
            [=[
]=],
        },
        {
            5264,
            5320,
            [=[
]=],
        },
        {
            5217,
            5262,
            [=[
~]=],
        },
        {
            5183,
            5215,
            [=[
]=],
        },
        {
            5154,
            5180,
            [=[
c]=],
        },
        {
            5146,
            5152,
            [=[
l]=],
        },
        {
            5145,
            5144,
            [=[
s]=],
        },
        {
            5034,
            5132,
            [=[
]=],
        },
        {
            5031,
            5032,
            [=[
byID]=],
        },
        {
            5026,
            5029,
            [=[
ws]=],
        },
        {
            5023,
            5023,
            [=[
]=],
        },
        {
            5003,
            5021,
            [=[
]=],
        },
        {
            4981,
            5001,
            [=[
v]=],
        },
        {
            4976,
            4976,
            [=[
ff]=],
        },
        {
            4974,
            4974,
            [=[
]=],
        },
        {
            4938,
            4945,
            [=[
]=],
        },
        {
            4935,
            4936,
            [=[
ur]=],
        },
        {
            4933,
            4933,
            [=[
(id);re]=],
        },
        {
            4931,
            4930,
            [=[
nab]=],
        },
        {
            4929,
            4929,
            [=[
]=],
        },
        {
            4923,
            4923,
            [=[
]=],
        },
        {
            4920,
            4921,
            [=[
d]=],
        },
        {
            4913,
            4918,
            [=[
]=],
        },
        {
            4881,
            4883,
            [=[
rn end]=],
        },
        {
            4880,
            4879,
            [=[
l row=byID[id];if not row or not row.available then ret]=],
        },
        {
            4878,
            4878,
            [=[
not current()then return end
        loc]=],
        },
        {
            4874,
            4873,
            [=[
s();if not rows]=],
        },
        {
            4859,
            4867,
            [=[
ws,byID=]=],
        },
        {
            4846,
            4856,
            [=[
]=],
        },
        {
            4829,
            4829,
            [=[
]=],
        },
        {
            4811,
            4827,
            [=[
cho]=],
        },
        {
            4810,
            4809,
            [=[
a]=],
        },
        {
            4806,
            4805,
            [=[
Action]=],
        },
        {
            4751,
            4751,
            [=[
]=],
        },
        {
            4744,
            4743,
            [=[
replacement and selection(replacement,value)or]=],
        },
        {
            4718,
            4717,
            [=[
d or not wasSelected and selected==id then return end
        if replacement then
            local target=byID[replacement]
            if not target or replacement==id or not target.available or disabled(profile,replacement)then return end
        elseif wasSelected then
            -- A new enabled alternative requires a fresh explicit handoff choice.
            for other,target in pairs(byID)do if other~=id and target.available and not disabled(profile,other)then return end end
        end
        local value=highlighting(profile);local map=mapWith(id,true);if not map then return end
        rememberHighlight(value);profile.lua_editor_disabled=map
        if wasSelecte]=],
        },
        {
            4716,
            4715,
            [=[
selection(id,value)end
        p:Draw()
    end
    local function disable(id,replacement,wasSelected)
        local rows,byID=editors();if not rows or not current()then return end
        local row=byID[id];if not row or not row.available or disabled(profile,id)then return end
        local selected=effective(rows,byID)
        if wasSelected and selected~]=],
        },
        {
            4692,
            4696,
            [=[
);]=],
        },
        {
            4687,
            4686,
            [=[
selected then rememberHighlight(]=],
        },
        {
            4656,
            4656,
            [=[
]=],
        },
        {
            4619,
            4618,
            [=[
return map
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
        ]=],
        },
        {
            4602,
            4605,
            [=[
]=],
        },
        {
            4580,
            4579,
            [=[
t map[id]then n=n+1 end
        if n>64 then p:Message(L['Unavailable']);retur]=],
        },
        {
            4579,
            4578,
            [=[
true;n=n+1 end end
        if value and n]=],
        },
        {
            4569,
            4568,
            [=[
 if on==true then]=],
        },
        {
            4563,
            4563,
            [=[
]=],
        },
        {
            4500,
            4512,
            [=[
]=],
        },
        {
            4480,
            4490,
            [=[
{},0]=],
        },
        {
            4460,
            4478,
            [=[
]=],
        },
        {
            4437,
            4458,
            [=[
]=],
        },
        {
            4430,
            4435,
            [=[
]=],
        },
        {
            4424,
            4428,
            [=[
]=],
        },
        {
            4420,
            4422,
            [=[
m]=],
        },
        {
            4417,
            4418,
            [=[
local]=],
        },
        {
            4398,
            4397,
            [=[
'native'or'plain')or id end
    local function mapWith]=],
        },
        {
            4397,
            4396,
            [=[
 an]=],
        },
        {
            4396,
            4395,
            [=[
u]=],
        },
        {
            4394,
            4394,
            [=[
tive'and(va]=],
        },
        {
            4391,
            4391,
            [=[
ion(id,value)return id==']=],
        },
        {
            4390,
            4389,
            [=[
lec]=],
        },
        {
            4360,
            4359,
            [=[
(value)
        if profile.lua_native_highlighting==nil then profile.lua_native_highlighting=value end]=],
        },
        {
            4356,
            4355,
            [=[
n return'native'end
    end
    local function rememberHighl]=],
        },
        {
            4347,
            4353,
            [=[
rofile,'native')t]=],
        },
        {
            4346,
            4345,
            [=[
if not disabled(]=],
        },
        {
            3999,
            4324,
            [=[
]=],
        },
        {
            3946,
            3995,
            [=[
d ]=],
        },
        {
            3935,
            3943,
            [=[
]=],
        },
        {
            3932,
            3933,
            [=[
sele]=],
        },
        {
            3905,
            3924,
            [=[
 ]=],
        },
        {
            3902,
            3903,
            [=[
he]=],
        },
        {
            3898,
            3900,
            [=[
d)]=],
        },
        {
            3887,
            3895,
            [=[
]=],
        },
        {
            3882,
            3885,
            [=[
e]=],
        },
        {
            3880,
            3879,
            [=[
le and not disabled(profile,s]=],
        },
        {
            3877,
            3876,
            [=[
row=byID[selected];if row and row.avai]=],
        },
        {
            3858,
            3857,
            [=[
 if row.available and not disabled(profile,row.id)then return row.id end end
        elseif selected~='native'and selected~='plain' then]=],
        },
        {
            3850,
            3853,
            [=[
w]=],
        },
        {
            3848,
            3848,
            [=[
r]=],
        },
        {
            3833,
            3836,
            [=[
w]=],
        },
        {
            3831,
            3831,
            [=[
r]=],
        },
        {
            3653,
            3816,
            [=[
]=],
        },
        {
            3618,
            3647,
            [=[
]=],
        },
        {
            3613,
            3616,
            [=[
]=],
        },
        {
            3605,
            3611,
            [=[
]=],
        },
        {
            3585,
            3602,
            [=[
]=],
        },
        {
            3568,
            3583,
            [=[
]=],
        },
        {
            3567,
            3566,
            [=[
ected=='aut]=],
        },
        {
            3566,
            3565,
            [=[
if se]=],
        },
        {
            3555,
            3556,
            [=[
or or'auto']=],
        },
        {
            3553,
            3553,
            [=[
]=],
        },
        {
            3545,
            3551,
            [=[
a_ed]=],
        },
        {
            3535,
            3542,
            [=[
e.]=],
        },
        {
            3534,
            3533,
            [=[
fi]=],
        },
        {
            3518,
            3531,
            [=[
]=],
        },
        {
            3495,
            3516,
            [=[
=]=],
        },
        {
            3492,
            3493,
            [=[
lecte]=],
        },
        {
            3488,
            3490,
            [=[
s]=],
        },
        {
            3444,
            3471,
            [=[
rows,byID]=],
        },
        {
            3440,
            3441,
            [=[
v]=],
        },
        {
            3438,
            3437,
            [=[
effec]=],
        },
        {
            3414,
            3414,
            [=[
,name=L['Native'],available=true};byID.native=native
        return rows,byID,native
    ]=],
        },
        {
            3413,
            3412,
            [=[
native]=],
        },
        {
            3412,
            3411,
            [=[
end
        local native={id=]=],
        },
        {
            3411,
            3410,
            [=[
kbench=row]=],
        },
        {
            3408,
            3408,
            [=[
able=false};rows[#rows+1]=row;byID.LuaW]=],
        },
        {
            3404,
            3404,
            [=[
nch',name=L['LuaWorkbench'],av]=],
        },
        {
            3403,
            3402,
            [=[
='LuaWorkb]=],
        },
        {
            3400,
            3401,
            [=[
ow={i]=],
        },
        {
            3399,
            3398,
            [=[
hen local ]=],
        },
        {
            3398,
            3397,
            [=[
ch ]=],
        },
        {
            3395,
            3395,
            [=[
LuaWorkb]=],
        },
        {
            3393,
            3393,
            [=[
ot byID]=],
        },
        {
            3390,
            3391,
            [=[
]=],
        },
        {
            3380,
            3384,
            [=[
]=],
        },
        {
            3374,
            3378,
            [=[
]=],
        },
        {
            3366,
            3372,
            [=[
]=],
        },
        {
            3362,
            3363,
            [=[
chAll]=],
        },
        {
            3356,
            3360,
            [=[
kbe]=],
        },
        {
            3354,
            3353,
            [=[
       if w]=],
        },
        {
            3352,
            3352,
            [=[
nd
]=],
        },
        {
            3349,
            3350,
            [=[
urn ]=],
        },
        {
            3345,
            3347,
            [=[
e]=],
        },
        {
            3344,
            3343,
            [=[
()then ]=],
        },
        {
            3339,
            3340,
            [=[
d('!!!LuaWorkbench');if not curr]=],
        },
        {
            3335,
            3336,
            [=[
uppor]=],
        },
        {
            3333,
            3333,
            [=[
a.id<b.id end)
        local workbenchAllowed=]=],
        },
        {
            3325,
            3324,
            [=[
.text),available=available==true};rows[#rows+1]=row;byID[id]=row end
            end
        end
        table.sort(rows,function(a,b]=],
        },
        {
            3311,
            3318,
            [=[
afeName]=],
        },
        {
            3310,
            3309,
            [=[
nt()then return end
                if not byID[id]then local row={id=id,name=]=],
        },
        {
            3309,
            3308,
            [=[

                if not curr]=],
        },
        {
            3308,
            3307,
            [=[
check(self)==true
                en]=],
        },
        {
            3307,
            3306,
            [=[
'and]=],
        },
        {
            3299,
            3298,
            [=[
allowed=supported(id=='LuaWorkbench'and'!!!LuaWorkbench'or id);if not current()then return end
            if allowed and id~='auto' and id~='plain' and id~='native' then
                local available=true
                if id=='LuaWorkbench'then
                    local check=self.IsLuaWorkbenchIntegrationAvailable;if not current()then return end
                    available=type(check)==']=],
        },
        {
            3175,
            3288,
            [=[
     ]=],
        },
        {
            3171,
            3173,
            [=[
]=],
        },
        {
            3160,
            3169,
            [=[
]=],
        },
        {
            3157,
            3158,
            [=[

]=],
        },
        {
            3155,
            3155,
            [=[
lu]=],
        },
        {
            3149,
            3153,
            [=[
entry.v]=],
        },
        {
            3119,
            3146,
            [=[
]=],
        },
        {
            3109,
            3117,
            [=[
]=],
        },
        {
            3095,
            3098,
            [=[
       ]=],
        },
        {
            3087,
            3093,
            [=[
o
]=],
        },
        {
            3086,
            3085,
            [=[
es)]=],
        },
        {
            3083,
            3084,
            [=[
]=],
        },
        {
            3061,
            3078,
            [=[
]=],
        },
        {
            3035,
            3034,
            [=[
    ]=],
        },
        {
            3028,
            3028,
            [=[
ows,byID=]=],
        },
        {
            3027,
            3026,
            [=[
cal ]=],
        },
        {
            3026,
            3025,
            [=[
return end
        l]=],
        },
        {
            3025,
            3024,
            [=[
then]=],
        },
        {
            3023,
            3022,
            [=[
=list(self);if not current]=],
        },
        {
            3022,
            3021,
            [=[
rn end
        local entrie]=],
        },
        {
            3019,
            3019,
            [=[
hen re]=],
        },
        {
            3017,
            3017,
            [=[
']=],
        },
        {
            3010,
            3012,
            [=[
(list)~='func]=],
        },
        {
            3009,
            3008,
            [=[
()or typ]=],
        },
        {
            3006,
            3006,
            [=[
LuaEditorProviders;if not curre]=],
        },
        {
            3001,
            3001,
            [=[
.]=],
        },
        {
            2998,
            2997,
            [=[
tate=='unsupported')
    end
    local function editors()
        local list=s]=],
        },
        {
            2991,
            2990,
            [=[
rn end
            if type(check)=='function'then return check(self,id,client)end
        end)
        if not current()then return end
        return not(succes]=],
        },
        {
            2988,
            2988,
            [=[
;if not current()then re]=],
        },
        {
            2987,
            2986,
            [=[
uppor]=],
        },
        {
            2986,
            2985,
            [=[
Client]=],
        },
        {
            2974,
            2973,
            [=[
upported(id)
        local success,state=pcall(function()
            local check=self.Ge]=],
        },
        {
            2973,
            2972,
            [=[
f not current()then return end
        local get=platform and platform.GetClientInfo;if not current()then return end
        if type(get)=='function'then return get(platform)end
    end)
    if not current()then return end
    if ok then client=value end
    local function ]=],
        },
        {
            2971,
            2971,
            [=[
Platform;]=],
        },
        {
            2961,
            2964,
            [=[
value=pcall(function()
        local platform]=],
        },
        {
            2960,
            2959,
            [=[
 is a cold page snapshot; failures retain the unknown entry.
    local client
    local ok]=],
        },
        {
            2959,
            2958,
            [=[
 p.draft and p.draft.profile==profile)
    end
    -- Compatibilit]=],
        },
        {
            2957,
            2956,
            [=[
()
        return p:Valid(token) and (not p.transactionKeys ]=],
        },
        {
            2953,
            2953,
            [=[
 curr]=],
        },
        {
            2952,
            2951,
            [=[
o]=],
        },
        {
            2951,
            2950,
            [=[
funct]=],
        },
        {
            2940,
            2939,
            [=[
;local token=p.generation]=],
        },
        {
            2657,
            2853,
            [=[
2}}]=],
        },
        {
            2630,
            2655,
            [=[
]=],
        },
        {
            2627,
            2628,
            [=[
.8]=],
        },
        {
            2606,
            2625,
            [=[
={1]=],
        },
        {
            2599,
            2604,
            [=[
e]=],
        },
        {
            2589,
            2597,
            [=[
c]=],
        },
        {
            2551,
            2586,
            [=[
]=],
        },
        {
            2546,
            2548,
            [=[
d={.25,.7,.35},]=],
        },
        {
            2523,
            2540,
            [=[
]=],
        },
        {
            2516,
            2521,
            [=[
d={.85,.25,.25},]=],
        },
        {
            2514,
            2514,
            [=[
bl]=],
        },
        {
            2511,
            2512,
            [=[
d={.25,.55,.9},dis]=],
        },
        {
            2507,
            2508,
            [=[
]=],
        },
        {
            2505,
            2505,
            [=[
{missing={.48,.48,.48},suppo]=],
        },
        {
            2504,
            2503,
            [=[
olors]=],
        },
        {
            2259,
            2496,
            [=[
]=],
        },
        {
            1960,
            2254,
            [=[
]=],
        },
        {
            1932,
            1958,
            [=[
']=],
        },
        {
            1913,
            1929,
            [=[
]=],
        },
        {
            1883,
            1911,
            [=[
u]=],
        },
        {
            1882,
            1881,
            [=[
re]=],
        },
        {
            1606,
            1868,
            [=[
]=],
        },
        {
            1467,
            1602,
            [=[
]=],
        },
        {
            1449,
            1465,
            [=[
]=],
        },
        {
            1327,
            1447,
            [=[
]=],
        },
        {
            1316,
            1325,
            [=[
 o]=],
        },
        {
            1207,
            1308,
            [=[
]=],
        },
        {
            1125,
            1205,
            [=[
y]=],
        },
        {
            1116,
            1123,
            [=[
t]=],
        },
        {
            1108,
            1113,
            [=[
]=],
        },
        {
            1054,
            1100,
            [=[
 ]=],
        },
        {
            1051,
            1052,
            [=[
e]the]=],
        },
        {
            1043,
            1048,
            [=[
y.st]=],
        },
        {
            1037,
            1041,
            [=[
t]=],
        },
        {
            1033,
            1035,
            [=[
s[e]=],
        },
        {
            1020,
            1029,
            [=[
St]=],
        },
        {
            1016,
            1016,
            [=[
ded==nil and vers]=],
        },
        {
            1015,
            1014,
            [=[
 lo]=],
        },
        {
            1012,
            1012,
            [=[
d==true ]=],
        },
        {
            1008,
            1009,
            [=[
if loa]=],
        },
        {
            977,
            998,
            [=[
]=],
        },
        {
            949,
            975,
            [=[
]=],
        },
        {
            948,
            947,
            [=[
y.load]=],
        },
        {
            946,
            946,
            [=[
ent]=],
        },
        {
            944,
            944,
            [=[
loaded]=],
        },
        {
            903,
            928,
            [=[
]=],
        },
        {
            851,
            901,
            [=[
]=],
        },
        {
            843,
            849,
            [=[
]=],
        },
        {
            835,
            841,
            [=[
]=],
        },
        {
            828,
            832,
            [=[
if entry]=],
        },
        {
            811,
            821,
            [=[
y]=],
        },
        {
            796,
            807,
            [=[
]=],
        },
        {
            793,
            794,
            [=[
For(]=],
        },
        {
            771,
            785,
            [=[
]=],
        },
        {
            755,
            754,
            [=[

local versionStates={loaded=true,connected=true,disabled=true,incompatible=true}]=],
        },
        {
            751,
            751,
            [=[
]=],
        },
        {
            692,
            696,
            [=[
]=],
        },
        {
            680,
            680,
            [=[
fe]=],
        },
        {
            677,
            678,
            [=[
]=],
        },
        {
            674,
            675,
            [=[
]=],
        },
        {
            654,
            653,
            [=[
e.lua_editor~='plain']=],
        },
        {
            653,
            652,
            [=[
fi]=],
        },
        {
            613,
            650,
            [=[
p]=],
        },
        {
            542,
            600,
            [=[
d]=],
        },
        {
            532,
            540,
            [=[
e]=],
        },
        {
            524,
            530,
            [=[
ue]=],
        },
        {
            522,
            521,
            [=[
g==]=],
        },
        {
            514,
            520,
            [=[
i]=],
        },
        {
            512,
            512,
            [=[
ghligh]=],
        },
        {
            503,
            510,
            [=[
]=],
        },
        {
            502,
            501,
            [=[
ive_]=],
        },
        {
            498,
            499,
            [=[
urn profile.lua_n]=],
        },
        {
            496,
            496,
            [=[
n re]=],
        },
        {
            495,
            494,
            [=[
h]=],
        },
        {
            485,
            491,
            [=[
ni]=],
        },
        {
            484,
            483,
            [=[
e.lua_native_highlighting~]=],
        },
        {
            483,
            482,
            [=[
fi]=],
        },
        {
            477,
            480,
            [=[
p]=],
        },
        {
            471,
            475,
            [=[
if]=],
        },
        {
            455,
            464,
            [=[
e]=],
        },
        {
            454,
            453,
            [=[
fi]=],
        },
        {
            452,
            452,
            [=[
highlighting(pr]=],
        },
        {
            291,
            436,
            [=[
]=],
        },
        {
            180,
            200,
            [=[
]=],
        },
        {
            89,
            139,
            [=[
]=],
        },
    },
}

records["UI/lua_editor.lua"] = {
    old = [=[
local addon_name,addon=...
local providers={}
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
end
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
    preferred=resolveEditor(self,preferred)
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
    if editorDisabled(self,'native') then preferred='plain' end
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
    local resolved=resolveEditor(self,preferred)
    if resolved=='LuaWorkbench' and not self:IsLuaWorkbenchIntegrationAvailable() then resolved='native' end
    if editorDisabled(self,resolved) then resolved='plain' end
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
            23641,
            23640,
            [=[
)]=],
        },
        {
            23633,
            23632,
            [=[
resolveEditor(self,]=],
        },
        {
            10398,
            10397,
            [=[
 'plain' or 'native')]=],
        },
        {
            10395,
            10395,
            [=[
a]=],
        },
        {
            10387,
            10386,
            [=[
resolveEditor(self,preferred==]=],
        },
        {
            10339,
            10376,
            [=[
]=],
        },
        {
            750,
            749,
            [=[
) or not available(preferred) then preferred='native' end
    local profile=self.db and self.db.profile
    if preferred=='native' and (editorDisabled(self,'native') or profile and profile.lua_native_highlighting==false]=],
        },
        {
            609,
            608,
            [=[
name) and available(]=],
        },
        {
            496,
            495,
            [=[

    local client,clientRead
    local function available(name)
        if name~='native' and name~='plain' and type(self.GetIntegrationClientSupport)=='function' then
            if not clientRead then
                clientRead=true
                local ok,value=pcall(function()return self.Platform and self.Platform:GetClientInfo()end)
                if ok then client=value end
            end
            local ok,state=pcall(self.GetIntegrationClientSupport,self,name=='LuaWorkbench' and '!!!LuaWorkbench'or name,client)
            if ok and state=='unsupported'then return false end
        end
        return name~='LuaWorkbench' or type(self.IsLuaWorkbenchIntegrationAvailable)=='function' and self:IsLuaWorkbenchIntegrationAvailable()==true
    end]=],
        },
        {
            393,
            393,
            [=[
]=],
        },
        {
            390,
            391,
            [=[
]=],
        },
        {
            383,
            388,
            [=[
i]=],
        },
        {
            380,
            381,
            [=[
pl]=],
        },
        {
            377,
            377,
            [=[
~]=],
        },
        {
            370,
            371,
            [=[
and]=],
        },
        {
            365,
            367,
            [=[
o]=],
        },
        {
            364,
            363,
            [=[
u]=],
        },
        {
            362,
            362,
            [=[
]=],
        },
        {
            359,
            359,
            [=[
~]=],
        },
        {
            354,
            354,
            [=[
]=],
        },
        {
            184,
            194,
            [=[
]=],
        },
        {
            182,
            182,
            [=[
r]=],
        },
        {
            177,
            180,
            [=[
n]=],
        },
        {
            173,
            175,
            [=[
]=],
        },
        {
            145,
            164,
            [=[
]=],
        },
        {
            141,
            143,
            [=[
]=],
        },
        {
            137,
            139,
            [=[
fie]=],
        },
        {
            121,
            134,
            [=[
]=],
        },
        {
            117,
            119,
            [=[
]=],
        },
        {
            115,
            115,
            [=[
unknown id]=],
        },
        {
            114,
            113,
            [=[
;]=],
        },
        {
            102,
            102,
            [=[
 also cover registered]=],
        },
        {
            86,
            92,
            [=[
]=],
        },
        {
            76,
            84,
            [=[
]=],
        },
        {
            50,
            72,
            [=[
S]=],
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
        elseif key=='lua_editor_disabled' then
            if type(item)~='table' or getmetatable(item)~=nil then return false end
            for name,disabled in pairs(item) do if (name~='native' and name~='LuaWorkbench') or disabled~=true then return false end end
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
            6369,
            6368,
            [=[

           ]=],
        },
        {
            6328,
            6328,
            [=[
]=],
        },
        {
            6325,
            6326,
            [=[
]=],
        },
        {
            6324,
            6323,
            [=[
=='plai]=],
        },
        {
            6321,
            6322,
            [=[
 nam]=],
        },
        {
            6317,
            6318,
            [=[
to' ]=],
        },
        {
            6315,
            6315,
            [=[
a]=],
        },
        {
            6312,
            6312,
            [=[
:find('%S') or name=]=],
        },
        {
            6299,
            6306,
            [=[
]=],
        },
        {
            6298,
            6297,
            [=[
me>128 or no]=],
        },
        {
            6296,
            6295,
            [=[
string' or #]=],
        },
        {
            6293,
            6292,
            [=[
)]=],
        },
        {
            6288,
            6287,
            [=[
count>64 or type]=],
        },
        {
            6284,
            6283,
            [=[

                count=count+1
               ]=],
        },
        {
            6249,
            6248,
            [=[
local count=0
            ]=],
        },
        {
            79,
            78,
            [=[
',lua_native_highlighting='boolean]=],
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
    local scopes={Integrations={profile={'lua_editor','lua_editor_disabled','lua_line_numbers','questie_enabled'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
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
            2530,
            2529,
            [=[
','lua_native_highlighting]=],
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
    source = dofile('tests/fixtures/restore_masque_preview.lua')(path, source)
    local record = assert(records[path], 'unsupported integration pills inverse path')

    if source == record.old then
        return source
    end

    assert(source == record.new, 'integration pills inverse requires exact complete successor: ' .. path)
    return record.old
end
