local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- Alternative text formats for a rotation transfer. Rotation Master's own export (base64) is the default; WowSims
-- (the community simulator's Action Priority List, JSON) is the second one. The conversion code and its data live
-- in the load-on-demand add-on Modules/RotationMaster_WowSims, which this file loads the first time a transfer
-- window needs it: until then nothing of it is in memory. This file only knows which formats exist, where each
-- is available, which one the player last chose (profile.transfer_format), how to ask the module for a
-- conversion and how to turn its answer into what the transfer window shows. docs/quality/wowsims-transport.md
-- describes the format, the mapping and its fidelity vocabulary.
local MODULE_NAME='RotationMaster_WowSims'
local formats={
    rm={id='rm'},
    wowsims={id='wowsims',module=MODULE_NAME,families={era=true,tbc=true,progression=true,forever=true}},
}
local order={'rm','wowsims'}
local registry={}

-- The load-on-demand add-on hands its finished API to this global from its last file.
_G.RotationMasterTransferFormats={Register=function(id,api)
    if type(id)~='string' or not formats[id] or id=='rm' or type(api)~='table' then return false end
    registry[id]=api;return true
end}

local function family()
    local platform=addon.Platform
    local value=platform and type(platform.GetClientFamily)=='function' and platform:GetClientFamily()
    return type(value)=='string' and value or 'unknown'
end

-- Whether a format can be used on this client: WowSims has simulators for Classic Era, TBC, the Wrath, Cataclysm and
-- Mists progression clients and Forever; Retail has none.
function addon:IsTransferFormatAvailable(id)
    local format=formats[id]
    if not format then return false end
    if not format.families then return true end
    return format.families[family()]==true
end
function addon:GetTransferFormatLabel(id)
    if id=='wowsims' then return L['WowSims'] end
    return L['Rotation Master']
end
-- The choices for the Format menu: {value,text,disabled}. WowSims is listed, but cannot be picked, where it does not apply.
function addon:GetTransferFormatChoices()
    local choices={}
    for _,id in ipairs(order) do
        choices[#choices+1]={value=id,text=self:GetTransferFormatLabel(id),disabled=not self:IsTransferFormatAvailable(id) or nil}
    end
    return choices
end
-- Why the menu cannot offer WowSims here, in words; nil when it can.
function addon:GetTransferFormatUnavailableReason()
    if self:IsTransferFormatAvailable('wowsims') then return nil end
    return L['WowSims has no simulator for this game version, so only the Rotation Master format is available here.']
end
-- The format chosen last (kept in the profile), or Rotation Master when it is not available on this client.
function addon:GetTransferFormat()
    local profile=self.db and self.db.profile
    local chosen=type(profile)=='table' and profile.transfer_format or nil
    if chosen~=nil and chosen~='rm' and formats[chosen] and self:IsTransferFormatAvailable(chosen) then return chosen end
    return 'rm'
end
function addon:SetTransferFormat(id)
    local profile=self.db and self.db.profile
    if type(profile)~='table' or not formats[id] or not self:IsTransferFormatAvailable(id) then return false end
    profile.transfer_format=id
    return true
end

-- Loads the add-on of a format (once) and returns its API, or nil and the client's reason.
function addon:LoadTransferFormat(id)
    local format=formats[id]
    if not format or not format.module then return nil,'unknown-format' end
    if registry[id] then return registry[id] end
    if not self:IsTransferFormatAvailable(id) then return nil,'unavailable' end
    local loader=self.transferFormatLoader
    if type(loader)~='function' then loader=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn end
    if type(loader)~='function' then return nil,'no-loader' end
    local ok,loaded,reason=pcall(loader,format.module)
    if registry[id] then return registry[id] end
    if not ok then return nil,'error' end
    return nil,tostring(reason or (loaded and 'NO_API') or 'UNKNOWN_ERROR')
end
function addon:IsTransferFormatLoaded(id) return registry[id]~=nil end

-- ---- what the conversion needs from the game ------------------------------------------------------------------
-- Can this condition run on this client? The editor refuses what cannot; the converter imports such a step disabled
-- and says why (hidden health or power on Forever and Retail, a missing game API).
local function conditionSupport()
    return function(tree)
        local definitions=addon.conditionDefinitions
        local definition=type(definitions)=='table' and definitions[tree.type] or nil
        if not definition then return {ok=false,reason='unknown-condition',code='unknown-condition'} end
        if type(addon.GetConditionSupport)~='function' then return {ok=true} end
        local reason=addon:GetConditionSupport(tree.type,definition,tree)
        if reason then return {ok=false,reason=reason,code=reason} end
        return {ok=true}
    end
end
-- Does the game client know this spell / item id? true, false, or nil when it cannot tell.
local function spellKnownToClient(id)
    local platform=addon.Platform
    if not platform or type(platform.GetSpellInfo)~='function' then return nil end
    local info,why=platform:GetSpellInfo(id)
    if info then return true end
    if why=='spell-data-unavailable' then return false end
    return nil
end
local function itemKnownToClient(id)
    local platform=addon.Platform
    if not platform or type(platform.GetItemInfoInstant)~='function' then return nil end
    local info,why=platform:GetItemInfoInstant(id)
    if info then return true end
    if why=='item-data-unavailable' then return false end
    return nil
end
-- The client's edition (the simulator family) and the player's class for a rotation transfer.
function addon:GetTransferFormatTarget(spec)
    local context=type(self.GetRotationContext)=='function' and self:GetRotationContext(spec) or nil
    local value=type(context)=='table' and context.family or family()
    local class=type(context)=='table' and context.class or nil
    return type(value)=='string' and value or 'unknown',type(class)=='string' and class or nil
end

-- A condition-support reason (Core/condition_support.lua) in words, for "not available on this client (...)".
local function supportReason(code)
    local words={
        ['unsupported-policy']=L['combat data is restricted on this client'],
        ['combat-log-unavailable']=L['the combat log is not available to addons on this client'],
        ['secret-health']=L['health is secret on this client'],
        ['secret-power']=L['this power is secret on this client'],
        ['no-ranged-slot']=L['this client has no ranged slot'],
        ['specialization-unsupported']=L['this client has no specializations for your class'],
        ['missing-api']=L['the game API it needs is missing'],
        ['unsupported-client']=L['this client is not supported'],
        ['talent-layout-mismatch']=L['this client uses a different talent system'],
        ['historical-talent-layout']=L['this client uses a different talent system'],
        ['unsupported-talent-layout']=L['this client uses a different talent system'],
        ['unsupported-glyph-layout']=L['glyphs are not supported on this client build'],
        ['unsupported-point-expansion']=L['this edition has no point resource'],
        ['unknown-condition']=L['Rotation Master has no such condition'],
    }
    return words[code] or tostring(code)
end

-- A reason, in words, a format could not be used.
local function describeLoadFailure(reason)
    return string.format(L['The WowSims converter could not be loaded (%s). Rotation Master keeps working; use the Rotation Master format.'],tostring(reason))
end

local function className(token)
    local names=LOCALIZED_CLASS_NAMES_MALE
    return type(names)=='table' and type(names[token])=='string' and names[token] or token
end
local function format(text,params)
    return (text:gsub('{([%w_]+)}',function(key) local value=params[key];if value==nil then return nil end return tostring(value) end))
end

-- A converter's report in words, for the report window. direction is 'import' or 'export'.
function addon:RenderTransferFormatReport(id,report,direction)
    local api=self:LoadTransferFormat(id)
    if not api or type(report)~='table' then return nil end
    local options={classLabel=className,supportReason=supportReason,editionLabel=function(e) return self:GetTransferFormatEditionLabel(e) end}
    if direction=='export' then return api.renderExportReport(report,L,options) end
    return api.renderImportReport(report,L,options)
end

-- WowSims text -> a Rotation Master rotation for the transfer window. Returns
--   {body=<rotation body>,report=<the converter's report>,warnings=...,text=<the report, worded>,target=...}
-- or nil and a message in words (and, as a third value, the converter's failure for the window to inspect).
function addon:ConvertRotationFromFormat(id,text,spec)
    if not self:IsTransferFormatAvailable(id) then return nil,self:GetTransferFormatUnavailableReason() or describeLoadFailure('unavailable') end
    local api,why=self:LoadTransferFormat(id)
    if not api then return nil,describeLoadFailure(why) end
    local edition,class=self:GetTransferFormatTarget(spec)
    if not api.supportsEdition(edition) then return nil,self:GetTransferFormatUnavailableReason() or L['WowSims has no simulator for this game version, so only the Rotation Master format is available here.'] end
    local counter=0
    local ok,result=pcall(api.import,text,{edition=edition,cls=class,supports=conditionSupport(),checkSpell=spellKnownToClient,checkItem=itemKnownToClient,
        newId=function() counter=counter+1;return 'ws-'..counter end})
    if not ok then return nil,string.format(L['The WowSims text could not be converted: %s'],tostring(result)) end
    if not result.ok then
        local message=api.describeError(result,L,{class=class,edition=edition,classLabel=className,editionLabel=function(e) return self:GetTransferFormatEditionLabel(e) end})
        return nil,message,result
    end
    local report,target=result.report,result.target
    local summary=report.summary
    local label=className(target.cls)
    local name=report.detected and report.detected.name
    local body={
        name=format(L['WowSims import: {label}'],{label=name and name~='' and name or label}):sub(1,256),
        description=format(L['Imported from a WowSims rotation (APL). Steps: {steps}, disabled: {disabled}, items not imported: {skipped}. Review the disabled steps before enabling them.'],
            {steps=summary.steps,disabled=summary.disabled,skipped=summary.skipped}),
        tags=result.body.tags,rotation=result.body.rotation,cooldowns=result.body.cooldowns,
    }
    return {body=body,report=report,target=target,text=self:RenderTransferFormatReport(id,report,'import')}
end

-- A Rotation Master rotation (an envelope or a body) -> WowSims JSON text for the transfer window. Returns
--   {text=<the settings JSON>,aplText=<the rotation only>,report=,reportText=<the report, worded>}
-- or nil and a message in words.
function addon:ConvertRotationToFormat(id,source,spec)
    if not self:IsTransferFormatAvailable(id) then return nil,self:GetTransferFormatUnavailableReason() or describeLoadFailure('unavailable') end
    local api,why=self:LoadTransferFormat(id)
    if not api then return nil,describeLoadFailure(why) end
    local edition,class=self:GetTransferFormatTarget(spec)
    if not api.supportsEdition(edition) then return nil,self:GetTransferFormatUnavailableReason() end
    if type(source)~='table' then return nil,string.format(L['Export unavailable: %s'],'no-rotation') end
    local body=type(source.body)=='table' and source.body or source
    local ok,result=pcall(api.export,body,{edition=edition,cls=class})
    if not ok then return nil,string.format(L['The rotation could not be converted to WowSims: %s'],tostring(result)) end
    if not result.ok then return nil,api.describeError(result,L,{class=class,edition=edition,classLabel=className}) end
    result.reportText=self:RenderTransferFormatReport(id,result.report,'export')
    return result
end

-- The game edition in words, for the reports (the names the rest of Rotation Master uses).
function addon:GetTransferFormatEditionLabel(edition)
    if edition=='era' then return L['Classic Era']
    elseif edition=='tbc' then return L['TBC']
    elseif edition=='progression' then return L['Classic Progression']
    elseif edition=='forever' then return L['Forever'] end
    return tostring(edition)
end
