-- WoW Forever Elemental Shaman, from Lava Burst (21-point talent, level 30) to 60, Icy Veins
-- leveling order. Chosen with Elemental as the main tree and 21 points in it (Lava Burst's tier):
-- before that every source plays Elemental as a melee hybrid, which the Enhancement default covers. Lightning Bolt (or Chain Lightning on a pack) from range; instants while
-- moving; Fire Nova and Chain Lightning on packs; Flame Shock; Lava Burst on cooldown; Stormstrike
-- into Earth Shock for the Stormcaller hybrid; Fire Nova on a Clearcasting proc in groups;
-- Lightning Bolt. Health, mana and time to die are secret or unavailable on Forever, so self-heals,
-- the low-mana melee pause and the will-it-live checks are left out. Shared parts:
-- Defaults/blocks/forever-shaman.lua.
-- Left manual: totem presets, Earthbind kiting, Frost Shock, Purge and other utility.
local _,addon=...
-- Talent trees in the Forever talent window's order (assumed classic: 1 Elemental, 2 Enhancement, 3 Restoration; verify in game).
-- Level 10 first (no talent config below it), then the points (an empty tree is a clean no-match),
-- then the primary tree, which settles hybrids.
local function tree(n,points)return{type='AND',value={{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=25},
 {type='TALENT_TREE_POINTS',tree=n,operator='GREATERTHANOREQUALS',value=points},{type='PRIMARY_TALENT_TREE',tree=n}}}end
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function enemies(n)return{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local shocked={type='DEBUFF',unit='target',spell=8050,anyrank=true,owndebuff=true}
local melee=negate({type='BEYOND_MELEE',unit='target'})
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.shaman.elemental',revision=7,
 blocks={['forever.shaman.manual-target']=2,['forever.shaman.upkeep']=2,['forever.shaman.imbue']=1,['forever.shaman.group-totems']=1,
  ['forever.shaman.caster-aoe']=1,['forever.shaman.stormstrike-hybrid']=1},
 nameKey='Default.Forever.Shaman.Elemental.Name',descriptionKey='Default.Forever.Shaman.Elemental.Description',
 applicability={families={'forever'},actionContext='player',class='SHAMAN'},
 tags={'dps','ranged','caster','leveling','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-forever/elemental-shaman-leveling',title='Icy Veins: Forever Elemental Shaman leveling',reviewedAt='2026-10-23',revision='2026-10-18'},
 {url='https://www.icy-veins.com/wow-forever/elemental-shaman-ranged-dps-pve-guide',title='Icy Veins: Forever Elemental Shaman PvE guide',reviewedAt='2026-10-23',revision='2026-10-18'},
 {url='https://www.wowhead.com/forever/guide/stormcaller-shaman-hybrid-guide-for-wow-forever-35072',title='Wowhead (user guide): Stormcaller Shaman hybrid',reviewedAt='2026-10-23',revision='2026-10-20'},
 {url='https://www.wowhead.com/forever/guide/classes/shaman/elemental/level-30-dps-overview',title='Wowhead: Forever level 30 Elemental Shaman (Clearcasting Fire Nova)',reviewedAt='2026-10-23',revision='2026-10-06'},
 {url='https://us.forums.blizzard.com/en/wow/t/2360696',title='Blizzard: WoW Forever beta development notes (Lava Burst, Elemental Mastery)',reviewedAt='2026-10-23',revision='2026-10-16'}},
 body={priority=20,switch=tree(1,21),
 cooldowns={block('forever.shaman.upkeep','shaman-ele-'),block('forever.shaman.imbue','shaman-ele-'),block('forever.shaman.group-totems','shaman-ele-'),
  spell('shaman-ele-magma-totem',8190,all(combat(),negate({type='TOTEM',spell=1}),enemies(3))),
  spell('shaman-ele-searing-totem',3599,all(combat(),negate({type='TOTEM',spell=1}),negate(enemies(3)))),
  spell('shaman-ele-elemental-mastery',16166,combat())},
 rotation={
 block('forever.shaman.manual-target','shaman-ele-'),
 {id='shaman-ele-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('shaman-ele-pull-chain',421,all(negate({type='MOVING'}),{type='DISTANCE_COUNT',enemy=true,distance=30,operator='GREATERTHANOREQUALS',value=3})),
  spell('shaman-ele-pull-bolt',403,negate({type='MOVING'})),
  {id='shaman-ele-pull-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 {id='shaman-ele-moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('shaman-ele-moving-flame-shock',8050,negate(shocked)),
  {id='shaman-ele-moving-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 block('forever.shaman.caster-aoe','shaman-ele-'),
 spell('shaman-ele-flame-shock',8050,negate(shocked)),
 spell('shaman-ele-lava-burst',408490),
 block('forever.shaman.stormstrike-hybrid','shaman-ele-'),
 spell('shaman-ele-clearcasting-nova',408341,all({type='GROUP'},{type='BUFF',unit='player',spell=16246},{type='TOTEM',spell=1},melee)),
 spell('shaman-ele-bolt',403),
 }},
}))
