-- Test-only copy of the retired rm.tbc.shaman.starter Built In (revision 9): engine tests use it
-- as a fixed, known pack. It is not in the TOC and never ships.
local _, addon = ...
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
