-- Exact inverse of accepted 810d79f/e7bdf65 schema-map reuse; predecessor assertions remain unchanged.
local pairs={
 {[====[local addressFields={scope=true,class=true,owner=true,spec=true,id=true}
local stateFields={version=true,classes=true,characters=true,legacy=true}
local recordFields={body=true,origin=true,imported=true,comparison=true}
]====],[====[]====]},
 {[====[return fields(a,addressFields) and isClass]====],[====[return fields(a,{scope=true,class=true,owner=true,spec=true,id=true}) and isClass]====]},
 {[====[if not fields(record,recordFields) or not plain(record.body) or not data.CheckPortable]====],[====[if not fields(record,{body=true,origin=true,imported=true,comparison=true}) or not plain(record.body) or not data.CheckPortable]====]},
 {[====[if not fields(state,stateFields) or state.version~=1 or not plain(state.classes) or not plain(state.characters) then]====],[====[if not fields(state,{version=true,classes=true,characters=true,legacy=true}) or state.version~=1 or not plain(state.classes) or not plain(state.characters) then]====]},
 {[====[if not fields(state,stateFields) or state.version~=1
]====],[====[if not fields(state,{version=true,classes=true,characters=true,legacy=true}) or state.version~=1
]====]},
 {[====[if not fields(record,recordFields) or not plain(record.body) then]====],[====[if not fields(record,{body=true,origin=true,imported=true,comparison=true}) or not plain(record.body) then]====]},
}
local function hash(s)local h=0;for i=1,#s do h=(h*33+s:byte(i))%4294967296 end;return string.format("%08x",h)end
return function(text)
 assert(type(text)=="string"and #text==36975 and hash(text)=="1801f0e3","unexpected complete rotation store schema-map source")
 for _,pair in ipairs(pairs)do local first,last=text:find(pair[1],1,true);assert(first and not text:find(pair[1],last+1,true),"missing or duplicate schema-map hunk");text=text:sub(1,first-1)..pair[2]..text:sub(last+1)end
 assert(#text==36964 and hash(text)=="64c496e7","rotation store predecessor drift")
 return text
end
