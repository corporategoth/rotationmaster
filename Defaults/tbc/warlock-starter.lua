local _,addon=...
-- Original bounded priority data. Guide provenance and deliberate deviations
-- are recorded in Defaults/README.md; no external guide text is bundled.
local function all(...) return {type='AND',value={...}} end
local function negate(value) return {type='NOT',value=value} end
local function stationary() return negate({type='MOVING'}) end
local function missing(id) return negate({type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}) end
local function damage(id,spell,conditions) return {id='warlock-starter-'..id,type='spell',action=spell,ranked=false,conditions=conditions} end
assert(addon:RegisterDefaultRotation({
    format='RotationMaster',schemaVersion=1,id='rm.tbc.warlock.starter',revision=2,
    nameKey='Default.TBC.Warlock.Starter.Name',descriptionKey='Default.TBC.Warlock.Starter.Description',
    applicability={families={'tbc'},actionContext='player',class='WARLOCK',minLevel=1,maxLevel=29},
    tags={'leveling','solo','starter','affliction','single-target','preview'},
    sources={{url='https://www.icy-veins.com/tbc-classic/affliction-warlock-leveling-guide',
        title='Icy Veins: Affliction Warlock leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
    body={
        switch=all({type='SPELL_KNOWN',spell=686},{type='LEVEL',unit='player',operator='LESSTHAN',value=30}),
        cooldowns={{id='warlock-starter-skin',type='spell',action=687,ranked=false,
            conditions=all(negate({type='SPELL_KNOWN',spell=706}),
                negate({type='BUFF',unit='player',spell=706,anyrank=true}),
                negate({type='BUFF',unit='player',spell=687,anyrank=true}))},
            {id='warlock-starter-armor',type='spell',action=706,ranked=false,
                conditions=all({type='SPELL_KNOWN',spell=706},
                    negate({type='BUFF',unit='player',spell=706,anyrank=true}))}},
        rotation={{id='warlock-starter-target',type='branch',
            conditions=all({type='ATTACKABLE',unit='target'},
                {type='OR',value={{type='COMBAT',unit='player'},negate({type='COMBAT',unit='target'})}}),
            onFalse={},onTrue={
                {id='warlock-starter-channel',type='none',suppress_attack=true,conditions={type='CHANNELING',unit='player'}},
                damage('immolate',348,all(stationary(),missing(348))),
                -- Corruption can become instant through talents; this bounded
                -- preview conservatively retains its stationary requirement.
                damage('corruption',172,all(stationary(),missing(172))),
                damage('agony',980,missing(980)),
                -- 70% is an explicit RM starter heuristic, not a guide claim.
                damage('drain',689,all(stationary(),{type='COMBAT',unit='player'},
                    {type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.7})),
                {id='warlock-starter-wand-known',type='branch',conditions={type='SPELL_KNOWN',spell=5019},onFalse={},onTrue={
                    {id='warlock-starter-wand-active',type='none',suppress_attack=true,
                        conditions={type='SPELL_AUTOREPEAT',spell=5019,ranked=true}}}},
                damage('shoot',5019,stationary()),
                damage('bolt',686,stationary()),
                {id='warlock-starter-exhausted',type='none',suppress_attack=true,conditions={}},
            }}},
    },
}))
