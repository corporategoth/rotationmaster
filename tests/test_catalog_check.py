# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Real scanner fixtures: missing keys, comments and escaped keys, against English files in the generated ID layout."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import locale_format as F  # noqa: E402

SPEC = importlib.util.spec_from_file_location('catalog_check', ROOT / 'tools/catalog_check.py')
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)


def english(*rows):
    """An enUS.lua from (key, text) rows; text None means the key is its own English."""
    entries = []
    for number, (key, text) in enumerate(rows, 1):
        text = key if text is None else text
        entry = F.English(number, key, text, F.text_hash(text), 0)
        entries.append(entry)
    return F.render_english(entries, 'test catalog')


class CatalogTests(unittest.TestCase):
    def check(self, base, source, extra=None):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'Locales').mkdir()
            (root / 'Locales/enUS.lua').write_text(base)
            (root / 'main.lua').write_text(source)
            for name, text in (extra or {}).items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text(text)
            return catalog.check(root)

    def test_missing_key_detected_without_matching_comments_or_dynamic_prefixes(self):
        issues = self.check(english(('Known', None), ('Escaped "quote"', None)), '''-- L["Comment"]
--[=[ L["Long comment"] ]=]
local source = [[ L["Code in a string"] ]]
print(L["Known"], L["Missing"], L["Escaped \\"quote\\""], L["Prefix" .. color.RED])
''')
        self.assertEqual(len(issues), 1, issues)
        self.assertIn('Missing', issues[0])
        self.assertIn('main.lua:4', issues[0])

    def test_a_symbolic_key_is_a_defined_key(self):
        base = english(('Default.X.Name', 'Arms Warrior'), ('Plain', None))
        self.assertEqual(self.check(base, 'print(L["Default.X.Name"], L["Plain"])'), [])
        issues = self.check(base, 'print(L["Arms Warrior"])')
        self.assertEqual(len(issues), 1, issues)

    def test_long_string_removes_only_the_first_lua_opening_newline(self):
        self.assertEqual(self.check(english(('\nIntentional newline', None)), 'print(L[ [=[\n\nIntentional newline]=] ])'), [])
        self.assertEqual(catalog.decode_string('[=[\r\n\r\nText]=]'), '\nText')

    def test_a_key_defined_in_two_catalogs_is_reported(self):
        manifest = '{"bundles": [{"id": "help", "module": "RotationMaster_HelpText"}]}'
        issues = self.check(english(('Shared', None)), 'print(L["Shared"])', {
            'Locales/bundles.json': manifest,
            'Modules/RotationMaster_HelpText/enUS.lua': english(('Shared', None))})
        self.assertEqual(len(issues), 1, issues)
        self.assertIn('also defined', issues[0])

    def test_an_english_file_that_is_not_in_the_id_layout_is_reported(self):
        issues = self.check('L["Known"] = true\n[7] = "no hash comment above"\n', 'print(L["Known"])')
        self.assertTrue(any('no hash comment' in issue for issue in issues), issues)

    def test_actual_english_dictionary_retains_the_literal_gate(self):
        self.assertEqual(catalog.check(ROOT), [])


if __name__ == '__main__':
    unittest.main()
