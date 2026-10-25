-- The rotation editor's header, two rows:
--   row 1  [specialization] [name ........................] [Metadata]
--   row 2  [kind] [ID  Priority] [Enabled  Delete]       (wraps by group)
-- where the kind is the Read-Only pill on a Built In and Undo + Redo on your
-- own rotation (the Default is editable, so it carries Undo and Redo too). For the Default, a Built In (with and without a Reset to
-- default button) and your own rotation, in English, German and Russian, at
-- the narrowest window (800 px) and a normal one, every visible control
-- sits inside the pane and on none of the others; the specialization
-- picker is the first control of row 1; the name field has no label; and
-- when row 2 does not fit it wraps whole groups in a fixed order.
-- Geometry is resolved from the real anchors (tests/fixtures/layout_audit.lua);
-- text is measured per character (7 px, wider than the client's font).
local T=dofile('tests/fixtures/toc_addon.lua')
local F=dofile('tests/fixtures/addon.lua')
local audit=dofile('tests/fixtures/layout_audit.lua')
local test,finish=F.suite()
local WIDTHS={min=800-24-210-18,normal=1120-24-270-18}
local HELP_RESERVE=22
local function characters(text) local n=0;for _ in (text or ''):gmatch('[^\128-\191]') do n=n+1 end return n end
local function key(a,id) return a:GetScopedRotationCoordinator():Key({kind='builtin',id=id}) end
local function custom(f,spec,name)
    local a=f.addon;local ref=assert(a:NewRotationDraftTarget(spec,'class'))
    local body={name=name,specs={spec},switch={type='COMBAT',unit='player'},rotation={{id='a1',type='assisted',conditions={}}},cooldowns={}}
    assert(a:CommitRotationDraft(ref,nil,{body=body},'class'))
    return a:GetScopedRotationCoordinator():Key(ref)
end
local function open(language,case,width)
    local f=T.new{level=10,specIndex=1};local a=f.addon
    if language~='enUS' then f.env.GetLocale=function() return language end;f.load('Locales/'..language..'.lua') end
    local id
    if case=='default' then id=f.env.DEFAULT
    elseif case=='mine' then id=custom(f,268,'Mine')
    else id=key(a,'rm.retail.monk.brewmaster') end
    if case=='builtin overridden' then assert(a:SetBuiltinPriority('rm.retail.monk.brewmaster',33)) end
    local parent=f.env.CreateFrame('Frame');parent:SetSize(width,420);parent.rmHelpReserve=HELP_RESERVE
    local pane=assert(a:CreateRotationEditor(parent,268,id))
    for _,frame in ipairs(f.nativeFrames or {}) do
        if frame.kind=='FontString' then function frame:GetStringWidth() return characters(self.text)*7 end end
    end
    for _,label in ipairs({pane.identifierLabel,pane.priorityLabel}) do function label:GetStringWidth() return characters(self.text)*7 end end
    pane:Layout()
    return f,pane
end
local function controls(pane)
    local list={{'picker',pane.specButton},{'name',pane.name},{'metadata',pane.info},{'read-only pill',pane.readOnlyPill},{'undo',pane.undo},{'redo',pane.redo},
        {'id label',pane.identifierLabel},{'id',pane.identifier},{'priority label',pane.priorityLabel},{'priority down',pane.priorityDown},{'priority',pane.priority},{'priority up',pane.priorityUp},
        {'reset',pane.overrideReset},{'enabled',pane.enable},{'delete',pane.delete},{'switch heading',pane.switchLabel}}
    return list
end
local function check(pane,label,case,nameMinimum)
    local root=pane.frame;local resolve=audit.resolver(root);local seen,byName={},{}
    for _,item in ipairs(controls(pane)) do
        if item[2]:IsShown() then
            local rect=assert(resolve(item[2]),label..': '..item[1]..' has no position')
            assert(rect.right>rect.left,string.format('%s: %s has no width [%.1f..%.1f]',label,item[1],rect.left,rect.right))
            assert(rect.left>=-.5 and rect.right<=root.width+.5,string.format('%s: %s leaves the pane [%.1f..%.1f] of %d',label,item[1],rect.left,rect.right,root.width))
            seen[#seen+1]={item[1],rect};byName[item[1]]=rect
        end
    end
    for i=1,#seen do for j=i+1,#seen do
        local a,b=seen[i][2],seen[j][2]
        assert(not (a.left<b.right-.5 and b.left<a.right-.5 and a.bottom<b.top-.5 and b.bottom<a.top-.5),
            string.format('%s: %s [%.1f..%.1f] overlaps %s [%.1f..%.1f]',label,seen[i][1],a.left,a.right,seen[j][1],b.left,b.right))
    end end
    -- Nothing sits under the help icon's corner on row 1.
    assert(byName.metadata.right<=root.width-8-HELP_RESERVE+.5,label..': Metadata is under the help icon')
    -- Row 1: the picker first, then the name, then Metadata, all on one line.
    local picker,name,info=byName.picker,byName.name,byName.metadata
    assert(picker and picker.left<name.left and name.right<=info.left+.5,label..': row 1 is not picker, name, Metadata')
    assert(math.abs((picker.top+picker.bottom)/2-(name.top+name.bottom)/2)<4 and math.abs((info.top+info.bottom)/2-(name.top+name.bottom)/2)<4,label..': row 1 is not one line')
    assert(name.right-name.left>=(nameMinimum or 200),label..': the name field is too small: '..(name.right-name.left))
    for _,item in ipairs(seen) do if item[1]~='picker' and item[1]~='name' and item[1]~='metadata' and item[1]~='switch heading' then
        assert(item[2].top<=name.bottom+.5,label..': '..item[1]..' is on row 1')
    end end
    -- Row 2: groups in a fixed order, each whole on its line.
    local function line(rect) return math.floor(-(rect.top+rect.bottom)/2/24) end
    -- Your own rotation and the Default are editable; only a Built In is read-only.
    local editable=case=='mine' or case=='default'
    local kindName=editable and 'undo' or 'read-only pill'
    local k=assert(byName[kindName],label..': no '..kindName)
    if editable then
        assert(byName.redo and line(byName.redo)==line(k) and k.right<=byName.redo.left+.5,label..': Undo and Redo are not together')
        assert(not byName['read-only pill'],label..': a Read-Only pill on your own rotation')
    else assert(not byName.undo and not byName.redo,label..': Undo/Redo on a read-only rotation') end
    local idLine=line(byName.id)
    assert(line(byName['id label'])==idLine,label..': the ID label is on another line')
    assert(byName['id label'].right<=byName.id.left+.5)
    if case~='default' then
        for _,n in ipairs({'priority label','priority down','priority','priority up'}) do assert(line(byName[n])==idLine,label..': '..n..' is not with ID') end
        assert(byName.id.right<=byName['priority label'].left+.5 and byName['priority label'].right<=byName['priority down'].left+.5 and byName['priority down'].right<=byName.priority.left+.5 and byName.priority.right<=byName['priority up'].left+.5,label..': Priority is out of order')
    else assert(not byName.priority and not byName['priority label'],label..': the Default shows a priority') end
    local endLine=line(byName.enabled)
    assert(line(byName.delete)==endLine and byName.enabled.right<=byName.delete.left+.5,label..': Enabled and Delete are not together')
    if byName.reset then assert(line(byName.reset)==endLine and byName.reset.right<=byName.enabled.left+.5,label..': Reset is not with Enabled') end
    assert(line(k)<=idLine and idLine<=endLine,label..': the groups are out of order')
    if line(k)==idLine then assert(k.right<=byName['id label'].left+.5,label..': the kind is not left of ID') end
    if idLine==endLine then assert(byName.id.right<=byName.enabled.left+.5 and (byName.priority or byName.id).right<=byName.enabled.left+.5,label..': ID is not left of Enabled') end
    -- The switch heading begins below the last header line.
    local lowest=-math.huge;for _,item in ipairs(seen) do if item[1]~='switch heading' then lowest=math.max(lowest,-item[2].bottom) end end
    assert(-byName['switch heading'].top>=lowest-.5,label..': the switch heading is inside the header')
    return byName,line(k),idLine,endLine
end

for _,language in ipairs({'enUS','deDE','ruRU'}) do
    for _,size in ipairs({'min','normal'}) do
        test(language..' '..size..' width: no header control overlaps another or leaves the pane (Built In, Built In with a Reset, own, Default)',function()
            for _,case in ipairs({'builtin','builtin overridden','mine','default'}) do
                local _,pane=open(language,case,WIDTHS[size]);local label=language..' '..size..' '..case
                if case=='builtin overridden' then assert(pane.overrideReset:IsShown(),label..': no Reset to default') end
                assert(pane.nameLabel==nil,label..': the name field still has a label')
                for k,v in pairs(pane) do
                    if type(v)=='table' and v.kind=='FontString' and v:IsShown() then assert(v.text~=pane.name.tooltip,label..': '..tostring(k)..' is a Name label') end
                end
                local _,kind,id,finish_=check(pane,label,case=='builtin overridden' and 'builtin' or case)
                if size=='normal' then assert(kind==id and id==finish_,label..': row 2 wraps at a normal width') end
                -- The picker keeps the Built In and Default read-only, your own editable.
                assert(pane.specButton:IsShown() and (case=='mine')==pane.specButton:IsEnabled(),label..': picker state')
                pane:Release()
            end
        end)
    end
end

test('the picker holds the longest specialization wording at its fixed width, and every row-1 control fits at the minimum',function()
    for _,language in ipairs({'enUS','deDE','ruRU'}) do
        local f,pane=open(language,'mine',WIDTHS.min);local a=f.addon
        local width=pane.specButton:GetWidth();assert(width==172,'the picker width changed: '..width)
        local texts={}
        for _,entry in ipairs(a:GetRotationSpecEntries()) do texts[#texts+1]=entry.name end
        local L=f.env.LibStub('AceLocale-3.0'):GetLocale('rotationmaster')
        for _,k in ipairs({'All specializations','Any specialization','No specialization','Primary talents','Secondary talents'}) do texts[#texts+1]=L[k] end
        -- The caption starts after the chevron (26 px) and keeps 4 px at the right; the client's font averages
        -- under 6 px a character.
        for _,text in ipairs(texts) do assert(characters(text)*6<=width-30,language..': "'..text..'" does not fit the picker') end
    end
end)
test('row 2 wraps whole groups in order when they cannot share a line: kind, then ID with Priority, then Enabled with Delete',function()
    -- Forced: a pane too narrow for the three groups on one line.
    local _,pane=open('ruRU','mine',WIDTHS.min)
    pane.frame:SetWidth(430);pane:Layout()
    local resolve2=audit.resolver(pane.frame)
    local rows={}
    for _,control in ipairs({pane.undo,pane.identifier,pane.priority,pane.enable,pane.delete}) do local r=resolve2(control);rows[#rows+1]=-(r.top+r.bottom)/2 end
    assert(rows[1]<=rows[2] and rows[2]==rows[3] and rows[3]<=rows[4] and rows[4]==rows[5],'groups did not keep together in order')
    assert(rows[4]>rows[1],'nothing wrapped in a narrow pane')
    check(pane,'narrow','mine',60)
end)
finish()
