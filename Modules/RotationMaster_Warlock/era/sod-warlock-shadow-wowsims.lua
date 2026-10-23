-- Season of Discovery Shadow Warlock, wowsims Phase 6 "Drain Soul filler" (alternative premade;
-- same switch, lower priority). For a Soul Siphon build: Drain Soul is the filler at every health
-- and is not protected as a channel, so the next step shows as soon as it is due (clip the channel
-- for it). DoTs are refreshed early: Unstable Affliction and Shadowflame with 7.5 seconds left,
-- Agony and Corruption with 6; Haunt; Shadow Bolt only on a Shadow Trance proc; Siphon Life; Life
-- Tap below 10% mana. Same reminders as the recommended SoD Shadow premade (era/blocks.lua).
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function due(id,n)return any(negate(own(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=n})end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local curses={980,603,1490,17862,704,1714,702,18223}
local others={type='OR',value={}};for i,id in ipairs(curses)do if id~=980 then others.value[#others.value+1]=own(id)end end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.sod.warlock.shadow.wowsims',revision=1,
 blocks={['era.warlock.armor']=1,['era.warlock.pets']=1,['era.warlock.safety']=1},
 nameKey='Default.SoD.Warlock.Shadow.Wowsims.Name',descriptionKey='Default.SoD.Warlock.Shadow.Wowsims.Description',
 applicability={families={'era'},actionContext='player',class='WARLOCK',minLevel=1,maxLevel=60,rulesets={'season:2'}},
 tags={'dps','ranged','caster','endgame','season-of-discovery','wowsims'},
 sources={{url='https://github.com/wowsims/sod/blob/0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e/ui/warlock/apls/p6/affliction.apl.json',title='wowsims/sod: Affliction Warlock Phase 6 APL (Drain Soul filler)',reviewedAt='2026-10-23',revision='0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e'}},
 body={priority=55,switch={type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=1},
 cooldowns={block('era.warlock.armor','sod-ws-'),block('era.warlock.pets','sod-ws-'),
  spell('sod-ws-pet-life-tap',1454,all(combat(),{type='PET'},{type='MANAPCT',unit='pet',operator='LESSTHAN',value=.3},{type='HEALTHPCT',unit='player',operator='GREATERTHAN',value=.6})),
  block('era.warlock.safety','sod-ws-')},
 rotation={
 stop('sod-ws-cast',{type='CASTING',unit='player'}),
 stop('sod-ws-target',negate(all({type='ATTACKABLE',unit='target'},any(combat(),negate({type='COMBAT',unit='target'}),{type='GROUP'})))),
 spell('sod-ws-unstable-affliction',427717,due(427717,7.5)),
 spell('sod-ws-drain-life',403677,negate(own(403677))),
 spell('sod-ws-shadowflame',426320,due(426320,7.5)),
 spell('sod-ws-agony',980,all(negate(others),due(980,6))),
 spell('sod-ws-corruption',172,due(172,6)),
 spell('sod-ws-haunt',403501),
 spell('sod-ws-shadow-trance',686,{type='BUFF',unit='player',spell=17941}),
 spell('sod-ws-siphon-life',18265,negate(own(18265))),
 spell('sod-ws-tap',1454,{type='MANAPCT',unit='player',operator='LESSTHAN',value=.1}),
 stop('sod-ws-draining',{type='CHANNELING',unit='player'}),
 spell('sod-ws-drain-soul',1120),
 spell('sod-ws-bolt',686),
 }},
}))
