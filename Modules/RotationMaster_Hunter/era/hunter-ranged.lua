-- Classic Era Hunter ranged DPS, levels 1–60, every talent tree (the recommended premade and the
-- Hunter default). Spec buttons (Aimed Shot, Bestial Wrath, Trueshot Aura, Intimidation,
-- Counterattack) are offered once known. Solo: the pet tanks, your own sting, extra shots only on
-- spare mana. In a group: Aimed Shot and Multi-Shot straight after an Auto Shot (the full rotation),
-- Serpent Sting outside raids (debuff limit), Arcane Shot before Aimed Shot or on a dying target.
-- Variants: rm.era.hunter.ranged.icyveins (clipped), rm.era.hunter.ranged.wowsims (raid sting).
-- Left manual: melee weaving, traps, Wing Clip/Disengage, Feed Pet, Tranquilizing Shot, positioning.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function afterAuto(window)return{type='SPELL_HISTORY_TIME',spell=75,ranked=true,operator='LESSTHANOREQUALS',value=window}end
local function remain(op,n)return{type='DEBUFF_REMAIN',unit='target',spell=1978,owndebuff=true,operator=op,value=n}end
local stingless=all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),
 negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}),negate({type='DEBUFF',unit='target',spell=3034,anyrank=true,owndebuff=true}))
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.era.hunter.ranged',revision=4,
 blocks={['era.hunter.boundaries']=3,['era.hunter.dead-zone']=3,['era.hunter.opening']=3,['era.hunter.solo']=2,
  ['era.hunter.hawk']=1,['era.hunter.upkeep']=1,['era.hunter.cooldowns']=1},
 nameKey='Default.Era.Hunter.Ranged.Name',descriptionKey='Default.Era.Hunter.Ranged.Description',
 applicability={families={'era'},actionContext='player',class='HUNTER'},
 tags={'dps','ranged','leveling','endgame','icy-veins','warcraft-tavern','wowsims'},
 sources={
  {url='https://www.icy-veins.com/wow-classic/hunter-dps-pve-rotation-cooldowns-abilities',title='Icy Veins: Classic Hunter DPS rotation, cooldowns and abilities',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.icy-veins.com/wow-classic/marksmanship-hunter-leveling-guide-1-60',title='Icy Veins: Marksmanship Hunter leveling 1-60',reviewedAt='2026-10-23',revision='2024-11-17'},
  {url='https://www.icy-veins.com/wow-classic/hardcore-hunter-class-overview',title='Icy Veins: Hardcore Hunter class overview',reviewedAt='2026-10-23',revision='2023-06-09'},
  {url='https://www.wowhead.com/classic/guide/classes/hunter/dps-rotation-cooldowns-abilities-pve',title='Wowhead: Classic Hunter DPS rotation',reviewedAt='2026-10-23',revision='2025-03-20'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/pve-marksmanship-hunter/',title='Warcraft Tavern: PvE Marksmanship Hunter',reviewedAt='2026-10-23'},
  {url='https://www.warcrafttavern.com/wow-classic/guides/hunter-leveling-guide/',title='Warcraft Tavern: Hunter leveling guide',reviewedAt='2026-10-23'},
  {url='https://github.com/wowsims/classic/blob/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/hunter/apls/p1.apl.json',title='wowsims/classic: Hunter P1 APL',reviewedAt='2026-10-23',revision='7779ebb'},
 },
 body={priority=10,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.hunter.hawk','hunter-'),block('era.hunter.upkeep','hunter-'),block('era.hunter.cooldowns','hunter-')},
 rotation={
  block('era.hunter.boundaries','hunter-'),
  block('era.hunter.dead-zone','hunter-'),
  block('era.hunter.opening','hunter-'),
  {id='hunter-solo',type='branch',conditions={type='GROUP'},onFalse={block('era.hunter.solo','hunter-solo-')},onTrue={
   spell('hunter-aimed-shot',19434,afterAuto(.5)),
   spell('hunter-multi-shot',2643,afterAuto(1)),
   spell('hunter-serpent-sting',1978,all(negate({type='INSTANCE',value='raid'}),any(stingless,remain('LESSTHAN',5)),
    {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=12})),
   spell('hunter-arcane-shot',3044,any(negate({type='SPELL_KNOWN',spell=19434}),{type='TT_HEALTH',unit='target',health=0,operator='LESSTHAN',value=3})),
   {id='hunter-wait-auto',type='stop',suppress_attack=true,conditions={}},
  }},
 }},
}))
