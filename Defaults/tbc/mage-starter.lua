local _,addon=...
-- Original bounded priority data; provenance/omissions are in Defaults/README.md.
local function all(...) return {type='AND',value={...}} end
local function negate(value) return {type='NOT',value=value} end
local function known(id) return {type='SPELL_KNOWN',spell=id} end
local function peaceful() return negate({type='COMBAT',unit='player'}) end
local function conditions(prepull)
    local values={{type='ATTACKABLE',unit='target'},negate({type='MOVING'})}
    if prepull then values[#values+1]=peaceful();values[#values+1]=negate({type='COMBAT',unit='target'}) end
    return {type='AND',value=values}
end
-- Select one training-dependent order, retaining the other family as a
-- readiness fallback without repeating either family in multi-step previews.
local function priorities(prefix,prepull)
    local function filler(suffix,id)
        return {id=prefix..suffix,type='spell',action=id,ranked=false,conditions=conditions(prepull)}
    end
    return {id=prefix..'-preference',type='branch',
        conditions=all(known(143),negate(known(205))),
        onTrue={filler('-fire-first',133),filler('-frost-second',116)},
        onFalse={filler('-frost-first',116),filler('-fire-second',133)}}
end
local rotation={priorities('mage-starter-pull',true),
    {id='mage-starter-combat-boundary',type='none',conditions=peaceful()},
    priorities('mage-starter-combat',false)}

assert(addon:RegisterDefaultRotation({
    format='RotationMaster',schemaVersion=1,id='rm.tbc.mage.starter',revision=1,
    nameKey='Default.TBC.Mage.Starter.Name',descriptionKey='Default.TBC.Mage.Starter.Description',
    applicability={families={'tbc'},actionContext='player',class='MAGE',minLevel=1,maxLevel=19},
    tags={'leveling','solo','starter','frost','single-target','preview'},
    sources={
        {url='https://www.icy-veins.com/tbc-classic/frost-single-target-mage-leveling-guide',
            title='Icy Veins: Frost single-target Mage leveling',reviewedAt='2026-10-18',revision='2026-01-12'},
        {url='https://wowclassicdb.com/tbc/spell/133',title='Fireball rank1 spell record',reviewedAt='2026-10-18'},
        {url='https://wowclassicdb.com/tbc/spell/116',title='Frostbolt rank1 spell record',reviewedAt='2026-10-18'},
        {url='https://wowclassicdb.com/tbc/spell/143',title='Fireball rank2 spell record',reviewedAt='2026-10-18'},
        {url='https://www.wowhead.com/tbc/spell%3D205/frostbolt',title='Frostbolt rank2 spell record',reviewedAt='2026-10-18'},
        {url='https://wowclassicdb.com/tbc/spell/1459',title='Arcane Intellect spell record',reviewedAt='2026-10-18'},
        {url='https://www.wowhead.com/tbc/spell%3D168/frost-armor',title='Frost Armor rank1 spell record',reviewedAt='2026-10-18'},
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
