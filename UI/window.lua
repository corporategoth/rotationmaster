local addon_name,addon=...
local scaledWindows=setmetatable({}, {__mode='k'})
local function scaleValue(value)
    if type(value)~='number' or value~=value or value<.7 or value>1.3 then return 1 end
    return math.floor(value*100+.5)/100
end
function addon:ApplyWorkbenchScale(frame)
    if frame and frame.GetParent and frame:GetParent()==UIParent and frame.SetScale then
        scaledWindows[frame]=true
        frame:SetScale(scaleValue(self.db and self.db.global and self.db.global.uiScale))
    end
end
function addon:ScaleWorkbenchWindows(value)
    for frame in pairs(scaledWindows) do frame:SetScale(scaleValue(value)) end
end

-- Apply only to RM-owned dialogs. An opaque layer beneath their native art
-- keeps overlapping configuration windows readable without modifying AceGUI.
function addon:MakeWindowOpaque(widget)
    local frame=widget and (widget.frame or widget)
    if not frame or not frame.CreateTexture then return end
    if not frame.rmOpaqueBackground then
        local background=frame:CreateTexture(nil,"BACKGROUND",nil,-8)
        background:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-8)
        background:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-8,8)
        background:SetColorTexture(0.035,0.045,0.055,1)
        frame.rmOpaqueBackground=background
    end
    if not widget.rmOpaqueActive and widget.frame then
        local original=widget.OnRelease
        local alpha=frame.GetAlpha and frame:GetAlpha() or 1
        local previousScale=frame.GetScale and frame:GetScale() or 1
        widget.rmOpaqueActive=true
        widget.OnRelease=function(control,...)
            frame.rmOpaqueBackground:Hide()
            if frame.SetAlpha then frame:SetAlpha(alpha) end
            if scaledWindows[frame] then scaledWindows[frame]=nil;frame:SetScale(previousScale) end
            control.rmOpaqueActive=nil;control.OnRelease=original
            if original then return original(control,...) end
        end
    end
    if frame.SetAlpha then frame:SetAlpha(1) end
    self:ApplyWorkbenchScale(frame)
    frame.rmOpaqueBackground:Show()
end

-- One standard Escape target closes the frontmost RM window. Registering every
-- dialog separately would let one Escape close its underlying configuration too.
-- Frames remain private to their owners; pooled controls leave this registry.
local escapeName="RotationMasterFrontmostDialog"
local escapeProxyName="RotationMasterEscapeTarget"
local dialogs={}
local watcher
local escapeProxy
local function updateEscapeTarget()
    local target,level,selected
    for _,entry in ipairs(dialogs) do
        if entry.frame:IsShown() then
            local current=entry.frame:GetFrameLevel()
            if not level or current>=level then target,level,selected=entry.frame,current,entry end
        end
    end
    _G[escapeName]=target
    if escapeProxy then
        escapeProxy.target=selected;escapeProxy.syncing=true
        if target then escapeProxy:Show() else escapeProxy:Hide() end
        escapeProxy.syncing=false
    end
    if watcher then
        if target then watcher:Show() else watcher:Hide() end
    end
end
local function remove(entry)
    for index,current in ipairs(dialogs) do
        if current==entry then table.remove(dialogs,index);break end
    end
end
local function present(entry)
    remove(entry)
    local level=entry.level
    for _,current in ipairs(dialogs) do
        if current.frame:IsShown() then level=math.max(level,current.frame:GetFrameLevel()+100) end
    end
    dialogs[#dialogs+1]=entry
    entry.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    entry.frame:SetFrameLevel(level)
    entry.frame:Raise()
    updateEscapeTarget()
end
function addon:RegisterWindowForEscape(widget)
    local frame=widget and (widget.frame or widget);if frame then frame.rmEscapeOwner=widget end
    if type(UISpecialFrames)~="table" or not frame or not frame.GetScript or not frame.IsShown then return false end
    if widget.rmEscapeEntry then present(widget.rmEscapeEntry);return true end
    local registered=false
    for _,name in pairs(UISpecialFrames) do if name==escapeProxyName then registered=true;break end end
    if not registered then UISpecialFrames[#UISpecialFrames+1]=escapeProxyName end
    if not escapeProxy then
        -- CloseSpecialWindows hides its registered Frame directly. A private
        -- proxy routes that request through the owner's guarded Hide method.
        escapeProxy=CreateFrame('Frame',escapeProxyName,UIParent);_G[escapeProxyName]=escapeProxy
        escapeProxy:EnableMouse(false);escapeProxy.syncing=true;escapeProxy:Hide();escapeProxy.syncing=false
        escapeProxy:SetScript('OnHide',function()
            if escapeProxy.syncing or escapeProxy.closing then return end
            local target=escapeProxy.target
            escapeProxy.closing=true
            if target then
                if type(target.widget.Hide)=='function' then target.widget:Hide() else target.frame:Hide() end
            end
            escapeProxy.closing=false;updateEscapeTarget()
        end)
    end
    if not watcher then
        watcher=CreateFrame("Frame",nil,UIParent)
        -- Native SetToplevel can raise any already-shown window on a child
        -- click without OnShow. Observe only RM roots while they are open.
        watcher:SetScript("OnUpdate",updateEscapeTarget)
    end
    local entry={frame=frame,widget=widget,level=frame:GetFrameLevel(),strata=frame:GetFrameStrata()}
    widget.rmEscapeEntry=entry
    local onShow,onHide=frame:GetScript("OnShow"),frame:GetScript("OnHide")
    local show=function(self,...)
        addon:ApplyWorkbenchScale(self)
        if onShow then onShow(self,...) end
        if widget.rmEscapeEntry==entry then present(entry) end
    end
    local hide=function(self,...)
        if onHide then onHide(self,...) end
        updateEscapeTarget()
    end
    frame:SetScript("OnShow",show);frame:SetScript("OnHide",hide)
    local release=widget.OnRelease
    widget.OnRelease=function(control,...)
        remove(entry);control.rmEscapeEntry=nil;control.OnRelease=release
        if frame:GetScript("OnShow")==show then frame:SetScript("OnShow",onShow) end
        if frame:GetScript("OnHide")==hide then frame:SetScript("OnHide",onHide) end
        frame:SetFrameLevel(entry.level);frame:SetFrameStrata(entry.strata)
        updateEscapeTarget()
        if release then return release(control,...) end
    end
    present(entry)
    return true
end

-- Child editors share the main workbench chrome without navigation tabs.
function addon:EnableWorkbenchRightClickClose(frame)
    if frame.rmRightClickWatcher then return end
    local watcher=CreateFrame('Frame',nil,frame);frame.rmRightClickWatcher=watcher;watcher:EnableMouse(false)
    local rightDown=IsMouseButtonDown and IsMouseButtonDown('RightButton') or false
    local onShow=frame:GetScript('OnShow')
    addon:SetUIScript(frame,'OnShow',function(...) rightDown=IsMouseButtonDown and IsMouseButtonDown('RightButton') or false;if onShow then onShow(...) end end)
    addon:SetUIScript(watcher,'OnUpdate',function()
        local down=IsMouseButtonDown and IsMouseButtonDown('RightButton') or false
        if down and not rightDown and frame:IsShown() then
            local top=_G.RotationMasterFrontmostDialog;local focus
            if GetMouseFoci then focus=GetMouseFoci()[1] elseif GetMouseFocus then focus=GetMouseFocus() end
            local inside=false
            for _=1,100 do if focus==frame then inside=true;break end;if not focus or type(focus.GetParent)~='function' then break end;focus=focus:GetParent() end
            if inside and (not top or top==frame) then local owner=frame.rmEscapeOwner;if owner and type(owner.Hide)=='function' then owner:Hide() else frame:Hide() end end
        end
        rightDown=down
    end)
end
function addon:CreateWorkbenchDialogChrome(frame,title)
    local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
    local chrome={};self:EnableWorkbenchRightClickClose(frame)
    local function fill(parent,r,g,b)
        local art=parent:CreateTexture(nil,'BACKGROUND');art:SetAllPoints(parent);art:SetColorTexture(r,g,b,1);return art
    end
    chrome.background=fill(frame,.075,.08,.085)
    chrome.header=frame:CreateTexture(nil,'BACKGROUND');chrome.header:SetPoint('TOPLEFT',1,-1);chrome.header:SetPoint('TOPRIGHT',-1,-1);chrome.header:SetHeight(28);chrome.header:SetColorTexture(.12,.125,.13,1)
    chrome.footer=CreateFrame('Frame',nil,frame);chrome.footer:SetPoint('BOTTOMLEFT',1,1);chrome.footer:SetPoint('BOTTOMRIGHT',-1,1);chrome.footer:SetHeight(20);fill(chrome.footer,.09,.10,.11)
    for _,edge in ipairs({{'TOPLEFT','TOPRIGHT',true},{'BOTTOMLEFT','BOTTOMRIGHT',true},{'TOPLEFT','BOTTOMLEFT'},{'TOPRIGHT','BOTTOMRIGHT'}}) do
        local art=frame:CreateTexture(nil,'BORDER');art:SetColorTexture(.33,.35,.37,1);art:SetPoint(edge[1],frame,edge[1]);art:SetPoint(edge[2],frame,edge[2]);if edge[3] then art:SetHeight(1) else art:SetWidth(1) end
    end
    local function text(parent,point,x,y,value)
        local label=parent:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');label:SetPoint(point,x,y);label:SetText(value);return label
    end
    chrome.icon=frame:CreateTexture(nil,'ARTWORK');chrome.icon:SetSize(18,18);chrome.icon:SetPoint('TOPLEFT',12,-5);chrome.icon:SetTexture(addon.logoTexture)
    title:ClearAllPoints();title:SetPoint('TOPLEFT',36,-5);title:SetHeight(18);title:SetJustifyV('MIDDLE');title:SetJustifyH('LEFT');title:SetWordWrap(false);title:SetMaxLines(1);title:SetTextColor(.94,.95,.96)

    local getter=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version=type(getter)=='function' and getter(addon_name,'Version') or L['Development']
    if not version or version:find('@',1,true) then version=L['Development'] end

    local client=addon.Platform and addon.Platform.GetClientInfo and addon.Platform:GetClientInfo() or {}
    local edition=({tbc=L['TBC'],era=L['Classic Era'],progression=L['Classic Progression'],retail=L['Retail'],forever=L['Forever']})[client.family] or L['Unknown']
    chrome.version=text(frame,'TOPRIGHT',-62,-5,version..' · '..edition..(client.version and ' '..client.version or ''));chrome.version:SetWidth(220);chrome.version:SetHeight(18);chrome.version:SetJustifyH('RIGHT');chrome.version:SetJustifyV('MIDDLE');chrome.version:SetWordWrap(false);chrome.version:SetMaxLines(1)
    chrome.author=text(chrome.footer,'LEFT',8,0,string.format(L['Created by %s'],'PreZ'))
    chrome.hint=text(chrome.footer,'RIGHT',-24,0,L['Right-click to close'])
    function chrome:LayoutTitle()
        title:SetWidth(math.max(100,frame:GetWidth()-36-62-(self.contextWidth or 220)-16))
        self.author:SetWidth(math.max(40,frame:GetWidth()-self.hint:GetStringWidth()-40));self.author:SetJustifyH('LEFT');self.author:SetWordWrap(false);self.author:SetMaxLines(1)
    end
    function chrome:SetContext(heading,kind,rotationName)
        title:SetText(string.format(L['%s: %s'],addon.pretty_name or L['Rotation Master'],addon:PlainWorkbenchName(heading or '')))
        self.version:SetText(kind or L['Condition']);self.contextWidth=math.min(220,math.max(48,self.version:GetStringWidth()+8));self.version:SetWidth(self.contextWidth)
        self.author:SetText(addon:PlainWorkbenchName(rotationName or ''));self:LayoutTitle()
    end
    return chrome
end
