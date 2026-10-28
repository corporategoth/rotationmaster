# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Load-on-demand text bundles: every key complete in every language, one owner per key, a fresh index.

The Lua side (tests/text_bundles.lua) proves the runtime; this proves the files. The main catalog may carry
untranslated keys (the game shows English); a bundle may not, because a translator who changes the main
catalog cannot see a bundle's gaps and a player who opens that window would see English among their language.
"""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))

import locales as L  # noqa: E402
import translation_lib as T  # noqa: E402


class BundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.bundles = [c for c in L.catalogs() if not c.is_main]
        cls.corpus = T.Corpus()

    def test_the_manifest_names_the_bundles_the_runtime_expects(self):
        self.assertGreaterEqual(len(self.bundles), 4)
        for bundle in self.bundles:
            self.assertTrue(bundle.module.startswith('RotationMaster_'), bundle.module)
            self.assertTrue(bundle.directory.is_dir(), bundle.directory)
            self.assertGreater(len(L.english(bundle)), 0, f'{bundle.name} holds no text')

    def test_every_bundle_key_is_translated_in_every_language_from_the_current_english(self):
        problems = []
        for locale in L.LOCALES:
            state = self.corpus.classify(locale)
            for bundle in self.bundles:
                mine = set(L.english(bundle))
                for reason in ('missing', 'stale', 'invalid'):
                    for key in mine.intersection(state[reason]):
                        problems.append(f'{locale} {bundle.name} {reason}: {key[:70]!r}')
        self.assertEqual(problems, [], f'{len(problems)} load-on-demand string(s) are not translated; '
                                       'see python3 tools/translation_todo.py <locale> and translation_apply.py\n'
                         + '\n'.join(problems[:15]))

    def test_a_key_lives_in_exactly_one_catalog(self):
        seen = {}
        for catalog in L.catalogs():
            for key in L.english(catalog):
                self.assertNotIn(key, seen, f'{key!r} is in both {seen.get(key)} and {catalog.name}')
                seen[key] = catalog.name

    def test_no_two_bundles_share_a_key_hash(self):
        owner = {}
        for bundle in self.bundles:
            for key in L.english(bundle):
                previous = owner.setdefault(L.key_hash(key), bundle.name)
                self.assertEqual(previous, bundle.name, f'{key!r} collides with a key of {previous}')

    def test_the_index_is_fresh(self):
        self.assertTrue(L.cmd_index(check=True))

    def test_each_bundle_is_a_load_on_demand_addon_listing_every_language(self):
        for bundle in self.bundles:
            toc = L.toc_path(bundle).read_text(encoding='utf-8')
            self.assertIn('## LoadOnDemand: 1', toc, bundle.module)
            self.assertIn('## Dependencies: RotationMaster', toc, bundle.module)
            listed = [line.strip() for line in toc.splitlines() if line.strip().endswith('.lua')]
            self.assertEqual(listed[0], 'enUS.lua', f'{bundle.module}: English must load first')
            for locale in L.LOCALES:
                self.assertIn(f'{locale}.lua', listed, f'{bundle.module} does not list {locale}.lua')
                self.assertTrue(bundle.path(locale).exists(), f'{bundle.module}/{locale}.lua is missing')

    def test_the_main_toc_loads_the_index_and_the_loader_after_the_locales(self):
        lines = [line.strip() for line in (ROOT / 'RotationMaster.toc').read_text(encoding='utf-8').splitlines()]
        order = [lines.index(name) for name in ('locales.xml', 'Data/text_bundle_index.lua', 'Core/text_bundles.lua')]
        self.assertEqual(order, sorted(order))
        self.assertEqual(order[1] + 1, order[2])

    def test_a_bundle_key_is_not_read_from_the_main_catalog_by_a_stale_copy(self):
        main = set(L.english(L.catalog_named('main')))
        for bundle in self.bundles:
            self.assertEqual(main.intersection(L.english(bundle)), set(), bundle.name)


if __name__ == '__main__':
    unittest.main()
