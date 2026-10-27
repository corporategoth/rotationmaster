local _, addon = ...
local owner = addon
local identity = rawequal
local epoch, stamp = 0, {}
local bound = false
local executionStamp = {}

local function readExecutionGeneration()
    return executionStamp
end

local function advanceExecutionGeneration()
    executionStamp = {}
    return executionStamp
end

-- Trusted startup modules capture the same continuation clock. Content
-- revisions remain separate; the clock only retires in-flight execution.
function addon:BindRotationExecutionGeneration(receiver)
    if not identity(self, owner) then return nil, 'foreign-dependency-owner' end
    if type(receiver) ~= 'function' then return nil, 'invalid-execution-generation-binder' end
    receiver(readExecutionGeneration, advanceExecutionGeneration)
    return true
end

-- Managed shared dependency writes notify once before returning to selection.
-- Optional kind/id describe a cold publication; this aggregate foundation does
-- not build dependency lists or alter persisted rotation content revisions.
function addon:InvalidateRotationDependencies(kind, id)
    if not identity(self, owner) then return nil, 'foreign-dependency-owner' end
    advanceExecutionGeneration()
    local nextEpoch = epoch + 1
    if nextEpoch > epoch then epoch = nextEpoch end
    -- The opaque stamp never repeats, including numeric precision exhaustion.
    stamp = {}
    return true
end

-- One startup consumer receives the actual owner's private generation reader.
function addon:BindRotationDependencyReader(bind)
    if not identity(self, owner) then return nil, 'foreign-dependency-owner' end
    if type(bind) ~= 'function' then return nil, 'invalid-dependency-reader-binder' end
    if bound then return nil, 'dependency-reader-already-bound' end
    bound = true

    bind(function(current)
        if not identity(current, owner) then return nil end
        return stamp, epoch
    end)

    return true
end
