local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function section(title,text) return {title=title,text=text} end
function addon:GetProfileOptionHelp()
    return {
        {id='activate',title=L['Activate profile'],text=L['Help.Profiles.activate']},
        {id='copy',title=L['Copy from profile'],text=L['Help.Profiles.copy']},
        {id='reset',title=L['Reset current profile'],text=L['Help.Profiles.reset']},
        {id='delete',title=L['Delete'],text=L['Help.Profiles.delete']},
        {id='new_name',title=L['New profile name'],text=L['Help.Profiles.new_name']},
        {id='collections',title=L['New / Duplicate / Import / Compare'],text=L['Help.Profiles.collections']},
    }
end
function addon:GetIntegrationOptionHelp()
    return {
        {id='lua_editor',title=L['Editor'],text=L['Help.Integrations.lua_editor']},
        {id='lua_line_numbers',title=L['Show line numbers'],text=L['Help.Integrations.lua_line_numbers']},
        {id='optional_addons',title=L['Optional addons'],text=L['Help.Integrations.optional_addons']},
    }
end
function addon:WorkbenchInteractionHelp(kind)
    local result={section(L['Names and details'],L['Click a name to rename it. Clear a custom step name to restore its action name. Click a collapsed title to show its summary. Click action or condition text to open its details; the double chevron returns from fields to the summary.'])}
    if kind=='condition' then
        result={section(L['Choose and edit'],L['Click a condition type to search or browse categories. Dismissing the picker or choosing the same type keeps its fields. Click the condition summary to edit its fields. The chevron switches between name only and summary; the double chevron closes the fields.']),
            section(L['Groups and toggles'],L['If / Unless toggles negation. Enabled / Disabled keeps the saved fields while skipping evaluation. All / Any changes AND / OR. Click a group name to rename it; the branch icon hides or shows its children. Gray descendants cannot be reached.']),
            section(L['Move, copy and remove'],L['Drag a card into one highlighted gap, or use the left-side Up / Down arrows. Hold Ctrl when starting a drag to carry the card and all following siblings. Groups always carry their children. Unavailable moves are gray. Ctrl-click or Shift-click selects several cards for grouping; dragging an existing selection moves that selection. Duplicate copies a card; Split group removes its wrapper; the red trash can deletes it. Add condition and Add group append when clicked or insert where dropped.'])}
    else
        result[#result+1]=section(L['Move, copy and remove'],L['Drag one card into a highlighted gap; hold Ctrl when starting the drag to carry that card and all following siblings. A branch always carries its children. Use Up / Down on the left to move one card. Duplicate copies the card and the red trash can deletes it. Cooldowns are independent, so they have no move arrows.'])
        result[#result+1]=section(L['Conditions and state'],kind=='branch' and L['Click the guard text to edit the branch condition. Evaluate uses that condition; Always true / Always false skips it. False is left and red; True is right and green. The branch icon hides both arms without changing them. Click True or False to fold only that arm; its hidden count remains visible. Gray cards in a forced arm are unreachable.'] or L['Click condition text to edit when this card can run. Enabled / Disabled preserves the card while switching its participation. Actions also require known or carried actions, usable resources, cooldown readiness and valid range.'])
        if kind=='cooldown' then result[#result+1]=section(L['Highlight effects'],L['Click the action to edit its type, spell or item. The leading icon previews the effect. Effect selects a style; Magnification changes its size. Click the swatch or edit RGBA on the 0–1 scale. Arrows adjust position; V / H show offsets. Default restores profile values. Sound selection and Play preview an audible reminder.']) end
    end
    result[#result+1]=section(L['Help and saving'],L['The question mark explains the visible controls. With condition fields open, it adds that condition’s help below the fields. Undo / Redo affect the draft. Apply saves; Discard or Cancel abandons draft changes. Red borders mark invalid or incomplete data.'])
    return result
end
function addon:WorkbenchPageHelp(topic)
    if topic=='Functions' then return {
        section(L['Using this page'],L['Search helpers by name or description, then filter Built In / Custom and namespace. Packaged helpers use the same read-only pane. Duplicate creates an editable custom copy.']),
        section(L['Namespace'],L['Choose an existing namespace from the suggestions or type a new dotted namespace. Built In namespaces follow source files; custom namespaces are implied by saved functions and need no separate maintenance.']),
        section(L['Name'],L['Function names use letters, numbers and underscores, beginning with a letter or underscore. The code signature shows the qualified namespace.name used by callers.']),
        section(L['Arguments and returns'],L['Click an Arguments or Returns heading to collapse or expand it. + Argument and + Return append when clicked, or insert at a highlighted gap when dragged. Drag a row or use Up / Down to reorder; Ctrl-drag carries following rows. The trash can removes a row. Type and Nullable document accepted values; Description explains each input or result. Lua can return several ordered results. Return rows describe those results; moving them does not rewrite return statements. Reordering a saved function warns because positional callers may need changes; RM does not rewrite call sites.']),
        section(L['Editing code'],L['Undo and Redo edit the Lua body. Reset restores the saved body or new-function template and can be undone. Check syntax executes no custom Lua. Apply saves the body and metadata together; Discard abandons the draft. Leaving with changes offers Apply, Discard or Cancel.']),
        section(L['Function bindings'],L['Call a utility as namespace.name(...). Built In namespaces follow source files; custom functions choose their Namespace. Accepting a completion attaches its stable dependency binding; for a typed call, add its qualified name under Function bindings. Namespaces do not supply self. Pass a method receiver explicitly in a namespaced dot call; object:method(x) is Lua shorthand for object.method(object, x). Existing addon APIs remain compatible with saved definitions. Existing aliases still work. Renaming a function or namespace does not rewrite existing code or bindings. Missing, disabled or invalid dependencies keep consumers unavailable.']),
        section(L['Import/Export'],L['Include custom function dependencies exports their source with the selected definition. Without it, the bundle records required helper identities and versions. Review source shows every imported Lua body. Resolve each original name and destination with Reuse, Replace or a new identifier. Apply import saves the complete reviewed bundle and can register imported Lua. Only apply code you trust.']),
        section(L['Window controls'],L['Drag the title bar to move. Set Scale with the top-left slider; child windows follow it. The question mark toggles Help. Close with X, Escape, or right-click in the content area.'])} end
    local description={
        General=L['Configure recommendation timing, automatic switching, history, preview and profile highlight defaults. Labels are on the left. Checkboxes toggle options, sliders show numeric values, and fields validate before saving.'],
        Conditions=L['Choose a category and search for a condition. Hidden removes it from pickers without deleting its definition. Switch Condition controls its availability for automatic rotation switching. Move To stages a category destination; its Apply button confirms the move. The assigned category opens category management. Sidebar arrows and dragging order entries. Page Apply saves the draft; Discard abandons edits to a saved entry. Custom conditions can be edited, duplicated or deleted.'],
        Effects=L['Select an effect to edit its name, type and type-specific settings. The icon previews it live. Sequence sections edit animation, color, pulse or custom frames in order. Duplicate creates an independent effect. Drag a sequence card surface to reorder it; fields remain editable. New effects can be configured before naming. Apply saves the draft; Discard abandons edits to a saved entry. Import stages a validated replacement.'],
        ItemSets=L['Choose an item set and edit its priority list. Global shares the set across profiles. Move arrows change item priority. Bind item set picks up an available item for placement on an action bar; The binding pill removes matching bound bar actions when unbinding, outside combat. Reset restores a packaged set. Search or drag items into reference fields. Apply saves settings; Discard abandons edits to a saved entry. Binding changes are explicit action-bar operations.'],
        Announces=L['Expand an announcement to choose its action, event, channel and text. Spell fields search the catalog; exact rank limits matching to that rank. Enabled toggles the announcement. New opens a draft with Apply and Cancel. Audible replaces text with sound selection and Play. Duplicate, Import/Export and Compare are below the list; imports are validated and never execute code. Apply saves changes.'],
        Profiles=L['Select a profile in the sidebar to inspect it, then Activate profile to switch. New and Duplicate open a named draft with Apply and Cancel. Import stages a validated new profile; Compare shows setting differences. Copy and Reset replace the active profile after confirmation; the red trash deletes an inactive profile.'],
        About=L['Version, author, credits and project links are shown here. Click a link field to select its text for copying.'],
        Rotations=L['Search or filter the rotation roster, then select a rotation. Blue Built In rotations use the same editor but remain read-only; Duplicate makes an editable copy. The name and Metadata describe the rotation. Switch condition selects when it applies. Use the Rotation and Cooldowns tabs to select the content below the switch condition. Cooldowns highlight independently of the ordered rotation.']}
    description.Integrations=L['Choose the editor for custom Lua conditions and functions. Show line numbers applies across code editors. Built In syntax highlighting and Plain text work without another addon. Automatic selects a connected provider or falls back safely. Apply saves settings; editor changes take effect on reopening, and line-number visibility updates open editors. LuaWorkbench and WowLua loading status is shown separately from integration availability.']
    local result={section(L['Using this page'],description[topic] or L['Optional addon settings.'])}
    if topic~='Profiles' and topic~='Rotations' and topic~='About' then result[#result+1]=section(L['Apply / Discard'],L['Edits stay in a draft until Apply. Discard abandons pending changes. Leaving with changes offers Apply, Discard or Cancel; Cancel keeps the page and draft open. Effect previews do not save changes. Action-bar binding operations are explicit and immediate.']) end
    if topic=='General' and self.GetGeneralOptionHelp then for _,entry in ipairs(self:GetGeneralOptionHelp()) do result[#result+1]=entry end end
    local authored={Conditions=self.GetDocument_layout_conditions_options_help,Effects=self.GetDocument_layout_effects_options_help,ItemSets=self.GetDocument_layout_itemsets_options_help,Announces=self.GetDocument_layout_announce_options_help,Profiles=self.GetProfileOptionHelp,Integrations=self.GetIntegrationOptionHelp}
    if authored[topic] then for _,entry in ipairs(authored[topic](self)) do result[#result+1]=entry end end
    if topic=='Rotations' then
        result[#result+1]=section(L['Navigating rotations'],L['Diagram / List changes only the rotation view; General settings choose the default. Diagram has floating minus, percentage and plus controls at the bottom right. Scroll to zoom from 25% to 200%; click the percentage or middle-click to reset to 100%. Drag empty diagram space to pan. List uses normal scrollbars with touching cards and boxed branch arms, False before True. Cooldowns use a separate scrolling grid. Dragging cards reorders them in every view. Valid rotation bodies can contain up to 2,000 total steps; large workspaces reuse nearby card controls as you navigate. Folded branches intentionally hide their children.'])
        for _,entry in ipairs(self:WorkbenchInteractionHelp('rotation')) do result[#result+1]=entry end
    elseif topic~='Profiles' and topic~='About' then result[#result+1]=section(L['Editing settings'],L['Press Enter or leave a text field to stage its value; Apply saves the draft. Invalid text stays red and must be corrected before Apply; Discard can abandon it. Searchable selectors open on click and filter as you type. Section headings collapse or expand their contents.']) end
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
