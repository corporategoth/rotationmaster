-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- QA-only inverse of the boss-mod/Titan integration change. Each current
-- file that is exactly its reviewed current bytes maps back to its
-- predecessor, so closed historical proofs that pin complete file bytes keep
-- running against the source they were written for. Any other text,
-- including every older stage and unrelated edits, passes through unchanged.
local records = {}

records["Core/profile_data.lua"] = {
    bytes = 14097,
    hash = 2093772813,
    {
        [=[local _,addon=...
local scalar={unitStateSwitchSeeded='boolean',bossModConditionsSeeded='boolean',rotationFallbackID='string',lua_editor='string',lua_native_highlighting='boolean',lua_line_numbers='boolean',questie_enabled='boolean',encounter_provider='string',preview_masque='boolean',version='number',enable='boolean',poll='number',ignore_mana='boolean',ignore_range='boolean',effect='string',magnification='number',setpoint='string',xoffs='number',yoffs='number',loglevel='number',detailed_profiling='boolean',disable_autoswitch='boolean',live_config_update='number',spell_history='number',combat_history='number',damage_history='number',disable_buttons='boolean',rotation_view='string',preview_spells='number',preview_vertical='boolean',preview_locked='boolean',preview_opacity='number',preview_icon_size='number'}
local function dense(value,validate)
]=],
        [=[local _,addon=...
local scalar={unitStateSwitchSeeded='boolean',rotationFallbackID='string',lua_editor='string',lua_native_highlighting='boolean',lua_line_numbers='boolean',questie_enabled='boolean',preview_masque='boolean',version='number',enable='boolean',poll='number',ignore_mana='boolean',ignore_range='boolean',effect='string',magnification='number',setpoint='string',xoffs='number',yoffs='number',loglevel='number',detailed_profiling='boolean',disable_autoswitch='boolean',live_config_update='number',spell_history='number',combat_history='number',damage_history='number',disable_buttons='boolean',rotation_view='string',preview_spells='number',preview_vertical='boolean',preview_locked='boolean',preview_opacity='number',preview_icon_size='number'}
local function dense(value,validate)
]=],
    },
    {
        [=[    if value.lua_editor~=nil and (#value.lua_editor>128 or not value.lua_editor:find('%S')) then return false end
    if value.encounter_provider~=nil and value.encounter_provider~='DBM-Core' and value.encounter_provider~='BigWigs' then return false end
    if value.rotation_view~=nil and value.rotation_view~='diagram' and value.rotation_view~='list' then return false end
]=],
        [=[    if value.lua_editor~=nil and (#value.lua_editor>128 or not value.lua_editor:find('%S')) then return false end
    if value.rotation_view~=nil and value.rotation_view~='diagram' and value.rotation_view~='list' then return false end
]=],
    },
}

records["Core/rotation_lifecycle.lua"] = {
    bytes = 4891,
    hash = 4197021753,
    {
        [=[    if self.SyncQuestieIntegration then self:SyncQuestieIntegration() end
    if self.SyncEncounterIntegration then self:SyncEncounterIntegration() end
    if invalidateDependencies then invalidateDependencies(addon,'all',nil) end
]=],
        [=[    if self.SyncQuestieIntegration then self:SyncQuestieIntegration() end
    if invalidateDependencies then invalidateDependencies(addon,'all',nil) end
]=],
    },
}

records["Data/builtin_sources.lua"] = {
    bytes = 812259,
    hash = 3937531038,
    {
        [=[["module"]="Conditions/range.lua"},["BOSSMOD_ENCOUNTER"]={["callbacks"]={["evaluate"]={["bindings"]={},["code"]="\010        local active, id, _, reason = addon:GetBossModEncounter()\010        if active == nil then return nil, reason or \"bossmod-unavailable\" end\010        if not active then return false end\010        if value.encounter == nil then return true end\010        return id == value.encounter\010    ",["line"]=78,["parameters"]={"value"}},["help"]={["bindings"]={["helpers"]="builtin:Conditions/bossmod.lua:helpers"},["code"]="\010        frame:AddChild(helpers.CreateText(L[\"Help.Conditions.BOSSMOD_ENCOUNTER\"]))\010    ",["line"]=97,["parameters"]={"frame"}},["print"]={["bindings"]={["validID"]="builtin:Conditions/bossmod.lua:validID"},["code"]="\010        if validID(value.encounter) then\010            return string.format(L[\"your boss mod reports encounter %s {{!is|is not}} in progress\"], tostring(value.encounter))\010        end\010        return L[\"your boss mod {{!reports|does not report}} an encounter in progress\"]\010    ",["line"]=85,["parameters"]={"_","value"}},["valid"]={["bindings"]={["validID"]="builtin:Conditions/bossmod.lua:validID"},["code"]="\010        return value.encounter == nil or validID(value.encounter)\010    ",["line"]=75,["parameters"]={"_","value"}},["widget"]={["bindings"]={["encounterNote"]="builtin:Conditions/bossmod.lua:encounterNote",["idEditor"]="builtin:Conditions/bossmod.lua:idEditor",["note"]="builtin:Conditions/bossmod.lua:note"},["code"]="\010        local top = parent:GetUserData(\"top\")\010        local function update() top:SetStatusText(top:GetUserData(\"funcs\"):print(top:GetUserData(\"root\"), spec)) end\010        idEditor(parent, L[\"Encounter ID (blank for any)\"], value.encounter, function(id) value.encounter = id; update() end)\010        note(parent, encounterNote())\010    ",["line"]=91,["parameters"]={"parent","spec","value"}}},["module"]="Conditions/bossmod.lua"},["BOSSMOD_STAGE"]={["callbacks"]={["evaluate"]={["bindings"]={["Functions.presentation.compareString"]="builtin:utils.lua:compareString",["Functions.presentation.nullable"]="builtin:utils.lua:nullable",["Functions.values.compare"]="builtin:utils.lua:compare",["Functions.values.isin"]="builtin:utils.lua:isin"},["code"]="\010        local active, _, stage, reason = addon:GetBossModEncounter()\010        if active == nil then return nil, reason or \"bossmod-unavailable\" end\010        if not active then return false end\010        return Functions.values.compare(value.operator, stage, value.value)\010    ",["line"]=109,["parameters"]={"value"}},["help"]={["bindings"]={},["code"]="\010        addon.layout_condition_operatorwidget_help(frame, L[\"Boss Mod Encounter Stage\"], L[\"Stage\"], L[\"Help.Conditions.BOSSMOD_STAGE\"])\010    ",["line"]=124,["parameters"]={"frame"}},["print"]={["bindings"]={["Functions.presentation.compareString"]="builtin:utils.lua:compareString",["Functions.presentation.nullable"]="builtin:utils.lua:nullable",["Functions.values.compare"]="builtin:utils.lua:compare",["Functions.values.isin"]="builtin:utils.lua:isin"},["code"]="\010        return Functions.presentation.compareString(value.operator, L[\"the boss-mod encounter stage\"], Functions.presentation.nullable(value.value))\010    ",["line"]=115,["parameters"]={"_","value"}},["valid"]={["bindings"]={["validCompare"]="builtin:Conditions/bossmod.lua:validCompare"},["code"]="\010        return validCompare(value)\010    ",["line"]=106,["parameters"]={"_","value"}},["widget"]={["bindings"]={["encounterNote"]="builtin:Conditions/bossmod.lua:encounterNote",["note"]="builtin:Conditions/bossmod.lua:note"},["code"]="\010        local top = parent:GetUserData(\"top\")\010        local function update() top:SetStatusText(top:GetUserData(\"funcs\"):print(top:GetUserData(\"root\"), spec)) end\010        parent:AddChild(addon:Widget_OperatorWidget(value, L[\"Stage\"], update))\010        note(parent, encounterNote())\010    ",["line"]=118,["parameters"]={"parent","spec","value"}}},["module"]="Conditions/bossmod.lua"},["BOSSMOD_TIMER"]={["callbacks"]={["evaluate"]={["bindings"]={["Functions.presentation.compareString"]="builtin:utils.lua:compareString",["Functions.presentation.nullable"]="builtin:utils.lua:nullable",["Functions.values.compare"]="builtin:utils.lua:compare",["Functions.values.isin"]="builtin:utils.lua:isin"},["code"]="\010        local remaining, reason = addon:GetBossModTimerRemaining(value.spell, evalStart)\010        if remaining == nil then return nil, reason or \"bossmod-unavailable\" end\010        if not remaining then return false end\010        return Functions.values.compare(value.operator, remaining, value.value)\010    ",["line"]=136,["parameters"]={"value","_","evalStart"}},["help"]={["bindings"]={["helpers"]="builtin:Conditions/bossmod.lua:helpers"},["code"]="\010        frame:AddChild(helpers.CreateText(L[\"Help.Conditions.BOSSMOD_TIMER\"]))\010        frame:AddChild(helpers.Gap())\010        addon.layout_condition_operatorwidget_help(frame, L[\"Boss Mod Timer\"], L[\"Seconds\"],\010            L[\"Seconds until the boss mod expects the ability. A paused timer keeps its remaining time.\"])\010    ",["line"]=160,["parameters"]={"frame"}},["print"]={["bindings"]={["Functions.presentation.compareString"]="builtin:utils.lua:compareString",["Functions.presentation.nullable"]="builtin:utils.lua:nullable",["Functions.values.compare"]="builtin:utils.lua:compare",["Functions.values.isin"]="builtin:utils.lua:isin",["validID"]="builtin:Conditions/bossmod.lua:validID"},["code"]="\010        local spell = validID(value.spell) and addon:SpellLabel(value.spell) or L[\"<spell>\"]\010        return Functions.presentation.compareString(value.operator, string.format(L[\"the boss-mod timer for %s\"], spell),\010            string.format(L[\"%s seconds\"], Functions.presentation.nullable(value.value)))\010    ",["line"]=142,["parameters"]={"_","value"}},["valid"]={["bindings"]={["validCompare"]="builtin:Conditions/bossmod.lua:validCompare",["validID"]="builtin:Conditions/bossmod.lua:validID"},["code"]="\010        return validID(value.spell) and validCompare(value)\010    ",["line"]=133,["parameters"]={"_","value"}},["widget"]={["bindings"]={["idEditor"]="builtin:Conditions/bossmod.lua:idEditor",["note"]="builtin:Conditions/bossmod.lua:note",["timerNote"]="builtin:Conditions/bossmod.lua:timerNote"},["code"]="\010        local top = parent:GetUserData(\"top\")\010        local preview\010        local function update() top:SetStatusText(top:GetUserData(\"funcs\"):print(top:GetUserData(\"root\"), spec)) end\010        idEditor(parent, L[\"Boss ability spell ID\"], value.spell, function(id)\010            value.spell = id\010            preview:SetUserData(\"spell\", id);preview:SetText(addon:SpellLabel(id))\010            update()\010        end)\010        preview = addon:CreateSpellLabel(parent, value.spell)\010        parent:AddChild(addon:Widget_OperatorWidget(value, L[\"Seconds\"], update))\010        note(parent, timerNote())\010    ",["line"]=147,["parameters"]={"parent","spec","value"}}},["module"]="Conditions/bossmod.lua"},["BUFF"]={["callbacks"]={["evaluate"]={["bindings"]={},]=],
        [=[["module"]="Conditions/range.lua"},["BUFF"]={["callbacks"]={["evaluate"]={["bindings"]={},]=],
    },
    {
        [=[["hash"]="0a16f4e2ed5cae1515e6de26baa9507d291286defa71ee6a3ff7963019de6dc6"},["Conditions/bossmod.lua"]={["bindings"]={["encounterNote"]={["bindings"]={},["code"]="\010    if type(addon.GetBossModEncounter) ~= \"function\" then return string.format(L[\"Boss mod data unavailable: %s\"], \"adapter-unavailable\") end\010    local active, id, stage, detail = addon:GetBossModEncounter()\010    if active == nil then return string.format(L[\"Boss mod data unavailable: %s\"], tostring(detail or \"unknown\")) end\010    if not active then return L[\"No boss-mod encounter is in progress.\"] end\010    return string.format(L[\"Current encounter: %s (ID %s), stage %s\"], detail or L[\"Unknown\"], id and tostring(id) or L[\"none\"], tostring(stage))\010",["kind"]="function",["line"]=49,["parameters"]={}},["helpers"]={["kind"]="value"},["idEditor"]={["bindings"]={["validID"]="builtin:Conditions/bossmod.lua:validID"},["code"]="\010    local edit = addon:CreateConditionEditBox()\010    edit:SetFullWidth(true)\010    edit:SetLabel(label)\010    edit:SetText(current and tostring(current) or \"\")\010    edit:SetCallback(\"OnEnterPressed\", function(_, _, text)\010        local id = tonumber(text)\010        changed(validID(id) and id or nil)\010        edit:SetText(validID(id) and tostring(id) or \"\")\010    end)\010    parent:AddChild(edit)\010    return edit\010",["kind"]="function",["line"]=29,["parameters"]={"parent","label","current","changed"}},["note"]={["bindings"]={},["code"]="\010    local label = addon:CreateConditionLabel()\010    label:SetFullWidth(true)\010    label:SetText(text)\010    parent:AddChild(label)\010",["kind"]="function",["line"]=42,["parameters"]={"parent","text"}},["timerNote"]={["bindings"]={},["code"]="\010    if type(addon.ListBossModTimers) ~= \"function\" then return string.format(L[\"Boss mod data unavailable: %s\"], \"adapter-unavailable\") end\010    local rows = addon:ListBossModTimers(6)\010    if #rows == 0 then\010        local active, _, _, detail = addon:GetBossModEncounter()\010        if active == nil then return string.format(L[\"Boss mod data unavailable: %s\"], tostring(detail or \"unknown\")) end\010        return L[\"No boss-mod timers are running.\"]\010    end\010    local parts = {}\010    for _, row in ipairs(rows) do\010        parts[#parts + 1] = string.format(\"%s (%d) %.0fs\", addon:SpellLabel(row.spellId), row.spellId, row.remaining)\010    end\010    return L[\"Running timers:\"] .. \" \" .. table.concat(parts, \", \")\010",["kind"]="function",["line"]=56,["parameters"]={}},["validCompare"]={["bindings"]={["Functions.presentation.compareString"]="builtin:utils.lua:compareString",["Functions.presentation.nullable"]="builtin:utils.lua:nullable",["Functions.values.compare"]="builtin:utils.lua:compare",["Functions.values.isin"]="builtin:utils.lua:isin"},["code"]="\010    return value.operator ~= nil and Functions.values.isin(addon.operators, value.operator)\010        and type(value.value) == \"number\" and value.value >= 0 and value.value < math.huge\010",["kind"]="function",["line"]=25,["parameters"]={"value"}},["validID"]={["bindings"]={},["code"]="\010    return type(value) == \"number\" and value > 0 and value < 2^31 and value % 1 == 0\010",["kind"]="function",["line"]=22,["parameters"]={"value"}}},["hash"]="4304076ebcabcc19bd13ca2f090680623e42a9b2bfcc5c01596e769efa14186b"},["Conditions/buffs.lua"]={["bindings"]={["color"]={["kind"]="value"},]=],
        [=[["hash"]="0a16f4e2ed5cae1515e6de26baa9507d291286defa71ee6a3ff7963019de6dc6"},["Conditions/buffs.lua"]={["bindings"]={["color"]={["kind"]="value"},]=],
    },
}

records["Integrations/catalog.lua"] = {
    bytes = 39364,
    hash = 2353602905,
    {
        [=[ {'Questie','Questie','Quest update receipts only; native quest progress is not verified.','questie'},
 {'DBM-Core','DBM','Boss-mod timers and encounter stage for the Boss Mod conditions.','encounters'},
 {'BigWigs','BigWigs','Boss-mod timers and encounter stage for the Boss Mod conditions.','encounters'},
 {'Titan','Titan Panel','Shows the active rotation from RM\'s LibDataBroker feed; add Rotation Master from Titan\'s plugin menu.'},
 {'ElvUI','ElvUI','Optional action-bar glow support.'},
]=],
        [=[ {'Questie','Questie','Quest update receipts only; native quest progress is not verified.','questie'},
 {'ElvUI','ElvUI','Optional action-bar glow support.'},
]=],
    },
    {
        [=[ ["Masque"]={{["provider"]="github",["label"]="Official website / GitHub",["url"]="https://github.com/SFX-WoW/Masque",["primary"]=true,["note"]="Author-declared website and source repository. Release 12.1.0 declares Retail, Classic Era, TBC, Wrath, Cataclysm and Mists interfaces; RM native acceptance is unverified.",["families"]={"retail","era","tbc","progression"}},{["provider"]="curseforge",["label"]="CurseForge",["url"]="https://www.curseforge.com/wow/addons/masque",["primary"]=false,["note"]="StormFX project 13592. Publisher lists Retail, Forever, Classic, TBC, Mists and Wrath Titan Reforged releases; choose the file for your edition.",["families"]={"retail","forever","era","tbc","progression"}},{["provider"]="wowinterface",["label"]="WoWInterface",["url"]="https://www.wowinterface.com/downloads/info12097-Masque.html",["primary"]=false,["note"]="StormFX project 12097, version 12.1.0. Publisher declares Retail, Classic, TBC, Wrath and Cataclysm; displayed patch metadata varies from current TOC.",["families"]={"retail","era","tbc","progression"}},{["provider"]="wago",["label"]="Wago Addons",["url"]="https://addons.wago.io/addons/masque",["primary"]=false,["note"]="Official mirror linked by the pinned author README and WoWInterface project. This page requires JavaScript; edition metadata was not independently readable.",["families"]={}},{["provider"]="wowuphub",["label"]="WowUp Hub",["url"]="https://wowup.io/addons/16",["primary"]=false,["note"]="StormFX and JJSheets, official SFX-WoW/Masque repository. Current listed Classic Era 12.1.0; Retail and Wrath listings are historical, with current patch support unverified.",["families"]={"era"}}},
 ["DBM-Core"]={{["provider"]="curseforge",["label"]="CurseForge",["url"]="https://www.curseforge.com/wow/addons/deadly-boss-mods",["primary"]=true,["note"]="DBM-Core for Retail, Forever, Classic Era, TBC and Mists Classic. Encounter timers need the matching raid or dungeon module download, such as DBM-Raids-BC for TBC raids.",["families"]={"retail","forever","era","tbc","progression"}},{["provider"]="github",["label"]="GitHub",["url"]="https://github.com/DeadlyBossMods/DeadlyBossMods",["primary"]=false,["note"]="Official source repository. Choose the release for your game edition; source availability does not certify integration behavior.",["families"]={"retail","forever","era","tbc","progression"}},{["provider"]="wowinterface",["label"]="WoWInterface — historical",["url"]="https://www.wowinterface.com/downloads/info8814-DeadlyBossMods.html",["primary"]=false,["note"]="Official historical release page. The authors no longer update it; use CurseForge or GitHub for current releases.",["families"]={}}},
 ["BigWigs"]={{["provider"]="curseforge",["label"]="CurseForge",["url"]="https://www.curseforge.com/wow/addons/big-wigs",["primary"]=true,["note"]="BigWigs (Boss Timers & Tools) for Retail, Forever, Classic and Classic progression. Its TOC also declares TBC Anniversary.",["families"]={"retail","forever","era","tbc","progression"}},{["provider"]="github",["label"]="GitHub",["url"]="https://github.com/BigWigsMods/BigWigs",["primary"]=false,["note"]="Official source repository. Choose the release for your game edition; source availability does not certify integration behavior.",["families"]={"retail","forever","era","tbc","progression"}},{["provider"]="wowinterface",["label"]="WoWInterface",["url"]="https://www.wowinterface.com/downloads/info5086-BigWigsBossmods.html",["primary"]=false,["note"]="Official project page. Publisher lists Retail, Classic Era, TBC, Wrath and Cataclysm Classic. Choose the matching file; exact patch and RM integration behavior may be unverified.",["families"]={"retail","era","tbc","progression"}},{["provider"]="wago",["label"]="Wago Addons",["url"]="https://addons.wago.io/addons/bigwigs",["primary"]=false,["note"]="Official project page. This page requires JavaScript; edition metadata was not independently readable.",["families"]={}}},
 ["Titan"]={{["provider"]="curseforge",["label"]="CurseForge",["url"]="https://www.curseforge.com/wow/addons/titan-panel",["primary"]=true,["note"]="Titan Panel for Retail, Forever, Mists Classic, Classic and Classic TBC.",["families"]={"retail","forever","era","tbc","progression"}},{["provider"]="wowinterface",["label"]="WoWInterface",["url"]="https://www.wowinterface.com/downloads/info8092-TitanPanel.html",["primary"]=false,["note"]="Official project page. Publisher lists Retail and Classic Era. Choose the matching file; exact patch and RM integration behavior may be unverified.",["families"]={"retail","era"}}},
}
]=],
        [=[ ["Masque"]={{["provider"]="github",["label"]="Official website / GitHub",["url"]="https://github.com/SFX-WoW/Masque",["primary"]=true,["note"]="Author-declared website and source repository. Release 12.1.0 declares Retail, Classic Era, TBC, Wrath, Cataclysm and Mists interfaces; RM native acceptance is unverified.",["families"]={"retail","era","tbc","progression"}},{["provider"]="curseforge",["label"]="CurseForge",["url"]="https://www.curseforge.com/wow/addons/masque",["primary"]=false,["note"]="StormFX project 13592. Publisher lists Retail, Forever, Classic, TBC, Mists and Wrath Titan Reforged releases; choose the file for your edition.",["families"]={"retail","forever","era","tbc","progression"}},{["provider"]="wowinterface",["label"]="WoWInterface",["url"]="https://www.wowinterface.com/downloads/info12097-Masque.html",["primary"]=false,["note"]="StormFX project 12097, version 12.1.0. Publisher declares Retail, Classic, TBC, Wrath and Cataclysm; displayed patch metadata varies from current TOC.",["families"]={"retail","era","tbc","progression"}},{["provider"]="wago",["label"]="Wago Addons",["url"]="https://addons.wago.io/addons/masque",["primary"]=false,["note"]="Official mirror linked by the pinned author README and WoWInterface project. This page requires JavaScript; edition metadata was not independently readable.",["families"]={}},{["provider"]="wowuphub",["label"]="WowUp Hub",["url"]="https://wowup.io/addons/16",["primary"]=false,["note"]="StormFX and JJSheets, official SFX-WoW/Masque repository. Current listed Classic Era 12.1.0; Retail and Wrath listings are historical, with current patch support unverified.",["families"]={"era"}}},
}
]=],
    },
    {
        [=[ ["Masque"]={["families"]={"retail","forever","era","tbc","progression"},["progression"]={"wrath","cata","mists"},["interfaceRanges"]={}},
 ["DBM-Core"]={["families"]={"retail","forever","era","tbc","progression"},["progression"]={"wrath","cata","mists"},["interfaceRanges"]={}},
 ["BigWigs"]={["families"]={"retail","forever","era","tbc","progression"},["progression"]={"wrath","cata","mists"},["interfaceRanges"]={}},
 ["Titan"]={["families"]={"retail","forever","era","tbc","progression"},["progression"]={"mists"},["interfaceRanges"]={}},
}
]=],
        [=[ ["Masque"]={["families"]={"retail","forever","era","tbc","progression"},["progression"]={"wrath","cata","mists"},["interfaceRanges"]={}},
}
]=],
    },
    {
        [=[end
local function connection(kind,id)
 if kind=='ecs' then
]=],
        [=[end
local function connection(kind)
 if kind=='ecs' then
]=],
    },
    {
        [=[  return ({connected='connected',disabled='disabled',missing='missing',incompatible='incompatible',error='unknown',unavailable='unknown'})[state]or'loaded'
 elseif kind=='encounters' then
  -- One boss mod is selected at a time; the other loaded one is merely idle.
  local ok,value=pcall(function()
   local get=addon.GetEncounterIntegrationStatus
   if type(get)=='function' then return get(addon) end
  end)
  if not ok or not readable(value) or type(value)~='table' then return 'unknown' end
  local state,provider=rawget(value,'state'),rawget(value,'provider')
  if provider~=id then return 'disabled' end
  return questieStates[state] or 'unknown'
 elseif kind=='questie' then
]=],
        [=[  return ({connected='connected',disabled='disabled',missing='missing',incompatible='incompatible',error='unknown',unavailable='unknown'})[state]or'loaded'
 elseif kind=='questie' then
]=],
    },
    {
        [=[  local version=text(native('GetAddOnMetadata',provider[1],'Version'),4096,true)
  if loaded==true then state=connection(provider[4],provider[1]) end
  local detail=display(provider[3],320)
]=],
        [=[  local version=text(native('GetAddOnMetadata',provider[1],'Version'),4096,true)
  if loaded==true then state=connection(provider[4]) end
  local detail=display(provider[3],320)
]=],
    },
}

records["Locales/enUS.lua"] = {
    bytes = 265776,
    hash = 3494868623,
    {
        [=[L["Seconds"] = true
L["Boss Mod Encounter"] = true
L["Boss Mod Encounter Stage"] = true
L["Boss Mod Timer"] = true
L["Stage"] = true
L["none"] = true
L["Encounter ID (blank for any)"] = true
L["Boss ability spell ID"] = true
L["Running timers:"] = true
L["No boss-mod timers are running."] = true
L["No boss-mod encounter is in progress."] = true
L["Boss mod data unavailable: %s"] = true
L["Current encounter: %s (ID %s), stage %s"] = true
L["your boss mod reports encounter %s {{!is|is not}} in progress"] = true
L["your boss mod {{!reports|does not report}} an encounter in progress"] = true
L["the boss-mod encounter stage"] = true
L["the boss-mod timer for %s"] = true
L["Seconds until the boss mod expects the ability. A paused timer keeps its remaining time."] = true
L["Help.Conditions.BOSSMOD_ENCOUNTER"] = "True while your enabled boss mod (DBM or BigWigs, chosen on the Integrations page) reports a boss encounter in progress. Leave Encounter ID blank for any encounter, or enter the game's encounter ID, which DBM and BigWigs share, to match one boss; while an encounter is active the editor shows its name and ID. This is the boss mod's report, not game state: it starts when the boss mod engages and ends when it records a win, wipe or reset. Use it as a switch condition for encounter-specific rotations; automatic switching picks it up on its normal re-check interval. Unavailable, never simply false, when no boss mod is enabled or loaded."
L["Help.Conditions.BOSSMOD_STAGE"] = "The stage (phase) your boss mod reports for the current encounter. An encounter whose boss mod has not reported a stage counts as stage 1, and some intermissions are reported as half stages such as 1.5. False when no encounter is in progress; unavailable when no boss mod is enabled or loaded."
L["Help.Conditions.BOSSMOD_TIMER"] = "Compares the time left on your boss mod's timer for one boss ability, identified by the ability's spell ID; while timers run, the editor lists them with their IDs. Timers are the boss mod's predictions and can shift, pause or be cancelled. When no timer for that ability is running the condition is false, so 'is less than 5 seconds' is only true while a timer is actually counting down. Bars without a spell ID, such as pull or respawn timers, are not tracked. Unavailable when no boss mod is enabled or loaded."
L["Spell Active or Pending"] = true
]=],
        [=[L["Seconds"] = true
L["Spell Active or Pending"] = true
]=],
    },
    {
        [=[L["Optional action-bar glow support."] = true
L["DBM"] = true
L["BigWigs"] = true
L["Titan Panel"] = true
L["Boss mods"] = true
L["Top panels"] = true
L["Boss-mod timers and encounter stage for the Boss Mod conditions."] = true
L["Shows the active rotation from RM's LibDataBroker feed; add Rotation Master from Titan's plugin menu."] = true
L["DBM-Core for Retail, Forever, Classic Era, TBC and Mists Classic. Encounter timers need the matching raid or dungeon module download, such as DBM-Raids-BC for TBC raids."] = true
L["Official historical release page. The authors no longer update it; use CurseForge or GitHub for current releases."] = true
L["BigWigs (Boss Timers & Tools) for Retail, Forever, Classic and Classic progression. Its TOC also declares TBC Anniversary."] = true
L["Official project page. Publisher lists Retail, Classic Era, TBC, Wrath and Cataclysm Classic. Choose the matching file; exact patch and RM integration behavior may be unverified."] = true
L["Titan Panel for Retail, Forever, Mists Classic, Classic and Classic TBC."] = true
L["Official project page. Publisher lists Retail and Classic Era. Choose the matching file; exact patch and RM integration behavior may be unverified."] = true
L["Help.Integrations.encounter_provider"] = "Enable DBM or BigWigs to feed the Boss Mod conditions (encounter, stage and ability timers), then Apply. Only one boss mod can be enabled; enabling one disables the other. RM listens to the boss mod's own callbacks and never polls it or changes its settings. With none enabled, or the enabled addon not loaded, Boss Mod conditions are unavailable. Supported on Classic Era, TBC and Classic progression clients."
L["Help.Integrations.top_panels"] = "Rotation Master publishes a LibDataBroker data source with the active rotation, a tooltip and click menus. Titan Panel and other LibDataBroker displays show it without further setup: in Titan, add Rotation Master from the plugin menu. Panel absence has no effect on rotation selection."
L["Connected"] = true
]=],
        [=[L["Optional action-bar glow support."] = true
L["Connected"] = true
]=],
    },
}

records["RotationMaster.toc"] = {
    bytes = 8335,
    hash = 2802365333,
    {
        [=[Integrations/questie.lua
Integrations/encounters.lua
Integrations/masque.lua
]=],
        [=[Integrations/questie.lua
Integrations/masque.lua
]=],
    },
    {
        [=[Conditions/misc.lua
Conditions/bossmod.lua

]=],
        [=[Conditions/misc.lua

]=],
    },
}

records["UI/help.lua"] = {
    bytes = 27850,
    hash = 3201346870,
    {
        [=[        {id='questie_enabled',title=L['Enable Questie integration'],text=L['Help.Integrations.questie_enabled']},
        {id='encounter_provider',title=L['Boss mods'],text=L['Help.Integrations.encounter_provider']},
        {id='top_panels',title=L['Top panels'],text=L['Help.Integrations.top_panels']},
        {id='native_highlighting',title=L['Syntax highlighting'],text=L['Help.Integrations.native_highlighting']},
]=],
        [=[        {id='questie_enabled',title=L['Enable Questie integration'],text=L['Help.Integrations.questie_enabled']},
        {id='native_highlighting',title=L['Syntax highlighting'],text=L['Help.Integrations.native_highlighting']},
]=],
    },
}

records["UI/settings_collections.lua"] = {
    bytes = 7552,
    hash = 877541452,
    {
        [=[    local p=cached or self:CreateSettingsForm(parent)
    local scopes={Integrations={profile={'lua_editor','lua_editor_disabled','lua_native_highlighting','lua_line_numbers','questie_enabled','encounter_provider','preview_masque'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','announcement_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','idle_poll','autoswitch_poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
    scopes.Functions={global={'custom_functions'}}
]=],
        [=[    local p=cached or self:CreateSettingsForm(parent)
    local scopes={Integrations={profile={'lua_editor','lua_editor_disabled','lua_native_highlighting','lua_line_numbers','questie_enabled','preview_masque'}},Effects={global={'effects'}},ItemSets={profile={'itemsets'},global={'itemsets'}},Announces={profile={'announces'}},Conditions={profile={'condition_groups','switch_conditions','announcement_conditions','other_conditions_order','disabled_conditions'},global={'custom_conditions'}},General={profile={'enable','poll','idle_poll','autoswitch_poll','ignore_mana','ignore_range','effect','color','magnification','setpoint','xoffs','yoffs','loglevel','detailed_profiling','disable_autoswitch','live_config_update','spell_history','combat_history','damage_history','disable_buttons','rotation_view','preview_spells','preview_vertical','preview_locked','preview_opacity','preview_icon_size','preview_window','minimap'},char={'specs'}}}
    scopes.Functions={global={'custom_functions'}}
]=],
    },
}

records["UI/settings_integrations.lua"] = {
    bytes = 20103,
    hash = 3062102450,
    {
        [=[    end
    -- Boss mods: at most one is enabled; enabling one switches the other off.
    local encounterRows={}
    for _,id in ipairs({'DBM-Core','BigWigs'})do
        local allowed=supported(id);if not current()then return end
        if allowed then
            local entry=metadata[id]or{id=id,name=L[id=='DBM-Core'and'DBM'or id],state='missing'}
            local row=readonly(entry)
            local chosen=profile.encounter_provider==id
            local loaded=entry.loaded==true or entry.loaded==nil and entry.state~='missing'and entry.state~='unknown'
            row.state=not loaded and'missing'or chosen and'enabled'or'disabled'
            if row.state~='missing'or chosen then
                row.action=function()
                    if not supported(id)or not current()then return end
                    profile.encounter_provider=profile.encounter_provider~=id and id or nil
                    p:RunSettingsEffect('encounter_provider',function()self:SyncEncounterIntegration()end);p:Draw()
                end
            end
            encounterRows[#encounterRows+1]=row
        end
    end
    if #encounterRows>0 then groups[#groups+1]={key='integrations_encounters',title=L['Boss mods'],rows=encounterRows}end
    local masqueAllowed=supported('Masque');if not current()then return end
]=],
        [=[    end
    local masqueAllowed=supported('Masque');if not current()then return end
]=],
    },
    {
        [=[    end
    group('integrations_panels',L['Top panels'],{'Titan'})
    group('integrations_actionbars',L['Action bars'],{'ElvUI','Bartender4','ButtonForge','G15Buttons','SyncUI','LUI','Dominos','DiabolicUI','AzeriteUI','Neuron','FarmingBar','TotemTimers','SamyTotemTimers'})
]=],
        [=[    end
    group('integrations_actionbars',L['Action bars'],{'ElvUI','Bartender4','ButtonForge','G15Buttons','SyncUI','LUI','Dominos','DiabolicUI','AzeriteUI','Neuron','FarmingBar','TotemTimers','SamyTotemTimers'})
]=],
    },
}

records["init.lua"] = {
    bytes = 24742,
    hash = 2773269107,
    {
        [=[            "ATTACKABLE", "ENEMY", "COMBAT_HISTORY", "COMBAT_HISTORY_TIME", "TIME_IN_COMBAT",
            "BOSSMOD_ENCOUNTER", "BOSSMOD_STAGE", "BOSSMOD_TIMER",
        }
]=],
        [=[            "ATTACKABLE", "ENEMY", "COMBAT_HISTORY", "COMBAT_HISTORY_TIME", "TIME_IN_COMBAT",
        }
]=],
    },
    {
        [=[    "STEALTHED", "GROUP", "FORM", "CLASS", "CLASS_GROUP", "CREATURE", "CLASSIFICATION",
    "PET", "PET_NAME", "EQUIPPED", "DISTANCE_COUNT", "THREAT_COUNT", "ROLE", "GLYPH",
    "BOSSMOD_ENCOUNTER", "BOSSMOD_STAGE"
}
]=],
        [=[    "STEALTHED", "GROUP", "FORM", "CLASS", "CLASS_GROUP", "CREATURE", "CLASSIFICATION",
    "PET", "PET_NAME", "EQUIPPED", "DISTANCE_COUNT", "THREAT_COUNT", "ROLE", "GLYPH"
}
]=],
    },
    {
        [=[    self:InstallUnitStateConditions(self.db)
    if self.InstallBossModConditions then self:InstallBossModConditions(self.db) end
    self:InstallAnnouncementConditionPreferences()
]=],
        [=[    self:InstallUnitStateConditions(self.db)
    self:InstallAnnouncementConditionPreferences()
]=],
    },
}

records["main.lua"] = {
    bytes = 144249,
    hash = 1889014067,
    {
        [=[    self:InitializeQuestieIntegration()
    if self.InitializeEncounterIntegration then self:InitializeEncounterIntegration() end

]=],
        [=[    self:InitializeQuestieIntegration()

]=],
    },
}

records["tools/check"] = {
    bytes = 46595,
    hash = 3081953555,
    {
        [=[            ['luajit', 'tests/questie_settings.lua'],
            ['lua5.1', 'tests/bossmod_integration.lua'],
            ['luajit', 'tests/bossmod_integration.lua'],
            ['lua5.1', 'tests/integration_catalog.lua'],
]=],
        [=[            ['luajit', 'tests/questie_settings.lua'],
            ['lua5.1', 'tests/integration_catalog.lua'],
]=],
    },
}

records["tools/integration_projects.json"] = {
    bytes = 124452,
    hash = 3297383619,
    {
        [=[      }
    },
    "DBM-Core": {
      "links": [
        {
          "provider": "curseforge",
          "label": "CurseForge",
          "url": "https://www.curseforge.com/wow/addons/deadly-boss-mods",
          "primary": true,
          "note": "DBM-Core for Retail, Forever, Classic Era, TBC and Mists Classic. Encounter timers need the matching raid or dungeon module download, such as DBM-Raids-BC for TBC raids.",
          "families": [
            "retail",
            "forever",
            "era",
            "tbc",
            "progression"
          ]
        },
        {
          "provider": "github",
          "label": "GitHub",
          "url": "https://github.com/DeadlyBossMods/DeadlyBossMods",
          "primary": false,
          "note": "Official source repository. Choose the release for your game edition; source availability does not certify integration behavior.",
          "families": [
            "retail",
            "forever",
            "era",
            "tbc",
            "progression"
          ]
        },
        {
          "provider": "wowinterface",
          "label": "WoWInterface — historical",
          "url": "https://www.wowinterface.com/downloads/info8814-DeadlyBossMods.html",
          "primary": false,
          "note": "Official historical release page. The authors no longer update it; use CurseForge or GitHub for current releases.",
          "families": []
        }
      ],
      "coverage": {
        "curseforge": {
          "status": "verified",
          "query": "Exact DBM-Core project ID 3358 from the installed TOC on curseforge",
          "evidence": [
            "https://www.curseforge.com/wow/addons/deadly-boss-mods: title 'DBM - Deadly Boss Mods (DBM-Core)', project ID 3358, owner MysticalOS; flavors Retail, Forever, MoP Classic, Titan Reforged Classic, Classic (checked 2026-10-23).",
            "GitHub repository homepage field points to https://www.curseforge.com/wow/addons/deadly-boss-mods."
          ]
        },
        "github": {
          "status": "verified",
          "query": "Author-linked GitHub organization DeadlyBossMods",
          "evidence": [
            "https://api.github.com/repos/DeadlyBossMods/DeadlyBossMods: full_name DeadlyBossMods/DeadlyBossMods, not archived, pushed 2026-10-23T05:22:19Z, homepage the CurseForge project.",
            "https://allmylinks.com/mysticalos (redirect target of the TOC X-Website) links https://github.com/DeadlyBossMods."
          ]
        },
        "wowinterface": {
          "status": "verified",
          "query": "Exact Deadly Boss Mods project search on wowinterface",
          "evidence": [
            "https://www.wowinterface.com/downloads/info8814-DeadlyBossMods.html: authors MysticalOS, Tandanu; version 11.2.15 updated 09-15-25; author comment 02-21-26 says the page is no longer updated."
          ]
        },
        "wago": {
          "status": "unverified",
          "query": "Wago project for TOC X-Wago-ID qv633o6b",
          "evidence": [
            "https://addons.wago.io/addons/dbm-core and https://addons.wago.io/addons/dbm returned HTTP 404 on 2026-10-23; the slug for X-Wago-ID qv633o6b was not resolved, and the README links no Wago page."
          ]
        },
        "wowuphub": {
          "status": "unverified",
          "query": "WowUp Hub search for Deadly Boss Mods",
          "evidence": [
            "{\"url\":\"https://hub.wowup.io/addons/search/burningCrusade?query=Deadly%20Boss%20Mods&limit=10\",\"resultCount\":0}"
          ]
        }
      },
      "scope": {
        "families": [
          "retail",
          "forever",
          "era",
          "tbc",
          "progression"
        ],
        "progression": [
          "wrath",
          "cata",
          "mists"
        ],
        "evidence": [
          "Declared edition scope for the DBM-Core folder identity; RM's adapter itself only binds on Classic Era, TBC and Classic progression.",
          "Local TBC Anniversary install, Interface/AddOns/DBM-Core/DBM-Core.toc v12.1.17: '## Interface: 11509, 16001, 20506, 30405, 38002, 40402, 50504, 120100, 120105', X-Curse-Project-ID 3358, X-Wago-ID qv633o6b, X-Website https://deadlybossmods.com (redirects to the author's link page, which links only https://github.com/DeadlyBossMods)."
        ]
      }
    },
    "BigWigs": {
      "links": [
        {
          "provider": "curseforge",
          "label": "CurseForge",
          "url": "https://www.curseforge.com/wow/addons/big-wigs",
          "primary": true,
          "note": "BigWigs (Boss Timers & Tools) for Retail, Forever, Classic and Classic progression. Its TOC also declares TBC Anniversary.",
          "families": [
            "retail",
            "forever",
            "era",
            "tbc",
            "progression"
          ]
        },
        {
          "provider": "github",
          "label": "GitHub",
          "url": "https://github.com/BigWigsMods/BigWigs",
          "primary": false,
          "note": "Official source repository. Choose the release for your game edition; source availability does not certify integration behavior.",
          "families": [
            "retail",
            "forever",
            "era",
            "tbc",
            "progression"
          ]
        },
        {
          "provider": "wowinterface",
          "label": "WoWInterface",
          "url": "https://www.wowinterface.com/downloads/info5086-BigWigsBossmods.html",
          "primary": false,
          "note": "Official project page. Publisher lists Retail, Classic Era, TBC, Wrath and Cataclysm Classic. Choose the matching file; exact patch and RM integration behavior may be unverified.",
          "families": [
            "retail",
            "era",
            "tbc",
            "progression"
          ]
        },
        {
          "provider": "wago",
          "label": "Wago Addons",
          "url": "https://addons.wago.io/addons/bigwigs",
          "primary": false,
          "note": "Official project page. This page requires JavaScript; edition metadata was not independently readable.",
          "families": []
        }
      ],
      "coverage": {
        "curseforge": {
          "status": "verified",
          "query": "Exact BigWigs project ID 2382 from BigWigs.toc on curseforge",
          "evidence": [
            "https://www.curseforge.com/wow/addons/big-wigs: 'BigWigs (Boss Timers & Tools)', project ID 2382, owner Funkeh; v427.7 files for Retail, Forever, Mists Classic, Wrath Titan Reforged and Classic (checked 2026-10-23)."
          ]
        },
        "github": {
          "status": "verified",
          "query": "BigWigsMods/BigWigs repository",
          "evidence": [
            "https://api.github.com/repos/BigWigsMods/BigWigs: not archived, pushed 2026-10-23T03:35:41Z; master 55925095283d3d2a37b2f9a50d342e560bf2a93d.",
            "BigWigs.toc at master: X-Curse-Project-ID 2382, X-WoWI-ID 5086, X-Wago-ID 5NRegwG3, X-Website https://github.com/BigWigsMods."
          ]
        },
        "wowinterface": {
          "status": "verified",
          "query": "TOC X-WoWI-ID 5086",
          "evidence": [
            "https://www.wowinterface.com/downloads/info5086-BigWigsBossmods.html: author funkydude, v427.7 updated 10-21-26; compatibility 12.1.0, Classic 1.15.7, Cataclysm Classic 4.4.2, WOTLK 3.4.3, TBC 2.5.4."
          ]
        },
        "wago": {
          "status": "verified",
          "query": "Wago project for TOC X-Wago-ID 5NRegwG3",
          "evidence": [
            "https://addons.wago.io/addons/bigwigs serves title 'BigWigs (Boss Timers & Tools)'; the rest of the page needs JavaScript (checked 2026-10-23)."
          ]
        },
        "wowuphub": {
          "status": "unverified",
          "query": "WowUp Hub search for BigWigs",
          "evidence": [
            "{\"url\":\"https://hub.wowup.io/addons/search/burningCrusade?query=BigWigs&limit=10\",\"resultCount\":0}",
            "{\"url\":\"https://hub.wowup.io/addons/search/classic?query=BigWigs&limit=10\",\"resultCount\":0}"
          ]
        }
      },
      "scope": {
        "families": [
          "retail",
          "forever",
          "era",
          "tbc",
          "progression"
        ],
        "progression": [
          "wrath",
          "cata",
          "mists"
        ],
        "evidence": [
          "Declared edition scope for the BigWigs folder identity; RM's adapter itself only binds on Classic Era, TBC and Classic progression.",
          "BigWigs.toc at master 5592509: '## Interface: 11508, 11509, 16001, 20505, 20506, 30405, 38002, 40402, 50503, 50504, 120100, 120105, 120107'. Not installed on the TBC Anniversary test client."
        ]
      }
    },
    "Titan": {
      "links": [
        {
          "provider": "curseforge",
          "label": "CurseForge",
          "url": "https://www.curseforge.com/wow/addons/titan-panel",
          "primary": true,
          "note": "Titan Panel for Retail, Forever, Mists Classic, Classic and Classic TBC.",
          "families": [
            "retail",
            "forever",
            "era",
            "tbc",
            "progression"
          ]
        },
        {
          "provider": "wowinterface",
          "label": "WoWInterface",
          "url": "https://www.wowinterface.com/downloads/info8092-TitanPanel.html",
          "primary": false,
          "note": "Official project page. Publisher lists Retail and Classic Era. Choose the matching file; exact patch and RM integration behavior may be unverified.",
          "families": [
            "retail",
            "era"
          ]
        }
      ],
      "coverage": {
        "curseforge": {
          "status": "verified",
          "query": "Exact Titan Panel project search on curseforge",
          "evidence": [
            "https://www.curseforge.com/wow/addons/titan-panel: 'Titan Panel', project ID 489, owner HonorGoG, author urnati; flavors Retail, Forever, MoP Classic, Classic, Classic TBC (checked 2026-10-23)."
          ]
        },
        "wowinterface": {
          "status": "verified",
          "query": "TOC X-WoWI-ID 8092",
          "evidence": [
            "https://www.wowinterface.com/downloads/info8092-TitanPanel.html: authors HonorGoG and urnati, 9.3.5 updated 10-14-26; same version as the installed Titan.toc."
          ]
        },
        "github": {
          "status": "not_found",
          "query": "Titan Panel official source repository",
          "evidence": [
            "Neither the CurseForge nor the WoWInterface page links a source repository; bug reports go to https://sourceforge.net/p/titanpanel/tickets/. A web search found no Titan Panel GitHub repository (2026-10-23)."
          ]
        },
        "wago": {
          "status": "unverified",
          "query": "Wago Addons Titan Panel",
          "evidence": [
            "The installed TOC declares no X-Wago-ID and no publisher page links Wago; not checked further."
          ]
        },
        "wowuphub": {
          "status": "unverified",
          "query": "WowUp Hub Titan Panel",
          "evidence": [
            "No publisher page links WowUp Hub; not checked further."
          ]
        }
      },
      "scope": {
        "families": [
          "retail",
          "forever",
          "era",
          "tbc",
          "progression"
        ],
        "progression": [
          "mists"
        ],
        "evidence": [
          "Local TBC Anniversary install, Interface/AddOns/Titan/Titan.toc v9.3.5: '## Interface: 120105, 50504, 20506, 16001, 11509'.",
          "RM provides only its LibDataBroker data source; Titan's TitanLDB.lua adopts existing data objects through DataObjectIterator and LibDataBroker_DataObjectCreated."
        ]
      }
    }
]=],
        [=[      }
    }
]=],
    },
}

local function digest(s)
    local n = 5381

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return n
end

return function(value, path)
    assert(path ~= 'tests/fixtures/restore_bossmod_integration.lua', 'boss-mod inverse cannot normalize itself')
    value = dofile('tests/fixtures/restore_function_fonts.lua')(value, path)
    local row = type(value) == 'string' and records[path]

    if not row or #value ~= row.bytes or digest(value) ~= row.hash then
        return value
    end

    for i = #row, 1, -1 do
        local s, e = value:find(row[i][1], 1, true)
        value = value:sub(1, s - 1) .. row[i][2] .. value:sub(e + 1)
    end

    return value
end
