# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""One rank option, one wording: "Use this exact spell rank", unticked by default.

"Match all ranks" (and its translations) was the aura option's old label; the
spell options said "Use this exact spell rank". Every rank surface now says the
latter, so the former must not survive anywhere a player or author reads:
enUS, every locale, help, tooltips, docs, premade names and descriptions.
Frozen predecessor fixtures (tests/fixtures/restore_*) record old text on
purpose and are the only exception.
"""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
LABEL = 'Use this exact spell rank'
LOCALES = ['deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW']
# A locale entry names its English source (key and "-- en:" comment), so the
# English phrase also proves no translation of the old label remains.
OLD = ['Match all ranks', 'match all ranks']
# Every place a rank checkbox is built or described.
SURFACES = ['Conditions/common.lua', 'Help/conditional.lua', 'Help/rotations.lua', 'UI/rotation_fields.lua',
            'UI/settings_announces.lua', 'UI/rotation_reference.lua']
SKIP = ('Libs/', 'LibsAugment/', '.git/', 'tests/fixtures/restore_', 'tests/test_rank_wording.py',
        'tests/rank_checkbox.lua')


def tracked():
    out = subprocess.run(['git', 'ls-files', '-co', '--exclude-standard'], cwd=ROOT, capture_output=True, text=True)
    files = [p for p in out.stdout.splitlines() if p and not p.startswith(SKIP)]
    return [p for p in files if p.endswith(('.lua', '.md', '.json', '.txt', '.toc', '.xml', '.py'))]


class RankWording(unittest.TestCase):
    def test_old_label_is_gone_everywhere(self):
        hits = []
        for rel in tracked():
            path = ROOT / rel
            if not path.is_file():
                continue
            text = path.read_text(encoding='utf-8', errors='replace')
            for old in OLD:
                if old in text:
                    hits.append(f'{rel}: {old}')
        self.assertEqual(hits, [], 'old "Match all ranks" wording remains')

    def test_every_locale_translates_the_shared_label(self):
        for name in ['enUS'] + LOCALES:
            text = (ROOT / f'Locales/{name}.lua').read_text(encoding='utf-8')
            # English maps the label to its ID; translations record the English above each entry.
            marker = f'N["{LABEL}"] = ' if name == 'enUS' else f' English: {LABEL}\n'
            self.assertIn(marker, text, name)

    def test_every_rank_surface_uses_the_shared_label(self):
        for rel in SURFACES + ['UI/rotation_fields.lua', 'UI/settings_announces.lua']:
            text = (ROOT / rel).read_text(encoding='utf-8')
            self.assertTrue(LABEL in text, f'{rel} does not use "{LABEL}"')

    def test_no_rank_surface_builds_its_own_unguarded_checkbox(self):
        # Each checkbox is guarded by the one client helper, never WOW_PROJECT_ID.
        for rel in ['Conditions/common.lua', 'UI/rotation_fields.lua', 'UI/settings_announces.lua',
                    'Help/conditional.lua', 'Help/rotations.lua', 'UI/rotation_reference.lua']:
            text = (ROOT / rel).read_text(encoding='utf-8')
            self.assertIn('ClientHasSpellRanks', text, rel)
            for line in text.splitlines():
                if LABEL in line and 'WOW_PROJECT' in line:
                    self.fail(f'{rel}: rank option decided from WOW_PROJECT_ID: {line.strip()}')


if __name__ == '__main__':
    unittest.main()
