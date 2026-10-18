local _,addon=...
local data=addon.RotationData
local function characters(text)
    local i,n=1,0
    while i<=#text do
        local a=text:byte(i);local width=a<128 and 1 or a>=194 and a<=223 and 2 or a>=224 and a<=239 and 3 or a>=240 and a<=244 and 4
        if not width or i+width-1>#text then return end
        for j=i+1,i+width-1 do local byte=text:byte(j);if byte<128 or byte>191 then return end end
        local b=text:byte(i+1)
        if a==194 and b>=128 and b<=159 then return end
        if width==3 and (a==224 and b<160 or a==237 and b>=160) or width==4 and (a==240 and b<144 or a==244 and b>=144) then return end
        n=n+1;i=i+width
    end
    return n
end
function data.NormalizeRotationTags(tags)
    if type(tags)~='table' or getmetatable(tags) then return nil,'invalid-tags' end
    local count=0;for key in pairs(tags) do if type(key)~='number' or key<1 or key%1~=0 or key>#tags then return nil,'invalid-tags' end;count=count+1 end
    if count~=#tags or count>64 then return nil,'tag-limit' end
    local normalized,seen={},{}
    for _,tag in ipairs(tags) do
        if type(tag)~='string' or tag:find('%c') then return nil,'invalid-tag' end
        local text=tag:match('^%s*(.-)%s*$');local length=characters(text);if not length or length==0 or length>64 then return nil,'tag-length' end
        local key=text:lower();if not seen[key] then normalized[#normalized+1]=text;seen[key]=true end
    end
    return normalized
end
function data.ParseRotationTags(text)
    if type(text)~='string' or #text>32768 then return nil,'tag-limit' end
    local tags,parts={},{};local quoted,closed=false,false;local i=1
    local function finish()
        local value=table.concat(parts):match('^%s*(.-)%s*$');if value~='' then tags[#tags+1]=value end;parts={};closed=false
    end
    while i<=#text do
        local ch=text:sub(i,i)
        if quoted then
            if ch=='"' then if text:sub(i+1,i+1)=='"' then parts[#parts+1]='"';i=i+1 else quoted=false;closed=true end else parts[#parts+1]=ch end
        elseif ch==',' or ch=='\n' or ch=='\r' then finish()
        elseif ch=='"' then if closed or table.concat(parts):find('%S') then return nil,'invalid-tag-quotes' end;parts={};quoted=true
        elseif closed and ch:find('%S') then return nil,'invalid-tag-quotes'
        else parts[#parts+1]=ch end
        i=i+1
    end
    if quoted then return nil,'invalid-tag-quotes' end;finish();return data.NormalizeRotationTags(tags)
end
function data.FormatRotationTags(tags)
    local normalized,why=data.NormalizeRotationTags(tags);if not normalized then return nil,why end
    local parts={};for _,tag in ipairs(normalized) do parts[#parts+1]=tag:find('[,"]') and '"'..tag:gsub('"','""')..'"' or tag end;return table.concat(parts,', ')
end
function data.GetRotationTags(value)
    if type(value)~='table' then return {} end
    local body=type(value.body)=='table' and value.body or value
    local tags=body.tags;if tags==nil then tags=value.tags end
    if tags==nil then return {} end
    return data.NormalizeRotationTags(tags)
end
function data.RotationTagMatches(tags,tag)
    if not tag then return true end
    for _,value in ipairs(tags or {}) do if value:lower()==tag:lower() then return true end end;return false
end
-- Compare effective labels once, regardless of whether they are inherited or
-- explicitly stored. This detached view never materializes tags in saved data.
function data.RotationComparisonValue(body,inheritedTags)
    local copy,why=data.CopyData(body);if not copy then return nil,why end
    local tags=data.GetRotationTags({body=copy,tags=inheritedTags}) or {}
    copy.tags=nil
    return {body=copy,tags=tags}
end
function data.RotationSearchText(value,displayName,displayDescription)
    local body=type(value)=='table' and (type(value.body)=='table' and value.body or value) or {}
    local text={type(displayName)=='string' and displayName or type(body.name)=='string' and body.name or '',type(displayDescription)=='string' and displayDescription or type(body.description)=='string' and body.description or ''}
    for _,tag in ipairs(data.GetRotationTags(value) or {}) do text[#text+1]=tag end
    if type(body.metadata)=='table' then for _,field in ipairs({'author','realm','email','website','version'}) do if type(body.metadata[field])=='string' then text[#text+1]=body.metadata[field] end end end
    if type(value)=='table' and type(value.sources)=='table' then for _,source in ipairs(value.sources) do if type(source)=='table' then for _,field in ipairs({'title','url','publisher','author'}) do if type(source[field])=='string' then text[#text+1]=source[field] end end end end end
    return table.concat(text,' '):lower()
end
