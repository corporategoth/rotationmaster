local addon_name,addon=...
local L=LibStub('AceLocale-3.0'):GetLocale(addon_name)
function addon:LuaContextSymbols(context)
    context=context or {};local source=context.source or {};local symbols={}
    local function add(name,kind,description,typeName,args,returns,id)
        local info={Name=name,Type=kind=='functionName' and 'Function' or 'Parameter',Documentation={description or ''},Arguments={},Returns={}}
        for _,arg in ipairs(args or {}) do info.Arguments[#info.Arguments+1]={Name=arg.name,Type=arg.type,Documentation={arg.description or ''}} end
        for i,result in ipairs(returns or {}) do info.Returns[#info.Returns+1]={Name='result'..i,Type=result.type,Documentation={result.description or ''}} end
        symbols[name]={name=name,kind=kind,description=description or '',type=typeName,info=info,id=id}
    end
    add('addon','identifier',L['Rotation Master addon instance. Public helper functions are documented in Functions.'],'RMAddon')
    add('L','identifier',L['Localized Rotation Master text, indexed by its English key.'],'table')
    for id,entry in pairs(self.builtinFunctions or {}) do
        if entry.public and entry.callName and entry.source then
            local args={};for index,arg in ipairs(entry.source.args or {}) do
                if not (index==1 and arg.name=='self' and entry.callName:find(':',1,true)) then args[#args+1]=arg end
            end
            add(entry.callName,'functionName',entry.source.description,'function',args,entry.source.returns,id)
        end
    end
    local arguments={}
    if context.kind=='function' then arguments=source.args or {}
    else
        local docs=self.CustomConditionCallbackDocs and self.CustomConditionCallbackDocs[context.callback or 'evaluate']
        if docs then for _,arg in ipairs(docs.args) do arguments[#arguments+1]={name=arg[1],type=arg[2],description=arg[3]} end end
        for alias,canonical in pairs(self:CustomConditionParameterAliases(source,context.callback or 'evaluate')) do
            for _,arg in ipairs(docs and docs.args or {}) do if arg[1]==canonical then add(alias,'parameter',arg[3],arg[2]) end end
        end
    end
    for _,arg in ipairs(arguments) do if arg.name~='...' then add(arg.name,'parameter',arg.description,arg.type) end end
    if symbols.value then for name,typeName in pairs(source.fields or {}) do if type(name)=='string' then add('value.'..name,'identifier',name,type(typeName)=='string' and typeName or 'table') end end end
    for alias,id in pairs(source.bindings or {}) do
        local builtin=self.builtinFunctions and self.builtinFunctions[id];local custom=(self.db.global.custom_functions or {})[id];local entry=custom or builtin and builtin.source
        if entry then add(alias,builtin and builtin.valueBinding and 'identifier' or 'functionName',entry.description,builtin and builtin.valueBinding and 'any' or 'function',entry.args,entry.returns,id) end
    end
    return symbols
end
function addon:ApplyLuaContextSymbols(engine,context,limited)
    local api=engine.APIHelp
    local function shallow(value) local result={};for key,entry in pairs(value or {}) do result[key]=entry end;return result end
    if not api.rmSyncSymbols then
        function api:rmSyncSymbols()
            -- Documentation can arrive after the editor opens (combat defers
            -- upstream loading). Strip only our previous overlay, retain newly
            -- loaded metadata, then apply the current callback's symbols.
            local index,catalog=shallow(self.index),shallow(self.catalog)
            for name,symbol in pairs(self.rmOverlaySymbols or {}) do
                if index[name]==symbol.info then index[name]=self.rmBaseIndex and self.rmBaseIndex[name] end
                if catalog[name] and catalog[name].info==symbol.info then catalog[name]=self.rmBaseCatalog and self.rmBaseCatalog[name] end
            end
            self.rmBaseIndex=shallow(index);self.rmBaseCatalog=shallow(catalog)
            for name,symbol in pairs(engine.rmSymbols or {}) do index[name]=symbol.info;catalog[name]={name=name,kind=symbol.kind=='functionName' and 'apiFunctions' or 'apiOther',info=symbol.info} end
            self.index,self.catalog=index,catalog;self.rmOverlaySymbols=engine.rmSymbols
            self.source,self.paths,self.text=nil,nil,{};self.revision=self.revision+1
            if engine.KnowledgeBase then engine.KnowledgeBase.entries=nil end
        end
        local load=api.Load
        function api:Load(...)
            local revision=self.revision;load(self,...)
            if self.revision~=revision then self:rmSyncSymbols() end
        end
        local paths=api.Paths
        function api:Paths(source,force)
            local result=paths(self,source,force)
            if not force and not self:Enabled() then return result end
            local analysis=engine.Analysis:Get(source);local chain,previous,declaration
            for _,token in ipairs(analysis.tokens) do
                if token.kind~='space' and token.kind~='newline' and token.kind~='comment' then
                    if token.kind=='identifier' or token.kind=='call' then
                        if chain and previous and (previous.text=='.' or previous.text==':') then chain=chain..previous.text..token.text
                        else chain=token.semanticKind=='globalVariable' and not token.definition and not analysis.globals[token.text] and token.text or nil;declaration=previous and previous.text=='function' end
                        if chain and not declaration and not token.definition and engine.rmSymbols[chain] then result[token.start]=chain end
                    elseif token.text~='.' and token.text~=':' then chain=nil end
                    previous=token
                end
            end
            return result
        end
    end
    engine.rmSymbols=self:LuaContextSymbols(context);api:rmSyncSymbols()
    if limited then api.ready=true;function api:Load() end end
    if not engine.Autocomplete.rmNames then
        engine.Autocomplete.rmNames=engine.Autocomplete.Names
        function engine.Autocomplete:Names()
            local names=self:rmNames();for name,symbol in pairs(engine.rmSymbols or {}) do self.nameKinds[name]=symbol.kind end;return names
        end
    end
    engine.Autocomplete:Hide()
end

function addon:NavigateLuaSymbol(engine,input,source,cursor)
    local first=cursor
    while first>0 and source:sub(first,first):match('[%w_%.:]') do first=first-1 end
    local last=cursor+1;while last<=#source and source:sub(last,last):match('[%w_%.:]') do last=last+1 end
    local name=source:sub(first+1,last-1);local symbol=engine.rmSymbols and engine.rmSymbols[name]
    if symbol and symbol.id and self.ShowFunctionSource then return self:ShowFunctionSource(symbol.id) end
    if engine.Navigation and not engine.embeddingOptions.limited then return engine.Navigation:Go({scriptId=engine.Workspace.current,source=source,cursor=cursor}) end
    return false
end
