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

    def test_packaged_defaults_must_be_in_the_load_graph(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tests').mkdir()
            (root / 'Libs').mkdir()
            (root / 'Defaults/tbc').mkdir(parents=True)
            shutil.copyfile(ROOT / 'tests/verify.py', root / 'tests/verify.py')
            (root / 'Libs/UPSTREAM.json').write_text('{"libraries": {}}')
            (root / 'Defaults/tbc/pack.lua').write_text('return 1')
            toc = root / 'RotationMaster.toc'
            toc.write_text('')
            def check():
                return subprocess.run([sys.executable, 'tests/verify.py'], cwd=root,
                                      capture_output=True, text=True)
            self.assertNotEqual(check().returncode, 0, 'unloaded default pack accepted')
            toc.write_text('Defaults/tbc/pack.lua\n')
            self.assertEqual(check().returncode, 0)

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
