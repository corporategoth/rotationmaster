local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

local function failure(reason)
    if reason=='script-profile-disabled' then
        return L['CPU capture requires WoW scriptProfile to be enabled before a reload. RM does not change this setting.']
    elseif reason=='running' or reason=='already-running' then return L['CPU capture is running. Open the report after it finishes.']
    elseif reason=='not-captured' then return L['No CPU capture is available. Start a capture first.']
    elseif reason=='not-running' then return L['No CPU capture is running.'] end
    return L['CPU capture is unavailable: %s']:format(tostring(reason or L['Unknown']))
end

-- These actions affect diagnostic state only, independently of settings drafts.
function addon:RunCPUProfileAction(action)
    local ok,message
    if action==nil or action=='' or action=='start' then
        local reason;ok,reason=self:StartCPUProfile(10)
        message=ok and L['CPU capture started for 10 seconds. Close configuration to measure normal gameplay, then open CPU report.'] or failure(reason)
    elseif action=='cancel' then
        local reason;ok,reason=self:CancelCPUProfile()
        message=ok and L['CPU capture cancelled.'] or failure(reason)
    elseif action=='report' then
        local report,reason=self:GetCPUProfileReport()
        if report then self:ShowConditionText(report,L['CPU profile']);return true,'' end
        ok=false;message=failure(reason)
    else
        ok=false;message=L['Usage: /rm cpu [start|report|cancel]']
    end
    self:print(message)
    return ok,message
end

function addon:OnCPUProfileFinished(_,status)
    if status=='complete' then
        self:print(L['CPU capture complete. Use General > CPU report or /rm cpu report to view and copy it.'])
    elseif status=='invalid' then
        self:print(L['CPU capture could not produce valid measurements. Open CPU report for details.'])
    end
end
