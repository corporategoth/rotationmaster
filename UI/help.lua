local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function section(title,text) return {title=title,text=text} end
function addon:WorkbenchInteractionHelp(kind)
    local result={section(L['Names and details'],L['Click a name to rename it. Clear a custom step name to restore its action name. Click a collapsed title to show its summary. Click action or condition text to open its details; the double chevron returns from fields to the summary.'])}
    if kind=='condition' then
        result={section(L['Choose and edit'],L['Click a condition type to search or browse categories. Dismissing the picker or choosing the same type keeps its fields. Click the condition summary to edit its fields. The chevron switches between name only and summary; the double chevron closes the fields.']),
            section(L['Groups and toggles'],L['If / Unless toggles negation. Enabled / Disabled keeps the saved fields while skipping evaluation. All / Any changes AND / OR. Click a group name to rename it; the branch icon hides or shows its children. Gray descendants cannot be reached.']),
            section(L['Move, copy and remove'],L['Drag a card into one highlighted gap, or use the left-side Up / Down arrows. Unavailable moves are gray. Ctrl-click or Shift-click selects several cards for grouping. Duplicate copies a card; Split group removes its wrapper; the red trash can deletes it. Add condition and Add group append when clicked or insert where dropped.'])}
    else
        result[#result+1]=section(L['Move, copy and remove'],L['Drag a card into a highlighted gap or use Up / Down on the left. Moving a branch carries its children; moving an action into another arm also carries the following sequence. Duplicate copies the card and the red trash can deletes it. Cooldowns are independent, so they have no move arrows.'])
        result[#result+1]=section(L['Conditions and state'],kind=='branch' and L['Click the guard text to edit the branch condition. Evaluate uses that condition; Always true / Always false skips it. False is left and red; True is right and green. The branch icon hides its arms without changing them. Gray cards in a forced arm are unreachable.'] or L['Click condition text to edit when this card can run. Enabled / Disabled preserves the card while switching its participation. Actions also require known or carried actions, usable resources, cooldown readiness and valid range.'])
        if kind=='cooldown' then result[#result+1]=section(L['Highlight effects'],L['Click the action to edit its type, spell or item. The leading icon previews the effect. Effect selects a style; Magnification changes its size. Click the swatch or edit RGBA on the 0–1 scale. Arrows adjust position; V / H show offsets. Default restores profile values. Sound selection and Play preview an audible reminder.']) end
    end
    result[#result+1]=section(L['Help and saving'],L['The question mark explains the visible controls. With condition fields open, it adds that condition’s help below the fields. Undo / Redo affect the draft. Apply saves; Discard or Cancel abandons draft changes. Red borders mark invalid or incomplete data.'])
    return result
end
function addon:WorkbenchPageHelp(topic)
    local description={
        General=L['Configure recommendation timing, automatic switching, history, preview and profile highlight defaults. Labels are on the left. Checkboxes toggle options, sliders show numeric values, and fields validate before saving.'],
        Conditions=L['Choose a category and search for a condition. Hidden removes it from pickers without deleting its definition. Switch Condition controls its availability for automatic rotation switching. Move To stages a category destination; its Apply button confirms the move. The assigned category opens category management. Sidebar arrows and dragging order entries. Page Apply saves the draft; Cancel discards it. Custom conditions can be edited, duplicated or deleted.'],
        Effects=L['Select an effect to edit its name, type and type-specific settings. The icon previews it live. Sequence sections edit animation, color, pulse or custom frames in order. Duplicate creates an independent effect. Drag a sequence card surface to reorder it; fields remain editable. New effects can be configured before naming. Apply saves the draft; Cancel discards it. Import stages a validated replacement.'],
        ItemSets=L['Choose an item set and edit its priority list. Global shares the set across profiles. Move arrows change item priority. Bind item set picks up an available item for placement on an action bar; The binding pill removes matching bound bar actions when unbinding, outside combat. Reset restores a packaged set. Search or drag items into reference fields. Apply saves settings; Cancel discards them. Binding changes are explicit action-bar operations.'],
        Announces=L['Expand an announcement to choose its action, event, channel and text. Spell fields search the catalog; exact rank limits matching to that rank. Enabled toggles the announcement. New opens a draft with Apply and Cancel. Audible replaces text with sound selection and Play. Duplicate, Import/Export and Compare are below the list; imports are validated and never execute code. Apply saves changes.'],
        Profiles=L['Select a profile in the sidebar to inspect it, then Activate profile to switch. New and Duplicate open a named draft with Apply and Cancel. Import stages a validated new profile; Compare shows setting differences. Copy and Reset replace the active profile after confirmation; the red trash deletes an inactive profile.'],
        About=L['Version, author, credits and project links are shown here. Click a link field to select its text for copying.'],
        Rotations=L['Search or filter the rotation roster, then select a rotation. Blue defaults use the same editor but remain read-only; Duplicate makes an editable copy. The name and Metadata describe the rotation. Switch condition selects when it applies. Cooldowns run independently above the ordered rotation.']}
    local result={section(L['Using this page'],description[topic] or L['Optional addon settings.'])}
    if topic~='Profiles' and topic~='Rotations' and topic~='About' then result[#result+1]=section(L['Apply / Cancel'],L['Edits stay in a draft until Apply. Cancel restores saved settings. Changing tabs or closing asks to apply pending changes; Cancel on the page discards them. Effect previews do not save changes. Action-bar binding operations are explicit and immediate.']) end
    if topic=='General' and self.GetGeneralOptionHelp then for _,entry in ipairs(self:GetGeneralOptionHelp()) do result[#result+1]=entry end end
    local authored={Conditions=self.GetDocument_layout_conditions_options_help,Effects=self.GetDocument_layout_effects_options_help,ItemSets=self.GetDocument_layout_itemsets_options_help,Announces=self.GetDocument_layout_announce_options_help}
    if authored[topic] then for _,entry in ipairs(authored[topic](self)) do result[#result+1]=entry end end
    if topic=='Rotations' then
        result[#result+1]=section(L['Navigating rotations'],L['Diagram / List changes only the view. Minus and plus zoom the canvas from 25% to 200%, independently of window Scale; click the percentage to reset to 100%. Drag empty canvas space with the left mouse button to pan. Dragging cards still reorders them. The list shows False before True. Both views currently show at most 200 cards; the remaining saved cards are preserved.'])
        for _,entry in ipairs(self:WorkbenchInteractionHelp('rotation')) do result[#result+1]=entry end
    else result[#result+1]=section(L['Editing settings'],L['These settings apply immediately. Press Enter or leave a text field to commit it. Invalid text stays red and blocks navigation until corrected. Searchable selectors open on click and filter as you type. Section headings collapse or expand their contents.']) end
    result[#result+1]=section(L['Window controls'],L['Drag the title bar to move. Set Scale with the top-left slider; child windows follow it. The question mark toggles Help. Close with X, Escape, or right-click in the content area.'])
    return result
end
function addon:ShowWorkbenchHelp(heading,sections,owner)
    local d=self.helpWindow
    if not d then
        d={frame=CreateFrame('Frame',nil,UIParent),rows={}};self.helpWindow=d;local frame=d.frame
        frame:SetPoint('CENTER');frame:SetSize(540,360);frame:SetFrameStrata('FULLSCREEN_DIALOG');frame:SetToplevel(true);frame:SetClampedToScreen(true);frame:EnableMouse(true);addon:MakeWindowOpaque(frame)
        d.title=frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=addon:CreateWorkbenchDialogChrome(frame,d.title)
        d.scroll=addon:CreateWorkbenchScrollFrame(frame);d.scroll:SetPoint('TOPLEFT',12,-38);d.child=CreateFrame('Frame',nil,d.scroll);d.scroll:SetScrollChild(d.child);d.child:SetWidth(490)
        d.close=addon:CreateWorkbenchIconButton(frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5)
        local function hide() frame:Hide() end
        addon:SetUIScript(d.close,'OnClick',hide)
        for _,surface in ipairs({frame,d.scroll}) do addon:SetUIScript(surface,'OnMouseUp',function(_,button) if button=='RightButton' then hide() end end) end
        function d:Hide() frame:Hide() end
        frame:Hide();addon.HideOnEscape(d)
    end
    d.heading=heading;d.sections=sections;d.chrome:SetContext(heading,L['Help'],owner or addon.pretty_name or L['Rotation Master'])
    local y=0;local n=0
    for _,entry in ipairs(sections or {}) do
        for i,value in ipairs({entry.title or '',entry.text or ''}) do
            n=n+1;local t=d.rows[n];if not t then t=d.child:CreateFontString(nil,'OVERLAY',i==1 and 'GameFontNormal' or 'GameFontHighlightSmall');d.rows[n]=t end
            t:SetFontObject(i==1 and 'GameFontNormal' or 'GameFontHighlightSmall');t:ClearAllPoints();t:SetPoint('TOPLEFT',0,-y);t:SetWidth(490);t:SetJustifyH('LEFT');t:SetWordWrap(true);t:SetText(value);t:SetTextColor(i==1 and 1 or .85,i==1 and .82 or .88,i==1 and .2 or .9);t:SetHeight(0);t:SetHeight(math.max(16,t:GetStringHeight()));t:Show();y=y+t:GetHeight()+(i==1 and 4 or 14)
        end
    end
    for i=n+1,#d.rows do d.rows[i]:Hide() end
    d.child:SetHeight(math.max(1,y));local visible=math.min(300,math.max(100,y));d.frame:SetHeight(38+visible+28);d.scroll:SetSize(510,visible);d.chrome:LayoutTitle()
    local front=_G.RotationMasterFrontmostDialog;d.frame:SetFrameLevel(front and front~=d.frame and front:GetFrameLevel()+20 or d.frame:GetFrameLevel()+1);d.frame:Show();d.scroll.workbenchBar:SetValue(0);d.scroll:UpdateWorkbenchScroll();addon:RegisterWindowForEscape(d);return d
end
