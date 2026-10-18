local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local data=addon.RotationData

-- View controls stay outside the scaled/scrolled scene. All three workspaces
-- share the same draft and history; these choices never alter rotation data.
function addon:InstallRotationView(pane)
    pane.contentTabs={};pane.sectionLabels=pane.contentTabs;pane.sectionTools={};pane.palette={}
    for _,section in ipairs({'rotation','cooldowns'}) do
        local tab=addon:CreateWorkbenchButton(pane.frame,section=='rotation' and L['Rotation'] or L['Cooldowns'],100)
        pane.contentTabs[section]=tab
        pane.sectionTools[section]={
            expand=addon:CreateWorkbenchLabeledIconButton(pane.frame,'expand-all',L['Expand all'],100),
            collapse=addon:CreateWorkbenchLabeledIconButton(pane.frame,'collapse-all',L['Collapse all'],100)}
    end
    pane.expand=pane.sectionTools.rotation.expand;pane.collapse=pane.sectionTools.rotation.collapse
    pane.viewMode=addon:CreateWorkbenchPill(pane.frame,L['Diagram view'],108)
    pane.viewMode.tooltip=L['Switch between the diagram and compact tree list. This changes only the view.']
    for _,entry in ipairs({{key='action',text=L['Add action'],section='rotation',node={type='spell',conditions={}}},
        {key='branch',text=L['Add branch'],section='rotation',node={type='branch',conditions={},onTrue={},onFalse={}}},
        {key='optional',text=L['Add cooldown'],section='cooldowns',node={type='spell',conditions={}}}}) do
        local control=addon:CreateWorkbenchLabeledIconButton(pane.frame,entry.key=='branch' and 'branch' or 'plus',entry.text,116)
        control.section=entry.section;control.node=entry.node;control.tooltip=L['Drag into a gap, or click to append.'];pane.palette[entry.key]=control
    end
    pane.zoomBar=CreateFrame('Frame',nil,pane.canvas.frame);pane.zoomBar:SetSize(96,24);pane.zoomBar:EnableMouse(true)
    pane.zoomBar:SetPoint('BOTTOMRIGHT',pane.canvas.frame,'BOTTOMRIGHT',-8,8)
    pane.zoomOut=addon:CreateWorkbenchIconButton(pane.zoomBar,'minus',L['Zoom out']);pane.zoomOut:SetSize(22,22);pane.zoomOut:SetPoint('LEFT')
    pane.zoomReset=addon:CreateWorkbenchButton(pane.zoomBar,'100%',44);pane.zoomReset:SetSize(44,22);pane.zoomReset:SetPoint('LEFT',pane.zoomOut,'RIGHT',2,0)
    pane.zoomIn=addon:CreateWorkbenchIconButton(pane.zoomBar,'plus',L['Zoom in']);pane.zoomIn:SetSize(22,22);pane.zoomIn:SetPoint('LEFT',pane.zoomReset,'RIGHT',2,0)
    pane.zoomReset.tooltip=L['Reset diagram zoom to 100%. Scroll to zoom; middle-click to reset. Drag empty space to pan.']
    function pane:ContentSection() return self.view.section=='cooldowns' and 'cooldowns' or 'rotation' end
    function pane:SelectContent(section)
        if not self.active or (section~='rotation' and section~='cooldowns') then return nil end
        if self:ContentSection()==section then return true end
        if not self:FlushName() then return nil end
        local ok,why=self:FlushFieldEdits();if not ok then self:Message(why);return nil,why end
        self.canvas:RememberViewport();self.view.section=section;self:Render();return true
    end
    function pane:UpdateCanvasNavigation()
        local section=self:ContentSection();local diagram=self.canvas:IsDiagram()
        for key,button in pairs(self.contentTabs) do button:SetSelected(key==section) end
        if section=='rotation' then self.viewMode:Show() else self.viewMode:Hide() end
        if diagram then self.zoomBar:SetFrameLevel(self.canvas.frame:GetFrameLevel()+200);self.zoomBar:Show() else self.zoomBar:Hide() end
        local value=self.canvas:GetZoom();self.zoomReset:SetText(string.format('%d%%',math.floor(value*100+.5)))
        if value<=.25 then self.zoomOut:Disable() else self.zoomOut:Enable() end
        if value>=2 then self.zoomIn:Disable() else self.zoomIn:Enable() end
    end
    function pane:LayoutViewControls(top,width)
        local section=self:ContentSection()
        for i,key in ipairs({'rotation','cooldowns'}) do
            local button=self.contentTabs[key];button:ClearAllPoints();button:SetPoint('TOPLEFT',8+(i-1)*104,-top)
        end
        self.viewMode:ClearAllPoints();self.viewMode:SetPoint('TOPRIGHT',-8,-top)
        local row=top+28;local adds=section=='cooldowns' and {'optional'} or {'action','branch'}
        local wrap=width<220+#adds*120
        for key,tools in pairs(self.sectionTools) do
            for i,button in ipairs({tools.expand,tools.collapse}) do
                button:ClearAllPoints();button:SetPoint('TOPLEFT',8+(i-1)*104,-row)
                if key==section then button:Show() else button:Hide() end
            end
        end
        for _,control in pairs(self.palette) do control:Hide() end
        for i,key in ipairs(adds) do
            local button=self.palette[key];button:ClearAllPoints();button:SetPoint('TOPRIGHT',-8-(#adds-i)*120,-row-(wrap and 26 or 0));button:Show()
        end
        self:UpdateCanvasNavigation()
        return row+(wrap and 26 or 0)+28
    end
    function pane:BindViewControls(alive)
        for section,button in pairs(self.contentTabs) do
            addon:SetUIScript(button,'OnClick',function() if alive() then self:SelectContent(section) end end)
        end
        addon:SetUIScript(self.viewMode,'OnClick',function()
            if not alive() or self:ContentSection()~='rotation' or not self:FlushName() then return end
            local ok,why=self:FlushFieldEdits();if not ok then self:Message(why);return end
            self.canvas:RememberViewport();self.view.layout=self.view.layout=='list' and 'diagram' or 'list';self:Render()
        end)
        for _,entry in ipairs({{self.zoomOut,-.1},{self.zoomReset,0},{self.zoomIn,.1}}) do
            local button,delta=entry[1],entry[2]
            addon:SetUIScript(button,'OnClick',function()
                if alive() and self.canvas:IsDiagram() then self.canvas:SetZoom(delta==0 and 1 or math.floor(self.canvas:GetZoom()*100+.5)/100+delta) end
            end)
        end
        for section,controls in pairs(self.sectionTools) do
            for _,entry in ipairs({{controls.expand,'normal'},{controls.collapse,'compact'}}) do
                local mode=entry[2]
                addon:SetUIScript(entry[1],'OnClick',function()
                    if not alive() or self:ContentSection()~=section then return end
                    for _,row in ipairs(data.IndexRotationSteps(self.workspace:Snapshot()).rows) do if row.section==section then
                        self.view.cardStates[row.step.id]=mode;if mode=='normal' then self.view.hiddenChildren[row.step.id]=nil;if self.view.hiddenArms then self.view.hiddenArms[row.step.id]=nil end end
                    end end
                    self:Render()
                end)
            end
        end
        for _,control in pairs(self.palette) do
            if self.workspace.readOnly then control:Disable() else control:Enable() end
            addon:SetUIScript(control,'OnClick',function()
                if not alive() or self.workspace.readOnly or control.section~=self:ContentSection() then return end
                local list=self.workspace:Snapshot()[control.section];self:Command('Insert',{path={control.section},index=#list+1},control.node)
            end)
            addon:BindWorkbenchDragSource(control,function()
                if alive() and control.section==self:ContentSection() then self.canvas:BeginDrag(nil,control.node) end
            end,function() if alive() then self.canvas:EndDrag() end end)
        end
    end
end
