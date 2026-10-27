-- Content revision counter of a saved rotation body: reads it, compares bodies ignoring it, and computes the next one
-- when a rotation is created, imported or edited.
-- It owns the rule that the counter moves only when content really changes; it never writes saved data itself, it
-- returns a detached copy for the caller to commit. The counter is separate from envelope and Built In source
-- revisions.
-- Loaded from RotationMaster.toc after Data/plain.lua (addon.RotationData, CheckPortable, CopyData) and before
-- Data/tags.lua. Revisions are integers from 1 to 2^53-1; an absent counter reads as 1 (legacy bodies).
local _, addon = ...
local data = addon.RotationData
local maximum = 9007199254740991

-- This saved content revision counter is separate from envelope/source revisions.
-- Returns the body's revision (1 when absent), or nil and 'invalid-rotation-body' / 'invalid-rotation-revision'.
function data.GetRotationContentRevision(body)
    if type(body) ~= 'table' or getmetatable(body) ~= nil then return nil, 'invalid-rotation-body' end
    local value = body.revision
    if value == nil then return 1 end

    if type(value) ~= 'number' or value < 1 or value > maximum or value % 1 ~= 0 then
        return nil, 'invalid-rotation-revision'
    end

    return value
end

-- Ignore only the body's own revision; nested user fields remain content.
-- Returns true when both bodies are portable data and deeply equal apart from the root revision field.
function data.SameRotationContent(left, right)
    if not data.CheckPortable(left) or not data.CheckPortable(right) then return false end

    local function same(a, b, root)
        if type(a) ~= type(b) then return false end
        if type(a) ~= 'table' then return a == b end

        for key, value in pairs(a) do
            if not (root and key == 'revision') and not same(value, b[key], false) then return false end
        end

        for key in pairs(b) do
            if not (root and key == 'revision') and a[key] == nil then return false end
        end

        return true
    end

    return same(left, right, true)
end

-- Prepare detached data before a commit. Never trust an editable draft count.
-- mode is 'create' (revision 1), 'import' (keeps the incoming revision) or 'edit' (previous revision plus one when the
-- content changed or forceChanged is true; unchanged keeps the previous value, including a legacy absence).
-- Returns the stamped copy, nil and the changed flag; or nil and a reason code (including overflow at the maximum).
function data.PrepareRotationContentRevision(body, previous, mode, forceChanged)
    local incoming, why = data.GetRotationContentRevision(body)
    if not incoming then return nil, why end
    if mode ~= 'create' and mode ~= 'import' and mode ~= 'edit' then return nil, 'invalid-rotation-revision-policy' end
    local revision, changed

    if mode == 'edit' then
        local old, problem = data.GetRotationContentRevision(previous)
        if not old then return nil, problem end
        changed = forceChanged == true or not data.SameRotationContent(previous, body)

        if changed then
            if old == maximum then return nil, 'rotation-revision-overflow' end
            revision = old + 1
        else
            revision = previous.revision
        end  -- preserve legacy absence on a no-op
    else
        revision = mode == 'import' and incoming or 1
        changed = true
    end

    local copy, problem = data.CopyData(body)
    if not copy then return nil, problem and problem.code or 'invalid-rotation-body' end
    copy.revision = revision
    return copy, nil, changed
end
