local _,addon=...
local data=addon.RotationData
-- Roster presentation reads only metadata, never copies the action tree or
-- populates optional saved fields while a user is browsing.
function addon:GetRotationTagView(spec,id)
    local default=self:GetDefaultIdForRuntime(spec,id)
    if default then
        local source=self.GetDefaultRotation and self:GetDefaultRotation(default)
        if not source and self.ListDefaultRotations then for _,entry in ipairs(self:ListDefaultRotations(spec)) do if entry.id==default then source=entry;break end end end
        return source and source.envelope or {}
    end
    local root=self.db.profile.rotations;local rows=type(root)=='table' and root[spec];local body=type(rows)=='table' and rows[id];if type(body)~='table' then return {} end
    local manifest;local state=self.db.profile.rotationLibrary
    if type(state)=='table' then for _,kind in ipairs({'origins','imports'}) do
        local all=state[kind];local scope=type(all)=='table' and all[spec];local record=type(scope)=='table' and scope[id]
        if type(record)=='table' and type(record.manifest)=='table' then manifest=record.manifest;break end
    end end
    return {body={name=body.name,description=body.description,priority=body.priority,tags=data.CopyData(body.tags),metadata=data.CopyData(body.metadata)},tags=manifest and data.CopyData(manifest.tags),sources=manifest and data.CopyData(manifest.sources)}
end
function addon:GetRotationTags(spec,id)
    return data.GetRotationTags(self:GetRotationTagView(spec,id)) or {}
end
