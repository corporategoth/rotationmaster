-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

local F = dofile('tests/fixtures/addon.lua')
local test, finish = F.suite()

local function fixture()
    local f = F.new()
    local a = f.addon

    local infos = {
        [403] = { name = 'Lightning Bolt', spellID = 403, subtext = 'Rank 1', iconID = 1 },
        [529] = { name = 'Lightning Bolt', spellID = 529, subtext = 'Rank 2', iconID = 1 },
        [324] = { name = 'Lightning Shield', spellID = 324, subtext = 'Rank 1', iconID = 2 },
        [974] = { name = 'Earth Shield', spellID = 974, iconID = 3 },
        [555] = { name = 'A.b [test]', spellID = 555, iconID = 4 },
    }

    a.Platform = {
        GetSpellInfo = function(_, query)
            if query == 'Lightning Bolt' then
                query = 529
            elseif query == 'Earth Shield' then
                query = 974
            end

            return infos[query], not infos[query] and 'spell-data-unavailable' or nil
        end,
        GetSpellLink = function(_, id) return 'spell:' .. id end,
    }

    for id in pairs(infos) do
        a.SpellCatalog:UpdateSpell(id)
    end

    a.specSpells = { [0] = { [403] = true, [324] = true }, pet = { [529] = true } }
    a.spellBookStatus = { player = { complete = true }, pet = { complete = true } }
    return f
end

test('search is deterministic bounded and detached with explicit indexed coverage', function()
    local f = fixture()
    local c = f.addon.SpellCatalog
    local rows, status = c:Search('light', { limit = 2 })

    assert(
        #rows == 2 and rows[1].id == 529 and rows[2].id == 403 and status.more and status.coverage == 'indexed-metadata'
    )

    rows[1].name = 'bad'
    assert(c:Search('Lightning Bolt')[1].name == 'Lightning Bolt')
    rows, status = c:Search('A.b [')
    assert(#rows == 1 and rows[1].id == 555, 'query was interpreted as a Lua pattern')
    rows, status = c:Search('', { limit = 0 })
    assert(rows == nil and status == 'invalid-search-options')
end)

test('rank collapsing happens after selected spellbook filtering and never substitutes player for pet', function()
    local f = fixture()
    local c = f.addon.SpellCatalog
    local rows, status = c:Search('Lightning', { spec = 0, norank = true })
    assert(#rows == 2 and rows[1].id == 403 and status.scope == 'spellbook' and status.bookComplete)
    rows = c:Search('Lightning', { spec = 'pet', norank = true })
    assert(#rows == 1 and rows[1].id == 529)
    rows = c:Search('Earth', { spec = 0 })
    assert(#rows == 0)
    rows = c:Search('Earth')
    assert(#rows == 1 and rows[1].id == 974, 'reference metadata was mistaken for learned state')
end)

test('exact IDs links and formatted rank names retain identity instead of canonical upgrades', function()
    local c = fixture().addon.SpellCatalog
    assert(c:ResolveSelection('403') == 403)
    assert(c:ResolveSelection('|cff71d5ff|Hspell:403|h[Lightning Bolt]|h|r') == 403)
    assert(c:ResolveSelection('Lightning Bolt|cFF888888 (Rank 1)|r') == 403)
    assert(c:ResolveSelection('Lightning Bolt') == 529)
    local id, why = c:ResolveSelection('974', { spec = 0 })
    assert(id == nil and why == 'spell-not-in-book')
    assert(c:ResolveSelection('Lightning Bolt (Rank 1)', { spec = 0 }) == 403)
end)

test('failed banks and metadata remain explicit instead of advertising stale choices', function()
    local f = fixture()
    local a = f.addon
    local c = a.SpellCatalog
    a.spellBookStatus.pet = { complete = false, reason = 'restricted-value' }
    local rows, status = c:Search('Lightning', { spec = 'pet' })
    assert(#rows == 0 and not status.bookComplete and status.reason == 'restricted-value')
    local id, why = c:ResolveSelection('529', { spec = 'pet' })
    assert(id == nil and why == 'restricted-value')
    a.Platform.GetSpellInfo = function() return nil, 'restricted-value' end
    id, why = c:ResolveSelection('999')
    assert(id == nil and why == 'restricted-value')
end)

test('scoped native-name fallback cannot escape player or pet membership', function()
    local f = fixture()
    local c = f.addon.SpellCatalog
    f.addon.specSpells.pet = {}
    local id, why = c:ResolveSelection('Earth Shield', { spec = 0 })
    assert(id == nil and why == 'spell-not-in-book', 'unlearned name escaped the player book')
    id, why = c:ResolveSelection('Lightning Bolt', { spec = 'pet' })
    assert(id == nil and why == 'spell-not-in-book', 'player spell escaped the pet book')
end)

finish()
