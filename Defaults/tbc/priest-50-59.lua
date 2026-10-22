-- Bounded solo preview for Shadow-oriented levels50–59; healing, utility and resources remain manual.
-- Learned Flay above half health is RM policy and may repeat after a channel.
-- Primary allocation is not proof of trained spells or a complete talent build.
-- Manually choose when to channel or wand; active channels and wand filler are preserved.
-- This does not count one/two channels or claim optimal gameplay/native acceptance.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function standing()return negate({type='MOVING'})end
-- Explicit RM preview heuristic; the guide does not prescribe a numeric cutoff.
local function substantial()return{type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.5}end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.tbc.priest.shadow.50-59',revision=1,
 nameKey='Default.TBC.Priest.Shadow50.Name',descriptionKey='Default.TBC.Priest.Shadow50.Description',
 applicability={families={'tbc'},actionContext='player',class='PRIEST',minLevel=50,maxLevel=59},
 tags={'leveling','solo','shadow','single-target','preview'},
 sources={{url='https://www.icy-veins.com/tbc-classic/shadow-priest-leveling-guide',title='Icy Veins: Shadow Priest leveling',reviewedAt='2026-10-20',revision='2026-01-12'}},
 body={
  switch=all({type='SPELL_KNOWN',spell=585},{type='PRIMARY_TALENT_TREE',tree=3},{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=50},{type='LEVEL',unit='player',operator='LESSTHAN',value=60}),
  cooldowns={{id='priest-shadow50-inner-fire',type='spell',action=588,ranked=false,conditions=negate({type='BUFF',unit='player',spell=588,anyrank=true})}},
  rotation={{id='priest-shadow50-target',type='branch',conditions=all({type='ATTACKABLE',unit='target'},
   {type='OR',value={{type='COMBAT',unit='player'},negate({type='COMBAT',unit='target'})}}),onFalse={},onTrue={
   {id='priest-shadow50-channel',type='none',suppress_attack=true,conditions={type='CHANNELING',unit='player'}},
   {id='priest-shadow50-mind-blast-opener',type='spell',action=8092,ranked=false,
    conditions=all(standing(),negate({type='COMBAT',unit='player'}),substantial())},
   {id='priest-shadow50-pain',type='spell',action=589,ranked=false,
    conditions=all(substantial(),negate({type='DEBUFF',unit='target',spell=589,anyrank=true,owndebuff=true}))},
   {id='priest-shadow50-wand-known',type='branch',conditions={type='SPELL_KNOWN',spell=5019},onFalse={},onTrue={
    {id='priest-shadow50-wand-active',type='none',suppress_attack=true,conditions={type='SPELL_AUTOREPEAT',spell=5019,ranked=true}}}},
   -- Preserve active wand before learned Flay filler. 50% is inherited RM policy.
   {id='priest-shadow50-flay-known',type='branch',conditions={type='SPELL_KNOWN',spell=15407},onFalse={},onTrue={
    {id='priest-shadow50-flay',type='spell',action=15407,ranked=false,conditions=all(standing(),substantial())}}},
   {id='priest-shadow50-shoot',type='spell',action=5019,ranked=false,conditions=standing()},
   {id='priest-shadow50-smite',type='spell',action=585,ranked=false,conditions=standing()},
   {id='priest-shadow50-exhausted',type='none',suppress_attack=true,conditions={}},
  }}},
 },
}))
