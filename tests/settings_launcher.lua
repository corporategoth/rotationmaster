local F=dofile('tests/fixtures/addon.lua')
local test,finish=F.suite()
local function fixture()
    local f=F.new();local a=f.addon
    local frames=dofile('tests/fixtures/native_ui.lua')(f.env)
    local registered={}
    local libs=f.libraries
    f.env.LibStub=setmetatable({GetLibrary=function(_,name) return assert(libs[name]) end},{__call=function(_,name)
        assert(not name:find('AceGUI',1,true) and not name:find('AceConfig',1,true) and name~='AceDBOptions-3.0' and name~='LibAboutPanel-2.0','retired settings dependency: '..name)
        return assert(libs[name],name)
    end})
    f.env.C_AddOns={GetAddOnMetadata=function(name,key) assert(name=='rotationmaster');return ({Title='Rotation Master',Author='Makiel',Version='test.1'})[key] end}
    a.name='rotationmaster';a.pretty_name='Rotation Master';a.opened=0
    a.ShowConfig=function(_,section) a.opened=a.opened+1;a.openedSection=section end
    a.RegisterOptionsCategory=function(_,frame) registered[#registered+1]=frame end
    a.IterateModules=function() error('native launcher enumerated legacy module UI') end
    a.DisableRotation=function() a.disabled=true end;a.EnableRotation=function() a.enabled=true end
    a.RefreshConfiguration=function() a.refreshed=true end
    f.load('UI/settings_launcher.lua');f.load('UI/settings_setup.lua')
    return f,registered,frames
end

test('preview forwarding is available without loading the old General renderer',function()
    local f=fixture();local a=f.addon;local native={};a.CreateNativePreviewWindow=function(self) assert(self==a);return native end
    assert(a:CreatePreviewWindow()==native and not a.BuildConfigurationPane)
end)
test('SetupOptions registers only one native launcher and opens the standalone workbench',function()
    local f,registered=fixture();local a=f.addon
    a:SetupOptions();a:SetupOptions()
    assert(#registered==1 and a.settingsLauncher and registered[1]==a.settingsLauncher.frame)
    assert(a.settingsLauncher.open:GetHeight()>=60)
    assert(a.settingsLauncher.commands.text:find('/rm config',1,true) and a.settingsLauncher.commands.text:find('/rm errors',1,true))
    assert(a.settingsLauncher.metadata.text:find('Makiel',1,true) and a.settingsLauncher.metadata.text:find('test.1',1,true))
    a.settingsLauncher.open:Click();assert(a.opened==1 and a.openedSection=='Rotations')
    assert(not a.configModuleApps and not a.BuildModuleConfigurationPane and not a.BuildConfigurationPane)
end)
test('native specialization service keeps platform identities and localized default names',function()
    local f=fixture();local a=f.addon;local entries={{id=0},{id=2},{id=3,name='Named'}}
    a.db.char={specs={[2]='Saved spec'}}
    a.Platform.GetRotationSpecializations=function(_,classID) assert(classID==8);return entries end
    assert(a:GetRotationEditorSpecs(8)==entries and entries[1].name=='Rotations' and entries[2].name=='Saved spec' and entries[3].name=='Named')
    a.Platform.GetRotationSpecializations=function() return nil end
    local missing=a:GetRotationEditorSpecs(8);assert(#missing==1 and missing[1].id==0 and missing[1].name=='Rotations')
end)
test('normal load order retains native services without any retired Options renderer',function()
    local file=assert(io.open('RotationMaster.toc'));local text=file:read('*a');file:close();local entries={}
    for line in text:gmatch('[^\n]+') do if not line:match('^#') then entries[line]=true end end
    for _,name in ipairs({'general','effects','announce','itemset','rotations','custom_condition','conditions','conditional'}) do assert(not entries['Options/'..name..'.lua'],'ordinary TOC still installs '..name..' legacy renderer') end
    for _,path in ipairs({'Core/condition_catalog.lua','Core/itemset_services.lua','Core/custom_condition_services.lua','UI/settings_setup.lua','UI/condition_entrypoints.lua'}) do assert(entries[path],'required native service missing: '..path) end
end)
-- Translator credit (Core/text_bundles.lua GetTranslationCredit): one more wrapped line under the credits, only when the
-- game's language has a human translator. The real function is loaded over the fixture's locale table.
local function withTranslators(names,languageName)
    local f,registered,frames=fixture();local a=f.addon
    local L=f.libraries['AceLocale-3.0']:GetLocale()
    f.env.GetLocale=function() return languageName end
    if names then rawset(L,0,names) end
    f.load('Core/text_bundles.lua')
    a:SetupOptions()
    return f,a,a.settingsLauncher
end
test('no translator line when nobody human has translated the language (the AI is never credited there)',function()
    local _,a,page=withTranslators(nil,'deDE')
    assert(a:GetTranslationCredit()==nil)
    assert(not page.credits.text:find('Translation',1,true) and not page.credits.text:find('Deutsch',1,true),page.credits.text)
    local _,_,english=withTranslators({},'enUS')
    assert(not english.credits.text:find('Translation',1,true))
end)
test('two human translators give one Translation (language) line, each name once',function()
    local f,a,page=withTranslators({'Anna Beispiel','Bruno','anna beispiel'},'deDE')
    f.translations['Translation (%s): %s']='Übersetzung (%s): %s'
    local line=a:GetTranslationCredit()
    assert(line=='Übersetzung (Deutsch): Anna Beispiel, Bruno',tostring(line))
    local f2,a2,page2=withTranslators({'Anna Beispiel','Bruno'},'deDE')
    assert(page2.credits.text:find('Translation (Deutsch): Anna Beispiel, Bruno',1,true),page2.credits.text)
    -- the three existing credit lines are still first
    assert(page2.credits.text:find('^License'),page2.credits.text)
end)
test('a long list is cut at a name boundary with an ellipsis and wraps inside the credits width in every script',function()
    local samples={
        Latin={'Maximilian von Beispielhausen-Müller','Anna-Katharina Schmidt-Wagner'},
        Cyrillic={'Иван Петров-Водкин','Екатерина Александровна'},
        Hangul={'김철수','박영희','이민호'},
        Han={'王小明','李小龍','陳大文'},
    }
    for script,names in pairs(samples) do
        local many={};for i=1,80 do many[#many+1]=names[(i-1)%#names+1]..(i>#names and (' '..i) or '') end
        local f,a,page=withTranslators(many,'koKR')
        local line=a:GetTranslationCredit(480)
        assert(line:len()<=480+60,script..' '..line:len())
        assert(line:sub(-3)=='\226\128\166',script..' list was not cut with an ellipsis')
        -- Whole names only: what precedes the ellipsis ends exactly at the end of one of the names.
        local kept=line:match(': (.*), \226\128\166$');local last
        for _,name in ipairs(many) do if kept:sub(-#name)==name then last=name end end
        assert(last,script..' the cut is not at a name boundary: '..tostring(kept):sub(-12))
        assert(page.credits.text:find(line,1,true),'the page does not show the capped line')
        -- Wrapped height under a conservative model (7 points a character, 13 per line): the block ends above the page's bottom.
        local function characters(text) local n=0;for _ in text:gmatch('[^\128-\191]') do n=n+1 end return n end
        local lines=0
        for paragraph in (page.credits.text..'\n'):gmatch('(.-)\n') do lines=lines+math.max(1,math.ceil(characters(paragraph)*7/592)) end
        assert(460+lines*13<=600-8,script..': credits need '..lines..' lines and run past the page')
        -- The label keeps its wrap on and follows the panel's width.
        assert(page.credits.wordWrap==true)
        page.frame.scripts.OnSizeChanged(page.frame,300)
        assert(page.credits:GetWidth()<=300-48+0.5,page.credits:GetWidth())
    end
end)
test('the About page of the workbench lists the translators too, in full, and nothing for English',function()
    local function about(names)
        local f,a=withTranslators(names,'deDE')
        f.load('UI/settings_profiles.lua')
        local texts={}
        local p={Heading=function() end,Text=function(_,text) texts[#texts+1]=text end,Edit=function() return {} end,Guard=function(_,fn) return fn end}
        a:BuildAboutSettings(p)
        return table.concat(texts,'\n')
    end
    assert(about({'Anna','Bruno'}):find('Translation (Deutsch): Anna, Bruno',1,true))
    assert(not about(nil):find('Translation',1,true))
    local many={};for i=1,100 do many[i]='Translator '..i end
    assert(about(many):find('Translator 100',1,true),'the About page of the workbench must not cap the list')
end)
test('the launcher caps by whole names',function()
    local _,a=withTranslators({'Anna','Bruno'},'deDE')
    assert(a:GetTranslationCredit(8)=='Translation (Deutsch): Anna, \226\128\166',a:GetTranslationCredit(8))
end)

finish()
