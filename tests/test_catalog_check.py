"""Real scanner fixtures: missing keys, comments and escaped keys."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('catalog_check', ROOT / 'tools/catalog_check.py')
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)


class CatalogTests(unittest.TestCase):
    def check(self, base, source):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'Locales').mkdir()
            (root / 'Locales/enUS.lua').write_text(base)
            (root / 'main.lua').write_text(source)
            return catalog.check(root)

    def test_missing_key_detected_without_matching_comments_or_dynamic_prefixes(self):
        spec = importlib.util.spec_from_file_location('catalog_check', ROOT / 'tools/catalog_check.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'Locales').mkdir()
            (root / 'Locales/enUS.lua').write_text('L["Known"] = true\nL["Escaped \\"quote\\""] = true\n')
            (root / 'main.lua').write_text('''-- L["Comment"]
--[=[ L["Long comment"] ]=]
local source = [[ L["Code in a string"] ]]
print(L["Known"], L["Missing"], L["Escaped \\"quote\\""], L["Prefix" .. color.RED])
''')
            issues = module.check(root)
            self.assertEqual(len(issues), 1, issues)
            self.assertIn('Missing', issues[0])
            self.assertIn('main.lua:4', issues[0])

    def test_unassigned_base_reads_cannot_prove_their_own_definition(self):
        issues = self.check('L["Known"] = true\nlocal sample = L["Missing"]\n',
                            'print(L["Known"], L["Missing"])\n')
        self.assertEqual(len(issues), 2, issues)
        self.assertTrue(any('Locales/enUS.lua:2' in issue and 'Missing' in issue for issue in issues), issues)
        self.assertTrue(any('main.lua:1' in issue and 'Missing' in issue for issue in issues), issues)

    def test_base_alias_checks_its_read_instead_of_treating_it_as_a_definition(self):
        issues = self.check('L["Alias"] = L["Absent"]\n', 'print(L["Alias"])\n')
        self.assertEqual(len(issues), 1, issues)
        self.assertIn('Absent', issues[0])
        self.assertIn('Locales/enUS.lua:1', issues[0])

    def test_equality_and_inequality_are_reads_not_assignments(self):
        issues = self.check('if L["Equal"] == true then end\nif L["NotEqual"] ~= nil then end\n',
                            'print(L["Equal"], L["NotEqual"])\n')
        self.assertEqual(len(issues), 4, issues)

    def test_nil_false_and_other_obviously_invalid_base_values_are_not_translations(self):
        for value in ('nil', 'false', '17', '.5', '-17', '{}', 'function() end'):
            with self.subTest(value=value):
                issues = self.check('L["Broken"] = ' + value + '\n', 'print(L["Broken"])\n')
                self.assertTrue(any('invalid enUS value' in issue for issue in issues), issues)
                self.assertTrue(any('main.lua:1' in issue and 'Broken' in issue for issue in issues), issues)

    def test_valid_true_string_long_string_and_defined_alias_are_preserved(self):
        base = '''L["Same"] = true
L["Title"] = "A translated title"
L["Paragraph"] = [=[One paragraph\ncontinued here.]=]
L["Alias"] = L["Title"]
-- L["Fake"] = nil
local ignored = [==[L["Fake"] = nil]==]
'''
        self.assertEqual(self.check(base, 'print(L["Same"],L["Title"],L["Paragraph"],L["Alias"])'), [])

    def test_long_string_removes_only_the_first_lua_opening_newline(self):
        base = 'L[ [=[\n\nIntentional newline]=] ] = true\n'
        self.assertEqual(self.check(base, 'print(L["\\nIntentional newline"])'), [])
        self.assertEqual(catalog.decode_string('[=[\r\n\r\nText]=]'), '\nText')

    def test_computed_rhs_is_not_rejected_based_on_its_first_literal(self):
        base = '''L["Fallback"] = false or "A usable string"
L["NumericText"] = 17 .. " suffix"
L["Alias"] = L["Fallback"]
L["TableText"] = {} and "A usable string"
L["FunctionText"] = function() end and "A usable string"
'''
        self.assertEqual(self.check(base, 'print(L["Fallback"],L["NumericText"],L["Alias"],L["TableText"],L["FunctionText"])'), [])


if __name__ == '__main__':
    unittest.main()
