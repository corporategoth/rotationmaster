-- A Retail (12.x) class talent tree, as the client's C_Traits / C_ClassTalents
-- answer for it. NO REAL CLIENT WAS AVAILABLE: this models Blizzard's generated
-- API documentation (Gethe/wow-ui-source live 12.1.5.70575,
-- Blizzard_APIDocumentationGenerated SharedTraits/ClassTalents) and how the
-- talent window itself reads the tree (Blizzard_SharedTalentUI,
-- Blizzard_PlayerSpells/ClassTalents). Node and spell IDs are invented.
--
-- Facts modeled, each from that source:
--   * C_Traits.GetTreeNodes(tree) holds the nodes of ALL specializations of the
--     class, class talents and hero talents ("Contains nodes for all class
--     specializations"); the active config answers GetNodeInfo for every one,
--     with isVisible false (and no ranks) for nodes of other specializations.
--   * A selection node (type 2) has several entries, each its own talent; a
--     tiered node (type 1) has several entries that are the tiers of ONE
--     talent; the hero SubTreeSelection node (type 3) has entries without a
--     definition, only a subTreeID.
--   * Hero talents carry subTreeID; subTreeActive says the subtree is chosen.
--     C_ClassTalents.GetHeroTalentSpecsForClassSpec lists the subtrees a
--     specialization may choose.
--   * Another specialization is read from the view config
--     (Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID, -3) after
--     C_ClassTalents.InitializeViewLoadout(specID, level);
--     C_ClassTalents.GetTraitTreeForSpec(specID) names the tree.
--   * C_Traits.GetNodeInfo(config, node) answers ID 0 for a config that does not
--     contain the node. activeRank counts granted ranks too.
local M={}

M.TREE=1001
M.ACTIVE=7
M.VIEW=-3
M.SPECS={Arcane=62,Fire=63,Frost=64}
M.CLASS_ID=8

-- {id, name, icon}
local function spell(id,name) return {id=id,name=name,icon=id+100000} end
M.spells={
    [1459]=spell(1459,'Arcane Intellect'),[212653]=spell(212653,'Shimmer'),[1953]=spell(1953,'Blink'),
    [45438]=spell(45438,'Ice Block'),[110959]=spell(110959,'Greater Invisibility'),[342245]=spell(342245,'Alter Time'),
    [100000]=spell(100000,'Improved Frost Nova I'),[100001]=spell(100001,'Improved Frost Nova II'),
    [5143]=spell(5143,'Arcane Missiles'),[321739]=spell(321739,'Arcane Surge'),
    [11366]=spell(11366,'Pyroblast'),[190319]=spell(190319,'Combustion'),[257541]=spell(257541,'Phoenix Flames'),
    [235870]=spell(235870,'Alexstrasza\'s Fury'),[155148]=spell(155148,'Kindling'),
    [84714]=spell(84714,'Frozen Orb'),[199786]=spell(199786,'Glacial Spike'),[153595]=spell(153595,'Comet Storm'),
    [431044]=spell(431044,'Frostfire Bolt'),[431066]=spell(431066,'Isothermic Core'),
    [443739]=spell(443739,'Spellfrost Teachings'),[444735]=spell(444735,'Overpowered Missiles'),
    [451038]=spell(451038,'Sunfury Execution'),[449559]=spell(449559,'Invocation: Arcane Phoenix'),
}
M.heroNames={[41]='Frostfire',[42]='Spellslinger',[43]='Sunfury'}
-- The hero trees each specialization can choose.
M.heroOf={[62]={42,43},[63]={41,43},[64]={41,42}}

-- Node table. spec=nil is a class talent. hero=subTreeID for a hero talent.
-- entries: list of spell IDs; kind: 'single' (default), 'selection', 'tiered', 'subtree'.
M.nodes={
    {id=2001,x=1,y=1,entries={1459},ranks=1,edges={2002,2003}},
    {id=2002,x=2,y=1,kind='selection',entries={212653,1953},ranks=1},
    {id=2003,x=1,y=2,entries={45438},ranks=1},
    {id=2004,x=2,y=2,kind='tiered',entries={100000,100001},ranks=2},
    {id=2005,x=3,y=2,entries={110959},ranks=1},
    {id=2006,x=4,y=3,entries={342245},ranks=1},
    -- Arcane
    {id=2101,x=1,y=1,spec=62,entries={5143},ranks=1,granted=true},
    {id=2102,x=2,y=1,spec=62,entries={321739},ranks=1},
    -- Fire
    {id=2201,x=1,y=1,spec=63,entries={11366},ranks=1,granted=true,edges={2202}},
    {id=2202,x=2,y=1,spec=63,entries={190319},ranks=1,edges={2203}},
    {id=2203,x=3,y=1,spec=63,entries={257541},ranks=2},
    {id=2204,x=4,y=1,spec=63,entries={235870,155148},kind='selection',ranks=1},
    -- Frost
    {id=2301,x=1,y=1,spec=64,entries={84714},ranks=1},
    {id=2302,x=2,y=1,spec=64,entries={199786},ranks=1},
    {id=2303,x=3,y=1,spec=64,entries={153595},ranks=1},
    -- Hero: the selection node, then each subtree's talents.
    {id=2400,x=5,y=1,kind='subtree',entries={},subtrees={41,42,43},ranks=1},
    {id=2411,x=1,y=9,hero=41,entries={431044},ranks=1,edges={2412}},{id=2412,x=2,y=9,hero=41,entries={431066},ranks=1},
    {id=2421,x=1,y=9,hero=42,entries={443739},ranks=1},{id=2422,x=2,y=9,hero=42,entries={444735},ranks=1},
    {id=2431,x=1,y=9,hero=43,entries={451038},ranks=1},{id=2432,x=2,y=9,hero=43,entries={449559},ranks=1},
}

-- Entry IDs are 3000+node*10+position; definition IDs 4000+entry.
local function entryID(node,position) return 3000+node.id*10+position end
M.entryID=entryID

-- state: {spec (the played specialization), purchased = {[node]=rank | {entry=position,rank=n}},
-- chosenHero (subtree ID), leakHero (hero nodes of other specializations answer visible),
-- combat, errors = {fn=true}, viewSpec (set by InitializeViewLoadout), calls}
function M.install(env,state)
    state=state or {}
    state.spec=state.spec or M.SPECS.Fire
    state.purchased=state.purchased or {[2001]=1,[2002]={entry=2,rank=1},[2003]=1,[2201]=1,[2202]=1,[2203]=2,[2204]={entry=2,rank=1},[2411]=1}
    state.chosenHero=state.chosenHero==nil and 41 or state.chosenHero
    state.calls=state.calls or {}
    local function hit(name) state.calls[name]=(state.calls[name] or 0)+1 end
    local byID,byEntry,byDefinition={},{},{}
    for _,node in ipairs(M.nodes) do
        byID[node.id]=node
        for position,id in ipairs(node.entries) do
            local entry=entryID(node,position);byEntry[entry]={node=node,position=position,spell=id}
            byDefinition[4000+entry]=entry
        end
        if node.kind=='subtree' then
            for position,sub in ipairs(node.subtrees) do local entry=entryID(node,position);byEntry[entry]={node=node,position=position,subTree=sub} end
        end
    end
    local function gate(name)
        hit(name)
        if state.errors and state.errors[name] then error(name..' blocked',0) end
    end
    -- Which specialization a config shows.
    local function specOf(config)
        if config==M.ACTIVE then return state.spec end
        if config==M.VIEW then return state.viewSpec end
    end
    local function visible(node,spec)
        if spec==nil then return false end
        if node.hero then
            for _,sub in ipairs(M.heroOf[spec]) do if sub==node.hero then return true end end
            return state.leakHero==true
        end
        return node.spec==nil or node.spec==spec
    end
    local function purchasedRank(node,config)
        if config~=M.ACTIVE then return 0,nil end
        local p=state.purchased[node.id]
        if p==nil then
            if node.granted and node.spec==state.spec then return 1,1 end
            return 0,nil
        end
        if type(p)=='table' and getmetatable(p)==nil and p.rank~=nil then return p.rank,p.entry end
        return p,1
    end
    local traits={}
    traits.GetLoadoutSerializationVersion=function() gate('GetLoadoutSerializationVersion');return 2 end
    traits.GetConfigInfo=function(config)
        gate('GetConfigInfo')
        if config==M.ACTIVE or (config==M.VIEW and state.viewSpec) then return {ID=config,type=1,name='Loadout',treeIDs={M.TREE},usesSharedActionBars=false} end
    end
    traits.GetTreeNodes=function(tree)
        gate('GetTreeNodes');assert(tree==M.TREE)
        local list={};for _,node in ipairs(M.nodes) do list[#list+1]=node.id end;return list
    end
    traits.GetNodeInfo=function(config,id)
        gate('GetNodeInfo')
        local node=byID[id];local spec=specOf(config)
        if not node or spec==nil then return {ID=0,posX=0,posY=0,entryIDs={},isVisible=false,activeRank=0,maxRanks=0,groupIDs={},conditionIDs={}} end
        local entries={}
        if node.kind=='subtree' then for position=1,#node.subtrees do entries[position]=entryID(node,position) end
        else for position=1,#node.entries do entries[position]=entryID(node,position) end end
        local rank,position=purchasedRank(node,config)
        local scale=state.scale or 1
        local info={ID=id,posX=node.x*scale,posY=node.y*scale,flags=0,entryIDs=entries,isVisible=visible(node,spec),isAvailable=true,
            ranksPurchased=node.granted and 0 or rank,activeRank=rank,currentRank=rank,maxRanks=node.ranks,totalMaxRanks=node.ranks,
            type=({single=0,tiered=1,selection=2,subtree=3})[node.kind or 'single'],groupIDs={},conditionIDs={},visibleEdges={}}
        for _,target in ipairs(node.edges or {}) do info.visibleEdges[#info.visibleEdges+1]={targetNode=target,type=0,visualStyle=0,isActive=false} end
        if type(rank)=='number' and rank>0 and position then info.activeEntry={entryID=entryID(node,position),rank=rank} end
        if node.hero then
            info.subTreeID=node.hero
            info.subTreeActive=(config==M.ACTIVE and state.chosenHero==node.hero) or (config==M.VIEW and false)
        end
        return info
    end
    traits.GetEntryInfo=function(config,entry)
        gate('GetEntryInfo')
        local record=byEntry[entry];if not record then return nil end
        if record.subTree then return {subTreeID=record.subTree,type=2,maxRanks=1,isAvailable=true,conditionIDs={}} end
        return {definitionID=4000+entry,type=1,maxRanks=record.node.ranks,isAvailable=true,conditionIDs={}}
    end
    traits.GetDefinitionInfo=function(definition)
        gate('GetDefinitionInfo')
        local entry=byDefinition[definition];if not entry then return nil end
        return {spellID=byEntry[entry].spell}
    end
    traits.GetSubTreeInfo=function(config,sub)
        gate('GetSubTreeInfo')
        if M.heroNames[sub] then return {ID=sub,name=M.heroNames[sub],isActive=state.chosenHero==sub,subTreeSelectionNodeIDs={2400}} end
    end
    local classTalents={
        GetActiveConfigID=function() gate('GetActiveConfigID');if state.noConfig then return nil end;return M.ACTIVE end,
        GetTraitTreeForSpec=function(spec) gate('GetTraitTreeForSpec');for _,id in pairs(M.SPECS) do if id==spec then return M.TREE end end end,
        InitializeViewLoadout=function(spec,level)
            gate('InitializeViewLoadout');assert(type(level)=='number' and level>=1)
            state.viewSpec=spec;state.viewLevel=level
        end,
        GetHeroTalentSpecsForClassSpec=function(config,spec)
            gate('GetHeroTalentSpecsForClassSpec')
            local use=spec or (config==M.ACTIVE and state.spec) or state.viewSpec
            local list={};for _,sub in ipairs(M.heroOf[use] or {}) do list[#list+1]=sub end;return list,71
        end,
    }
    env.C_Traits,env.C_ClassTalents=traits,classTalents
    env.Enum=env.Enum or {}
    env.Enum.TraitNodeType={Single=0,Tiered=1,Selection=2,SubTreeSelection=3}
    -- Specializations of the class (Blizzard_UnitFrame GetSpecializationInfoForClassID order:
    -- id, name, description, icon, role, primaryStat).
    local specNames={[62]='Arcane',[63]='Fire',[64]='Frost'}
    local order={62,63,64}
    env.GetSpecializationInfoForClassID=function(class,index) assert(class==M.CLASS_ID);local id=order[index];return id,specNames[id],'',id+500,'DAMAGER',4 end
    env.GetSpecializationInfoByID=function(id) return id,specNames[id],'',id+500,'DAMAGER','MAGE','Mage' end
    local sp={
        GetNumSpecializationsForClassID=function() return 3 end,
        GetSpecialization=function() for index,id in ipairs(order) do if id==state.spec then return index end end end,
        GetSpecializationInfo=function(index) local id=order[index];return id,specNames[id],'',id+500,'DAMAGER',4 end,
    }
    env.C_SpecializationInfo=sp
    env.UnitClass=function() return 'Mage','MAGE',M.CLASS_ID end
    env.UnitLevel=function() return 80 end
    env.InCombatLockdown=function() return state.combat==true end
    env.C_Spell=env.C_Spell or {}
    env.C_Spell.GetSpellInfo=function(id) local s=M.spells[id];if s then return {spellID=id,name=s.name,iconID=s.icon} end end
    return state,byEntry
end

return M
