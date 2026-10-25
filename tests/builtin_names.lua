-- Built In display names (the user, 2026-10-25): the list row, the minimap and the website already show
-- the class, the edition and a declared specialization, so the name keeps only the variant, source or
-- approach. Rules, for every shipped pack on every client: no class, edition or "Class:" prefix; a pack that
-- declares a specialization (body.specs) does not repeat it; not empty, capitalized, no trailing punctuation;
-- unique within its class, load scope (Classic Era and Season of Discovery share a client) and specialization.
-- Identifiers come from the pack id, never the name. tools/builtin_names.py derives and documents them.
local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local corpus=dofile('tests/fixtures/default_corpus.lua')
local modules=dofile('tools/builtin_modules.lua')

local names={}
do
    local L=setmetatable({},{__newindex=function(_,key,value) names[key]=value==true and key or value end})
    local env=setmetatable({LibStub=function() return {NewLocale=function() return L end} end,color=setmetatable({},{__index=function() return '' end})},{__index=_G})
    local chunk=assert(loadfile('Locales/enUS.lua'));setfenv(chunk,env);chunk('rotationmaster')
end
local function packs()
    local f=corpus.load(5,1,'ROGUE',{modules=false});local a=f.addon;local out={}
    local register=a.RegisterDefaultRotation
    a.RegisterDefaultRotation=function(self,p) out[#out+1]=a.RotationData.CopyData(p);return register(self,p) end
    for _,path in ipairs(modules.paths()) do f.load(path) end
    return out
end
local CLASSES={'Death Knight','Demon Hunter','Druid','Evoker','Hunter','Mage','Monk','Paladin','Priest','Rogue','Shaman','Warlock','Warrior'}
local EDITIONS={'Retail','MoP','Forever','Season of Discovery','Classic Era','TBC','Mists of Pandaria'}
local function has(name,word) return (' '..name:gsub('[%(%),:]',' ')..' '):find(' '..word..' ',1,true)~=nil end

test('every Built In name keeps only its variant: no class, edition or prefix, nothing repeated, well formed, unique',function()
    local list=packs();assert(#list>=300,#list..' packs')
    local seen,bad={},{}
    for _,p in ipairs(list) do
        local name=names[p.nameKey];local ap=p.applicability
        if type(name)~='string' or name=='' then bad[#bad+1]=p.id..': no name'
        else
            for _,class in ipairs(CLASSES) do if has(name,class) then bad[#bad+1]=p.id..': '..name..' names its class' end end
            for _,edition in ipairs(EDITIONS) do if has(name,edition) then bad[#bad+1]=p.id..': '..name..' names its edition' end end
            if name:find('^[^%(]*:') then bad[#bad+1]=p.id..': '..name..' has a prefix' end
            if name~=name:match('^%s*(.-)%s*$') or name:find('[%.,;:!%-]$') or not name:find('^[A-Z]') then bad[#bad+1]=p.id..': '..name..' is not capitalized or ends in punctuation' end
            local specs=p.body.specs
            if specs and #specs==1 and has(name,'No specialization') then bad[#bad+1]=p.id..': '..name..' repeats its specialization' end
            local group=(ap.families[1]=='era') and 'era' or ap.families[1]..tostring(ap.minExpansion)
            local key=table.concat({ap.class,group,specs and table.concat(specs,',') or 'any',name},'\0')
            if seen[key] then bad[#bad+1]=p.id..' and '..seen[key]..' are both named '..name end
            seen[key]=p.id
        end
    end
    assert(#bad==0,table.concat(bad,'\n'))
end)

test('the names the user asked for, and Season of Discovery keeps its mark',function()
    assert(names['Default.Retail.Monk.Brewmaster.Name']=='Blizzard Assisted with brews',names['Default.Retail.Monk.Brewmaster.Name'])
    assert(names['Default.Retail.Monk.BrewmasterGuide.Name']=='Reference (Icy Veins)')
    assert(names['Default.SoD.Druid.Balance.Name']=='Balance (SoD)' and names['Default.Era.Druid.Balance.Name']=='Balance',
        'Classic Era packs load on Season of Discovery too, so its packs say so')
end)

finish()
