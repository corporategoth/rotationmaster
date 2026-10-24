-- Classic Era Warlock, Icy Veins order (alternative premade; same switch, lower priority). Built
-- for 16-debuff realms: in raids only the curse and Corruption, then Shadow Bolt (no Immolate and
-- no Siphon Life even when slots allow). Leveling and five-man play as the recommended premade
-- (era/blocks.lua parts): Immolate with mana, Agony, Corruption, Siphon Life, the wand.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local outside=negate({type='INSTANCE',value='raid'})
local lasting=any({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.4})
local blocks={['era.warlock.boundaries']=2,['era.warlock.procs']=1,['era.warlock.group-finish']=1,['era.warlock.dying']=1,['era.warlock.curse']=2,
 ['era.warlock.moving']=1,['era.warlock.aoe']=1,['era.warlock.sustain']=2,['era.warlock.filler']=1,['era.warlock.armor']=1,['era.warlock.pets']=1,['era.warlock.safety']=1}
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.warlock.dps.icyveins',revision=3,blocks=blocks,
 nameKey='Default.Era.Warlock.DPS.IcyVeins.Name',descriptionKey='Default.Era.Warlock.DPS.IcyVeins.Description',
 applicability={families={'era'},actionContext='player',class='WARLOCK'},
 tags={'dps','ranged','caster','leveling','endgame','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-classic/warlock-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Warlock DPS rotation',reviewedAt='2026-10-23',revision='2024-11-18'},
 {url='https://www.icy-veins.com/wow-classic/classic-warlock-leveling-guide',title='Icy Veins: Classic Warlock leveling guide',reviewedAt='2026-10-23',revision='2024-11-18'},
 {url='https://www.icy-veins.com/wow-classic/warlock-dps-pve-spec-builds-talents',title='Icy Veins: Classic Warlock DPS talents (16-debuff limit)',reviewedAt='2026-10-23',revision='2026-07-18'}},
 body={priority=3,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.warlock.armor','lock-'),block('era.warlock.pets','lock-'),block('era.warlock.safety','lock-')},
 rotation={
 block('era.warlock.boundaries','lock-'),
 block('era.warlock.procs','lock-'),
 block('era.warlock.group-finish','lock-'),
 block('era.warlock.dying','lock-'),
 block('era.warlock.moving','lock-'),
 block('era.warlock.aoe','lock-'),
 block('era.warlock.curse','lock-'),
 spell('lock-immolate',348,all(outside,any(negate(own(348)),{type='DEBUFF_REMAIN',unit='target',spell=348,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5}),
  any(known(17962),{type='MANAPCT',unit='player',operator='GREATERTHAN',value=.4}),lasting)),
 spell('lock-corruption',172,negate(own(172))),
 spell('lock-siphon-life',18265,all(outside,negate(own(18265)))),
 block('era.warlock.sustain','lock-'),
 block('era.warlock.filler','lock-'),
 }},
}))
