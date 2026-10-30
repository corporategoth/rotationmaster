# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))

def load(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'tools'/f'{name}.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

class LintTests(unittest.TestCase):
    def test_fingerprints_track_source_and_warning_counts_without_line_number_churn(self):
        lint=load('lint')
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);path=root/'example.lua';path.write_text('local x = UnitHeath("player")\n')
            report='example.lua:1:11: warning[undefined-global] undefined global \'UnitHeath\'\n'
            first=lint.parse_diagnostics(report,root)
            path.write_text('\nlocal x = UnitHeath("player")\n')
            shifted=lint.parse_diagnostics(report.replace(':1:11:',':2:11:'),root)
            self.assertEqual(first,shifted)
            baseline=lint.make_baseline(first)
            self.assertEqual(lint.new_diagnostics(shifted,baseline),[])
            self.assertEqual(len(lint.new_diagnostics(shifted+shifted,baseline)),1)
            path.write_text('local x = AnotherTypo("player")\n')
            fresh=lint.parse_diagnostics(report.replace('UnitHeath','AnotherTypo'),root)
            self.assertEqual(len(lint.new_diagnostics(fresh,baseline)),1)

    def test_parser_refuses_paths_outside_repo_and_invalid_source_locations(self):
        lint=load('lint')
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/'example.lua').write_text('local x=1\n')
            for path,line in [('../private.lua',1),('example.lua',200)]:
                with self.assertRaises(ValueError):
                    lint.parse_diagnostics(f'{path}:{line}:1: warning[undefined-global] typo\n',root)

    def test_tool_failures_cannot_pass_as_an_empty_warning_set(self):
        lint=load('lint')
        for code,output in [(2,'panic: failed'),(1,'failed to load config')]:
            with self.assertRaises(ValueError): lint.validate_result(code,output,[])
        lint.validate_result(0,'Checked 1 files',[])

    def test_logged_configuration_failures_cannot_pass_even_on_exit_zero(self):
        lint=load('lint')
        for output in [
            '[WARN  wowlua_analysis::config] failed to parse .wowluarc.json: expected value',
            '[ERROR wowlua_ls] cannot read configuration',
            'Warning: configuration ignored',
        ]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                lint.parse_diagnostics(output,ROOT)

    def test_verified_setup_never_overwrites_a_different_existing_file(self):
        setup=load('setup_lint')
        payload=b'trusted test tool';digest=hashlib.sha256(payload).hexdigest()
        with tempfile.TemporaryDirectory() as folder:
            target=Path(folder)/'tool'
            self.assertEqual(setup.install_verified(target,payload,digest),target)
            self.assertEqual(target.read_bytes(),payload)
            with self.assertRaises(ValueError): setup.install_verified(target,b'replacement',hashlib.sha256(b'replacement').hexdigest())
            self.assertEqual(target.read_bytes(),payload)
            other=Path(folder)/'bad'
            with self.assertRaises(ValueError): setup.install_verified(other,b'bad bytes',digest)
            self.assertFalse(other.exists())

if __name__=='__main__':unittest.main()
