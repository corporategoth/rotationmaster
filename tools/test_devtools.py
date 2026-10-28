#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Tests for the development tools: package builder and checker, release notes, translation tools,
repository guards, fast-test selection. Standard library only; seconds.

  python3 tools/test_devtools.py
"""
import http.server
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))

import check_all  # noqa: E402
import copyright as C  # noqa: E402
import fast_tests  # noqa: E402
import gitea_release  # noqa: E402
import lint_workflows  # noqa: E402
import release_plan  # noqa: E402
import package_release as P  # noqa: E402
import precommit_hygiene as H  # noqa: E402
import release_notes as R  # noqa: E402
import translation_apply  # noqa: E402
import translation_lib as T  # noqa: E402

INFO = {'version': '2.0.0-beta.1', 'revision': '12', 'hash': 'a' * 40, 'abbreviated-hash': 'aaaaaaa', 'author': 'A',
        'timestamp': '1700000000', 'date-iso': '2023-11-14T22:13:20Z', 'date-integer': '20231114221320'}


def temp_dir(test):
    handle = tempfile.TemporaryDirectory(prefix='rm-devtools-')
    test.addCleanup(handle.cleanup)
    return Path(handle.name)


def git(root, *args):
    identity = {'GIT_AUTHOR_NAME': 'T', 'GIT_AUTHOR_EMAIL': 't@example.invalid',
                'GIT_COMMITTER_NAME': 'T', 'GIT_COMMITTER_EMAIL': 't@example.invalid'}
    subprocess.run(['git', '-C', str(root), *args], check=True, capture_output=True, env={**os.environ, **identity})


def minimal_layout(version='2.0.0-beta.1'):
    """A package that passes every check, small enough to edit in a test."""
    interfaces = ', '.join(str(n) for n in P.SUPPORTED_CLIENTS)
    layout = {
        'RotationMaster/RotationMaster.toc': f'## Interface: {interfaces}\n## Version: {version}\nmain.lua\nembeds.xml\nlocales.xml\n',
        'RotationMaster/main.lua': 'return 1\n',
        'RotationMaster/embeds.xml': '<Ui><Script file="Libs\\a.lua"/></Ui>\n',
        'RotationMaster/Libs/a.lua': 'return 1\n',
        'RotationMaster/locales.xml': '<Ui><Script file="Locales\\enUS.lua"/></Ui>\n',
        'RotationMaster/Locales/enUS.lua': 'return 1\n',
        'RotationMaster/LICENSE': 'MIT\n',
        'RotationMaster/Fonts/OFL.txt': 'OFL\n',
        'RotationMaster/THIRD_PARTY_NOTICES.md': f'{P.NOTICE}\n',
        'RotationMaster_Mage/RotationMaster_Mage.toc': f'## Interface: 11509\n## Version: {version}\nbind.lua\n',
        'RotationMaster_Mage/bind.lua': 'return 1\n',
    }
    return {name: text.encode() for name, text in layout.items()}


META = {'package-as': 'RotationMaster', 'move-folders': {'RotationMaster/Modules/RotationMaster_Mage': 'RotationMaster_Mage'},
        'ignore': [], 'changelog': None}


class Classify(unittest.TestCase):
    def test_tag_names_decide_the_release_type(self):
        for tag, expected in [('2.0.0-beta.1', 'beta'), ('2.0.0beta3', 'beta'), ('2.0.0-ALPHA.2', 'alpha'), ('2.0.0', 'release'),
                              ('1.4.3e', 'release'), ('2.0.0-rc.1', 'release'), ('2.0.0-alpha-beta', 'alpha'), ('', 'alpha'), (None, 'alpha')]:
            self.assertEqual(P.classify(tag), expected, tag)
            self.assertEqual(R.release_type(tag) if tag else 'release', expected if tag else 'release')

    def test_release_notes_and_packager_agree_on_the_type(self):
        for tag in ('2.0.0-beta.1', '2.0.0-alpha', '2.0.0', 'v3.0.0-BETA'):
            self.assertEqual(P.classify(tag), R.release_type(tag))


class Pkgmeta(unittest.TestCase):
    def test_the_repository_pkgmeta_parses(self):
        meta = P.parse_pkgmeta(ROOT / '.pkgmeta')
        self.assertEqual(meta['package-as'], 'RotationMaster')
        self.assertEqual(meta['changelog'], 'CHANGELOG.md')
        # Every add-on folder under Modules/ ships beside the main add-on: the Built In class modules and the
        # load-on-demand text bundles.
        folders = sorted(d.name for d in (ROOT / 'Modules').iterdir() if d.is_dir())
        self.assertEqual(sorted(meta['move-folders'].values()), folders)
        self.assertNotIn('RotationMaster_WowSims', meta['move-folders'].values())
        for item in ('tests', 'tools', 'docs', '.claude', '.gitea', 'README.md', 'Data/talent_trees.json'):
            self.assertIn(item, meta['ignore'])

    def test_ignore_entries_become_globs_the_way_release_sh_does(self):
        root = temp_dir(self)
        (root / 'dir').mkdir()
        (root / 'file.txt').write_text('x')
        self.assertEqual(P.ignore_globs(root, ['dir', 'file.txt', 'missing', 'dir/*']),
                         ['dir/*', 'file.txt', 'missing', 'missing/*', 'dir/*'])


class Text(unittest.TestCase):
    def test_keywords_blocks_and_endings(self):
        text = '--@do-not-package@\nsecret()\n--@end-do-not-package@\nv=@project-version@ r=@project-revision@\r\nend\n'
        out = P.process_text('x.lua', text.encode(), INFO, False).decode()
        self.assertEqual(out, 'v=2.0.0-beta.1 r=12\nend\n')

    def test_project_tocs_lose_interface_dash_lines_and_other_tocs_keep_them(self):
        toc = '## Interface: 11509\n## Interface-Classic: 11509\n## Version: @project-version@\nmain.lua\n'
        project = P.process_text('A.toc', toc.encode(), INFO, True).decode()
        other = P.process_text('B.toc', toc.encode(), INFO, False).decode()
        self.assertNotIn('Interface-Classic', project)
        self.assertIn('Interface-Classic', other)
        self.assertIn('## Version: 2.0.0-beta.1', project)

    def test_a_keyword_this_tool_does_not_reproduce_is_refused(self):
        with self.assertRaises(P.PackageError):
            P.process_text('x.lua', b'--@alpha@\nx\n--@end-alpha@\n', INFO, False)


class Check(unittest.TestCase):
    def problems(self, layout, **kwargs):
        return P.check_layout(layout, META, '2.0.0-beta.1', ROOT, **kwargs)

    def test_a_clean_package_passes(self):
        self.assertEqual(self.problems(minimal_layout()), [])

    def test_development_paths_and_files_fail(self):
        for path in ('RotationMaster/tests/a.lua', 'RotationMaster/tools/a.lua', 'RotationMaster/docs/a.md', 'RotationMaster/.claude/CLAUDE.md',
                     'RotationMaster/.gitea/w.yml', 'RotationMaster/README.md', 'RotationMaster/TODO', 'RotationMaster/Libs/x/a.py',
                     'RotationMaster/Assets/a.svg', 'RotationMaster/__pycache__/a.pyc',
                     'RotationMaster/Web/index.html', 'RotationMaster/outputs/a.txt'):
            layout = minimal_layout()
            layout[path] = b'x'
            self.assertTrue(self.problems(layout), path)

    def test_every_file_type_that_is_not_for_the_game_fails_the_package(self):
        # Spelled out, not read from P.FORBIDDEN_SUFFIXES, so dropping a suffix from the checker fails here.
        for suffix in ('.py', '.sh', '.svg', '.psd', '.xcf', '.png', '.jpg', '.jpeg', '.zip', '.gz', '.bak', '.orig', '.rej', '.swp',
                       '.log', '.pyc', '.pem', '.key', '.env'):
            for name in (f'RotationMaster/Fonts/sample{suffix}', f'RotationMaster/Data/SAMPLE{suffix.upper()}'):
                layout = minimal_layout()
                layout[name] = b'x'
                self.assertTrue(any('file type that is not for the game' in problem for problem in self.problems(layout)), name)

    def test_a_vendored_library_may_keep_its_own_docs_folder(self):
        layout = minimal_layout()
        layout['RotationMaster/Libs/AceX/docs/LICENSE'] = b'x'
        self.assertEqual(self.problems(layout), [])

    def test_only_what_the_game_loads_and_license_or_notice_files_are_allowed(self):
        for name in ('Assets/Conditions/provenance.json', 'Assets/Conditions/README.md', 'Libs/UPSTREAM.json', 'Libs/X/README.textile',
                     'Locales/bundles.json', 'Fonts/readme.txt', 'Data/talent_trees.json', 'Sounds/hit.ogg', 'Libs/X/NOTES', 'Libs/X/LICENSE.html'):
            layout = minimal_layout()
            layout['RotationMaster/' + name] = b'x'
            self.assertEqual([p for p in self.problems(layout) if 'neither a file the game loads' in p],
                             [f'neither a file the game loads nor a license or notice: RotationMaster/{name}'], name)

    def test_license_notice_and_loadable_files_are_allowed(self):
        layout = minimal_layout()
        layout['RotationMaster/main.lua'] = b'a("Fonts/F"); b("Textures/t"); c("plus")\n'
        for name in ('Libs/Ace3-LICENSE.txt', 'Libs/X/LICENSE', 'Libs/X/COPYING', 'Libs/X/license.txt', 'Fonts/F.ttf', 'Textures/t.blp',
                     'Assets/Controls/plus.tga'):
            layout['RotationMaster/' + name] = b'x'
        self.assertEqual(self.problems(layout), [])

    def test_code_no_toc_loads_and_textures_no_code_names_fail(self):
        layout = minimal_layout()
        layout['RotationMaster/Libs/dead.lua'] = b'return 1\n'
        layout['RotationMaster/Textures/unused.tga'] = b'x'
        layout['RotationMaster_Mage/orphan.xml'] = b'<Ui/>\n'
        problems = self.problems(layout)
        self.assertIn('RotationMaster/Libs/dead.lua: no TOC or XML loads this file', problems)
        self.assertIn('RotationMaster_Mage/orphan.xml: no TOC or XML loads this file', problems)
        self.assertIn('RotationMaster/Textures/unused.tga: no loaded code names this texture or font', problems)
        self.assertEqual(len(problems), 3)

    def test_missing_required_files_and_modules_fail(self):
        for path in ('RotationMaster/LICENSE', 'RotationMaster/Fonts/OFL.txt', 'RotationMaster/THIRD_PARTY_NOTICES.md',
                     'RotationMaster_Mage/RotationMaster_Mage.toc', 'RotationMaster/embeds.xml'):
            layout = minimal_layout()
            del layout[path]
            self.assertTrue(self.problems(layout), path)

    def test_the_third_party_notice_must_carry_the_wowsims_mit_notice(self):
        layout = minimal_layout()
        layout['RotationMaster/THIRD_PARTY_NOTICES.md'] = b'Notices.\n'
        self.assertTrue(any('WowSims MIT notice' in problem for problem in self.problems(layout)))

    def test_toc_rules(self):
        wrong_clients = minimal_layout()
        wrong_clients['RotationMaster/RotationMaster.toc'] = b'## Interface: 11509\n## Version: 2.0.0-beta.1\nmain.lua\nembeds.xml\nlocales.xml\n'
        self.assertTrue(any('supported clients' in p for p in self.problems(wrong_clients)))
        old_version = minimal_layout(version='1.0')
        self.assertTrue(any('## Version' in p for p in self.problems(old_version)))
        missing_file = minimal_layout()
        missing_file['RotationMaster/RotationMaster.toc'] += b'gone.lua\n'
        self.assertTrue(any('gone.lua' in p for p in self.problems(missing_file)))
        bad_module_client = minimal_layout()
        bad_module_client['RotationMaster_Mage/RotationMaster_Mage.toc'] = b'## Interface: 99999\n## Version: 2.0.0-beta.1\nbind.lua\n'
        self.assertTrue(any('unsupported client' in p for p in self.problems(bad_module_client)))
        unreplaced = minimal_layout()
        unreplaced['RotationMaster/main.lua'] = b'v = "@project-version@"\n'
        self.assertTrue(any('@project' in p for p in self.problems(unreplaced)))

    def test_xml_includes_must_exist_and_comments_are_ignored(self):
        layout = minimal_layout()
        layout['RotationMaster/embeds.xml'] = b'<Ui><!-- <Script file="gone.lua"/> --><Script file="Libs\\a.lua"/></Ui>\n'
        self.assertEqual(self.problems(layout), [])
        layout['RotationMaster/embeds.xml'] = b'<Ui><Script file="Libs\\missing.lua"/></Ui>\n'
        self.assertTrue(any('missing.lua' in p for p in self.problems(layout)))

    def test_case_collisions_size_and_unexpected_top_level_fail(self):
        layout = minimal_layout()
        layout['RotationMaster/main.LUA'] = b'x'
        layout['RotationMaster/MAIN.lua'] = b'x'
        layout['RotationMaster/Main.lua'] = b'x'
        self.assertTrue(any('only by case' in p for p in self.problems(layout)))
        big = minimal_layout()
        big['RotationMaster/Libs/big.lua'] = b'x' * (5 * 1024 * 1024)
        self.assertTrue(any('big.lua' in p for p in self.problems(big)))
        stray = minimal_layout()
        stray['Other/a.lua'] = b'x'
        self.assertTrue(any('Other' in p for p in self.problems(stray)))
        self.assertTrue(any('MB' in p for p in self.problems(minimal_layout(), zip_bytes=80 * 1024 * 1024)))

    def test_carriage_returns_in_text_fail(self):
        layout = minimal_layout()
        layout['RotationMaster/main.lua'] = b'return 1\r\n'
        self.assertTrue(any('CR line endings' in p for p in self.problems(layout)))

    def test_the_repository_packages_cleanly(self):
        meta = P.parse_pkgmeta(ROOT / '.pkgmeta')
        info = P.project_info(ROOT, tag='2.0.0-beta.1')
        layout = P.build_files(ROOT, meta, info, changelog=None)
        self.assertEqual(P.check_layout(layout, meta, '2.0.0-beta.1', ROOT), [])
        self.assertEqual(info['type'], 'beta')
        self.assertNotIn('RotationMaster_WowSims/RotationMaster_WowSims.toc', layout)
        self.assertNotIn('RotationMaster/tests', ' '.join(layout))

    def test_zip_round_trip_is_deterministic(self):
        out = temp_dir(self)
        layout = minimal_layout()
        first = P.write_zip(layout, out / 'a.zip', INFO)
        second = P.write_zip(layout, out / 'b.zip', INFO)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        self.assertEqual(P.read_zip(first), layout)


class Lean(unittest.TestCase):
    """The package built from this repository holds what the game loads and license or notice files, and each ignore
    rule that keeps the rest out is needed."""

    @classmethod
    def setUpClass(cls):
        cls.meta = P.parse_pkgmeta(ROOT / '.pkgmeta')
        cls.info = P.project_info(ROOT, tag='2.0.0-beta.1')
        cls.layout, cls.problems = cls.package(cls.meta['ignore'])

    @classmethod
    def package(cls, ignore):
        meta = dict(cls.meta, ignore=ignore)
        layout = P.build_files(ROOT, meta, cls.info)
        return layout, P.check_layout(layout, meta, '2.0.0-beta.1', ROOT)

    def test_every_license_and_notice_file_in_git_ships(self):
        self.assertEqual(self.problems, [])
        notices = [name for name in P.tracked_files(ROOT) if P.NOTICE_FILE.fullmatch(name.rsplit('/', 1)[-1])
                   and name.split('/')[0] not in ('tests', 'tools', 'docs', 'Modules') and not name.startswith('.')]
        self.assertIn('LICENSE', notices)
        self.assertIn('Libs/Ace3-LICENSE.txt', notices)
        self.assertEqual([name for name in notices if f'RotationMaster/{name}' not in self.layout], [])

    def test_dropping_a_rule_from_the_ignore_list_fails_the_check(self):
        # Rules that keep a kind of file out, each with a file only it keeps out.
        rules = {'Assets/*.json': 'Assets/Conditions/v2/provenance.json', 'Assets/*.md': 'Assets/Branding/README.md',
                 'Libs/*.json': 'Libs/UPSTREAM.json', 'Libs/*/README.*': 'Libs/LibDataBroker-1.1/README.textile',
                 'Locales/*.json': 'Locales/bundles.json'}
        for rule in rules:
            self.assertIn(rule, self.meta['ignore'])
        _, problems = self.package([item for item in self.meta['ignore'] if item not in rules])
        for rule, name in rules.items():
            self.assertIn(f'neither a file the game loads nor a license or notice: RotationMaster/{name}', problems, rule)
        # The derived entries: companion textures, and code no TOC or XML loads.
        derived = [item for item in self.meta['ignore'] if item.endswith(('-64.tga', '-128.tga', '.lua')) and '*' not in item]
        self.assertTrue(any(item.endswith('-64.tga') for item in derived) and any(item.endswith('.lua') for item in derived))
        _, problems = self.package([item for item in self.meta['ignore'] if item not in derived])
        self.assertEqual(len(problems), len(derived), problems[:3])
        self.assertTrue(all('no loaded code names' in p or 'no TOC or XML loads' in p for p in problems))

    def test_the_release_notes_go_to_the_sites_not_into_the_package(self):
        notes = temp_dir(self) / 'CHANGELOG.md'
        notes.write_text('# Notes\n')
        self.assertIn('CHANGELOG.md', self.meta['ignore'])
        self.assertNotIn('RotationMaster/CHANGELOG.md', P.build_files(ROOT, self.meta, self.info, changelog=notes))
        kept = dict(self.meta, ignore=[item for item in self.meta['ignore'] if item != 'CHANGELOG.md'])
        self.assertIn('RotationMaster/CHANGELOG.md', P.build_files(ROOT, kept, self.info, changelog=notes))

    def test_a_stray_file_in_the_package_fails_the_check(self):
        layout = dict(self.layout, **{'RotationMaster/Assets/Stray/notes.json': b'{}'})
        problems = P.check_layout(layout, self.meta, '2.0.0-beta.1', ROOT)
        self.assertEqual(problems, ['neither a file the game loads nor a license or notice: RotationMaster/Assets/Stray/notes.json'])


class LoadGraph(unittest.TestCase):
    """What the game loads and names, read from TOCs, XML includes and strings in code."""

    def files(self, **extra):
        files = {'A.toc': '## Interface: 11509\nmain.lua\nembeds.xml\n', 'main.lua': 'return 1\n',
                 'embeds.xml': '<Ui><!-- <Script file="old.lua"/> --><Script file = "Libs\\a.lua"/><Include file="Libs\\b.xml"/></Ui>\n',
                 'Libs/a.lua': 'return 1\n', 'Libs/b.xml': '<Ui><Script file="b.lua"/></Ui>\n', 'Libs/b.lua': 'return 1\n',
                 'old.lua': 'return 1\n', 'Libs/dead.lua': 'return 1\n', 'Bindings.xml': '<Bindings/>\n', 'Sub/Bindings.xml': '<Bindings/>\n'}
        files.update(extra)
        return files

    def test_the_graph_follows_tocs_through_xml_and_skips_comments_and_orphans(self):
        files = self.files()
        loaded = P.load_graph(files, files.__getitem__)
        self.assertEqual(sorted(loaded), ['A.toc', 'Bindings.xml', 'Libs/a.lua', 'Libs/b.lua', 'Libs/b.xml', 'embeds.xml', 'main.lua'])
        self.assertEqual(P.unused_files(files, files.__getitem__)[0], ['Libs/dead.lua', 'Sub/Bindings.xml', 'old.lua'])

    def test_a_texture_is_named_by_its_path_or_by_a_quoted_name_in_the_named_folders_only(self):
        files = self.files(**{
            'main.lua': 'local a = "Interface\\\\AddOns\\\\" .. n .. "\\\\Assets\\\\Cond\\\\v2\\\\used"\n'
                        'local b = ControlTexture("plus"); local grip = 1\n',
            'Assets/Cond/v2/used.tga': '', 'Assets/Cond/v2/used-64.tga': '', 'Assets/Cond/v2/plus.tga': '',
            'Assets/Controls/plus.tga': '', 'Assets/Controls/grip.tga': '', 'Fonts/F.ttf': '', 'dead.lua': '"Fonts/F"'})
        self.assertEqual(P.unused_files(files, files.__getitem__)[1],
                         ['Assets/Cond/v2/plus.tga', 'Assets/Cond/v2/used-64.tga', 'Assets/Controls/grip.tga', 'Fonts/F.ttf'])


class Notes(unittest.TestCase):
    def repository(self):
        root = temp_dir(self)
        subprocess.run(['git', 'init', '-q', '-b', 'main', str(root)], check=True)
        return root

    def commit(self, root, name, subject):
        (root / name).write_text(subject)
        git(root, 'add', name)
        git(root, 'commit', '-q', '-m', subject)

    def test_subjects_are_cleaned_grouped_and_deduplicated(self):
        cases = {
            'Merge claude/talent-dropdown: talent pickers lay out the icon left': ('change', 'Talent pickers lay out the icon left'),
            'feat(editor): add undo for conditions': ('feat', 'Add undo for conditions'),
            'fix: stop the preview flickering': ('fix', 'Stop the preview flickering'),
            'perf: lean engine skips idle polls': ('perf', 'Lean engine skips idle polls'),
            'chore: bump pin': ('maintenance', 'bump pin'),
            'Fix the flaky tests in tests/startup': ('maintenance', 'Fix the flaky tests in tests/startup'),
            'wip': ('maintenance', 'wip'),
            'Merge branch main into x': ('maintenance', 'Merge branch main into x'),
            "Merge branch 'main' into claude/x": (None, None),
        }
        for subject, (kind, text) in cases.items():
            self.assertEqual(R.clean(subject), (kind, text), subject)

    def test_generated_notes_are_capped_and_count_the_rest(self):
        root = self.repository()
        self.commit(root, 'a', 'Initial')
        git(root, 'tag', '1.0.0')
        for n in range(30):
            self.commit(root, f'f{n}', f'feat: add feature number {n}')
        self.commit(root, 'z', 'chore: internal')
        body, count = R.generated_notes(root, '1.0.0', 10)
        self.assertEqual(count, 31)
        self.assertEqual(body.count('\n- Add feature'), 10)
        self.assertIn('and 20 more changes', body)
        self.assertIn('1 internal change', body)

    def test_curated_notes_win_and_stable_tags_can_require_them(self):
        root = self.repository()
        self.commit(root, 'a', 'Initial')
        git(root, 'tag', '1.0.0')
        self.commit(root, 'b', 'feat: something')
        notes = root / 'docs' / 'release' / 'notes'
        notes.mkdir(parents=True)
        (notes / '2.0.0-beta.1.md').write_text('<!-- note to self -->\n## Highlights\n- Written by hand\n')
        out = root / 'out.md'
        self.assertEqual(R.main(['--root', str(root), '--tag', '2.0.0-beta.1', '--target', 'gitea', '--out', str(out),
                                 '--changelog-url', 'https://example.invalid/o/r']), 0)
        text = out.read_text()
        self.assertIn('Written by hand', text)
        self.assertNotIn('note to self', text)
        self.assertIn('test release', text)
        self.assertIn('compare/1.0.0...2.0.0-beta.1', text)
        self.assertIn('beta guide (docs/release/BETA.md)', text)
        self.assertEqual(R.main(['--root', str(root), '--tag', '2.0.0-beta.1', '--target', 'gitea', '--out', str(out),
                                 '--beta-url', 'https://example.invalid/BETA']), 0)
        self.assertIn('beta guide (https://example.invalid/BETA)', out.read_text())
        self.assertEqual(R.main(['--root', str(root), '--tag', '2.0.0', '--require-curated']), 1)

    def test_previous_tag_skips_prereleases_for_a_stable_tag(self):
        root = self.repository()
        for name, tag in (('a', '1.0.0'), ('b', '2.0.0-beta.1'), ('c', '2.0.0-beta.2')):
            self.commit(root, name, name)
            git(root, 'tag', tag)
        self.commit(root, 'd', 'd')
        git(root, 'tag', '2.0.0')
        self.assertEqual(R.previous_tag(root, '2.0.0'), '1.0.0')
        self.assertEqual(R.previous_tag(root, '2.0.0-beta.2'), '2.0.0-beta.1')


class Guards(unittest.TestCase):
    def test_planning_documents_and_local_files_are_refused(self):
        bad = ['docs/plan-2.0.md', 'docs/TODO.md', 'docs/roadmap.md', 'docs/design-proposal-tooltips.md', 'docs/plans/x.md',
               'docs/adr/0001.md', '.claude/settings.local.json', 'CHANGELOG.md', 'outputs/a.txt', 'Web/a.js', 'x.bak', 'id_rsa']
        for name in bad:
            self.assertTrue(H.check_forbidden([name]), name)
        good = ['docs/dev/architecture.md', 'docs/release/RELEASING.md', 'docs/architecture/tooltips.md', 'Libs/X/CHANGELOG.md',
                '.claude/CLAUDE.md', 'TODO', 'docs/translators/README.md', 'docs/talent-selector.md']
        for name in good:
            self.assertEqual(H.check_forbidden([name]), [], name)

    def test_secret_patterns(self):
        flagged = ['WOWI_API_TOKEN=abcdef0123456789abcdef', 'CF_API_KEY: "0123456789abcdef0123"', '-----BEGIN RSA PRIVATE KEY-----',
                   'token ghp_' + 'a' * 36, 'Authorization: token ' + 'a1' * 20, 'password = "correct-horse-battery"']
        clean = ['WOWI_API_TOKEN: ${{ secrets.WOWI_API_TOKEN }}', 'CF_API_KEY=$CF_API_KEY', 'password = ""', 'local password = readInput()',
                 'Authorization: token $TOKEN', 'echo "set CF_API_KEY in the repository secrets"']
        for line in flagged:
            self.assertTrue(any(p.search(line) for _, p in H.SECRET_PATTERNS), line)
        for line in clean:
            self.assertFalse(any(p.search(line) for _, p in H.SECRET_PATTERNS), line)

    def test_endings_and_syntax_guards_on_a_temporary_file(self):
        names = ['tools/test_devtools.py']
        self.assertEqual(H.check_endings(names), [])
        self.assertEqual(H.check_lua([]), [])


class Copyright(unittest.TestCase):
    """tools/copyright.py: the notice on line one of every original source file, and the TOC licence field."""

    SAMPLES = {
        'lua': ('x.lua', 'local x = 1\n'),
        'python': ('x.py', '"""Doc."""\n'),
        'shell': ('x.sh', 'echo hi\n'),
        'yaml': ('x.yml', 'name: x\n'),
        'toc': ('x.toc', '## Interface: 11509\n## X-License: MIT + Attribution\nmain.lua\n'),
        'xml': ('x.xml', '<Ui/>\n'),
    }

    def repo(self, files):
        root = temp_dir(self)
        git(root, 'init', '-q')
        for name, text in files.items():
            (root / name).parent.mkdir(parents=True, exist_ok=True)
            (root / name).write_text(text)
        git(root, 'add', '-A')
        return root

    def test_the_repository_carries_the_notice(self):
        self.assertEqual(C.check(), [])

    def test_the_notice_is_one_line_built_from_the_constants(self):
        self.assertNotIn('\n', C.NOTICE)
        self.assertNotIn('--', C.NOTICE, 'an XML comment cannot hold two hyphens in a row')
        self.assertTrue(C.NOTICE.startswith(f'Copyright {C.FIRST_YEAR}-{C.LAST_YEAR} Preston A. Elder <prez@neuromancy.net>.'))
        self.assertTrue(C.NOTICE.endswith('see the LICENSE file for details.'))
        self.assertEqual(C.TOC_LICENSE_FIELD, '## X-License: MIT + Attribution')
        # The terms live only in LICENSE.
        self.assertIn('modified MIT license', (ROOT / 'LICENSE').read_text())

    def test_every_comment_syntax(self):
        for kind, (name, text) in self.SAMPLES.items():
            done = C.fixed(kind, text)
            first = done.split('\n')[0]
            self.assertEqual(first, C.notice_line(kind), kind)
            self.assertEqual(C.problem(kind, done), None, kind)
            self.assertEqual(C.fixed(kind, done), done, f'{kind}: --write is idempotent')
        self.assertEqual(C.notice_line('lua'), '-- ' + C.NOTICE)
        self.assertEqual(C.notice_line('python'), '# ' + C.NOTICE)
        self.assertEqual(C.notice_line('toc'), '# ' + C.NOTICE)
        self.assertEqual(C.notice_line('xml'), '<!-- ' + C.NOTICE + ' -->')

    def test_a_shebang_and_an_xml_declaration_stay_first(self):
        script = C.fixed('shell', '#!/bin/sh\necho hi\n')
        self.assertEqual(script.split('\n')[:2], ['#!/bin/sh', C.notice_line('shell')])
        tool = C.fixed('python', '#!/usr/bin/env python3\n"""Doc."""\n')
        self.assertEqual(tool.split('\n')[:2], ['#!/usr/bin/env python3', C.notice_line('python')])
        xml = C.fixed('xml', '<?xml version="1.0" encoding="utf-8"?>\n<Ui/>\n')
        self.assertEqual(xml.split('\n')[:3], ['<?xml version="1.0" encoding="utf-8"?>', C.notice_line('xml'), '<Ui/>'])
        self.assertIsNone(C.problem('xml', xml))
        self.assertEqual(C.problem('xml', '<?xml version="1.0"?>\n<Ui/>\n' + C.notice_line('xml') + '\n'), 'misplaced notice',
                         'the notice goes straight after the declaration')

    def test_a_lua_file_gets_a_blank_line_before_its_own_header(self):
        self.assertEqual(C.fixed('lua', '-- header\nlocal x = 1\n'), C.notice_line('lua') + '\n\n-- header\nlocal x = 1\n')
        self.assertEqual(C.fixed('lua', ''), C.notice_line('lua') + '\n')

    def test_removing_the_notice_fails_the_check(self):
        for kind, (name, text) in self.SAMPLES.items():
            root = self.repo({name: C.fixed(kind, text)})
            self.assertEqual(C.check(root), [], kind)
            (root / name).write_text(text)
            self.assertEqual(C.check(root), [(name, 'missing notice')], kind)

    def test_a_stale_year_or_wording_fails_and_write_upgrades_it(self):
        for kind, (name, text) in self.SAMPLES.items():
            line = C.notice_line(kind)
            for stale in (line.replace(f'-{C.LAST_YEAR}', f'-{C.LAST_YEAR - 1}'),
                          line.replace('modified MIT license (MIT + Attribution)', 'MIT license'),
                          line.replace(f'{C.FIRST_YEAR}-{C.LAST_YEAR}', str(C.FIRST_YEAR))):
                self.assertNotEqual(stale, line)
                root = self.repo({name: stale + '\n' + text})
                self.assertEqual(C.check(root), [(name, 'stale notice')], (kind, stale))
                changed, stuck = C.write(root)
                self.assertEqual((changed, stuck), ([name], []))
                self.assertEqual((root / name).read_text(), line + '\n' + text, kind)
                self.assertEqual(C.check(root), [])
                self.assertEqual(C.write(root), ([], []), 'idempotent')

    def test_a_notice_below_the_first_line_is_not_the_notice(self):
        root = self.repo({'x.lua': '-- other\n' + C.notice_line('lua') + '\n'})
        self.assertEqual(C.check(root), [('x.lua', 'misplaced notice')])
        self.assertEqual(C.write(root)[1][0][0], 'x.lua')

    def test_a_new_kind_of_file_must_be_classified(self):
        root = self.repo({'new.zzz': 'data\n', 'sub/no_extension': 'data\n', 'ok.png': 'x', 'ok.lua': C.fixed('lua', '')})
        problems = dict(C.check(root))
        self.assertTrue(problems['new.zzz'].startswith('not classified'))
        self.assertTrue(problems['sub/no_extension'].startswith('not classified'))
        self.assertEqual(sorted(problems), ['new.zzz', 'sub/no_extension'])
        self.assertEqual(C.write(root), ([], []), 'write never invents a classification')

    def test_vendored_and_generated_files_are_skipped_with_a_reason(self):
        for name in ('Libs/Ace/a.lua', 'LibsAugment/FAIAP.lua', 'tools/vendor/x/release.sh', 'Locales/deDE.lua',
                     'Modules/RotationMaster_HelpText/frFR.lua', 'Data/text_bundle_index.lua', 'Data/artwork.lua',
                     'tests/fixtures/client_api_era.lua', 'Assets/Controls/a.svg', 'Fonts/a.ttf', 'x/data.json', 'docs/a.md'):
            action = C.classify(name)
            self.assertEqual(action[0], 'skip', name)
            self.assertTrue(action[1], name)
        for name in ('main.lua', 'Modules/RotationMaster_Mage/era/frost.lua', 'tests/a.lua', 'tools/check', 'tools/x.py', '.pkgmeta',
                     'Assets/Conditions/export_icons.py', 'Modules/RotationMaster_HelpText/RotationMaster_HelpText.toc'):
            self.assertEqual(C.classify(name)[0], 'include', name)

    def test_every_toc_names_the_attribution_licence(self):
        old = 'Hello\n## X-License: MIT\n'
        self.assertIn('X-License', C.toc_problem(old))
        self.assertIn('X-License', C.toc_problem('## Interface: 1\n'))
        self.assertIsNone(C.toc_problem('## X-License: MIT + Attribution\n'))
        root = self.repo({'x.toc': C.notice_line('toc') + '\n## X-License: MIT\n'})
        self.assertEqual([name for name, _ in C.check(root)], ['x.toc'])

    def test_frozen_entries_must_exist(self):
        original = dict(C.FROZEN)
        self.addCleanup(lambda: (C.FROZEN.clear(), C.FROZEN.update(original)))
        C.FROZEN['no/such/file.lua'] = 'test entry'
        self.assertIn(('no/such/file.lua', 'FROZEN entry names a file that is not tracked'), C.check())

    def test_the_static_gate_runs_the_check(self):
        listing = (TOOLS / 'check').read_text()
        self.assertIn("'tools/copyright.py', '--check'", listing.split('if not args.static')[0])

    def test_the_generators_emit_the_notice(self):
        import generate_artwork_catalog
        self.assertEqual(generate_artwork_catalog.release_metadata().split('\n')[0], C.notice_line('yaml'))
        self.assertEqual((ROOT / 'Data/builtin_sources.lua').read_text().split('\n')[0], C.notice_line('lua'))
        self.assertIn(C.notice_line('toc') + '\n', (ROOT / 'Modules/RotationMaster_HelpText/RotationMaster_HelpText.toc').read_text())


class Fast(unittest.TestCase):
    COMMANDS = [['lua5.1', 'tests/rotation_scope_core.lua'], ['luajit', 'tests/rotation_scope_core.lua'], ['lua5.1', 'tests/platform_unit_health.lua'],
                ['lua5.1', 'tests/defaults_tbc_mage.lua'], ['lua5.1', 'tests/other.lua'], ['python3', 'tests/verify.py']]

    def test_suites_are_chosen_by_name(self):
        self.assertEqual(fast_tests.select(['Core/rotation_scope.lua'], self.COMMANDS), [['lua5.1', 'tests/rotation_scope_core.lua']])
        self.assertEqual(fast_tests.select(['Platform/unit_health.lua'], self.COMMANDS), [['lua5.1', 'tests/platform_unit_health.lua']])
        self.assertEqual(fast_tests.select(['Modules/RotationMaster_Mage/tbc/frost.lua'], self.COMMANDS), [['lua5.1', 'tests/defaults_tbc_mage.lua']])
        self.assertEqual(fast_tests.select(['tests/other.lua'], self.COMMANDS), [['lua5.1', 'tests/other.lua']])
        self.assertEqual(fast_tests.select(['Core/nothing.lua', 'Libs/X/a.lua'], self.COMMANDS), [])

    def test_a_locale_or_text_bundle_edit_picks_the_locale_suites(self):
        commands = [['lua5.1', 'tests/client_locale.lua'], ['lua5.1', 'tests/text_bundles.lua'], ['lua5.1', 'tests/other.lua']]
        for changed in ('Locales/deDE.lua', 'Modules/RotationMaster_HelpText/frFR.lua', 'Core/text_bundles.lua'):
            picked = fast_tests.select([changed], commands)
            self.assertIn(['lua5.1', 'tests/text_bundles.lua'], picked, changed)
        self.assertEqual(fast_tests.select(['Modules/RotationMaster_HelpText/frFR.lua'], commands),
                         [['lua5.1', 'tests/client_locale.lua'], ['lua5.1', 'tests/text_bundles.lua']])

    def test_collect_lists_the_real_command_list(self):
        commands = check_all.collect()
        self.assertGreater(len(commands), 500)
        self.assertEqual(commands[0][1], 'tests/verify.py')

    # A suite that tools/check does not run is a suite that never fails. Every tests/*.lua and tests/*.py is a command
    # in the list, unless it is named here with the reason it is not (none is: the helper scripts live in
    # tests/fixtures/, and the one file that is not a suite is tests/README.md).
    UNLISTED_SUITES = {}

    def test_every_suite_file_is_a_command_tools_check_runs(self):
        run = {argument for command in check_all.collect() for argument in command}
        suites = sorted(path.relative_to(ROOT).as_posix() for pattern in ('tests/*.lua', 'tests/*.py') for path in ROOT.glob(pattern))
        self.assertGreater(len(suites), 500)
        self.assertEqual([name for name in suites if name not in run and name not in self.UNLISTED_SUITES], [],
                         'a suite file is not in tools/check; add it to the lua5.1/luajit/python lines or to UNLISTED_SUITES with a reason')

    def test_the_slow_and_known_failure_lists_name_real_commands(self):
        labels = {check_all.label(command) for command in check_all.collect()}
        for name in ('slow_tests.txt', 'known_failures.txt'):
            listed = check_all.load_baseline(TOOLS / name)
            self.assertEqual(sorted(listed - labels), [], f'{name} lists a command tools/check does not run')

    def test_baseline_file_ignores_comments(self):
        root = temp_dir(self)
        (root / 'b.txt').write_text('# comment\nlua5.1 tests/a.lua\n\n  \npython3 tests/b.py\n')
        self.assertEqual(check_all.load_baseline(root / 'b.txt'), {'lua5.1 tests/a.lua', 'python3 tests/b.py'})
        self.assertEqual(check_all.label(['lua5.1', 'tests/a.lua']), 'lua5.1 tests/a.lua')


class Plan(unittest.TestCase):
    ALL = {'CF_API_KEY': 'x', 'WOWI_API_TOKEN': 'x', 'WAGO_API_TOKEN': 'x'}

    def test_a_stable_tag_goes_everywhere(self):
        result = release_plan.plan('2.0.0', self.ALL)
        self.assertEqual((result['type'], result['prerelease'], result['problems']), ('release', 'false', []))
        self.assertEqual(result['sites'], ['curseforge', 'wago', 'wowinterface'])
        self.assertEqual(result['packager'], '-u -e -l')

    def test_a_beta_skips_wowinterface_unless_asked(self):
        result = release_plan.plan('2.0.0-beta.1', self.ALL)
        self.assertEqual((result['type'], result['prerelease']), ('beta', 'true'))
        self.assertEqual(result['sites'], ['curseforge', 'wago'])
        self.assertIn('-w 0', result['packager'])
        self.assertEqual(release_plan.plan('2.0.0-beta.1', self.ALL, wowi_beta=True)['sites'], ['curseforge', 'wago', 'wowinterface'])
        self.assertEqual(release_plan.plan('2.0.0-alpha.2', self.ALL)['type'], 'alpha')

    def test_a_missing_secret_fails_the_plan_unless_allowed(self):
        env = {'CF_API_KEY': 'x', 'WAGO_API_TOKEN': 'x'}
        self.assertTrue(release_plan.plan('2.0.0', env)['problems'])
        allowed = release_plan.plan('2.0.0', env, allow_missing=True)
        self.assertEqual((allowed['problems'], allowed['sites']), ([], ['curseforge', 'wago']))
        self.assertIn('-w 0', allowed['packager'])

    def test_a_dry_run_needs_no_secrets_and_uploads_nothing(self):
        result = release_plan.plan('2.0.0', {}, dry_run=True)
        self.assertEqual(result['problems'], [])
        self.assertTrue(result['packager'].startswith('-u -e -l -d') or ' -d' in result['packager'])

    # The workflow pipes the tool through tee under pipefail and relies on its exit status to refuse a release that would
    # skip a site, and on the key=value lines for $GITHUB_OUTPUT. Run it as the workflow does, in a process.
    def run_tool(self, *arguments, environ=None):
        clean = {key: value for key, value in os.environ.items() if key not in ('CF_API_KEY', 'WOWI_API_TOKEN', 'WAGO_API_TOKEN')}
        clean.update(environ or {})
        return subprocess.run([sys.executable, str(TOOLS / 'release_plan.py'), *arguments], capture_output=True, text=True, env=clean)

    def test_the_command_exits_nonzero_when_a_site_would_be_skipped(self):
        refused = self.run_tool('--tag', '2.0.0', environ={'CF_API_KEY': 'x', 'WAGO_API_TOKEN': 'x'})
        self.assertEqual(refused.returncode, 1, refused.stderr)
        self.assertIn('ERROR wowinterface: WOWI_API_TOKEN is not set', refused.stderr)
        self.assertEqual(self.run_tool('--tag', '2.0.0').returncode, 1, 'no secret at all was accepted')
        self.assertEqual(self.run_tool('--tag', '2.0.0-beta.1', environ={'CF_API_KEY': 'x'}).returncode, 1, 'a beta without the Wago secret was accepted')

    def test_the_command_exits_zero_and_prints_the_workflow_outputs(self):
        done = self.run_tool('--tag', '2.0.0-beta.1', environ={'CF_API_KEY': 'x', 'WAGO_API_TOKEN': 'x'})
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(done.stdout.splitlines(), ['type=beta', 'prerelease=true', 'sites=curseforge wago', 'packager=-u -e -l -w 0'])
        self.assertEqual(self.run_tool('--tag', '2.0.0', '--dry-run').returncode, 0)
        self.assertEqual(self.run_tool('--tag', '2.0.0', '--allow-missing-tokens', environ={'CF_API_KEY': 'x'}).returncode, 0)


class FakeGitea(http.server.BaseHTTPRequestHandler):
    state = None

    def log_message(self, *args):
        pass

    def reply(self, code, body=None):
        raw = json.dumps(body).encode() if body is not None else b''
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def record(self):
        length = int(self.headers.get('Content-Length') or 0)
        body = self.rfile.read(length)
        self.state['calls'].append((self.command, self.path, self.headers.get('Authorization'), body))
        return body

    def do_GET(self):
        self.record()
        release = self.state.get('release')
        if self.path.startswith('/api/v1/repos/o/r/releases/tags/'):
            return self.reply(200, release) if release else self.reply(404, {'message': 'no'})
        if self.path.endswith('/assets'):
            return self.reply(200, self.state.get('assets', []))
        self.reply(404, {})

    def do_POST(self):
        body = self.record()
        if self.state.get('fail'):
            return self.reply(500, {'message': 'boom'})
        if self.path.endswith('/releases'):
            self.state['release'] = dict(json.loads(body), id=7)
            return self.reply(201, self.state['release'])
        if '/assets?' in self.path:
            self.state.setdefault('assets', []).append({'id': 9, 'name': self.path.split('name=')[1]})
            return self.reply(201, {'id': 9})
        self.reply(404, {})

    def do_PATCH(self):
        body = self.record()
        self.state['release'] = dict(self.state['release'], **json.loads(body))
        self.reply(200, self.state['release'])

    def do_DELETE(self):
        self.record()
        self.state['assets'] = []
        self.reply(204)


class GiteaRelease(unittest.TestCase):
    def serve(self, **state):
        state.setdefault('calls', [])
        handler = type('Handler', (FakeGitea,), {'state': state})
        server = http.server.HTTPServer(('127.0.0.1', 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return state, f'http://127.0.0.1:{server.server_port}'

    def files(self):
        root = temp_dir(self)
        (root / 'RotationMaster-2.0.0-beta.1.zip').write_bytes(b'PK-fake')
        return root / 'RotationMaster-2.0.0-beta.1.zip'

    def test_creates_a_prerelease_with_the_asset_and_never_prints_the_token(self):
        state, url = self.serve()
        log = []
        gitea_release.publish(url, 'o/r', 'sekrit', '2.0.0-beta.1', '2.0.0-beta.1', 'notes', True, [self.files()], log=log.append)
        self.assertTrue(state['release']['prerelease'])
        self.assertEqual(state['release']['body'], 'notes')
        self.assertEqual(state['assets'][0]['name'], 'RotationMaster-2.0.0-beta.1.zip')
        self.assertTrue(all(call[2] == 'token sekrit' for call in state['calls']))
        self.assertNotIn('sekrit', ' '.join(log))

    def test_running_again_updates_and_replaces_the_asset(self):
        state, url = self.serve(release={'id': 7, 'tag_name': 'v', 'body': 'old', 'prerelease': True},
                                assets=[{'id': 3, 'name': 'RotationMaster-2.0.0-beta.1.zip'}])
        gitea_release.publish(url, 'o/r', 't', '2.0.0-beta.1', 'name', 'new notes', False, [self.files()], log=lambda *_: None)
        methods = [(c[0], c[1].split('?')[0]) for c in state['calls']]
        self.assertIn(('PATCH', '/api/v1/repos/o/r/releases/7'), methods)
        self.assertIn(('DELETE', '/api/v1/repos/o/r/releases/7/assets/3'), methods)
        self.assertEqual((state['release']['body'], state['release']['prerelease']), ('new notes', False))

    def test_dry_run_changes_nothing_and_errors_are_reported(self):
        state, url = self.serve()
        gitea_release.publish(url, 'o/r', 't', 'x', 'x', 'n', True, [], dry_run=True, log=lambda *_: None)
        self.assertEqual([c[0] for c in state['calls']], ['GET'])
        failing, url = self.serve(fail=True)
        with self.assertRaises(gitea_release.ApiError):
            gitea_release.publish(url, 'o/r', 't', 'x', 'x', 'n', True, [], log=lambda *_: None)

    def test_the_command_line_needs_a_token(self):
        notes = temp_dir(self) / 'n.md'
        notes.write_text('x')
        saved = {k: os.environ.pop(k, None) for k in ('GITEA_TOKEN', 'RELEASE_TOKEN', 'GITHUB_TOKEN')}
        self.addCleanup(lambda: os.environ.update({k: v for k, v in saved.items() if v}))
        self.assertEqual(gitea_release.main(['--tag', 'x', '--notes', str(notes), '--api-url', 'http://127.0.0.1:1', '--repo', 'o/r']), 2)


class Workflows(unittest.TestCase):
    def setUp(self):
        try:
            import yaml  # noqa: F401
        except ImportError:
            self.skipTest('PyYAML is not installed')

    def lint(self, text, name='w.yml'):
        path = temp_dir(self) / name
        path.write_text(text)
        problems = []
        lint_workflows.lint_workflow(path, problems)
        return problems

    def test_the_repository_workflows_are_clean(self):
        self.assertEqual(lint_workflows.main(['--require-yaml']), 0)

    def test_mistakes_are_caught(self):
        good = ('name: x\non: push\njobs:\n  a:\n    runs-on: ubuntu-latest\n    timeout-minutes: 5\n'
                '    steps:\n      - run: echo ok\n')
        self.assertEqual(self.lint(good), [])
        self.assertTrue(self.lint(good.replace('timeout-minutes: 5', 'x: 1')), 'no timeout')
        self.assertTrue(self.lint(good.replace('echo ok', 'echo ${{ secrets.TOKEN }}')), 'secret in a script')
        self.assertTrue(self.lint(good.replace('echo ok', 'echo ${{ github.event.inputs.tag }}')), 'injectable expression')
        self.assertTrue(self.lint(good.replace('echo ok', 'if then')), 'shell syntax')
        self.assertTrue(self.lint(good.replace('- run: echo ok', '- uses: actions/checkout@v4')), 'unpinned action')
        self.assertTrue(self.lint(good.replace('    steps:', '    needs: [b]\n    steps:')), 'unknown needs')
        self.assertTrue(self.lint(good + '        uses: y\n'), 'run and uses')
        self.assertTrue(self.lint(good.replace('on: push', 'on: push\non: pull_request')), 'duplicate key')

class Translation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.corpus = T.Corpus(['deDE'])

    class Args:
        allow_identical = False
        max_ratio = 2.5

    def check(self, key, text, locale='deDE'):
        return translation_apply.validate(self.corpus, locale, key, text, self.Args)

    def test_names_and_token_only_strings_are_not_untranslated(self):
        self.assertEqual(self.corpus.identical_reason('deDE', 'Rotation Master'), 'name')
        self.assertEqual(self.corpus.identical_reason('deDE', '%d. %s'), 'no-words')
        self.assertEqual(self.corpus.identical_reason('deDE', 'Questie'), 'name')

    def test_classification_accounts_for_every_english_key(self):
        state = self.corpus.classify('deDE')
        counted = len(state['complete']) + len(state['missing']) + len(state['stale']) + len(state['suspect']) + len(
            [k for k in state['invalid'] if k not in state['complete'] and k not in state['stale'] and k not in state['suspect']])
        self.assertGreaterEqual(counted, len(self.corpus.english) - 0)

    def test_validation_rules(self):
        key = next(k for k in self.corpus.english if k.count('%s') == 1 and len(k) < 60 and '{' not in k and '|' not in k)
        english = self.corpus.english[key]
        self.assertEqual(self.check(key, 'Übersetzt ' + english), ([], self.check(key, 'Übersetzt ' + english)[1]))
        self.assertTrue(self.check(key, 'Übersetzt')[0], 'dropped placeholder')
        self.assertTrue(self.check(key, ' Übersetzt ' + english)[0], 'leading space')
        self.assertTrue(self.check(key, 'Über\nsetzt ' + english)[0], 'extra line break')
        self.assertTrue(self.check(key, 'Über\\"setzt ' + english)[0], 'backslash')
        self.assertTrue(self.check(key, 'Über|xsetzt ' + english)[0], 'stray pipe')
        self.assertTrue(self.check(key, 'Über​setzt ' + english)[0], 'zero width')
        self.assertTrue(self.check('not a key at all', 'x')[0])
        self.assertTrue(self.check(key, '')[0])
        self.assertTrue(self.check(key, english)[0], 'identical to English')

    def test_color_codes_must_survive(self):
        key = next((k for k, v in self.corpus.english.items() if '|cff' in v.lower() and '|r' in v), None)
        if key:
            english = self.corpus.english[key]
            self.assertTrue(self.check(key, english.replace('|r', ''))[0])


if __name__ == '__main__':
    unittest.main(verbosity=1)
