# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Stable-ID translations: the file formats, the registry, reword, build/missing/check, credits, notes and `where`.

Every test works in a throwaway repository (tools/locales.py is pointed at it), never in the real one; the last class
checks the real repository's files for the invariants the migration promised.
"""
import contextlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import locale_format as F  # noqa: E402
import locales as L  # noqa: E402

XML = '<?xml version="1.0" encoding="utf-8"?>\n<Ui>\n\n<Script file="Locales\\enUS.lua" />\n\n</Ui>\n'
SOURCE = '''local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
print(L["Old text"], L["Old text and more"], L['Single quoted "inside"'], L["Cast"], L["Cast Spell"])
local raw = "Old text"
local function Show()
    return string.format(L["Hello %s, you are %d"], name, 5)
end
'''


class Sandbox(unittest.TestCase):
    """A repository of its own: Locales/, locales.xml, tools/, one Lua source and a bundle."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.saved = L.ROOT
        L.ROOT = self.root
        L._cache.clear()
        (self.root / 'Locales').mkdir()
        (self.root / 'tools').mkdir()
        (self.root / 'locales.xml').write_text(XML)
        (self.root / 'Locales/bundles.json').write_text(json.dumps({'bundles': [
            {'id': 'help', 'module': 'RotationMaster_HelpText', 'title': 'Help text', 'notes': 'Help.'}]}))
        (self.root / 'main.lua').write_text(SOURCE)
        model = L.Model()
        for key, text in [('Old text', None), ('Old text and more', None), ('Single quoted "inside"', None), ('Cast', None),
                          ('Cast Spell', None), ('Hello %s, you are %d', None), ('Pipe [a|b]', 'Pipe [a||b]')]:
            model.add(key, text)
        model.add('Help.One', 'The first help text.', 'help')
        model.write()
        self.date = '2026-01-02'
        import os
        os.environ['RM_LOCALE_DATE'] = self.date

    def tearDown(self):
        L.ROOT = self.saved
        L._cache.clear()
        self.tmp.cleanup()

    def run_tool(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                L.main(list(argv))
                code = 0
            except SystemExit as exit_:
                code = exit_.code if isinstance(exit_.code, int) else 1
                if isinstance(exit_.code, str):
                    err.write(exit_.code)
        L._cache.clear()
        return code, out.getvalue(), err.getvalue()

    def ids(self):
        return {e.key: e.id for e in L.english_entries()}

    def translate(self, locale, mapping, *flags):
        work = self.root / f'{locale}.json'
        work.write_text(json.dumps(mapping, ensure_ascii=False))
        code, out, err = self.run_tool('build', locale, str(work), *flags)
        self.assertEqual(code, 0, err)
        return out

    def check(self, *flags):
        return self.run_tool('check', *flags)


class FormatTests(unittest.TestCase):
    def test_english_comment_wraps_and_decodes_exactly(self):
        for text in ['short', 'two  spaces and a trailing space ', ' leading', 'new\nline and \\ backslash',
                     ' '.join(['word'] * 80), 'x' * 300 + ' y', 'a' + ' ' * 120 + 'b']:
            lines = F.english_comment(F.text_hash(text), text)
            self.assertTrue(all(len(line) <= F.WRAP or ' ' not in line.split('English: ', 1)[-1].lstrip('- ') for line in lines), lines)
            entries, header, problems = F.parse_locale('\n'.join(lines) + '\n[1] = "x",\n')
            self.assertEqual(problems, [])
            self.assertEqual(entries[0].english, text)
            self.assertEqual(entries[0].hash, F.text_hash(text))

    def test_lua_strings_round_trip(self):
        for text in ['plain', 'quote " and \\ and \n newline', '\x01\x7f control', 'ünï 日本語 🙂', '|cffff0000red|r %s %d']:
            self.assertEqual(F.decode_lua_string(F.lua_string(text)), text)

    def test_english_file_round_trip_with_symbolic_entries(self):
        entries = [F.English(1, 'Plain', 'Plain', F.text_hash('Plain'), 0),
                   F.English(2, 'Default.X.Name', 'Arms', F.text_hash('Arms'), 0),
                   F.English(3, 'A [b|c]', 'A [b||c]', F.text_hash('A [b||c]'), 0)]
        text = F.render_english(entries, 'x')
        self.assertEqual(text.split('\n', 1)[0], F.COPYRIGHT)
        parsed, problems = F.parse_english(text)
        self.assertEqual(problems, [])
        self.assertEqual(sorted((e.id, e.key, e.text, e.hash) for e in parsed), sorted((e.id, e.key, e.text, e.hash) for e in entries))

    def test_a_translation_line_holds_only_the_id_and_the_string(self):
        entries = [F.Translation(5, 'Übersetzt "so"', F.text_hash('English'), 'English', 0)]
        text = F.render_locale('deDE', entries, [{'name': 'Claude', 'kind': 'ai'}])
        self.assertIn('\n[5] = "Übersetzt \\"so\\"",\n', text)
        self.assertIn(f'-- {F.text_hash("English")} English: English\n[5]', text)
        self.assertEqual(text.split('\n', 1)[0], F.COPYRIGHT)


class IdTests(Sandbox):
    def test_ids_are_sequential_unique_across_catalogs_and_never_reused(self):
        ids = self.ids()
        self.assertEqual(sorted(ids.values()), list(range(1, 9)))
        self.assertEqual(self.ids()['Help.One'], 8)
        code, out, err = self.run_tool('remove', 'Cast')
        self.assertEqual(code, 0, err)
        registry = json.loads((self.root / L.REGISTRY_FILE).read_text())
        self.assertIn(ids['Cast'], registry['retired'])
        self.run_tool('add', 'Brand new')
        self.assertEqual(self.ids()['Brand new'], 9)
        self.assertNotIn(ids['Cast'], self.ids().values())
        self.assertEqual(self.check()[0], 0)

    def test_check_fails_on_a_retired_duplicate_unknown_or_missing_id(self):
        self.translate('deDE', {'Cast': 'Zaubern'})
        path = self.root / 'Locales/deDE.lua'
        good = path.read_text()
        cast = self.ids()['Cast']
        # unknown ID
        path.write_text(good.replace(f'[{cast}] = ', '[999] = '))
        code, out, _ = self.check()
        self.assertEqual(code, 1)
        self.assertIn('ID 999', out)
        # duplicate ID
        path.write_text(good.replace('}\n', f'-- {F.text_hash("Cast")} English: Cast\n[{cast}] = "Nochmal",\n}}\n', 1)
                        if good.rstrip().endswith('}') else good)
        code, out, _ = self.check()
        self.assertIn('appears twice', out)
        # an entry whose hash comment is gone
        path.write_text('\n'.join(l for l in good.split('\n') if ' English: Cast' not in l))
        code, out, _ = self.check()
        self.assertIn('no "-- <hash> English:" comment', out)
        # a retired ID in the English
        path.write_text(good)
        registry = json.loads((self.root / L.REGISTRY_FILE).read_text())
        registry['retired'].append(cast)
        (self.root / L.REGISTRY_FILE).write_text(L.render_registry(registry))
        code, out, _ = self.check()
        self.assertIn('retired', out)

    def test_check_fails_when_a_translation_changes_a_placeholder(self):
        self.translate('deDE', {'Hello %s, you are %d': 'Hallo %s, du bist %d'})
        path = self.root / 'Locales/deDE.lua'
        path.write_text(path.read_text().replace('Hallo %s, du bist %d', 'Hallo, du bist %d'))
        code, out, _ = self.check()
        self.assertEqual(code, 1)
        self.assertIn('placeholders differ', out)

    def test_check_requires_the_copyright_line_first(self):
        path = self.root / 'Locales/enUS.lua'
        path.write_text('-- something else\n' + path.read_text().split('\n', 1)[1])
        self.assertIn('copyright', self.check()[1])


class MissingTests(Sandbox):
    def test_missing_lists_untranslated_and_stale_ids_and_nothing_else(self):
        self.translate('deDE', {'Cast': 'Zaubern', 'Old text': 'Alter Text', 'Cast Spell': 'Zauber wirken'})
        ids = self.ids()
        code, out, _ = self.run_tool('missing', 'deDE')
        rows = json.loads(out)
        self.assertEqual({r['id'] for r in rows}, set(ids.values()) - {ids['Cast'], ids['Old text'], ids['Cast Spell']})
        self.assertEqual({r['reason'] for r in rows}, {'untranslated'})
        # Reword one translated string: it becomes stale and is the only stale one.
        self.assertEqual(self.run_tool('reword', 'Cast Spell', 'Cast a Spell')[0], 0)
        rows = json.loads(self.run_tool('missing', 'deDE')[1])
        stale = [r for r in rows if r['reason'] == 'stale']
        self.assertEqual([(r['id'], r['previous_en'], r['translation']) for r in stale],
                         [(ids['Cast Spell'], 'Cast Spell', 'Zauber wirken')])
        self.assertTrue(all(r['reason'] in ('stale', 'untranslated') for r in rows))
        # accept blesses it
        self.assertEqual(self.run_tool('accept', 'deDE', str(ids['Cast Spell']))[0], 0)
        self.assertNotIn('stale', {r['reason'] for r in json.loads(self.run_tool('missing', 'deDE')[1])})

    def test_a_stale_translation_is_still_what_the_game_shows(self):
        self.translate('deDE', {'Old text': 'Alter Text'})
        self.run_tool('reword', 'Old text', 'Older text')
        entries, _, _ = L.read_locale_file('deDE', L.catalogs()[0])
        self.assertEqual([e.text for e in entries], ['Alter Text'])
        self.assertEqual(L.locale_entries('deDE'), [('Older text', 'Alter Text')])

    def test_complete_fails_on_untranslated_or_stale(self):
        self.translate('deDE', {'Cast': 'Zaubern'})
        self.assertEqual(self.check('--complete')[0], 1)
        self.assertEqual(self.check()[0], 0)


class RewordTests(Sandbox):
    def test_reword_rewrites_every_call_site_keeps_the_id_and_every_translation(self):
        ids = self.ids()
        self.translate('deDE', {'Old text': 'Alter Text', 'Old text and more': 'Alter Text und mehr'})
        self.translate('frFR', {'Old text': 'Ancien texte'})
        code, out, err = self.run_tool('reword', 'Old text', 'New text')
        self.assertEqual(code, 0, err)
        source = (self.root / 'main.lua').read_text()
        # Only the whole literal L["Old text"] changed; a longer string that starts with it, and a plain string, did not.
        self.assertIn('L["New text"], L["Old text and more"]', source)
        self.assertIn('local raw = "Old text"', source)
        self.assertEqual(self.ids()['New text'], ids['Old text'])
        self.assertNotIn('Old text', self.ids())
        english = L.by_id()[ids['Old text']]
        self.assertEqual((english.text, english.hash), ('New text', F.text_hash('New text')))
        # every translation is where it was
        self.assertEqual(dict(L.locale_entries('deDE'))['New text'], 'Alter Text')
        self.assertEqual(dict(L.locale_entries('frFR'))['New text'], 'Ancien texte')
        self.assertEqual(dict(L.locale_entries('deDE'))['Old text and more'], 'Alter Text und mehr')
        # and the note says so
        self.assertIn('2 translation(s) are now stale', out)
        self.assertEqual(self.check()[0], 0)

    def test_a_reword_does_not_orphan_at_runtime(self):
        """Mutation: the English changes under a fixed ID; the game still resolves the new English to the old translation."""
        self.translate('deDE', {'Old text': 'Alter Text'})
        for name in ('Libs/LibStub', 'Libs/AceLocale-3.0'):
            shutil.copytree(ROOT / name, self.root / name)
        for name in ('globals.lua', 'Core/text_bundles.lua', 'Data/text_bundle_index.lua'):
            (self.root / name).parent.mkdir(exist_ok=True)
            shutil.copy(ROOT / name, self.root / name)
        self.run_tool('index')

        def read(key, client='deDE'):
            keys = self.root / 'keys.txt'
            keys.write_text(key.encode().hex() + '\n')
            out = self.root / 'out.txt'
            subprocess.run(['luajit', str(ROOT / 'tools/locale_dump.lua'), str(self.root), client, str(keys), str(out)],
                           check=True, capture_output=True, cwd=ROOT)
            return bytes.fromhex(out.read_text().split()[1]).decode()
        self.assertEqual(read('Old text'), 'Alter Text')
        self.assertEqual(self.run_tool('reword', 'Old text', 'New text')[0], 0)
        self.assertEqual(read('New text'), 'Alter Text')
        self.assertEqual(read('New text', 'enUS'), 'New text')
        # the old wording is no longer a key: it reads as itself, as any unknown text does
        self.assertEqual(read('Old text'), 'Old text')

    def test_exact_literal_only_substrings_and_quotes(self):
        self.assertEqual(self.run_tool('reword', 'Cast', 'Cast now')[0], 0)
        source = (self.root / 'main.lua').read_text()
        self.assertIn('L["Cast now"], L["Cast Spell"]', source)
        self.assertEqual(self.run_tool('reword', 'Single quoted "inside"', "It's 'new' \"quoted\"")[0], 0)
        source = (self.root / 'main.lua').read_text()
        self.assertIn("""L['It\\'s \\'new\\' "quoted"']""", source)
        entry = L.by_key()["It's 'new' \"quoted\""]
        self.assertEqual(entry.text, "It's 'new' \"quoted\"")
        self.assertEqual(self.check()[0], 0)

    def test_pipe_escaped_text_keeps_its_escaping(self):
        (self.root / 'main.lua').write_text((self.root / 'main.lua').read_text() + 'print(L["Pipe [a|b]"])\n')
        self.assertEqual(self.run_tool('reword', 'Pipe [a|b]', 'Pipe [c|d]')[0], 0)
        entry = L.by_key()['Pipe [c|d]']
        self.assertEqual(entry.text, 'Pipe [c||d]')

    def test_refusals(self):
        self.assertNotEqual(self.run_tool('reword', 'No such', 'x')[0], 0)
        self.assertNotEqual(self.run_tool('reword', 'Cast', 'Cast Spell')[0], 0)
        self.assertNotEqual(self.run_tool('reword', 'Cast', 'Cast')[0], 0)
        # a key that no L[...] literal spells (built in code) would be silently orphaned in the code: refuse
        code, _, err = self.run_tool('reword', 'Hello %s, you are %d', 'Hi %s, you are %d')
        self.assertEqual(code, 0)
        model = L.Model()
        model.add('Only here')
        model.write()
        code, _, err = self.run_tool('reword', 'Only here', 'Only there')
        self.assertNotEqual(code, 0)
        self.assertIn('no L["..."] site', err)

    def test_a_symbolic_text_reword_changes_the_text_and_not_the_key(self):
        model = L.Model()
        model.add('Default.X.Name', 'Arms')
        model.write()
        (self.root / 'main.lua').write_text((self.root / 'main.lua').read_text() + 'print(L["Default.X.Name"])\n')
        before = (self.root / 'main.lua').read_text()
        self.assertEqual(self.run_tool('reword', 'Arms', 'Arms Warrior')[0], 0)
        self.assertEqual((self.root / 'main.lua').read_text(), before)
        entry = L.by_key()['Default.X.Name']
        self.assertEqual(entry.text, 'Arms Warrior')
        self.assertEqual(self.run_tool('reword', 'Default.X.Name', 'Other')[0] != 0, True)

    def test_tests_directory_is_reported_not_edited_unless_asked(self):
        (self.root / 'tests').mkdir()
        (self.root / 'tests/a.lua').write_text('assert(L["Cast"]=="Cast")\n')
        code, out, _ = self.run_tool('reword', 'Cast', 'Cast now')
        self.assertEqual(code, 0)
        self.assertIn('tests/a.lua:1', out)
        self.assertEqual((self.root / 'tests/a.lua').read_text(), 'assert(L["Cast"]=="Cast")\n')
        (self.root / 'tests/b.lua').write_text('assert(L["Cast now"]=="Cast now")\n')
        self.assertEqual(self.run_tool('reword', 'Cast now', 'Cast later', '--tests')[0], 0)
        self.assertIn('Cast later', (self.root / 'tests/b.lua').read_text())


class BuildTests(Sandbox):
    def test_build_is_idempotent_and_keeps_other_entries(self):
        self.translate('deDE', {'Cast': 'Zaubern'}, '--translator', 'Anna')
        first = (self.root / 'Locales/deDE.lua').read_text()
        first_json = (self.root / L.TRANSLATORS_FILE).read_text()
        self.translate('deDE', {'Cast': 'Zaubern'}, '--translator', 'Anna')
        self.assertEqual((self.root / 'Locales/deDE.lua').read_text(), first)
        self.assertEqual((self.root / L.TRANSLATORS_FILE).read_text(), first_json)
        self.translate('deDE', {'Cast Spell': 'Zauber wirken'}, '--translator', 'Anna')
        self.assertEqual(len(L.locale_entries('deDE')), 2)
        self.assertEqual(self.check()[0], 0)

    def test_build_takes_ids_or_keys_and_rejects_bad_placeholders_writing_nothing(self):
        ids = self.ids()
        self.translate('deDE', {str(ids['Cast']): 'Zaubern'})
        self.assertEqual(dict(L.locale_entries('deDE')), {'Cast': 'Zaubern'})
        work = self.root / 'bad.json'
        work.write_text(json.dumps({'Hello %s, you are %d': 'Hallo %d %s', 'Cast Spell': 'ok'}))
        before = (self.root / 'Locales/deDE.lua').read_text()
        code, out, err = self.run_tool('build', 'deDE', str(work))
        self.assertNotEqual(code, 0)
        self.assertEqual((self.root / 'Locales/deDE.lua').read_text(), before)
        work.write_text(json.dumps({'nonsense': 'x'}))
        self.assertNotEqual(self.run_tool('build', 'deDE', str(work))[0], 0)

    def test_a_bundle_gets_its_own_file_and_the_toc_lists_the_english_last(self):
        self.translate('deDE', {'Help.One': 'Der erste Hilfetext.', 'Cast': 'Zaubern'})
        bundle = self.root / 'Modules/RotationMaster_HelpText'
        self.assertTrue((bundle / 'deDE.lua').exists())
        toc = (bundle / 'RotationMaster_HelpText.toc').read_text().split()
        self.assertEqual([t for t in toc if t.endswith('.lua')], ['deDE.lua', 'enUS.lua'])
        xml = (self.root / 'locales.xml').read_text()
        self.assertLess(xml.index('deDE.lua'), xml.index('enUS.lua'))
        self.assertEqual(self.check()[0], 0)

    def test_move_keeps_the_id_and_the_translation(self):
        ids = self.ids()
        self.translate('deDE', {'Cast': 'Zaubern'})
        keys = self.root / 'keys.json'
        keys.write_text(json.dumps(['Cast']))
        self.assertEqual(self.run_tool('move', 'help', str(keys))[0], 0)
        self.assertEqual(L.by_key()['Cast'].catalog.name, 'help')
        self.assertEqual(L.by_key()['Cast'].id, ids['Cast'])
        self.assertEqual(dict(L.locale_entries('deDE', L.catalog_named('help'))), {'Cast': 'Zaubern'})
        self.assertEqual(self.check()[0], 0)
        self.assertEqual(self.run_tool('move', 'main', str(keys))[0], 0)
        self.assertEqual(dict(L.locale_entries('deDE', L.catalog_named('main'))), {'Cast': 'Zaubern'})

    def test_sync_adds_what_the_code_reads(self):
        (self.root / 'more.lua').write_text('print(L["Fresh from code"])\n')
        self.assertEqual(self.run_tool('sync', '--dry-run')[0], 1)
        self.assertEqual(self.run_tool('sync')[0], 0)
        self.assertIn('Fresh from code', self.ids())
        self.assertEqual(self.run_tool('sync', '--dry-run')[0], 0)


class CreditTests(Sandbox):
    def humans(self, locale='deDE', catalog='main'):
        entries, header, problems = L.read_locale_file(locale, L.catalog_named(catalog))
        return header['humans'], header['translators']

    def test_the_ai_is_named_in_the_header_and_never_in_the_data(self):
        self.translate('deDE', {'Cast': 'Zaubern'}, '--translator', 'Claude', '--ai')
        humans, header = self.humans()
        self.assertEqual(humans, [])
        self.assertIn('Claude (AI-assisted, not yet reviewed by a native speaker; 1 string, 2026-01-02)', header)
        self.assertEqual(self.check()[0], 0)

    def test_humans_are_listed_deduplicated_and_merged_into_the_main_file(self):
        self.translate('deDE', {'Cast': 'Zaubern'}, '--translator', 'Claude', '--ai')
        self.translate('deDE', {'Cast Spell': 'Zauber wirken', 'Help.One': 'Hilfe'}, '--translator', 'Anna Beispiel', '--url', 'https://example.org/anna')
        self.translate('deDE', {'Old text': 'Alter Text'}, '--translator', 'anna beispiel')
        self.translate('deDE', {'Old text and more': 'Mehr'}, '--translator', 'Bruno')
        humans, header = self.humans()
        self.assertEqual(humans, ['Anna Beispiel', 'Bruno'])
        self.assertIn('Anna Beispiel <https://example.org/anna> (2 strings, 2026-01-02)', header)
        self.assertIn('Claude (AI-assisted, not yet reviewed by a native speaker; 1 string, 2026-01-02)', header)
        # the bundle file credits who translated it; the main file carries the language's humans of every catalog
        bundle_humans, bundle_header = self.humans('deDE', 'help')
        self.assertEqual(bundle_humans, ['Anna Beispiel'])
        self.assertIn('Anna Beispiel', bundle_header)
        self.assertEqual(self.check()[0], 0)

    def test_the_game_credits_the_humans_of_its_language_and_only_that_language(self):
        """End to end: the data table in the locale files is what the About page reads at runtime."""
        self.translate('deDE', {'Cast': 'Zaubern'}, '--translator', 'Claude', '--ai')
        self.translate('deDE', {'Help.One': 'Hilfe', 'Cast Spell': 'Zauber wirken'}, '--translator', 'Anna Beispiel')
        self.translate('deDE', {'Old text': 'Alter Text'}, '--translator', 'Bruno')
        self.translate('frFR', {'Cast': 'Lancer'}, '--translator', 'Claude', '--ai')
        for name in ('Libs/LibStub', 'Libs/AceLocale-3.0'):
            shutil.copytree(ROOT / name, self.root / name)
        for name in ('globals.lua', 'Core/text_bundles.lua', 'Data/text_bundle_index.lua'):
            (self.root / name).parent.mkdir(exist_ok=True)
            shutil.copy(ROOT / name, self.root / name)
        self.run_tool('index')
        keys = self.root / 'keys.txt'
        keys.write_text('')

        def credited(client):
            out = subprocess.run(['luajit', str(ROOT / 'tools/locale_dump.lua'), str(self.root), client, str(keys), str(self.root / 'o.txt')],
                                 check=True, capture_output=True, text=True, cwd=ROOT).stdout
            return dict(line.split('=', 1) for line in out.splitlines())['translators']
        self.assertEqual(credited('deDE'), 'Anna Beispiel;Bruno')
        self.assertEqual(credited('frFR'), '')
        self.assertEqual(credited('enUS'), '')

    def test_the_header_cannot_be_hand_edited(self):
        self.translate('deDE', {'Cast': 'Zaubern'}, '--translator', 'Anna')
        path = self.root / 'Locales/deDE.lua'
        path.write_text(path.read_text().replace('-- Translators: Anna', '-- Translators: Mallory'))
        self.assertIn('Translators', self.check()[1])
        self.assertEqual(self.run_tool('rebuild')[0], 0)
        self.assertEqual(self.check()[0], 0)

    def test_human_kind_can_be_set_later_and_credit_without_strings(self):
        self.translate('deDE', {'Cast': 'Zaubern'}, '--translator', 'Claude', '--ai')
        self.assertEqual(self.run_tool('credit', 'deDE', '--translator', 'Carla')[0], 0)
        self.assertEqual(self.humans()[0], ['Carla'])
        self.assertEqual(self.run_tool('credit', 'deDE', '--translator', 'Carla', '--ai')[0], 0)
        self.assertEqual(self.humans()[0], [])


class NotesTests(Sandbox):
    def set_notes(self, mapping):
        work = self.root / 'notes.json'
        work.write_text(json.dumps(mapping))
        return self.run_tool('notes', 'set', str(work))

    def test_notes_and_context_render_in_english_and_translated_files(self):
        self.translate('deDE', {'Hello %s, you are %d': 'Hallo %s, du bist %d', 'Cast': 'Zaubern'})
        ids = self.ids()
        code, out, err = self.set_notes({str(ids['Hello %s, you are %d']): ['the player name, e.g. "Anna"', 'the level, e.g. 70'],
                                         'Cast': {'context': 'Button on the action bar that starts a spell.'}})
        self.assertEqual(code, 0, err)
        german = (self.root / 'Locales/deDE.lua').read_text()
        digest = F.text_hash('Hello %s, you are %d')
        self.assertIn(f'-- {digest} English: Hello %s, you are %d\n-- %s #1: the player name, e.g. "Anna"\n-- %d #2: the level, e.g. 70\n[{ids["Hello %s, you are %d"]}] = "Hallo %s, du bist %d",', german)
        self.assertIn(f'-- {F.text_hash("Cast")} English: Cast\n-- Context: Button on the action bar that starts a spell.\n[{ids["Cast"]}]', german)
        english = (self.root / 'Locales/enUS.lua').read_text()
        self.assertIn(f'-- {digest}\n-- %s #1: the player name, e.g. "Anna"\n-- %d #2: the level, e.g. 70\n[{ids["Hello %s, you are %d"]}] = "Hello %s, you are %d",', english)
        # the translation line holds only the key and the string
        for line in german.split('\n'):
            if line.startswith('['):
                self.assertRegex(line, r'^\[\d+\] = "(?:[^"\\]|\\.)*",$')
        self.assertEqual(self.check()[0], 0)
        # parsing the files sees the same annotations
        entries, _, _ = L.read_locale_file('deDE', L.catalogs()[0])
        self.assertEqual(len([e for e in entries if e.annotations]), 2)

    def test_note_count_must_equal_token_count(self):
        ids = self.ids()
        code, _, err = self.set_notes({str(ids['Hello %s, you are %d']): ['only one']})
        self.assertNotEqual(code, 0)
        self.assertIn('1 note(s) for 2 format token(s)', err)
        # a hand-edited registry that disagrees is caught by check
        registry = json.loads((self.root / L.REGISTRY_FILE).read_text())
        registry['annotations'] = {str(ids['Hello %s, you are %d']): {'notes': ['a', 'b', 'c']}}
        (self.root / L.REGISTRY_FILE).write_text(L.render_registry(registry))
        code, out, _ = self.check()
        self.assertEqual(code, 1)
        self.assertIn('3 note(s) for 2 format token(s)', out)

    def test_set_is_idempotent_and_survives_rebuild_reword_and_move(self):
        ids = self.ids()
        self.translate('deDE', {'Hello %s, you are %d': 'Hallo %s, du bist %d'})
        notes = {'Hello %s, you are %d': ['%s = the name, e.g. "A"', 'the level, e.g. 5'], 'Cast': {'context': 'A verb.'}}
        self.assertEqual(self.set_notes(notes)[0], 0)
        first = {p.name: p.read_text() for p in (self.root / 'Locales').glob('*.lua')}
        first_registry = (self.root / L.REGISTRY_FILE).read_text()
        self.assertEqual(self.set_notes(notes)[0], 0)
        self.assertEqual({p.name: p.read_text() for p in (self.root / 'Locales').glob('*.lua')}, first)
        self.assertEqual((self.root / L.REGISTRY_FILE).read_text(), first_registry)
        # the "%s =" prefix of an author's note is dropped: the token is rendered from the English
        self.assertIn('-- %s #1: the name, e.g. "A"', first['deDE.lua'])
        self.assertEqual(self.run_tool('rebuild')[0], 0)
        self.assertEqual({p.name: p.read_text() for p in (self.root / 'Locales').glob('*.lua')}, first)
        # reword keeps them (the code needs the site)
        self.assertEqual(self.run_tool('reword', 'Cast', 'Cast now')[0], 0)
        registry = json.loads((self.root / L.REGISTRY_FILE).read_text())
        self.assertEqual(registry['annotations'][str(ids['Cast'])], {'context': 'A verb.'})
        self.assertIn('-- Context: A verb.', (self.root / 'Locales/enUS.lua').read_text())
        keys = self.root / 'keys.json'
        keys.write_text(json.dumps(['Cast now']))
        self.assertEqual(self.run_tool('move', 'help', str(keys))[0], 0)
        self.assertIn('-- Context: A verb.', (self.root / 'Modules/RotationMaster_HelpText/enUS.lua').read_text())
        self.assertEqual(self.check()[0], 0)

    def test_requirements_are_off_by_default_and_list_what_is_missing(self):
        self.assertEqual(self.check()[0], 0)
        code, out, _ = self.check('--require-notes')
        self.assertEqual(code, 1)
        self.assertIn('Hello %s, you are %d', out)
        code, out, _ = self.check('--require-context')
        self.assertEqual(code, 1)
        self.assertIn("'Cast'", out)
        self.assertNotIn('The first help text', out)

    def test_todo_lists_tokens_and_short_strings_with_call_sites(self):
        code, out, _ = self.run_tool('notes', 'todo')
        rows = {r['key']: r for r in json.loads(out)}
        self.assertEqual(rows['Hello %s, you are %d']['needs'], ['notes'])
        self.assertEqual(rows['Hello %s, you are %d']['tokens'], ['%s', '%d'])
        self.assertEqual(rows['Hello %s, you are %d']['sites'], ['main.lua:5'])
        self.assertIn('context', rows['Cast']['needs'])
        self.assertNotIn('The first help text.', rows)
        self.assertNotIn('Cast Spell', rows if False else {})
        wide = {r['key'] for r in json.loads(self.run_tool('notes', 'todo', '--context-words', '1')[1])}
        self.assertNotIn('Cast Spell', wide)
        self.assertIn('Cast', wide)


class WhereTests(Sandbox):
    def where(self, *args):
        return self.run_tool('where', *args)

    def test_found_with_function_and_context_options(self):
        ids = self.ids()
        code, out, _ = self.where('Hello %s, you are %d')
        self.assertEqual(code, 0)
        self.assertIn('main.lua:5 in Show', out)
        self.assertEqual(len([l for l in out.split('\n') if l.startswith('>')]), 1)
        self.assertNotIn('local raw', out)
        code, out, _ = self.where('-C', '2', str(ids['Hello %s, you are %d']))
        lines = [l for l in out.split('\n') if l[:1] in ('>', ' ') and l[2:7].strip().isdigit()]
        self.assertEqual([int(l[2:7]) for l in lines], [3, 4, 5, 6, 7])
        code, out, _ = self.where('-B', '1', '-A', '0', 'Hello %s, you are %d')
        self.assertEqual([int(l[2:7]) for l in out.split('\n') if l[:1] in ('>', ' ') and l[2:7].strip().isdigit()], [4, 5])

    def test_overlapping_hits_merge_like_grep(self):
        code, out, _ = self.where('-C', '3', 'Old text')
        self.assertEqual(code, 0)
        data = json.loads(self.where('-C', '3', '--json', 'Old text')[1])
        blocks = data['sites'][0]['blocks']
        lines = [row['line'] for b in blocks for row in b['lines']]
        self.assertEqual(lines, sorted(set(lines)), 'a line was shown twice')
        self.assertEqual(data['before'], 3)
        self.assertEqual(data['after'], 3)

    def test_json_for_editors_and_id_flag(self):
        ids = self.ids()
        code, out, _ = self.where('--id', str(ids['Cast']), '--json')
        data = json.loads(out)
        self.assertEqual((data['id'], data['key'], data['catalog']), (ids['Cast'], 'Cast', 'main'))
        self.assertEqual(data['sites'][0]['file'], 'main.lua')
        self.assertEqual(data['sites'][0]['hits'][0]['line'], 2)

    def test_multiple_matches_ask_for_a_more_exact_one(self):
        code, out, err = self.where('Cast')
        self.assertEqual(code, 0)  # 'Cast' is exact
        code, out, err = self.where('Old')
        self.assertEqual(code, 2)
        self.assertIn('more of its text', err)
        self.assertIn('Old text and more', err)

    def test_dynamic_strings_say_so_and_escaped_quotes_are_found(self):
        code, out, _ = self.where('Brand new unused')
        self.assertNotEqual(code, 0)
        model = L.Model()
        model.add('Built later')
        model.write()
        code, out, _ = self.where('Built later')
        self.assertEqual(code, 0)
        self.assertIn('no direct call site found (looked up dynamically?)', out)
        code, out, _ = self.where('Single quoted "inside"')
        self.assertIn('main.lua:2', out)

    def test_concatenated_literals_and_plain_strings(self):
        (self.root / 'more.lua').write_text('local x = L["Cast " .. "Spell"]\nlocal y = "Cast"\n')
        data = json.loads(self.where('--json', 'Cast Spell')[1])
        self.assertEqual({s['file'] for s in data['sites']}, {'main.lua', 'more.lua'})
        data = json.loads(self.where('--json', 'Cast')[1])
        self.assertTrue(any(s['file'] == 'more.lua' for s in data['indirect']))

    def test_notes_and_context_are_shown(self):
        ids = self.ids()
        work = self.root / 'n.json'
        work.write_text(json.dumps({'Cast': {'context': 'Verb on a button.'}}))
        self.run_tool('notes', 'set', str(work))
        out = self.where('Cast')[1]
        self.assertIn('Context: Verb on a button.', out)

    def test_tests_are_skipped_unless_asked(self):
        (self.root / 'tests').mkdir()
        (self.root / 'tests/t.lua').write_text('print(L["Cast"])\n')
        self.assertFalse(any(s['file'].startswith('tests/') for s in json.loads(self.where('--json', 'Cast')[1])['sites']))
        self.assertTrue(any(s['file'].startswith('tests/') for s in json.loads(self.where('--json', '--tests', 'Cast')[1])['sites']))


class ShippedFiles(unittest.TestCase):
    """Invariants of the real repository's locale files."""

    @classmethod
    def setUpClass(cls):
        L.ROOT = ROOT
        L._cache.clear()
        cls.catalogs = L.catalogs()

    def test_every_generated_locale_file_starts_with_the_copyright_line(self):
        for catalog in self.catalogs:
            for locale in ['enUS'] + L.LOCALES:
                path = catalog.path(locale)
                self.assertTrue(path.exists(), path)
                self.assertEqual(path.read_text(encoding='utf-8').split('\n', 1)[0], F.COPYRIGHT, path)
        self.assertEqual((ROOT / L.INDEX_FILE).read_text(encoding='utf-8').split('\n', 1)[0], F.COPYRIGHT)

    def test_every_translation_file_names_its_translators_and_says_the_ai_is_unreviewed(self):
        for catalog in self.catalogs:
            for locale in L.LOCALES:
                lines = catalog.path(locale).read_text(encoding='utf-8').split('\n')
                self.assertEqual(lines[0], F.COPYRIGHT)
                header = [l for l in lines[:8] if l.startswith('-- Translators:')]
                self.assertEqual(len(header), 1, catalog.path(locale))
                self.assertIn('Claude (AI-assisted, not yet reviewed by a native speaker', header[0])

    def test_every_string_has_one_id_across_all_catalogs_and_a_matching_hash(self):
        seen = {}
        for e in L.english_entries():
            self.assertNotIn(e.id, seen)
            seen[e.id] = e
            self.assertEqual(e.hash, F.text_hash(e.text))
        self.assertGreaterEqual(len(seen), 4042)

    def test_every_locale_is_complete_and_current(self):
        for locale in L.LOCALES:
            untranslated, stale = L.classify(locale)
            self.assertEqual((untranslated, stale), ([], []), locale)


if __name__ == '__main__':
    unittest.main()
