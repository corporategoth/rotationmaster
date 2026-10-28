-- Closed continuation successor to its exact combined predecessor.
local rows = {}

do
    local before = ([[!local _,addon=...
local data=addon.RotationData
local isClass=data.IsRotationClassToken
local components={'body','origin','imported','comparison'}
local addressFields={scope=true,class=true,owner=true,spec=true,id=true}
local stateFields={version=true,classes=true,characters=true,legacy=true}
local recordFields={body=true,origin=true,imported=true,comparison=true}
local characterBucketFields={class=true,specs=true}
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
    return fields(a,addressFields) and isClass(a.class) and spec(a.spec) and text(a.id,128)
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
    if not fields(record,recordFields) or not plain(record.body) or not data.CheckPortable(record.body)
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
    if comparison and (not fields(comparison,{kind=true,id=true,origins=true,sourceAddress=true}) or comparison.kind~='custom' and comparison.kind~='builtin'
        or not text(comparison.id,128) or not originMap(comparison.origins)
        or comparison.sourceAddress~=nil and (comparison.kind~='custom' or not validAddress(comparison.sourceAddress) or comparison.sourceAddress.id~=comparison.id)) then return nil,'invalid-record' end
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
    if not fields(state,stateFields) or state.version~=1 or not plain(state.classes) or not plain(state.characters) then return nil,'invalid-store' end
    for class,map in pairs(state.classes) do
        if not isClass(class) then return nil,'invalid-store' end
        local ok,why=validSpecMap(map,function(record,id,number) return validRecord(record,{id=id,class=class,spec=number}) end)
        if not ok then return nil,why end
    end
    for owner,bucket in pairs(state.characters) do
        if not text(owner,512) or not fields(bucket,characterBucketFields) or not isClass(bucket.class) then return nil,'invalid-store' end
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
    if not plain(options) or options.bindInternalReader~=nil and type(options.bindInternalReader)~='function' then return nil,'invalid-store-options' end
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
    local function readRows(a,c,source)
        source=source or index
        if not validAddress(a) then return nil,'invalid-address' end
        local allowed,reason=visible(a,c);if not allowed then return nil,reason end
        if not fields(state,stateFields) or state.version~=1
            or not plain(state.classes) or not plain(state.characters) or not plain(state.legacy) then return nil,'invalid-store' end
        if not sameRoots(source.roots) then return nil,'stale-store-index' end
        local root=a.scope=='class' and state.classes or state.characters
        local indexed=(a.scope=='class' and source.classes or source.characters)[a.owner]
        local bucket=root[a.owner]
        if bucket~=nil and not plain(bucket) then return nil,'invalid-store' end
        if a.scope=='character' and bucket and bucket.class~=a.class then return nil,'foreign-owner' end
        if bucket~=(indexed and indexed.bucket) then return nil,'stale-store-index' end
        if not indexed then return true end
        if a.scope=='character' and bucket.class~=indexed.class then return nil,'stale-store-index' end
        if a.scope=='character' and not fields(bucket,characterBucketFields) then return nil,'invalid-store' end
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
    -- This capability is bound only to trusted facade code. Canonical borrows
    -- must not escape its synchronous projectors; UI keeps snapshot APIs.
    local reader,readerState,readerBusy={},'binding',false
    local readIndex,readEpoch,readRevision=nil,0,0
    local publicationWriteVersion=0
    local readSeals=setmetatable({},{__mode='k'})
    local nilCharacter={}
    local function detachedAddress(a)
        return {scope=a.scope,class=a.class,owner=a.owner,spec=a.spec,id=a.id}
    end
    local function contextCopy(c) return {class=c.class,character=c.character} end
    local function privateContext(c) return plain(c) and isClass(c.class) and (c.character==nil or text(c.character,512)) end
    local function sameContext(a,c) return plain(c) and a.class==c.class and a.character==c.character end
    local function readerReady(checkBusy)
        if readerState=='retired' then return nil,'retired-rotation-reader' end
        if readerState~='active' then return nil,'rotation-reader-not-ready' end
        if checkBusy and readerBusy then return nil,'reentrant-rotation-read' end
        return true
    end
    local function recordMetadata(a,record)
        readRevision=readRevision+1
        local _,chain=locate(a);local payload={}
        for _,component in ipairs(components) do payload[component]=record[component] end
        return {address=detachedAddress(a),record=record,chain=chain,payload=payload,revision=readRevision,
            seals=setmetatable({},{__mode='v'})}
    end
    local function resetReaderIndex()
        local replacement=buildIndex()
        local function add(kind,name,owner)
            for number,scope in pairs(owner.specs) do
                scope.metadata={}
                for id,record in pairs(scope.records) do
                    scope.metadata[id]=recordMetadata({scope=kind,class=kind=='class' and name or owner.class,owner=name,spec=number,id=id},record)
                end
            end
        end
        for name,owner in pairs(replacement.classes) do add('class',name,owner) end
        for name,owner in pairs(replacement.characters) do add('character',name,owner) end
        readIndex=replacement;readEpoch=readEpoch+1
    end
    -- Update only addresses actually written by this service. Rebuilding from
    -- raw state would accidentally bless external component/container changes.
    local function advanceReaderAddress(a)
        local root=a.scope=='class' and state.classes or state.characters
        local owners=a.scope=='class' and readIndex.classes or readIndex.characters
        local bucket=root[a.owner];local map=a.scope=='class' and bucket or bucket.specs
        local owner=owners[a.owner]
        if not owner then owner={bucket=bucket,map=map,specs={},class=a.scope=='character' and bucket.class or nil};owners[a.owner]=owner end
        local rows=map[a.spec];local scope=owner.specs[a.spec]
        if not scope then scope={rows=rows,records={},metadata={},count=0};owner.specs[a.spec]=scope end
        local record=rows[a.id];local previous=scope.records[a.id]
        if previous==nil and record~=nil then scope.count=scope.count+1 elseif previous~=nil and record==nil then scope.count=scope.count-1 end
        scope.records[a.id]=record;scope.metadata[a.id]=record and recordMetadata(a,record) or nil
    end
    local function privateRecord(a,c)
        local allowed,rows,scope=readRows(a,c,readIndex);if not allowed then return nil,rows end
        local record=rows and rows[a.id]
        if record~=(scope and scope.records[a.id]) then return nil,'stale-store-index' end
        if not record then return nil,'unknown-rotation' end
        local meta=scope.metadata[a.id]
        if not fields(record,recordFields) or not plain(record.body) then return nil,'invalid-record' end
        local _,chain=locate(a)
        for i=1,4 do if chain[i]~=meta.chain[i] then return nil,'stale-store-index' end end
        for _,component in ipairs(components) do
            if record[component]~=meta.payload[component] then return nil,'stale-store-index' end
            if record[component]~=nil and not plain(record[component]) then return nil,'invalid-record' end
        end
        return meta
    end
    local function recordSeal(meta,c)
        local key=c.character;if key==nil then key=nilCharacter end
        local seal=meta.seals[key]
        if not seal then
            seal={};meta.seals[key]=seal
            readSeals[seal]={kind='record',epoch=readEpoch,meta=meta,context=contextCopy(c)}
        end
        return seal
    end
    local function privateRows(number,c)
        if not spec(number) then return nil,'invalid-specialization' end
        if not privateContext(c) then return nil,'missing-owner-context' end
        local result={}
        local function add(kind,name)
            local a={scope=kind,class=c.class,owner=name,spec=number,id=options.fallbackID}
            local allowed,rows,scope=readRows(a,c,readIndex);if not allowed then return nil,rows end
            local count=0
            for id,record in pairs(rows or {}) do
                if not text(id,128) or scope.records[id]~=record then return nil,'stale-store-index' end
                a.id=id;local meta,reason=privateRecord(a,c);if not meta then return nil,reason end
                count=count+1;result[#result+1]=meta
            end
            if count~=(scope and scope.count or 0) then return nil,'stale-store-index' end
            return true
        end
        local allowed,reason=add('class',c.class);if not allowed then return nil,reason end
        local character=type(c.character)=='string' and state.characters[c.character]
        if character~=nil and character~=false and not plain(character) then return nil,'invalid-store' end
        if not character or character.class==c.class then
            if text(c.character,512) then allowed,reason=add('character',c.character);if not allowed then return nil,reason end end
        end
        table.sort(result,function(a,b) local x,y=a.address,b.address
            if x.scope~=y.scope then return x.scope<y.scope end;return x.id<y.id
        end)
        return result
    end
    function reader:IsCurrent(seal,c)
        local ready,reason=readerReady();if not ready then return nil,reason end
        local entry=readSeals[seal];if not entry then return nil,'invalid-rotation-read-seal' end
        if not privateContext(c) then return nil,'missing-owner-context' end
        if not sameContext(entry.context,c) then return nil,'foreign-owner' end
        if entry.epoch~=readEpoch then return nil,'stale-rotation-read-seal' end
        if entry.kind=='record' then
            local meta=privateRecord(entry.meta.address,c)
            if meta~=entry.meta then return nil,'stale-rotation-read-seal' end
        else
            local current=privateRows(entry.spec,c)
            if not current or #current~=#entry.items then return nil,'stale-rotation-read-seal' end
            for i,meta in ipairs(current) do if meta~=entry.items[i] then return nil,'stale-rotation-read-seal' end end
        end
        return true
    end
    local ownedReaderIsCurrent=reader.IsCurrent
    -- Only an owned factory admission may consume this private capability.
    local guardType,guardPairs,guardGetmetatable,guardRawget=type,pairs,getmetatable,rawget
    local function makePublicationGuard(_,seal,c)
        local entry=readSeals[seal]
        if not entry or entry.kind~='record' then return nil end
        local meta=entry.meta;local a=meta.address;c=c or entry.context
        local owners=a.scope=='class' and readIndex.classes or readIndex.characters
        local owner=owners[a.owner];local scope=owner and owner.specs[a.spec]
        local epoch,writeVersion=entry.epoch,publicationWriteVersion
        local expectedRoots=readIndex.roots;local chain=meta.chain
        local record,payload=meta.record,meta.payload
        return function()
            if reader.IsCurrent~=ownedReaderIsCurrent or type~=guardType or pairs~=guardPairs
                or getmetatable~=guardGetmetatable or rawget~=guardRawget then return nil end
            -- Preserve public-reader admission and its actual string receivers.
            if readerState~='active' then return false end
            if not privateContext(c) or not sameContext(entry.context,c) then return false end
            if readEpoch~=epoch then return false end
            if not validAddress(a) or not visible(a,c) then return false end
            if readerState~='active' or readEpoch~=epoch or publicationWriteVersion~=writeVersion
                or not scope or scope.metadata[a.id]~=meta then return false end
            -- Preserve all raw state/header/container/component witnesses checked
            -- by readRows/privateRecord, without allocating a locate chain or
            -- repeating plain checks of the same class map/body.
            if not fields(state,stateFields) or state.version~=1 then return false end
            local classes,characters,legacy=state.classes,state.characters,state.legacy
            if classes~=expectedRoots[1] or characters~=expectedRoots[2] or legacy~=expectedRoots[3]
                or not plain(classes) or not plain(characters) or not plain(legacy) then return false end
            local root=a.scope=='class' and classes or characters
            if root~=chain[1] then return false end
            local bucket=root[a.owner]
            if bucket~=chain[2] or not plain(bucket) then return false end
            local map=bucket
            if a.scope=='character' then
                if bucket.class~=a.class or bucket.class~=owner.class or not fields(bucket,characterBucketFields) then return false end
                map=bucket.specs
                if not plain(map) then return false end
            end
            if map~=chain[3] then return false end
            local rows=map[a.spec]
            if rows~=chain[4] or not plain(rows) or rows[a.id]~=record then return false end
            if not fields(record,recordFields) then return false end
            for _,component in ipairs(components) do
                local value=record[component]
                if value~=payload[component] or value~=nil and not plain(value) then return false end
            end
            return true
        end
    end
    function reader:ListOwned(number,c)
        local ready,reason=readerReady(true);if not ready then return nil,reason end
        local items,problem=privateRows(number,c);if not items then return nil,problem end
        local rows={}
        for _,meta in ipairs(items) do rows[#rows+1]={address=detachedAddress(meta.address),seal=recordSeal(meta,c)} end
        local seal={};readSeals[seal]={kind='list',epoch=readEpoch,spec=number,items=items,context=contextCopy(c)}
        return rows,seal
    end
    function reader:Read(a,c,project)
        local ready,reason=readerReady(true);if not ready then return nil,reason end
        if coroutine.running()~=nil then return nil,'invalid-rotation-read-context' end
        if type(project)~='function' then return nil,'invalid-rotation-read-callback' end
        -- Validate before copying the small address/context; never copy payload.
        if not validAddress(a) then return nil,'invalid-address' end
        if not privateContext(c) then return nil,'missing-owner-context' end
        local allowed,problem=visible(a,c);if not allowed then return nil,problem end
        local address,context=detachedAddress(a),contextCopy(c)
        local meta,errorText=privateRecord(address,context);if not meta then return nil,errorText end
        local seal=recordSeal(meta,context)
        readerBusy=true;local ok,value=pcall(project,meta.record,seal);readerBusy=false
        if not ok then return nil,'rotation-read-callback-failed' end
        if not sameContext(context,c) then return nil,'rotation-read-context-changed' end
        ready,reason=self:IsCurrent(seal,context);if not ready then return nil,reason end
        return true,value,seal
    end
    function reader:Retire() readerState='retired';return true end
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
        if readIndex then resetReaderIndex() end
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
        local advanceDestination,advanceSource
        if readIndex then
            advanceDestination=readRows(destination,c,readIndex)
            if pending.operation=='move' then advanceSource=readRows(pending.address,c,readIndex) end
        end
        -- A successful write with an unadvanceable stale
        -- index must retire private publication witnesses, without blessing it
        -- or changing public unrelated-record seal semantics.
        if readIndex and (not advanceDestination or pending.operation=='move' and not advanceSource) then
            publicationWriteVersion=publicationWriteVersion+1
        end
        -- All checks and copies precede plain table assignments; no callbacks run.
        if pending.operation=='delete' then write(pending.address,nil)
        else
            write(destination,payload)
            if pending.operation=='move' then write(pending.address,nil)
            elseif pending.operation=='adopt' then
                for kind in pairs(legacyKinds) do local map=state.legacy[kind];local rows=map and map[pending.source.selection.spec];if rows then rows[pending.source.selection.id]=nil end end
            end
        end
        index=buildIndex()
        if advanceDestination then advanceReaderAddress(destination) end
        if advanceSource then advanceReaderAddress(pending.address) end
        plans[public]=nil;return true,copied(destination)
    end
    if options.bindInternalReader then
        local bound=pcall(options.bindInternalReader,reader)
        if not bound then readerState='retired';return nil,'internal-reader-bind-failed' end
        if readerState=='retired' then return nil,'retired-rotation-reader' end
        local valid,reason=validState(state)
        if not valid then readerState='retired';return nil,reason end
        index=buildIndex();resetReaderIndex();readerState='active'
    end
    -- Keep this capability out of the mutable reader callback transport.
    return service,nil,makePublicationGuard
end
local ownedRotationStoreFactory=data.NewRotationStore
local storeFactoryEnvironment=type(getfenv)=='function' and getfenv(1) or nil
function data.BindOwnedRotationStoreFactory(bind)
    if type(bind)=='function' then bind(ownedRotationStoreFactory,storeFactoryEnvironment) end
end

-- BEGIN CPU RUNTIME WORK HANDOFF
do
 local bind=addon.BindCPURuntimeWorkDiagnostic
 if type(bind)=='function' then bind(addon,'store',data.NewRotationStore,function() return plain,fields,validAddress end) end
end
-- END CPU RUNTIME WORK HANDOFF
]]):sub(2)

    local after = before

    after = after:sub(1, 26805)
        .. ([[!        -- Configuration was admitted by fullCurrent. Between real callouts,
        -- use raw identity/epoch witnesses only; never invoke extension code.
        local function continuationCurrent()
            if readerState~='active' or readEpoch~=epoch or publicationWriteVersion~=writeVersion
                or not scope or scope.metadata[a.id]~=meta then return false end
            if guardRawget(state,'version')~=1 or guardRawget(state,'classes')~=expectedRoots[1]
                or guardRawget(state,'characters')~=expectedRoots[2] or guardRawget(state,'legacy')~=expectedRoots[3] then return false end
            if guardRawget(chain[1],a.owner)~=chain[2] then return false end
            if a.scope=='character' and (guardRawget(chain[2],'class')~=a.class or guardRawget(chain[2],'specs')~=chain[3]) then return false end
            if guardRawget(chain[3],a.spec)~=chain[4] or guardRawget(chain[4],a.id)~=record then return false end
            for index=1,#components do
                local component=components[index]
                if guardRawget(record,component)~=payload[component] then return false end
            end
            return true
        end
        return fullCurrent,continuationCurrent
]]):sub(2)
        .. after:sub(26806)

    after = after:sub(1, 24392)
        .. ([[!        local function fullCurrent()
]]):sub(2)
        .. after:sub(24419)

    rows["Data/rotation_store.lua"] = { before = before, after = after }
end

do
    local before = ([[!local addon_name,addon=...
local data=addon.RotationData
local ownedStoreFactory,ownedStoreEnvironment
local bindOwnedStoreFactory=data.BindOwnedRotationStoreFactory
if type(bindOwnedStoreFactory)=='function' then
    bindOwnedStoreFactory(function(factory,environment) ownedStoreFactory,ownedStoreEnvironment=factory,environment end)
    data.BindOwnedRotationStoreFactory=nil
end
---@type fun(f: number|function): table
local storeGetfenv=getfenv
local storeScopeEnvironment=type(storeGetfenv)=='function' and storeGetfenv(1) or nil
-- These public helpers receive the execution body/path in the default sequence.
-- Unknown helpers keep the public RuntimePass route before private data escapes.
local planIndex,planCopy,planPortable,planIpairs=data.IndexRotationSteps,data.CopyData,data.CheckPortable,ipairs
local function planDataCurrent(owner)
    return rawget(storeScopeEnvironment,'ipairs')==planIpairs and rawget(owner,'RotationData')==data and rawget(data,'IndexRotationSteps')==planIndex
        and rawget(data,'CopyData')==planCopy and rawget(data,'CheckPortable')==planPortable
        and storeGetfenv(planIndex)==storeScopeEnvironment and storeGetfenv(planCopy)==storeScopeEnvironment
        and storeGetfenv(planPortable)==storeScopeEnvironment
end
local prepareChoicePublication,finishChoicePublication
local consumeChoices=addon.ConsumeRotationChoicePublication
if type(consumeChoices)=='function' then
    prepareChoicePublication,finishChoicePublication=consumeChoices(addon)
    addon.ConsumeRotationChoicePublication=nil
end
local invalidateChoiceContext=addon.InvalidateRotationChoiceContext
local prepareActivePublication,finishActivePublication,prepareActiveRebind,finishActiveRebind,readActiveRuntime,copyActiveRuntime
local activeCurrent=addon.IsActiveRotationTransitionCurrent
local protect,raise=pcall,error
local preparedBinding,bindGeneration
local bindIdentity=rawequal
if type(addon.BindActiveRotationPublication)=='function' then
    addon:BindActiveRotationPublication(function(prepare,finish,rebind,complete,readRuntime,copyRuntime)
        prepareActivePublication,finishActivePublication,prepareActiveRebind,finishActiveRebind=prepare,finish,rebind,complete
        readActiveRuntime,copyActiveRuntime=readRuntime,copyRuntime
    end)
end
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local libraryReader,libraryGenerationProof,libraryContextProof,libraryRuntimeContextGuard
local runtimeAuthority,planEligible,ownedRuntimeContext,ownedRuntimeReadValue,readLibraryRuntime
local currentPlanSource,ownedAcquireRuntimePass
local evaluationRequest,contextVersion
local privatePlanPass={}
contextVersion={}
local ownedRuntimePasses=setmetatable({},{__mode="kv"})
local bindLibrary=addon.BindRotationLibraryReader
if type(bindLibrary)=='function' then
    bindLibrary(addon,function(reader,proof,contextProof,runtimeGuard,authority,eligible,contextMethod,readValue,generation) runtimeAuthority,planEligible,ownedRuntimeContext,ownedRuntimeReadValue,readLibraryRuntime=authority,eligible,contextMethod,readValue,generation;libraryRuntimeContextGuard=runtimeGuard;libraryReader=reader;if type(proof)=='function' then libraryGenerationProof=proof end;if type(contextProof)=='function'then libraryContextProof=contextProof end end)
    addon.BindRotationLibraryReader=nil
end
local function rotationContext(owner,spec)
    local method=libraryReader and libraryReader.Context
    if type(method)=='function' then local value,private=method(libraryReader,spec);return value,private,method end
    local fallback=owner.GetRotationContext
    local value=fallback(owner,spec);return value,false
end
local current,serial
serial=0
-- Exposure survives explicit Refresh/rebinding while that canonical body lives.
local exposed=setmetatable({},{__mode='k'})
local exposureVersion={}
local function plain(v) return type(v)=='table' and getmetatable(v)==nil end
local function text(v,n) return type(v)=='string' and #v>0 and #v<=n and v:find('%S')~=nil and not v:find('[%z\1-\31\127]') end
local function copy(v) return data.CopyData(v) end
local function metadataView(value)
    if not plain(value) then return nil end
    local result={};for _,key in ipairs({'author','realm','email','website','version'}) do if type(value[key])=='string' then result[key]=value[key] end end;return result
end
local function tagsView(value)
    if value==nil then return nil end
    return data.NormalizeRotationTags(value) or false
end
local function same(a,b)
    if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function addressKey(a) return a.scope..'\0'..a.class..'\0'..a.owner..'\0'..a.spec..'\0'..a.id end
local function validSpec(v) return type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
local function customReference(r)
    if not plain(r) or r.kind~='custom' or not plain(r.address) then return false end
    for key in pairs(r) do if key~='kind' and key~='address' then return false end end
    for key in pairs(r.address) do if key~='scope' and key~='class' and key~='owner' and key~='spec' and key~='id' then return false end end
    local a=r.address
    return (a.scope=='class' or a.scope=='character') and data.IsRotationClassToken(a.class) and text(a.owner,512) and validSpec(a.spec) and text(a.id,128) and (a.scope~='class' or a.owner==a.class)
end
local function copyRecord(r) local out={} for _,k in ipairs({'body','origin','imported','comparison'}) do if r[k]~=nil then out[k]=copy(r[k]) end end return out end
local function referenceKey(r) return r.kind=='builtin' and 'builtin\0'..r.id or 'custom\0'..addressKey(r.address) end
function addon:GetRotationOwnerContext()
    local class
    local platform=self.Platform
    if libraryReader and type(libraryReader.OwnsContext)=='function' and libraryReader:OwnsContext(self.GetRotationContext)
        and type(platform)=='table' and type(platform.GetPlayerOwnerClassObservation)=='function' then
        class=platform:GetPlayerOwnerClassObservation()
    else
        local context=self:GetRotationContext(self.currentSpec)
        class=context and context.class
    end
    if not data.IsRotationClassToken(class) then return nil,'missing-owner-context' end
    local character=self.db.keys and self.db.keys.char
    if not text(character,512) then character=nil end
    return {class=class,character=character}
end
local ownedOwnerContext=addon.GetRotationOwnerContext
function addon:GetScopedRotationCoordinator()
    -- Once scoped mode is bound, a profile transition must fail closed until
    -- the explicit event handler rebinds it; never reopen the old flat adapter.
    return current
end
local ownedScopedCoordinator=addon.GetScopedRotationCoordinator
local function rebindContext()
    if not prepareActiveRebind then return nil end
    local ticket,reference,token,spec,id=prepareActiveRebind(DEFAULT)
    if not token then return nil end
    return {ticket=ticket,reference=reference,token=token,spec=spec,id=id}
end
local function completeRebind(binding,coordinator,problem)
    if not binding or not binding.ticket or not activeCurrent(addon,binding.token) then return end
    local function read(object,name,...)
        if not activeCurrent(addon,binding.token) then return nil end
        local method=object[name]
        if not activeCurrent(addon,binding.token) then return nil end
        local value=method(object,...)
        if not activeCurrent(addon,binding.token) then return nil end
        return value
    end
    local function resolve()
        if problem then return nil end
        local key=binding.id
        if key~=DEFAULT then
            if not binding.reference then return nil end
            local reference=read(coordinator,'Resolve',binding.spec,binding.reference)
            if not reference then return nil end
            key=read(coordinator,'Key',reference)
        end
        if not key then return nil end
        local reference=read(coordinator,'Resolve',binding.spec,key)
        local pass
        local sourcePass=ownedRuntimePasses[coordinator]
        if reference and rawget(coordinator,'RuntimePass')==sourcePass then
            if not activeCurrent(addon,binding.token) then return nil end
            pass=sourcePass(coordinator,binding.spec,privatePlanPass)
            if not activeCurrent(addon,binding.token) then return nil end
        elseif reference then pass=read(coordinator,'RuntimePass',binding.spec) end
        local body=pass and read(pass,'Get',key)
        return key,reference,body
    end
    local ok,key,reference,body=protect(resolve)
    if not activeCurrent(addon,binding.token) then return end
    local handle,token=finishActiveRebind(binding.ticket,ok and key or nil,ok and reference or nil,ok and body or nil)
    if not handle and token and activeCurrent(addon,token) then addon.manualRotation=false end
end
local function runPreparedBind(owner,binding,method)
    local previous=preparedBinding;preparedBinding=binding
    local ok,result,reason=protect(method,owner)
    if preparedBinding==binding then preparedBinding=previous end
    if not ok then raise(result,0) end
    return result,reason
end
function addon:BindActiveRotationProfileRebind(receiver)
    if self~=addon or type(receiver)~='function' then return nil end
    receiver(rebindContext,runPreparedBind)
    return true
end
function addon:BindRotationProfile()
    if invalidateChoiceContext then invalidateChoiceContext(addon) end
    local bindToken={};bindGeneration=bindToken
    local binding,profile
    local function bindingCurrent()
        if bindGeneration~=bindToken or binding and not activeCurrent(self,binding.token) then return false end
        if profile then local db=self.db;if not bindIdentity(db and db.profile,profile) then return false end end
        return bindGeneration==bindToken
    end
    if self==addon then
        binding=preparedBinding or rebindContext()
        if binding then
            if binding.used or not bindingCurrent() then return nil,'rotation-transition-superseded' end
            binding.used=true
        end
    end
    if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    local previous=current
    if previous then
        local retire=previous.Retire
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        retire(previous)
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    end
    local owner=self;profile=self.db.profile;local state=profile.rotationStore;local fallbackID=profile.rotationFallbackID
    local reader,store,problem,ownedPublicationGuard;local alive=true;local managedStoreReader=false
    if not libraryReader then problem='rotation-library-not-ready'
    elseif not text(profile.rotationFallbackID,128) then problem='missing-fallback-configuration'
    else
        local construct=data.NewRotationStore
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        local getOptions=self.GetRotationValidationOptions
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        local validation=getOptions(self)
        if not bindingCurrent() then return nil,'rotation-transition-superseded' end
        store,problem,ownedPublicationGuard=construct({state=state,fallbackID=profile.rotationFallbackID,validation=validation,bindInternalReader=function(value) reader=value end})
        managedStoreReader=construct==ownedStoreFactory and ownedStoreEnvironment~=nil
            and type(storeGetfenv)=='function' and getfenv==storeGetfenv and storeGetfenv(construct)==ownedStoreEnvironment
    end
    if not bindingCurrent() then return nil,'rotation-transition-superseded' end
    local coordinator={};current=coordinator
    local rosterStamp,rosterOwned,rosterLibrary,rosterValidation,rosterVirtual,rosterBuiltin
    local byKey,byReference,expected,pending,assets,headers,cleanup={},{},setmetatable({},{__mode='k'}),{},{},{},{}
    local function context() return owner:GetRotationOwnerContext() end
    local function ready()
        if not alive or owner.db.profile~=profile or profile.rotationStore~=state or profile.rotationFallbackID~=fallbackID then return nil,'rotation-profile-changed' end
        if problem then return nil,problem end
        return true
    end
    local function keyFor(reference)
        local index=referenceKey(reference);local key=byReference[index]
        if not key then serial=serial+1;key=string.char(1)..'rm:rotation:'..serial;byReference[index]=key;byKey[key]=copy(reference) end
        return key
    end
    local function validateReference(reference,number)
        if plain(reference) and reference.kind=='builtin' and text(reference.id,128) then
            local ok,why=libraryReader:Read(number,reference.id,function() return true end)
            if not ok then return nil,why end;return {kind='builtin',id=reference.id}
        end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;local c,contextReason=context();if not c then return nil,contextReason end
        if c.class~=a.class or a.scope=='character' and c.character~=a.owner then return nil,'foreign-owner' end
        if a.spec~=number then return nil,'invalid-specialization' end
        -- The private store performs the complete typed address/class gate.
        local ok,reason=reader:Read(a,c,function() return true end)
        if not ok then return nil,reason end
        return copy(reference)
    end
    local function fallbackReference(number)
        local c,why=context();if not c or not c.character then return nil,why or 'missing-owner-context' end
        for _,scope in ipairs({'character','class'}) do
            local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=profile.rotationFallbackID}}
            local ok,reason=reader:Read(reference.address,c,function() return true end)
            if ok then return reference end
            if reason~='unknown-rotation' then return nil,reason end
        end
        return nil,'unknown-rotation'
    end
    function coordinator:CheckReady() return ready() end
    function coordinator:OwnsProfile(value) return value==profile end
    function coordinator:Retire() alive=false;if reader then reader:Retire() end;return true end
    function coordinator:Resolve(number,value)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ownerContext,ownerReason=context();if not ownerContext then return nil,ownerReason end
        if type(value)=='table' then
            if value.kind=='builtin' then return validateReference(value,number) end
            if customReference(value) then
                local p=pending[referenceKey(value)];if p then return self:PendingReference(number,p.reference) end
                return validateReference(value,number)
            end
            return nil,'invalid-rotation-reference'
        end
        if type(value)~='string' then return nil,'invalid-rotation-reference' end
        if byKey[value] then
            local reference=byKey[value];if pending[referenceKey(reference)] then return self:PendingReference(number,reference) end
            return validateReference(reference,number)
        end
        if value==DEFAULT then return fallbackReference(number) end
        local c,errorText=context();if not c then return nil,errorText end
        local rows,reason=reader:ListOwned(number,c);if not rows then return nil,reason end
        local found
        for _,row in ipairs(rows) do if row.address.id==value then
            if found then return nil,'ambiguous-rotation-reference' end
            found={kind='custom',address=row.address}
        end end
        return found or nil,not found and 'unknown-rotation' or nil
    end
    function coordinator:PendingReference(number,r)
        local c,contextReason=context();if not c then return nil,contextReason end
        local a=r.address;if a.spec~=number then return nil,'invalid-specialization' end
        if a.class~=c.class or a.scope=='character' and a.owner~=c.character then return nil,'foreign-owner' end
        return copy(r)
    end
    function coordinator:Key(reference) return keyFor(reference) end
    function coordinator:IsPending(reference) return customReference(reference) and pending[referenceKey(reference)]~=nil end
    function coordinator:StagePending(reference,scope)
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local initial=referenceKey(reference);local draft=pending[initial];if not draft then return nil,'unknown-rotation' end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target=copy(reference);target.address.scope=scope;target.address.owner=scope=='class' and c.class or c.character
        local index=referenceKey(target)
        -- A staged collision must not steal the existing owner's issued key.
        if byReference[index] and byReference[index]~=draft.key then return copy(target) end
        if draft.alias and draft.alias~=initial and draft.alias~=index then pending[draft.alias]=nil;byReference[draft.alias]=nil end
        draft.alias=index;draft.reference=target;pending[index]=draft;byReference[index]=draft.key;byKey[draft.key]=copy(target)
        return copy(target)
    end
    function coordinator:TokenCurrent(token)
        local issued=expected[token];if not issued or not ready() then return false end
        local c=context();if not c or not same(c,issued.context) then return false end
        local ok,value=reader:Read(issued.reference.address,c,function(record,seal)
            if seal~=issued.seal then return false end
            for _,key in ipairs({'body','origin','imported','comparison'}) do if not data.CheckPortable(record[key]) or not same(record[key],issued.baseline[key]) then return false end end
            return true
        end)
        return ok and value==true
    end
    function coordinator:Snapshot(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then
            local ok,record=libraryReader:Read(number,reference.id,function(view,body) return {body=copy(body),source=copy(view)} end)
            if not ok then return nil,record end;return record,nil,record.source.validation
        end
        local c,errorText=context();if not c then return nil,errorText end
        local record,token=store:Get(reference.address,c);if not record then return nil,token end
        local _,_,seal=reader:Read(reference.address,c,function() return true end)
        local public={};expected[public]={reference=copy(reference),token=token,context=c,seal=seal,baseline=copyRecord(record)}
        return record,public,data.ValidateBody(record.body,owner:GetRotationValidationOptions())
    end
    function coordinator:NewDraft(number,scope,fallback)
        if not validSpec(number) then return nil,'invalid-specialization' end
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        scope=scope or 'class';if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local id=profile.rotationFallbackID
        if not fallback then
            local used={};if libraryReader then libraryReader:Reserve(used) end;local rows,errorText=store:AllStored();if not rows then return nil,errorText end
            for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
            for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
            for _=1,100 do local success,candidate=pcall(owner.uuid);if success and text(candidate,128) and not used[candidate] and candidate~=profile.rotationFallbackID then id=candidate;break end;id=nil end
            if not id then return nil,'id-allocation-exhausted' end
        end
        local reference={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local previous=pending[referenceKey(reference)];if previous then local resolved,pendingReason=self:PendingReference(number,previous.reference);if not resolved then return nil,pendingReason end;return resolved,previous.key end
        local exists,lookupReason=reader:Read(reference.address,c,function() return true end)
        if exists then return nil,'rotation-id-collision' end;if lookupReason~='unknown-rotation' then return nil,lookupReason end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key}
        return copy(reference),key
    end
    function coordinator:LegacyDraft(number,id)
        local ok,why=ready();if not ok then return nil,why end
        if not validSpec(number) or not text(id,128) then return nil,'invalid-rotation-target' end
        if id==DEFAULT then return self:NewDraft(number,'class',true) end
        local c,contextReason=context();if not c then return nil,contextReason end
        local reference={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=id}}
        local draft=pending[referenceKey(reference)];if draft then local resolved,pendingReason=self:PendingReference(number,draft.reference);if not resolved then return nil,pendingReason end;return resolved,draft.key end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local used={};if libraryReader then libraryReader:Reserve(used) end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do data.ReserveRotationIdentities(component,used) end end
        if used[id] then return nil,'unknown-rotation' end
        local key=keyFor(reference);pending[referenceKey(reference)]={reference=copy(reference),key=key};return reference,key
    end
    function coordinator:Commit(reference,token,record,scope,revisionPolicy)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        if not customReference(reference) then return nil,'invalid-rotation-reference' end
        local a=reference.address;scope=scope or a.scope
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local destination=copy(a);destination.scope=scope;destination.owner=scope=='class' and c.class or c.character
        local issued=token and expected[token];local plan,reason
        if revisionPolicy~=nil and revisionPolicy~='import' then return nil,'invalid-rotation-revision-policy' end
        if not plain(record) then return nil,'invalid-record' end
        if token and (not issued or not same(issued.reference,reference) or not same(issued.context,c)) then return nil,'stale-rotation-record' end
        local previousKey=byReference[referenceKey(reference)]
        local moved=a.scope~=destination.scope or a.owner~=destination.owner
        local previous
        if issued then
            -- Compare the editor's existing empty-list normalization on a
            -- detached public snapshot; keep the issued authority seal exact.
            local snapshot,snapshotProblem=store:Get(a,c)
            if not snapshot then return nil,snapshotProblem end
            previous=snapshot.body
            if plain(previous) and plain(record.body) then
                if previous.rotation==nil and record.body.rotation~=nil then previous.rotation={} end
                if previous.cooldowns==nil and record.body.cooldowns~=nil then previous.cooldowns={} end
            end
        end
        local body,problem=data.PrepareRotationContentRevision(record.body,previous,
            token and 'edit' or revisionPolicy=='import' and 'import' or 'create',moved or revisionPolicy=='import')
        if not body then return nil,problem end
        local detached=copy(record);if not detached then return nil,'invalid-record' end
        record=detached;record.body=body
        local target={kind='custom',address=destination}
        local fallbackKey=destination.id==profile.rotationFallbackID and DEFAULT or nil
        local publication=prepareActivePublication and prepareActivePublication(a.spec,previousKey,reference,target,body,nil,fallbackKey)
        local choicePublication=prepareChoicePublication and prepareChoicePublication(profile,reference,target)
        local now,contextProblem=context()
        local readyNow,currentProblem=ready();if not readyNow then return nil,currentProblem end
        if not now then return nil,contextProblem end
        if not same(now,c) then return nil,'rotation-owner-changed' end
        if token then
            if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
            if a.scope~=destination.scope or a.owner~=destination.owner then plan,reason=store:PlanMove(a,destination,c,issued.token,record)
            else plan,reason=store:PlanReplace(a,record,c,issued.token) end
        else plan,reason=store:PlanCreate(destination,record,c) end
        if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        if finishChoicePublication then finishChoicePublication(choicePublication,alive and current==coordinator) end
        if token then expected[token]=nil end
        local oldIndex=referenceKey(reference);local targetIndex=referenceKey(target)
        local draft=pending[oldIndex]
        if draft then
            for index,value in pairs(pending) do if value==draft then pending[index]=nil;if index~=targetIndex then byReference[index]=nil end end end
            byReference[targetIndex]=draft.key;byKey[draft.key]=copy(target)
        elseif oldIndex~=targetIndex then
            local oldKey=byReference[oldIndex];if oldKey then cleanup[oldKey]=assets[oldIndex] and assets[oldIndex].body;byKey[oldKey]=nil;byReference[oldIndex]=nil end
        end
        local nextKey=keyFor(target)
        local transition
        if finishActivePublication then local _,change=finishActivePublication(publication,nextKey);transition=change end
        return target,nil,transition
    end
    function coordinator:Delete(reference,token)
        local ok,why=ready();if not ok then return nil,why end
        local c,errorText=context();if not c then return nil,errorText end
        local issued=expected[token]
        if not issued or not same(issued.reference,reference) or not same(issued.context,c) then return nil,'stale-rotation-record' end
        if reference.address.id==profile.rotationFallbackID then return nil,'read-only-rotation' end
        local choicePublication=prepareChoicePublication and prepareChoicePublication(profile,reference,nil)
        local plan,reason=store:PlanDelete(reference.address,c,issued.token);if not plan then return nil,reason end
        local committed,problemText=store:Commit(plan,c);if not committed then return nil,problemText end
        if finishChoicePublication then finishChoicePublication(choicePublication,alive and current==coordinator) end
        local index=referenceKey(reference);local key=byReference[index]
        if key then cleanup[key]=assets[index] and assets[index].body;byKey[key]=nil;byReference[index]=nil;headers[key]=nil end
        assets[index]=nil;expected[token]=nil
        return true
    end
    function coordinator:Cleanup(number,value,privateToken)
        if cleanup[value] then return cleanup[value] end
        local reference=type(value)=='string' and byKey[value]
        if reference and assets[referenceKey(reference)] then local asset=assets[referenceKey(reference)];if privateToken~=privatePlanPass then asset.borrowed=true end;return asset.body end
        local pass=self:RuntimePass(number,privateToken);return pass and pass:Get(value)
    end
    function coordinator:TagView(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then local ok,result=libraryReader:Read(number,reference.id,function(view) return {tags=copy(view.envelope.tags),sources=copy(view.envelope.sources),body={name=L[view.nameKey or reference.id]}} end);if not ok then return nil,result end;return result end
        local c=context();local ok,result=reader:Read(reference.address,c,function(record)
            local body=record.body;local retained=record.origin or record.imported;local manifest=retained and retained.manifest
            return {body={name=body.name,description=body.description,priority=body.priority,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
        end)
        if not ok then return nil,result end;return result
    end
    function coordinator:StoredRecords() local ok,why=ready();if not ok then return nil,why end;return store:AllStored() end
    function coordinator:Unassigned()
        local ok,why=ready();if not ok then return nil,why end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        local result={};for _,row in ipairs(rows) do if row.address.scope=='legacy' then result[#result+1]=row end end;return result
    end
    local adoptionPlans=setmetatable({},{__mode='k'})
    function coordinator:PlanAdoption(selection,scope)
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=selection.spec,id=selection.id}
        local plan,planReason=store:PlanLegacyAdoption({spec=selection.spec,id=selection.id},target,c);if not plan then return nil,planReason end
        local public={reference={kind='custom',address=copy(target)},selection=copy(selection),scope=scope}
        adoptionPlans[public]={plan=plan,context=c,target=target};return public
    end
    function coordinator:ApplyAdoption(public)
        local ok,why=ready();if not ok then return nil,why end
        local adoption=adoptionPlans[public];if not adoption then return nil,'invalid-adoption-plan' end
        local c,contextReason=context();if not c or not same(c,adoption.context) then return nil,contextReason or 'rotation-owner-changed' end
        local reference={kind='custom',address=copy(adoption.target)}
        local rows=profile.rotationStore.legacy.rotations[adoption.target.spec]
        local body=rows and rows[adoption.target.id]
        local fallbackKey=adoption.target.id==profile.rotationFallbackID and DEFAULT or nil
        local publication=prepareActivePublication and prepareActivePublication(adoption.target.spec,nil,reference,reference,body,nil,fallbackKey)
        local current,currentReason=ready();if not current then return nil,currentReason end
        local now,ownerReason=context();if not now or not same(now,c) then return nil,ownerReason or 'rotation-owner-changed' end
        local committed,commitReason=store:Commit(adoption.plan,c);if not committed then return nil,commitReason end
        if finishChoicePublication then finishChoicePublication(nil) end
        local draft=pending[referenceKey(reference)]
        if draft then
            -- Adoption creates a saved entity, not the old virtual draft's
            -- first Apply. Retire every alias/key so dirty pending workspaces
            -- retain their text but cannot authorize a write over that entity.
            for index,value in pairs(pending) do if value==draft then
                pending[index]=nil;if byReference[index]==draft.key then byReference[index]=nil end
            end end
            byKey[draft.key]=nil;headers[draft.key]=nil
        end
        adoptionPlans[public]=nil;keyFor(reference)
        if finishActivePublication then finishActivePublication(publication) end
        return true,reference
    end
    function coordinator:SourceView(number,value,imported)
        local record,why=self:Snapshot(number,value);if not record then return nil,why end
        if record.source then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local retained;if imported then retained=record.imported else retained=record.origin end
        if not retained then return nil,imported and 'not-imported' or 'no-source-baseline' end
        local envelope=copy(retained.manifest);envelope.body=record.body
        if imported then return {envelope=envelope,applicability=envelope.applicability,enabled=true,validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions()),sourceId=retained.sourceId,sourceRevision=retained.sourceRevision,stepOrigins=copy(retained.stepOrigins)} end
        local catalog,catalogReason=data.NewCatalog({state={custom={[envelope.id]=envelope},lineage={[envelope.id]=retained.lineage}},validation=owner:GetRotationValidationOptions()})
        local view=catalog and catalog:Get({kind='custom',id=envelope.id})
        if not view or view.lineageError then return nil,catalogReason or 'invalid-origin-state' end;return view
    end
    function coordinator:ComparisonIdentity(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return {kind='builtin',id=reference.id} end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local identity=copy(record.comparison)
        if record.origin then
            local lineage=record.origin.lineage
            identity=identity or {kind=lineage.sourceKind,id=lineage.sourceId,origins={}}
            if identity.kind~=lineage.sourceKind or identity.id~=lineage.sourceId then return nil,'invalid-comparison-origin' end
            for key,origin in pairs(lineage.stepOrigins) do identity.origins[key]=origin end
        elseif record.imported then return {kind='import',id=record.imported.sourceId,origins=copy(record.imported.stepOrigins)} end
        return identity or {kind='custom',id=reference.address.id,sourceAddress=copy(reference.address)}
    end
    function coordinator:Allocator()
        local used={};if libraryReader then libraryReader:Reserve(used) end
        local rows,inventoryReason=store:AllStored();if not rows then return nil,inventoryReason end
        for _,row in ipairs(rows) do used[row.address.id]=true;for _,component in pairs(row.record) do local ok,why=data.ReserveRotationIdentities(component,used);if not ok then return nil,why.code end end end
        for _,draft in pairs(pending) do used[draft.reference.address.id]=true end
        return function()
            local ok,id=pcall(owner.uuid)
            if not ok or not text(id,128) or not id:match('^[%w][%w._:%-]*$') then return nil end
            if used[id] then return nil end;used[id]=true;return id
        end
    end
    function coordinator:Import(prepared,number,name,replacement,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if replacement~=nil and not plain(replacement) then return nil,'invalid-replacement-target' end
        if not validSpec(number) then return nil,'invalid-specialization' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local ok,why=ready();if not ok then return nil,why end
        local c,contextReason=context();if not c then return nil,contextReason end
        if not plain(prepared) then return nil,'invalid-import' end
        local body=data.CopyData(prepared.body);if not plain(body) then return nil,'invalid-import' end
        local manifest=prepared.manifest and copy(prepared.manifest)
        if prepared.manifest and not manifest then return nil,'invalid-import' end
        if manifest and manifest.applicability and manifest.applicability.class and manifest.applicability.class~=c.class then return nil,'class-mismatch' end
        local validation
        if manifest then local envelope=copy(manifest);envelope.body=body;validation=data.ValidateEnvelope(envelope,owner:GetRotationValidationOptions())
        else validation=data.ValidateBody(body,owner:GetRotationValidationOptions()) end
        if not validation.valid or not validation.supported or not validation.resolved then return nil,'import-not-ready' end
        local reference,token,legacyValid
        if replacement then
            if replacement.profile and replacement.profile~=profile then return nil,'rotation-changed-externally' end
            reference,why=self:Resolve(number,replacement.reference or replacement.id);if not reference then return nil,why end
            if reference.kind~='custom' then return nil,'read-only-rotation' end
            token=replacement.recordToken
            if not token then
                if type(replacement.valid)~='function' then return nil,'stale-rotation-record' end
                local record;record,token=self:Snapshot(number,reference);if not record then return nil,token end
                legacyValid=replacement.valid
            end
        end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local id=reference and reference.address.id or allocate();if not id then return nil,'id-collision' end
        local origins={};local tree,treeError=data.IndexRotationSteps(body);if not tree then return nil,treeError.code end
        for _,row in ipairs(tree.rows) do
            local old=row.step.id;local id=allocate();if not id then return nil,'id-collision' end
            row.step.id=id;origins[id]=prepared.stepOrigins and prepared.stepOrigins[old] or old
        end
        body.name=name;local record={body=body}
        if manifest then
            local sourceId=prepared.sourceId or manifest.id;local sourceRevision=prepared.sourceRevision or manifest.revision
            manifest.id=id;manifest.revision=1;manifest.nameKey=name
            record.imported={manifest=manifest,sourceId=sourceId,sourceRevision=sourceRevision,stepOrigins=origins}
        end
        local scope=reference and reference.address.scope or options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        reference=reference or {kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        if legacyValid then local ok,valid=pcall(legacyValid);if not ok or not valid then return nil,'rotation-changed-externally' end end
        local saved,commitReason,transition=self:Commit(reference,token,record,scope,'import');if not saved then return nil,commitReason end
        return id,nil,saved,transition
    end
    function coordinator:Copy(number,value,name,options)
        if options~=nil and not plain(options) then return nil,'invalid-rotation-options' end
        if type(name)~='string' or not name:find('%S') or #name>256 then return nil,'invalid-name' end
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        local record,reason=self:Snapshot(number,reference);if not record then return nil,reason end
        local allocate,allocationReason=self:Allocator();if not allocate then return nil,allocationReason end
        local body=record.body;local copiedRecord={};local id
        if reference.kind=='builtin' then
            local source=record.source;local state={};local catalog=data.NewCatalog({state=state,newId=allocate})
            assert(catalog:RegisterBuiltin(source.envelope));id,why=catalog:Clone({kind='builtin',id=reference.id},name);if not id then return nil,why end
            local view=catalog:Get({kind='custom',id=id});local manifest=view.envelope;copiedRecord.body=manifest.body;manifest.body=nil
            if manifest.applicability.universal then manifest.applicability.universal=nil;manifest.applicability.class=context().class end
            copiedRecord.origin={manifest=manifest,lineage=view.lineage}
        else
            id=allocate();if not id then return nil,'id-collision' end
            local identity,why=self:ComparisonIdentity(number,reference);if not identity then return nil,why end
            local correspondence={kind=identity.kind=='import' and 'custom' or identity.kind,id=identity.id,origins={},sourceAddress=copy(identity.sourceAddress)}
            local tree,errorText=data.IndexRotationSteps(body,{allowMissingIds=true});if not tree then return nil,errorText.code end
            copiedRecord=copyRecord(record);copiedRecord.body=body
            local lineage=copiedRecord.origin and copiedRecord.origin.lineage;local oldOrigins=lineage and copy(lineage.stepOrigins)
            if lineage then lineage.clonedFrom=reference.address.id;lineage.stepOrigins={} end
            local imported=copiedRecord.imported;local oldImported=imported and copy(imported.stepOrigins);if imported then imported.stepOrigins={} end
            for _,row in ipairs(tree.rows) do
                local old=row.step.id;local new=allocate();if not new then return nil,'id-collision' end
                row.step.id=new;correspondence.origins[new]=identity.origins and identity.origins[old] or old
                if lineage then lineage.stepOrigins[new]=oldOrigins[old] end
                if imported then imported.stepOrigins[new]=oldImported[old] or old end
            end
            body.name=name
            for _,source in ipairs({copiedRecord.origin or false,copiedRecord.imported or false}) do if source then source.manifest.id=id;source.manifest.revision=1;source.manifest.nameKey=name end end
            if not imported then copiedRecord.comparison=correspondence else copiedRecord.comparison=nil end
        end
        local c,contextReason=context();if not c then return nil,contextReason end;local scope=options and options.scope or 'class'
        if scope~='class' and scope~='character' then return nil,'invalid-owner-scope' end
        if scope=='character' and not c.character then return nil,'missing-owner-context' end
        local target={kind='custom',address={scope=scope,class=c.class,owner=scope=='class' and c.class or c.character,spec=number,id=id}}
        local saved,commitReason=self:Commit(target,nil,copiedRecord,scope);if not saved then return nil,commitReason end
        return id,nil,saved
    end
    function coordinator:GetEditableRotation(number,value)
        local reference,why=self:Resolve(number,value);if not reference then return nil,why end
        if reference.kind=='builtin' then return nil,'readonly-rotation' end
        local c,reason=context();if not c then return nil,reason end
        local readable,alreadyExposed,previousSeal=reader:Read(reference.address,c,function(record) return exposed[record.body]==true end)
        if not readable then return nil,alreadyExposed end
        if not alreadyExposed then
            -- A portable store may legitimately share payload tables between
            -- records or history. The mutable legacy escape must first acquire
            -- an independent canonical body, without changing any data values.
            local detached,token=store:Get(reference.address,c);if not detached then return nil,token end
            local plan,planReason=store:PlanReplace(reference.address,detached,c,token);if not plan then return nil,planReason end
            local committed,commitReason=store:Commit(plan,c);if not committed then return nil,commitReason end
            if finishChoicePublication then finishChoicePublication(nil) end
            -- This transaction changed identity only. Preserve UI authorities
            -- that still describe the exact complete value being detached.
            local _,freshToken=store:Get(reference.address,c)
            local _,_,freshSeal=reader:Read(reference.address,c,function() return true end)
            for _,issued in pairs(expected) do
                if issued.seal==previousSeal and same(issued.reference,reference) and same(issued.context,c) and same(issued.baseline,detached) then issued.token=freshToken;issued.seal=freshSeal end
            end
        end
        local ok,body=reader:Read(reference.address,c,function(record) exposureVersion={};exposed[record.body]=true;local asset=assets[referenceKey(reference)];if asset then asset.untracked=true end;return record.body end)
        if not ok then return nil,body end;return body
    end
    function coordinator:Headers(number)
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local rows,stamp=reader:ListOwned(number,c);if not rows then return nil,stamp end
        local fallback=fallbackReference(number);local result={};local presentationChanged=false;local virtualSignature
        local validation,validationStamp=owner:GetRotationValidationOptions()
        for _,row in ipairs(rows) do
            local reference={kind='custom',address=row.address};local key=keyFor(reference)
            local header=headers[key]
            local valid=header and reader:IsCurrent(header.seal,c)
            local projected,view=reader:Read(row.address,c,function(record)
                if header and valid and header.stamp==validationStamp and not exposed[record.body] then return header.view end
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local status=data.ValidateBody(body,validation)
                if manifest then local envelope={};for k,v in pairs(manifest) do envelope[k]=v end;envelope.body=body;status=data.ValidateEnvelope(envelope,validation) end
                local state=not status.valid and 'invalid' or not status.supported and 'unsupported' or not status.resolved and 'unresolved' or 'valid'
                local projection={validationState=state,body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    priority=body.priority,disabled=body.disabled,tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return projection
            end)
            if not projected then return nil,view end
            if not header or not same(header.view,view) then presentationChanged=true end
            headers[key]={seal=row.seal,view=view,stamp=validationStamp}
            result[#result+1]={key=key,reference=copy(reference),canonicalId=row.address.id,kind='custom',scope=row.address.scope,
                name=view.body.name or L['Unnamed rotation'],description=view.body.description or '',enabled=not view.body.disabled,
                priority=data.GetRotationPriority(view.body.priority),tags=data.GetRotationTags(view) or {},search=data.RotationSearchText(view,view.body.name or '',view.body.description or ''),
                readOnly=false,pending=false,virtual=false,fallback=row.address.id==profile.rotationFallbackID,effectiveFallback=fallback and same(fallback,reference) or false,validationState=view.validationState}
        end
        local virtual={kind='custom',address={scope='class',class=c.class,owner=c.class,spec=number,id=profile.rotationFallbackID}}
        local exists,missing=reader:Read(virtual.address,c,function() return true end)
        if not exists and missing=='unknown-rotation' then
            local reference,key=self:NewDraft(number,'class',true)
            if reference then virtualSignature=key..referenceKey(reference);result[#result+1]={key=key,reference=reference,canonicalId=profile.rotationFallbackID,kind='custom',scope='class',name=profile.rotationFallbackID,description='',enabled=true,priority=0,tags={},search=profile.rotationFallbackID:lower(),readOnly=false,pending=true,virtual=true,fallback=true,effectiveFallback=false,validationState='pending'} end
        elseif not exists then return nil,missing end
        local builtinPresentation={}
        if libraryReader then
            local rows,why=libraryReader:List(number,function(id,view,body)
                local reference={kind='builtin',id=id};local name=L[view.nameKey or id];local description=L[view.descriptionKey or '']
                local eligible,eligibilityReason=libraryReader:Eligible(view,number,false)
                builtinPresentation[id]={name=name,description=description,eligible=eligible,reason=eligibilityReason}
                return {key=keyFor(reference),reference=reference,canonicalId=id,kind='builtin',name=name,description=description,enabled=view.enabled,eligible=eligible,eligibilityReason=eligibilityReason,priority=data.GetRotationPriority(body.priority),
                    tags=data.GetRotationTags(view.envelope) or {},search=data.RotationSearchText(view.envelope,name,description),readOnly=true,pending=false,virtual=false,fallback=false,effectiveFallback=false,validationState=view.validation.valid and 'valid' or 'invalid'}
            end)
            if not rows then return nil,why end;for _,row in ipairs(rows) do result[#result+1]=row end
        end
        local libraryStamp=libraryReader and libraryReader:Generation()
        local ownedCurrent=rosterOwned and reader:IsCurrent(rosterOwned,c)
        if not rosterStamp or not ownedCurrent or rosterLibrary~=libraryStamp or rosterValidation~=validationStamp or rosterVirtual~=virtualSignature or not same(rosterBuiltin,builtinPresentation) or presentationChanged then rosterStamp={} end
        if not ownedCurrent then rosterOwned=stamp end
        rosterLibrary=libraryStamp;rosterValidation=validationStamp;rosterVirtual=virtualSignature
        rosterBuiltin=builtinPresentation
        return result,rosterStamp
    end
    function coordinator:RuntimePass(number,privateToken)
        local request=evaluationRequest;evaluationRequest=nil
        local private=request~=nil or privateToken==privatePlanPass
        local version=contextVersion
        local ok,why=ready();if not ok then return nil,why end
        local c,reason=context();if not c then return nil,reason end
        local validation,referenceStamp=owner:GetRotationValidationOptions();local revision=owner.conditionRegistryVersion;local generation=libraryReader and libraryReader:Generation();local pass={}
        local selected,untracked,listSeal={},{},nil
        local publicationSelected={};local makePublicationGuard=managedStoreReader and ownedPublicationGuard
        local observedPrivate,observedMethod
        local function eligibilityContext()
            local value,private,method=rotationContext(owner,number)
            if libraryContextProof and libraryContextProof(method,eligibilityContext,rotationContext)and private==true then observedPrivate,observedMethod=true,method;return value end
            observedPrivate=false
            local result={}
            for _,key in ipairs({'family','class','spec','actionContext','level','build','combatDataPolicy'}) do result[key]=value and value[key] end
            return result
        end
        local observedContext=eligibilityContext()
        local contextGuard=request and observedPrivate and libraryRuntimeContextGuard
            and libraryRuntimeContextGuard(observedContext,observedMethod,eligibilityContext,rotationContext)
        local function baseCurrent()
            local readyNow,problemText=ready();if not readyNow then return nil,problemText end
            local now=context();if not now or not same(now,c) then return nil,'rotation-owner-changed' end
            if request and version~=contextVersion then return nil,'rotation-context-changed' end
            if contextGuard then
                local unchanged=contextGuard()
                if request and version~=contextVersion then return nil,'rotation-context-changed' end
                if unchanged==false then return nil,'rotation-context-changed' end
                if unchanged==nil then contextGuard=nil end
            end
            if not contextGuard and not same(observedContext,eligibilityContext()) then return nil,'rotation-context-changed' end
            local stamp
            if libraryReader then
                local eligible=libraryGenerationProof and libraryGenerationProof(nil,referenceStamp,generation)
                local method=libraryReader.Generation
                local currentGeneration,_,checked,proof=method(libraryReader)
                if currentGeneration~=generation then return nil,'rotation-library-changed' end
                if eligible and proof and libraryGenerationProof(method,referenceStamp,generation) then stamp=checked end
            end
            -- Only the immediately preceding owned, unchanged library check can
            -- supply this observation; every uncertain path repeats the public read.
            if stamp==nil then stamp=owner:GetRotationValidationStamp() end
            if stamp~=referenceStamp or owner.conditionRegistryVersion~=revision then return nil,'rotation-dependencies-changed' end
            return true
        end
        function pass:IsCurrent()
            local current,problemText=baseCurrent();if not current then return nil,problemText end
            if listSeal then
                if not reader:IsCurrent(listSeal,c) then return nil,'rotation-records-changed' end
            else
                for _,seal in pairs(selected) do if not reader:IsCurrent(seal,c) then return nil,'rotation-records-changed' end end
            end
            for _,watch in pairs(untracked) do
                local readable,unchanged=reader:Read(watch.address,c,function(record)
                    return data.CheckPortable(record.body) and same(record.body,watch.baseline)
                end)
                if not readable or not unchanged then return nil,'rotation-records-changed' end
            end
            return true
        end
        local function observeList()
            if listSeal then return true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return nil,seal end
            listSeal=seal;return true
        end
        -- Batch candidates validate their complete list once before publication.
        -- Rechecking an ever-growing selected set for each row would be O(n^2).
        local function get(value,candidates,batch)
            local readyNow,problemText
            if batch then readyNow,problemText=baseCurrent() else readyNow,problemText=pass:IsCurrent() end
            if not readyNow then return nil,problemText end
            local reference,errorText=coordinator:Resolve(number,value);if not reference then return nil,errorText end
            local index=referenceKey(reference)
            if reference.kind=='builtin' then
                local readable,item=libraryReader:Read(number,reference.id,function(view,body,allowed,eligibilityReason)
                    if not allowed then return {reason=eligibilityReason} end
                    local asset=assets[index];if not asset or asset.generation~=generation then asset={body=copy(body),generation=generation};assets[index]=asset end
                    return asset
                end,candidates)
                if not readable then return nil,item end;if item.reason then return nil,item.reason end
                if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
                if not private then item.borrowed=true end
                return item.body
            end
            if reference.address.id==fallbackID then
                local observed,problemText=observeList();if not observed then return nil,problemText end
                local effective,fallbackReason=coordinator:Resolve(number,DEFAULT)
                if not effective then return nil,fallbackReason end
                if not same(reference,effective) then return nil,'inactive-fallback' end
            end
            local okRead,asset,seal=reader:Read(reference.address,c,function(record,recordSeal)
                local previous=assets[index]
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and not exposed[record.body] then return previous end
                local portable=data.CheckPortable(record.body);if not portable then return {unavailable='invalid-rotation-body'} end
                if previous and previous.seal==recordSeal and previous.stamp==referenceStamp and exposed[record.body] and same(record.body,previous.baseline) then return previous end
                local status=data.ValidateBody(record.body,validation)
                local provenance=record.origin or record.imported
                local source=provenance and copy(provenance.manifest)
                if source then source.body=copy(record.body);status=data.ValidateEnvelope(source,validation) end
                local item={seal=recordSeal,stamp=referenceStamp,baseline=copy(record.body),body=copy(record.body),validation=status,applicability=source and source.applicability,untracked=exposed[record.body]==true}
                assets[index]=item;return item
            end)
            if not okRead then return nil,asset end
            selected[index]=seal
            if request and type(makePublicationGuard)=='function' then publicationSelected[index]=makePublicationGuard(reader,seal,c) end
            if asset.untracked then untracked[index]={address=copy(reference.address),baseline=asset.baseline} end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            local status=asset.validation
            if asset.unavailable or not status.valid or not status.supported or not status.resolved then return nil,reference.address.id==fallbackID and 'invalid-fallback' or asset.unavailable or 'rotation-unavailable' end
            if asset.body.disabled then return nil,'disabled' end
            if asset.applicability then local allowed,eligibilityReason=libraryReader:Eligible({enabled=true,validation=status,applicability=asset.applicability},number,candidates);if not allowed then return nil,eligibilityReason end
            elseif rotationContext(owner,number).combatDataPolicy~='probe' then return nil,'restricted-or-unsupported-client' end
            if owner:HasDisabledRotationDependency(asset.body) then return nil,'disabled-dependency' end
            if not batch then local current,problemText=pass:IsCurrent();if not current then return nil,problemText end end
            if not private then asset.borrowed=true end
            return asset.body
        end
        function pass:Get(value,candidates) return get(value,candidates,false) end
        function pass:Candidates(candidates)
            local current,problemText=self:IsCurrent();if not current then return {},problemText end
            if candidates==nil then candidates=true end
            local rows,seal=reader:ListOwned(number,c);if not rows then return {},seal end
            -- Keep the original seal when a caller repeats Candidates on the
            -- same pass: stale authority must never be refreshed implicitly.
            listSeal=listSeal or seal
            local fallback=coordinator:Resolve(number,DEFAULT);local result={}
            for _,row in ipairs(rows) do
                local reference={kind='custom',address=row.address}
                local effective=row.address.id==fallbackID and fallback and same(reference,fallback)
                if row.address.id~=fallbackID or effective then
                    local body=get(reference,candidates,true);if body then result[effective and DEFAULT or keyFor(reference)]=body end
                end
            end
            if libraryReader then
                local views,libraryReason=libraryReader:List(number,function(id) return {kind='builtin',id=id} end);if not views then return {},libraryReason end
                for _,reference in ipairs(views) do local body=get(reference,candidates,true);if body then result[keyFor(reference)]=body end end
            end
            local complete,completionReason=self:IsCurrent();if not complete then return {},completionReason end
            return result
        end
        if request and managedStoreReader then
            local originalCurrent=pass.IsCurrent
            request.pass=pass
            request.publication=function()
                -- Public overrides and list/fallback semantics retain the full route.
                if pass.IsCurrent~=originalCurrent or listSeal or not storeScopeEnvironment
                    or getfenv~=storeGetfenv or storeGetfenv(originalCurrent)~=storeScopeEnvironment then return pass:IsCurrent() end
                local current,problemText=baseCurrent();if not current then return nil,problemText end
                if listSeal then
                    if not reader:IsCurrent(listSeal,c) then return nil,'rotation-records-changed' end
                else
                    for index,seal in pairs(selected) do
                        local guard=publicationSelected[index]
                        local unchanged=guard and guard()
                        -- Base authority has already run. Fall back only this
                        -- selected-store check, without repeating callbacks.
                        if unchanged==nil then unchanged=reader:IsCurrent(seal,c) end
                        if not unchanged then return nil,'rotation-records-changed' end
                    end
                end
                -- Retain the supported mutable canonical-body watcher verbatim.
                for _,watch in pairs(untracked) do
                    local readable,unchanged=reader:Read(watch.address,c,function(record)
                        return data.CheckPortable(record.body) and same(record.body,watch.baseline)
                    end)
                    if not readable or not unchanged then return nil,'rotation-records-changed' end
                end
                return true
            end
        end
        return pass
    end
    -- Main alone receives this cold planner; public RuntimePass stays eager.
    local ownedResolve,ownedPass=coordinator.Resolve,coordinator.RuntimePass
    local ownerPlatform=rawget(owner,'Platform')
    local ownerClass=type(ownerPlatform)=='table' and rawget(ownerPlatform,'GetPlayerOwnerClassObservation')
    currentPlanSource=function(spec,key)
        if current~=coordinator or not alive or not managedStoreReader or not readActiveRuntime or not copyActiveRuntime or not planDataCurrent(owner)
            or not runtimeAuthority or not readLibraryRuntime or not planEligible
            or rawget(owner,'AcquireRotationRuntimePass')~=ownedAcquireRuntimePass or storeGetfenv(ownedAcquireRuntimePass)~=storeScopeEnvironment
            or rawget(owner,'GetScopedRotationCoordinator')~=ownedScopedCoordinator or rawget(coordinator,'Resolve')~=ownedResolve or rawget(coordinator,'RuntimePass')~=ownedPass
            or rawget(owner,'GetRotationOwnerContext')~=ownedOwnerContext or rawget(owner,'GetRotationContext')~=ownedRuntimeContext
            or rawget(owner,'Platform')~=ownerPlatform or not ownerPlatform or rawget(ownerPlatform,'CanReadValue')~=ownedRuntimeReadValue
            or rawget(ownerPlatform,'GetPlayerOwnerClassObservation')~=ownerClass then return end
        local known=byKey[key]
        if not known or known.kind~='custom' or known.address.id==fallbackID then return end
        local existing=assets[referenceKey(known)]
        if existing and (existing.untracked or existing.borrowed) then return end
        local handle,revision=readActiveRuntime(owner,spec,key);if not handle then return end
        local epoch,db,p,g,defs,registry,shared,personal,effects,libraryState=runtimeAuthority(owner)
        if not epoch then return end
        local pass=ownedPass(coordinator,spec,privatePlanPass);local body=pass and pass:Get(key)
        if not body or not pass:IsCurrent() then return end
        local reference=ownedResolve(coordinator,spec,key)
        if not reference or reference.kind~='custom' or reference.address.id==fallbackID then return end
        local contextValue=context();if not contextValue then return end
        local ok,selected,seal=reader:Read(reference.address,contextValue,function(record) return record end)
        if not ok or exposed[selected.body] then return end
        local guard=ownedPublicationGuard and ownedPublicationGuard(reader,seal,contextValue)
        if not guard or guard()~=true then return end
        local execution=copyActiveRuntime(owner,handle,body);if not execution then return end
        local asset=assets[referenceKey(reference)];if not asset or not asset.validation then return end
        local generation,definitionVersion=readLibraryRuntime()
        local exposure=exposureVersion
        local function authority()
            local nextEpoch,nextDB,nextProfile,nextGlobal,nextDefs,nextRegistry,nextShared,nextPersonal,nextEffects,nextLibrary=runtimeAuthority(owner)
            local activeHandle,activeRevision=readActiveRuntime(owner,spec,key)
            local libraryGeneration,libraryVersion=readLibraryRuntime()
            return alive and current==coordinator and rawget(owner,'AcquireRotationRuntimePass')==ownedAcquireRuntimePass
                and storeGetfenv(ownedAcquireRuntimePass)==storeScopeEnvironment and planDataCurrent(owner) and bindIdentity(activeHandle,handle) and activeRevision==revision
                and bindIdentity(nextEpoch,epoch) and bindIdentity(nextDB,db) and bindIdentity(nextProfile,p) and bindIdentity(nextGlobal,g)
                and bindIdentity(nextDefs,defs) and bindIdentity(nextRegistry,registry) and bindIdentity(nextShared,shared)
                and bindIdentity(nextPersonal,personal) and bindIdentity(nextEffects,effects) and bindIdentity(nextLibrary,libraryState)
                and bindIdentity(libraryGeneration,generation) and libraryVersion==definitionVersion
                and exposure==exposureVersion and not exposed[selected.body] and not asset.borrowed
                and rawget(owner,'GetScopedRotationCoordinator')==ownedScopedCoordinator and rawget(coordinator,'Resolve')==ownedResolve and rawget(coordinator,'RuntimePass')==ownedPass
                and rawget(owner,'GetRotationOwnerContext')==ownedOwnerContext and rawget(owner,'GetRotationContext')==ownedRuntimeContext
                and rawget(owner,'Platform')==ownerPlatform and ownerPlatform and rawget(ownerPlatform,'CanReadValue')==ownedRuntimeReadValue
                and rawget(ownerPlatform,'GetPlayerOwnerClassObservation')==ownerClass and guard()==true
        end
        if not authority() then return end
        local view={enabled=true,validation=asset.validation,applicability=asset.applicability}
        local function entry()
            if not authority() then return end
            local actor=context()
            if not actor or actor.class~=contextValue.class or actor.character~=contextValue.character then return end
            local info,private,method=rotationContext(owner,spec)
            if private~=true or not libraryContextProof(method,entry,rotationContext) then return end
            if not authority() then return end
            local allowed,reason
            if view.applicability then allowed,reason=planEligible(view,info,false)
            else allowed=info.combatDataPolicy=='probe';reason='restricted-or-unsupported-client' end
            local _,_,operation=readActiveRuntime(owner,spec,key)
            return {version=contextVersion,operation=operation,allowed=allowed==true,reason=reason}
        end
        local function currentEntry(value)
            if not value or value.version~=contextVersion or not authority() then return false end
            local _,_,operation=readActiveRuntime(owner,spec,key)
            return bindIdentity(operation,value.operation)
        end
        -- Only the literal native cooldown publisher receives these views.
        -- Runtime colors already belong to one CopyData graph, separate from
        -- execution: retain sibling aliases and later eager-fallback mutations.
        local presentation={}
        for index,step in planIpairs(execution.cooldowns or {}) do
            local public=body.cooldowns[index]
            presentation[step]={id=public.id,effect=public.effect,color=public.color,
                magnification=public.magnification,setpoint=public.setpoint,
                xoffs=public.xoffs,yoffs=public.yoffs,angle=public.angle}
        end
        return {body=execution,presentation=presentation,handle=handle,token={},entry=entry,current=currentEntry,authority=authority}
    end
    ownedRuntimePasses[coordinator]=coordinator.RuntimePass
    completeRebind(binding,coordinator,problem)
    if problem then return nil,problem end
    return true
end
local function bound()
    local value=addon:GetScopedRotationCoordinator();if not value then return nil,'rotation-profile-not-bound' end;return value
end
function addon:ResolveRotationReference(spec,value) local c,why=bound();if not c then return nil,why end;return c:Resolve(spec,value) end
function addon:ListRotationHeaders(spec) local c,why=bound();if not c then return nil,why end;return c:Headers(spec) end
function addon:GetRotationRecordSnapshot(spec,value) local c,why=bound();if not c then return nil,why end;return c:Snapshot(spec,value) end
function addon:NewRotationDraftTarget(spec,scope,fallback) local c,why=bound();if not c then return nil,why end;return c:NewDraft(spec,scope,fallback) end
function addon:CommitRotationDraft(reference,token,record,scope) local c,why=bound();if not c then return nil,why end;return c:Commit(reference,token,record,scope) end
function addon:DeleteRotationRecord(reference,token) local c,why=bound();if not c then return nil,why end;return c:Delete(reference,token) end
function addon:AcquireRotationRuntimePass(spec) local c,why=bound();if not c then return nil,why end;return c:RuntimePass(spec) end


ownedAcquireRuntimePass=addon.AcquireRotationRuntimePass
local ownedGetCleanup=addon.GetRotationForCleanup
-- Only main receives this capability. Public/manual RuntimePass callers retain
-- the fresh provider route, and every main invocation starts a new observation.
function addon:BindRuntimeEvaluationContext(bind)
    if self~=addon or type(bind)~='function' then return nil end
    bind(function(owner,spec)
        contextVersion={}
        if owner~=addon or owner.AcquireRotationRuntimePass~=ownedAcquireRuntimePass
            or owner.GetScopedRotationCoordinator~=ownedScopedCoordinator
            or not current or current.RuntimePass~=ownedRuntimePasses[current] then return owner:AcquireRotationRuntimePass(spec) end
        local previous=evaluationRequest;local request={};evaluationRequest=request
        local ok,pass,reason=protect(ownedAcquireRuntimePass,owner,spec)
        evaluationRequest=previous
        if not ok then raise(pass,0) end
        return pass,reason,request.pass==pass and request.publication or nil
    end,function() contextVersion={} end,function(owner,spec)
        if owner~=addon or rawget(owner,'AcquireRotationRuntimePass')~=ownedAcquireRuntimePass
            or storeGetfenv(ownedAcquireRuntimePass)~=storeScopeEnvironment
            or rawget(owner,'GetScopedRotationCoordinator')~=ownedScopedCoordinator
            or not current or rawget(current,'RuntimePass')~=ownedRuntimePasses[current] then return owner:AcquireRotationRuntimePass(spec) end
        return current:RuntimePass(spec,privatePlanPass)
    end,function(owner,spec,key,capturedMethod)
        if owner~=addon or capturedMethod~=ownedGetCleanup or rawget(owner,'GetRotationForCleanup')~=ownedGetCleanup
            or storeGetfenv(ownedGetCleanup)~=storeScopeEnvironment
            or rawget(owner,'GetScopedRotationCoordinator')~=ownedScopedCoordinator
            or not current or rawget(current,'RuntimePass')~=ownedRuntimePasses[current] then return capturedMethod(owner,spec,key) end
        return current:Cleanup(spec,key,privatePlanPass)
    end)
    return true
end

-- Inspection of another profile never switches the active database or grants
-- edit authority. Only detached saved headers for the current owner leave here.
function addon:GetProfileRotationHeaders(profile)
    if not plain(profile) then return nil,'invalid-profile' end
    if profile.rotationStore==nil then return nil,'rotation-profile-recovery-required' end
    if not text(profile.rotationFallbackID,128) then return nil,'missing-fallback-configuration' end
    local c,why=self:GetRotationOwnerContext();if not c then return nil,why end
    local state,fallback=profile.rotationStore,profile.rotationFallbackID
    local reader;local store,reason=data.NewRotationStore({state=state,fallbackID=fallback,validation=self:GetRotationValidationOptions(),bindInternalReader=function(value) reader=value end})
    if not store then return nil,reason end
    local function finish(value,problem) reader:Retire();return value,problem end
    local numbers={};local class=state.classes[c.class];for number in pairs(class or {}) do numbers[number]=true end
    local character=c.character and state.characters[c.character]
    if character and character.class~=c.class then return finish(nil,'foreign-owner') end
    for number in pairs(character and character.specs or {}) do numbers[number]=true end
    local specs={};for number in pairs(numbers) do specs[#specs+1]=number end;table.sort(specs)
    local result={}
    for _,number in ipairs(specs) do
        local rows,problem=reader:ListOwned(number,c);if not rows then return finish(nil,problem) end
        for _,row in ipairs(rows) do
            local ok,view=reader:Read(row.address,c,function(record)
                local body=record.body;local manifest=record.origin and record.origin.manifest or record.imported and record.imported.manifest
                local projection={body={name=type(body.name)=='string' and body.name or nil,description=type(body.description)=='string' and body.description or nil,
                    tags=tagsView(body.tags),metadata=metadataView(body.metadata)},tags=manifest and copy(manifest.tags),sources=manifest and copy(manifest.sources)}
                return {reference={kind='custom',address=copy(row.address)},canonicalId=row.address.id,kind='custom',scope=row.address.scope,spec=number,
                    name=projection.body.name or L['Unnamed rotation'],description=projection.body.description or '',enabled=not body.disabled,
                    priority=data.GetRotationPriority(body.priority),tags=data.GetRotationTags(projection) or {},search=data.RotationSearchText(projection,projection.body.name or '',projection.body.description or ''),
                    fallback=row.address.id==fallback,readOnly=false,pending=false}
            end)
            if not ok then return finish(nil,view) end;result[#result+1]=view
        end
    end
    local now=self:GetRotationOwnerContext()
    if not now or not same(c,now) or profile.rotationStore~=state or profile.rotationFallbackID~=fallback then return finish(nil,'rotation-profile-changed') end
    return finish(result)
end

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'scope',addon.BindRotationProfile,function() return same end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF

-- Cold-consumed by Core/active_runtime_plan, never a public body getter.
function addon:BindScopedActiveRuntimePlan(receiver)
    if self~=addon or type(receiver)~='function' then return end
    receiver(function(owner,spec,key)
        if owner~=addon or not currentPlanSource then return end
        return currentPlanSource(spec,key)
    end,readActiveRuntime)
end
]]):sub(2)

    local after = before

    after = after:sub(1, 69965)
        .. ([[!        return {body=execution,presentation=presentation,handle=handle,token={},entry=entry,current=currentEntry,conditionCurrent=conditionCurrent,authority=authority}
]]):sub(2)
        .. after:sub(70100)

    after = after:sub(1, 69337)
        .. ([[!        local function conditionCurrent(value)
            if not value or value.version~=contextVersion or not alive or current~=coordinator
                or rawget(profile,'rotationStore')~=state or rawget(profile,'rotationFallbackID')~=fallbackID
                or exposure~=exposureVersion or exposed[selected.body] or asset.borrowed or not planDataCurrent(owner) then return false end
            local activeHandle,activeRevision,operation=readActiveRuntime(owner,spec,key)
            if not bindIdentity(activeHandle,handle) or activeRevision~=revision or not bindIdentity(operation,value.operation) then return false end
            local nextEpoch,nextDB,nextProfile,nextGlobal,nextDefs,nextRegistry,nextShared,nextPersonal,nextEffects,nextLibrary=runtimeAuthority(owner,true)
            if not bindIdentity(nextEpoch,epoch) or not bindIdentity(nextDB,db) or not bindIdentity(nextProfile,p) or not bindIdentity(nextGlobal,g)
                or not bindIdentity(nextDefs,defs) or not bindIdentity(nextRegistry,registry) or not bindIdentity(nextShared,shared)
                or not bindIdentity(nextPersonal,personal) or not bindIdentity(nextEffects,effects) or not bindIdentity(nextLibrary,libraryState) then return false end
            local libraryGeneration,libraryVersion=readLibraryRuntime()
            return bindIdentity(libraryGeneration,generation) and libraryVersion==definitionVersion and storeContinuation()==true
        end
]]):sub(2)
        .. after:sub(69338)

    after = after:sub(1, 65803)
        .. ([[!        local guard,storeContinuation
        if ownedPublicationGuard then guard,storeContinuation=ownedPublicationGuard(reader,seal,contextValue) end
        if not guard or not storeContinuation or guard()~=true then return end
]]):sub(2)
        .. after:sub(65952)

    rows["Core/rotation_scope.lua"] = { before = before, after = after }
end

do
    local before = ([[!local _,addon=...
local kind,raw,identity=type,rawget,rawequal
---@type fun(f: number|function): table
local environment=getfenv
local source,readActive,dispatch,dispatchEnvironment
---@type fun(...): any
local bind=addon.BindScopedActiveRuntimePlan
if kind(bind)=='function' then bind(addon,function(value,read)source,readActive=value,read end);addon.BindScopedActiveRuntimePlan=nil end
---@type fun(...): any, any
local consume=addon.ConsumeAnnouncementRuntimeSource
if kind(consume)=='function' then dispatch,dispatchEnvironment=consume(addon);addon.ConsumeAnnouncementRuntimeSource=nil end
local glowCooldown,presentationEnvironment
-- buttons.lua consumes this receiver before its library callbacks, then sends
-- the literal method immediately after definition. Never recapture a live field.
function addon:BindActiveRuntimePresentationSource(method,env)
    if self~=addon or glowCooldown~=nil or kind(method)~='function' or kind(env)~='table' then return end
    glowCooldown,presentationEnvironment=method,env
end
local spellIDs,sequence,mainEnvironment,registered
local request,plan
local plansBuilt,reused,declined,currentRoute=0,0,0,'idle'
local function consumers(owner)
    return registered and identity(owner,addon)
        and kind(environment)=='function' and kind(dispatch)=='function' and kind(dispatchEnvironment)=='table'
        and kind(glowCooldown)=='function' and identity(raw(owner,'GlowCooldown'),glowCooldown)
        and identity(environment(glowCooldown),presentationEnvironment)
        and identity(raw(owner,'GetSpellIds'),spellIDs) and identity(raw(owner,'EvaluateRotationSequence'),sequence)
        and identity(raw(owner,'DispatchAnnouncement'),dispatch)
        and identity(environment(spellIDs),mainEnvironment) and identity(environment(sequence),mainEnvironment)
        and identity(environment(dispatch),dispatchEnvironment)
end
local function register(owner,ids,run,env)
    if registered or owner~=addon or kind(ids)~='function' or kind(run)~='function' or kind(env)~='table' then return end
    spellIDs,sequence,mainEnvironment,registered=ids,run,env,true
    return true
end
local function retired() return false end
local function acquire(owner,spec,key)
    if owner~=addon then return nil,nil,nil,false end
    if not identity(raw(owner,'currentSpec'),spec) or not identity(raw(owner,'currentRotation'),key) then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
    local ticket={};request=ticket
    local handle,revision,operation
    if kind(readActive)=='function' then handle,revision,operation=readActive(owner,spec,key) end
    local function requestCurrent()
        if not identity(request,ticket) then return false end
        if not handle then return true end
        local nextHandle,nextRevision,nextOperation=readActive(owner,spec,key)
        return identity(nextHandle,handle) and nextRevision==revision and identity(nextOperation,operation)
    end
    if not consumers(owner) or kind(source)~='function' then plan=nil;declined=declined+1;currentRoute='fallback';return nil,nil,nil,false end
    local built=false
    local authoritative=plan and plan.authority()
    if not requestCurrent() then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
    if not authoritative then
        local prepared=source(owner,spec,key)
        if prepared then plansBuilt=plansBuilt+1;built=true end
        if not requestCurrent() then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
        plan=prepared
    end
    if not plan or not consumers(owner) then plan=nil;declined=declined+1;currentRoute='fallback';return nil,nil,nil,false end
    local selected=plan;local state=selected.entry()
    if not requestCurrent() then declined=declined+1;currentRoute='retired';return nil,retired,nil,true end
    if not state then plan=nil;declined=declined+1;currentRoute='fallback';return nil,nil,nil,false end
    local function current()
        return requestCurrent() and identity(plan,selected) and consumers(owner) and selected.current(state)
    end
    if not current() then declined=declined+1;currentRoute='retired';return nil,current,nil,true end
    if not built then reused=reused+1 end
    currentRoute=state.allowed and 'managed' or 'unavailable'
    return state.allowed and selected.body or nil,current,selected.token,true,selected.presentation
end
function addon:ConsumeActiveRuntimePlan()
    if self~=addon then return end
    return acquire,register
end

-- Scalar snapshots only; collection does not prepare or inspect a plan.
function addon:GetActiveRuntimePlanDiagnostic()
    if self~=addon then return end
    return {plansBuilt=plansBuilt,reused=reused,declined=declined,currentRoute=currentRoute}
end
]]):sub(2)

    local after = before

    after = after:sub(1, 4294)
        .. ([[!    local function conditionCurrent()
        return identity(request,ticket) and identity(plan,selected) and consumers(owner) and selected.conditionCurrent(state)
    end
    return state.allowed and selected.body or nil,current,selected.token,true,selected.presentation,conditionCurrent
]]):sub(2)
        .. after:sub(4395)

    rows["Core/active_runtime_plan.lua"] = { before = before, after = after }
end

do
    local before = ([[!local _,addon=...
local observed,stamp
local dependencyReader
local bindDependency=addon.BindRotationDependencyReader
if type(bindDependency)=='function' then
    bindDependency(addon,function(reader) if type(reader)=='function' then dependencyReader=reader end end)
    addon.BindRotationDependencyReader=nil
end
local dependencyIdentity=rawequal
local managed
local runtimeAuthority,ownedOptions,ownedDisabledDependency
-- Trusted standard primitives at module load; changed live pointers disable reuse.
local proofPairs,proofRawget,proofRawequal,proofType,proofGetmetatable=pairs,rawget,rawequal,type,getmetatable
-- Lua5.1 accepts a stack level or function; the checker declares only levels.
---@type fun(f: number|function): table
local proofGetfenv=getfenv
local proofEnvironment=proofType(proofGetfenv)=='function' and proofGetfenv(1) or nil
local function normalized(value)
    return type(value)=='table' and value or false
end
local function entries(value)
    local result,count={},0
    if type(value)=='table' then
        for key,item in pairs(value) do result[key]=normalized(item);count=count+1 end
    end
    return result,count
end
local function sameEntries(value,previous,expected)
    local count=0
    if type(value)=='table' then
        for key,item in pairs(value) do
            if not rawequal(type(item)=='table' and item or false,previous[key]) then return false end
            count=count+1
        end
    end
    return count==expected
end
local function validItemsets(shared,personal)
    return (shared==nil or type(shared)=='table') and (personal==nil or type(personal)=='table')
end
local function sameItemsets(shared,personal,previous,expected)
    if not validItemsets(shared,personal) then return expected==0 end
    local count=0
    if shared then
        for key,item in pairs(shared) do
            -- Only actual personal entries shadow shared entries. A missing-key
            -- lookup could materialize an AceDB default and mutate the source.
            if not personal or rawget(personal,key)==nil then
                if not rawequal(type(item)=='table' and item or false,previous[key]) then return false end
                count=count+1
            end
        end
    end
    if personal then
        for key,item in pairs(personal) do
            if not rawequal(type(item)=='table' and item or false,previous[key]) then return false end
            count=count+1
        end
    end
    return count==expected
end
local function itemsetEntries(shared,personal)
    if not validItemsets(shared,personal) then return {},0 end
    local result,count=entries(shared)
    if personal then
        for key,item in pairs(personal) do
            if result[key]==nil then count=count+1 end
            result[key]=normalized(item)
        end
    end
    return result,count
end
-- Observe identities without copying maps on the common unchanged path.
-- Normalized false markers keep malformed/NaN entries stable, as before.
local function observeLegacy(owner)
    local profile,global=owner.db.profile,owner.db.global
    local shared,personal=global.itemsets,profile.itemsets
    local conditions,effects=owner.conditionDefinitions,global.effects
    local version=owner.conditionRegistryVersion or 0
    if observed and observed.profile==profile and observed.global==global and observed.version==version
        and sameItemsets(shared,personal,observed.itemsets,observed.itemsetCount)
        and sameEntries(conditions,observed.conditions,observed.conditionCount)
        and sameEntries(effects,observed.effects,observed.effectCount) then return end
    local itemsets,itemsetCount=itemsetEntries(shared,personal)
    local conditionEntries,conditionCount=entries(conditions)
    local effectEntries,effectCount=entries(effects)
    observed={profile=profile,global=global,version=version,
        itemsets=itemsets,itemsetCount=itemsetCount,
        conditions=conditionEntries,conditionCount=conditionCount,
        effects=effectEntries,effectCount=effectCount}
    stamp={}
end
-- Managed ownership does not require plain/default-free maps. AceDB may
-- materialize default metatables; contents change through explicit publication.
local function observe(owner)
    if not dependencyReader or not dependencyIdentity(owner,addon) then
        observeLegacy(owner);return observed,stamp
    end
    local epoch=dependencyReader(owner)
    local db=owner.db;local profile,global=db.profile,db.global
    local conditions,version=owner.conditionDefinitions,owner.conditionRegistryVersion or 0
    local shared,personal,effects=global.itemsets,profile.itemsets,global.effects
    if not managed or not dependencyIdentity(managed.epoch,epoch) or not dependencyIdentity(managed.db,db)
        or not dependencyIdentity(managed.profile,profile) or not dependencyIdentity(managed.global,global)
        or not dependencyIdentity(managed.conditions,conditions) or not dependencyIdentity(managed.shared,shared)
        or not dependencyIdentity(managed.personal,personal) or not dependencyIdentity(managed.effects,effects)
        or not dependencyIdentity(managed.version,version) then
        managed={epoch=epoch,db=db,profile=profile,global=global,conditions=conditions,
            shared=shared,personal=personal,effects=effects,version=version,stamp={}}
    end
    -- Public options copy actual source maps, never a retained private map.
    -- Capture this invocation's roots and generation before live iteration.
    return managed,managed.stamp
end
-- Internal authority checks need the current stamp, not detached public maps.
-- Keep checking every dependency at each call, including reentrant mutations.
function addon:GetRotationValidationStamp()
    local _,current=observe(self)
    return current
end
local ownedValidationStamp=addon.GetRotationValidationStamp
-- Even protected metatable metadata can disguise a callback. Only native
-- primitives stored directly in the owned environment can certify this path.
local function proofGlobals()
    return proofType(proofEnvironment)=='table' and proofRawequal(proofRawget(proofEnvironment,'pairs'),proofPairs)
        and proofRawequal(proofRawget(proofEnvironment,'rawget'),proofRawget) and proofRawequal(proofRawget(proofEnvironment,'rawequal'),proofRawequal)
        and proofRawequal(proofRawget(proofEnvironment,'type'),proofType) and proofRawequal(proofRawget(proofEnvironment,'getmetatable'),proofGetmetatable)
        and proofRawequal(proofRawget(proofEnvironment,'getfenv'),proofGetfenv)
        and proofRawequal(proofGetfenv(ownedValidationStamp),proofEnvironment)
        and proofRawequal(proofGetfenv(observe),proofEnvironment) and proofRawequal(proofGetfenv(observeLegacy),proofEnvironment) and proofRawequal(proofGetfenv(normalized),proofEnvironment)
        and proofRawequal(proofGetfenv(entries),proofEnvironment) and proofRawequal(proofGetfenv(sameEntries),proofEnvironment)
        and proofRawequal(proofGetfenv(validItemsets),proofEnvironment) and proofRawequal(proofGetfenv(sameItemsets),proofEnvironment)
        and proofRawequal(proofGetfenv(itemsetEntries),proofEnvironment)
end
local function proofPlain(value)
    return proofType(value)=='table' and proofGetmetatable(value)==nil
end
-- Only raw-present, callback-free layouts can join adjacent observations.
-- AceAddon owners and AceDB db objects may have metatables: every accessed
-- slot is raw-present, and neither object participates in equality/tostring.
local function validationLayout(owner,method)
    if proofType(owner)~='table'
        or method~=ownedValidationStamp or proofRawget(owner,'GetRotationValidationStamp')~=ownedValidationStamp then return end
    -- Public option copying uses live pairs; a prior override can retain its
    -- private input maps. Their later lookups must remain callback-free too.
    if not proofPlain(observed) or not proofPlain(stamp)
        or not proofPlain(proofRawget(observed,'itemsets'))
        or not proofPlain(proofRawget(observed,'conditions'))
        or not proofPlain(proofRawget(observed,'effects')) then return end
    local db=proofRawget(owner,'db');if proofType(db)~='table' then return end
    local profile,global=proofRawget(db,'profile'),proofRawget(db,'global')
    if not proofPlain(profile) or not proofPlain(global) then return end
    local conditions,version=proofRawget(owner,'conditionDefinitions'),proofRawget(owner,'conditionRegistryVersion')
    local shared,personal=proofRawget(global,'itemsets'),proofRawget(profile,'itemsets')
    local effects,state=proofRawget(global,'effects'),proofRawget(profile,'rotationLibrary')
    if not proofPlain(conditions) or proofType(version)~='number' or not proofPlain(shared)
        or not proofPlain(personal) or not proofPlain(effects) or not proofPlain(state) then return end
    return db,profile,global,conditions,shared,personal,effects,version,state
end
local function sameValidationLayout(owner,method,db,profile,global,conditions,shared,personal,effects,version,state)
    local d,p,g,c,s,i,e,v,l=validationLayout(owner,method)
    return d~=nil and proofRawequal(d,db) and proofRawequal(p,profile) and proofRawequal(g,global)
        and proofRawequal(c,conditions) and proofRawequal(s,shared) and proofRawequal(i,personal)
        and proofRawequal(e,effects) and proofRawequal(v,version) and proofRawequal(l,state)
end
local function readValidationStamp(owner,method,entryMethod)
    if dependencyReader and dependencyIdentity(owner,addon) then
        local value=method(owner);return value
    end
    local db,profile,global,conditions,shared,personal,effects,version,state
    -- A successful PRE proof closes the owned scan. POST checks raw layout
    -- again, without repeating globals that no permitted callback can change.
    if entryMethod==ownedValidationStamp and proofGlobals() then db,profile,global,conditions,shared,personal,effects,version,state=validationLayout(owner,method) end
    local value=method(owner)
    if db then return value,db,profile,global,conditions,shared,personal,effects,version,state end
    return value
end
-- Trusted private module handoff, retired by its consumer. This does not
-- authenticate a hostile replacement of the complete loader/binder itself.
function addon:BindRotationValidationReader(bind)
    if type(bind)~='function' then return nil,'invalid-validation-reader-binder' end
    bind(readValidationStamp,sameValidationLayout,proofRawget,proofRawequal,proofType,proofGetmetatable,runtimeAuthority,ownedOptions,ownedDisabledDependency)
    return true
end
-- Dependency maps may carry AceDB defaults metatables. Observe their entries,
-- without copying/traversing definitions or writing into SavedVariables.
function addon:GetRotationValidationOptions()
    local snapshot,current=observe(self)
    -- Public maps remain fresh: consumers cannot poison private observations.
    local conditions=entries(snapshot.conditions)
    local itemsets
    if dependencyReader and dependencyIdentity(self,addon) then
        itemsets=itemsetEntries(snapshot.shared,snapshot.personal)
    else itemsets=entries(snapshot.itemsets) end
    local effects=entries(snapshot.effects)
    return {conditions=conditions,itemsets=itemsets,effects=effects},current
end

ownedOptions=addon.GetRotationValidationOptions
-- Constant-time managed publication authority; unknown property layouts and
-- public overrides retain the existing eager reader. No membership scan.
runtimeAuthority=function(owner)
    if not dependencyReader or not dependencyIdentity(owner,addon)
        or proofRawget(owner,'GetRotationValidationOptions')~=ownedOptions
        or proofRawget(owner,'GetRotationValidationStamp')~=ownedValidationStamp
        or proofRawget(owner,'HasDisabledRotationDependency')~=ownedDisabledDependency
        or proofType(proofGetfenv)~='function' or proofGetfenv(ownedOptions)~=proofEnvironment
        or proofGetfenv(ownedValidationStamp)~=proofEnvironment or proofGetfenv(ownedDisabledDependency)~=proofEnvironment then return end
    local db=proofRawget(owner,'db');if proofType(db)~='table' then return end
    local profile,global=proofRawget(db,'profile'),proofRawget(db,'global')
    if proofType(profile)~='table' or proofType(global)~='table' then return end
    local conditions,shared,personal,effects=proofRawget(owner,'conditionDefinitions'),proofRawget(global,'itemsets'),proofRawget(profile,'itemsets'),proofRawget(global,'effects')
    if not proofPlain(conditions) or not proofPlain(shared) or not proofPlain(personal) or not proofPlain(effects) then return end
    return dependencyReader(owner),db,profile,global,conditions,
        proofRawget(owner,'conditionRegistryVersion'),proofRawget(global,'itemsets'),
        proofRawget(profile,'itemsets'),proofRawget(global,'effects'),proofRawget(profile,'rotationLibrary')
end

-- Legacy bodies have no envelope. Inspect their semantic condition edges too,
-- so a disabled definition cannot be bypassed by a later priority action.
function addon:HasDisabledRotationDependency(body)
    local definitions=self.conditionDefinitions or {}
    local hasDisabled=false
    for _,definition in pairs(definitions) do if type(definition)=='table' and definition.disabled then hasDisabled=true;break end end
    if not hasDisabled then return false end
    local tree=self.RotationData.IndexRotationSteps(body,{allowMissingIds=true})
    if not tree then return true end
    local count=0
    local condition,declared
    declared=function(value,schema,depth)
        if value==nil then return false end
        if depth>64 then return true end
        if schema=='condition' then return condition(value,depth+1) end
        if schema=='condition[]' then
            if type(value)~='table' then return true end
            for _,child in ipairs(value) do if condition(child,depth+1) then return true end end
        elseif type(schema)=='table' and type(value)=='table' then
            if schema[1]~=nil then
                -- Union schemas may contain object/list alternatives. Inspect
                -- only alternatives that declare nested conditions.
                for _,alternative in ipairs(schema) do if declared(value,alternative,depth+1) then return true end end
            else
                for key,kind in pairs(schema) do if declared(value[key],kind,depth+1) then return true end end
            end
        end
        return false
    end
    condition=function(value,depth)
        if value==nil then return false end
        count=count+1;if count>4096 or depth>64 or type(value)~='table' then return true end
        if value.type=='AND' or value.type=='OR' then return declared(value.value,'condition[]',depth+1) end
        if value.type=='NOT' then return condition(value.value,depth+1) end
        local definition=definitions[value.type]
        if type(definition)=='table' then
            if definition.disabled then return true end
            for key,kind in pairs(definition.fields or {}) do if declared(value[key],kind,depth+1) then return true end end
        end
        return false
    end
    if condition(body.switch,0) then return true end
    for _,row in ipairs(tree.rows) do if condition(row.step.conditions,0) then return true end end
    return false
end

ownedDisabledDependency=addon.HasDisabledRotationDependency

-- BEGIN PRIVATE VALIDATION CPU HANDOFF
do
 local bind=addon.BindCPUValidationScopeDiagnostic
 if type(bind)=='function' then bind(addon,'references',ownedValidationStamp,function() return observe,sameEntries,sameItemsets,proofGlobals end) end
end
-- END PRIVATE VALIDATION CPU HANDOFF
]]):sub(2)

    local after = before

    after = after:sub(1, 12435)
        .. ([[!    if continuation~=true and (not proofPlain(conditions) or not proofPlain(shared) or not proofPlain(personal) or not proofPlain(effects)) then return end
]]):sub(2)
        .. after:sub(12567)

    after = after:sub(1, 11880)
        .. ([[!        or proofGetfenv(ownedValidationStamp)~=proofEnvironment or proofGetfenv(ownedDisabledDependency)~=proofEnvironment) then return end
]]):sub(2)
        .. after:sub(12020)

    after = after:sub(1, 11442)
        .. ([[!runtimeAuthority=function(owner,continuation)
    if not dependencyReader or not dependencyIdentity(owner,addon) then return end
    if continuation~=true and (proofRawget(owner,'GetRotationValidationOptions')~=ownedOptions
]]):sub(2)
        .. after:sub(11618)

    rows["Core/rotation_references.lua"] = { before = before, after = after }
end

return function(text, path, mode)
    if mode == nil then
        text = dofile('tests/fixtures/restore_execution_generation.lua')(text, path)
    end

    local row = rows[path]
    assert(row, "unknown continuation source path")

    if mode == "before" then
        assert(text == nil)
        return row.before
    end

    assert(mode == nil and text == row.after, "unrelated continuation source change: " .. path)
    return row.before
end
