local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local function clean(text)
    return type(text)=="string" and text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","") or text
end
local function hideTooltip(popup)
    if GameTooltip then for _,row in ipairs(popup.rows) do
        if GameTooltip:IsOwned(row) then GameTooltip:Hide();break end
    end end
end
local function newPopup(widget)
    local popup=CreateFrame("Frame",nil,UIParent)
    popup:SetFrameStrata("TOOLTIP");popup:SetClampedToScreen(true);popup:EnableMouse(true);popup.rows={}
    popup.footer=popup:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    popup.footer:SetPoint("BOTTOMLEFT",10,10);popup.footer:SetJustifyH("LEFT")
    for index=1,12 do
        local row=CreateFrame("Button",nil,popup);popup.rows[index]=row
        row:SetPoint("TOPLEFT",8,-8-(index-1)*26);row:SetPoint("TOPRIGHT",-8,-8-(index-1)*26);row:SetHeight(26)
        row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        row.text:SetPoint("LEFT",30,0);row.text:SetPoint("RIGHT",-4,0);row.text:SetJustifyH("LEFT")
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(20,20);row.icon:SetPoint("LEFT",3,0)
        row.selection=row:CreateTexture(nil,"BACKGROUND");row.selection:SetAllPoints(row)
        row.selection:SetColorTexture(.357,.753,.922,.2)
    end
    addon:MakeWindowOpaque(popup);popup:Hide();widget.rmSpellPopup=popup
    return popup
end

-- The ordinary field remains compatible with existing data callbacks. Search,
-- suggestions and exact selection belong to RM, not the shared ID scanner.
function addon:CreateReferenceEditBox(kind,initialSpell)
    local provider=self:GetReferenceProvider(kind)
    if type(initialSpell)=="number" then provider.index(initialSpell)
    elseif type(initialSpell)=="string" then provider.resolve(initialSpell) end
    local widget=self:CreateConditionEditBox()
    -- Suggestions temporarily decorate a native text lease. Restore its exact
    -- scripts and methods before it returns to the ordinary input pool.
    local field=widget.editbox
    local popup=widget.rmSpellPopup or newPopup(widget)
    local dropHint=field.rmDropHint or field:CreateFontString(nil,'OVERLAY','GameFontDisableSmall');field.rmDropHint=dropHint;dropHint:ClearAllPoints();dropHint:SetPoint('LEFT',5,0);dropHint:SetPoint('RIGHT',-5,0);dropHint:SetJustifyH('LEFT');dropHint:SetText(provider.kind=='item' and L['Search or drag an item here'] or L['Search or drag a spell here'])
    local alive,setting=true,false
    local acceptedText=""
    local acceptedID
    local selected,navigated=1,false
    local matches={}
    widget.rmSpellSearchActive=true
    widget:SetMaxLetters(256)
    local originalText,originalRelease,originalReferenceID,originalCommit=widget.SetText,widget.OnRelease,widget.GetReferenceID,widget.CommitPending
    local scripts={}
    local function install(frame,event,handler)
        local binding={frame=frame,event=event,original=frame:GetScript(event)}
        binding.handler=addon:SetUIScript(frame,event,handler);scripts[#scripts+1]=binding
    end
    local function settings()
        return {spec=(kind=="Spec_EditBox" or kind=="Totem_EditBox") and widget:GetUserData("spec") or nil,
            nameContains=kind=="Totem_EditBox" and L["Totem"] or nil,
            norank=widget:GetUserData("norank")==true,inventory=provider.inventory,limit=12}
    end
    local function hide()
        hideTooltip(popup);popup:Hide()
    end
    widget.SetText=function(self,text)
        local id=type(text)=='number' and text or type(text)=='string' and (tonumber(text) or tonumber(text:match('|H'..provider.kind..':(%d+)')))
        acceptedID=id
        if id then text=provider.name(id,self:GetUserData('norank')) or provider.missing end
        setting=true;originalText(self,clean(text));setting=false
        acceptedText=field:GetText();if acceptedText=='' then dropHint:Show() else dropHint:Hide() end;hide()
    end
    widget.GetReferenceID=function() if alive and field:GetText()==acceptedText then return acceptedID end end
    local function highlight()
        for index,row in ipairs(popup.rows) do
            if index==selected and matches[index] then row.selection:Show() else row.selection:Hide() end
        end
    end
    local function commit(id)
        if not alive or widget.disabled then return end
        local resolved=provider.resolve(tostring(id),settings())
        if not resolved then return end
        local name=provider.name(resolved,widget:GetUserData("norank"))
        widget:SetText(resolved)
        widget:Fire("OnEnterPressed",tostring(resolved))
        -- A callback may rebuild/release this field; never touch its next owner.
        if alive then widget:ClearFocus() end
    end
    local function query()
        if not alive or setting or widget.disabled or not field:HasFocus() then return end
        if acceptedID and field:GetText()==acceptedText then
            local name=provider.name(acceptedID,widget:GetUserData('norank'))
            if name and name~=acceptedText then widget:SetText(acceptedID) end
        end
        local text=field:GetText();if text=='' then dropHint:Show() else dropHint:Hide() end;if text==provider.missing then text='' end;local opts=settings()
        local rows,status=provider.search(text,opts)
        if rows and #rows==0 and text~="" then
            local id=provider.resolve(text,opts)
            local name=id and provider.name(id,true)
            if name then rows,status=provider.search(name,opts) end
        end
        matches=rows or {};selected=1;navigated=false
        for index,row in ipairs(popup.rows) do
            local entry=matches[index];row.referenceID=entry and entry.id;row.spellID=provider.kind=='spell' and row.referenceID or nil;row.itemID=provider.kind=='item' and row.referenceID or nil
            if entry then
                row.text:SetText(entry.display)
                if entry.icon then row.icon:SetTexture(entry.icon);row.icon:Show() else row.icon:Hide() end
                row:Show()
            else row:Hide() end
        end
        local footer
        if provider.kind=="item" then footer=#matches==0 and L["No matching items."] or L["Click a result or enter an item name, ID or link."]
        elseif status and status.reason then footer=L["Spell search data is unavailable."]
        elseif #matches==0 then footer=L["No matching spells."]
        elseif status and status.more then footer=L["More matches available. Keep typing to narrow the search."]
        elseif opts.spec~=nil then footer=L["Spells from this spellbook. Click a result or press Enter."]
        else footer=L["Known and referenced spells. Enter a spell ID or link to find another spell."] end
        popup.footer:SetText(footer..'\n'..(provider.kind=='item' and L['Search or drag an item here'] or L['Search or drag a spell here']))
        local width=math.max(360,field:GetWidth()+16)
        popup:SetSize(width,math.max(1,#matches)*26+60);popup.footer:SetWidth(width-20)
        popup:ClearAllPoints();popup:SetPoint("TOPLEFT",field,"BOTTOMLEFT",-6,-4)
        highlight();popup:Show()
    end
    local function enter()
        if not alive or widget.disabled then return end
        local text=field:GetText()
        if text=="" then
            widget:SetText("");widget:Fire("OnEnterPressed","")
            if alive then widget:ClearFocus() end
            return
        end
        local id=not navigated and (text==acceptedText and acceptedID or provider.resolve(text,settings())) or nil
        if id then commit(id)
        elseif matches[selected] then commit(matches[selected].id)
        else query() end
    end
    widget.CommitPending=function(self)
        if not alive or self.disabled or not self:IsPending() then return true end
        enter();return field:GetText()==acceptedText or nil
    end
    local onText=field:GetScript("OnTextChanged")
    install(field,"OnTextChanged",function(self,...)
        if not alive then return end
        if onText then onText(self,...) end
        if alive then query() end
    end)
    local onFocus=field:GetScript("OnEditFocusGained")
    install(field,"OnEditFocusGained",function(self,...)
        if not alive then return end
        if onFocus then onFocus(self,...) end
        if alive then query() end
    end)
    local onLost=field:GetScript("OnEditFocusLost")
    install(field,"OnEditFocusLost",function(self,...)
        if not alive then return end
        if alive then widget:SetText(acceptedID or acceptedText);hide() end
        if onLost then onLost(self,...) end
    end)
    install(field,"OnEnterPressed",enter)
    install(field,"OnEscapePressed",function() if alive then hide();widget:ClearFocus() end end)
    install(field,"OnTabPressed",function(_,reverse)
        if not alive or widget.disabled then return end
        if #matches>0 then selected=((selected-1+(reverse and -1 or 1))%#matches)+1;navigated=true;highlight() end
    end)
    local function drag()
        if not alive or type(GetCursorInfo)~="function" then return end
        local observed={pcall(GetCursorInfo)}
        local ok,cursor,first,third=observed[1],observed[2],observed[3],observed[5]
        if not ok or not addon.Platform:CanReadValue(cursor) then return end
        local id
        if provider.kind=="item" and cursor=="item" then id=first elseif provider.kind=="spell" and cursor=="spell" then id=third elseif provider.kind=="spell" and cursor=="petaction" then id=first end
        if not addon.Platform:CanReadValue(id) or type(id)~="number" then return end
        if provider.resolve(tostring(id),settings()) then
            commit(id);if type(ClearCursor)=="function" then ClearCursor() end
        end
    end
    install(field,"OnReceiveDrag",drag);install(field,"OnMouseDown",drag)
    local onHide=widget.frame:GetScript("OnHide")
    install(widget.frame,"OnHide",function(self,...)
        if not alive then return end
        hide();if onHide then onHide(self,...) end
    end)
    for _,row in ipairs(popup.rows) do
        addon:SetUIScript(row,"OnMouseDown",function(self,button) if button=="LeftButton" and self.referenceID then commit(self.referenceID) end end)
        addon:SetUIScript(row,"OnEnter",function(self)
            if self.referenceID and GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(provider.kind..":"..self.referenceID) end
        end)
        addon:SetUIScript(row,"OnLeave",function(self) if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    end
    widget.OnRelease=function(self,...)
        alive=false;hide();dropHint:Hide();self.rmSpellSearchActive=nil
        for _,binding in ipairs(scripts) do
            if binding.frame:GetScript(binding.event)==binding.handler then binding.frame:SetScript(binding.event,binding.original) end
        end
        for _,row in ipairs(popup.rows) do row.spellID=nil;row.itemID=nil;row.referenceID=nil;addon:SetUIScript(row,"OnMouseDown",nil);addon:SetUIScript(row,"OnEnter",nil);addon:SetUIScript(row,"OnLeave",nil) end
        self.SetText,self.OnRelease,self.GetReferenceID,self.CommitPending=originalText,originalRelease,originalReferenceID,originalCommit
        if originalRelease then return originalRelease(self,...) end
    end
    return widget
end

function addon:CreateSpellEditBox(kind,initialSpell) return self:CreateReferenceEditBox(kind,initialSpell) end
function addon:CreateItemEditBox(kind,initialItem) return self:CreateReferenceEditBox(kind or 'Item_EditBox',initialItem) end
