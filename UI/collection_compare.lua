local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end;return true
end
local function scalar(value)
    if value==nil then return L['None'] end
    if type(value)=='boolean' then return value and L['Yes'] or L['No'] end
    if type(value)=='number' then return string.format('%.4g',value) end
    return tostring(value)
end
local function color(value)
    if type(value)~='table' then return scalar(value) end
    return string.format('R %.3f  G %.3f  B %.3f  A %.3f',value.r or 1,value.g or 1,value.b or 1,value.a or 1)
end
function addon:CollectionComparisonRows(kind,left,right,showSame)
    local rows={};local total=0
    local function add(label,a,b,format,icons)
        local changed=not equal(a,b);if changed then total=total+1 end
        if changed or showSame then rows[#rows+1]={label=label,left=(format or scalar)(a),right=(format or scalar)(b),changed=changed,leftIcon=icons and icons(a),rightIcon=icons and icons(b)} end
    end
    add(L['Name'],left.name,right.name)
    if kind=='profile' then
        local labels={lua_editor=L['Lua editor'],identifier=L['Identifier'],definition=L['Definition'],enable=L['Enable'],poll=L['Polling Interval (seconds)'],idle_poll=L['Idle Re-check Interval (seconds)'],autoswitch_poll=L['Auto-Switch Re-check Interval (seconds)'],ignore_mana=L['Ignore mana'],ignore_range=L['Ignore range'],effect=L['Effect'],color=L['Highlight Color'],magnification=L['Magnification'],setpoint=L['Anchor'],xoffs=L['H'],yoffs=L['V'],loglevel=L['Log Level'],detailed_profiling=L['Detailed Profiling'],disable_autoswitch=L['Disable Auto-Switching'],live_config_update=L['Live Status Update Frequency (seconds)'],spell_history=L['Spell History Memory (seconds)'],combat_history=L['Combat History Memory (seconds)'],damage_history=L['Damage History Memory (seconds)'],disable_buttons=L['Disable Bar Highlighting'],rotation_view=L['Default rotation view'],preview_spells=L['Preview Spells'],preview_window=L['Preview position'],minimap=L['Minimap Icon'],rotations=L['Rotations'],rotationLibrary=L['Rotation library'],itemsets=L['Item Sets'],announces=L['Announces'],outputs=L['Outputs'],channel_name=L['Channel'],condition_groups=L['Categories'],switch_conditions=L['Switch conditions'],other_conditions_order=L['Other'],disabled_conditions=L['Hidden'],name=L['Name'],description=L['Description'],conditions=L['Conditions'],rotation=L['Rotation'],cooldowns=L['Cooldowns'],type=L['Type'],action=L['Action'],unit=L['Unit'],value=L['Value'],spell=L['Spell'],item=L['Item'],items=L['Items'],disabled=L['Disabled'],announce=L['Announce'],event=L['Event'],announce_sound=L['Sound'],emote=L['Emote'],emote_target=L['Use spell recipient ({{target}})'],ranked=L['Use this exact spell rank'],use_name=L['Use step name'],suppress_attack=L['Also suppress auto-attack (Attack or Shoot)'],preview_vertical=L['Vertical'],preview_locked=L['Lock position and size'],preview_opacity=L['Preview window opacity'],preview_icon_size=L['Preview icon size'],preview_masque=L['Skin preview buttons with Masque'],evaluate=L['Evaluate'],valid=L['Validate'],print=L['Summary'],widget=L['Fields UI'],help=L['Help'],on_register=L['On register'],on_unregister=L['On unregister'],preferences=L['Built In preferences'],origins=L['Clone sources'],comparisons=L['Comparison history'],imports=L['Imports']}
        local function plain(key,a,b)
            if labels[key] then return labels[key] end
            local record=type(a)=='table' and a or type(b)=='table' and b
            if record and type(record.name)=='string' then return record.name end
            if type(key)=='number' then return tostring(key) end
            local definition=(self.conditionDefinitions or {})[key];if definition then return definition.description or key end
            return tostring(key):gsub('_',' '):gsub('(%l)(%u)','%1 %2')
        end
        local function walk(a,b,prefix,depth)
            if equal(a,b) and not showSame then return end
            if depth>=12 or type(a)~='table' and type(b)~='table' then add(prefix,a,b);return end
            if a~=nil and type(a)~='table' or b~=nil and type(b)~='table' then add(prefix,type(a)=='table' and L['Structured settings'] or a,type(b)=='table' and L['Structured settings'] or b);return end
            local seen,keys={},{};for key in pairs(a or {}) do seen[key]=true;keys[#keys+1]=key end;for key in pairs(b or {}) do if not seen[key] then keys[#keys+1]=key end end;table.sort(keys,function(x,y) return tostring(x)<tostring(y) end)
            for _,key in ipairs(keys) do local av,bv=a and a[key],b and b[key];local name=plain(key,av,bv);walk(av,bv,prefix~='' and prefix..' / '..name or name,depth+1) end
        end
        walk(left.profile or {},right.profile or {},'',0)
    elseif kind=='announcement' then
        if not left.outputs and not right.outputs then
        add(L['Conditions'],left.conditions,right.conditions,function(value) return self:DescribeCondition(value or {},self.currentSpec) end)
        for _,field in ipairs({{'type','Action Type'},{'identifier','Identifier'},{'event','Event'},{'announce','Announce'},{'value','Text'},{'emote','Emote'},{'emote_target','Use spell recipient ({{target}})'},{'announce_sound','Sound'},{'disabled','Disabled'},{'ranked','Use this exact spell rank'}}) do add(L[field[2]],left[field[1]],right[field[1]]) end
        else
            for _,field in ipairs({{'type','Action Type'},{'identifier','Identifier'},{'event','Event'},{'disabled','Disabled'},{'ranked','Use this exact spell rank'}})do add(L[field[2]],left[field[1]],right[field[1]])end
            local first,second=left.outputs or {left},right.outputs or {right}
            for i=1,math.max(#first,#second)do
                local a,b=first[i],second[i];local title=string.format(L['Output %d'],i)..' / '
                add(title..L['Output'],a~=nil,b~=nil)
                for _,field in ipairs({{'announce','Announce'},{'value','Text'},{'announce_sound','Sound'},{'emote','Emote'},{'emote_target','Use spell recipient ({{target}})'},{'channel_name','Channel'}})do add(title..L[field[2]],a and a[field[1]],b and b[field[1]])end
                local ad,bd;if left.outputs and a then ad=a.disabled end;if right.outputs and b then bd=b.disabled end
                add(title..L['Disabled'],ad,bd)
                add(title..L['Conditions'],a and a.conditions,b and b.conditions,function(value)return self:DescribeCondition(value or {},self.currentSpec)end)
            end
        end
        local function spell(id) return id and self:PlainWorkbenchName(self:SpellLabel(id))..' ('..tostring(id)..')' or L['None'] end
        add(L['Spell'],left.spell,right.spell,spell)
        local function items(value) if type(value)~='table' then return scalar(value) end;local parts={};local provider=self:GetReferenceProvider('item');for _,id in ipairs(value) do parts[#parts+1]=(provider.name(tonumber(id) or provider.resolve(id)) or L['Item data loading'])..' ('..tostring(id)..')' end;return table.concat(parts,'\n') end
        add(L['Items'],left.item,right.item,items)
    elseif kind=='itemset' then
        local provider=self:GetReferenceProvider('item')
        local function info(value) return value and provider.info(tonumber(value) or provider.resolve(value)) end
        local function name(value)
            if value==nil then return L['None'] end
            local record=info(value);local friendly=record and record.name or L['Item data loading']
            local identity=type(value)=='number' and string.format(L['Item ID: %s'],tostring(value)) or string.format(L['Item reference: %s'],tostring(value))
            return friendly..'\n'..identity
        end
        local function icon(value) local record=info(value);return record and record.icon end
        local a,b=left.items or {},right.items or {};for i=1,math.max(#a,#b) do add(string.format(L['Item %d'],i),a[i],b[i],name,icon) end
    else
        for _,field in ipairs({{'type','Type'},{'texture','Texture'},{'lines','Lines'},{'frequency','Frequency'},{'length','Length'},{'thickness','Thickness'},{'particles','Particles'},{'scale','Scale'},{'steps','Steps'},{'reverse','Reverse'}}) do if left[field[1]]~=nil or right[field[1]]~=nil then add(L[field[2]],left[field[1]],right[field[1]]) end end
        local function entry(value,kind)
            if value==nil then return L['None'] end
            if kind=='custom' and type(value)=='table' then return L['Texture']..': '..scalar(value.texture)..'\n'..L['Angle']..': '..scalar(value.angle)..'\n'..L['Magnification']..': '..scalar(value.magnification)..'\n'..color(value.color) end
            if kind=='dazzle' then return color(value) end;return scalar(value)
        end
        local a,b=left.sequence or {},right.sequence or {}
        for i=1,math.max(#a,#b) do
            local changed=not equal(a[i],b[i]) or left.type~=right.type;if changed then total=total+1 end
            if changed or showSame then rows[#rows+1]={label=string.format(L['Step %d'],i),left=entry(a[i],left.type),right=entry(b[i],right.type),changed=changed,leftIcon=left.type=='animate' and a[i] or left.type=='custom' and type(a[i])=='table' and a[i].texture or nil,rightIcon=right.type=='animate' and b[i] or right.type=='custom' and type(b[i])=='table' and b[i].texture or nil} end
        end
    end
    return rows,total
end
function addon:ShowCollectionComparison(p,kind,left,right,options)
    options=options or {}
    local d=p.comparison
    if not d then
        d={frame=CreateFrame('Frame',nil,UIParent),cells={}};p.comparison=d;local frame=d.frame;frame:SetSize(760,520);frame:SetPoint('CENTER');frame:SetFrameStrata('FULLSCREEN_DIALOG');frame:SetToplevel(true);frame:SetClampedToScreen(true);frame:EnableMouse(true);self:MakeWindowOpaque(frame)
        d.title=frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.chrome=self:CreateWorkbenchDialogChrome(frame,d.title)
        d.leftHeading=frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.leftHeading:SetPoint('TOPLEFT',12,-64);d.rightHeading=frame:CreateFontString(nil,'OVERLAY','GameFontNormal');d.rightHeading:SetPoint('TOPLEFT',366,-64)
        d.close=self:CreateWorkbenchIconButton(frame,'close',L['Close']);d.close:SetPoint('TOPRIGHT',-5,-5);self:SetUIScript(d.close,'OnClick',function() frame:Hide() end)
        d.toggle=self:CreateWorkbenchCheckBox(frame,L['Show unchanged'],220);d.toggle:SetPoint('TOPLEFT',12,-34)
        d.scroll=self:CreateWorkbenchScrollFrame(frame);d.scroll:SetPoint('TOPLEFT',12,-86);d.scroll:SetSize(718,398);d.child=CreateFrame('Frame',nil,d.scroll);d.child:SetWidth(700);d.scroll:SetScrollChild(d.child)
        self:SetUIScript(frame,'OnMouseUp',function(_,button) if button=='RightButton' then frame:Hide() end end);self:SetUIScript(d.scroll,'OnMouseUp',function(_,button) if button=='RightButton' then frame:Hide() end end)
        frame:Hide()
    end
    d.serial=(d.serial or 0)+1;local serial=d.serial
    local token=p.generation;local function valid() return p:Valid(token) and d.serial==serial end;local first,second=self:CopySettingsData(left),self:CopySettingsData(right);local showSame=false
    local function draw()
        if not valid() then return end
        local rows,changes;if options.rows then rows,changes=options.rows(first,second,showSame) else rows,changes=self:CollectionComparisonRows(kind,first,second,showSame) end;d.rows=rows;d.toggle:SetChecked(showSame)
        local y=0;local n=0
        local function cell(value,x,width,height,tone,icon)
            n=n+1;local c=d.cells[n];if not c then c=CreateFrame('Frame',nil,d.child);c.art=c:CreateTexture(nil,'BACKGROUND');c.art:SetAllPoints(c);c.text=c:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');c.text:SetJustifyH('LEFT');c.text:SetJustifyV('TOP');c.text:SetWordWrap(true);c.icon=c:CreateTexture(nil,'ARTWORK');c.icon:SetPoint('TOPLEFT',5,-4);c.icon:SetSize(24,24);d.cells[n]=c end
            c:ClearAllPoints();c:SetPoint('TOPLEFT',x,-y);c:SetSize(width,height);c.art:SetColorTexture(tone[1],tone[2],tone[3],.3);c.text:ClearAllPoints();c.text:SetPoint('TOPLEFT',icon and 34 or 6,-4);c.text:SetWidth(width-(icon and 40 or 12));c.text:SetHeight(0);c.text:SetText(value);c:Show();if icon then c.icon:SetTexture(icon);c.icon:Show() else c.icon:Hide() end;return c
        end
        for _,row in ipairs(rows) do
            cell(row.label,0,132,24,{.18,.18,.18});y=y+24
            local height=math.max(34,16*(1+select(2,row.left:gsub('\n',''))),16*(1+select(2,row.right:gsub('\n',''))))+8
            local a=cell(row.left,0,346,height,row.changed and {.4,.16,.16} or {.18,.18,.18},row.leftIcon);local b=cell(row.right,354,346,height,row.changed and {.16,.35,.2} or {.18,.18,.18},row.rightIcon);height=math.max(height,a.text:GetStringHeight()+8,b.text:GetStringHeight()+8);a:SetHeight(height);b:SetHeight(height);y=y+height+10
        end
        if #rows==0 then cell(L['No differences.'],0,700,30,{.18,.18,.18});y=38 end
        for i=n+1,#d.cells do d.cells[i]:Hide() end;d.child:SetHeight(math.max(1,y));d.scroll:UpdateWorkbenchScroll();d.chrome.author:SetText(string.format(L['Changed fields: %d'],changes))
    end
    d.chrome:SetContext(options.title or L['Compare']..': '..(left.name or '')..' / '..(right.name or ''),L['Read-only'],addon.pretty_name);d.leftHeading:SetText(options.leftHeading or left.name or L['Selected entry']);d.rightHeading:SetText(options.rightHeading or right.name or L['Compared entry'])
    self:SetUIScript(d.frame,'OnUpdate',function() if not valid() then d.frame:Hide() end end)
    self:SetUIScript(d.toggle,'OnClick',function() if valid() then showSame=not showSame;draw() end end)
    p.cleanups[#p.cleanups+1]=function() d.frame:Hide() end;d.frame:Show();self:RegisterWindowForEscape(d);draw();return d
end
