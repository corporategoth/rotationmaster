local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
local function itemValue(text)
    local value=text:match('^%s*(.-)%s*$');if value=='' then return end
    local number=tonumber(value);if number then if number<=0 or number%1~=0 then return end;return number end
    return value
end
function addon:BuildItemSettings(p)
    local store=p:SettingsData()
    local profileSets=store.profile.itemsets or {};local globalSets=store.global.itemsets or {};local merged={}
    for id,set in pairs(globalSets) do merged[id]=set end;for id,set in pairs(profileSets) do merged[id]=set end
    local entries=self:SettingsEntries(merged);for _,entry in ipairs(entries) do local value=(merged[entry.value].items or {})[1];local info=value and self:GetReferenceProvider('item').info(tonumber(value) or self:GetReferenceProvider('item').resolve(value));entry.icon=info and info.icon or 'Interface\\Icons\\INV_Misc_Bag_08' end;if not merged[p.selection] and not p.creating then p.selection=entries[1] and entries[1].value end
    p:UseRoster(entries,p.selection,function(id) p.selection=id;p.creating=false;p:Draw() end,{newText=L['Add item set'],new=function() p.previousSelection=p.selection;p.selection=nil;p.creating=true;p.emptyDismissed=false;p:Draw() end});p:Heading(L['Item Sets']);if p.historyEnabled then p:HistoryActions() end
    local set=merged[p.selection]
    if set then
        local id=p.selection;local items=set.items or {}
        local function update()
            local first=(set.items or {})[1];local provider=self:GetReferenceProvider('item');local info=first and provider.info(tonumber(first) or provider.resolve(first));p:UpdateRosterEntry(id,{text=set.name,icon=info and info.icon or 'Interface\\Icons\\INV_Misc_Bag_08'})
            set.modified=true;p:RunSettingsEffect('items_'..id,function() if self.UpdateBoundButton then self:UpdateBoundButton(id) end;if self.UpdateItemSetButtons then self:UpdateItemSetButtons(id) end end)
        end
        p:Edit('name',L['Name'],set.name or '',function(text) return self:SettingsNonempty(text) end,function(text) set.name=text;update() end)
        p:InlineCheck('name','global',L['Global'],globalSets[id]~=nil,function(value)
            store.global.itemsets=store.global.itemsets or {};store.profile.itemsets=store.profile.itemsets or {}
            if value then store.global.itemsets[id]=set;store.profile.itemsets[id]=nil else store.profile.itemsets[id]=set;store.global.itemsets[id]=nil end;p:Draw()
        end,140)
        p:Section('items_'..id,L['Items in priority order'],function()
            p:OrderedCollection('items_'..id,items,function(i) return self:GetReferenceProvider('item').name(tonumber(items[i]) or self:GetReferenceProvider('item').resolve(items[i])) or L['Item data loading'] end,function(form,i,item,row)
                local field=form:Item('item'..i,nil,item,function(value) items[i]=value;update() end);field:ClearAllPoints();field:SetPoint('TOPLEFT',18,-2);field:SetSize(form.width-20,24);form.y=22
            end,update,{prefix='item',compact=true})
            p.newItem=p.newItem or '';local y=p.y;local newItem=p:Item('new_item',L['Item'],p.newItem,function(value) p.newItem=value end,true);newItem:SetWidth(math.max(60,p.width-334))
            local add=p:Button('add_item',L['Add item'],function() local value=itemValue(tostring(p.newItem));if not value then p:Message(L['Choose an item first.']);return end;set.items=set.items or {};set.items[#set.items+1]=value;p.newItem='';update();p:Draw() end,'plus');add:ClearAllPoints();add:SetPoint('TOPRIGHT',0,-y);add:SetWidth(104);p.y=p.y-28
        end)
        local bindings=self.db.char and self.db.char.bindings or {}
        local binding=p:Acquire('bindingPill',function() return self:CreateWorkbenchPill(p.child,'',180) end);binding:ClearAllPoints();binding:SetPoint('TOPRIGHT',-100,-4);binding:SetSize(200,18);p.fields.binding=binding;p.fields.bind=binding
        local function refreshBinding()
            local slots=bindings[id];local labels={};for _,slot in ipairs(slots or {}) do labels[#labels+1]=tostring(slot) end
            binding:SetText(#labels>0 and string.format(L['Slots %s · Unbind'],table.concat(labels,', ')) or L['Bind']);binding:SetSelected(#labels>0)
            if self.EndHighlightSlot then self:EndHighlightSlot() end;if slots and self.HighlightSlots then self:HighlightSlots(slots) end
        end
        self:SetUIScript(binding,'OnClick',p:Guard(function() if not p:FlushEdits() then return end
            if InCombatLockdown and InCombatLockdown() then p:Message(L['Leave combat before changing action bar bindings.']);return end
            if bindings[id] then if self.UnbindItemSet then if self:UnbindItemSet(id)==false then p:Message(L['Leave combat before changing action bar bindings.']);return end else bindings[id]=nil;if self.EndHighlightSlot then self:EndHighlightSlot() end end;refreshBinding();return end
            if p.transactionKeys and p:IsSettingsDraftDirty() then p:Message(L['Apply item-set changes before binding it to an action bar.']);return end
            local first;if self.FindFirstItemOfItemSet then first=self:FindFirstItemOfItemSet({},id,true) elseif self.FindFirstItemInItems then first=self:FindFirstItemInItems(items) end
            if not first or type(PickupItem)~='function' then p:Message(L['An item from this set must be available before binding.']);return end
            self.bindingItemSet=id;PickupItem(first)
        end))
        local token=p.generation;local callback=function(changedId) if p:Valid(token) and (changedId==nil or changedId==id) then refreshBinding() end end;self.itemSetCallback=callback;refreshBinding()
        p.cleanups[#p.cleanups+1]=function() if self.itemSetCallback==callback then self.itemSetCallback=nil end;if self.bindingItemSet==id then self.bindingItemSet=nil;if type(GetCursorInfo)=='function' and GetCursorInfo()=='item' and type(ClearCursor)=='function' then ClearCursor() end end;if self.EndHighlightSlot then self:EndHighlightSlot() end end
        local actionEntries={{key='duplicate',text=L['Duplicate'],icon='copy',action=function() local new=self:uuid();store.profile.itemsets=store.profile.itemsets or {};store.profile.itemsets[new]=self:CopySettingsData(set);store.profile.itemsets[new].name=string.format(L['Copy of %s'],set.name or id);p.selection=new;p:Draw() end},
            {key='transfer',text=L['Import/Export'],icon='transfer',action=function()
                local codec=self:NewRotationCodec();local text,why=codec:Encode({format='RM-ItemSet',version=1,name=set.name,items=items});if not text then p:Message(why);return end
                self:ShowSettingsTextTransfer(p,L['Item Set'],text,function(input,settings)
                    local candidate,errorText=self:ParseItemSetImport(input,codec);if not candidate then return false,errorText end
                    if settings.mode=='replace' then set.items=self:CopySettingsData(candidate.items);update()
                    else local generated=self:uuid();store.profile.itemsets=store.profile.itemsets or {};store.profile.itemsets[generated]={name=settings.name,items=self:CopySettingsData(candidate.items)};p.selection=generated;p.creating=false;p:RunSettingsEffect('items_'..generated,function() if self.UpdateItemSetButtons then self:UpdateItemSetButtons(generated) end end) end;return true
                end,{canReplace=true,selectedName=set.name,fallbackName=L['Imported item set'],originalName=function(input) local candidate=self:ParseItemSetImport(input,codec);return candidate and candidate.name end})
            end},
            {key='reset',text=L['Reset'],icon='undo',enabled=self.getDefaultItemset and self:getDefaultItemset(id)~=nil or false,action=function() local defaults=self:getDefaultItemset(id);if defaults then set.items=self:CopySettingsData(defaults);update();set.modified=false;p:Draw() end end},
            {key='delete',text=L['Delete'],icon='trash',action=function()
                self:ConfirmSettingsDeletion(p,L['Delete this item set and its binding? Rotations referencing it will need another item set.'],function()
                    local profile,global=self.db.profile.itemsets or {},self.db.global.itemsets or {};local current=profile[id] or global[id]
                    if not current then return false,'item-set-changed' end
                    if self.UnbindItemSet then if self:UnbindItemSet(id,self:CopySettingsData(current.items or {}))==false then return false,L['Leave combat before changing action bar bindings.'] end
                    elseif self.db.char and self.db.char.bindings then self.db.char.bindings[id]=nil end
                    profile[id]=nil;global[id]=nil;if self.UpdateItemSetButtons then self:UpdateItemSetButtons(id) end;return true
                end)
            end}}

        self:CollectionFooter(p,'itemset',merged,id,actionEntries[1],actionEntries[2]);self:SettingsTopDelete(p,actionEntries[4].action)
        local reset=p:Acquire('resetPill',function() return self:CreateWorkbenchPill(p.child,L['Reset'],62) end);reset:ClearAllPoints();reset:SetPoint('TOPRIGHT',-30,-4);reset:SetSize(62,18);reset:SetText(L['Reset']);p.fields.reset=reset;if actionEntries[3].enabled then reset:Enable() else reset:Disable() end;self:SetUIScript(reset,'OnClick',p:Guard(function() if p:FlushEdits() then actionEntries[3].action() end end))
    end
    if p.creating or not set then
    self:CollectionFooter(p,'itemset',merged,nil,{key='duplicate',text=L['Duplicate'],icon='copy',enabled=false,action=function() end},{key='transfer',text=L['Import/Export'],icon='transfer',action=function()
        local codec=self:NewRotationCodec();self:ShowSettingsTextTransfer(p,L['Item Set'],'',function(text,settings)
            local candidate,why=self:ParseItemSetImport(text,codec);if not candidate then return false,why end
            local id=self:uuid();store.profile.itemsets=store.profile.itemsets or {};store.profile.itemsets[id]={name=settings.name,items=self:CopySettingsData(candidate.items)};p.selection=id;p.creating=false;return true
        end,{fallbackName=L['Imported item set'],originalName=function(input) local candidate=self:ParseItemSetImport(input,codec);return candidate and candidate.name end})
    end})
    if not p.creating and not p:CanAutoCreateCollection('profile','itemsets') then return end
    p:Heading(L['Add item set']);p.newItemSetName=p.newItemSetName or '';p:Edit('new_name',L['Name'],p.newItemSetName,nil,function(text) p.newItemSetName=text end)
    p:CreationActions(function()
        if not self:SettingsNonempty(p.newItemSetName) then p:Message(L['Enter a name first.']);return end
        local id=self:uuid();store.profile.itemsets=store.profile.itemsets or {};store.profile.itemsets[id]={name=p.newItemSetName,items={}};p.selection=id;p.creating=false;p.newItemSetName='';p:Draw()
    end,function() p.creating=false;p.selection=p.previousSelection;p.emptyDismissed=true;p.newEffectName=nil;p.newItemSetName=nil;p:Draw() end)
    end
end
