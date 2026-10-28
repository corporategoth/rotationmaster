-- Strict additive inverse of the native hidden-string publication fix only.
local function hash(s)
    local n = 5381

    for i = 1, #s do
        n = (n * 33 + s:byte(i)) % 4294967296
    end

    return string.format('%08x', n)
end

local changes = {
    {
        current = [========[    -- Only an owned factory admission may consume this private capability.
    local guardType,guardPairs,guardGetmetatable,guardRawget=type,pairs,getmetatable,rawget
    local function makePublicationGuard(_,seal,c)
        local entry=readSeals[seal]
]========],
        previous = [========[    -- Only an owned factory admission may consume this private capability.
    local guardType,guardPairs,guardGetmetatable,guardRawget=type,pairs,getmetatable,rawget
    local stringMeta=guardGetmetatable('')
    local stringIndex=guardType(stringMeta)=='table' and guardRawget(stringMeta,'__index')
    local stringFind=guardType(stringIndex)=='table' and guardRawget(stringIndex,'find')
    local function makePublicationGuard(_,seal,c)
        local entry=readSeals[seal]
]========],
    },
    {
        current = [========[            if reader.IsCurrent~=ownedReaderIsCurrent or type~=guardType or pairs~=guardPairs
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
]========],
        previous = [========[            if reader.IsCurrent~=ownedReaderIsCurrent or type~=guardType or pairs~=guardPairs
                or getmetatable~=guardGetmetatable or rawget~=guardRawget then return nil end
            if guardType(stringIndex)~='table' or guardType(stringFind)~='function'
                or guardGetmetatable('')~=stringMeta or guardRawget(stringMeta,'__index')~=stringIndex
                or guardRawget(stringIndex,'find')~=stringFind then return nil end
            -- These retained scalar validators can call custom code. Finish
            -- them before checking the current lifetime/metadata/raw witnesses.
            if not plain(c) or not isClass(c.class) or c.class~=entry.context.class or c.character~=entry.context.character then return false end
            if not isClass(a.class) then return false end
            if readerState~='active' or readEpoch~=epoch or publicationWriteVersion~=writeVersion
                or not scope or scope.metadata[a.id]~=meta then return false end
            -- Preserve all raw state/header/container/component witnesses checked
            -- by readRows/privateRecord; omit only revalidating immutable private
            -- addresses and duplicate checks of the same plain class map/body.
            if not fields(state,stateFields) or state.version~=1 then return false end
            local classes,characters,legacy=state.classes,state.characters,state.legacy
]========],
    },
}

return function(text, path)
    if path ~= 'Data/rotation_store.lua' then
        return text
    end

    if text:find('local characterBucketFields=', 1, true) then
        text = dofile('tests/fixtures/restore_rotation_store_character_schema.lua')(text, path)
    end

    assert(#text == 40987 and hash(text) == '9d678565', 'unrelated native-store-guard source')

    for _, change in ipairs(changes) do
        local a, b = text:find(change.current, 1, true)
        assert(a and not text:find(change.current, b + 1, true), 'native-store-guard inverse anchor')
        text = text:sub(1, a - 1) .. change.previous .. text:sub(b + 1)
    end

    assert(#text == 41494 and hash(text) == '11e30f95', 'native-store-guard predecessor mismatch')
    return text
end
