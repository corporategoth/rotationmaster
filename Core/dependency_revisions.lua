-- Dependency revision service: the private execution generation (a table stamp that is replaced on every managed
-- dependency write) and the aggregate dependency stamp and epoch that rotation_references.lua reads. It owns that state
-- and hands it out only through bind callbacks at startup; it must not scan or copy any dependency map itself.
-- Loaded straight after globals.lua (before Platform/ and every dependency writer) so writers can capture
-- InvalidateRotationDependencies; see docs/architecture/runtime-revisions.md.

local _, addon = ...
local owner = addon
local identity = rawequal
-- The dependency epoch counts writes; the stamp is an opaque table so a stale reader can never match a new one.
local epoch, stamp = 0, {}
local bound = false
local executionStamp = {}

-- Returns the current execution generation stamp.
-- @return table  The stamp; callers compare it by identity only.
local function readExecutionGeneration()
    return executionStamp
end

-- Retires every in-flight execution by replacing the stamp with a fresh table.
-- @return table  The new execution generation stamp.
local function advanceExecutionGeneration()
    executionStamp = {}
    return executionStamp
end

-- Hands the execution-generation reader and advancer to one trusted startup module.
-- @param receiver function  Called as receiver(read, advance) with the two private closures.
-- @return boolean|nil  True when the receiver was called; nil on refusal.
-- @return string|nil  The reason code on refusal ('foreign-dependency-owner' or 'invalid-execution-generation-binder');
--   nil otherwise.
--
-- Trusted startup modules capture the same continuation clock. Content revisions remain separate; the clock only
-- retires
-- in-flight execution.
function addon:BindRotationExecutionGeneration(receiver)
    if not identity(self, owner) then
        return nil, 'foreign-dependency-owner'
    end
    if type(receiver) ~= 'function' then
        return nil, 'invalid-execution-generation-binder'
    end

    receiver(readExecutionGeneration, advanceExecutionGeneration)
    return true
end

-- Notifies that a managed shared dependency was written; retires in-flight executions and moves the dependency stamp
-- and epoch on.
-- @param kind string|nil  The kind of dependency that changed; currently unused.
-- @param id any|nil  The identity of the dependency that changed; currently unused.
-- @return boolean|nil  True when the notification was recorded; nil when the caller is not the owner.
-- @return string|nil  'foreign-dependency-owner' when refused; nil otherwise.
--
-- Managed shared dependency writes notify once before returning to selection. Optional kind/id describe a cold
-- publication; this aggregate foundation does not build dependency lists or alter persisted rotation content revisions.
function addon:InvalidateRotationDependencies(kind, id)
    if not identity(self, owner) then
        return nil, 'foreign-dependency-owner'
    end

    advanceExecutionGeneration()
    local nextEpoch = epoch + 1

    if nextEpoch > epoch then
        epoch = nextEpoch
    end

    -- The opaque stamp never repeats, including numeric precision exhaustion.
    stamp = {}
    return true
end

-- Gives one startup consumer a reader for the dependency stamp and epoch.
-- @param bind function  Called once as bind(reader); reader(addon) returns the current stamp table and epoch number,
--   or nil when the argument is not the owning addon.
-- @return boolean|nil  True when the reader was handed over; nil on refusal.
-- @return string|nil  The reason code on refusal ('foreign-dependency-owner', 'invalid-dependency-reader-binder' or
--   'dependency-reader-already-bound'); nil otherwise.
function addon:BindRotationDependencyReader(bind)
    if not identity(self, owner) then
        return nil, 'foreign-dependency-owner'
    end
    if type(bind) ~= 'function' then
        return nil, 'invalid-dependency-reader-binder'
    end
    if bound then
        return nil, 'dependency-reader-already-bound'
    end

    bound = true

    bind(function(current)
        if not identity(current, owner) then
            return nil
        end

        return stamp, epoch
    end)

    return true
end
