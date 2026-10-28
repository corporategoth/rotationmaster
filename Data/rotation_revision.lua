-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

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

-- Reads a saved rotation body's content revision counter.
-- @param body table  The rotation body.
-- @return number|nil  The revision (1 when absent); nil when it is invalid.
-- @return string|nil  'invalid-rotation-body' or 'invalid-rotation-revision' when the first return is nil; nil
--   otherwise.
--
-- This saved content revision counter is separate from envelope and source revisions.
function data.GetRotationContentRevision(body)
    if type(body) ~= 'table' or getmetatable(body) ~= nil then
        return nil, 'invalid-rotation-body'
    end

    local value = body.revision

    if value == nil then
        return 1
    end
    if type(value) ~= 'number' or value < 1 or value > maximum or value % 1 ~= 0 then
        return nil, 'invalid-rotation-revision'
    end

    return value
end

-- Tells whether two rotation bodies hold the same content.
-- @param left table  The first body.
-- @param right table  The second body.
-- @return boolean  True when both bodies are portable data and deeply equal apart from the root revision field.
--
-- Ignores only the body's own revision; nested user fields remain content.
function data.SameRotationContent(left, right)
    if not data.CheckPortable(left) or not data.CheckPortable(right) then
        return false
    end

    -- Compares two values deeply.
    -- @param a any  The first value.
    -- @param b any  The second value.
    -- @param root boolean  True for the body itself, whose revision field is ignored.
    -- @return boolean  True when the values are equal.
    local function same(a, b, root)
        if type(a) ~= type(b) then
            return false
        end
        if type(a) ~= 'table' then
            return a == b
        end

        for key, value in pairs(a) do
            if not (root and key == 'revision') and not same(value, b[key], false) then
                return false
            end
        end

        for key in pairs(b) do
            if not (root and key == 'revision') and a[key] == nil then
                return false
            end
        end

        return true
    end

    return same(left, right, true)
end

-- Prepares a detached copy of a rotation body for a commit, stamped with its content revision.
-- @param body table  The body being committed.
-- @param previous table|nil  The body as previously saved; used by the 'edit' mode.
-- @param mode string  'create' (revision 1), 'import' (keeps the incoming revision) or 'edit' (previous revision plus
--   one when the content changed or forceChanged is true; unchanged keeps the previous value, including a legacy
--   absence).
-- @param forceChanged boolean|nil  True to count an edit as changed even when the content is equal.
-- @return table|nil  The stamped copy; nil on failure.
-- @return string|nil  The reason code when the first return is nil (including overflow at the maximum); nil
--   otherwise.
-- @return boolean|nil  Whether the content changed; nil on failure.
--
-- Prepares detached data before a commit and never trusts an editable draft count.
function data.PrepareRotationContentRevision(body, previous, mode, forceChanged)
    local incoming, why = data.GetRotationContentRevision(body)

    if not incoming then
        return nil, why
    end
    if mode ~= 'create' and mode ~= 'import' and mode ~= 'edit' then
        return nil, 'invalid-rotation-revision-policy'
    end

    local revision, changed

    if mode == 'edit' then
        local old, problem = data.GetRotationContentRevision(previous)

        if not old then
            return nil, problem
        end

        changed = forceChanged == true or not data.SameRotationContent(previous, body)

        if changed then
            if old == maximum then
                return nil, 'rotation-revision-overflow'
            end

            revision = old + 1
        else
            revision = previous.revision
        end  -- preserve legacy absence on a no-op
    else
        revision = mode == 'import' and incoming or 1
        changed = true
    end

    local copy, problem = data.CopyData(body)

    if not copy then
        return nil, problem and problem.code or 'invalid-rotation-body'
    end

    copy.revision = revision
    return copy, nil, changed
end
