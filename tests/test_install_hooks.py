# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Install only a local static gate while preserving a checkout's hook chain."""
from pathlib import Path
import importlib.util
import errno
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

INSTALLER = Path(__file__).resolve().parents[1] / 'tools/install_hooks.py'


class HookTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        subprocess.run(['git', 'init', '-q', '--template=', str(self.root)], check=True)
        (self.root / 'tools').mkdir()
        self.hooks = self.root / '.git/hooks'
        self.hooks.mkdir()
        self.hook = self.hooks / 'pre-commit'
        self.check = self.root / 'tools/check'
        self.check.write_text("from pathlib import Path\nimport sys\nassert sys.argv[1:] == ['--static']\nPath('gate-ran').write_text('yes')\n")

    def install(self, *args):
        return subprocess.run([sys.executable, str(INSTALLER), '--repo', str(self.root), *args],
                              capture_output=True, text=True)

    def run_hook(self, *args):
        return subprocess.run([str(self.hook), *args], cwd=self.root, capture_output=True, text=True)

    def test_dry_run_does_not_write_and_check_reports_absence(self):
        before = set(self.hooks.iterdir())
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(set(self.hooks.iterdir()), before)
        self.assertFalse(self.hook.exists())
        self.assertEqual(self.install('--check').returncode, 1)

    def test_preserves_original_body_path_args_mode_and_gate_order(self):
        original = b'#!/bin/sh\n[ -f gate-ran ] || exit 41\nprintf "%s:%s" "$0" "$1" > original-ran\n'
        self.hook.write_bytes(original)
        self.hook.chmod(0o750)
        result = self.install('--install')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.hooks / '.rotationmaster-pre-commit.original').read_bytes(), original)
        self.assertEqual(self.hook.stat().st_mode & 0o777, 0o750)
        self.assertEqual(self.run_hook('argument').returncode, 0)
        self.assertEqual((self.root / 'original-ran').read_text(), str(self.hook) + ':argument')
        self.assertEqual(self.install('--check').returncode, 0)
        before = self.hook.read_bytes()
        self.assertEqual(self.install('--install').returncode, 0)
        self.assertEqual(self.hook.read_bytes(), before)

    def test_static_failure_and_original_failure_both_block(self):
        self.hook.write_text('#!/bin/sh\nexit 17\n')
        self.hook.chmod(0o755)
        self.assertEqual(self.install('--install').returncode, 0)
        self.assertEqual(self.run_hook().returncode, 17)
        self.check.write_text('raise SystemExit(23)\n')
        self.assertEqual(self.run_hook().returncode, 23)

    def test_absent_and_nonexecutable_originals_only_run_the_gate(self):
        self.hook.write_text('#!/bin/sh\nexit 17\n')
        self.hook.chmod(0o644)
        self.assertEqual(self.install('--install').returncode, 0)
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertEqual(self.hook.stat().st_mode & 0o777, 0o744)

    def test_removed_check_on_an_older_branch_preserves_personal_hook(self):
        self.hook.write_text('#!/bin/sh\nexit 17\n')
        self.hook.chmod(0o755)
        self.assertEqual(self.install('--install').returncode, 0)
        self.check.rename(self.root / 'tools/check-away')
        self.assertEqual(self.run_hook().returncode, 17)

    def test_hooks_path_does_not_redirect_installation_to_system_or_global_hooks(self):
        external = self.root / 'external-hooks'
        external.mkdir()
        sentinel = external / 'pre-commit'
        sentinel.write_text('unchanged')
        subprocess.run(['git', '-C', str(self.root), 'config', 'core.hooksPath', str(external)], check=True)
        self.assertEqual(self.install('--install').returncode, 0)
        self.assertEqual(sentinel.read_text(), 'unchanged')
        self.assertTrue(self.hook.is_file())
        self.assertEqual(self.run_hook().returncode, 0)

    def test_symlink_and_non_shell_hooks_are_refused_without_mutating_them(self):
        target = self.root / 'other-hook'
        target.write_text('#!/bin/sh\nexit 17\n')
        self.hook.symlink_to(target)
        self.assertNotEqual(self.install('--install').returncode, 0)
        self.assertTrue(self.hook.is_symlink())
        self.assertEqual(target.read_text(), '#!/bin/sh\nexit 17\n')
        self.hook.rename(self.hooks / 'saved-link')
        self.hook.write_text('#!/usr/bin/python3\nraise SystemExit(17)\n')
        self.hook.chmod(0o755)
        before = self.hook.read_bytes()
        self.assertNotEqual(self.install('--install').returncode, 0)
        self.assertEqual(self.hook.read_bytes(), before)

    def test_modified_installed_hook_or_backup_is_not_overwritten(self):
        self.hook.write_text('#!/bin/sh\nexit 0\n')
        self.hook.chmod(0o755)
        self.assertEqual(self.install('--install').returncode, 0)
        self.hook.write_bytes(self.hook.read_bytes() + b'# another editor\n')
        before = self.hook.read_bytes()
        self.assertNotEqual(self.install('--install').returncode, 0)
        self.assertEqual(self.hook.read_bytes(), before)
        self.assertNotEqual(self.install('--check').returncode, 0)

    def test_missing_or_modified_original_backup_blocks_reinstallation(self):
        self.hook.write_text('#!/bin/sh\nexit 0\n')
        self.hook.chmod(0o755)
        self.assertEqual(self.install('--install').returncode, 0)
        before = self.hook.read_bytes()
        backup = self.hooks / '.rotationmaster-pre-commit.original'
        backup.write_text('# another editor\n')
        self.assertNotEqual(self.install('--install').returncode, 0)
        self.assertNotEqual(self.install('--check').returncode, 0)
        self.assertEqual(self.hook.read_bytes(), before)
        backup.rename(self.hooks / 'saved-original')
        self.assertNotEqual(self.install('--install').returncode, 0)
        self.assertEqual(self.hook.read_bytes(), before)

    def test_detected_concurrent_hook_change_is_preserved_instead_of_installed_over(self):
        original = b'#!/bin/sh\nexit 0\n'
        changed = b'#!/bin/sh\nexit 18\n'
        self.hook.write_bytes(original)
        self.hook.chmod(0o755)
        spec = importlib.util.spec_from_file_location('rm_hook_installer', INSTALLER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        write = module.exclusive_write

        def external_change(path, data, mode):
            write(path, data, mode)
            if path.name.endswith('.original'):
                self.hook.write_bytes(changed)

        with mock.patch.object(module, 'exclusive_write', external_change):
            with self.assertRaisesRegex(ValueError, 'Hook changed'):
                module.run(self.root, install=True)
        self.assertEqual(self.hook.read_bytes(), changed)
        self.assertEqual((self.hooks / '.rotationmaster-pre-commit.original').read_bytes(), original)

    def test_last_moment_hook_edit_is_preserved_at_publication_boundary(self):
        original = b'#!/bin/sh\nexit 0\n'
        changed = b'#!/bin/sh\nexit 19 # concurrent editor\n'
        self.hook.write_bytes(original)
        self.hook.chmod(0o755)
        spec = importlib.util.spec_from_file_location('rm_hook_installer_boundary', INSTALLER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        publish = module.publish_candidate

        def external_change(candidate, hook, current):
            hook.write_bytes(changed)
            return publish(candidate, hook, current)

        with mock.patch.object(module, 'publish_candidate', external_change):
            try:
                module.run(self.root, install=True)
            except ValueError:
                pass
        preserved = [path.read_bytes() for path in self.hooks.iterdir() if path.is_file()]
        self.assertIn(changed, preserved, 'last-moment edit disappeared from every hook/backup')
        self.assertEqual(self.hook.read_bytes(), changed)

    def test_unavailable_atomic_exchange_refuses_to_replace_the_original(self):
        original = b'#!/bin/sh\nexit 0\n'
        self.hook.write_bytes(original)
        self.hook.chmod(0o755)
        spec = importlib.util.spec_from_file_location('rm_hook_no_exchange', INSTALLER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with mock.patch.object(module, 'atomic_exchange', side_effect=OSError(errno.ENOTSUP, 'unsupported')):
            with self.assertRaises(OSError):
                module.run(self.root, install=True)
        self.assertEqual(self.hook.read_bytes(), original)
        self.assertEqual((self.hooks / '.rotationmaster-pre-commit.original').read_bytes(), original)

    def test_new_hook_appearing_at_publication_is_never_overwritten(self):
        changed = b'#!/bin/sh\nexit 19\n'
        spec = importlib.util.spec_from_file_location('rm_hook_new_entry', INSTALLER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        publish = module.publish_candidate

        def external_change(candidate, hook, current):
            hook.write_bytes(changed)
            return publish(candidate, hook, current)

        with mock.patch.object(module, 'publish_candidate', external_change):
            with self.assertRaises(FileExistsError):
                module.run(self.root, install=True)
        self.assertEqual(self.hook.read_bytes(), changed)

    def test_symlink_hooks_directory_is_refused(self):
        self.hooks.rename(self.root / 'saved-hooks')
        self.hooks.symlink_to(self.root / 'saved-hooks', target_is_directory=True)
        self.assertNotEqual(self.install('--install').returncode, 0)
        self.assertFalse((self.root / 'saved-hooks/pre-commit').exists())


if __name__ == '__main__':
    unittest.main()
