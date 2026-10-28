-- Platform adapter for C_LossOfControl: the crowd-control effects currently on the player.
-- Owns two `value or nil, reason` readers, the number of active effects and one field of one effect; it must not
-- decide which effects matter to a rotation. Both run under the probe and restricted policies and refuse more than
-- 256 effects as a work budget. Both readers are Built In helpers: their bodies are recorded in the generated block at
-- the end of the file and must keep their exact text. Loaded from RotationMaster.toc after Platform/zone_pvp.lua.
local _, addon = ...
local platform = addon.Platform

-- Counts the loss of control effects currently on the player (C_LossOfControl.GetActiveLossOfControlDataCount).
-- @return number|nil  The number of active effects; nil when it cannot be read or exceeds the 256 scan limit.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- The scan limit is an RM resource budget, not a declared native maximum.
function platform:GetLossOfControlCount()
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    local namespace=C_LossOfControl
    if not self:CanReadValue(namespace) then return nil,'restricted-value' end
    if type(namespace)~='table' then return nil,'missing-api' end
    local methodOk,method=pcall(function() return namespace.GetActiveLossOfControlDataCount end)
    if not methodOk then return nil,'api-error' end
    if not self:CanReadValue(method) then return nil,'restricted-value' end
    if type(method)~='function' then return nil,'missing-api' end
    local ok,count=pcall(method)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(count) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(count) then return nil,'restricted-value' end
    if count==nil then return nil,'loss-of-control-count-unavailable' end
    if type(count)~='number' or count~=count or count==math.huge or count==-math.huge or count<0 or count%1~=0 then return nil,'invalid-api-result' end
    if count>256 then return nil,'loss-of-control-budget-exceeded' end
    return count
end

-- Reads one field of one active loss of control effect (C_LossOfControl.GetActiveLossOfControlData).
-- @param index number  The effect's position, an integer from 1 to 256.
-- @param kind string  Which subject to read: "type" (the locType string) or "school" (the lockoutSchool number).
-- @return table|nil  The record { locType = string } or { lockoutSchool = number } for the requested subject, plus
--   timeRemaining (number) or timeRemainingReason (string); nil when the subject itself cannot be read.
-- @return string|nil  The reason code when the first return is nil; nil otherwise.
--
-- Only the requested subject is required. Timing readiness stays on the row so an unrelated event with unknown
-- duration does not block a later match.
function platform:GetLossOfControlEvent(index, kind)
    local policy=self:GetCombatDataPolicy()
    if policy~='probe' and policy~='restricted' then return nil,'unsupported-policy' end
    if not self:CanReadValue(index) or not self:CanReadValue(kind) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(index) then return nil,'restricted-value' end
    if type(index)~='number' or index~=index or index==math.huge or index==-math.huge or index<1 or index%1~=0 then return nil,'invalid-loss-of-control-query' end
    if kind~='type' and kind~='school' then return nil,'invalid-loss-of-control-query' end
    if index>256 then return nil,'loss-of-control-budget-exceeded' end
    local namespace=C_LossOfControl
    if not self:CanReadValue(namespace) then return nil,'restricted-value' end
    if type(namespace)~='table' then return nil,'missing-api' end
    local methodOk,method=pcall(function() return namespace.GetActiveLossOfControlData end)
    if not methodOk then return nil,'api-error' end
    if not self:CanReadValue(method) then return nil,'restricted-value' end
    if type(method)~='function' then return nil,'missing-api' end
    local ok,event=pcall(method,index)
    if not ok then return nil,'api-error' end
    if not self:CanReadValue(event) then return nil,'restricted-value' end
    if event==nil then return nil,'loss-of-control-event-unavailable' end
    if type(event)~='table' then return nil,'invalid-api-result' end
    local subjectOk,subject=pcall(function() return event[kind=='type' and 'locType' or 'lockoutSchool'] end)
    if not subjectOk then return nil,'api-error' end
    if not self:CanReadValue(subject) then return nil,'restricted-value' end
    if canaccessvalue and not canaccessvalue(subject) then return nil,'restricted-value' end
    if subject==nil then return nil,'loss-of-control-subject-unavailable' end
    local record={}
    if kind=='type' then
        if type(subject)~='string' then return nil,'invalid-api-result' end
        record.locType=subject
    else
        if type(subject)~='number' or subject~=subject or subject==math.huge or subject==-math.huge or subject<0 or subject%1~=0 then return nil,'invalid-api-result' end
        record.lockoutSchool=subject
    end
    local timeOk,remaining=pcall(function() return event.timeRemaining end)
    if not timeOk then record.timeRemainingReason='api-error'
    elseif not self:CanReadValue(remaining) then record.timeRemainingReason='restricted-value'
    elseif canaccessvalue and not canaccessvalue(remaining) then record.timeRemainingReason='restricted-value'
    elseif remaining==nil then record.timeRemainingReason='loss-of-control-time-unavailable'
    elseif type(remaining)~='number' or remaining~=remaining or remaining==math.huge or remaining==-math.huge then record.timeRemainingReason='invalid-api-result'
    else record.timeRemaining=remaining end
    return record
end

-- BEGIN GENERATED RM SOURCE BINDINGS
do
    local function sourceGetter(name)
        if name=="Platform_GetLossOfControlCount" then return addon.Platform.GetLossOfControlCount end
        if name=="Platform_GetLossOfControlEvent" then return addon.Platform.GetLossOfControlEvent end
    end
    if addon.RegisterBuiltinSourceModule then
        addon:RegisterBuiltinSourceModule("Platform/loss_of_control.lua", sourceGetter)
    else
        addon.builtinSourceModules=addon.builtinSourceModules or {}
        addon.builtinSourceModules["Platform/loss_of_control.lua"]=sourceGetter
    end
end
-- END GENERATED RM SOURCE BINDINGS
