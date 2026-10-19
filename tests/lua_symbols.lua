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
test('RM table and platform method docs preserve dot versus colon calling conventions',function()
 local f,a=fixture();local engine=documentationEngine(f)
 a.builtinFunctions={['builtin:ready']={public=true,callName='addon.Platform:IsSpellReady',source={description='Check readiness',args={{name='self',type='RMPlatform',description='Platform receiver'},{name='spell',type='number',description='Spell ID'},{name='now',type='number',description='Evaluation time'}},returns={{type='boolean | nil',description='Ready or unavailable'}}}}}
 a:ApplyLuaContextSymbols(engine,{callback='evaluate',source={}},false)
 local source='addon.getCached(cache, addon.Platform.IsSpellReady, addon.Platform, spellid, evalStart)'
 local paths=engine.APIHelp:Paths(source,true);local method=assert(source:find('IsSpellReady',1,true));local receiver=assert(source:find('addon.Platform,',1,true))+6
 assert(paths[method]=='addon.Platform.IsSpellReady','dot reference to colon-defined method has no documentation')
 assert(paths[receiver]=='addon.Platform','platform receiver has no typed documentation')
 assert(engine.rmSymbols['addon.Platform.IsSpellReady'].info.Arguments[1].Name=='self','dot method reference hides its required receiver')
 assert(engine.rmSymbols['addon.Platform:IsSpellReady'].info.Arguments[1].Name=='spell','colon method documentation repeats implicit self')
 assert(engine.APIHelp:Paths('addon.units[value.unit]',true)[7]=='addon.units','unit lookup table lacks hover docs')
 local text=engine.APIHelp:FullDescription(paths[method]);assert(text:find('Rotation Master built-in function',1,true) and not text:find('Blizzard API function',1,true),'RM helper is labelled as a Blizzard API')
 local valueText=engine.APIHelp:FullDescription('addon.Platform');assert(valueText:find('RMPlatform',1,true),'table metadata omits its type')
end)
test('undocumented live global function references have honest fallback docs without evaluation',function()
 local f,a=fixture();local engine=documentationEngine(f);local calls=0
 for _,name in ipairs({'UnitExists','UnitCanAttack','UnitIsDead'}) do f.env[name]=function() calls=calls+1 end end
 f.env.APIDocumentation={functions={{Name='UnitExists',Type='Function',Documentation={'Exists documentation'}},{Name='UnitCanAttack',Type='Function',Documentation={'Attack documentation'}}}}
 a:ApplyLuaContextSymbols(engine,{callback='evaluate',source={}},false);engine.APIHelp:Load(true)
 local source='getCached(cache, UnitExists, unit) and getCached(cache, UnitCanAttack, unit) and not getCached(cache, UnitIsDead, unit)'
 local paths=engine.APIHelp:Paths(source,true)
 for _,name in ipairs({'UnitExists','UnitCanAttack','UnitIsDead'}) do assert(paths[assert(source:find(name,1,true))]==name,name..' bare reference has no hover') end
 assert(engine.APIHelp:FullDescription('UnitExists'):find('Exists documentation',1,true),'fallback replaced upstream documentation')
 local text=engine.APIHelp:FullDescription('UnitIsDead');assert(text:find('UnitIsDead',1,true) and text:find('does not provide signature documentation',1,true),'undocumented API invents or omits its docs limitation')
 assert(calls==0,'hover discovery executed a function')
 local shadow='local UnitIsDead=function() end\nreturn UnitIsDead';local position=assert(shadow:find('UnitIsDead',30,true));assert(not engine.APIHelp:Paths(shadow,true)[position],'local name incorrectly resolved as a global API')
 local unknown='return DefinitelyNotARealFunction';assert(not engine.APIHelp:Paths(unknown,true)[8],'invented documentation for missing global')
end)
test('reduced editing keeps API fallback disabled',function()
 local f,a=fixture();local engine=documentationEngine(f);f.env.UnitIsDead=function() error('must not run') end
 a:ApplyLuaContextSymbols(engine,{callback='evaluate',source={}},true);assert(not engine.APIHelp:Paths('UnitIsDead',true)[1],'limited editor grew its own WoW knowledge database')
end)
test('function namespace suggestions preserve stable dependencies and suppress ambiguous or shadowed names',function()
 local f,a=fixture();a.db.global.custom_functions={A={name='ready',description='Readiness',args={{name='unit',type='string'}},returns={{type='boolean'}}},B={name='ambiguous'},C={name='ambiguous'},D={name='off',disabled=true}}
 local symbols=a:LuaContextSymbols({kind='function',source={bindings={check='A'}}})
 assert(symbols.check.id=='A' and symbols['functions.check'].id=='A' and not symbols['functions.check'].requiresBinding)
 assert(symbols['functions.ready'].id=='A' and symbols['functions.ready'].requiresBinding and symbols['functions.ready'].bindingName=='functions.ready')
 assert(not symbols['functions.ambiguous'] and not symbols['functions.off'])
 assert(not a:LuaContextSymbols({kind='function',source={args={{name='functions',type='table'}},bindings={}}})['functions.ready'],'argument-shadowed namespace leaked completion candidates')
 assert(not a:LuaContextSymbols({kind='function',id='A',source={bindings={}}})['functions.ready'],'function offered itself as a new cyclic dependency')
 assert(a:LuaContextSymbols({kind='function',source={args={{name='ready',type='number'}},bindings={}}})['functions.ready'],'unrelated argument prevented a qualified reference')
end)
test('accepting a current namespace completion binds once before insertion and preserves signature docs',function()
 local f,a=fixture();local engine=documentationEngine(f);engine.UI={};a.LuaWorkbenchModules.Autocomplete('rotationmaster',engine)
 a.db.global.custom_functions={A={name='ready',description='Readiness',args={{name='unit',type='string',description='Unit token'}},returns={{type='boolean'}}}}
 local source,cursor='functions.re',12;local input={editBox={GetCursorPosition=function() return cursor end},GetText=function() return source end};engine.Query.Console.input=input
 function engine.Query.Editor:SetSource(_,text,position) source,cursor=text,position end
 local bindings=0;local context={kind='function',source={bindings={}},bindFunction=function(id,alias) assert(id=='A' and alias=='functions.ready' and source=='functions.re');bindings=bindings+1;return true end}
 a:ApplyLuaContextSymbols(engine,context,true);local complete=engine.Autocomplete
 function complete:Update() end
 complete.input=input;complete.context=assert(complete:Context(source,cursor));complete.items=complete:Suggest(complete.context,true);complete.selected=1;complete.panel={IsShown=function() return true end}
 assert(complete.items[1].name=='functions.ready','completion is not a complete callable namespace name');assert(bindings==0,'browsing suggestions created a dependency')
 assert(complete:Accept(input) and source=='functions.ready' and bindings==1,'completion insertion did not bind the stable function first')
 local signature=complete:Signature(assert(complete:Context('functions.ready(',16)));assert(signature:find('unit',1,true) and signature:find('string',1,true),'namespaced completion lost its argument docs')
end)
test('stale refused or read-only completion acceptance never mutates dependencies',function()
 local f,a=fixture();local engine=documentationEngine(f);engine.UI={};a.LuaWorkbenchModules.Autocomplete('rotationmaster',engine)
 a.db.global.custom_functions={A={name='ready',description='Readiness',args={},returns={}}};local source,cursor='functions.re',12;local calls=0
 local input={editBox={GetCursorPosition=function() return cursor end},GetText=function() return source end};engine.Query.Console.input=input
 function engine.Query.Editor:SetSource(_,text,position) source,cursor=text,position end
 a:ApplyLuaContextSymbols(engine,{kind='function',source={bindings={}},bindFunction=function() calls=calls+1;return false end},true)
 local complete=engine.Autocomplete;function complete:Update() end
 local function select() complete.input=input;complete.context=assert(complete:Context(source,cursor));complete.items=complete:Suggest(complete.context,true);complete.selected=1;complete.panel={IsShown=function() return true end,Hide=function() end} end
 select();assert(not complete:Accept(input) and calls==1 and source=='functions.re','refused binding inserted source')
 select();cursor=11;assert(not complete:Accept(input) and calls==1,'stale cursor created a dependency')
 cursor=12;select();input.readonly=true;assert(not complete:Accept(input) and calls==1,'readonly completion created a dependency')
end)
test('canonical completion separates module namespaces and preserves explicit saved binding paths',function()
 local f,a=fixture();local src={name='ready',namespace='custom.healing',description='Custom readiness',args={},returns={}}
 a.db.global.custom_functions={CUSTOM=src,OTHER={name='ready',namespace='custom.damage',description='Other readiness',args={},returns={}}}
 a.builtinFunctions={['builtin:utils.lua:ready']={source={name='ready',namespace='utils',description='Module utility',args={},returns={}}}}
 local symbols=a:LuaContextSymbols({kind='function',source={bindings={['old.path.ready']='CUSTOM'}}})
 for _,name in ipairs({'custom.healing.ready','custom.damage.ready','utils.ready'}) do assert(symbols[name].requiresBinding and symbols[name].bindingName==name,name..' lost its canonical binding') end
 assert(symbols.custom and symbols['custom.healing'] and symbols.utils,'intermediate namespaces cannot be completed')
 assert(symbols['old.path.ready'].id=='CUSTOM' and not symbols['old.path.ready'].requiresBinding,'metadata rename rewrote a saved binding path')
 assert(not a:LuaContextSymbols({kind='function',source={args={{name='custom',type='table'}},bindings={}}})['custom.healing.ready'],'argument-shadowed namespace was offered')
end)
test('moved helpers retain verified legacy hover and navigation without duplicate completion entries',function()
 local f,a=fixture();f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');local engine=documentationEngine(f)
 a:ApplyLuaContextSymbols(engine,{kind='condition',callback='evaluate',source={}},false)
 for _,name in ipairs({'getCached','getRetryCached','compare','nullable','split','deepcopy'}) do
  local alias='addon.'..name;local symbol=assert(engine.rmSymbols[alias]);assert(symbol.documentationOnly and engine.APIHelp.index[alias] and not engine.APIHelp.catalog[alias])
  assert(engine.APIHelp:FullDescription(alias):find(symbol.description,1,true))
 end
 a.getCached=function() end;a:ApplyLuaContextSymbols(engine,{kind='condition',callback='evaluate',source={}},false)
 assert(not engine.rmSymbols['addon.getCached'],'changed alias incorrectly inherited another function docs')
end)
test('actual Attackable and AnySpell Available sources document every cited public reference',function()
 local f,a=fixture();f.load('Data/builtin_sources.lua');f.load('Core/builtin_sources.lua');f.load('Conditions/common.lua');f.load('Platform/spells.lua');f.load('Platform/actions.lua');f.load('Conditions/combat.lua');f.load('Conditions/anyspell.lua')
 local engine=documentationEngine(f);for _,name in ipairs({'UnitExists','UnitCanAttack','UnitIsDead'}) do f.env[name]=function() error('hover must not execute') end end
 for _,case in ipairs({{'ATTACKABLE','evaluate',{'UnitExists','UnitCanAttack','UnitIsDead','Functions.cache.getCached'}},{'ATTACKABLE','valid',{'addon.units'}},{'ANYSPELL_AVAIL','evaluate',{'addon:Widget_GetSpellId','addon.Platform.IsSpellReady','addon.Platform'}}}) do
  local source=assert(a:GetBuiltinConditionSource(case[1]));a:ApplyLuaContextSymbols(engine,{kind='condition',id=case[1],callback=case[2],source=source},false)
  local paths=engine.APIHelp:Paths(source[case[2]],true)
  for _,name in ipairs(case[3]) do
   local found=false;for _,path in pairs(paths) do if path==name then found=true end end
   assert(found,case[1]..' '..case[2]..' lacks '..name);local text=engine.APIHelp:FullDescription(name);assert(text and text:find('%S'),name..' has no readable documentation')
  end
 end
end)
finish()
