# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

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




class LocaleReportTests(unittest.TestCase):
    def report(self, base, translated='', source='', contracts=None, strict=False,
               manifest=None, registration='frFR', english_reuse=None):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root / 'Locales').mkdir()
            (root / 'Locales/enUS.lua').write_text(
                'local L=LibStub("AceLocale-3.0"):NewLocale(...,"enUS",true)\n' + base)
            if translated is not None:
                (root / 'Locales/frFR.lua').write_text(
                    'local L=LibStub("AceLocale-3.0"):NewLocale(...,"' + registration + '")\n'
                    'if not L then return end\n' + translated)
            (root / 'locales.xml').write_text(manifest or
                '<Ui><Script file="Locales/enUS.lua"/><Script file="Locales/frFR.lua"/></Ui>')
            (root / 'main.lua').write_text(source)
            return catalog.locale_report(root, contracts, strict, english_reuse)

    def test_partial_coverage_is_reported_not_completed_or_failed(self):
        r=self.report('L["A"]=true\nL["B"]=true\nL["C"]=true',
                      'L["A"]="Un"\nL["B"]=true')
        self.assertEqual(r['issues'], [])
        fr=r['locales']['frFR']
        self.assertEqual(fr['missing'], ['C']);self.assertEqual(fr['english_reuse'], ['B'])
        self.assertEqual(fr['translated'], ['A']);self.assertEqual(fr['explicit'], 2)
        self.assertFalse(fr['complete']);self.assertEqual(fr['fallback'], ['C'])
        self.assertTrue(self.report('L["A"]=true', '', strict=True)['issues'])

    def test_english_reuse_requires_explicit_attestation_for_strict_readiness(self):
        r=self.report('L["A"]=true','L["A"]=true',strict=True)
        self.assertFalse(r['locales']['frFR']['complete'])
        self.assertTrue(r['issues'])
        r=self.report('L["A"]=true','L["A"]=true',strict=True,english_reuse={'frFR':['A']})
        self.assertEqual(r['issues'],[])
        self.assertEqual(r['locales']['frFR']['intentional_english'],['A'])
        self.assertTrue(r['locales']['frFR']['complete'])
        r=self.report('L["A"]="English label"','L["A"]=true')
        self.assertEqual(r['locales']['frFR']['translated'],[])
        self.assertEqual(r['locales']['frFR']['english_reuse'],[])
        self.assertEqual(r['locales']['frFR']['key_reuse'],['A'])
        self.assertTrue(self.report('L["A"]=true','',english_reuse={'frFR':['Missing']})['issues'])

    def test_extra_conflicting_and_invalid_values_are_errors_identical_duplicates_reported(self):
        r=self.report('L["A"]=true', 'L["A"]="Un"\nL["A"]="Un"\nL["A"]="Autre"\nL["X"]=true\nL["A"]=false')
        joined=' '.join(r['issues'])
        for word in ['conflicting', 'extra', 'invalid']:self.assertIn(word, joined)
        self.assertEqual(len(r['locales']['frFR']['duplicates']), 3)

    def test_manifest_registration_order_and_unloaded_files_are_not_silently_accepted(self):
        r=self.report('L["A"]=true', 'L["A"]="Un"',registration='deDE')
        self.assertTrue(any('registration' in x for x in r['issues']))
        r=self.report('L["A"]=true','',manifest='<Ui><Script file="Locales/frFR.lua"/><Script file="Locales/enUS.lua"/></Ui>')
        self.assertTrue(any('enUS first' in x for x in r['issues']))
        r=self.report('L["A"]=true','',manifest='<Ui><Script file="Locales/enUS.lua"/></Ui>')
        self.assertTrue(any('not loaded' in x for x in r['issues']))

    def test_computed_values_and_keys_are_explicitly_unchecked_not_translated(self):
        r=self.report('L["A"]=true\nL["Prefix"..color.WHITE]=true', 'L["A"]=select(1,"Un")')
        self.assertEqual(r['locales']['frFR']['translated'], [])
        self.assertEqual(r['locales']['frFR']['unchecked'], ['A'])
        self.assertGreater(r['computed_key_sites'], 0)
        self.assertIn('literal',r['scope'])

    def test_printf_is_classified_from_real_consumers_not_documentation_examples(self):
        base='L["Count %02d: %s (%%)"]=true\nL["Help.Example"]="Use %s or {x} as examples"'
        source='string.format(L["Count %02d: %s (%%)"], n, name)'
        r=self.report(base,'L["Count %02d: %s (%%)"]="%s %02d %%"\nL["Help.Example"]="Exemples libres"',source)
        self.assertEqual(len(r['issues']),1,r['issues']);self.assertIn('printf',r['issues'][0])
        self.assertEqual(self.report(base,'L["Count %02d: %s (%%)"]="Nombre %02d : %s (%%)"',source)['issues'],[])
        r=self.report('L["A"]= "%d"','L["A"]="%1$d"',contracts={'A':['printf']})
        self.assertTrue(any('positional' in x for x in r['issues']))

    def test_only_complete_literal_format_arguments_are_auto_classified(self):
        r=self.report('L["A"]="A prefix %"','L["A"]="Préfixe %"',
                      'string.format(L["A"] .. suffix, n)')
        self.assertEqual(r['issues'],[])
        self.assertNotIn('A',r['classified_keys'])

    def test_printf_preserves_precision_escape_count_and_rejects_trailing_percent(self):
        self.assertEqual(self.report('L["A"]="%s %% %d"','L["A"]="%% %s %d"',contracts={'A':['printf']})['issues'],[])
        for target in ['%.1f %s %%','%.2f %d %%','%.2f %s','%.2f %s %','%q %s %%']:
            self.assertTrue(self.report('L["A"]="%.2f %s %%"','L["A"]='+repr(target),contracts={'A':['printf']})['issues'],target)

    def test_named_summaries_reorder_slots_but_preserve_multiplicity_primary_and_escaping(self):
        base='L["A"]="{unit} {{!is|is not}} {value} {{{{literal}}}}"'
        good='L["A"]="{value} — {unit} {{!est|pas}} {{{{littéral}}}}"'
        self.assertEqual(self.report(base,good,contracts={'A':['summary']})['issues'],[])
        for target in ['{unit} {{est|pas}} {value} {{{{x}}}}','{unit} {{!est|pas}} {wrong} {{{{x}}}}','{unit} {unit} {{!est|pas}} {value} {{{{x}}}}','{unit} {{!est}} {value}','{unit} {{!est|pas}} {value} }']:
            self.assertTrue(self.report(base,'L["A"]='+repr(target),contracts={'A':['summary']})['issues'],target)

    def test_primary_marker_cannot_move_to_another_inline_predicate(self):
        r=self.report('L["A"]="{unit} {{!is|is not}} primary; {{has|has not}} qualifier"',
                      'L["A"]="{unit} {{is|is not}} primary; {{!has|has not}} qualifier"',
                      contracts={'A':['summary']})
        self.assertTrue(any('summary' in issue for issue in r['issues']))

    def test_attested_english_reuse_cannot_certify_true_that_displays_a_stable_key(self):
        r=self.report('L["Default.TBC.Mage.Starter.Name"]="Mage: early leveling (1–29)"',
                      'L["Default.TBC.Mage.Starter.Name"]=true',strict=True,
                      english_reuse={'frFR':['Default.TBC.Mage.Starter.Name']})
        self.assertFalse(r['locales']['frFR']['complete'])
        self.assertEqual(r['locales']['frFR']['intentional_english'],[])
        self.assertTrue(r['issues'])
        self.assertEqual(r['locales']['frFR']['key_reuse'],['Default.TBC.Mage.Starter.Name'])
        good=self.report('L["Stable.Name"]="English label"','L["Stable.Name"]="English label"',
                         strict=True,english_reuse={'frFR':['Stable.Name']})
        self.assertEqual(good['issues'],[])

    def test_announcement_tokens_are_a_different_contract_than_summary_predicates(self):
        base='L["A"]="{{spell}} at {{target}}"'
        self.assertEqual(self.report(base,'L["A"]="{{target}} : {{spell}}"',contracts={'A':['announcement']})['issues'],[])
        self.assertTrue(self.report(base,'L["A"]="{{target}} : {{item}}"',contracts={'A':['announcement']})['issues'])

    def test_markup_allows_human_link_caption_but_not_payload_or_delimiter_changes(self):
        base='L["A"]="|cffaabbcc|Hspell:123|h[Spell]|h|r |Ticon:16|t |Aatlas:16:16|a"'
        good='L["A"]="|cffaabbcc|Hspell:123|h[Sort traduit]|h|r |Ticon:16|t |Aatlas:16:16|a"'
        self.assertEqual(self.report(base,good,contracts={'A':['markup']})['issues'],[])
        for changed in [good.replace('spell:123','spell:124'),good.replace('ffaabbcc','ffaabbaa'),good.replace('|h|r','|r'),good.replace('icon:16','other:16'),good.replace('|a"','|t"'),good[:-1]+' |Kopaque|k"']:
            self.assertTrue(self.report(base,changed,contracts={'A':['markup']})['issues'],changed)

    def test_explicit_contract_mistakes_are_errors_and_plain_prose_stays_plain(self):
        self.assertTrue(self.report('L["A"]=true','',contracts={'Missing':['printf']})['issues'])
        self.assertTrue(self.report('L["A"]=true','',contracts={'A':['guess']})['issues'])
        self.assertEqual(self.report('L["A"]="50% {ordinary} | prose"','L["A"]="Texte libre"')['issues'],[])

    def test_actual_english_dictionary_retains_existing_literal_gate(self):
        self.assertEqual(catalog.check(ROOT),[])
        r=catalog.locale_report(ROOT)
        self.assertEqual(r['issues'],[])
        # English plus the ten shipped translations, each read across the main catalog and the text bundles.
        self.assertEqual(set(r['locales']),{'enUS','deDE','esES','esMX','frFR','itIT','koKR','ptBR','ruRU','zhCN','zhTW'})
        self.assertFalse(r['literal_complete'])
        # Computed keys (L[prefix..x]) in locale files are reported, never certified; the shipped files hold none now.
        self.assertIsInstance(r['computed_key_sites'],int)


if __name__ == '__main__':
    unittest.main()
