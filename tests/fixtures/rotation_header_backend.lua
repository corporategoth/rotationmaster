-- Legacy UI unit tests keep simple test identities. This fixture implements
-- the projected service boundary; production UI must not inspect these maps.
return function(a, DEFAULT, NEW)
    local drafts = {}

    function a:ListRotationHeaders(spec)
        local rows = {}
        local custom = self.db.profile.rotations[spec] or {}

        local function append(id, body, pending)
            local ref = {
                kind = 'custom',
                address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = spec, id = id },
            }

            local view = body or { name = id == DEFAULT and DEFAULT or NEW }

            rows[#rows + 1] = {
                key = id,
                reference = ref,
                canonicalId = id,
                kind = 'custom',
                scope = 'class',
                name = view.name or id,
                description = view.description,
                enabled = not view.disabled,
                fallback = id == DEFAULT,
                effectiveFallback = id == DEFAULT and body ~= nil,
                readOnly = false,
                pending = pending == true or body == nil,
                virtual = body == nil and not pending,
                validationState = 'valid',
                tags = self.RotationData.GetRotationTags(view) or {},
                search = self.RotationData.RotationSearchText(view, view.name or id, view.description),
                priority = self.RotationData.GetRotationPriority(view.priority),
            }
        end

        append(DEFAULT, custom[DEFAULT])

        for id, body in pairs(custom) do
            if id ~= DEFAULT and type(body) == 'table' then
                append(id, body)
            end
        end

        for id, draft in pairs(drafts) do
            if draft.spec == spec and not custom[id] then
                append(id, nil, true)
            end
        end

        for _, entry in ipairs(self:ListDefaultRotations(spec)) do
            local view = self:GetRotationTagView(spec, entry.runtimeKey)

            rows[#rows + 1] = {
                key = entry.runtimeKey,
                reference = { kind = 'builtin', id = entry.id },
                canonicalId = entry.id,
                kind = 'builtin',
                name = entry.name,
                description = entry.description,
                enabled = entry.enabled,
                eligible = entry.eligible,
                readOnly = true,
                validationState = 'valid',
                tags = self.RotationData.GetRotationTags(view) or {},
                search = self.RotationData.RotationSearchText(view, entry.name, entry.description),
                priority = self.RotationData.GetRotationPriority(view.body and view.body.priority),
            }
        end

        return rows, {}
    end

    function a:ResolveRotationReference(spec, value)
        for _, row in ipairs(self:ListRotationHeaders(spec)) do
            if
                value == row.key
                or type(value) == 'table'
                    and value.kind == row.reference.kind
                    and (value.kind == 'builtin' and value.id == row.canonicalId
                        or value.address and value.address.id == row.canonicalId)
            then
                return row.reference
            end
        end

        return nil, 'unknown-rotation'
    end

    function a:NewRotationDraftTarget(spec)
        for _ = 1, 100 do
            local id = self:uuid()

            if
                not (self.db.profile.rotations[spec] or {})[id]
                and not drafts[id]
                and not self:GetDefaultIdForRuntime(spec, id)
            then
                local ref = {
                    kind = 'custom',
                    address = { scope = 'class', class = 'SHAMAN', owner = 'SHAMAN', spec = spec, id = id },
                }

                drafts[id] = { spec = spec, reference = ref }
                return ref, id
            end
        end

        return nil, 'id-allocation-exhausted'
    end
end
