local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function catalogs()
    local groups={};local labels={}
    for _,group in ipairs({{'Combat',{'Swords','Ability_DualWield'},{'Shield','Ability_Warrior_DefensiveStance'},{'Healing','Spell_Holy_Heal'}},{'Spells',{'Lightning','Spell_Nature_Lightning'},{'Buffs','Spell_Holy_PowerWordShield'},{'Fire','Spell_Fire_FlameBolt'},{'Nature','Spell_Nature_Rejuvenation'}},{'Items',{'Potions','INV_Potion_54'},{'Weapon','INV_Weapon_ShortBlade_01'},{'Armor','INV_Chest_Chain_07'},{'Food','INV_Misc_Food_15'}},{'Groups',{'Group','Spell_Holy_PrayerOfHealing02'},{'Location','INV_Misc_Map_01'},{'Book','INV_Misc_Book_09'},{'Question','INV_Misc_QuestionMark'}}}) do
        local row={name=L[group[1]],icons={}}
        for i=2,#group do local entry=group[i];local texture='Interface\\Icons\\'..entry[2];row.icons[#row.icons+1]={texture=texture,name=L[entry[1]]};labels[texture]=L[entry[1]] end;groups[#groups+1]=row
    end
    local known={name=L['Known spells'],icons={}};local seen={}
    for _,entry in ipairs(addon.SpellCatalog:GetIndexedSpells()) do if entry.icon and not seen[entry.icon] then seen[entry.icon]=true;known.icons[#known.icons+1]={texture=entry.icon,name=entry.name};labels[entry.icon]=entry.name end end
    if #known.icons>0 then groups[#groups+1]=known end
    for _,source in ipairs({{L['Game icons'],C_Macro and C_Macro.GetMacroIcons or GetMacroIcons},{L['Item icons'],C_Macro and C_Macro.GetMacroItemIcons or GetMacroItemIcons}}) do
        if type(source[2])=='function' then
            local values={};local ok,returned=pcall(source[2],values);if ok then
                if type(returned)=='table' then values=returned end
                local row={name=source[1],icons={}};local unique={}
                for _,texture in ipairs(values) do if addon:IsCategoryIcon(texture) and not unique[texture] then unique[texture]=true;local name=labels[texture] or type(texture)=='string' and (texture:match('([^\\/]+)$') or L['Game icon']):gsub('_',' ') or L['Game icon'];row.icons[#row.icons+1]={texture=texture,name=name} end end
                if #row.icons>0 then groups[#groups+1]=row end
            end
        end
    end
    return groups
end
function addon:ShowWorkbenchIconPicker(current,choose,ownerValid)
    local d=self.iconPicker
    if not d then
        d={frame=CreateFrame('Frame',nil,UIParent),buttons={},categoryButtons={}};self.iconPicker=d;local frame=d.frame;frame:SetSize(630,430);frame:SetPoint('CENTER');frame:SetFrameStrata('FULLSCREEN_DIALOG');frame:SetToplevel(true);frame:SetClampedToScreen(true);frame:EnableMouse(true);self:MakeWindowOpaque(frame)
        d.title=frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=self:CreateWorkbenchDialogChrome(frame,d.title)
        d.close=self:CreateWorkbenchIconButton(frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5);self:SetUIScript(d.close,'OnClick',function() frame:Hide() end)
        d.search=self:CreateWorkbenchEditBox(frame);d.search:SetPoint('TOPLEFT',166,-38);d.search:SetSize(432,24)
        d.prev=self:CreateWorkbenchIconButton(frame,'up',L['Previous']);d.prev.icon:SetRotation(math.pi/2);d.prev:SetPoint('BOTTOMRIGHT',-60,28)
        d.next=self:CreateWorkbenchIconButton(frame,'down',L['Next']);d.next.icon:SetRotation(math.pi/2);d.next:SetPoint('BOTTOMRIGHT',-30,28)
        d.pageLabel=frame:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');d.pageLabel:SetPoint('BOTTOMLEFT',166,32)
        self:SetUIScript(frame,'OnHide',function() d.search:ClearFocus() end);self:SetUIScript(frame,'OnMouseUp',function(_,button) if button=='RightButton' then frame:Hide() end end);frame:Hide()
    end
    d.serial=(d.serial or 0)+1;local serial=d.serial;local selectedCategory,page=1,1;d.categories=catalogs();d.search:SetText('')
    local function valid() return d.serial==serial and d.frame:IsShown() and ownerValid() end
    local function draw()
        if not valid() then return end
        d.revision=(d.revision or 0)+1;local revision=d.revision;d.matches={};local query=(d.search:GetText() or ''):lower()
        for _,entry in ipairs(d.categories[selectedCategory].icons) do if entry.name:lower():find(query,1,true) then d.matches[#d.matches+1]=entry end end
        local pages=math.max(1,math.ceil(#d.matches/54));page=math.min(page,pages);d.pageLabel:SetText(string.format(L['Page %d of %d'],page,pages))
        if page>1 then d.prev:Enable() else d.prev:Disable() end;if page<pages then d.next:Enable() else d.next:Disable() end
        for i=1,54 do
            local entry=d.matches[(page-1)*54+i];local button=d.buttons[i]
            if entry then
                if not button then button=addon:CreateWorkbenchButton(d.frame,'',44);button.icon=button:CreateTexture(nil,'ARTWORK');button.icon:SetAllPoints(button);d.buttons[i]=button end
                button:ClearAllPoints();button:SetPoint('TOPLEFT',166+((i-1)%9)*48,-74-math.floor((i-1)/9)*48);button:SetSize(40,40);button.icon:SetTexture(entry.texture);button:SetSelected(entry.texture==current);button.tooltip=entry.name;button:Show()
                addon:SetUIScript(button,'OnClick',function() if valid() and d.revision==revision then d.frame:Hide();choose(entry.texture) end end)
            elseif button then button:Hide() end
        end
        for i,button in ipairs(d.categoryButtons) do button:SetSelected(i==selectedCategory) end
    end
    for i,category in ipairs(d.categories) do
        local button=d.categoryButtons[i];if not button then button=self:CreateWorkbenchButton(d.frame,'',136);d.categoryButtons[i]=button end
        button:ClearAllPoints();button:SetPoint('TOPLEFT',12,-38-(i-1)*28);button:SetText(category.name);button:Show();self:SetUIScript(button,'OnClick',function() if valid() then selectedCategory=i;page=1;draw() end end)
    end
    for i=#d.categories+1,#d.categoryButtons do d.categoryButtons[i]:Hide() end
    self:SetUIScript(d.search,'OnTextChanged',function(_,user) if user and valid() then page=1;draw() end end);self:SetUIScript(d.search,'OnEscapePressed',function() d.frame:Hide() end)
    self:SetUIScript(d.prev,'OnClick',function() if valid() then page=math.max(1,page-1);draw() end end);self:SetUIScript(d.next,'OnClick',function() if valid() then page=page+1;draw() end end)
    d.chrome:SetContext(L['Select Icon'],L['Category'],self.pretty_name);d.frame:Show();self:RegisterWindowForEscape(d);draw();d.search:SetFocus();return d
end
