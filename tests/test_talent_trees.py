"""The website's copy of the talent tree names (Data/talent_trees.json) is the addon's table."""
import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class TalentTreeExportTests(unittest.TestCase):
    def test_json_matches_the_lua_table(self):
        result = subprocess.run([sys.executable, str(ROOT / 'tools/export_talent_trees.py'), '--check'],
                                cwd='/tmp', capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_shape_for_the_site(self):
        data = json.loads((ROOT / 'Data/talent_trees.json').read_text(encoding='utf-8'))
        self.assertEqual(data['familyOrder'], ['era', 'tbc', 'wrath', 'cata', 'forever'])
        self.assertEqual(sorted(data['families']), sorted(data['familyOrder']))
        for key, row in data['families'].items():
            self.assertTrue(row['label'] and row['basis'], key)
            for class_token, names in row['classes'].items():
                self.assertEqual(len(names), 3, f'{key} {class_token}')
                self.assertEqual(len(set(names)), 3, f'{key} {class_token}')
        # The tree number a rotation saves is the position in the list.
        era = data['families']['era']['classes']
        self.assertEqual(era['SHAMAN'], ['Elemental', 'Enhancement', 'Restoration'])
        self.assertEqual(era['DRUID'][1], 'Feral Combat')
        self.assertNotIn('DEATHKNIGHT', era)
        self.assertEqual(data['families']['wrath']['classes']['DEATHKNIGHT'], ['Blood', 'Frost', 'Unholy'])


if __name__ == '__main__':
    unittest.main()
