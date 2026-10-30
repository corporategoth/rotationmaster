-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Strict complete f7cfe4f module inverse of the composed manual-choice slice.
local rows = {
    ['main.lua'] = {
        bytes = 92461,
        hash = '6986a417',
        oldBytes = 91122,
        oldHash = '16746958',
        edits = {
            {
                at = 586,
                current = [========[
local prepareChoiceSelection,finishChoiceSelection,readDesiredChoice,choiceNeedsRefresh
local invalidateChoiceContext=addon.InvalidateRotationChoiceContext
local invalidateChoiceDependencies=addon.InvalidateRotationDependencies
local consumeChoices=addon.ConsumeRotationChoiceSelection
if type(consumeChoices)=='function' then
    prepareChoiceSelection,finishChoiceSelection,readDesiredChoice,choiceNeedsRefresh=consumeChoices(addon)
    addon.ConsumeRotationChoiceSelection=nil
end
]========],
                previous = [========[
]========],
            },
            {
                at = 2201,
                current = [========[
end
local function activeObjectValue(self,token,object,name,...)
    if not activeChangeCurrent(self,token) then return false end
    local method=object[name]
    if not activeChangeCurrent(self,token) then return false end
    local value=method(object,...)
    return activeChangeCurrent(self,token),value
]========],
                previous = [========[
]========],
            },
            {
                at = 10682,
                current = [========[
-- Chat, menu and cold restoration share the existing active transition path.
local function chooseManualRotation(self,id,change,remember)
    change=change or beginActive(self)
    if not activeChangeCurrent(self,change) then return nil end
    local body=id and runtimeOne(self,self.currentSpec,id)
    if not activeChangeCurrent(self,change) or id and not body then return nil end
    local ticket
    if remember and prepareChoiceSelection then
        local reference
        if id then
            local available=self.GetScopedRotationCoordinator
            if not activeChangeCurrent(self,change) then return nil end
            local checked,coordinator
            if available then checked,coordinator=activeValue(self,change,'GetScopedRotationCoordinator');if not checked then return nil end end
            if coordinator then checked,reference=activeObjectValue(self,change,coordinator,'Resolve',self.currentSpec,id);if not checked then return nil end end
        end
        if not id or reference then ticket=prepareChoiceSelection(self,reference) end
        if not activeChangeCurrent(self,change) then return nil end
    end
    if ticket and invalidateChoiceDependencies then
        invalidateChoiceDependencies(self,'selection',nil)
        if not activeChangeCurrent(self,change) then return nil end
    end
    self.rotationChoiceSuspended=nil
    if id==nil then
        if ticket then finishChoiceSelection(ticket) end
        self.manualRotation=false
        return self:SwitchRotation()
    end
    local selected=self.currentRotation
    if not activeChangeCurrent(self,change) then return nil end
    if selected~=id then
        if not retireActive(self,change) or not activeChangeCurrent(self,change) then return nil end
        if not activeCall(self,change,'RemoveAllCurrentGlows') then return nil end
        if not commitActive(self,change,self.currentSpec,id,body) or not activeChangeCurrent(self,change) then return nil end
        self.manualRotation=true
        self.skipAnnounce=true;self.avail_announced={};self.announced={}
        if not activeCall(self,change,'EnableRotationTimer') then return nil end
        local named,name=activeValue(self,change,'GetRotationName',id)
        if not named or not activeBroker(self,change,DataBroker,name) then return nil end
        if not activeObjectCall(self,change,AceEvent,'SendMessage','ROTATIONMASTER_ROTATION',id,name) then return nil end
    else self.manualRotation=true end
    if remember then
        local named,name=activeValue(self,change,'GetRotationName',id)
        if not named or not activeCall(self,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name) then return nil end
        local checked,valid=activeValue(self,change,'rotationValidConditions',body,self.currentSpec)
        if not checked then return nil end
        if not valid and not activeCall(self,change,'warn',L["Active rotation is incomplete and may not work correctly!"]) then return nil end
        if ticket then finishChoiceSelection(ticket) end
    end
    return true,change
end

local function restoreManualChoice(self)
    if choiceNeedsRefresh and choiceNeedsRefresh(self) then
        local change=beginActive(self)
        if not activeChangeCurrent(self,change) then return true end
        local desired,changed=readDesiredChoice(self)
        if not activeChangeCurrent(self,change) then return true end
        if self.adviceErrorReport or self.initializationErrorReport then return true end
        if changed then
            local wasManual=self.manualRotation
            if not activeChangeCurrent(self,change) then return true end
            self.rotationChoiceSuspended=nil
            self.manualRotation=false
            if desired then
                local available=self.GetScopedRotationCoordinator
                if not activeChangeCurrent(self,change) then return true end
                local checked,coordinator,reference,key
                if available then checked,coordinator=activeValue(self,change,'GetScopedRotationCoordinator');if not checked then return true end end
                if coordinator then
                    checked,reference=activeObjectValue(self,change,coordinator,'Resolve',self.currentSpec,desired)
                    if not checked then return true end
                    if reference then checked,key=activeObjectValue(self,change,coordinator,'Key',reference);if not checked then return true end end
                end
                if not activeChangeCurrent(self,change) then return true end
                if reference and chooseManualRotation(self,key,change,false) then return true,change end
                if not activeChangeCurrent(self,change) then return true end
                self.rotationChoiceSuspended=true
            end
            if wasManual and self.currentRotation then
                local disable=self.DisableRotation
                if not activeChangeCurrent(self,change) then return true end
                local _,nextChange,stopped=disable(self)
                if stopped==false then return true end
                change=nextChange or change
                if not activeChangeCurrent(self,change) then return true end
            end
        end
        return false,change
    end
    return false
end

]========],
                previous = [========[
]========],
            },
            {
                at = 16872,
                current = [========[
        addon:print(L["                          Manual choices are remembered for this character, specialization and action context."])
]========],
                previous = [========[
        addon:print(L["                          This is reset upon switching specializations."])
]========],
            },
            {
                at = 18703,
                current = [========[
        if name=="auto" then
            chooseManualRotation(self,nil,change,true)
        elseif name==self.currentRotation or name==DEFAULT then
            if not chooseManualRotation(self,name,change,true) and activeChangeCurrent(self,change) and name==DEFAULT then
                self:warn(L['The fallback rotation is unavailable. Open Rotations to complete or recover it.'])
]========],
                previous = [========[
        if name == "auto" then
            self.manualRotation = false
            self:SwitchRotation()
        elseif name == self.currentRotation then
            self.manualRotation = true
            activeCall(self,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name)
        elseif name == DEFAULT then
            if self.GetScopedRotationCoordinator and self:GetScopedRotationCoordinator() and not runtimeOne(self,self.currentSpec,DEFAULT) then
                addon:warn(L['The fallback rotation is unavailable. Open Rotations to complete or recover it.']);return
]========],
            },
            {
                at = 19102,
                current = [========[
        else
            local matches={}
            for id,rot in pairs(runtimeRows(self,self.currentSpec)) do if rot.name==name then matches[#matches+1]=id end end
]========],
                previous = [========[
]========],
            },
            {
                at = 19337,
                current = [========[
            if #matches>1 then self:warn(L['More than one rotation is named %s. Select its Class or This character entry in the rotation browser.'],name);return end
            if #matches==1 then chooseManualRotation(self,matches[1],change,true);return end
            self:warn(L["Could not find rotation named " .. color.WHITE .. "%s" .. color.WARN .. " for your current specialization."],name)
]========],
                previous = [========[
            local body=runtimeOne(self,self.currentSpec,DEFAULT)
            if not activeChangeCurrent(self,change) or not body then return end
            if not retireActive(self,change) or not activeChangeCurrent(self,change) then return end
            if not activeCall(self,change,'RemoveAllCurrentGlows') then return end
            if not commitActive(self,change,self.currentSpec,DEFAULT,body) or not activeChangeCurrent(self,change) then return end
            self.manualRotation = true
            self.skipAnnounce = true
            self.avail_announced = {}
            self.announced = {}
            if not activeCall(self,change,'EnableRotationTimer') then return end
            local named,displayName=activeValue(self,change,'GetRotationName',DEFAULT)
            if not named then return end
            if not activeBroker(self,change,DataBroker,displayName) then return end
            local namedCurrent,currentName=activeValue(self,change,'GetRotationName',self.currentRotation)
            if not namedCurrent then return end
            if not activeObjectCall(self,change,AceEvent,'SendMessage',"ROTATIONMASTER_ROTATION",self.currentRotation,currentName) then return end
            if not activeChangeCurrent(self,change) then return end
            activeCall(self,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name)
        else
            do
                local matches={}
                for id,rot in pairs(runtimeRows(self,self.currentSpec)) do if rot.name==name then matches[#matches+1]={id=id,body=rot} end end
                if not activeChangeCurrent(self,change) then return end
                if #matches>1 then addon:warn(L['More than one rotation is named %s. Select its Class or This character entry in the rotation browser.'],name);return end
                for _,entry in ipairs(matches) do
                    local id,rot=entry.id,entry.body
                    if rot.name == name then
                        if not activeChangeCurrent(self,change) then return end
                        if not retireActive(self,change) or not activeChangeCurrent(self,change) then return end
                        if not activeCall(self,change,'RemoveAllCurrentGlows') then return end
                        if not commitActive(self,change,self.currentSpec,id,rot) or not activeChangeCurrent(self,change) then return end
                        self.manualRotation = true
                        self.skipAnnounce = true
                        self.avail_announced = {}
                        self.announced = {}
                        if not activeCall(self,change,'EnableRotationTimer') then return end
                        local named,displayName=activeValue(self,change,'GetRotationName',id)
                        if not named then return end
                        if not activeBroker(self,change,DataBroker,displayName) then return end
                        local namedCurrent,currentName=activeValue(self,change,'GetRotationName',self.currentRotation)
                        if not namedCurrent then return end
                        if not activeObjectCall(self,change,AceEvent,'SendMessage',"ROTATIONMASTER_ROTATION",self.currentRotation,currentName) then return end
                        if not activeChangeCurrent(self,change) then return end
                        activeCall(self,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name)
                        if not activeChangeCurrent(self,change) then return end
                        local checked,valid=activeValue(self,change,'rotationValidConditions',rot,self.currentSpec)
                        if not checked then return end
                        if not valid then activeCall(self,change,'warn',L["Active rotation is incomplete and may not work correctly!"]) end
                        return
                    end
                end
            end
            addon:warn(L["Could not find rotation named " .. color.WHITE .. "%s" .. color.WARN .. " for your current specialization."], name)
]========],
            },
            {
                at = 24186,
                current = [========[
    self.rotationChoiceSuspended=nil
]========],
                previous = [========[
]========],
            },
            {
                at = 26349,
                current = [========[
local function minimapChangeRotation(_,arg1)
    chooseManualRotation(addon,arg1,nil,true)
]========],
                previous = [========[
local function minimapChangeRotation(_, arg1, _, _)
    local change=beginActive(addon)
    if not activeChangeCurrent(addon,change) then return end
    if arg1 == nil then
        addon.manualRotation = false
        addon:SwitchRotation()
    else
        if addon.currentSpec ~= arg1 then
            local body=runtimeOne(addon,addon.currentSpec,arg1)
            if not activeChangeCurrent(addon,change) or not body then return end
            if not retireActive(addon,change) or not activeChangeCurrent(addon,change) then return end
            if not activeCall(addon,change,'RemoveAllCurrentGlows') then return end
            if not commitActive(addon,change,addon.currentSpec,arg1,body) or not activeChangeCurrent(addon,change) then return end
            addon.skipAnnounce = true
            addon.avail_announced = {}
            addon.announced = {}
            if not activeCall(addon,change,'EnableRotationTimer') then return end
            local named,name=activeValue(addon,change,'GetRotationName',arg1)
            if not named then return end
            if not activeBroker(addon,change,DataBroker,name) then return end
            local namedCurrent,currentName=activeValue(addon,change,'GetRotationName',addon.currentRotation)
            if not namedCurrent then return end
            if not activeObjectCall(addon,change,AceEvent,'SendMessage',"ROTATIONMASTER_ROTATION",addon.currentRotation,currentName) then return end
            if not activeChangeCurrent(addon,change) then return end
        end
        addon.manualRotation = true
        local named,name=activeValue(addon,change,'GetRotationName',arg1)
        if not named then return end
        activeCall(addon,change,'info',L["Active rotation manually switched to " .. color.WHITE .. "%s" .. color.INFO],name)
    end
]========],
            },
            {
                at = 29125,
                current = [========[
    end
    if addon.rotationChoiceSuspended then
        GameTooltip:AddLine(L['Saved manual choice is unavailable in the current context.'],1,0.8,0.2,true)
]========],
                previous = [========[
]========],
            },
            {
                at = 35890,
                current = [========[
    local handled,restoredChange=restoreManualChoice(self)
    if handled then return nil,restoredChange end
]========],
                previous = [========[
]========],
            },
            {
                at = 36069,
                current = [========[
        if restoredChange and not activeChangeCurrent(self,restoredChange) then return end
        return nil,restoredChange
]========],
                previous = [========[
        return
]========],
            },
            {
                at = 64024,
                current = [========[
    if invalidateChoiceContext then invalidateChoiceContext(self) end
]========],
                previous = [========[
]========],
            },
            {
                at = 67702,
                current = [========[
        if invalidateChoiceContext and (event==nil or runtimeContextEvents[event]) then invalidateChoiceContext(self) end
]========],
                previous = [========[
]========],
            },
            {
                at = 72214,
                current = [========[
addon.VEHICLE_UPDATE = wrapEvent(function(self)
    restoreManualChoice(self)
    self:ButtonFetch()
end)
]========],
                previous = [========[
addon.VEHICLE_UPDATE = wrapEvent(addon.ButtonFetch)
]========],
            },
            {
                at = 73067,
                current = [========[
    restoreManualChoice(self)
]========],
                previous = [========[
]========],
            },
        },
    },
    ['Core/rotation_scope.lua'] = {
        bytes = 67096,
        hash = '9b4c4157',
        oldBytes = 66058,
        oldHash = '9703e477',
        edits = {
            {
                at = 536,
                current = [========[
local prepareChoicePublication,finishChoicePublication
local consumeChoices=addon.ConsumeRotationChoicePublication
if type(consumeChoices)=='function' then
    prepareChoicePublication,finishChoicePublication=consumeChoices(addon)
    addon.ConsumeRotationChoicePublication=nil
end
local invalidateChoiceContext=addon.InvalidateRotationChoiceContext
]========],
                previous = [========[
]========],
            },
            {
                at = 7774,
                current = [========[
    if invalidateChoiceContext then invalidateChoiceContext(addon) end
]========],
                previous = [========[
]========],
            },
            {
                at = 23447,
                current = [========[
        local choicePublication=prepareChoicePublication and prepareChoicePublication(profile,reference,target)
]========],
                previous = [========[
]========],
            },
            {
                at = 23602,
                current = [========[
        local readyNow,currentProblem=ready();if not readyNow then return nil,currentProblem end
]========],
                previous = [========[
        local current,currentProblem=ready();if not current then return nil,currentProblem end
]========],
            },
            {
                at = 24425,
                current = [========[
        if finishChoicePublication then finishChoicePublication(choicePublication,alive and current==coordinator) end
]========],
                previous = [========[
]========],
            },
            {
                at = 25876,
                current = [========[
        local choicePublication=prepareChoicePublication and prepareChoicePublication(profile,reference,nil)
]========],
                previous = [========[
]========],
            },
            {
                at = 26207,
                current = [========[
        if finishChoicePublication then finishChoicePublication(choicePublication,alive and current==coordinator) end
]========],
                previous = [========[
]========],
            },
            {
                at = 26527,
                current = [========[
        assets[index]=nil;expected[token]=nil
        return true
]========],
                previous = [========[
        assets[index]=nil;expected[token]=nil;return true
]========],
            },
            {
                at = 30458,
                current = [========[
        if finishChoicePublication then finishChoicePublication(nil) end
]========],
                previous = [========[
]========],
            },
            {
                at = 42970,
                current = [========[
            if finishChoicePublication then finishChoicePublication(nil) end
]========],
                previous = [========[
]========],
            },
        },
    },
    ['Core/rotation_library.lua'] = {
        bytes = 44840,
        hash = 'f333471e',
        oldBytes = 44694,
        oldHash = '858703e0',
        edits = {
            {
                at = 31,
                current = [========[
local invalidateChoiceContext=addon.InvalidateRotationChoiceContext
]========],
                previous = [========[
]========],
            },
            {
                at = 17833,
                current = [========[
    if saved then active.views[id]=active.catalog:Get({kind="builtin",id=id});active.generation={}
        if invalidateChoiceContext then invalidateChoiceContext(self) end
    end
]========],
                previous = [========[
    if saved then active.views[id]=active.catalog:Get({kind="builtin",id=id});active.generation={} end
]========],
            },
        },
    },
    ['Core/profile_data.lua'] = {
        bytes = 13665,
        hash = '7e778643',
        oldBytes = 13126,
        oldHash = 'd41fb4fc',
        edits = {
            {
                at = 3954,
                current = [========[
local function validRotationChoices(owner,profile)
    local value=type(profile)=='table' and rawget(profile,'rotationChoicePreferences')
    return value==nil or type(owner.ValidateRotationChoicePreferences)=='function' and owner:ValidateRotationChoicePreferences(value)==true
end
]========],
                previous = [========[
]========],
            },
            {
                at = 4332,
                current = [========[
    if not validStockTargets(self,value) or not validRotationChoices(self,value) then return false end
]========],
                previous = [========[
    if not validStockTargets(self,value) then return false end
]========],
            },
            {
                at = 6899,
                current = [========[
        elseif key=='rotationChoicePreferences' then
            -- Closed optional schema checked before generic recursive copying.
]========],
                previous = [========[
]========],
            },
            {
                at = 11325,
                current = [========[
    if not validStockTargets(self,profile) or not validRotationChoices(self,profile) then return nil end
]========],
                previous = [========[
    if not validStockTargets(self,profile) then return nil end
]========],
            },
            {
                at = 12198,
                current = [========[
    if not validStockTargets(self,profile) or not validRotationChoices(self,profile) then return nil end
]========],
                previous = [========[
    if not validStockTargets(self,profile) then return nil end
]========],
            },
        },
    },
    ['Locales/enUS.lua'] = {
        bytes = 236594,
        hash = '06a208da',
        oldBytes = 236483,
        oldHash = '6d83822f',
        edits = {
            {
                at = 11256,
                current = [========[
L["                          Manual choices are remembered for this character, specialization and action context."] = true
]========],
                previous = [========[
L["                          This is reset upon switching specializations."] = true
]========],
            },
            {
                at = 178782,
                current = [========[
L['Saved manual choice is unavailable in the current context.'] = true

]========],
                previous = [========[
]========],
            },
        },
    },
    ['RotationMaster.toc'] = {
        bytes = 7999,
        hash = 'fe0a0c59',
        oldBytes = 7962,
        oldHash = '7260f5bc',
        edits = {
            {
                at = 3575,
                current = [========[
Core/rotation_choice_preferences.lua
]========],
                previous = [========[
]========],
            },
        },
    },
}

local function hash(s)
    local n = 5381

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return string.format('%08x', n)
end

return function(text, path)
    text = dofile('tests/fixtures/restore_unit_states.lua')(text, path)

    if
        path == "main.lua" and text:find("-- BEGIN ANNOUNCEMENT CONDITION OWNER", 1, true)
        or path == "Locales/enUS.lua" and text:find('L["Edit announcement conditions"]', 1, true)
        or path == "RotationMaster.toc" and text:find('Platform/announcement_recipient.lua', 1, true)
    then
        text = dofile("tests/fixtures/restore_announcement_conditions.lua")(text, path)
    end

    local row = assert(rows[path], 'unknown manual-choice inverse path')
    assert(#text == row.bytes and hash(text) == row.hash, 'unrelated manual-choice module: ' .. path)

    for i = #row.edits, 1, -1 do
        local c = row.edits[i]
        assert(text:sub(c.at, c.at + #c.current - 1) == c.current, 'manual-choice inverse delta mismatch')
        text = text:sub(1, c.at - 1) .. c.previous .. text:sub(c.at + #c.current)
    end

    assert(#text == row.oldBytes and hash(text) == row.oldHash, 'manual-choice predecessor mismatch: ' .. path)
    return text
end
