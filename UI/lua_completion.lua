local _,addon=...
-- The reduced editor uses the same released parser/completion component, but
-- only RM's declared arguments, fields and functions enter its knowledge index.
function addon:InstallRMCodeCompletion(c)
    if not self.CreateLuaWorkbenchEngine or not self.ApplyLuaContextSymbols then return end
    local ok,engine=pcall(self.CreateLuaWorkbenchEngine,self,{id='RM-native',limited=true});if not ok or not engine then return end
    engine.APIHelp.index={};engine.APIHelp.catalog={};engine.APIHelp.ready=true;function engine.APIHelp:Load() end
    -- Limited completion never loads Blizzard docs, including after combat.
    -- Its reusable editor therefore needs no persistent API-load event frame.
    if engine.APIHelp.events then engine.APIHelp.events:UnregisterAllEvents();engine.APIHelp.events:SetScript('OnEvent',nil) end
    local E,A=engine.Query.Editor,engine.Autocomplete
    local input={frame=c.frame,editBox=c.edit,scrollFrame=c.scroll,queryEditor={source='',elapsed=0}}
    engine.Query.Console.input=input
    function input:GetText() return c:GetText() end
    function E:Paint() end
    local function updateHoverGeometry(text)
        local state=input.queryEditor;if state.renderSource==text then return end
        state.renderSource=text;state.overlay=c.measure;state.renderSpans={};state.hoverAreas=nil
        c.measure:ClearAllPoints();c.measure:SetPoint('TOPLEFT',c.edit,'TOPLEFT',6,-4);c.measure:SetHeight(c.measure:GetStringHeight());c.measure:SetAlpha(0);c.measure:Show()
        for _,token in ipairs(E:Tokenize(text)) do
            if token.kind=='identifier' or token.kind=='call' then state.renderSpans[#state.renderSpans+1]={kind=token.kind,text=token.text,source=token.start,first=token.start,last=token.finish} end
        end
    end
    function E:SetSource(_,text,cursor)
        c:SetText(text);c.edit:SetCursorPosition(cursor or #text);input.queryEditor.source=text
        if not c.released and c.valid() and c.changed then c.changed(text) end
    end
    function A:Enabled(value) return value==input and not c.released and not c.readOnly and c.valid() end
    local originals={};local attached=false
    local function wrap(event,callback)
        local original=c.edit:GetScript(event);originals[event]=original or false
        addon:SetUIScript(c.edit,event,function(...) return callback(original,...) end)
    end
    local function attachedHandler()
        if attached then return end;attached=true
        wrap('OnKeyDown',function(original,frame,key) if A:Enabled(input) and A:Key(input,key) then return end;if original then return original(frame,key) end end)
        wrap('OnKeyUp',function(original,frame,key) A:RestoreCursor(input);A.keySource,A.keyCursor,A.arrowKey,A.arrowOrigin=nil,nil,nil,nil;if original then return original(frame,key) end end)
        wrap('OnChar',function(original,frame,char)
            if A.keySource and char==' ' then
                local source,cursor=A.keySource,A.keyCursor;A.keySource,A.keyCursor=nil,nil
                if frame:GetText()==source:sub(1,cursor)..char..source:sub(cursor+1) then E:SetSource(input,source,cursor);return end
            end
            if original then return original(frame,char) end
        end)
        wrap('OnArrowPressed',function(original,frame,key) if A:Enabled(input) and A:Arrow(input,key) then return true end;if original then return original(frame,key) end end)
        wrap('OnTabPressed',function(original,frame) if A:Enabled(input) and A:Accept(input) then return end;if original then original(frame) else frame:Insert('    ') end end)
        wrap('OnEnterPressed',function(original,frame) if A:Enabled(input) and A:Accept(input) then return true end;if original then return original(frame) end;if not c.readOnly then frame:Insert('\n') end end)
        wrap('OnEscapePressed',function(original,frame) if A.input==input and (A.panel and A.panel:IsShown() or A.signaturePanel and A.signaturePanel:IsShown()) then A:Hide();return end;if original then return original(frame) end end)
        wrap('OnUpdate',function(original,frame,elapsed) if original then original(frame,elapsed) end;if c.context then engine.Query.Console.source=c:GetText();A:Tick(input,elapsed);updateHoverGeometry(c:GetText());engine.DebugUI:HoverUpdate(elapsed) end end)
        wrap('OnCursorChanged',function(original,frame,x,y,width,height) input.cursorX,input.cursorY=x,y;if original then return original(frame,x,y,width,height) end end)
        wrap('OnMouseUp',function(original,frame,button) if original then original(frame,button) end;if button=='LeftButton' and IsControlKeyDown and IsControlKeyDown() then addon:NavigateLuaSymbol(engine,input,c:GetText(),frame:GetCursorPosition()) end end)
        wrap('OnEditFocusLost',function(original,...) A:Hide();if original then return original(...) end end)
    end
    function c:UpdateSymbols(context)
        self.context=context
        local source=context and context.source or {};local signature={kind=context and context.kind,id=context and context.id,callback=context and context.callback,args=source.args,returns=source.returns,bindings=source.bindings,fields=source.fields,parameters=source.parameters,revision=addon.functionRegistryVersion}
        if addon:SettingsDataEqual(signature,self.symbolSignature) then return end;self.symbolSignature=addon:CopySettingsData(signature)
        engine.Workspace.current=context and context.id or 'RM-native';addon:ApplyLuaContextSymbols(engine,context,true)
    end
    function c:ReleaseCompletion()
        A:Hide();engine.DebugUI:HideTooltip(nil,'owner-closed');engine.Query.Console.source='';if not attached then return end;attached=false
        for event,script in pairs(originals) do addon:SetUIScript(self.edit,event,script or nil) end;originals={}
    end
    function c:AcquireCompletion() attachedHandler();if self.context then self:UpdateSymbols(self.context) end end
    c.completionEngine=engine;c:AcquireCompletion()
end
