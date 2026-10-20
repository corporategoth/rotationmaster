-- Strict whole-pack inverses for the bounded e3fb19e TBC twenty-level scope extension.
local sources={
 ['Defaults/tbc/shaman-starter.lua']={old=[====[local _, addon = ...
-- Original priority data, not copied guide prose. Scope and omissions are in
-- Defaults/README.md. IDs are locale-independent; the engine expands action ranks.
local function all(...) return {type="AND",value={...}} end
local function notCondition(value) return {type="NOT",value=value} end
local function known(id) return {type="SPELL_KNOWN",spell=id} end
local function peaceful() return notCondition({type="COMBAT",unit="player"}) end
local function attackable() return {type="ATTACKABLE",unit="target"} end

assert(addon:RegisterDefaultRotation({
    format="RotationMaster",schemaVersion=1,id="rm.tbc.shaman.starter",revision=8,
    nameKey="Default.TBC.Shaman.Starter.Name",descriptionKey="Default.TBC.Shaman.Starter.Description",
    applicability={families={"tbc"},actionContext="player",class="SHAMAN",minLevel=1,maxLevel=19},
    tags={"leveling","solo","starter","preview"},
    sources={
        {url="https://www.icy-veins.com/tbc-classic/enhancement-shaman-leveling-guide",
            title="Icy Veins: Enhancement Shaman leveling",reviewedAt="2026-10-18",revision="2026-01-12"},
    },
    body={
        switch=all(known(403),{type="LEVEL",unit="player",operator="LESSTHAN",value=20}),
        rotation={
            {id="shaman-starter-pull",type="spell",action=403,ranked=false,
                conditions=all(peaceful(),attackable(),notCondition({type="COMBAT",unit="target"}))},
            {id="shaman-starter-combat-boundary",type="none",conditions=peaceful()},
            {id="shaman-starter-shock",type="spell",action=8042,ranked=false,
                conditions=attackable()},
            {id="shaman-starter-ranged-bolt",type="spell",action=403,ranked=false,
                conditions=all(attackable(),
                    {type="BEYOND_MELEE",unit="target"},notCondition({type="MOVING"}))},
        },
        cooldowns={
            {id="shaman-starter-imbue",type="spell",action=8017,ranked=false,
                conditions=notCondition({type="WEAPON",offhand=false})},
            {id="shaman-starter-shield",type="spell",action=324,ranked=false,
                conditions=notCondition({type="BUFF",unit="player",spell=324,ownbuff=true,anyrank=true})},

        },
    },
}))
]====],new=[====[local _, addon = ...
-- Original priority data, not copied guide prose. Scope and omissions are in
-- Defaults/README.md. IDs are locale-independent; the engine expands action ranks.
local function all(...) return {type="AND",value={...}} end
local function notCondition(value) return {type="NOT",value=value} end
local function known(id) return {type="SPELL_KNOWN",spell=id} end
local function peaceful() return notCondition({type="COMBAT",unit="player"}) end
local function attackable() return {type="ATTACKABLE",unit="target"} end

assert(addon:RegisterDefaultRotation({
    format="RotationMaster",schemaVersion=1,id="rm.tbc.shaman.starter",revision=9,
    nameKey="Default.TBC.Shaman.Starter.Name",descriptionKey="Default.TBC.Shaman.Starter.Description",
    applicability={families={"tbc"},actionContext="player",class="SHAMAN",minLevel=1,maxLevel=29},
    tags={"leveling","solo","starter","preview"},
    sources={
        {url="https://www.icy-veins.com/tbc-classic/enhancement-shaman-leveling-guide",
            title="Icy Veins: Enhancement Shaman leveling",reviewedAt="2026-10-20",revision="2026-01-12"},
    },
    body={
        switch=all(known(403),{type="LEVEL",unit="player",operator="LESSTHAN",value=30}),
        rotation={
            {id="shaman-starter-pull",type="spell",action=403,ranked=false,
                conditions=all(peaceful(),attackable(),notCondition({type="COMBAT",unit="target"}))},
            {id="shaman-starter-combat-boundary",type="none",conditions=peaceful()},
            {id="shaman-starter-shock",type="spell",action=8042,ranked=false,
                conditions=attackable()},
            {id="shaman-starter-ranged-bolt",type="spell",action=403,ranked=false,
                conditions=all(attackable(),
                    {type="BEYOND_MELEE",unit="target"},notCondition({type="MOVING"}))},
        },
        cooldowns={
            {id="shaman-starter-imbue",type="spell",action=8017,ranked=false,
                conditions=notCondition({type="WEAPON",offhand=false})},
            {id="shaman-starter-shield",type="spell",action=324,ranked=false,
                conditions=notCondition({type="BUFF",unit="player",spell=324,ownbuff=true,anyrank=true})},

        },
    },
}))
]====]},
 ['Defaults/tbc/mage-starter.lua']={old=[====[local _,addon=...
-- Original bounded priority data; provenance/omissions are in Defaults/README.md.
local function all(...) return {type='AND',value={...}} end
local function negate(value) return {type='NOT',value=value} end
local function known(id) return {type='SPELL_KNOWN',spell=id} end
-- The same filler decision works before and during combat. One outer
-- guard permits a deliberate pull, but never pulls an already engaged target
-- while the player is out of combat. Branches carry shared prerequisites.
local rotation={{id='mage-starter-target',type='branch',
    conditions=all({type='ATTACKABLE',unit='target'},negate({type='MOVING'}),
        {type='OR',value={{type='COMBAT',unit='player'},negate({type='COMBAT',unit='target'})}}),
    onTrue={{id='mage-starter-preference',type='branch',
        conditions=all(known(133),{type='OR',value={negate(known(116)),all(known(143),negate(known(205)))}}),
        onTrue={{id='mage-starter-fire',type='spell',action=133,ranked=false,conditions={}}},
        onFalse={{id='mage-starter-frost',type='spell',action=116,ranked=false,conditions={}}}}},
    onFalse={}}}

assert(addon:RegisterDefaultRotation({
    format='RotationMaster',schemaVersion=1,id='rm.tbc.mage.starter',revision=2,
    nameKey='Default.TBC.Mage.Starter.Name',descriptionKey='Default.TBC.Mage.Starter.Description',
    applicability={families={'tbc'},actionContext='player',class='MAGE',minLevel=1,maxLevel=19},
    tags={'leveling','solo','starter','frost','single-target','preview'},
    sources={
        {url='https://www.icy-veins.com/tbc-classic/frost-single-target-mage-leveling-guide',
            title='Icy Veins: Frost single-target Mage leveling',reviewedAt='2026-10-18',revision='2026-01-12'},
    },
    body={
        switch=all({type='OR',value={known(133),known(116)}},{type='LEVEL',unit='player',operator='LESSTHAN',value=20}),
        rotation=rotation,
        cooldowns={
            {id='mage-starter-intellect',type='spell',action=1459,ranked=false,
                conditions=negate({type='BUFF',unit='player',spell=1459,anyrank=true})},
            {id='mage-starter-armor',type='spell',action=168,ranked=false,
                conditions=negate({type='BUFF',unit='player',spell=168,anyrank=true})},
        },
    },
}))
]====],new=[====[local _,addon=...
-- Original bounded priority data; provenance/omissions are in Defaults/README.md.
local function all(...) return {type='AND',value={...}} end
local function negate(value) return {type='NOT',value=value} end
local function known(id) return {type='SPELL_KNOWN',spell=id} end
-- The same filler decision works before and during combat. One outer
-- guard permits a deliberate pull, but never pulls an already engaged target
-- while the player is out of combat. Branches carry shared prerequisites.
local rotation={{id='mage-starter-target',type='branch',
    conditions=all({type='ATTACKABLE',unit='target'},negate({type='MOVING'}),
        {type='OR',value={{type='COMBAT',unit='player'},negate({type='COMBAT',unit='target'})}}),
    onTrue={{id='mage-starter-preference',type='branch',
        conditions=all(known(133),{type='OR',value={negate(known(116)),all(known(143),negate(known(205)))}}),
        onTrue={{id='mage-starter-fire',type='spell',action=133,ranked=false,conditions={}}},
        onFalse={{id='mage-starter-frost',type='spell',action=116,ranked=false,conditions={}}}}},
    onFalse={}}}

assert(addon:RegisterDefaultRotation({
    format='RotationMaster',schemaVersion=1,id='rm.tbc.mage.starter',revision=3,
    nameKey='Default.TBC.Mage.Starter.Name',descriptionKey='Default.TBC.Mage.Starter.Description',
    applicability={families={'tbc'},actionContext='player',class='MAGE',minLevel=1,maxLevel=29},
    tags={'leveling','solo','starter','frost','single-target','preview'},
    sources={
        {url='https://www.icy-veins.com/tbc-classic/frost-single-target-mage-leveling-guide',
            title='Icy Veins: Frost single-target Mage leveling',reviewedAt='2026-10-20',revision='2026-01-12'},
    },
    body={
        switch=all({type='OR',value={known(133),known(116)}},{type='LEVEL',unit='player',operator='LESSTHAN',value=30}),
        rotation=rotation,
        cooldowns={
            {id='mage-starter-intellect',type='spell',action=1459,ranked=false,
                conditions=negate({type='BUFF',unit='player',spell=1459,anyrank=true})},
            {id='mage-starter-armor',type='spell',action=168,ranked=false,
                conditions=negate({type='BUFF',unit='player',spell=168,anyrank=true})},
        },
    },
}))
]====]},
}
return function(text,path)
 local source=assert(sources[path],'unexpected TBC pack inverse path')
 assert(text==source.new,'TBC pack differs outside exact reviewed scope extension: '..path)
 return source.old
end
