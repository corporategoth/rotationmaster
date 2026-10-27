local _, addon = ...
local data = addon.RotationData

-- Session-only staging: decoding/validation/comparison cannot touch saved data,
-- register conditions, evaluate predicates, or compile custom Lua.
function data.NewImportSession(codec, options)
    assert(type(codec) == "table" and type(codec.Decode) == "function", "trusted codec required")
    local current, generation = nil, 0
    local session = {}

    local function validation(candidate)
        if candidate.kind == "envelope" then return data.ValidateEnvelope(candidate.value, options) end
        return data.ValidateBody(candidate.value, options)
    end

    local function snapshot()
        if not current then return nil end

        return {
            token = current.token,
            kind = current.kind,
            original = current.original,
            scopeStatus = current.kind == "envelope" and "declared" or "unknown",
            value = data.CopyData(current.value),
            validation = data.CopyData(current.validation),
        }
    end

    function session:Clear()
        current = nil
        generation = generation + 1
    end

    function session:GetCandidate()
        return snapshot()
    end

    function session:Stage(text)
        self:Clear()
        local decoded, why = codec:Decode(text)
        if not decoded then return nil, why end

        current = {
            token = generation,
            kind = decoded.kind,
            original = decoded.original,
            value = data.CopyData(decoded.value),
        }

        current.validation = validation(current)
        return snapshot()
    end

    function session:GetReady(token)
        if not current or token ~= current.token then return nil, "stale-import" end
        local result = validation(current)
        if not result.valid then return nil, "invalid-import" end
        if not result.supported then return nil, "unsupported-import" end
        if not result.resolved then return nil, "unresolved-import" end
        local envelope = current.kind == "envelope" and data.CopyData(current.value) or nil
        local body = data.CopyData(envelope and envelope.body or current.value)
        if envelope then envelope.body = nil end
        return { kind = current.kind, body = body, manifest = envelope }
    end

    function session:Compare(token, body, inheritedTags)
        if not current or token ~= current.token then return nil, "stale-import" end
        local incoming

        if current.kind == "envelope" then
            incoming = current.value.body
        else
            incoming = current.value
        end

        if type(incoming) ~= "table" then return nil, "no-previewable-body" end
        local left, why = data.RotationComparisonValue(body, inheritedTags)
        if not left then return nil, why.code end
        local right = data.RotationComparisonValue(incoming, current.kind == 'envelope' and current.value.tags or nil)
        local diff = data.DiffRotations(left, right)
        return { key = "import", left = left, right = right, diff = diff }
    end

    -- The staged candidate as a detached copy to show in full, whether or not it
    -- is ready to import: its body and, for an envelope, the manifest around it.
    -- Nothing is validated, registered or evaluated here; a problem with the
    -- data is for the caller to report, never a reason to mutate the candidate.
    function session:Preview(token)
        if not current or token ~= current.token then return nil, "stale-import" end
        local envelope = current.kind == "envelope"
        local incoming = envelope and current.value.body or current.value
        if type(incoming) ~= "table" then return nil, "no-previewable-body" end
        local body, why = data.CopyData(incoming)
        if not body then return nil, why.code end
        local manifest

        if envelope then
            manifest, why = data.CopyData(current.value)
            if not manifest then return nil, why.code end
            manifest.body = nil
        end

        return { kind = current.kind, body = body, manifest = manifest }
    end

    return session
end
