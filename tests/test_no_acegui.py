# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Distribution and manifest acceptance for the native-only UI decision."""
from pathlib import Path
import json
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RETIRED = ('AceGUI-3.0', 'AceConfig-3.0', 'AceDBOptions-3.0', 'LibAboutPanel-2.0',
           'AceGUI-3.0-ActionSlotWidgets', 'AceGUI-3.0-SharedMediaWidgets',
           'AceGUI-3.0-Spell-EditBox', 'AceGUI-3.0-Item-EditBox')


def load_graph():
    found = []
    def walk(path):
        found.append(path.relative_to(ROOT).as_posix())
        if path.suffix == '.xml':
            for node in ET.parse(path).iter():
                ref = node.get('file')
                if ref:
                    walk(path.parent / ref.replace('\\', '/'))
    for line in (ROOT / 'RotationMaster.toc').read_text().splitlines():
        if line.strip() and not line.startswith('#'):
            walk(ROOT / line.strip())
    return found


class NativeOnlyDistribution(unittest.TestCase):
    def test_no_gui_payload_or_legacy_renderer_ships(self):
        manifest = json.loads((ROOT / 'Libs/UPSTREAM.json').read_text())['libraries']
        for name in RETIRED:
            self.assertFalse(name in manifest, name)
            self.assertFalse(any(p.is_file() for p in (ROOT / 'Libs' / name).rglob('*')), name)
        self.assertFalse(any((ROOT / 'Options').glob('*.lua')))
        self.assertFalse(any((ROOT / 'Widgets').glob('*.lua')))

    def test_native_manifest_retains_services_without_gui_dependencies(self):
        loaded = load_graph()
        for path in loaded:
            self.assertFalse(any(path.startswith('Libs/' + name + '/') for name in RETIRED), path)
            self.assertFalse(path.startswith(('Options/', 'Widgets/')), path)
            self.assertNotIn('_compat.lua', path)
        for name in ('AceAddon-3.0', 'AceConsole-3.0', 'AceDB-3.0', 'AceEvent-3.0',
                     'AceTimer-3.0', 'AceLocale-3.0', 'AceSerializer-3.0', 'AceComm-3.0', 'AceBucket-3.0'):
            self.assertIn('Libs/' + name + '/' + name + '.lua', loaded)
        self.assertIn('Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua', loaded)
        self.assertNotIn('AceGUI', (ROOT / 'RotationMaster.toc').read_text())

    def test_native_reference_events_and_picker_do_not_import_old_loaders(self):
        for name in ('main.lua', 'Core/reference_catalog.lua'):
            self.assertNotIn('AceGUI-3.0-', (ROOT / name).read_text(), name)


if __name__ == '__main__':
    unittest.main()
