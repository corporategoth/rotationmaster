local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function read(p)local h=assert(io.open(p));local s=h:read('*a');h:close();return s end
local restore=dofile('tests/fixtures/restore_announcement_series.lua')
local function digest(s)local n=5381;for i=1,#s do n=(n*33+s:byte(i))%4294967296 end;return n end
local function edit(s)return(s:sub(1,1)=='x'and'y'or'x')..s:sub(2)end
local function parse(s)local a={};assert(loadstring(s,'@closed-series-catalog'))('rotationmaster',a);return a.BuiltinSourceCatalog end
local function same(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local expected={["Core/announcement_data.lua"]={3872,1591932332},["Core/announcements.lua"]={12210,2253749734},["Core/macro_announcements.lua"]={9095,3095355608},["Data/builtin_sources.lua"]={799968,1697819878},["Help/announce.lua"]={4321,3362715946},["Locales/enUS.lua"]={251886,73360735},["Platform/announcement_recipient.lua"]={5366,3155682252},["UI/collection_compare.lua"]={12669,300530493},["UI/help.lua"]={27348,299157396},["UI/settings_announces.lua"]={15083,3295725144},["UI/settings_ordered.lua"]={10997,2563273466},["UI/settings_transfer.lua"]={15259,2811276624},["Web/schema/catalog.json"]={32746,839979888},["main.lua"]={94453,3541972621},["tools/check"]={40229,3807220061}}

test('complete series sources reconstruct all fifteen exact predecessor digests',function()
 local n=0
 for p,row in pairs(expected)do local current=read(p);local old=restore(current,p);assert(#old==row[1]and digest(old)==row[2],p);assert(old~=current,p);assert(restore(old,p)==old,p);assert(not pcall(restore,current..current,p),'duplicate accepted '..p);n=n+1 end
 assert(n==15)
end)
test('same-length unrelated successor and predecessor mutations reject',function()
 for p in pairs(expected)do local current=read(p);local old=restore(current,p);assert(not pcall(restore,edit(current),p),'successor edit accepted '..p);assert(not pcall(restore,edit(old),p),'predecessor edit accepted '..p)end
 assert(not pcall(restore,'','tests/fixtures/restore_announcement_series.lua'),'inverse normalized itself')
end)
test('catalog normalization is exact detached predecessor and rejects unrelated current code',function()
 local source=read('Data/builtin_sources.lua');local current=parse(source);local old=parse(restore(source,'Data/builtin_sources.lua'));local normalized=restore(current,'Data/builtin_sources.lua','catalog')
 assert(same(normalized,old)and normalized~=current and normalized.conditions~=current.conditions)
 current.conditions.COMBAT.callbacks.evaluate.code=current.conditions.COMBAT.callbacks.evaluate.code..' '
 assert(not pcall(restore,current,'Data/builtin_sources.lua','catalog'),'changed current callback code accepted')
end)
test('catalog predecessor metadata and presence edits reject before older proofs',function()
 local old=parse(restore(read('Data/builtin_sources.lua'),'Data/builtin_sources.lua'));assert(same(restore(old,'Data/builtin_sources.lua','catalog'),old))
 old.conditions.COMBAT.callbacks.evaluate.line=old.conditions.COMBAT.callbacks.evaluate.line+1
 assert(not pcall(restore,old,'Data/builtin_sources.lua','catalog'),'changed predecessor metadata accepted')
 local clean=parse(restore(read('Data/builtin_sources.lua'),'Data/builtin_sources.lua'));clean.conditions.COMBAT.unrelated=false
 assert(not pcall(restore,clean,'Data/builtin_sources.lua','catalog'),'false-presence edit accepted')
end)
finish()
