"""Guard RM's service-only versus explicit predictor compatibility load graph."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SERVICES = ['Libs/AceGUI-3.0-Spell-EditBox/SpellLoader.lua', 'Libs/AceGUI-3.0-Item-EditBox/ItemLoader.lua']
PREDICTORS = [
    'Libs/AceGUI-3.0-Spell-EditBox/' + name
    for name in ['EditBox-Core.lua', 'Spells-Editbox.lua', 'Casts-EditBox.lua', 'Auras-EditBox.lua', 'Player-EditBox.lua']
] + ['Libs/AceGUI-3.0-Item-EditBox/' + name for name in ['EditBox-Core.lua', 'Items-Editbox.lua', 'Inventory-EditBox.lua']]
AUGMENTS = ['LibsAugment/' + name for name in ['Spec-EditBox.lua', 'Totem-EditBox.lua', 'Glyph-EditBox.lua']]


def scripts(path):
    result = []
    for node in ET.parse(path).iter():
        reference = node.get('file')
        if reference:
            child = (path.parent / reference.replace('\\', '/')).resolve()
            if child.suffix == '.xml':
                result.extend(scripts(child))
            else:
                result.append(child.relative_to(ROOT).as_posix())
    return result


class ReferenceLoadGraph(unittest.TestCase):
    def test_services_are_direct_and_each_runtime_script_loads_once(self):
        path = ROOT / 'embeds.xml'
        direct = [(node.tag.rsplit('}', 1)[-1], node.get('file', '').replace('\\', '/')) for node in ET.parse(path).getroot()]
        for service in SERVICES:
            self.assertIn(('Script', service), direct)
        loaded = scripts(path)
        for name in SERVICES + PREDICTORS + AUGMENTS:
            self.assertEqual(loaded.count(name), 1, name)
        self.assertLess(loaded.index(SERVICES[1]), loaded.index(PREDICTORS[0]))
        self.assertEqual([name for name in loaded if name in PREDICTORS + AUGMENTS], PREDICTORS + AUGMENTS)
        self.assertLess(loaded.index('Libs/LibCompress/LibCompress.lua'), loaded.index(AUGMENTS[0]))
        toc = (ROOT / 'RotationMaster.toc').read_text().splitlines()
        self.assertLess(toc.index('embeds.xml'), toc.index('Core/reference_catalog.lua'))
        self.assertLess(toc.index('embeds.xml'), toc.index('main.lua'))

    def test_explicit_compatibility_manifests_contain_only_the_original_widgets(self):
        self.assertEqual(scripts(ROOT / 'reference-predictors-compat.xml'), PREDICTORS)
        self.assertEqual(scripts(ROOT / 'reference-predictor-augments-compat.xml'), AUGMENTS)
        self.assertFalse(set(SERVICES) & set(PREDICTORS + AUGMENTS))


if __name__ == '__main__':
    unittest.main()
