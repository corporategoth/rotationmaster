local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local types={{value='texture',text=L['Texture']},{value='pixel',text=L['Pixel']},{value='autocast',text=L['Auto Cast']},{value='blizzard',text=L['Glow']},{value='dazzle',text=L['Dazzle']},{value='animate',text=L['Animate']},{value='pulse',text=L['Pulse']},{value='rotate',text=L['Rotate']},{value='custom',text=L['Custom']}}
local schemas={pixel={{'lines','Lines',8,1,20,1},{'frequency','Frequency',.25,-1.5,1.5,.05},{'length','Length',2,1,20,1},{'thickness','Thickness',2,1,5,1}},autocast={{'particles','Particles',4,1,4,1},{'frequency','Frequency',.125,-1.5,1.5,.05},{'scale','Scale',1,.25,5,.25}},blizzard={{'frequency','Frequency',.125,0,1.5,.05}},dazzle={{'frequency','Frequency',.25,.1,5,.05}},animate={{'frequency','Frequency',.25,.1,5,.05}},pulse={{'frequency','Frequency',.25,.1,5,.05}},custom={{'frequency','Frequency',.25,.1,5,.05}},rotate={{'frequency','Frequency',.25,.1,5,.05},{'steps','Steps',4,2,36,1}}}
local function defaults(effect)
    for _,entry in ipairs(schemas[effect.type] or {}) do local v=effect[entry[1]];if type(v)~='number' or v~=v or v<entry[4] or v>entry[5] then effect[entry[1]]=entry[3] end end
    if effect.type=='dazzle' or effect.type=='animate' or effect.type=='pulse' or effect.type=='custom' then effect.sequence=effect.sequence or {} end
end
local function validEffect(effect)
    if type(effect)~='table' or type(effect.name)~='string' or not effect.name:find('%S') then return false end
    local known=false;for _,entry in ipairs(types) do known=known or entry.value==effect.type end;if not known then return false end
    for _,entry in ipairs(schemas[effect.type] or {}) do local v=effect[entry[1]];if v~=nil and (type(v)~='number' or v~=v or v<entry[4] or v>entry[5]) then return false end end
    if effect.texture~=nil and type(effect.texture)~='string' and type(effect.texture)~='number' then return false end
    if effect.sequence~=nil then
        if type(effect.sequence)~='table' or #effect.sequence>256 then return false end
        for _,entry in ipairs(effect.sequence) do
            if effect.type=='pulse' then if type(entry)~='number' or entry~=entry or entry<.1 or entry>2 then return false end
            elseif effect.type=='animate' then if type(entry)~='string' and type(entry)~='number' then return false end
            elseif effect.type=='dazzle' or effect.type=='custom' then
                local color=effect.type=='custom' and type(entry)=='table' and entry.color or entry
                if type(color)~='table' then return false end;for _,key in ipairs({'r','g','b','a'}) do if type(color[key])~='number' or color[key]~=color[key] or color[key]<0 or color[key]>1 then return false end end
                if effect.type=='custom' and ((type(entry.texture)~='string' and type(entry.texture)~='number') or type(entry.angle or 0)~='number' or (entry.angle or 0)~=(entry.angle or 0) or math.abs(entry.angle or 0)==math.huge or type(entry.magnification)~='number' or entry.magnification~=entry.magnification or entry.magnification<.1 or entry.magnification>2) then return false end
            end
        end
    end
    return true
end
function addon:IsValidEffectDefinition(value) return validEffect(value) end
function addon:BuildEffectSettings(p)
    local store=p:SettingsData()
    local effects=store.global.effects or {};local entries=self:SettingsEntries(effects)
    for _,entry in ipairs(entries) do local effect=effects[entry.value];entry.icon=effect.texture or self:ControlTexture('preview');entry.search=effect.type end
    if not effects[p.selection] and not p.creating then p.selection=entries[1] and entries[1].value end
    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,{newText=L['Add effect'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.newEffect=nil;p.emptyDismissed=false;p:Draw() end});p:Heading(L['Effects'])
    local isNew=p.creating or not effects[p.selection] and p:CanAutoCreateCollection('global','effects')
    if isNew then p.newEffect=p.newEffect or {name='',type='pixel'} end
    local effect=isNew and p.newEffect or effects[p.selection]
    if effect then
        local id=isNew and 'draft' or p.selection
        local function refresh() if self.RemoveAllCurrentGlows then self:RemoveAllCurrentGlows() end;if p.preview and self.HideGlow then self:HideGlow(p.preview,'settings-effect') end;if p.preview and self.Glow then self:Glow(p.preview,'settings-effect',effect,{r=1,g=1,b=1,a=1},1,'CENTER',0,0) end end
        local y=p.y;local preview=p:Acquire('effectPreview',function() return CreateFrame('Frame',nil,p.child) end);preview:ClearAllPoints();preview:SetPoint('TOPLEFT',174,-y-8);preview:SetSize(40,40);p.preview=preview
        p.cleanups[#p.cleanups+1]=function() if self.HideGlow then self:HideGlow(preview,'settings-effect') end end
        p:Edit('name',L['Name'],effect.name or '',nil,function(text) effect.name=text;p:UpdateRosterEntry(id,{text=effect.name,search=effect.type,icon=effect.texture or self:ControlTexture('preview')}) end)
        p:Choice('type',L['Type'],effect.type,types,function(value)
            if value==effect.type then return end
            local candidate=self:CopySettingsData(effect);candidate.type=value;candidate.sequence=nil;defaults(candidate)
            -- A new sequence kind has different entry shapes. Stage its valid
            -- empty sequence before replacing the saved object or previewing.
            if isNew then p.newEffect=candidate else effects[id]=candidate end;effect=candidate;refresh();p:Draw()
        end)
        if effect.type=='texture' or effect.type=='dazzle' or effect.type=='pulse' or effect.type=='rotate' then p:Edit('texture',L['Texture'],effect.texture or '',nil,function(value) effect.texture=tonumber(value) or value;refresh();p:UpdateRosterEntry(id,{text=effect.name,search=effect.type,icon=effect.texture or self:ControlTexture('preview')}) end) end
        for _,entry in ipairs(schemas[effect.type] or {}) do local key=entry[1];p:Slider(key,L[entry[2]],effect[key] or entry[3],entry[4],entry[5],entry[6],function(value) effect[key]=value;refresh() end) end
        if effect.type=='rotate' then p:Check('reverse',L['Reverse'],effect.reverse,function(value) effect.reverse=value;refresh() end) end
        if effect.type=='dazzle' or effect.type=='animate' or effect.type=='pulse' or effect.type=='custom' then
            p:Heading(L['Sequence'])
            do
                local sequence=effect.sequence or {}
                p:OrderedCollection('sequence_'..id,sequence,function() local label;for _,t in ipairs(types) do if t.value==effect.type then label=t.text end end;return label or L['Effect'] end,function(p,i,entry)
                    if effect.type=='pulse' then p:Slider('seq'..i,L['Magnification'],entry,.1,2,.1,function(v) sequence[i]=v;refresh() end)
                    elseif effect.type=='animate' then p:Texture('seq'..i,L['Texture'],entry,function(v) sequence[i]=tonumber(v) or v;refresh() end)
                    elseif effect.type=='dazzle' then p:Color('seq'..i,L['Color'],entry,function(v) sequence[i]=v;refresh() end)
                    else
                        p:Texture('seq'..i..'texture',L['Texture'],entry.texture or '',function(v) entry.texture=tonumber(v) or v;refresh() end)
                        p:Slider('seq'..i..'angle',L['Angle'],entry.angle or 0,0,359,1,function(v) entry.angle=v;refresh() end)
                        p:Slider('seq'..i..'mag',L['Magnification'],entry.magnification or 1,.1,2,.1,function(v) entry.magnification=v;refresh() end)
                        p:Color('seq'..i..'color',L['Color'],entry.color,function(v) entry.color=v;refresh() end)
                    end
                end,refresh,{prefix='seq',header=false,dragIcon=function(i) return effect.type=='animate' and sequence[i] or effect.type=='custom' and sequence[i].texture or effect.texture end,endPreview=function(ghost) if ghost.effectPreview and self.HideGlow then self:HideGlow(ghost.effectPreview,'settings-drag') end end,dragPreview=function(ghost,i)
                    ghost.effectPreview=ghost.effectPreview or CreateFrame('Frame',nil,ghost);ghost.effectPreview:ClearAllPoints();ghost.effectPreview:SetPoint('TOPLEFT',8,-8);ghost.effectPreview:SetSize(28,28);ghost.effectPreview:Show()
                    if self.HideGlow then self:HideGlow(ghost.effectPreview,'settings-drag') end
                    if self.Glow then local selected=self:CopySettingsData(effect);selected.sequence={self:CopySettingsData(sequence[i])};self:Glow(ghost.effectPreview,'settings-drag',selected,{r=1,g=1,b=1,a=1},1,'CENTER',0,0) end
                end,dragSummary=function(i) local e=sequence[i];return effect.type=='pulse' and L['Magnification']..': '..tostring(e) or effect.type=='animate' and L['Texture']..': '..tostring(e) or effect.type=='custom' and L['Texture']..': '..tostring(e.texture)..' / '..L['Magnification']..': '..tostring(e.magnification) or L['Color'] end})
                p:Button('sequence_add',L['Add step'],function()
                    effect.sequence=effect.sequence or {};local value=effect.type=='pulse' and 1 or effect.type=='animate' and '' or effect.type=='dazzle' and {r=1,g=1,b=1,a=1} or {texture='',angle=0,color={r=1,g=1,b=1,a=1},magnification=1}
                    effect.sequence[#effect.sequence+1]=value;refresh();p:Draw()
                end,'plus')
            end
        end
        local actionEntries={{key='duplicate',text=L['Duplicate'],icon='copy',action=function() local nextId=self:uuid();effects[nextId]=self:CopySettingsData(effect);effects[nextId].name=string.format(L['Copy of %s'],effect.name or id);p.selection=nextId;p:Draw() end},
            {key='transfer',text=L['Import/Export'],icon='transfer',action=function()
                local codec=self:NewRotationCodec();local text,why=codec:Encode(effect);if not text then p:Message(why);return end
                self:ShowSettingsTextTransfer(p,L['Effect'],text,function(input,settings)
                    local decoded,errorCode=codec:Decode(input);if not decoded or not validEffect(decoded.value) then return false,errorCode or L['Invalid effect.'] end
                    local value=self:CopySettingsData(decoded.value);local name=settings.mode=='new' and settings.name or effect.name
                    for other,record in pairs(effects) do if (settings.mode=='new' or other~=id) and record.name==name then return false,L['This name is already in use.'] end end;value.name=name
                    if settings.mode=='new' then local generated=self:uuid();store.global.effects=store.global.effects or {};store.global.effects[generated]=value;p.selection=generated;p.creating=false;p.newEffect=nil
                    elseif isNew then p.newEffect=value else effects[id]=value end;refresh();return true
                end,{canReplace=not isNew,selectedName=effect.name,fallbackName=L['Imported effect'],originalName=function(input) local decoded=codec:Decode(input);return decoded and type(decoded.value)=='table' and decoded.value.name end})
            end},
            {key='delete',text=L['Delete'],icon='trash',action=function() p:Confirm(L['Delete this effect? Rotations using it will need another effect.'],function() effects[id]=nil;refresh();p:Draw() end) end}}
        actionEntries[1].enabled=not isNew;self:CollectionFooter(p,'effect',effects,isNew and nil or id,actionEntries[1],actionEntries[2]);if not isNew then self:SettingsTopDelete(p,actionEntries[3].action) end
        refresh()
    end
    if isNew then
        p.fields.new_name=p.fields.name;p.fields.new_type=p.fields.type
        p:CreationActions(function()
            if not self:SettingsNonempty(p.newEffect.name) then p:Message(L['Enter a name first.']);return end
            if not validEffect(p.newEffect) then p:Message(L['Complete the effect settings before applying.']);return end
            for _,value in pairs(effects) do if value.name==p.newEffect.name then p:Message(L['This name is already in use.']);return end end
            local id=self:uuid();store.global.effects=store.global.effects or {};store.global.effects[id]=self:CopySettingsData(p.newEffect);defaults(store.global.effects[id]);p.selection=id;p.creating=false;p.newEffect=nil;p:Draw()
        end,function() p.creating=false;p.selection=p.previousSelection;p.newEffect=nil;p.emptyDismissed=true;p:Draw() end)
    elseif not effect then
        self:CollectionFooter(p,'effect',effects,nil,{key='duplicate',text=L['Duplicate'],icon='copy',enabled=false,action=function() end},{key='transfer',text=L['Import/Export'],icon='transfer',action=function()
            local codec=self:NewRotationCodec();self:ShowSettingsTextTransfer(p,L['Effect'],'',function(input,settings) local decoded,why=codec:Decode(input);if not decoded or not validEffect(decoded.value) then return false,why or L['Invalid effect.'] end;p.newEffect=decoded.value;p.newEffect.name=settings.name;p.creating=true;return true end,{fallbackName=L['Imported effect'],originalName=function(input) local decoded=codec:Decode(input);return decoded and type(decoded.value)=='table' and decoded.value.name end})
        end})
    end
end
