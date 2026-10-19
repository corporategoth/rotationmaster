local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)
local function metadata(key)
    local getter=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if getter then
        local ok,value=pcall(getter,addon_name,key)
        if ok and type(value)=="string" and value~="" then return value end
    end
    return L["Unknown"]
end
function addon:CreateSettingsLauncher()
    local frame=CreateFrame("Frame",nil,UIParent);frame.name=self.pretty_name
    local page={frame=frame}
    local function label(font)
        local result=frame:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
        result:SetJustifyH("LEFT");result:SetWordWrap(true);return result
    end
    page.icon=frame:CreateTexture(nil,"ARTWORK");page.icon:SetSize(96,96);page.icon:SetPoint("TOPLEFT",24,-24)
    page.icon:SetTexture(addon.logoArtworkTexture or addon.logoTexture)
    page.title=label("GameFontNormalLarge");page.title:SetPoint("TOPLEFT",136,-34);page.title:SetText(self.pretty_name)
    page.metadata=label("GameFontHighlightSmall");page.metadata:SetPoint("TOPLEFT",136,-64)
    page.metadata:SetText(string.format(L["Version: %s  ·  Author: %s"],metadata("Version"),metadata("Author")))
    page.description=label();page.description:SetPoint("TOPLEFT",24,-136)
    page.description:SetText(L["Configure rotations, conditions and highlights in the Rotation Master window."])
    page.open=addon:CreateWorkbenchButton(frame,L["Open Options"],380)
    page.open:SetSize(380,72);page.open:SetPoint("TOPLEFT",24,-182);page.open:SetText(L["Open Options"])
    page.open:GetFontString():SetFontObject("GameFontNormalLarge")
    addon:SetUIScript(page.open,"OnClick",function() addon:ShowConfig("Rotations") end)
    page.commands=label();page.commands:SetPoint("TOPLEFT",24,-278)
    page.commands:SetText(table.concat({L["/rm config              - Open the config dialog."],L["/rm errors              - View and copy Rotation Master errors."],
        L["/rm help                - This text."],L["/rm toggle              - Toggle between enabled and disabled."],
        L["/rm current             - Print out the name of the current rotation."]},"\n\n"))
    page.credits=label('GameFontHighlightSmall');page.credits:SetPoint('TOPLEFT',24,-460);page.credits:SetText(table.concat({L['License']..': '..metadata('X-License'),L['Credits']..': '..metadata('X-Credits'),L['Localizations']..': '..metadata('X-Localizations')},'\n'));page.credits:SetWidth(592)
    addon:SetUIScript(frame,"OnSizeChanged",function(_,width)
        local available=math.max(180,width-48)
        page.credits:SetWidth(available);page.description:SetWidth(available);page.commands:SetWidth(available)
        page.open:SetWidth(math.min(380,available));page.metadata:SetWidth(math.max(120,width-160))
    end)
    frame:SetSize(640,600);frame:Hide();return page
end
