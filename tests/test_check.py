# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Runner contract: cwd independence and failures must reach hooks/CI."""
from pathlib import Path
import contextlib
import io
import shutil
import os
import re
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / 'tools/check'


class RunnerTests(unittest.TestCase):
    def test_checks_do_not_inherit_a_git_hook_repository(self):
        run = runpy.run_path(str(RUNNER), run_name='test_runner')['main']
        inherited = {'GIT_DIR': '/wrong/repository', 'GIT_WORK_TREE': '/wrong/tree',
                     'GIT_INDEX_FILE': '/wrong/index', 'GIT_COMMON_DIR': '/wrong/common', 'GIT_PREFIX': 'wrong/'}
        with mock.patch.dict(os.environ, inherited), mock.patch.object(sys, 'argv', ['check', '--static']), \
             mock.patch.object(subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as called, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(run(), 0)
        self.assertTrue(called.call_args_list)
        for call in called.call_args_list:
            self.assertFalse(set(inherited) & set(call.kwargs['env']))
            self.assertEqual(call.kwargs['env']['PATH'], os.environ['PATH'])

    def test_missing_runtime_fails_with_actionable_message(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tools').mkdir()
            (root / 'tests').mkdir()
            shutil.copyfile(RUNNER, root / 'tools/check')
            # Every Python script the runner starts before it reaches a Lua runtime, as an empty stand-in.
            for script in sorted(set(re.findall(r"'((?:tools|tests)/[\w/]+\.py)'", RUNNER.read_text()))):
                (root / script).parent.mkdir(parents=True, exist_ok=True)
                (root / script).write_text('')
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
