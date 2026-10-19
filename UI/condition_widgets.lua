local _,addon=...
local available,legacyAvailable,observers={},{},{}
local function clear(t) for key in pairs(t or {}) do t[key]=nil end end
local function ace()
    if not LibStub then return end
    local ok,library=pcall(LibStub,'AceGUI-3.0',true)
    if ok then return library end
end
-- Saved factory source explicitly binds the real Ace table. Resolve it only
-- when that compatibility value is requested, never while native fields load.
function addon:GetConditionWidgetCompatibilityLibrary()
    return LibStub('AceGUI-3.0')
end
function addon:ObserveConditionWidgets(callback)
    local token={callback=callback};observers[token]=true
    return function() observers[token]=nil end
end
local function observed(widget)
    local callbacks={};for token in pairs(observers) do callbacks[#callbacks+1]=token end
    for _,token in ipairs(callbacks) do if observers[token] then token.callback(widget) end end
end
local base={}
local inherited={Release=function(self) return addon:ReleaseConditionWidget(self) end}
function base:SetCallback(event,callback)
    local lease=self.rmLease
    self.events[event]=type(callback)=='function' and function(...)
        if self.rmLease==lease and self.rmActive and (not self:IsReleasing() or event=='OnRelease') then return callback(...) end
    end or nil
end
function base:Fire(event,...)
    local callback=self.events[event];if not callback then return end
    -- Ace calls Fire directly while releasing, outside its safecall boundary.
    -- Preserve that historical protected callback contract for transferred leases.
    if self.isQueuedForRelease and not self.rmOwnedRelease then
        if addon.Diagnostics then local ok,value=addon.Diagnostics:Call({module='condition-widget',operation=event},callback,self,event,...);if ok then return value end
        else
            local ok,value=pcall(callback,self,event,...);if ok then return value end
            if geterrorhandler then pcall(geterrorhandler(),value) end
        end
        return
    end
    return callback(self,event,...)
end
function base:GetUserData(key) return self.userdata[key] end
function base:SetUserData(key,value) self.userdata[key]=value end
function base:GetUserDataTable() return self.userdata end
function base:SetParent(parent) self.parent=parent;self.frame:SetParent(parent.content or parent.frame) end
function base:SetWidth(width)
    self.sizing=true;self.frame:SetWidth(width);self.frame.width=width;self.sizing=false
    if self.OnWidthSet then self:OnWidthSet(width) end
end
function base:SetHeight(height)
    self.sizing=true;self.frame:SetHeight(height);self.frame.height=height;self.sizing=false
    if self.OnHeightSet then self:OnHeightSet(height) end
end
function base:SetFullWidth(value) self.width=value and 'fill' or nil end
function base:SetFullHeight(value) self.height=value and 'fill' or nil end
function base:IsFullWidth() return self.width=='fill' end
function base:IsFullHeight() return self.height=='fill' end
function base:SetRelativeWidth(value) assert(type(value)=='number' and value>0 and value<=1,'invalid-relative-width');self.width='relative';self.relWidth=value end
function base:IsShown() return self.frame:IsShown() end
function base:IsVisible() return self.frame:IsVisible() end
function base:SetPoint(...) return self.frame:SetPoint(...) end
function base:ClearAllPoints() self.frame:ClearAllPoints() end
function base:GetPoint(...) return self.frame:GetPoint(...) end
function base:GetNumPoints() return self.frame:GetNumPoints() end
function base:IsReleasing()
    local current=self
    for _=1,128 do if not current then return false end;if current.isQueuedForRelease then return true end;current=current.parent end
    return true
end
-- Historical Ace registrations use the same visuals and public widget shape.
-- Their leases stay with Ace; only ordinary default acquisition uses RM pools.
function addon:RegisterConditionWidget(widget,version,legacy)
    local w=widget;setmetatable(w,{__index=inherited});w.userdata={};w.events={};w.frame.obj=w;w.rmWidget=true;w.rmLegacyOwned=legacy==true;w.AceGUIWidgetVersion=version or 1
    if w.content then w.content.obj=w end
    for name,method in pairs(base) do if w[name]==nil then w[name]=method end end
    local acquire,release=w.OnAcquire,w.OnRelease
    function w:OnAcquire()
        if legacyAvailable[self.type] then legacyAvailable[self.type][self]=nil end
        self.rmLease={};self.rmActive=true;self.parent=nil;self.configure=nil;self.userdata={};self.events={};self.isQueuedForRelease=nil
        if acquire then acquire(self) end
    end
    function w:OnRelease()
        if not self.rmOwnedRelease then
            if available[self.type] then available[self.type][self]=nil end
            self.rmLegacyOwned=true;legacyAvailable[self.type]=legacyAvailable[self.type] or {};legacyAvailable[self.type][self]=true
        end
        self.rmActive=false
        if release then return release(self) end
    end
    addon:SetUIScript(w.frame,'OnSizeChanged',function(_,width,height)
        local oldWidth,oldHeight=w.frame.width,w.frame.height;w.frame.width=width;w.frame.height=height
        if not w.sizing and w.rmActive then
            if width~=oldWidth and w.OnWidthSet then w:OnWidthSet(width) end
            if height~=oldHeight and w.OnHeightSet then w:OnHeightSet(height) end
        end
    end)
    return w
end
function addon:AcquireConditionWidget(kind,constructor)
    local pool=available[kind] or {};available[kind]=pool
    local widget
    for candidate in pairs(pool) do
        if not candidate.isQueuedForRelease and not candidate.rmLegacyOwned then widget=candidate;pool[candidate]=nil;break end
    end
    if not widget then
        for candidate in pairs(legacyAvailable[kind] or {}) do
            if not candidate.isQueuedForRelease and not candidate.rmActive then
                local library=ace();if library then widget=library:Create(kind) end
                break
            end
        end
        if widget then widget.rmLegacyOwned=true else widget=constructor() end
        if not widget then error('condition-widget-construction-failed',0) end
    end
    if not widget.rmActive then
        local ok,why=pcall(widget.OnAcquire,widget)
        if not ok then widget.rmActive=false;widget.rmQuarantined=true;error(why,0) end
    end
    if kind=='RM-ConditionGroup' and self.PrepareNativeConditionTable then self:PrepareNativeConditionTable(widget) end
    observed(widget);return widget
end
function addon:ReleaseConditionWidget(widget)
    if not widget or widget.isQueuedForRelease or widget.rmWidget and not widget.rmActive then return false end
    if not widget.rmWidget or widget.rmLegacyOwned then
        local library=ace();if not library then error('legacy-widget-library-unavailable',0) end
        library:Release(widget);return true
    end
    if not widget.rmActive then return false end
    widget.isQueuedForRelease=true;widget.rmOwnedRelease=true
    if available[widget.type] then available[widget.type][widget]=nil end
    local problem
    local function perform(callback,...)
        if type(callback)~='function' then return end
        local ok,why=pcall(callback,...);if not ok then problem=problem or why end
    end
    perform(widget.PauseLayout,widget);perform(widget.frame.Hide,widget.frame)
    perform(widget.Fire,widget,'OnRelease')
    perform(widget.ReleaseChildren,widget);perform(widget.OnRelease,widget)
    widget.rmActive=false;widget.rmLease=nil;widget.parent=nil;clear(widget.userdata);clear(widget.events)
    widget.width=nil;widget.height=nil;widget.relWidth=nil;widget.relHeight=nil;widget.noAutoHeight=nil;widget.sizing=nil
    perform(widget.frame.ClearAllPoints,widget.frame);perform(widget.frame.Hide,widget.frame);perform(widget.frame.SetParent,widget.frame,UIParent)
    widget.isQueuedForRelease=nil;widget.rmOwnedRelease=nil
    if problem then widget.rmQuarantined=true;error(problem,0) end
    available[widget.type]=available[widget.type] or {};available[widget.type][widget]=true;return true
end
