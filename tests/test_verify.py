# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""A changed or missing vendored file must fail the production verifier."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class VendorTests(unittest.TestCase):
    def test_vendor_bytes_and_file_set_are_verified(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tests').mkdir()
            lib = root / 'Libs/Example'
            lib.mkdir(parents=True)
            shutil.copyfile(ROOT / 'tests/verify.py', root / 'tests/verify.py')
            (root / 'RotationMaster.toc').write_text('')
            source = b'return 1\n'
            file = lib / 'example.lua'
            file.write_bytes(source)
            (root / 'Libs/UPSTREAM.json').write_text(json.dumps({'libraries': {
                'Example': {'files': {'example.lua': hashlib.sha256(source).hexdigest()}}
            }}))
            def check():
                return subprocess.run([sys.executable, 'tests/verify.py'], cwd=root,
                                      capture_output=True, text=True)
            self.assertEqual(check().returncode, 0)
            file.write_text('return 2\n')
            self.assertNotEqual(check().returncode, 0, 'changed vendor file was accepted')
            file.write_bytes(source)
            (lib / 'obsolete.txt').write_text('old duplicate')
            self.assertNotEqual(check().returncode, 0, 'untracked vendor file was accepted')
            file.unlink()
            self.assertNotEqual(check().returncode, 0, 'missing vendor file was accepted')

    def test_a_lua_file_nothing_loads_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for child in ['tests', 'Libs', 'Core', 'tools']:
                (root / child).mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / 'tests/verify.py', root / 'tests/verify.py')
            (root / 'Libs/UPSTREAM.json').write_text('{"libraries": {}}')
            (root / 'RotationMaster.toc').write_text('Core/loaded.lua\n')
            (root / 'Core/loaded.lua').write_text('return 1\n')
            (root / 'tools/helper.lua').write_text('return 2\n')
            def check():
                return subprocess.run([sys.executable, 'tests/verify.py'], cwd=root, capture_output=True, text=True)
            self.assertEqual(check().returncode, 0, 'a listed file or an unpackaged tool script was refused')
            (root / 'Core/orphan.lua').write_text('return 3\n')
            result = check()
            self.assertNotEqual(result.returncode, 0, 'a Lua file no TOC loads was accepted')
            self.assertIn('Core/orphan.lua', result.stdout)
            (root / 'RotationMaster.toc').write_text('Core/loaded.lua\nCore/orphan.lua\n')
            self.assertEqual(check().returncode, 0, 'listing the file in the TOC did not satisfy the gate')

    def test_missing_native_icon_fails_without_a_lua_or_toc_error(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for child in ['tests', 'Libs', 'UI', 'Assets/Controls']:
                (root / child).mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / 'tests/verify.py', root / 'tests/verify.py')
            (root / 'Libs/UPSTREAM.json').write_text('{"libraries": {}}')
            (root / 'RotationMaster.toc').write_text('UI/control.lua\n')
            (root / 'UI/control.lua').write_text("addon:CreateWorkbenchIconButton(parent, 'minus', 'Zoom out')")
            def check():
                return subprocess.run([sys.executable, 'tests/verify.py'], cwd=root, capture_output=True, text=True)
            result = check()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Missing control texture', result.stdout)
            (root / 'Assets/Controls/minus.tga').write_bytes(b'fixture')
            self.assertEqual(check().returncode, 0)

    def test_packaged_defaults_must_be_in_exactly_one_edition_toc(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tests').mkdir()
            (root / 'Libs').mkdir()
            module = root / 'Modules/RotationMaster_Shaman'
            (module / 'tbc').mkdir(parents=True)
            (module / 'forever').mkdir(parents=True)
            shutil.copyfile(ROOT / 'tests/verify.py', root / 'tests/verify.py')
            (root / 'Libs/UPSTREAM.json').write_text('{"libraries": {}}')
            (root / 'RotationMaster.toc').write_text('')
            (module / 'bind.lua').write_text('return 1')
            (module / 'locales.xml').write_text('<Ui></Ui>')
            (module / 'tbc/pack.lua').write_text('return 1')
            (module / 'forever/pack.lua').write_text('return 1')
            header = '## Interface: 20506\n## Dependencies: RotationMaster\n## LoadOnDemand: 1\n'
            fallback = module / 'RotationMaster_Shaman.toc'
            tbc = module / 'RotationMaster_Shaman_TBC.toc'
            camelot = module / 'RotationMaster_Shaman_Camelot.toc'
            forever = module / 'RotationMaster_Shaman_Forever.toc'
            pkgmeta = root / '.pkgmeta'
            moved = ('package-as: RotationMaster\nmove-folders:\n'
                     '  RotationMaster/Modules/RotationMaster_Shaman: RotationMaster_Shaman\nignore:\n  - tests\n')
            def check():
                return subprocess.run([sys.executable, 'tests/verify.py'], cwd=root,
                                      capture_output=True, text=True)
            def good():
                pkgmeta.write_text(moved)
                fallback.write_text(header)
                tbc.write_text(header + 'bind.lua\nlocales.xml\ntbc/pack.lua\n')
                camelot.write_text(header + 'bind.lua\nlocales.xml\nforever/pack.lua\n')
                forever.write_text(header + 'bind.lua\nlocales.xml\nforever/pack.lua\n')
                (root / 'RotationMaster.toc').write_text('')
            good()
            self.assertEqual(check().returncode, 0, check().stdout)
            tbc.write_text(header + 'bind.lua\n')
            self.assertIn('listed by 0 edition TOCs', check().stdout, 'unlisted pack accepted')
            tbc.write_text(header + 'bind.lua\nlocales.xml\ntbc/pack.lua\ntbc/pack.lua\n')
            self.assertIn('listed by 2 edition TOCs', check().stdout, 'twice-listed pack accepted')
            tbc.write_text(header + 'bind.lua\nlocales.xml\ntbc/pack.lua\nforever/pack.lua\n')
            self.assertIn('outside tbc/', check().stdout, 'another edition\'s pack accepted')
            good()
            forever.write_text(header + 'bind.lua\n')
            self.assertIn('Flavour TOCs of one edition differ', check().stdout, 'diverging Forever TOCs accepted')
            good()
            fallback.write_text(header + 'bind.lua\ntbc/pack.lua\n')
            self.assertIn('Fallback module TOC must load nothing', check().stdout, 'loading fallback accepted')
            good()
            fallback.unlink()
            self.assertIn('lacks its fallback TOC', check().stdout)
            good()
            (root / 'RotationMaster.toc').write_text('Modules/RotationMaster_Shaman/tbc/pack.lua\n')
            self.assertIn('also loaded by RotationMaster.toc', check().stdout)
            good()
            tbc.write_text('## Interface: 20506\n## Dependencies: RotationMaster\nbind.lua\ntbc/pack.lua\n')
            self.assertIn('LoadOnDemand', check().stdout, 'eagerly loaded module accepted')
            good()
            tbc.write_text(header + 'tbc/pack.lua\nbind.lua\n')
            self.assertIn('bind.lua first', check().stdout, 'module without its bootstrap first accepted')
            good()
            (module / 'RotationMaster_Shaman_Bogus.toc').write_text(header)
            self.assertIn('Unknown module TOC flavour', check().stdout)
            (module / 'RotationMaster_Shaman_Bogus.toc').unlink()
            good()
            pkgmeta.write_text('package-as: RotationMaster\nignore:\n  - tests\n')
            self.assertIn('move-folders lacks', check().stdout, 'module left inside RotationMaster accepted')
            pkgmeta.write_text(moved + '  - Modules\n')
            self.assertIn('would omit a runtime file', check().stdout, 'ignored module accepted')
            good()
            (root / 'Defaults/tbc').mkdir(parents=True)
            (root / 'Defaults/tbc/stray.lua').write_text('return 1')
            self.assertIn('outside a load-on-demand module', check().stdout, 'pack outside a module accepted')

    def test_extra_library_and_missing_or_changed_root_notice_fail_independently(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tests').mkdir()
            (root / 'Libs').mkdir()
            shutil.copyfile(ROOT / 'tests/verify.py', root / 'tests/verify.py')
            (root / 'RotationMaster.toc').write_text('')
            notice = root / 'Libs/NOTICE.txt'
            notice.write_text('copyright')
            manifest = {'libraries': {}, 'notices': {
                'NOTICE.txt': hashlib.sha256(b'copyright').hexdigest()}}
            (root / 'Libs/UPSTREAM.json').write_text(json.dumps(manifest))
            def check():
                return subprocess.run([sys.executable, 'tests/verify.py'], cwd=root,
                                      capture_output=True, text=True)
            self.assertEqual(check().returncode, 0)
            notice.unlink()
            self.assertNotEqual(check().returncode, 0, 'missing notice accepted')
            notice.write_text('changed')
            self.assertNotEqual(check().returncode, 0, 'changed notice accepted')
            notice.write_text('copyright')
            (root / 'Libs/Obsolete').mkdir()
            (root / 'Libs/Obsolete/old.lua').write_text('return 1')
            self.assertNotEqual(check().returncode, 0, 'obsolete library accepted')


if __name__ == '__main__':
    unittest.main()
