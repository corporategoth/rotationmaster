local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)

-- BEGIN CONDITION CLIENT SUPPORT
-- A condition that can never work on this client is incomplete, not
-- momentarily unavailable. Each Built In condition declares here the client
-- capabilities its evaluation path requires: the combat data policy, the
-- client family, and the native APIs its readers feature-detect (any one
-- name of a group suffices, as the reader falls back). Validation reads
-- these declarations, so a rotation or cooldown that uses an unsupported
-- condition is unresolved and inactive through the ordinary eligibility
-- path. The condition itself is never evaluated here: a check is a policy
-- read and a few global lookups. Momentary causes (secret this poll, range
-- uncertain, data loading, no GUID yet) stay runtime-only.
--
-- A definition may instead carry its own `supported(value)` returning nil
-- when usable or a reason string; custom definitions are not looked up here.
local env=getfenv and getfenv(1) or _G
local PROBE,POLICY,FAMILY,LISTED,BOSSMOD,LOG='probe','policy','family','listed','bossmod','log'

local function lookup(path)
    local value=env
    for part in path:gmatch('[^.]+') do
        if type(value)~='table' then return nil end
        value=value[part]
    end
    return value
end

-- Value-dependent permanent gates.
local function talentLayout(value)
    if type(value)~='table' then return nil end
    if value.layout==nil and value.tree==nil and value.talent==nil and type(value.value)=='number' then
        return 'historical-talent-layout'
    end
    local platform=addon.Platform
    if not platform or type(platform.GetTalentLayout)~='function' then return nil end
    local current,reason=platform:GetTalentLayout()
    if current==nil then return reason or 'unsupported-talent-layout' end
    local wanted=(value.layout=='grid' or value.layout=='traits') and value.layout or 'tree'
    if current~=wanted then return 'talent-layout-mismatch' end
end
local function treeLayout()
    local platform=addon.Platform
    if not platform or type(platform.GetTalentLayout)~='function' then return nil end
    local current,reason=platform:GetTalentLayout()
    if current==nil then return reason or 'unsupported-talent-layout' end
    if current~='tree' then return 'talent-layout-mismatch' end
end
local function pointEdition()
    local platform=addon.Platform
    if not platform or type(platform.GetClientInfo)~='function' then return nil end
    local info=platform:GetClientInfo()
    if type(info)=='table' and info.family=='progression' and info.expansion~=2 and info.expansion~=3 and info.expansion~=4 then
        return 'unsupported-point-expansion'
    end
end
-- Mists removed the ranged slot and Retail followed (Core/build_context.lua).
local function weaponSlot(value)
    if type(value)~='table' or value.slot~='ranged' then return nil end
    local platform=addon.Platform
    if not platform or type(platform.GetClientInfo)~='function' then return nil end
    local info=platform:GetClientInfo()
    if type(info)=='table' and (info.family=='retail' or info.family=='progression' and type(info.expansion)=='number' and info.expansion>=4) then
        return 'no-ranged-slot'
    end
end
local function glyphLayout()
    local platform=addon.Platform
    if not platform or type(platform.IsGlyphLayoutSupported)~='function' then return nil end
    if not platform:IsGlyphLayoutSupported() then return 'unsupported-glyph-layout' end
end

local UNIT={'UnitExists'}
local CASTING={PROBE,UNIT,{'UnitCastingInfo'}}
local CHANNELING={PROBE,UNIT,{'UnitChannelInfo'}}
local AURA={UNIT,{'C_UnitAuras.GetAuraDataByIndex','UnitAura'}}
local SPELL_COOLDOWN={{'C_Spell.GetSpellCooldown','GetSpellCooldown'}}
local SPELL_CHARGES={{'C_Spell.GetSpellCharges','GetSpellCharges'}}
local SPELL_RANGE={FAMILY,UNIT,{'C_Spell.IsSpellInRange','IsSpellInRange'}}
local SPELL_CURRENT={{'C_Spell.IsCurrentSpell','IsCurrentSpell'}}
local KNOWN={{'C_SpellBook.IsSpellKnown','IsSpellKnown'}}
local function with(base,...)
    local result={};for i,v in ipairs(base) do result[i]=v end
    for i=1,select('#',...) do result[#result+1]=select(i,...) end
    return result
end
local HEALTH={PROBE,UNIT,{'UnitHealth'}}
local HEALTHPCT={PROBE,UNIT,{'UnitHealth'},{'UnitHealthMax'}}
local POWER={PROBE,UNIT,{'Enum.PowerType'},{'UnitPower'}}
local POWERPCT={PROBE,UNIT,{'Enum.PowerType'},{'UnitPower'},{'UnitPowerMax'}}
local FORECAST={PROBE,UNIT,{'UnitGUID'},{'UnitHealth'},{'GetTime'}}
local LOC={PROBE,{'C_LossOfControl.GetActiveLossOfControlDataCount'},{'C_LossOfControl.GetActiveLossOfControlData'}}
local PROXIMITY={UNIT,{'IsInRaid'},{'IsInGroup'},{'UnitIsUnit'},{'UnitPosition'}}
local MOBINFO={PROBE,UNIT,{'UnitName'},{'UnitLevel'}}
local WEAPON={{'GetWeaponEnchantInfo'}}
local SWING={{'UnitAttackSpeed'}}
local TOTEM={{'GetTotemInfo'}}
local TOTEM_SPELL={{'GetNumTotemSlots'},{'GetTotemInfo'}}
local RUNE={PROBE,{'GetRuneType'},{'GetRuneCooldown'}}
local ITEM_LOOKUP={{'C_Item.GetItemCount','GetItemCount'}}

local requirements={
    SELF_LEVEL={FAMILY,UNIT,{'UnitLevel'}},
    LEVEL={FAMILY,UNIT,{'UnitLevel'}},
    PVP={PROBE,UNIT,{'UnitIsPVP'}},
    ZONEPVP={LISTED,{'C_PvP.GetZonePVPInfo','GetZonePVPInfo'}},
    INSTANCE={LISTED,{'IsInInstance'}},
    OUTDOORS={PROBE,{'IsOutdoors'}},
    EQUIPPED={{'C_Item.IsEquippedItem','IsEquippedItem'}},
    CARRYING={{'C_Container.GetContainerNumSlots','GetContainerNumSlots'},{'C_Container.GetContainerItemInfo','GetContainerItemInfo'}},
    ITEM=ITEM_LOOKUP,
    ITEM_RANGE={{'C_Item.IsItemInRange','IsItemInRange'}},
    ITEM_COOLDOWN={{'C_Item.GetItemCooldown','C_Container.GetItemCooldown','GetItemCooldown'}},
    SET_PIECES={{'GetInventoryItemID'}},
    WEAPON_IMBUE=WEAPON,WEAPON=WEAPON,WEAPON_REMAIN=WEAPON,WEAPON_STACKS=WEAPON,
    SWING_TIME=SWING,SWING_TIME_REMAIN=with(SWING,LOG),
    BUFF=AURA,BUFF_REMAIN=AURA,BUFF_STACKS=AURA,STEALABLE=AURA,
    DEBUFF=AURA,DEBUFF_REMAIN=AURA,DEBUFF_STACKS=AURA,DISPELLABLE=AURA,
    TOTEM=TOTEM,TOTEM_REMAIN=TOTEM,TOTEM_SPELL=TOTEM_SPELL,TOTEM_SPELL_REMAIN=TOTEM_SPELL,
    BOSSMOD_ENCOUNTER={BOSSMOD},BOSSMOD_STAGE={BOSSMOD},BOSSMOD_TIMER={BOSSMOD},
    PROXIMITY=PROXIMITY,
    PROXIMITY_HEALTH=with(PROXIMITY,{'UnitHealth'},{'UnitHealthMax'}),
    PROXIMITY_HEALTH_COUNT=with(PROXIMITY,{'UnitHealth'},{'UnitHealthMax'}),
    PROXIMITY_HEALTHPCT=with(PROXIMITY,{'UnitHealth'},{'UnitHealthMax'}),
    PROXIMITY_HEALTHPCT_COUNT=with(PROXIMITY,{'UnitHealth'},{'UnitHealthMax'}),
    PROXIMITY_MANA=with(PROXIMITY,{'UnitPower'},{'UnitPowerMax'}),
    PROXIMITY_MANA_COUNT=with(PROXIMITY,{'UnitPower'},{'UnitPowerMax'}),
    PROXIMITY_MANAPCT=with(PROXIMITY,{'UnitPower'},{'UnitPowerMax'}),
    PROXIMITY_MANAPCT_COUNT=with(PROXIMITY,{'UnitPower'},{'UnitPowerMax'}),
    STAT={PROBE,UNIT},
    CASTING=CASTING,CASTING_SPELL=CASTING,CAST_INTERRUPTABLE=CASTING,CASTING_REMAIN=with(CASTING,{'GetTime'}),CASTING_PROGRESS=with(CASTING,{'GetTime'}),
    CHANNELING=CHANNELING,CHANNELING_SPELL=CHANNELING,CHANNEL_INTERRUPTABLE=CHANNELING,CHANNELING_REMAIN=with(CHANNELING,{'GetTime'}),CHANNELING_PROGRESS=with(CHANNELING,{'GetTime'}),
    BEYOND_MELEE={UNIT},
    SPELL_AVAIL=SPELL_COOLDOWN,SPELL_COOLDOWN=SPELL_COOLDOWN,SPELL_RANGE=SPELL_RANGE,
    SPELL_REMAIN=SPELL_CHARGES,SPELL_CHARGES=SPELL_CHARGES,SPELL_ACTIVE=SPELL_CURRENT,
    SPELL_HISTORY={LOG},SPELL_HISTORY_TIME={LOG},
    COMBAT_HISTORY={LOG},COMBAT_HISTORY_TIME={LOG},
    SPELL_AUTOREPEAT={PROBE,{'C_Spell.IsAutoRepeatSpell','IsAutoRepeatSpell'}},
    SPELL_KNOWN=KNOWN,
    ANYSPELL_AVAIL=SPELL_COOLDOWN,ANYSPELL_COOLDOWN=SPELL_COOLDOWN,ANYSPELL_RANGE=SPELL_RANGE,
    ANYSPELL_REMAIN=SPELL_CHARGES,ANYSPELL_CHARGES=SPELL_CHARGES,
    PETSPELL_AVAIL=with(KNOWN,SPELL_COOLDOWN[1]),PETSPELL_COOLDOWN=with(KNOWN,SPELL_COOLDOWN[1]),
    PETSPELL_RANGE=with(SPELL_RANGE,KNOWN[1]),
    PETSPELL_REMAIN=with(KNOWN,SPELL_CHARGES[1]),PETSPELL_CHARGES=with(KNOWN,SPELL_CHARGES[1]),
    PETSPELL_HISTORY=with(KNOWN,LOG),PETSPELL_HISTORY_TIME=with(KNOWN,LOG),PETSPELL_ACTIVE=with(KNOWN,SPELL_CURRENT[1]),
    HEALTH=HEALTH,HEALTHPCT=HEALTHPCT,
    MANA=POWER,MANAPCT=POWERPCT,POWER=with(POWER,{'UnitPowerType'}),POWERPCT=with(POWERPCT,{'UnitPowerType'}),
    POINT={POLICY,UNIT,{'UnitClass'},{'UnitPower'},pointEdition},
    RUNE=RUNE,RUNE_COOLDOWN=with(RUNE,{'GetTime'}),
    TT_HEALTH=FORECAST,TT_HEALTHPCT=with(FORECAST,{'UnitHealthMax'}),
    COMBAT={PROBE,UNIT,{'UnitAffectingCombat'}},
    PET={PROBE,UNIT},PET_NAME={PROBE,UNIT,{'GetUnitName'}},
    STEALTHED={PROBE,{'IsStealthed'}},INCONTROL={PROBE,{'HasFullControl'}},
    LOC_TYPE=LOC,LOC_BLOCKED=with(LOC,{'bit'}),
    MOVING={PROBE,{'GetUnitSpeed'}},
    THREAT={PROBE,UNIT,{'UnitIsEnemy'},{'UnitThreatSituation'}},
    THREAT_COUNT={PROBE,UNIT,{'UnitGUID'},{'UnitIsEnemy'},{'UnitThreatSituation'}},
    FORM={PROBE,{'GetShapeshiftForm'}},
    ATTACKABLE={PROBE,UNIT,{'UnitCanAttack'},{'UnitIsDead'}},
    ENEMY={PROBE,UNIT,{'UnitIsEnemy'}},
    ISSAME={PROBE,UNIT,{'UnitIsUnit'}},
    CLASS={PROBE,UNIT,{'UnitClass'}},
    CLASSIFICATION={PROBE,UNIT,{'UnitClassification'}},
    CLASS_GROUP={FAMILY,UNIT,{'IsInGroup'},{'IsInRaid'},{'UnitClass'}},
    GROUP={FAMILY,{'IsInGroup'},{'IsInRaid'}},
    ROLE={PROBE,UNIT},
    GLYPH={glyphLayout,{'GetNumGlyphSockets'},{'GetGlyphSocketInfo'}},
    CREATURE={PROBE,UNIT,{'UnitCreatureType'}},
    DEAD={PROBE,UNIT,{'UnitIsDeadOrGhost'}},
    FRIENDLY={PROBE,UNIT,{'UnitIsFriend'}},
    RUNNER=MOBINFO,RESIST=MOBINFO,IMMUNE=MOBINFO,
    ASSISTED_SUGGESTION={{'C_AssistedCombat.GetNextCastSpell'}},
    ASSISTED_ROTATION_SPELL={{'C_AssistedCombat.GetRotationSpells'}},
    ASSISTED_AVAILABLE={{'C_AssistedCombat.IsAvailable'}},
    TALENT={talentLayout},TALENT_TREE_POINTS={treeLayout,{'GetNumTalentTabs'}},PRIMARY_TALENT_TREE={treeLayout,{'GetNumTalentTabs'}},
    DISTANCE={FAMILY,UNIT},
    DISTANCE_COUNT={LOG,UNIT,{'UnitIsEnemy'},{'UnitGUID'},{'C_CVar.GetCVar','GetCVar'}},
    RUNE_ENGRAVED={{'C_Engraving.IsEngravingEnabled'}},
    WEAPON_TYPE={weaponSlot},
    ZONE={{'GetZoneText'},{'GetSubZoneText'}},
}
addon.conditionRequirements=requirements

local listedFamilies={retail=true,forever=true,era=true,tbc=true,progression=true}
local bossmodFamilies={era=true,tbc=true,progression=true}
local function check(requirement,value)
    local kind=type(requirement)
    if kind=='function' then return requirement(value) end
    if kind=='table' then
        for _,path in ipairs(requirement) do
            local found=lookup(path)
            if type(found)=='function' or type(found)=='table' and (path=='Enum.PowerType' or path=='bit') then return nil end
        end
        return 'missing-api'
    end
    local platform=addon.Platform
    if not platform then return nil end
    if requirement==PROBE then
        if platform:GetCombatDataPolicy()~='probe' then return 'unsupported-policy' end
    elseif requirement==LOG then
        -- Combat log, unit combat, spellcast and nameplate events are only
        -- registered under the probe policy (main.lua): without them this
        -- history is never recorded, so the condition could only read empty.
        if platform:GetCombatDataPolicy()~='probe' then return 'combat-events-unavailable' end
    elseif requirement==POLICY then
        local policy=platform:GetCombatDataPolicy()
        if policy~='probe' and policy~='restricted' then return 'unsupported-policy' end
    elseif requirement==FAMILY then
        if platform:GetClientFamily()=='unknown' then return 'unsupported-client' end
    elseif requirement==LISTED then
        if not listedFamilies[platform:GetClientFamily()] then return 'unsupported-policy' end
    elseif requirement==BOSSMOD then
        if not bossmodFamilies[platform:GetClientFamily()] then return 'unsupported-client' end
    end
end

-- nil when the condition can work on this client, else a permanent reason.
-- Never evaluates the condition and never caches: client facts are cached by
-- the platform, and validation results are keyed by the validation stamp,
-- which advances when the client changes (Core/rotation_references.lua).
function addon:GetConditionSupport(tag,definition,value)
    if type(definition)~='table' then return nil end
    if type(definition.supported)=='function' then
        local ok,reason=pcall(definition.supported,value)
        if not ok then return 'support-check-error' end
        return type(reason)=='string' and reason or nil
    end
    if definition.customCode then return nil end
    local list=requirements[tag]
    if not list then return nil end
    for _,requirement in ipairs(list) do
        local reason=check(requirement,value)
        if reason then return reason end
    end
end

local reasonText={
    ['unsupported-policy']=L['combat data is restricted on this client'],
    ['combat-events-unavailable']=L['combat events are not available on this client'],
    ['no-ranged-slot']=L['this client has no ranged slot'],
    ['specialization-unsupported']=L['this client has no specializations for your class'],
    ['missing-api']=L['the game API it needs is missing'],
    ['unsupported-client']=L['this client is not supported'],
    ['talent-layout-mismatch']=L['this client uses a different talent system'],
    ['historical-talent-layout']=L['this client uses a different talent system'],
    ['unsupported-talent-layout']=L['this client uses a different talent system'],
    ['unsupported-glyph-layout']=L['glyphs are not supported on this client build'],
    ['unsupported-point-expansion']=L['this edition has no point resource'],
}
-- "X is not supported on this client (reason)." for an unsupported-condition
-- validation issue; nil for any other issue.
function addon:DescribeUnsupportedCondition(problem)
    if type(problem)~='table' or problem.code~='unsupported-condition' then return nil end
    local definition=self.conditionDefinitions and self.conditionDefinitions[problem.condition]
    local name=type(definition)=='table' and type(definition.description)=='string' and definition.description or tostring(problem.condition)
    return string.format(L['%s is not available on this client (%s).'],name,reasonText[problem.reason] or tostring(problem.reason))
end
-- END CONDITION CLIENT SUPPORT
