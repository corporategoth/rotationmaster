-- Staged import session: holds one decoded import candidate (with its validation) and answers snapshot, ready, compare
-- and preview questions about it, so a transfer window can show what a paste contains before anything is applied.
-- It must never touch saved data, register conditions, evaluate predicates or compile custom Lua; every value it hands
-- out is a detached copy. A token (the staging generation) ties each answer to the candidate it was asked about.
-- Loaded from RotationMaster.toc after Data/visual_comparison.lua and before Data/rotation_store.lua; uses the codec's
-- Decode, data.ValidateEnvelope / ValidateBody (Data/validation.lua) and data.DiffRotations (Data/diff.lua).
local _, addon = ...
local data = addon.RotationData

-- Session-only staging: decoding/validation/comparison cannot touch saved data,
-- register conditions, evaluate predicates, or compile custom Lua.
-- Returns a session object (Clear, GetCandidate, Stage, GetReady, Compare, Preview); asserts when the codec has no
-- Decode.
function data.NewImportSession(codec, options)
    assert(type(codec) == "table" and type(codec.Decode) == "function", "trusted codec required")
    local current, generation = nil, 0
    local session = {}

    -- Validates a candidate as an envelope or as a bare body, depending on how it decoded.
    local function validation(candidate)
        if candidate.kind == "envelope" then return data.ValidateEnvelope(candidate.value, options) end
        return data.ValidateBody(candidate.value, options)
    end

    -- Returns a detached copy of the staged candidate with its token, or nil when nothing is staged. A bare body has an
    -- unknown scope; only an envelope declares one.
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

    -- Drops the staged candidate and advances the generation, which makes every earlier token stale.
    function session:Clear()
        current = nil
        generation = generation + 1
    end

    -- Returns the current candidate snapshot (nil when nothing is staged).
    function session:GetCandidate()
        return snapshot()
    end

    -- Decodes pasted text and stages it as the new candidate (replacing any earlier one), validated but not applied.
    -- Returns the snapshot, or nil and the codec's reason when the text does not decode.
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

    -- Re-validates the candidate and returns the importable pieces (kind, detached body, body-free manifest), or nil
    -- and 'stale-import', 'invalid-import', 'unsupported-import' or 'unresolved-import'. Only a ready candidate may
    -- be applied.
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

    -- Compares a saved rotation body (left) with the staged candidate (right) and returns the diff record, or nil and a
    -- reason ('stale-import', 'no-previewable-body' or a comparison error code). Works on data only.
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
