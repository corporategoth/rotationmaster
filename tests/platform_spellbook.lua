local F=dofile('tests/fixtures/addon.lua')
local fixture=dofile('tests/fixtures/platform.lua')
local test,finish=F.suite()
test('modern spellbook records preserve player enum zero ranks offspec and separate pet slots',function()
    local queried={}
    local p=fixture({Enum={SpellBookSpellBank={Player=0,Pet=1},SpellBookItemType={Spell=1,FutureSpell=2,PetAction=3,Flyout=4}},
        C_SpellBook={GetNumSpellBookSkillLines=function() return 2 end,
            GetSpellBookSkillLineInfo=function(line) return {itemIndexOffset=line==1 and 0 or 3,numSpellBookItems=line==1 and 3 or 1,offSpecID=line==2 and 264 or nil} end,
            HasPetSpells=function() return 2 end,
            GetSpellBookItemInfo=function(slot,bank)
                queried[#queried+1]={slot,bank}
                if bank==1 then return {itemType=slot==1 and 1 or 3,spellID=974,actionID=974,isPassive=false,isOffSpec=false} end
                if slot==2 then return {itemType=2} end
                if slot==3 then return {itemType=4} end
                return {itemType=1,spellID=slot==1 and 403 or 324,actionID=slot==1 and 403 or 324,isPassive=slot==4,isOffSpec=slot==4}
            end}}, {'Platform/client.lua','Platform/spellbook.lua'})
    local book=p:GetSpellBookSnapshot()
    assert(book.player.complete and book.pet.complete and #book.player.entries==2 and #book.pet.entries==1)
    assert(queried[1][2]==0 and queried[#queried][2]==1)
    assert(book.player.entries[1].spellID==403 and book.player.entries[2].offSpecID==264 and book.player.entries[2].isPassive)
    assert(book.pet.entries[1].slot==1 and book.pet.entries[1].spellID==974)
end)
test('legacy tabs and item tuples preserve lower ranks without requiring metadata links',function()
    local p=fixture({GetNumSpellTabs=function() return 1 end,GetSpellTabInfo=function() return 'Shaman',1,0,2,false,0 end,
        GetSpellBookItemInfo=function(slot,bank) assert(bank=='spell');return 'SPELL',slot==1 and 8042 or 8044 end,
        IsPassiveSpell=function() return false end,HasPetSpells=function() return nil end},
        {'Platform/client.lua','Platform/spellbook.lua'})
    local book=p:GetSpellBookSnapshot()
    assert(book.player.complete and #book.player.entries==2 and book.player.entries[1].spellID==8042 and book.player.entries[2].spellID==8044)
    assert(book.pet.complete and #book.pet.entries==0)
end)
test('restricted modern results never fall back to legacy or fabricate an empty book',function()
    local opaque={}
    local p=fixture({canaccessvalue=function(v) return not rawequal(v,opaque) end,
        C_SpellBook={GetNumSpellBookSkillLines=function() return opaque end,HasPetSpells=function() return nil end},
        GetNumSpellTabs=function() error('restricted native result must not fall back') end},
        {'Platform/client.lua','Platform/spellbook.lua'})
    local book=p:GetSpellBookSnapshot()
    assert(not book.player.complete and book.player.reason=='restricted-value')
    assert(book.pet.complete and #book.pet.entries==0)
end)
test('missing pet enums never substitute player bank and failures remain bank-specific',function()
    local p=fixture({Enum={SpellBookSpellBank={Player=0},SpellBookItemType={Spell=1}},
        C_SpellBook={GetNumSpellBookSkillLines=function() return 0 end,HasPetSpells=function() return 1 end,
            GetSpellBookItemInfo=function() error('missing pet bank must not be queried') end}},
        {'Platform/client.lua','Platform/spellbook.lua'})
    local book=p:GetSpellBookSnapshot()
    assert(book.player.complete and #book.player.entries==0)
    assert(not book.pet.complete and book.pet.reason=='missing-spell-bank')
end)
test('slot limits and malformed records fail explicitly rather than scanning indefinitely',function()
    local calls=0
    local env={GetNumSpellTabs=function() return 129 end,HasPetSpells=function() return nil end,
        GetSpellTabInfo=function() calls=calls+1 end}
    local p=fixture(env,{'Platform/client.lua','Platform/spellbook.lua'})
    local book=p:GetSpellBookSnapshot();assert(not book.player.complete and book.player.reason=='spellbook-limit' and calls==0)
    env.GetNumSpellTabs=function() return 1 end
    env.GetSpellTabInfo=function() return 'General',1,0,4097 end
    book=p:GetSpellBookSnapshot();assert(not book.player.complete and book.player.reason=='spellbook-limit')
    env.GetSpellTabInfo=function() return 'General',1,0,1 end
    env.GetSpellBookItemInfo=function() return 'SPELL',nil end
    book=p:GetSpellBookSnapshot();assert(not book.player.complete and book.player.reason=='spellbook-data-unavailable')
end)
test('unreadable bank constants and native item failures do not enable legacy fallbacks',function()
    local opaque={};local legacyCalls=0
    local env={Enum={SpellBookSpellBank={Player=opaque},SpellBookItemType={Spell=1}},
        canaccessvalue=function(v) return not rawequal(v,opaque) end,
        C_SpellBook={GetNumSpellBookSkillLines=function() return 1 end,
            GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=1} end,
            HasPetSpells=function() return nil end,GetSpellBookItemInfo=function() error('native item failure') end},
        GetSpellBookItemInfo=function() legacyCalls=legacyCalls+1;return 'SPELL',403 end}
    local p=fixture(env,{'Platform/client.lua','Platform/spellbook.lua'})
    local book=p:GetSpellBookSnapshot()
    assert(not book.player.complete and book.player.reason=='restricted-value' and legacyCalls==0)
    env.Enum.SpellBookSpellBank.Player=0
    book=p:GetSpellBookSnapshot()
    assert(not book.player.complete and book.player.reason=='api-error' and legacyCalls==0)
end)
finish()
