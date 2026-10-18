"""Real scanner fixtures: missing keys, comments and escaped keys."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CatalogTests(unittest.TestCase):
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


if __name__ == '__main__':
    unittest.main()
