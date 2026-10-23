-- Season of Discovery Warlock tank, levels 1–60 (Metamorphosis engraved). wowsims/sod Phase 4 tank
-- order with Icy Veins, Wowhead and Warcraft Tavern: Shadow Cleave whenever Defender's Resolve is
-- missing or ending (even on one target); a Soul Fire! proc; Incinerate to keep its fire buff; on
-- three engaged enemies Shadow Cleave, Lake of Fire, Shadowflame and Hellfire; a curse (Agony,
-- else Recklessness when nobody has it); Shadowflame (Immolate before it); Master Channeler Drain
-- Life; Corruption; Siphon Life; Conflagrate for Backdraft; Soul Fire under Decimation below 35%;
-- Searing Pain as the threat filler. Reminders: Metamorphosis, Fel Armor, the pet, Immolation
-- Aura, Demonic Grace, Vengeance, Menace when the target is not on you, Demonic Howl on packs, Life
-- Tap for a thirsty pet. Shared parts: era/blocks.lua. Left manual: Infernal Armor.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function remain(id,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local lasting=any({type='GROUP'},{type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},
 {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.4})
local curses={980,603,1490,17862,704,1714,702,18223}
local cursed={type='OR',value={}};for i,id in ipairs(curses)do cursed.value[i]=own(id)end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warlock.tank',revision=1,
 blocks={['era.warlock.boundaries']=1,['era.warlock.armor']=1,['era.warlock.pets']=1},
 nameKey='Default.SoD.Warlock.Tank.Name',descriptionKey='Default.SoD.Warlock.Tank.Description',
 applicability={families={'era'},actionContext='player',class='WARLOCK',minLevel=1,maxLevel=60,rulesets={'season:2'}},
 tags={'tank','ranged','caster','endgame','aoe','season-of-discovery','wowsims','icy-veins','wowhead','warcraft-tavern'},
 sources={{url='https://github.com/wowsims/sod/tree/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/tank_warlock/apls',title='wowsims/sod: Warlock tank Phase 4 APLs',reviewedAt='2026-10-23',revision='0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e'},
 {url='https://www.icy-veins.com/wow-classic/demonology-warlock-tank-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Demonology Warlock tank rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/warlock/tank-overview',title='Wowhead: SoD Warlock tank overview',reviewedAt='2026-10-23',revision='2025-01-26'},
 {url='https://www.warcrafttavern.com/wow-classic-sod/guides/warlock-tank/',title='Warcraft Tavern: SoD Warlock tank (Phase 4)',reviewedAt='2026-10-23'}},
 body={priority=80,switch=known(403789),
 cooldowns={
  spell('sod-tank-metamorphosis',403789,negate(buff(403789))),
  block('era.warlock.armor','sod-tank-'),
  block('era.warlock.pets','sod-tank-'),
  spell('sod-tank-immolation-aura',427726,all(combat(),negate(buff(427726)))),
  spell('sod-tank-demonic-grace',425463,combat()),
  spell('sod-tank-vengeance',426195,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.4})),
  spell('sod-tank-menace',403828,all(combat(),{type='GROUP'},negate({type='ISSAME',unit='targettarget',otherunit='player'}))),
  spell('sod-tank-demonic-howl',412789,all(combat(),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3})),
  spell('sod-tank-amplify-curse',18288,all(combat(),negate(own(980)))),
  spell('sod-tank-pet-life-tap',1454,all(combat(),{type='PET'},{type='MANAPCT',unit='pet',operator='LESSTHAN',value=.3},{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.6})),
 },
 rotation={
 block('era.warlock.boundaries','sod-tank-'),
 spell('sod-tank-shadow-cleave',403835,any(negate(buff(460200)),{type='BUFF_REMAIN',unit='player',spell=460200,operator='LESSTHAN',value=1.5})),
 spell('sod-tank-soul-fire-proc',6353,buff(457643)),
 spell('sod-tank-incinerate',412758,any(negate(buff(412758)),{type='BUFF_REMAIN',unit='player',spell=412758,operator='LESSTHAN',value=3})),
 {id='sod-tank-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('sod-tank-aoe-shadow-cleave',403835),
  spell('sod-tank-aoe-lake-of-fire',460692),
  spell('sod-tank-aoe-shadowflame',426320,negate(own(426320))),
  spell('sod-tank-aoe-hellfire',1949,{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5}),
 }},
 {id='sod-tank-curse',type='branch',conditions=negate(cursed),onFalse={},onTrue={
  spell('sod-tank-agony',980,lasting),
  spell('sod-tank-recklessness',704,negate({type='DEBUFF',unit='target',spell=704,anyrank=true})),
 }},
 spell('sod-tank-shadowflame',426320,all(negate(own(426320)),lasting)),
 spell('sod-tank-drain-life',403677,negate(own(403677))),
 spell('sod-tank-immolate',348,all(negate(known(426320)),any(negate(own(348)),remain(348,1.5)),lasting)),
 spell('sod-tank-corruption',172,all(negate(own(172)),lasting)),
 spell('sod-tank-siphon-life',18265,all(negate(own(18265)),lasting)),
 spell('sod-tank-conflagrate',17962,all(own(348),negate(buff(427714)))),
 spell('sod-tank-decimation-soul-fire',6353,all({type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.35},buff(440873))),
 spell('sod-tank-searing-pain',5676),
 spell('sod-tank-life-tap',1454,{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.5}),
 }},
}))
