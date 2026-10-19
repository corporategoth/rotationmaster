"""Runner contract: cwd independence and failures must reach hooks/CI."""
from pathlib import Path
import shutil
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / 'tools/check'


class RunnerTests(unittest.TestCase):
    def test_missing_runtime_fails_with_actionable_message(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tools').mkdir()
            (root / 'tests').mkdir()
            shutil.copyfile(RUNNER, root / 'tools/check')
            (root / 'tests/verify.py').write_text('')
            (root / 'tools/catalog_check.py').write_text('')
            (root / 'tools/lint.py').write_text('')
            (root / 'tools/generate_builtin_sources.py').write_text('')
            (root / 'tools/generate_artwork_catalog.py').write_text('')
            (root / 'tests/test_artwork.py').write_text('')
            result = subprocess.run([sys.executable, str(root / 'tools/check')],
                                    env=dict(os.environ, PATH=''), capture_output=True, text=True)
            self.assertEqual(result.returncode, 127)
            self.assertIn('lua5.1', result.stderr)

    def test_static_runner_works_outside_repository(self):
        result = subprocess.run([sys.executable, str(RUNNER), '--static'],
                                cwd='/tmp', capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('TOC/XML entries', result.stdout)

    def test_failing_check_returns_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tools').mkdir()
            (root / 'tests').mkdir()
            shutil.copyfile(RUNNER, root / 'tools/check')
            (root / 'tests/verify.py').write_text('raise SystemExit(7)\n')
            result = subprocess.run([sys.executable, str(root / 'tools/check'), '--static'],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 7, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
