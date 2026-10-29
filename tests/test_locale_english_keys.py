# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""English locale entries must use the source text itself as their only lookup key."""
import sys
import subprocess
import json
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import locale_format as F
import catalog_check
import locales
import builtin_locales


class EnglishKeyTests(unittest.TestCase):
    def test_catalog_binds_english_text_directly_to_its_id(self):
        entry = F.English(17, 'Cast this spell', 'Cast this spell', F.text_hash('Cast this spell'), 0)
        rendered = F.render_english([entry], 'test catalog')
        self.assertIn('T["Cast this spell"] = 17', rendered)
        self.assertNotIn('local S =', rendered)
        parsed, problems = F.parse_english(rendered)
        self.assertEqual(problems, [])
        self.assertEqual([(e.id, e.key, e.text) for e in parsed], [(17, 'Cast this spell', 'Cast this spell')])

    def test_english_and_translated_values_are_populated(self):
        entries = [F.English(17, 'Cast this spell', 'Cast this spell', F.text_hash('Cast this spell'), 0),
                   F.English(18, 'Ready', 'Ready', F.text_hash('Ready'), 0)]
        catalog = F.render_english(entries, 'test catalog')
        lua = """local source = %s
local locale
LibStub = function() return { NewLocale = function() locale = {}; return locale end } end
local addon = {}
assert(loadstring(source))('Example', addon)
assert(locale['Cast this spell'] == 'Cast this spell' and locale['Ready'] == 'Ready')
addon = { translation = { [17] = 'Zauber wirken' } }
assert(loadstring(source))('Example', addon)
assert(locale['Cast this spell'] == 'Zauber wirken' and locale['Ready'] == 'Ready')
""" % F.lua_string(catalog)
        subprocess.run(['lua5.1', '-'], input=lua, text=True, check=True)

    def test_catalog_refuses_independent_english_text(self):
        entry = F.English(17, 'Old.Symbolic.Key', 'The text the player sees', F.text_hash('The text the player sees'), 0)
        with self.assertRaises(ValueError):
            F.render_english([entry], 'test catalog')

    def test_catalog_refuses_duplicate_english_keys(self):
        entries = [F.English(i, 'Same text', 'Same text', F.text_hash('Same text'), 0) for i in (17, 18)]
        with self.assertRaises(ValueError):
            F.render_english(entries, 'test catalog')

    def test_locale_authoring_refuses_symbolic_or_non_startup_entries(self):
        model = locales.Model.__new__(locales.Model)
        with self.assertRaises(SystemExit):
            model.add('Synthetic.Key', 'Visible English')
        model.catalogs = [locales.Catalog('help', Path('/unused'), 'RotationMaster_HelpText')]
        with self.assertRaises(SystemExit):
            model.add('Visible English', catalog='help')

    def test_class_catalog_populates_the_main_locale(self):
        entry = F.English(17, 'Class name', 'Class name', F.text_hash('Class name'), 0)
        catalog = F.render_english([entry], 'class', central_locale=True)
        lua = """local source = %s
local main = {}
LibStub = function() return { NewLocale = function() return {} end, GetLocale = function(_, name)
  assert(name == 'RotationMaster'); return main
end } end
assert(loadstring(source))('RotationMaster_Shaman', {translation = {[17] = 'Klassenname'}})
assert(main['Class name'] == 'Klassenname')
""" % F.lua_string(catalog)
        subprocess.run(['lua5.1', '-'], input=lua, text=True, check=True)

    def test_builtin_locales_require_both_keys_in_every_language(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'Locales').mkdir()
            (root / 'Locales/bundles.json').write_text(json.dumps({'bundles': [{'kind': 'builtin', 'module': 'RotationMaster_Shaman'}]}))
            module = root / 'Modules/RotationMaster_Shaman'
            (module / 'tbc').mkdir(parents=True)
            (module / 'Locales').mkdir()
            (module / 'tbc/a.lua').write_text('addon:RegisterDefaultRotation({\n id = "rm.tbc.shaman.test", revision = 1\n})\n')
            lines = 'L["rm.tbc.shaman.test.Name"] = "Name"\nL["rm.tbc.shaman.test.Description"] = "Description"\n'
            for locale in ['enUS'] + F.LOCALES:
                (module / 'Locales' / f'{locale}.lua').write_text(lines)
            (module / 'locales.xml').write_text('\n'.join(f'<Script file="Locales\\{locale}.lua" />' for locale in ['enUS'] + F.LOCALES))
            self.assertEqual(builtin_locales.check(root), [])
            (module / 'Locales/deDE.lua').write_text('L["rm.tbc.shaman.test.Name"] = "Name"\n')
            self.assertTrue(any('missing rm.tbc.shaman.test.Description' in issue for issue in builtin_locales.check(root)))


if __name__ == '__main__':
    unittest.main()
