local addon_name, addon = ...
local L = LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Popups are outside scroll children. Leases also protect rows recycled inside
-- one opening, and active color children retain their original anchor frame.
function addon:CreateWorkbenchSelector()
    local menu = { frame = CreateFrame('Frame', nil, UIParent), rows = {}, serial = 0, revision = 0 }
    local frame = menu.frame
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    self:MakeWindowOpaque(frame)
    menu.search = self:CreateWorkbenchEditBox(frame)
    self:AttachWorkbenchSearchHint(menu.search)
    menu.search:SetPoint('TOPLEFT', 8, -8)
    menu.search:SetSize(284, 24)
    menu.scroll = self:CreateWorkbenchScrollFrame(frame)
    menu.scroll:SetPoint('TOPLEFT', 8, -40)
    menu.scroll:SetSize(272, 210)
    menu.child = CreateFrame('Frame', nil, menu.scroll)
    menu.child:SetWidth(272)
    menu.scroll:SetScrollChild(menu.child)

    function menu:IsValid()
        return self.active and self.valid and self.valid()
    end

    function menu:IsPinned(row)
        return row.colorOwner and row.colorOwner.frame and row.colorOwner.frame:IsShown()
    end

    function menu:Retire(row)
        if row.colorLease then row.colorLease.active = false end
        row.menuLease = nil
        row.menuEntry = nil
        row.menuIndex = nil
        row.colorOwner = nil
        row.colorLease = nil
        if self.colorRow == row then self.colorRow = nil end
        addon:SetUIScript(row, 'OnClick', nil)

        if row.colorButton then
            addon:SetUIScript(row.colorButton, 'OnClick', nil)
            row.colorButton:Hide()
        end

        row:Hide()
    end

    function menu:CloseColor()
        local row = self.colorRow
        self.colorRow = nil
        local owner = row and row.colorOwner
        local lease = row and row.colorLease

        if owner and owner.frame and owner.frame:IsShown() and owner.frame.rmSelectorColorSession == lease then
            if type(owner.Close) == 'function' then
                owner:Close(true)
            else
                owner.frame:Hide()
            end
        end

        if lease then lease.active = false end

        if row then
            row.colorOwner = nil
            row.colorLease = nil
        end
    end

    function menu:Hide()
        frame:Hide()
    end

    function menu:Bind(row, entry, index)
        local lease = {}
        local serial, revision = self.serial, self.revision
        row.menuLease = lease
        row.menuEntry = entry
        row.menuIndex = index
        row.menuRevision = revision

        local function alive()
            return menu:IsValid()
                and frame:IsShown()
                and menu.serial == serial
                and menu.revision == revision
                and row.menuLease == lease
        end

        local width = self.contentWidth
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', 0, -(index - 1) * 21)
        row:SetSize(width, 20)
        row:SetText(entry.text)
        row:SetSelected(entry.selected or entry.value == self.selected)
        addon:AlignWorkbenchTextLeft(row, entry.icon and 26 or 4)

        if entry.icon then
            row.icon:SetTexture(entry.icon)
            row.icon:Show()
        else
            row.icon:Hide()
        end

        if entry.color and entry.chooseColor then
            if not row.colorButton then
                local swatch = addon:CreateWorkbenchButton(row, '', 14)
                swatch:SetSize(14, 14)
                swatch:SetPoint('RIGHT', -3, 0)
                swatch.fill = swatch:CreateTexture(nil, 'ARTWORK')
                swatch.fill:SetAllPoints(swatch)
                row.colorButton = swatch
            end

            local swatch = row.colorButton
            local rgba = entry.color
            swatch.fill:SetColorTexture(rgba.r, rgba.g, rgba.b, rgba.a or 1)
            swatch.tooltip = L['Tag color']
            swatch:Show()
            row:GetFontString():SetWidth(width - (entry.icon and 48 or 26))

            addon:SetUIScript(swatch, 'OnClick', function()
                if alive() then
                    menu:CloseColor()
                    local colorLease = { active = true }
                    row.colorLease = colorLease

                    local function colorValid()
                        return colorLease.active and menu:IsValid() and menu.serial == serial and row.menuLease == lease
                    end

                    local owner = entry.chooseColor(
                        swatch,
                        function(color)
                            if alive() then swatch.fill:SetColorTexture(color.r, color.g, color.b, color.a or 1) end
                        end,
                        colorValid
                    )

                    if
                        alive() and type(owner) == 'table' and owner.frame and type(owner.frame.IsShown) == 'function'
                    then
                        local child = owner.frame
                        local previous = child.rmSelectorColorSession
                        if previous then previous.active = false end
                        child.rmSelectorColorSession = colorLease

                        if not child.rmSelectorColorHook then
                            child.rmSelectorColorHook = true

                            child:HookScript('OnHide', function()
                                local current = child.rmSelectorColorSession

                                if current then
                                    current.active = false
                                    child.rmSelectorColorSession = nil
                                end
                            end)
                        end

                        row.colorOwner = owner
                        menu.colorRow = row
                    end
                end
            end)
        elseif row.colorButton then
            row.colorButton:Hide()
            addon:SetUIScript(row.colorButton, 'OnClick', nil)
        end

        if entry.disabled then
            row:Disable()
        else
            row:Enable()
        end

        -- A section heading in a long list is a row that cannot be picked.
        local text = row:GetFontString()

        if entry.header then
            row:SetAlpha(1)
            text:SetTextColor(1, .82, 0)
        else
            text:SetTextColor(1, 1, 1)
        end

        local anchor, inline, changed = self.anchor, self.inline, self.changed

        addon:SetUIScript(row, 'OnClick', function()
            if alive() then
                menu:Hide()

                if not inline and anchor.SetText and anchor.GetFontString then
                    addon:PaintSelectorSelection(anchor, entry, entry.text)
                end

                changed(entry.value, entry.text, entry.icon)
            end
        end)

        row:Show()
    end

    function menu:RefreshViewport()
        if not self:IsValid() or self.rebuilding or self.refreshing then return end
        self.refreshing = true
        local binding

        local ok, why = pcall(function()
            local first, last = addon:GetWorkbenchVisibleRowRange(
                #self.matches,
                21,
                self.scroll.workbenchBar:GetValue(),
                self.scroll:GetHeight(),
                42
            )

            local bound = {}

            for _, row in ipairs(self.rows) do
                if row.menuLease then
                    if row.menuRevision == self.revision and row.menuIndex >= first and row.menuIndex <= last then
                        bound[row.menuIndex] = row
                        row:Show()
                    elseif self:IsPinned(row) then
                        row:Hide()
                    else
                        self:Retire(row)
                    end
                end
            end

            local free = 1

            for index = first, last do
                if not bound[index] then
                    while self.rows[free] and self.rows[free].menuLease do
                        free = free + 1
                    end

                    local row = self.rows[free]

                    if not row then
                        row = addon:CreateWorkbenchButton(self.child, '', self.contentWidth)
                        self.rows[free] = row
                        row.icon = row:CreateTexture(nil, 'ARTWORK')
                        row.icon:SetSize(18, 18)
                        row.icon:SetPoint('LEFT', 2, 0)
                    end

                    binding = row
                    self:Bind(row, self.matches[index], index)
                    binding = nil
                end
            end
        end)

        self.refreshing = nil

        if not ok then
            if binding then pcall(self.Retire, self, binding) end
            error(why, 0)
        end
    end

    function menu:Refilter()
        if not self:IsValid() then return end
        self.rebuilding = true
        self.revision = self.revision + 1

        for _, row in ipairs(self.rows) do
            if row.menuLease and not self:IsPinned(row) then self:Retire(row) end
        end

        local query = (self.search:GetText() or ''):lower()
        self.matches = {}

        for _, entry in ipairs(self.entries) do
            if tostring(entry.text):lower():find(query, 1, true) then self.matches[#self.matches + 1] = entry end
        end

        local height = math.max(21, math.min(10, #self.matches) * 21)
        self.contentWidth = self.width - (#self.matches > 10 and 30 or 16)
        self.scroll:SetSize(self.contentWidth, height)
        self.child:SetWidth(self.contentWidth)
        frame:SetHeight((self.inline and 8 or 40) + height + 8)
        self.child:SetHeight(math.max(1, #self.matches * 21))
        self.scroll:UpdateWorkbenchScroll()
        self.scroll.workbenchBar:SetValue(0)
        self.rebuilding = nil
        self:RefreshViewport()
    end

    function menu:Open(anchor, entries, selected, changed, valid, inline)
        if not inline and frame:IsShown() and self.anchor == anchor then
            self:Hide()
            return
        end

        if frame:IsShown() then self:Hide() end
        self.serial = self.serial + 1
        self.active = true
        self.valid = valid
        self.anchor = anchor
        self.entries = entries
        self.selected = selected
        self.changed = changed
        self.inline = inline
        frame:ClearAllPoints()
        frame:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -2)
        self.width = math.max(180, math.min(720, anchor:GetWidth()))
        frame:SetWidth(self.width)
        self.search:SetWidth(self.width - 16)
        self.search:SetText('')
        self.scroll:ClearAllPoints()
        self.scroll:SetPoint('TOPLEFT', 8, inline and -8 or -40)

        if inline then
            self.search:ClearFocus()
            self.search:Hide()
        else
            self.search:Show()
        end

        local serial = self.serial

        addon:SetUIScript(self.search, 'OnTextChanged', function()
            if menu.serial == serial then menu:Refilter() end
        end)

        frame:Show()
        self:Refilter()
        self.mouseDown = IsMouseButtonDown and IsMouseButtonDown('LeftButton')

        addon:SetUIScript(frame, 'OnUpdate', function()
            if menu.serial ~= serial then return end

            if not menu:IsValid() then
                menu:Hide()
                return
            end

            if menu.colorRow and not menu:IsPinned(menu.colorRow) then
                menu:CloseColor()
                menu:RefreshViewport()
            end

            local down = IsMouseButtonDown and IsMouseButtonDown('LeftButton')
            local over = InputUtil and InputUtil.IsMouseOver or MouseIsOver
            local child = menu.colorRow and menu.colorRow.colorOwner

            if
                down
                and not menu.mouseDown
                and over
                and not over(frame)
                and not over(anchor)
                and not (child and child.frame and over(child.frame))
            then
                menu:Hide()
            end

            menu.mouseDown = down
        end)

        addon:OpenPopup(self, anchor)
        if not inline and self:IsValid() then self.search:SetFocus() end
    end

    function menu:Release()
        self.serial = self.serial + 1
        self:Hide()
        if self.OnRelease then self:OnRelease() end
    end

    self:SetUIScript(menu.search, 'OnEscapePressed', function() menu:Hide() end)

    self:SetUIScript(frame, 'OnHide', function()
        menu.active = false
        menu.serial = menu.serial + 1
        menu:CloseColor()

        for _, row in ipairs(menu.rows) do
            menu:Retire(row)
        end

        menu.search:ClearFocus()
        addon:SetUIScript(frame, 'OnUpdate', nil)
    end)

    menu.scroll.workbenchBar:HookScript('OnValueChanged', function() menu:RefreshViewport() end)
    frame:Hide()
    return menu
end

-- Native field selector uses the shared bounded workbench menu.
---@class RMConditionSelector: RMConditionWidget
---@field SetList fun(self: RMConditionSelector, values: table, order?: table)
---@field SetValue fun(self: RMConditionSelector, value: any)
---@field GetValue fun(self: RMConditionSelector): any
---@field SetLabel fun(self: RMConditionSelector, text: string)
---@field SetDisabled fun(self: RMConditionSelector, disabled: boolean)
---@field SetText fun(self: RMConditionSelector, text: string)
local function selectorWidget()
    local w={type='RM-Selector',list={},order={},disabled=false}
    local frame=CreateFrame('Frame',nil,UIParent);w.frame=frame;frame:SetSize(220,44)
    local caption=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');w.caption=caption;caption:SetPoint('TOPLEFT',0,0);caption:SetPoint('TOPRIGHT',0,0);caption:SetHeight(18);caption:SetJustifyH('LEFT')
    local button=addon:CreateWorkbenchLabeledIconButton(frame,'chevron-down','',220);w.button=button;button:SetPoint('TOPLEFT',0,-20);button:SetPoint('TOPRIGHT',0,-20)
    local popup=addon:CreateWorkbenchSelector();w.selector=popup
    function w:OnAcquire() self.alive=true;self.list={};self.order={};self:SetDisabled(false);self:SetLabel('');self:SetValue(nil);self:SetWidth(220);self:SetHeight(44) end
    function w:OnRelease() self.alive=false;popup:Release();self.list={};self.order={};self.value=nil end
    function w:SetLabel(text) caption:SetText(text or '');local has=text and text~='';if has then caption:Show() else caption:Hide() end;button:ClearAllPoints();button:SetPoint('TOPLEFT',0,has and -20 or 0);button:SetPoint('TOPRIGHT',0,has and -20 or 0);self:SetHeight(has and 44 or 24) end
    function w:SetText(text) button:SetText(text or L['Select']);addon:AlignWorkbenchTextLeft(button,26) end
    function w:SetValue(value) self.value=value;local entry=self.list[value];if type(entry)=='table' then addon:PaintSelectorSelection(button,entry,entry.text) else self:SetText(entry);if button.valueIcon then button.valueIcon:Hide() end end end
    function w:GetValue() return self.value end
    function w:SetList(values,order)
        self.list=values or {};self.order={};if order then for _,id in ipairs(order) do self.order[#self.order+1]=id end else for id in pairs(self.list) do self.order[#self.order+1]=id end;table.sort(self.order,function(a,b) return tostring(type(self.list[a])=='table' and self.list[a].text or self.list[a])<tostring(type(self.list[b])=='table' and self.list[b].text or self.list[b]) end) end;self:SetValue(self.value)
    end
    function w:SetDisabled(value) self.disabled=value==true;if self.disabled then button:Disable();popup:Hide() else button:Enable() end end
    function w:ClearFocus() popup:Hide() end
    addon:SetUIScript(button,'OnClick',function()
        if not w.alive or w.disabled then return end
        if popup.frame:IsShown() then popup:Hide();return end
        local entries={};for _,id in ipairs(w.order) do local item=w.list[id];local record=type(item)=='table' and item or nil;entries[#entries+1]={value=id,text=record and record.text or item,icon=record and record.icon or nil,disabled=record and record.disabled or nil,header=record and record.header or nil} end
        local lifetime=w.userdata
        popup:Open(button,entries,w.value,function(value) if value~=w.value then w:SetValue(value);w:Fire('OnValueChanged',value) end end,function() return w.alive and w.userdata==lifetime and not w.disabled end)
    end)
    addon:SetUIScript(frame,'OnHide',function() popup:Hide() end)
    ---@cast w RMConditionWidget
    return addon:RegisterConditionWidget(w)
end

---@return RMConditionSelector
function addon:CreateConditionDropdown()
    local w=addon:AcquireConditionWidget('RM-Selector',selectorWidget)
    ---@cast w RMConditionSelector
    return w
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="CreateConditionDropdown" then return addon.CreateConditionDropdown end
        if name=="selectorWidget" then return selectorWidget end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("UI/selector.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["UI/selector.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
