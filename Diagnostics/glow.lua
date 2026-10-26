local addon_name,addon=...
local L=LibStub("AceLocale-3.0"):GetLocale(addon_name)

-- /rm debug glow [seconds]: why a recommendation does or does not light an
-- action button. It walks the chain the engine walks, in order:
--   client and the action bar APIs it offers -> the active rotation -> the
--   button scan (Blizzard bars frame by frame, read exactly as the scan reads
--   them) -> each rotation step (conditions, spell IDs with base/override,
--   the buttons they map to, readiness piece by piece) -> Blizzard's
--   suggestion -> the glow request and the frames it lit
-- and names the first link that drops the recommendation. With seconds, one
-- compact line per second follows (to catch combat, where values differ).
-- The report opens in a copyable window and is kept, newest last, in
-- RotationMasterDB.diagnostics.glow (at most 5 reports of 600 lines), so it
-- survives a /reload and can be read from SavedVariables. Nothing here runs
-- until the command does.

local MAX_REPORTS,MAX_LINES,MAX_STEPS,MAX_WATCH=5,600,24,60

local function readable(value)
    local platform=addon.Platform
    return not platform or type(platform.CanReadValue)~='function' or platform:CanReadValue(value)
end
local function show(value)
    if not readable(value) then return 'secret' end
    if value==nil then return 'nil' end
    if type(value)=='number' and value%1~=0 then return string.format('%.3f',value) end
    return tostring(value)
end
local function protect(fn,...)
    if type(fn)~='function' then return false,'missing' end
    return pcall(fn,...)
end
local function apiPresence(name,namespace)
    if namespace then
        local space=rawget(_G,namespace)
        return type(space)=='table' and type(space[name])=='function' and 'present' or 'missing'
    end
    return type(rawget(_G,name))=='function' and 'present' or 'missing'
end
local function cvar(name)
    local get=type(C_CVar)=='table' and C_CVar.GetCVar or rawget(_G,'GetCVar')
    local ok,value=protect(get,name)
    return ok and show(value) or 'unreadable'
end

local function store()
    local saved=rawget(_G,addon.savedVariableName or 'RotationMasterDB')
    if type(saved)~='table' then return nil end
    local diagnostics=rawget(saved,'diagnostics')
    if type(diagnostics)~='table' then diagnostics={};saved.diagnostics=diagnostics end
    local reports=diagnostics.glow
    if type(reports)~='table' then reports={};diagnostics.glow=reports end
    return reports
end

local function newReport()
    local lines={}
    local report={lines=lines}
    function report.add(text,...)
        if #lines>=MAX_LINES then
            if #lines==MAX_LINES then lines[#lines+1]='... (report capped at '..MAX_LINES..' lines)' end
            return
        end
        if select('#',...)>0 then
            local args={...}
            for i=1,select('#',...) do args[i]=show(args[i]) end
            text=string.format(text,unpack(args,1,select('#',...)))
        end
        lines[#lines+1]=text
    end
    return report
end

-- Readiness piece by piece, the way Core/action_policy.lua decides it.
local function readinessParts(kind,id,itemId,now)
    local platform=addon.Platform
    local parts={}
    if kind=='item' then
        local ready,why=platform:IsItemReady(itemId,now)
        parts[#parts+1]='itemReady='..show(ready)..(why and ('('..why..')') or '')
        local range,rangeWhy=platform:GetItemRangeState(itemId,'target')
        parts[#parts+1]='range='..(type(range)=='table' and (range.applicable==false and 'n/a' or show(range.inRange)) or ('nil('..show(rangeWhy)..')'))
    else
        local bank=kind
        if bank~='spell' and bank~='pet' and bank~='any' then bank='spell' end
        local known,why
        if bank~='pet' then known,why=platform:IsSpellKnown(id,false) end
        if known~=true and bank~='spell' then known,why=platform:IsSpellKnown(id,true) end
        parts[#parts+1]='known='..show(known)..(why and ('('..why..')') or '')
        local usable,power,usableWhy=platform:IsSpellUsable(id)
        parts[#parts+1]='usable='..show(usable)..' noPower='..show(power)..(usableWhy and ('('..usableWhy..')') or '')
        local ready,readyWhy=platform:IsSpellReady(id,now)
        parts[#parts+1]='cooldownReady='..show(ready)..(readyWhy and ('('..readyWhy..')') or '')
        if id==6603 then
            local beyond,beyondWhy=platform:IsBeyondMeleeRange('target')
            parts[#parts+1]='beyondMelee='..show(beyond)..(beyondWhy and ('('..beyondWhy..')') or '')
        else
            local range,rangeWhy=platform:GetSpellRangeState(id,'target',bank)
            parts[#parts+1]='range='..(type(range)=='table' and (range.applicable==false and 'n/a' or show(range.inRange)) or ('nil('..show(rangeWhy)..')'))
        end
    end
    local readyFn=addon:NewActionReadiness(now)
    local ok,final=pcall(readyFn,kind,id,itemId)
    return table.concat(parts,' '),ok and final==true,ok and '' or ('error: '..tostring(final))
end

local function spellRelations(id)
    local base,override
    if type(C_Spell)=='table' then
        local ok,value=protect(C_Spell.GetBaseSpell,id);if ok then base=value end
        ok,value=protect(C_Spell.GetOverrideSpell,id);if ok then override=value end
    end
    local slots
    if type(C_ActionBar)=='table' and type(C_ActionBar.FindSpellActionButtons)=='function' then
        local ok,value=pcall(C_ActionBar.FindSpellActionButtons,readable(base) and type(base)=='number' and base or id)
        if ok and readable(value) and type(value)=='table' then
            local list={}
            for i=1,math.min(#value,12) do list[#list+1]=show(value[i]) end
            slots=table.concat(list,',')
        elseif not ok then slots='error'
        else slots='unreadable' end
    end
    return base,override,slots
end

-- Why GetSpellIds (main.lua) returned nothing for a step: the lookup it
-- makes for that step type, and what that lookup said.
local SPELL_STEP={spell=true,pet=true,any=true}
local function explainNoSpellIds(self,step)
    local kind,action=step.type,step.action
    local platform=self.Platform
    if kind=='assisted' then
        if not (platform and platform.GetAssistedSuggestion) then return 'assisted: this client has no Assisted Combat reader' end
        local suggestion,why=platform:GetAssistedSuggestion()
        if suggestion==false then return 'assisted: Blizzard suggests nothing right now' end
        if suggestion==nil then return 'assisted: no suggestion ('..show(why)..')' end
        return 'assisted: suggestion '..show(suggestion)..' gave no candidates'
    end
    if action==nil then return 'the step has no action' end
    if SPELL_STEP[kind] then
        local spellType,petType=rawget(_G,'BOOKTYPE_SPELL'),rawget(_G,'BOOKTYPE_PET')
        local matched=kind==(spellType or 'spell') or kind==(petType or 'pet') or kind=='any'
        local text=string.format('%s step, action %s: BOOKTYPE_SPELL=%s BOOKTYPE_PET=%s',show(kind),show(action),show(spellType),show(petType))
        if not matched then return text..'; the step type matches no spell book type' end
        if rawget(_G,'WOW_PROJECT_ID')~=rawget(_G,'WOW_PROJECT_MAINLINE') and not step.ranked and self.SpellCatalog then
            local ok,ids=pcall(self.SpellCatalog.GetAllSpellIds,self.SpellCatalog,action)
            text=text..'; spell catalog ranks='..(ok and (type(ids)=='table' and #ids or show(ids)) or ('error '..tostring(ids)))
        end
        return text..'; GetSpellIds still returned nothing'
    end
    if kind=='item' then
        local items=action
        if type(items)=='string' then
            local profile,global=self.db.profile.itemsets or {},self.db.global.itemsets or {}
            local set=profile[items] or global[items]
            if type(set)~='table' then return 'item set '..show(items)..' does not exist' end
            items=set.items
        end
        if type(items)~='table' or #items==0 then return 'the item list is empty' end
        local parts={}
        for i,item in ipairs(items) do
            if i>6 then parts[#parts+1]='...';break end
            local use,useWhy=platform:GetItemUseSpell(item)
            local id,idWhy=platform:GetItemID(item)
            parts[#parts+1]=string.format('%s: use=%s%s id=%s%s',show(item),use and show(use.spellID) or 'nil',useWhy and ('('..useWhy..')') or '',show(id),idWhy and ('('..idWhy..')') or '')
        end
        return 'no item with a use spell and an item ID: '..table.concat(parts,'; ')
    end
    return 'step type '..show(kind)..' has no spell IDs'
end

local function rotationRows(self)
    local spec,id=self.currentSpec,self.currentRotation
    if id==nil or type(self.GetRotationForCleanup)~='function' then return nil,'no active rotation' end
    local ok,rotation=pcall(self.GetRotationForCleanup,self,spec,id)
    if not ok then return nil,'rotation read failed: '..tostring(rotation) end
    if type(rotation)~='table' then return nil,'rotation body unavailable' end
    local data=self.RotationData
    if type(data)~='table' or type(data.IndexRotationSteps)~='function' then return nil,'rotation index unavailable' end
    local indexed,index=pcall(data.IndexRotationSteps,rotation,{allowMissingIds=true})
    if not indexed or type(index)~='table' or type(index.rows)~='table' then return nil,'rotation index failed' end
    local rows={}
    for _,row in ipairs(index.rows) do
        if row.section=='rotation' and type(row.step)=='table' then rows[#rows+1]=row end
    end
    return rows,nil,rotation
end

local function conditionStatus(self,step)
    if step.conditions==nil then return 'match' end
    if type(self.evaluateConditionResult)~='function' then return 'unknown' end
    local ok,result=pcall(self.evaluateConditionResult,self,step.conditions,{stepId=step.id})
    if not ok then return 'error: '..tostring(result) end
    if type(result)~='table' then return show(result) end
    return show(result.status)..(result.reason and (' ('..show(result.reason)..')') or '')
end

-- One step: its outcome as the engine would see it now. Returns the verdict
-- ('selected', 'notmatched', 'unmapped', 'notready', 'noaction', 'disabled',
-- 'branch', 'stop'), the chosen spell, and the reason text.
local function walkStep(self,report,row,now,verbose)
    local step=row.step
    local label=string.format('#%s %s',show(row.ordinal),show(step.type))
    if step.disabled then if verbose then report.add('  %s disabled',label) end;return 'disabled' end
    if row.unreachable then if verbose then report.add('  %s unreachable',label) end;return 'disabled' end
    if step.type=='branch' then if verbose then report.add('  %s (branch: its steps follow)',label) end;return 'branch' end
    local status=conditionStatus(self,step)
    if step.type=='stop' then
        if verbose then report.add('  %s stop step, conditions=%s',label,status) end
        if status:match('^match') or status:match('^unavailable') then return 'stop',nil,'a stop step matched' end
        return 'notmatched'
    end
    if step.action==nil and step.type~='assisted' then if verbose then report.add('  %s has no action',label) end;return 'noaction' end
    if verbose then report.add('  %s action=%s conditions=%s',label,step.action,status) end
    if not status:match('^match') then return 'notmatched',nil,'conditions '..status end
    local ok,spellids,itemids=pcall(self.GetSpellIds,self,step)
    if not ok then if verbose then report.add('    GetSpellIds error: %s',spellids) end;return 'unmapped',nil,'spell IDs failed' end
    if type(spellids)~='table' or #spellids==0 then
        local okWhy,why=pcall(explainNoSpellIds,self,step)
        why=okWhy and why or ('explanation failed: '..tostring(why))
        if verbose then report.add('    no spell IDs: %s',why) end
        return 'unmapped',nil,'no spell IDs ('..why..')'
    end
    local firstReason,anyMapped
    for index,id in ipairs(spellids) do
        local itemId=itemids and itemids[index]
        local mapped=self:FindSpell({id},step.type=='item' and {itemId} or nil)
        local base,override,slots=spellRelations(id)
        local names=self.GetSpellButtonNames and self:GetSpellButtonNames(id) or {}
        if verbose then
            report.add('    spell %s base=%s override=%s mapped=%s buttons=[%s] blizzardSlots=[%s]',
                id,base,override,mapped~=nil,table.concat(names,','),slots or 'n/a')
        end
        if mapped then
            anyMapped=true
            local parts,ready,err=readinessParts(step.type,id,itemId,now)
            if verbose then report.add('      ready=%s %s %s',ready,parts,err) end
            if ready then return 'selected',mapped,nil end
            firstReason=firstReason or ('spell '..show(id)..' not ready: '..parts)
        else
            if verbose then report.add('      not on your action bars: this spell is skipped (it cannot be highlighted)') end
            firstReason=firstReason or ('spell '..show(id)..' is not on your action bars, so the step is skipped (it cannot be highlighted)')
        end
    end
    return anyMapped and 'notready' or 'unmapped',nil,firstReason
end

local function section(report,title) report.add('');report.add('== '..title) end

local function scanSection(self,report)
    local index=self.GetButtonIndexDiagnostic and self:GetButtonIndexDiagnostic()
    if index then
        report.add('index: %s buttons, %s spells, scans=%s lastScan=%s policyAtScan=%s',index.buttons,index.spells,index.fetches,index.lastFetch,index.policy)
        local ids={};for i,id in ipairs(index.ids) do ids[i]=show(id) end
        report.add('indexed spells (first 24): %s',table.concat(ids,','))
    else report.add('index: unavailable (buttons.lua diagnostic support missing)') end
    local firstError
    for _,bar in ipairs(self:GetGlowDiagnosticBars()) do
        local frames,typed,withAction,indexed,errors=0,0,0,0,0
        local rows={}
        for i=1,12 do
            local button=rawget(_G,bar..'Button'..i)
            if type(button)=='table' then
                frames=frames+1
                local record=self:DiagnoseActionButton(button)
                if record.kind=='action' then typed=typed+1 end
                if record.indexed then indexed=indexed+1 end
                if record.error then errors=errors+1;firstError=firstError or (record.name..': '..record.error) end
                if record.actionKind then withAction=withAction+1 end
                if record.actionKind or record.error then
                    rows[#rows+1]=string.format('  %s type=%s slot=%s shown=%s visible=%s action=%s:%s spell=%s indexed=%s%s',
                        record.name,show(record.kind),show(record.slot),show(record.shown),show(record.visible),show(record.actionKind),
                        show(record.action),show(record.spell),show(record.indexed),record.error and (' ERROR '..record.error) or '')
                end
            end
        end
        if frames>0 then
            report.add('%sButton1-12: %s frames, type=action %s, holding an action %s, indexed %s, read errors %s',bar,frames,typed,withAction,indexed,errors)
            for _,line in ipairs(rows) do report.add(line) end
        end
    end
    local libs=0
    for _,name in ipairs({'LibActionButton-1.0','LibActionButton-1.0-ElvUI'}) do
        local ok,lib=pcall(LibStub,name,true)
        if ok and type(lib)=='table' and type(lib.GetAllButtons)=='function' then
            local listed,buttons=pcall(lib.GetAllButtons,lib)
            if listed and type(buttons)=='table' then for _ in pairs(buttons) do libs=libs+1 end end
        end
    end
    report.add('LibActionButton buttons: %s',libs)
    return index,firstError
end

-- Every step the editor would warn "not on your action bars" for, in the
-- rotation open in the editor and in the active one, with the spell IDs the
-- step names, the IDs the client relates to each, whether the scan holds it
-- (directly, or through which alias) and the slots the client reports. This
-- is the text to paste when a warning looks wrong.
local function listIds(list)
    local out={};for i,value in ipairs(list or {}) do out[i]=show(value) end
    return table.concat(out,',')
end
local function bindingSection(self,report)
    local index=self.GetIndexedSpellsDiagnostic and self:GetIndexedSpellsDiagnostic(120)
    if not index or not self.ExplainStepBinding or not self.ListUnboundSteps then report.add('  unavailable (buttons.lua diagnostic support missing)');return end
    report.add('scan: scans=%s ageSeconds=%s pendingRescan=%s policyAtScan=%s indexedSpells=%s',index.scans,index.age and string.format('%.1f',index.age) or nil,index.pending,index.policy,index.total)
    for _,entry in ipairs(index.spells) do
        report.add('  on bars: %s %s buttons=[%s]%s',entry.id,entry.name or '?',table.concat(entry.buttons,','),entry.alias and (' (alias: '..entry.alias..')') or '')
    end
    if index.total>#index.spells then report.add('  ... %d more indexed spells',index.total-#index.spells) end
    local targets={}
    local pane=self.activeRotationEditor
    if type(pane)=='table' and pane.active and pane.workspace and type(pane.workspace.Snapshot)=='function' then
        local ok,body=pcall(pane.workspace.Snapshot,pane.workspace)
        if ok and type(body)=='table' then targets[#targets+1]={label='open in the editor: '..show(body.name or pane.workspace.id),body=body} end
    end
    local _,_,active=rotationRows(self)
    if active then targets[#targets+1]={label='active rotation: '..show(active.name or self.currentRotation),body=active} end
    if #targets==0 then report.add('  no rotation is open in the editor and none is active') end
    for _,target in ipairs(targets) do
        local unbound=self:ListUnboundSteps(target.body)
        report.add('%s: %d step(s) with no button',target.label,#unbound)
        for _,entry in ipairs(unbound) do
            local explain=self:ExplainStepBinding(entry.step)
            report.add('  %s [step id %s, %s %s]',self:DescribeUnboundStep(entry),show(entry.step.id),show(explain.type),show(explain.action))
            if explain.error then report.add('    GetSpellIds error: %s',explain.error) end
            for _,record in ipairs(explain.ids) do
                report.add('    spell %s %s: relatives=[%s] directlyIndexed=%s alias=%s buttons=[%s] clientSlots=[%s]',record.id,record.name or '?',listIds(record.relatives),record.direct,
                    record.how or 'none',table.concat(record.buttons,','),type(record.slots)=='table' and listIds(record.slots) or show(record.slots))
            end
            if #explain.ids==0 then report.add('    the step names no spell ID (%s)',explain.error or 'nothing to look up') end
        end
    end
end

function addon:BuildGlowDiagnostic()
    local report=newReport()
    local add=report.add
    local now=type(GetTime)=='function' and GetTime() or 0
    local platform=self.Platform
    local client=platform and platform.GetClientInfo and platform:GetClientInfo() or {}
    local okBuild,version,build=protect(rawget(_G,'GetBuildInfo'))
    local okCombat,combat=protect(rawget(_G,'InCombatLockdown'))
    add('Rotation Master glow diagnostic %s',type(date)=='function' and date('%Y-%m-%d %H:%M:%S') or '')
    add('client %s build %s family=%s policy=%s project=%s combat=%s time=%s',okBuild and version or '?',okBuild and build or '?',
        client.family,client.combatDataPolicy,rawget(_G,'WOW_PROJECT_ID'),okCombat and combat or '?',now)

    section(report,'Action bar APIs')
    add('HasAction=%s C_ActionBar.HasAction=%s GetActionInfo=%s C_ActionBar.FindSpellActionButtons=%s',
        apiPresence('HasAction'),apiPresence('HasAction','C_ActionBar'),apiPresence('GetActionInfo'),apiPresence('FindSpellActionButtons','C_ActionBar'))
    add('IsUsableAction=%s C_ActionBar.IsUsableAction=%s GetActionCooldown=%s C_ActionBar.GetActionCooldown=%s IsActionInRange=%s C_ActionBar.IsActionInRange=%s',
        apiPresence('IsUsableAction'),apiPresence('IsUsableAction','C_ActionBar'),apiPresence('GetActionCooldown'),apiPresence('GetActionCooldown','C_ActionBar'),
        apiPresence('IsActionInRange'),apiPresence('IsActionInRange','C_ActionBar'))
    add('CVar loadDeprecationFallbacks=%s assistedCombatHighlight=%s ActionButtonSpellAlertManager=%s',
        cvar('loadDeprecationFallbacks'),cvar('assistedCombatHighlight'),type(rawget(_G,'ActionButtonSpellAlertManager'))=='table')

    section(report,'Engine')
    local profile=type(self.db)=='table' and self.db.profile or {}
    local effects=type(self.db)=='table' and type(self.db.global)=='table' and self.db.global.effects or {}
    local effect=type(effects)=='table' and effects[profile.effect] or nil
    add('rotation=%s (%s) spec=%s timer=%s engine=%s actionContext=%s',self.currentRotation,
        self.currentRotation and self.GetRotationName and select(2,pcall(self.GetRotationName,self,self.currentRotation)) or nil,
        self.currentSpec,self.rotationTimer~=nil,self.GetEvaluationEngine and self:GetEvaluationEngine() or nil,
        self.GetActionContext and self:GetActionContext() or nil)
    add('disable_buttons=%s effect=%s effectType=%s effectName=%s magnification=%s assisted_highlight=%s assistedGlowHidden=%s',
        profile.disable_buttons,profile.effect,effect and effect.type,effect and effect.name,profile.magnification,
        self.GetAssistedHighlightMode and self:GetAssistedHighlightMode() or nil,self.assistedGlowHidden)
    local okTarget,target=protect(rawget(_G,'UnitExists'),'target')
    local okAttack,attack=protect(rawget(_G,'UnitCanAttack'),'player','target')
    add('target exists=%s attackable=%s',okTarget and target or '?',okAttack and attack or '?')

    section(report,'Button scan')
    local index,firstError=scanSection(self,report)

    section(report,'Steps the editor warns are not on your action bars')
    local boundOk,boundWhy=pcall(bindingSection,self,report)
    if not boundOk then add('  report failed: %s',boundWhy) end

    section(report,'Rotation steps (top to bottom, as the engine walks them)')
    local rows,rowsWhy,rotation=rotationRows(self)
    local expected,expectedReason
    if not rows then add('  %s',rowsWhy)
    else
        -- Steps and cooldowns the engine skips because no button holds them.
        local unbound=self.ListUnboundSteps and self:ListUnboundSteps(rotation) or {}
        if #unbound>0 then
            local names={}
            for i,entry in ipairs(unbound) do names[i]=self:DescribeUnboundStep(entry) end
            add('  skipped, not on your action bars (cannot be highlighted): %s',table.concat(names,'; '))
        end
        local stopped
        for n,row in ipairs(rows) do
            if n>MAX_STEPS then add('  ... %d more steps',#rows-MAX_STEPS);break end
            local verdict,spell,reason=walkStep(self,report,row,now,true)
            if not stopped and not expected then
                if verdict=='selected' then expected=spell
                elseif verdict=='stop' then stopped=true;expectedReason=reason
                elseif reason and not expectedReason then expectedReason=reason end
            end
        end
    end

    section(report,"Blizzard's suggestion")
    if not (platform and platform.GetAssistedSuggestion) then add('  not offered by this client')
    else
        local suggestion,why=platform:GetAssistedSuggestion()
        local available,availableWhy=platform:GetAssistedCombatAvailability()
        local candidates=suggestion and platform:GetAssistedSpellCandidates(suggestion) or {}
        local list={};for i,id in ipairs(candidates) do list[i]=show(id) end
        add('available=%s%s suggestion=%s%s candidates=[%s]',available,availableWhy and (' ('..availableWhy..')') or '',suggestion,why and (' ('..why..')') or '',table.concat(list,','))
    end

    section(report,'Glow')
    local glow=self.GetGlowDiagnostic and self:GetGlowDiagnostic() or {last={},glowing={}}
    local last=glow.last
    add('currentSpell=%s lastRequest spell=%s item=%s hidden=%s result=%s buttonsLit=%s at=%s clearedAt=%s',self.currentSpell,last.spell,last.item,last.hidden,last.result,last.lit,last.at,last.clearedAt)
    for _,entry in ipairs(self:GetRecentRecommendations()) do
        if entry.spell==nil then add('  recent t=%s rotation=%s: recommendation cleared',entry.at,entry.rotation)
        else add('  recent t=%s rotation=%s: step #%s (%s) recommended %s',entry.at,entry.rotation,entry.index,entry.kind,entry.spell) end
    end
    for _,entry in ipairs(glow.glowing) do
        add('  glowing spell=%s hidden=%s on %d button(s)',entry.spell,entry.hidden,#entry.buttons)
        for _,b in ipairs(entry.buttons) do
            local o=b.overlay
            add('    %s shown=%s visible=%s strata=%s level=%s size=%sx%s pixel=%s autocast=%s blizzard=%s proc=%s overlay=%s',b.name,b.shown,b.visible,b.strata,b.level,b.width,b.height,b.pixel,b.autocast,b.blizzard,b.proc,
                o and string.format('shown=%s visible=%s strata=%s level=%s size=%sx%s alpha=%s native=%s timer=%s texture=%s',show(o.shown),show(o.visible),show(o.strata),show(o.level),show(o.width),show(o.height),show(o.alpha),show(o.native),show(o.timer),show(o.texture)) or 'none')
        end
    end

    section(report,'Verdict')
    local stop
    if self.currentRotation==nil then stop='no rotation is active (Rotation Master is disabled, or no rotation could be selected: see /rm why)'
    elseif index and index.buttons==0 then stop='the button scan indexed no buttons'..(firstError and ('; first read error: '..firstError) or '')
    elseif not expected then stop='no step is selectable now: '..(expectedReason or 'every step was skipped')
    elseif profile.disable_buttons then stop='button highlighting is turned off (disable_buttons)'
    elseif not effect then stop='the profile glow effect '..show(profile.effect)..' does not exist'
    elseif self.currentSpell~=expected then stop='the engine published '..show(self.currentSpell)..' but this walk selects '..show(expected)..' (state changed, or the poll is not running)'
    elseif last.spell~=expected and not self:IsGlowing(expected,nil,false) then stop='the glow was never requested for '..show(expected)
    elseif last.result=='hidden' then stop="the glow is hidden: Blizzard's Assisted Highlight owns this step (assisted_highlight=blizzard)"
    elseif last.result and last.result~='lit' then stop='the glow request found '..last.result
    else
        local visible,unknown=false,false
        for _,entry in ipairs(glow.glowing) do for _,b in ipairs(entry.buttons) do
            local lit=b.pixel or b.autocast or b.blizzard or b.proc or b.overlay~=nil
            local overlayVisible=b.overlay==nil or b.overlay.visible
            if lit and b.visible==true and overlayVisible==true then visible=true
            elseif lit and b.visible~=false and overlayVisible~=false then unknown=true end
        end end
        stop=visible and 'none: a glow is on a visible frame'
            or unknown and 'none found: a glow started; its visibility could not be read'
            or 'the glow started but no lit frame is visible'
    end
    add('expected=%s',expected)
    add('STOPS AT: %s',stop)
    return report.lines,stop
end

-- Every recommendation change the engine announces (ROTATIONMASTER_SPELL_UPDATE:
-- rotation, step ordinal, step id, step type, spell; nil spell when the glow
-- is cleared), newest last, so a report can say which step asked for a glow.
-- Sent only when the recommendation changes; eight reused slots.
local RECENT=8
local recent,recentNext={},1
for i=1,RECENT do recent[i]={} end
local function noteUpdate(_,rotation,index,id,kind,spell)
    local slot=recent[recentNext]
    slot.at=type(GetTime)=='function' and GetTime() or nil
    slot.rotation,slot.index,slot.id,slot.kind,slot.spell,slot.used=rotation,index,id,kind,spell,true
    recentNext=recentNext%RECENT+1
end
do
    local ok,events=pcall(LibStub,'AceEvent-3.0',true)
    if ok and type(events)=='table' and type(events.RegisterMessage)=='function' then
        pcall(events.RegisterMessage,recent,'ROTATIONMASTER_SPELL_UPDATE',noteUpdate)
    end
end
function addon:GetRecentRecommendations()
    local list={}
    for n=0,RECENT-1 do
        local slot=recent[(recentNext+n-1)%RECENT+1]
        if slot.used then list[#list+1]=slot end
    end
    return list
end

local watcher
local function save(lines)
    local reports=store()
    if not reports then return nil end
    local entry={at=type(date)=='function' and date('%Y-%m-%d %H:%M:%S') or nil,lines=lines}
    reports[#reports+1]=entry
    while #reports>MAX_REPORTS do table.remove(reports,1) end
    return entry
end

-- One compact line: what the engine shows now and how the first steps fare.
local function watchLine(self)
    local now=type(GetTime)=='function' and GetTime() or 0
    local okCombat,combat=protect(rawget(_G,'InCombatLockdown'))
    local glow=self.GetGlowDiagnostic and self:GetGlowDiagnostic() or {last={}}
    local parts={string.format('t=%s combat=%s current=%s glow=%s/%s lit=%s',show(now),okCombat and show(combat) or '?',show(self.currentSpell),show(glow.last.spell),show(glow.last.result),show(glow.last.lit))}
    local rows=rotationRows(self)
    local sink=newReport()
    for n,row in ipairs(rows or {}) do
        if n>4 then break end
        local verdict,spell,reason=walkStep(self,sink,row,now,false)
        parts[#parts+1]=string.format('#%s:%s%s',show(row.ordinal),verdict,verdict=='selected' and ('='..show(spell)) or (reason and ('('..reason..')') or ''))
    end
    return table.concat(parts,' ')
end

function addon:RunGlowDiagnostic(seconds)
    local lines,stop=self:BuildGlowDiagnostic()
    local entry=save(lines)
    seconds=tonumber(seconds)
    if seconds and seconds>=1 and entry and type(self.ScheduleRepeatingTimer)=='function' then
        seconds=math.min(math.floor(seconds),MAX_WATCH)
        if watcher then self:CancelTimer(watcher.timer) end
        lines[#lines+1]=''
        lines[#lines+1]='== Watch, one line per second for '..seconds..'s'
        local remaining=seconds
        watcher={}
        watcher.timer=self:ScheduleRepeatingTimer(function()
            remaining=remaining-1
            if #lines<MAX_LINES then
                local ok,line=pcall(watchLine,self)
                lines[#lines+1]=ok and line or ('watch error: '..tostring(line))
            end
            if remaining<=0 then
                self:CancelTimer(watcher.timer);watcher=nil
                self:print(L['Glow watch finished. Run /rm debug glow show to view it.'])
            end
        end,1)
        self:print(L['Glow diagnostic saved. Watching for %d seconds.'],seconds)
    else
        self:print(L['Glow diagnostic saved.'])
    end
    if stop then self:print(L['Glow stops at: %s'],stop) end
    if self.ShowConditionText and not (seconds and seconds>=1) then self:ShowConditionText(table.concat(lines,'\n'),L['Glow diagnostic']) end
    return lines,stop
end

-- The newest stored report, in the copyable window.
function addon:ShowGlowDiagnostic()
    local reports=store()
    local entry=reports and reports[#reports]
    if not entry or type(entry.lines)~='table' then self:print(L['No glow diagnostic is saved yet. Run /rm debug glow.']);return end
    if self.ShowConditionText then self:ShowConditionText(table.concat(entry.lines,'\n'),L['Glow diagnostic']) end
end

-- /rm debug editor copies the Lua editor input report (UI/lua_input_diagnostics.lua);
-- /rm debug talents reports the trait talent reads (Diagnostics/talents.lua).
function addon:HandleDebugCommand(args)
    local what,rest=(args or ''):match('^%s*(%S*)%s*(.-)%s*$')
    if what=='glow' then
        if rest=='show' then return self:ShowGlowDiagnostic() end
        return self:RunGlowDiagnostic(rest~='' and rest or nil)
    end
    if what=='editor' and self.ShowLuaEditorInputReport then return self:ShowLuaEditorInputReport() end
    if what=='talents' and self.RunTalentDiagnostic then return self:RunTalentDiagnostic(rest) end
    self:print(L['Usage: /rm debug glow [seconds|show], /rm debug talents [views] or /rm debug editor'])
end
