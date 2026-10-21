-- Exact one-shot invalid-field presentation inverse; predecessor proofs remain unchanged.
local bytes,hash,oldBytes,oldHash=41404,2820911158,37135,3337624042
local edits={
 {at=41278,current=[====[    if not shell:ExpandInvalid({{}}) then return shell end
]====],previous=[====[]====]},
 {at=28062,current=[====[        if name=="Replace" or name=="Add" or name=="AddSibling" or name=="Insert" or name=="Duplicate" then
            local added=paths
            if name=="Add" then
                local node=at(self.active.working,path)
                if node and (node.type=="AND" or node.type=="OR") then
                    local child=copyPath(path);child[#child+1]='value';child[#child+1]=#node.value;added={child}
                end
            end
            if not self:ExpandInvalid(added) then return end
        end
]====],previous=[====[]====]},
 {at=14206,current=[====[    end
    -- Seed editable fields only at entry or for newly added/replaced subtrees.
    -- Redrawing and ordinary field edits retain the user's current fold state.
    function shell:ExpandInvalid(paths)
        local active,view=self.active,self.view
        local working=active.working
        local definitions,revision=addon.conditionDefinitions,addon.conditionRegistryVersion
        local function owned()
            return self.active==active and self.view==view and active.working==working
                and addon.db.profile==active.profile and addon.db.global==active.global and addon.db.char==active.char
                and (active.persistentOwner or active.generation==addon.configPaneGeneration)
                and addon.conditionDefinitions==definitions and addon.conditionRegistryVersion==revision
        end
        local function current()
            if not owned() then return false end
            if active.targetValid then
                local ok,valid=pcall(active.targetValid)
                if not ok or valid~=true then return false end
            end
            return owned()
        end
        if not current() then return false end
        local scene=self:Scene(true)
        if not scene or not current() then return false end
        for _,card in ipairs(scene.cards) do
            local selected=false
            for _,path in ipairs(paths) do
                local matches=#path<=#card.fieldPath
                for index,part in ipairs(path) do if card.fieldPath[index]~=part then matches=false;break end end
                if matches then selected=true;break end
            end
            if selected then
                local invalid=card.invalid
                if not invalid and not card.group then
                    local candidate=addon.RotationData.CopyData(at(working,card.fieldPath))
                    if candidate then
                        candidate.disabled=nil
                        local before=addon.RotationData.CopyData(candidate)
                        local function validate()
                            if self.userdata.announcementTarget then return addon:validateAnnouncementCondition(candidate,active.spec) end
                            return addon:validateCondition(candidate,active.spec)
                        end
                        local ok,valid
                        if addon.Diagnostics then
                            local definition=definitions[candidate.type]
                            ok,valid=addon.Diagnostics:Call({module='condition-editor',operation='validate',customCode=definition and definition.customCode==true},validate)
                        else ok,valid=pcall(validate) end
                        if not current() then return false end
                        invalid=not ok or not valid or not addon:UnsavedDataEqual(before,candidate)
                    end
                end
                if invalid then
                    view.cardStates[card.key]='expanded'
                    local path={}
                    for index=0,#card.path do
                        if index>0 then path[index]=card.path[index] end
                        local key=pathKey(path);view.hiddenChildren[key]=nil;view.collapsed[key]=nil
                        local parent=scene.cardsByKey[key]
                        if parent then view.cardStates[key]='expanded' end
                    end
                end
            end
        end
        return true
]====],previous=[====[]====]},
 {at=12660,current=[====[        local view=self.view
        if includeHidden then
            view={};for key,value in pairs(self.view) do view[key]=value end
            view.collapsed={};view.hiddenChildren={}
        end
        local scene,problem=addon:BuildConditionCanvas(self.active.working,rows,view,complete)
]====],previous=[====[        local scene,problem=addon:BuildConditionCanvas(self.active.working,rows,self.view,complete)
]====]},
 {at=12442,current=[====[    function shell:Scene(includeHidden)
]====],previous=[====[    function shell:Scene()
]====]},
}
local function digest(s)local n=5381;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return n end
return function(text,path)
 if path~='UI/condition_editor.lua' then return text end
 if #text==oldBytes and digest(text)==oldHash then return text end
 assert(#text==bytes and digest(text)==hash,'unrelated invalid-field expansion source')
 for _,edit in ipairs(edits)do
  assert(text:sub(edit.at,edit.at+#edit.current-1)==edit.current,'invalid-field expansion inverse drift')
  text=text:sub(1,edit.at-1)..edit.previous..text:sub(edit.at+#edit.current)
 end
 assert(#text==oldBytes and digest(text)==oldHash,'invalid-field expansion predecessor mismatch')
 return text
end
