local F=dofile('tests/fixtures/addon.lua');local test,finish=F.suite()
local function fixture() local f=F.new();f.load('Core/custom_authoring.lua');local file=io.open('Core/lua_symbols.lua');if file then file:close();f.load('Core/lua_symbols.lua') end;return f,f.addon end
test('RM suggestions describe actual arguments fields and explicitly bound functions without evaluation',function()
 local f,a=fixture();assert(a.LuaContextSymbols,'symbol model missing');a.builtinFunctions={['builtin:test']={source={description='Builtin utility',args={{name='id',type='number',description='Spell identifier'}},returns={{type='boolean',description='Ready'}}},valueBinding=false}}
 local context={kind='condition',callback='evaluate',source={fields={unit='string',spell='number'},bindings={ready='builtin:test'}}}
 local symbols=a:LuaContextSymbols(context);assert(symbols.value.type=='table' and symbols.cache and symbols.evalStart.type=='number');assert(symbols['value.spell'].type=='number')
 assert(symbols.ready.id=='builtin:test' and symbols.ready.info.Arguments[1].Type=='number' and symbols.ready.info.Returns[1].Documentation[1]=='Ready')
 assert(not symbols.UnitHealth and not symbols.GetSpellInfo,'RM fallback invented WoW knowledge')
end)
test('symbol docs preserve source-defined argument names and never invoke custom utility bodies',function()
 local f,a=fixture();f.env.CALLS=0;assert(a:InstallCustomFunction('OWN',{description='Own function',args={{name='target',type='string',description='Unit token'}},returns={{type='number',description='Result'}},code='CALLS=CALLS+1;return 1',bindings={}}))
 local symbols=a:LuaContextSymbols({kind='function',source={args={{name='amount',type='number',description='Amount'}},bindings={own='OWN'}}})
 assert(symbols.amount.description=='Amount' and symbols.own.info.Arguments[1].Name=='target' and f.env.CALLS==0)
 local actual=a:LuaContextSymbols({kind='condition',callback='evaluate',source={parameters={evaluate={'candidate','cache'}},bindings={},fields={}}});assert(actual.candidate and actual.value and actual.evalStart)
end)
test('public helper docs use callable names and hide implicit self only on colon calls',function()
 local f,a=fixture();a.builtinFunctions={
  ['builtin:public']={public=true,callName='addon:MakeField',source={description='Native field',args={{name='self',type='RMAddon'},{name='value',type='table',description='Values'}},returns={{type='RMInput',description='Field'}}}},
  ['builtin:dot']={public=true,callName='addon.cached',source={description='Cache',args={{name='cache',type='table'}},returns={}}},
  ['builtin:private']={source={description='Private',args={},returns={}}}}
 local symbols=a:LuaContextSymbols({kind='condition',source={}})
 assert(symbols.addon and symbols.L,'callback globals lack reference documentation')
 local field=assert(symbols['addon:MakeField']);assert(field.id=='builtin:public' and field.info.Arguments[1].Name=='value' and #field.info.Arguments==1)
 assert(symbols['addon.cached'].info.Arguments[1].Name=='cache');assert(not symbols['builtin:private'])
 local alias=a:LuaContextSymbols({kind='function',source={bindings={make='builtin:public'}}});assert(alias.make.info.Arguments[1].Name=='self','local aliases still need explicit self')
end)
local function documentationEngine(f)
 f.env.GetLocale=function() return 'enUS' end
 f.env.CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
 f.load('Libs/LuaWorkbench-Embed/modules.lua')
 local a=f.addon;local engine={L={},Workspace={db={options={}}},Query={Console={SetStatus=function() end}},Autocomplete={Names=function() return {} end,Hide=function() end}}
 a.LuaWorkbenchModules.Localization('rotationmaster',engine);a.LuaWorkbenchModules.LuaEditor('rotationmaster',engine);a.LuaWorkbenchModules.Analysis('rotationmaster',engine);a.LuaWorkbenchModules.APIHelp('rotationmaster',engine)
 return engine
end
test('deferred Blizzard documentation loads retain context symbols across callback changes',function()
 local f,a=fixture();local engine=documentationEngine(f);local combat=true;f.env.InCombatLockdown=function() return combat end
 a:ApplyLuaContextSymbols(engine,{callback='evaluate',source={}},false);engine.APIHelp:Load(true);assert(engine.APIHelp.pending)
 assert(engine.APIHelp:Paths('evalStart',true)[1]=='evalStart','RM hover depends on Blizzard documentation availability')
 f.env.UnitHealth=function() end;f.env.APIDocumentation={functions={{Name='UnitHealth',Type='Function',Documentation={'Health'}}}};combat=false
 engine.APIHelp:Load(true);assert(engine.APIHelp.index.UnitHealth and engine.APIHelp.catalog.UnitHealth)
 assert(engine.APIHelp.catalog.evalStart,'delayed catalog load lost RM symbols')
 a:ApplyLuaContextSymbols(engine,{callback='valid',source={}},false)
 assert(engine.APIHelp.index.UnitHealth and engine.APIHelp.catalog.UnitHealth,'context erased loaded WoW knowledge');assert(not engine.APIHelp.index.evalStart and engine.APIHelp.index.spec)
end)
test('public colon helper hover resolves methods without resolving shadowed addon locals',function()
 local f,a=fixture();local engine=documentationEngine(f)
 a.builtinFunctions={['builtin:field']={public=true,callName='addon:MakeField',source={description='Native field',args={},returns={}}}}
 a:ApplyLuaContextSymbols(engine,{callback='evaluate',source={}},false)
 local source='addon:MakeField()';local paths=engine.APIHelp:Paths(source,true);assert(paths[7]=='addon:MakeField','method token lacks typed documentation')
 assert(engine.APIHelp:FullDescription(paths[7]):find('Native field',1,true))
 local shadow='local addon={}\naddon:MakeField()';local offset=assert(shadow:find('MakeField',1,true));assert(not engine.APIHelp:Paths(shadow,true)[offset],'shadowed addon used RM global docs')
end)
finish()
