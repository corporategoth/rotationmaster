local _,addon=...
local platform=addon.Platform

-- Talent tree providers: the part of the talent selector that SHOWS a tree for
-- a class and specialization and hands back the talent the player clicked.
-- docs/talent-selector.md has the per-client research.
--
-- A provider is a table registered once per client family set:
--   id        string, unique
--   families  { [family]=true } (Platform:GetClientFamily values)
--   priority  number or function returning one, lower is tried first (default 100)
--   available function() -> boolean, cheap, no game reads that can be secret
--   open      function(context) -> handle | nil, reason
-- context = { spec, hero, selection={node,entry,spell}, specs={{id,name,icon}},
--   onSelect(selection), onClose(), onChange(spec,hero) }
-- handle  = { Reload(context), Close(reason) }
-- The UI (UI/talent_popup.lua) tries the available providers in order and keeps
-- the first one whose open succeeds, so a provider that cannot show the tree
-- right now (combat, a window it must not disturb, a missing API) simply says
-- why and the next one gets its turn.
local providers={}
function platform:RegisterTalentTreeProvider(id,provider)
    assert(type(id)=='string' and type(provider)=='table' and type(provider.open)=='function' and type(provider.families)=='table','invalid-talent-tree-provider')
    provider.id=id
    for index,current in ipairs(providers) do
        if current.id==id then providers[index]=provider;provider.order=current.order;return end
    end
    providers[#providers+1]=provider
    provider.order=#providers
end
-- The providers that can serve this client right now, in the order to try them.
function platform:GetTalentTreeProviders()
    local family=self:GetClientFamily()
    local list={}
    for _,provider in ipairs(providers) do
        if provider.families[family] then
            local available=true
            if type(provider.available)=='function' then
                local ok,value=pcall(provider.available)
                available=ok and value==true
            end
            if available then list[#list+1]=provider end
        end
    end
    local function rank(provider)
        local priority=provider.priority
        if type(priority)=='function' then local ok,value=pcall(priority);priority=ok and value or nil end
        return type(priority)=='number' and priority or 100
    end
    table.sort(list,function(a,b)
        local ra,rb=rank(a),rank(b)
        if ra~=rb then return ra<rb end
        return (a.order or 0)<(b.order or 0)
    end)
    return list
end
-- Whether the editors should offer the "Show talent tree" button.
function platform:HasTalentTreeProvider()
    return #self:GetTalentTreeProviders()>0
end

-- Trait tree view (Retail and Forever) ---------------------------------------
local function readable(value) return platform:CanReadValue(value) end
local function traitID(value)
    return readable(value) and type(value)=='number' and value>0 and value<2147483648 and value%1==0
end
local function call(namespace,name,...)
    local fn=type(namespace)=='table' and namespace[name] or nil
    if type(fn)~='function' then return false,'missing-api' end
    local ok,value=pcall(fn,...)
    if not ok then return false,'api-error' end
    if not readable(value) then return false,'restricted-value' end
    return true,value
end
local function traits(name,...) return call(C_Traits,name,...) end
local function classTalents(name,...) return call(C_ClassTalents,name,...) end

local SELECTION,SUBTREE_SELECTION=2,3 -- Enum.TraitNodeType

-- Whether the client has the trait API a provider needs (a cheap feature test;
-- nothing is read). The names are looked up by string, as in Platform/talents.lua.
local function has(namespace,names)
    if type(namespace)~='table' then return false end
    for _,name in ipairs(names) do if type(namespace[name])~='function' then return false end end
    return true
end
-- Blizzard's talent window can be shown a build: view loadouts and loadout strings.
function platform:CanShowTraitViewLoadout()
    return has(C_ClassTalents,{'InitializeViewLoadout'}) and has(C_Traits,{'GetLoadoutSerializationVersion'})
end
-- A tree can be read from the trait API for drawing.
function platform:CanReadTraitTree()
    return has(C_Traits,{'GetNodeInfo','GetTreeNodes'})
end

-- The specialization ID the loadout header names. Retail: the one asked for,
-- else the one being played. Forever has no specialization API of its own, so
-- Blizzard's PlayerUtil answers for the character.
function platform:GetTraitViewSpec(specID)
    if self:GetClientFamily()=='retail' then
        if traitID(specID) then return specID end
        if self.GetPlayerSpecializationID then
            local id=self:GetPlayerSpecializationID()
            if traitID(id) then return id end
        end
    end
    local util=rawget(_G,'PlayerUtil')
    if type(util)=='table' and type(util.GetCurrentSpecID)=='function' then
        local ok,id=pcall(util.GetCurrentSpecID)
        if ok and traitID(id) then return id end
    end
    return nil,'specialization-unsupported'
end

-- The structure of one specialization's trait tree: the node order Blizzard's
-- loadout strings are written in (C_Traits.GetTreeNodes), each visible node's
-- geometry, entries and edges, and the hero trees the specialization can choose.
-- Another specialization is read from the view loadout, never in combat
-- (GetTraitSpecTree). Returns view, or nil and a reason:
--   view = { spec, config, tree, source, order = {nodeID...}, index = {[nodeID]=position},
--            nodes = {[nodeID]={id, x, y, kind, maxRanks, entries={entryID...}, hero, edges={nodeID...}, visible}},
--            heroes = {{id, name, node, position, entry}...} }
function platform:GetTraitView(specID,options)
    -- Reading another specialization fills the shared view config (-3), the one
    -- Blizzard's talent window shows a linked or inspected build from: leave it
    -- alone while that window is on screen showing such a build.
    if traitID(specID) and self:GetClientFamily()=='retail' and not (options and options.ignoreInspect) then
        local played=self.GetPlayerSpecializationID and self:GetPlayerSpecializationID()
        local frame=rawget(_G,'PlayerSpellsFrame')
        if played~=specID and type(frame)=='table' and type(frame.IsShown)=='function' and type(frame.IsInspecting)=='function' then
            local okShown,shown=pcall(frame.IsShown,frame)
            local okInspecting,inspecting=pcall(frame.IsInspecting,frame)
            if okShown and okInspecting and shown and inspecting then return nil,'talent-window-inspecting' end
        end
    end
    local config,tree,source=self:GetTraitSpecTree(specID,{ignoreInspect=true})
    if not config then return nil,tree end
    -- Only a loadout string needs the specialization; the tree can be read without it.
    local header,headerWhy=self:GetTraitViewSpec(source=='view' and specID or nil)
    local ok,list=traits('GetTreeNodes',tree)
    if not ok then return nil,list end
    if type(list)~='table' or #list==0 then return nil,'invalid-api-result' end
    local view={spec=header,specReason=headerWhy,config=config,tree=tree,source=source,order={},index={},nodes={},heroes={}}
    local failure
    for position,node in ipairs(list) do
        if not traitID(node) then return nil,'invalid-api-result' end
        view.order[position]=node;view.index[node]=position
        local okNode,info=traits('GetNodeInfo',config,node)
        if not okNode then failure=failure or info end
        if okNode and type(info)=='table' and readable(info.ID) and info.ID==node then
            local entries={}
            if readable(info.entryIDs) and type(info.entryIDs)=='table' then
                for _,entry in ipairs(info.entryIDs) do if traitID(entry) then entries[#entries+1]=entry end end
            end
            local record={id=node,entries=entries,visible=readable(info.isVisible) and info.isVisible~=false,
                kind=readable(info.type) and type(info.type)=='number' and info.type or nil,
                maxRanks=readable(info.maxRanks) and type(info.maxRanks)=='number' and info.maxRanks or 1,
                x=readable(info.posX) and type(info.posX)=='number' and info.posX or 0,
                y=readable(info.posY) and type(info.posY)=='number' and info.posY or 0,
                hero=readable(info.subTreeID) and traitID(info.subTreeID) and info.subTreeID or nil,edges={}}
            if readable(info.visibleEdges) and type(info.visibleEdges)=='table' then
                for _,edge in ipairs(info.visibleEdges) do
                    if readable(edge) and type(edge)=='table' and traitID(edge.targetNode) then record.edges[#record.edges+1]=edge.targetNode end
                end
            end
            view.nodes[node]=record
        end
    end
    -- The hero trees the specialization can choose, in the order the selection
    -- node lists them. Blizzard lists a hero subtree's nodes only for those the
    -- specialization can choose (HeroTalentsContainer IsNodeInAvailableSubTree).
    local allowed
    if self:GetClientFamily()=='retail' then
        local okHero,ids=classTalents('GetHeroTalentSpecsForClassSpec',config,source=='view' and specID or nil)
        if okHero and type(ids)=='table' then
            allowed={};local any=false
            for _,id in ipairs(ids) do if traitID(id) then allowed[id]=true;any=true end end
            if not any then allowed=nil end
        end
    end
    for _,node in ipairs(view.order) do
        local record=view.nodes[node]
        if record and record.kind==SUBTREE_SELECTION and record.visible then
            for position,entry in ipairs(record.entries) do
                local okEntry,info=traits('GetEntryInfo',config,entry)
                local sub=okEntry and type(info)=='table' and readable(info.subTreeID) and traitID(info.subTreeID) and info.subTreeID or nil
                if sub and (not allowed or allowed[sub]) then
                    local okSub,subInfo=traits('GetSubTreeInfo',config,sub)
                    local name=okSub and type(subInfo)=='table' and readable(subInfo.name) and type(subInfo.name)=='string' and subInfo.name~='' and subInfo.name or nil
                    view.heroes[#view.heroes+1]={id=sub,name=name or tostring(sub),node=node,position=position,entry=entry}
                end
            end
            if #view.heroes>0 then break end
        end
    end
    -- A hero talent outside the chosen tree is not drawn; mark which are allowed.
    view.heroAllowed=allowed
    local count=0;for _ in pairs(view.nodes) do count=count+1 end
    if count==0 then return nil,failure or 'talent-tree-unavailable' end
    return view
end

-- Where a saved selection {node, entry, spell} sits in the view: the node, the
-- 1-based entry position (choice nodes) and the hero subtree it belongs to.
-- A node that no longer holds the saved talent is found again by its spell, the
-- way evaluation does (GetTraitSpellIndex).
function platform:FindTraitViewSelection(view,selection)
    if type(view)~='table' or type(selection)~='table' then return nil end
    local node,entry=selection.node,selection.entry
    local record=traitID(node) and view.nodes[node] or nil
    if record and traitID(selection.spell) then
        local spell=self:GetTraitEntrySpell(view.config,entry or record.entries[1])
        if spell and spell~=selection.spell then record=nil end
    end
    if not record and traitID(selection.spell) then
        for _,id in ipairs(view.order) do
            local candidate=view.nodes[id]
            if candidate and candidate.visible then
                for _,candidateEntry in ipairs(candidate.entries) do
                    if self:GetTraitEntrySpell(view.config,candidateEntry)==selection.spell then record,entry=candidate,candidateEntry;break end
                end
            end
            if record then break end
        end
    end
    if not record then return nil end
    local position
    for index,id in ipairs(record.entries) do if id==entry then position=index end end
    local choice=record.kind==SELECTION
    if not position and not choice then position=1 end
    return {node=record.id,entry=choice and position and record.entries[position] or nil,position=position,hero=record.hero}
end

-- Blizzard's loadout string (Blizzard_ClassTalentImportExport.lua): 8 bits of
-- serialization version, 16 of specialization ID and a 128 bit tree hash
-- (zero-filled: third parties may leave it empty, and ViewLoadout never checks
-- it), then one record per node of C_Traits.GetTreeNodes in order. A node is
-- 0 (unselected) or 1,1 (purchased) followed by 0 (not partially ranked) and
-- the choice bit (1 for a selection node) with the 2 bit entry index.
-- Written to a bit stream and packed six bits per base64 character, least
-- significant bit first (Blizzard_SharedXMLBase/ExportUtil.lua).
local BASE64='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function pack(values)
    local bits,count={},0
    for _,entry in ipairs(values) do
        local value=entry[2]
        for _=1,entry[1] do
            count=count+1;bits[count]=value%2;value=math.floor(value/2)
        end
    end
    local out={}
    for first=1,count,6 do
        local char=0
        for offset=0,5 do
            local bit=bits[first+offset]
            if bit==1 then char=char+2^offset end
        end
        out[#out+1]=BASE64:sub(char+1,char+1)
    end
    return table.concat(out)
end
-- picks: { {node=nodeID, position=entry position (selection nodes)} ... }
function platform:EncodeTraitView(view,picks)
    if type(view)~='table' or type(picks)~='table' then return nil,'invalid-talent-query' end
    local okVersion,version=traits('GetLoadoutSerializationVersion')
    if not okVersion or type(version)~='number' or version<0 or version>255 or version%1~=0 then return nil,okVersion and 'invalid-api-result' or version end
    if not traitID(view.spec) or view.spec>65535 then return nil,view.specReason or 'invalid-talent-query' end
    local chosen={}
    for _,pick in ipairs(picks) do
        local position=view.index[pick.node]
        local record=view.nodes[pick.node]
        if not position or not record then return nil,'talent-node-unavailable' end
        local choice=record.kind==SELECTION or record.kind==SUBTREE_SELECTION
        local entry
        if choice then
            entry=pick.position
            if type(entry)~='number' or entry<1 or entry>4 or entry%1~=0 or entry>#record.entries then return nil,'talent-entry-unavailable' end
        end
        chosen[position]={choice=choice,entry=entry}
    end
    local values={{8,version},{16,view.spec}}
    for _=1,16 do values[#values+1]={8,0} end
    -- One record for every node, as the client writes them, so no read runs past the string.
    for position=1,#view.order do
        local pick=chosen[position]
        if not pick then values[#values+1]={1,0}
        else
            values[#values+1]={1,1};values[#values+1]={1,1};values[#values+1]={1,0}
            values[#values+1]={1,pick.choice and 1 or 0}
            if pick.choice then values[#values+1]={2,pick.entry-1} end
        end
    end
    return pack(values)
end

-- The level a view loadout is built for: maximum, so hero nodes exist.
function platform:GetTraitViewLevel()
    for _,name in ipairs({'GetMaxLevelForPlayerExpansion','GetMaxLevelForLatestExpansion'}) do
        local fn=rawget(_G,name)
        if type(fn)=='function' then
            local ok,level=pcall(fn)
            if ok and readable(level) and type(level)=='number' and level>=1 and level<=200 and level%1==0 then return level end
        end
    end
    local ok,level=pcall(UnitLevel,'player')
    if ok and readable(level) and type(level)=='number' and level>=1 and level<=200 and level%1==0 then return level end
    return 80
end
