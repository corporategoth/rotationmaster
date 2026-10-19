local _,addon=...
local data=addon.RotationData
local isClass=data.IsRotationClassToken
local components={'body','origin','imported','comparison'}
local legacyKinds={rotations='body',origins='origin',imports='imported',comparisons='comparison'}
local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
local function text(v,limit) return type(v)=='string' and #v>0 and #v<=limit and v:find('%S')~=nil and not v:find('[%z\1-\31\127]') end
local function spec(v) return type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
local function fields(v,allowed)
    if not plain(v) then return false end
    for key in pairs(v) do if not allowed[key] then return false end end
    return true
end
local function validAddress(a)
    return fields(a,{scope=true,class=true,owner=true,spec=true,id=true}) and isClass(a.class) and spec(a.spec) and text(a.id,128)
        and (a.scope=='class' and a.owner==a.class or a.scope=='character' and text(a.owner,512))
end
local function visible(a,c)
    if not plain(c) or not isClass(c.class) then return nil,'missing-owner-context' end
    if a.scope=='character' and not text(c.character,512) then return nil,'missing-owner-context' end
    if c.class~=a.class or a.scope=='character' and a.owner~=c.character then return nil,'foreign-owner' end
    return true
end
local function equal(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end;return true
end
local function copied(value) return data.CopyData(value) end
local function copyRecord(record)
    local result={}
    for _,key in ipairs(components) do if record[key]~=nil then result[key]=copied(record[key]) end end
    return result
end
local function originMap(value)
    if not plain(value) then return false end
    for key,origin in pairs(value) do if not text(key,128) or not text(origin,128) then return false end end
    return true
end
local function validRecord(record,address)
    if not fields(record,{body=true,origin=true,imported=true,comparison=true}) or not plain(record.body) or not data.CheckPortable(record.body)
        or record.origin~=nil and record.imported~=nil then return nil,'invalid-record' end
    for _,kind in ipairs({'origin','imported','comparison'}) do
        if record[kind]~=nil and (not plain(record[kind]) or not data.CheckPortable(record[kind])) then return nil,'invalid-record' end
    end
    local provenance=record.origin or record.imported
    if provenance then
        local manifest=provenance.manifest
        if not plain(manifest) or manifest.body~=nil or manifest.id~=address.id then return nil,'invalid-record' end
        if manifest.applicability~=nil and not plain(manifest.applicability) then return nil,'invalid-record' end
        if manifest.applicability and manifest.applicability.class and manifest.applicability.class~=address.class then return nil,'source-class-mismatch' end
        -- Validate manifest structure independently of an incomplete current body.
        local envelope=copied(manifest);envelope.body={rotation={},cooldowns={}}
        if not data.ValidateEnvelope(envelope).valid then return nil,'invalid-record' end
        if record.origin then
            if not fields(provenance,{manifest=true,lineage=true}) or not plain(provenance.lineage) then return nil,'invalid-record' end
            local catalog=data.NewCatalog({state={custom={[address.id]=envelope},lineage={[address.id]=provenance.lineage}}})
            local view=catalog and catalog:Get({kind='custom',id=address.id})
            if not view or view.lineageError then return nil,'invalid-record' end
        elseif not fields(provenance,{manifest=true,sourceId=true,sourceRevision=true,stepOrigins=true}) or not text(provenance.sourceId,128)
            or provenance.sourceRevision~=nil and (not spec(provenance.sourceRevision) or provenance.sourceRevision<1)
            or not originMap(provenance.stepOrigins) then return nil,'invalid-record' end
    end
    local comparison=record.comparison
    if comparison and (not fields(comparison,{kind=true,id=true,origins=true}) or comparison.kind~='custom' and comparison.kind~='builtin'
        or not text(comparison.id,128) or not originMap(comparison.origins)) then return nil,'invalid-record' end
    return true
end
local function validSpecMap(map,visit)
    if not plain(map) then return nil,'invalid-store' end
    for number,rows in pairs(map) do
        if not spec(number) or not plain(rows) then return nil,'invalid-store' end
        for id,value in pairs(rows) do
            if not text(id,128) then return nil,'invalid-store' end
            local ok,why=visit(value,id,number);if not ok then return nil,why end
        end
    end
    return true
end
local function validLegacy(legacy)
    if not fields(legacy,{rotations=true,origins=true,imports=true,comparisons=true,evidence=true}) then return nil,'invalid-legacy-state' end
    for kind in pairs(legacyKinds) do if legacy[kind]~=nil then
        local ok=validSpecMap(legacy[kind],function(value) return data.CheckPortable(value) end)
        if not ok then return nil,'invalid-legacy-state' end
    end end
    if legacy.evidence~=nil and not data.CheckPortable(legacy.evidence) then return nil,'invalid-legacy-state' end
    return true
end
local function detachedPayload(value,owned)
    if type(value)~='table' then return true end
    if owned[value] then return false end
    for _,child in pairs(value) do if not detachedPayload(child,owned) then return false end end
    return true
end
local function distinctStructure(state)
    local owned,payloads={},{}
    local function claim(value)
        if owned[value] then return false end;owned[value]=true;return true
    end
    local function maps(map)
        if not claim(map) then return false end
        for _,rows in pairs(map) do
            if not claim(rows) then return false end
            for _,record in pairs(rows) do
                if not claim(record) then return false end
                for _,component in ipairs(components) do if record[component]~=nil then payloads[#payloads+1]=record[component] end end
            end
        end
        return true
    end
    if not claim(state) or not claim(state.classes) or not claim(state.characters) or not claim(state.legacy) then return false end
    for _,map in pairs(state.classes) do if not maps(map) then return false end end
    for _,bucket in pairs(state.characters) do if not claim(bucket) or not maps(bucket.specs) then return false end end
    for kind in pairs(legacyKinds) do if state.legacy[kind]~=nil then
        local map=state.legacy[kind];if not claim(map) then return false end
        for _,rows in pairs(map) do
            if not claim(rows) then return false end
            for _,value in pairs(rows) do payloads[#payloads+1]=value end
        end
    end end
    if state.legacy.evidence~=nil then payloads[#payloads+1]=state.legacy.evidence end
    -- Repeated data references are legal; owner containers must never be data.
    -- Otherwise a later plain table write could mutate another owner's body.
    for _,value in ipairs(payloads) do if not detachedPayload(value,owned) then return false end end
    return true
end
local function validState(state)
    if not fields(state,{version=true,classes=true,characters=true,legacy=true}) or state.version~=1 or not plain(state.classes) or not plain(state.characters) then return nil,'invalid-store' end
    for class,map in pairs(state.classes) do
        if not isClass(class) then return nil,'invalid-store' end
        local ok,why=validSpecMap(map,function(record,id,number) return validRecord(record,{id=id,class=class,spec=number}) end)
        if not ok then return nil,why end
    end
    for owner,bucket in pairs(state.characters) do
        if not text(owner,512) or not fields(bucket,{class=true,specs=true}) or not isClass(bucket.class) then return nil,'invalid-store' end
        local ok,why=validSpecMap(bucket.specs,function(record,id,number) return validRecord(record,{id=id,class=bucket.class,spec=number}) end)
        if not ok then return nil,why end
    end
    local ok,why=validLegacy(state.legacy);if not ok then return nil,why end
    if not distinctStructure(state) then return nil,'aliased-store' end
    return true
end
function data.ValidateRotationStore(state) return validState(state) end
local function copyLegacy(legacy)
    local result={}
    for kind in pairs(legacyKinds) do if legacy[kind]~=nil then
        local map={};result[kind]=map
        for number,rows in pairs(legacy[kind]) do
            map[number]={};for id,value in pairs(rows) do map[number][id]=copied(value) end
        end
    end end
    if legacy.evidence~=nil then result.evidence=copied(legacy.evidence) end
    return result
end
-- A proposal only: no source ownership is inferred and no live profile is changed.
function data.PlanRotationStoreMigration(legacy)
    local ok,why=validState({version=1,classes={},characters={},legacy=legacy});if not ok then return nil,why end
    return {version=1,classes={},characters={},legacy=copyLegacy(legacy)}
end

-- One profile-owned state object, with explicit caller-provided identity/config.
-- Bodies may be incomplete; storage safety and runtime readiness are separate.
function data.NewRotationStore(options)
    if not plain(options) then return nil,'invalid-store-options' end
    local state=options.state
    if not text(options.fallbackID,128) then return nil,'invalid-fallback-id' end
    local ok,why=validState(state);if not ok then return nil,why end
    local service={};local tokens=setmetatable({},{__mode='k'});local plans=setmetatable({},{__mode='k'})
    local function roots() return {state.classes,state.characters,state.legacy} end
    local function sameRoots(previous) return previous[1]==state.classes and previous[2]==state.characters and previous[3]==state.legacy end
    -- Built only after full validation or our own detached plain-table writes.
    local function buildIndex()
        local result={roots=roots(),classes={},characters={},owned={[state]=true}}
        for _,root in ipairs(result.roots) do result.owned[root]=true end
        local function add(bucket,map)
            result.owned[bucket]=true;result.owned[map]=true
            local owner={bucket=bucket,map=map,specs={}}
            for number,rows in pairs(map) do
                result.owned[rows]=true
                local scope={rows=rows,records={},count=0};owner.specs[number]=scope
                for id,record in pairs(rows) do
                    scope.records[id]=record;scope.count=scope.count+1;result.owned[record]=true
                end
            end
            return owner
        end
        for class,map in pairs(state.classes) do result.classes[class]=add(map,map) end
        for name,bucket in pairs(state.characters) do
            local owner=add(bucket,bucket.specs);owner.class=bucket.class;result.characters[name]=owner
        end
        for kind in pairs(legacyKinds) do if state.legacy[kind] then
            local map=state.legacy[kind];result.owned[map]=true
            for _,rows in pairs(map) do result.owned[rows]=true end
        end end
        return result
    end
    local index=buildIndex()
    local function locate(a)
        local root=a.scope=='class' and state.classes or state.characters
        local bucket=root[a.owner];local map=a.scope=='class' and bucket or bucket and bucket.specs
        local rows=map and map[a.spec]
        return rows and rows[a.id],{root,bucket or false,map or false,rows or false}
    end
    local function capture(a)
        local record,chain=locate(a)
        return {address=copied(a),record=record,chain=chain,roots=roots(),baseline=record and copyRecord(record)}
    end
    local function alive(lease)
        if not sameRoots(lease.roots) then return false end
        local current,chain=locate(lease.address)
        if current~=lease.record or not equal(current,lease.baseline) then return false end
        for i=1,4 do if chain[i]~=lease.chain[i] then return false end end;return true
    end
    local function target(a,c)
        if not validAddress(a) then return nil,'invalid-address' end
        local allowed,reason=visible(a,c);if not allowed then return nil,reason end
        local valid,problem=validState(state);if not valid then return nil,problem end
        local bucket=a.scope=='character' and state.characters[a.owner]
        if bucket and bucket.class~=a.class then return nil,'foreign-owner' end
        return true
    end
    local function readRows(a,c)
        if not validAddress(a) then return nil,'invalid-address' end
        local allowed,reason=visible(a,c);if not allowed then return nil,reason end
        if not fields(state,{version=true,classes=true,characters=true,legacy=true}) or state.version~=1
            or not plain(state.classes) or not plain(state.characters) or not plain(state.legacy) then return nil,'invalid-store' end
        if not sameRoots(index.roots) then return nil,'stale-store-index' end
        local root=a.scope=='class' and state.classes or state.characters
        local indexed=(a.scope=='class' and index.classes or index.characters)[a.owner]
        local bucket=root[a.owner]
        if bucket~=nil and not plain(bucket) then return nil,'invalid-store' end
        if a.scope=='character' and bucket and bucket.class~=a.class then return nil,'foreign-owner' end
        if bucket~=(indexed and indexed.bucket) then return nil,'stale-store-index' end
        if not indexed then return true end
        if a.scope=='character' and bucket.class~=indexed.class then return nil,'stale-store-index' end
        if a.scope=='character' and not fields(bucket,{class=true,specs=true}) then return nil,'invalid-store' end
        local map=a.scope=='class' and bucket or bucket.specs
        if not plain(map) then return nil,'invalid-store' end
        if map~=indexed.map then return nil,'stale-store-index' end
        local rows,scope=map[a.spec],indexed.specs[a.spec]
        if rows~=(scope and scope.rows) then return nil,'stale-store-index' end
        if rows~=nil and not plain(rows) then return nil,'invalid-store' end
        return true,rows,scope
    end
    local function selected(record,a)
        local valid,reason=validRecord(record,a);if not valid then return nil,reason end
        for _,component in ipairs(components) do
            if not detachedPayload(record[component],index.owned) then return nil,'aliased-store' end
        end
        return true
    end
    local function readRecord(a,c)
        local allowed,rows,scope=readRows(a,c);if not allowed then return nil,rows end
        local record=rows and rows[a.id]
        if record~=(scope and scope.records[a.id]) then return nil,'stale-store-index' end
        if record then local valid,reason=selected(record,a);if not valid then return nil,reason end end
        return true,record
    end
    local function checkExpected(a,expected)
        local lease=tokens[expected]
        if not lease or not equal(lease.address,a) or not alive(lease) then return nil,'stale-rotation-record' end
        return lease
    end
    local function prepare(record,a)
        local valid,reason=validRecord(record,a);if not valid then return nil,reason end
        if options.requireValidWrites and not data.ValidateBody(record.body,options.validation).valid then return nil,'invalid-rotation-body' end
        return copyRecord(record)
    end
    local function plan(operation,a,c,lease,payload,destination)
        local public={operation=operation,address=copied(a),destination=destination and copied(destination)}
        plans[public]={operation=operation,address=copied(a),source=lease,record=payload,destination=destination and copied(destination),
            target=capture(destination or a),roots=roots(),context={class=c.class,character=c.character}}
        return public
    end
    function service:Get(a,c)
        local allowed,record=readRecord(a,c);if not allowed then return nil,record end
        if not record then return nil,'unknown-rotation' end
        local lease=capture(a)
        local token={};tokens[token]=lease
        return copyRecord(record),token,data.ValidateBody(record.body,options.validation)
    end
    local function row(a,record) return {address=copied(a),record=copyRecord(record),validation=data.ValidateBody(record.body,options.validation)} end
    local function sort(rows)
        table.sort(rows,function(a,b)
            local x,y=a.address,b.address
            for _,key in ipairs({'scope','class','owner'}) do if x[key]~=y[key] then return (x[key] or '')<(y[key] or '') end end
            if x.spec~=y.spec then return x.spec<y.spec end;return x.id<y.id
        end);return rows
    end
    function service:ListVisible(number,c)
        if not spec(number) then return nil,'invalid-specialization' end
        if not plain(c) or not isClass(c.class) then return nil,'missing-owner-context' end
        local result={}
        local function add(kind,owner)
            local a={scope=kind,class=c.class,owner=owner,spec=number,id=options.fallbackID}
            local allowed,rows,scope=readRows(a,c);if not allowed then return nil,rows end
            local count=0
            for id,record in pairs(rows or {}) do
                if not text(id,128) or scope.records[id]~=record then return nil,'stale-store-index' end
                count=count+1;a.id=id
                local valid,reason=selected(record,a);if not valid then return nil,reason end
                result[#result+1]=row(a,record)
            end
            if count~=(scope and scope.count or 0) then return nil,'stale-store-index' end
            return true
        end
        local allowed,reason=add('class',c.class);if not allowed then return nil,reason end
        local character
        if type(c.character)=='string' then character=state.characters[c.character] end
        if character~=nil and not plain(character) then return nil,'invalid-store' end
        if not character or character.class==c.class then
            if text(c.character,512) then allowed,reason=add('character',c.character);if not allowed then return nil,reason end end
        end
        return sort(result)
    end
    function service:GetFallback(number,c)
        if not plain(c) or not isClass(c.class) or not text(c.character,512) then return nil,'missing-owner-context' end
        if not spec(number) then return nil,'invalid-specialization' end
        local found
        for _,kind in ipairs({'character','class'}) do
            local a={scope=kind,class=c.class,owner=kind=='class' and c.class or c.character,spec=number,id=options.fallbackID}
            local allowed,record=readRecord(a,c);if not allowed then return nil,record end
            if record then found=row(a,record);break end
        end
        if not found then return nil,'unknown-rotation' end
        if not found.validation.valid then return found,'invalid-fallback' end
        if not found.validation.supported or not found.validation.resolved then return found,'unavailable-fallback' end
        return found
    end
    function service:Refresh()
        local valid,reason=validState(state);if not valid then return nil,reason end
        local replacement=buildIndex()
        index=replacement;tokens=setmetatable({},{__mode='k'});plans=setmetatable({},{__mode='k'})
        return true
    end
    function service:AllStored()
        local valid,reason=validState(state);if not valid then return nil,reason end
        local result={}
        local function add(scope,owner,class,map)
            for number,rows in pairs(map) do for id,record in pairs(rows) do result[#result+1]=row({scope=scope,class=class,owner=owner,spec=number,id=id},record) end end
        end
        for class,map in pairs(state.classes) do add('class',class,class,map) end
        for owner,bucket in pairs(state.characters) do add('character',owner,bucket.class,bucket.specs) end
        local union={}
        for kind,component in pairs(legacyKinds) do for number,rows in pairs(state.legacy[kind] or {}) do
            union[number]=union[number] or {}
            for id,value in pairs(rows) do local record=union[number][id] or {};union[number][id]=record;record[component]=copied(value) end
        end end
        for number,rows in pairs(union) do for id,record in pairs(rows) do
            result[#result+1]={address={scope='legacy',spec=number,id=id},record=record,
                validation=data.ValidateBody(record.body,options.validation)}
        end end
        return sort(result)
    end
    function service:PlanCreate(a,record,c)
        local allowed,reason=target(a,c);if not allowed then return nil,reason end
        if locate(a)~=nil then return nil,'rotation-id-collision' end
        local payload,problem=prepare(record,a);if not payload then return nil,problem end
        return plan('create',a,c,nil,payload)
    end
    function service:PlanReplace(a,record,c,expected)
        local allowed,reason=target(a,c);if not allowed then return nil,reason end
        local lease,problem=checkExpected(a,expected);if not lease then return nil,problem end
        local payload,errorText=prepare(record,a);if not payload then return nil,errorText end
        return plan('replace',a,c,lease,payload)
    end
    function service:PlanDelete(a,c,expected)
        local allowed,reason=target(a,c);if not allowed then return nil,reason end
        local lease,problem=checkExpected(a,expected);if not lease then return nil,problem end
        return plan('delete',a,c,lease)
    end
    function service:PlanMove(a,destination,c,expected,replacement)
        local allowed,reason=target(a,c);if not allowed then return nil,reason end
        allowed,reason=target(destination,c);if not allowed then return nil,reason end
        if a.id~=destination.id or a.spec~=destination.spec or a.class~=destination.class or a.scope==destination.scope and a.owner==destination.owner then return nil,'invalid-move-destination' end
        local lease,problem=checkExpected(a,expected);if not lease then return nil,problem end
        if locate(destination)~=nil then return nil,'rotation-id-collision' end
        local payload,errorText=prepare(replacement or lease.baseline,destination);if not payload then return nil,errorText end
        return plan('move',a,c,lease,payload,destination)
    end
    local function legacyCapture(selection)
        local record,chain={},{}
        for kind,component in pairs(legacyKinds) do
            local map=state.legacy[kind];local rows=map and map[selection.spec];local value=rows and rows[selection.id]
            record[component]=value;chain[kind]={map or false,rows or false,value}
        end
        return {selection=copied(selection),record=record,baseline=copyRecord(record),chain=chain,roots=roots()}
    end
    local function legacyAlive(lease)
        if not sameRoots(lease.roots) then return false end
        local current=legacyCapture(lease.selection)
        if not equal(current.record,lease.baseline) then return false end
        for kind,chain in pairs(lease.chain) do for i=1,3 do if chain[i]~=current.chain[kind][i] then return false end end end
        return true
    end
    function service:PlanLegacyAdoption(selection,destination,c)
        if not fields(selection,{spec=true,id=true}) or not spec(selection.spec) or not text(selection.id,128) then return nil,'invalid-legacy-selection' end
        local allowed,reason=target(destination,c);if not allowed then return nil,reason end
        if selection.id~=destination.id or selection.spec~=destination.spec then return nil,'invalid-move-destination' end
        if locate(destination)~=nil then return nil,'rotation-id-collision' end
        local lease=legacyCapture(selection)
        if lease.record.body==nil then return nil,'unknown-rotation' end
        local payload,problem=prepare(lease.record,destination);if not payload then return nil,problem end
        return plan('adopt',destination,c,lease,payload,destination)
    end
    local function write(a,value)
        local root=a.scope=='class' and state.classes or state.characters
        local bucket=root[a.owner]
        if not bucket then bucket=a.scope=='class' and {} or {class=a.class,specs={}};root[a.owner]=bucket end
        local map=a.scope=='class' and bucket or bucket.specs
        local rows=map[a.spec];if not rows then rows={};map[a.spec]=rows end
        rows[a.id]=value
    end
    function service:Commit(public,c)
        local pending=plans[public];if not pending then return nil,'invalid-plan' end
        local destination=pending.destination or pending.address
        local allowed,reason=target(destination,c);if not allowed then return nil,reason end
        if pending.operation~='adopt' then
            allowed,reason=target(pending.address,c);if not allowed then return nil,reason end
        end
        if c.class~=pending.context.class or c.character~=pending.context.character then return nil,'foreign-owner' end
        if not sameRoots(pending.roots) then return nil,'stale-rotation-record' end
        if pending.source and not (pending.operation=='adopt' and legacyAlive(pending.source) or pending.operation~='adopt' and alive(pending.source)) then return nil,'stale-rotation-record' end
        if pending.operation=='create' or pending.operation=='move' or pending.operation=='adopt' then
            if locate(destination)~=nil then return nil,'rotation-id-collision' end
            if not alive(pending.target) then return nil,'stale-rotation-record' end
        end
        local payload
        if pending.record then payload,reason=prepare(pending.record,destination);if not payload then return nil,reason end end
        -- All checks and copies precede plain table assignments; no callbacks run.
        if pending.operation=='delete' then write(pending.address,nil)
        else
            write(destination,payload)
            if pending.operation=='move' then write(pending.address,nil)
            elseif pending.operation=='adopt' then
                for kind in pairs(legacyKinds) do local map=state.legacy[kind];local rows=map and map[pending.source.selection.spec];if rows then rows[pending.source.selection.id]=nil end end
            end
        end
        index=buildIndex();plans[public]=nil;return true,copied(destination)
    end
    return service
end
