-- Season of Discovery Shaman tank (Way of Earth), levels 30–60: chosen when the Way of Earth rune
-- (passive: a tank with Rockbiter and a shield) is engraved. Icy Veins and
-- Wowhead order with wowsims' details: Flame Shock to pull; Earth Shock taunts a target that is
-- not on you and interrupts; on two engaged enemies Molten Blast, Flame Shock, Chain Lightning at
-- five Maelstrom stacks or on Power Surge, Fire Nova at five stacks, Magma; Flame Shock kept up;
-- Lava Burst on Power Surge or while Flame Shock lasts; Stormstrike; Earth Shock; Lightning Bolt
-- at five stacks; Molten Blast; Frost Shock. Reminders: Rockbiter, Lightning Shield, Spirit of
-- the Alpha on yourself, Feral Spirit, Shamanistic Rage, totems. Shared parts: era/blocks.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function totem(slot)return{type='TOTEM',spell=slot}end
local function maelstrom(n)return{type='BUFF_STACKS',unit='player',spell=408505,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function imbue(ids)local list={};for _,id in ipairs(ids)do list[#list+1]={type='WEAPON_IMBUE',enchant=id}end;return{type='OR',value=list}end
local rockbiter=imbue({29,6,1,503,1663,683,1664,7568,504})
local flamed={type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}
local surge={type='BUFF',unit='player',spell=440285}
local group=all(combat(),{type='GROUP'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.shaman.tank',revision=5,
 blocks={['era.shaman.manual']=3,['era.shaman.interrupt']=1},
 nameKey='Default.SoD.Shaman.Tank.Name',descriptionKey='Default.SoD.Shaman.Tank.Description',
 applicability={families={'era'},actionContext='player',class='SHAMAN',rulesets={'season:2'}},
 tags={'tank','melee','endgame','aoe','season-of-discovery','icy-veins','wowhead','wowsims','warcraft-tavern'},
 sources={{url='https://www.icy-veins.com/wow-classic/enhancement-shaman-tank-season-of-discovery-pve-rotation-cooldowns-abilities',title='Icy Veins: SoD Enhancement Shaman tank rotation',reviewedAt='2026-10-23',revision='2025-04-08'},
 {url='https://www.wowhead.com/classic/guide/season-of-discovery/classes/shaman/tank-rotation-cooldowns-abilities-pve',title='Wowhead: SoD Shaman tank rotation',reviewedAt='2026-10-23',revision='2025-04-07'},
 {url='https://github.com/wowsims/sod/tree/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/warden_shaman/apls',title='wowsims/sod: Shaman tank Phase 4 APLs (Enhancement and Elemental)',reviewedAt='2026-10-23',revision='0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e'},
 {url='https://www.warcrafttavern.com/wow-classic/guides/sod-shaman-tank/',title='Warcraft Tavern: SoD Shaman tank (Phase 4)',reviewedAt='2026-10-23'}},
 -- Way of Earth: 408531 is the rune's first taught spell (wowsims/exporter), 408680 the same name on Wowhead.
 body={priority=70,switch={type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=30},any({type='RUNE_ENGRAVED',spell=408531},{type='RUNE_ENGRAVED',spell=408680})}},
 cooldowns={
  spell('sod-tank-rockbiter',8017,negate(rockbiter)),
  spell('sod-tank-lightning-shield',324,negate({type='BUFF',unit='player',spell=324,anyrank=true})),
  spell('sod-tank-spirit-of-the-alpha',408696,negate({type='BUFF',unit='player',spell=408696,ownbuff=true})),
  spell('sod-tank-feral-spirit',440580,combat()),
  spell('sod-tank-shamanistic-rage',425336,all(combat(),any({type='MANAPCT',unit='player',operator='LESSTHANOREQUALS',value=.65},{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5}))),
  spell('sod-tank-searing-totem',3599,all(combat(),negate(totem(1)),{type='THREAT_COUNT',threat=1,operator='LESSTHAN',value=2})),
  spell('sod-tank-magma-totem',8190,all(combat(),negate(totem(1)),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2})),
  spell('sod-tank-strength-of-earth',8075,all(group,negate(totem(2)))),
  spell('sod-tank-grace-of-air',8835,all(group,negate(totem(4)))),
  spell('sod-tank-mana-spring',5675,all(group,negate(totem(3)))),
 },
 rotation={
 block('era.shaman.manual','sod-tank-'),
 {id='sod-tank-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('sod-tank-pull-flame-shock',8050,all({type='ATTACKABLE',unit='target'},negate({type='COMBAT',unit='target'}))),
  {id='sod-tank-pull-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='sod-tank-no-target',type='stop',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 spell('sod-tank-taunt',8042,all(negate({type='ISSAME',unit='targettarget',otherunit='player'}),negate({type='BEYOND_MELEE',unit='target'}))),
 block('era.shaman.interrupt','sod-tank-'),
 {id='sod-tank-aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},onFalse={},onTrue={
  spell('sod-tank-aoe-molten-blast',425339),
  spell('sod-tank-aoe-flame-shock',8050,negate(flamed)),
  spell('sod-tank-aoe-chain-lightning',421,any(maelstrom(5),surge)),
  spell('sod-tank-aoe-fire-nova',408341,maelstrom(5)),
 }},
 spell('sod-tank-flame-shock',8050,negate(flamed)),
 spell('sod-tank-lava-burst',408490,any(surge,{type='DEBUFF_REMAIN',unit='target',spell=8050,anyrank=true,owndebuff=true,operator='GREATERTHANOREQUALS',value=4})),
 spell('sod-tank-stormstrike',17364),
 spell('sod-tank-earth-shock',8042),
 spell('sod-tank-maelstrom-bolt',403,maelstrom(5)),
 spell('sod-tank-molten-blast',425339),
 spell('sod-tank-frost-shock',8056,flamed),
 }},
}))
