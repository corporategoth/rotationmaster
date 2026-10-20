local _,addon=...
local data=addon.RotationData
local function plain(value) return type(value)=="table" and getmetatable(value)==nil end
local function settings(self)
    local options=self:GetRotationValidationOptions();return options
end
function addon:GetImportValidationOptions() return settings(self) end
function addon:GetImportedRotationView(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:SourceView(spec,id,true) end
    local state=self.db.profile.rotationLibrary
    if state==nil then return nil,"not-imported" end
    if not plain(state) then return nil,"invalid-import-state" end
    if state.imports==nil then return nil,"not-imported" end
    if not plain(state.imports) then return nil,"invalid-import-state" end
    local rows=state.imports[spec]
    if rows==nil then return nil,"not-imported" end
    if not plain(rows) then return nil,"invalid-import-state" end
    if rows[id]==nil then return nil,"not-imported" end
    local record,why=data.CopyData(rows[id])
    if why or not plain(record) or not plain(record.manifest) or record.manifest.id~=id
        or type(record.sourceId)~="string" or not plain(record.stepOrigins) then return nil,"invalid-import-state" end
    local body=self:GetEditableRotation(spec,id)
    local envelope=data.CopyData(record.manifest);envelope.body=data.CopyData(body)
    if not envelope.body then return nil,"invalid-import-state" end
    return {envelope=envelope,applicability=envelope.applicability,enabled=true,
        validation=data.ValidateEnvelope(envelope,settings(self)),sourceId=record.sourceId,
        sourceRevision=record.sourceRevision,stepOrigins=record.stepOrigins}
end
function addon:CreateImportedRotation(prepared,spec,name,replacement,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then return scoped:Import(prepared,spec,name,replacement,options) end
    if type(spec)~="number" or spec<0 or spec%1~=0 then return nil,"invalid-specialization" end
    if type(name)~="string" or #name==0 or #name>256 then return nil,"invalid-name" end
    local profile=self.db.profile
    local rotationsRoot=profile.rotations
    if rotationsRoot~=nil and not plain(rotationsRoot) then return nil,"invalid-rotation-storage" end
    if rotationsRoot and rotationsRoot[spec]~=nil and not plain(rotationsRoot[spec]) then return nil,"invalid-rotation-storage" end
    local body,problem=data.CopyData(prepared.body)
    if problem or not plain(body) then return nil,"invalid-import" end
    local manifest=prepared.manifest and data.CopyData(prepared.manifest)
    if prepared.manifest and not manifest then return nil,"invalid-import" end
    local result
    if manifest then
        local envelope=data.CopyData(manifest);envelope.body=body
        result=data.ValidateEnvelope(envelope,settings(self))
    else result=data.ValidateBody(body,settings(self)) end
    if not result.valid or not result.supported or not result.resolved then return nil,"import-not-ready" end
    local ok,why=self:InitializeRotationLibrary();if not ok then return nil,why end
    local state=self.db.profile.rotationLibrary
    for _,kind in ipairs({"origins","comparisons","imports"}) do if state[kind][spec]~=nil and not plain(state[kind][spec]) then return nil,"invalid-import-state" end end
    local used={}
    -- Reserve identities in live bodies and retained provenance; never discard
    -- malformed unrelated saved data while allocating a new rotation.
    local function reserve(value)
        if type(value)=="string" then used[value]=true
        elseif type(value)=="table" then for key,child in pairs(value) do reserve(key);reserve(child) end end
    end
    for _,rotations in pairs(rotationsRoot or {}) do
        if plain(rotations) then
            for id,rotation in pairs(rotations) do
                used[id]=true
                local copy=data.CopyData(rotation);if copy then reserve(copy) end
            end
        end
    end
    for _,kind in ipairs({"origins","comparisons","imports"}) do
        for _,rows in pairs(state[kind]) do
            if plain(rows) then for id,record in pairs(rows) do
                used[id]=true;local copy=data.CopyData(record);if copy then reserve(copy) end
            end end
        end
    end
    for _,row in ipairs(self:ListDefaultRotations(spec)) do reserve(row.envelope) end
    reserve(body);reserve(manifest)
    local function fresh()
        local success,id=pcall(self.uuid)
        if not success or type(id)~="string" or #id>128 or not id:match("^[%w][%w._:%-]*$") then return nil,"invalid-id-provider" end
        if used[id] then return nil,"id-collision" end
        used[id]=true;return id
    end
    local id,errorCode;if replacement then id=replacement.id else id,errorCode=fresh() end;if not id then return nil,errorCode end
    local sourceId=prepared.sourceId or manifest and manifest.id
    local sourceRevision=prepared.sourceRevision or manifest and manifest.revision
    local origins={}
    local tree,treeError=data.IndexRotationSteps(body)
    if not tree then return nil,treeError.code end
    for _,row in ipairs(tree.rows) do
        local step=row.step
        local stepId,reason=fresh();if not stepId then return nil,reason end
        origins[stepId]=prepared.stepOrigins and prepared.stepOrigins[step.id] or step.id
        step.id=stepId
    end
    body.name=name
    local previous=replacement and self:GetEditableRotation(spec,id) or nil
    local revised,revisionError=data.PrepareRotationContentRevision(body,previous,replacement and 'edit' or 'import',replacement~=nil)
    if not revised then return nil,revisionError end
    body=revised
    if manifest then manifest.id=id;manifest.revision=1;manifest.nameKey=name end
    -- Commit only after every validation/copy/allocation succeeds. Imported
    -- bodies have one saved home; the manifest contains no duplicate body.
    if replacement and not replacement.valid() then return nil,'rotation-changed-externally' end
    if self.db.profile~=profile or profile.rotations~=rotationsRoot or profile.rotationLibrary~=state then return nil,'rotation-changed-externally' end
    local rotations=rotationsRoot and rotationsRoot[spec] or {}
    if replacement and rotations[id]~=previous then return nil,'rotation-changed-externally' end
    if not replacement and rotations[id]~=nil then return nil,'id-collision' end
    self.db.profile.rotations=rotationsRoot or {}
    self.db.profile.rotations[spec]=rotations;rotations[id]=body
    if replacement then
        for _,kind in ipairs({'origins','comparisons','imports'}) do if type(state[kind][spec])=='table' then state[kind][spec][id]=nil end end
    end
    if manifest then
        local rows=state.imports[spec] or {};state.imports[spec]=rows
        rows[id]={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
    end
    return id
end
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end;for key in pairs(b) do if a[key]==nil then return false end end;return true
end
function addon:ApplyRotationImport(session,token,spec,name,target,expected,options)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator()
    if scoped then
        local prepared,why=session:GetReady(token);if not prepared then return nil,why end
        if not target then return self:CreateImportedRotation(prepared,spec,name,nil,options) end
        local reference,referenceReason=scoped:Resolve(spec,target);if not reference then return nil,referenceReason end
        if reference.kind~='custom' then return nil,'read-only-rotation' end
        if type(expected)~='table' or expected.profile~=self.db.profile then return nil,'rotation-changed-externally' end
        local workspace=self.GetRotationWorkspace and self:GetRotationWorkspace(spec,reference);if workspace and workspace:IsDirty() then return nil,'rotation-has-unsaved-changes' end
        local record,token=scoped:Snapshot(spec,reference);if not record then return nil,token end
        if expected.recordToken then
            if not equal(expected.reference,reference) then return nil,'rotation-changed-externally' end;token=expected.recordToken
        else
            local original=self:GetEditableRotation(spec,reference)
            if expected.target~=original or not data.CheckPortable(original) or not equal(original,expected.body) then return nil,'rotation-changed-externally' end
        end
        local id,commitReason,saved=self:CreateImportedRotation(prepared,spec,record.body.name or name,{profile=self.db.profile,reference=reference,recordToken=token},options)
        if not id then return nil,commitReason end
        if self.UpdateAutoSwitch then self:UpdateAutoSwitch() end;if self.SwitchRotation then self:SwitchRotation() end;if self.EvaluateNextAction then self:EvaluateNextAction() end
        return id,nil,saved
    end
    local prepared,why=session:GetReady(token);if not prepared then return nil,why end
    if not target then return self:CreateImportedRotation(prepared,spec,name) end
    local profile=self.db.profile;local original=self:GetEditableRotation(spec,target)
    local function valid()
        return self.db.profile==profile and type(expected)=='table' and expected.profile==profile and expected.target==original and original~=nil and self:GetEditableRotation(spec,target)==original and equal(original,expected.body) and not self:GetDefaultIdForRuntime(spec,target)
    end
    if not valid() then return nil,'rotation-changed-externally' end
    if self.GetRotationWorkspace then local workspace=self:GetRotationWorkspace(spec,target);if workspace and workspace:IsDirty() then return nil,'rotation-has-unsaved-changes' end end
    local id,reason=self:CreateImportedRotation(prepared,spec,original.name or name,{id=target,valid=valid})
    if not id then return nil,reason end
    if self.currentSpec==spec and self.currentRotation==target then
        if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() elseif self.GlowClear then self:GlowClear() end
        self.currentSpell=nil;self.avail_announced={};self.announced={};self.skipAnnounce=true
    end
    if self.UpdateAutoSwitch then self:UpdateAutoSwitch() end;if self.SwitchRotation then self:SwitchRotation() end;if self.EvaluateNextAction then self:EvaluateNextAction() end
    return id
end

function addon:GetRotationExportData(spec,id)
    local scoped=self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator();if scoped then
        local record,why=scoped:Snapshot(spec,id);if not record then return nil,why end
        local result
        if record.source then result=record.source.envelope
        elseif record.origin or record.imported then local retained=record.origin or record.imported;result=data.CopyData(retained.manifest);result.body=record.body
        else return record.body end
        if result.body.tags~=nil then result.tags=data.CopyData(result.body.tags) end;return result
    end
    local function currentTags(envelope)
        if type(envelope)=='table' and type(envelope.body)=='table' and envelope.body.tags~=nil then
            local copy,why=data.CopyData(envelope);if not copy then return nil,why end
            copy.tags=data.CopyData(copy.body.tags);return copy
        end
        return envelope
    end
    local defaultId=self:GetDefaultIdForRuntime(spec,id)
    if defaultId then return currentTags(self:GetDefaultRotation(defaultId).envelope) end
    local source,why=self:GetSourcedRotationView(spec,id)
    if source then return currentTags(source.envelope) end
    if why~="no-source-baseline" then return nil,why end
    local imported,reason=self:GetImportedRotationView(spec,id)
    if imported then return currentTags(imported.envelope) end
    if reason~="not-imported" then return nil,reason end
    return data.CopyData(self:GetEditableRotation(spec,id))
end
