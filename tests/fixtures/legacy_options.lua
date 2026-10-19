-- Exercise retained historical closures explicitly. Public native routes are
-- covered by scoped UI tests and must never fall back to these old bodies.
return function(f,path)
    local markers={['Options/general.lua']='-- Historical renderer closures',
        ['Options/rotations.lua']='-- Preserve captured legacy helpers'}
    local file=assert(io.open(path));local source=file:read('*a');file:close()
    local start=assert(source:find(assert(markers[path]),1,true))
    local chunk=assert(loadstring(source:sub(1,start-1)));setfenv(chunk,f.env)
    return chunk('rotationmaster',f.addon)
end
