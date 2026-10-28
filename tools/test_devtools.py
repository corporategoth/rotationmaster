#!/usr/bin/env python3
"""Tests for the development tools: package builder and checker, release notes, translation tools,
repository guards, fast-test selection. Standard library only; seconds.

  python3 tools/test_devtools.py
"""
import contextlib
import http.server
import io
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
import fast_tests  # noqa: E402
import function_comments as FC  # noqa: E402
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


class FunctionComments(unittest.TestCase):
    """tools/function_comments.py: which functions need a structured header and what makes one malformed."""

    GOOD = (
        '-- Looks a spell up.\n'
        '-- @param spell number|string  The spell ID or name.\n'
        '-- @param unit string|nil  The unit token; nil means "player".\n'
        '-- @return boolean  True when known.\n'
        '-- @return string|nil  The reason code when false.\n'
        '--\n'
        '-- Longer notes.\n'
        'function addon:Lookup(spell, unit)\n'
        '    local known = spell == 1\n'
        '    if known then\n'
        '        return true\n'
        '    end\n'
        '    return false, "unknown"\n'
        'end\n')

    def codes(self, source, strict=False, frozen=None):
        found = FC.check_source('x.lua', source, frozen=frozen if frozen is not None else set(), strict=strict)
        return sorted(v.code for v in found)

    def mutate(self, old, new, source=None):
        source = source or self.GOOD
        self.assertIn(old, source)
        return source.replace(old, new)

    def test_a_complete_header_passes(self):
        self.assertEqual(self.codes(self.GOOD), [])

    def test_missing_and_plain_comments(self):
        body = 'function addon:Lookup(spell, unit)\n    local a = 1\n    local b = 2\n    local c = 3\n    return a + b + c + spell\nend\n'
        self.assertEqual(self.codes(body), ['missing'], 'no comment')
        self.assertEqual(self.codes('-- Looks a spell up.\n' + body), ['missing'], 'plain comment where tags are needed')
        self.assertEqual(self.codes('-- Looks a spell up.\n\n' + body), ['missing'], 'comment behind a blank line')
        without_params = 'function addon:Reset()\n' + '    local a = 1\n' * 6 + 'end\n'
        self.assertEqual(self.codes(without_params), ['missing'], 'six lines need a comment')
        self.assertEqual(self.codes('-- Resets.\n' + without_params), [], 'a brief line is enough without parameters')

    def test_a_blank_line_between_a_tagged_header_and_the_function(self):
        source = self.mutate('-- Longer notes.\nfunction', '-- Longer notes.\n\nfunction')
        self.assertEqual(self.codes(source), ['blank'])

    def test_trivial_functions_need_nothing_unless_strict(self):
        short = 'local function pair(a, b)\n    return a, b\nend\n'
        self.assertEqual(self.codes(short), [])
        self.assertEqual(self.codes(short, strict=True), ['missing'])
        three = 'local function pair(a, b)\n    local x = a\n    local y = b\n    return x, y\nend\n'
        self.assertEqual(self.codes(three), [], 'three lines are still trivial')
        four = 'local function pair(a, b)\n    local x = a\n    local y = b\n    local z = x\n    return x, y\nend\n'
        self.assertEqual(self.codes(four), ['missing'], 'more than three lines with parameters')
        self.assertEqual(self.codes('local function noop()\n    local a = 1\n    local b = 2\n    local c = 3\n    local d = 4\nend\n'), [])

    def test_a_trivial_function_with_a_header_is_still_checked(self):
        source = '-- Pairs.\n-- @param a number  First.\nlocal function pair(a, b)\n    return a, b\nend\n'
        self.assertEqual(self.codes(source), ['param', 'return'])

    def test_the_brief_line(self):
        source = self.mutate('-- Looks a spell up.\n', '')
        self.assertEqual(self.codes(source), ['brief'])

    def test_parameters_must_match_the_declaration(self):
        self.assertEqual(self.codes(self.mutate('-- @param unit string|nil  The unit token; nil means "player".\n', '')), ['param'])
        self.assertEqual(self.codes(self.mutate('@param unit', '@param target')), ['param'])
        swapped = self.mutate('-- @param spell number|string  The spell ID or name.\n-- @param unit string|nil  The unit token; nil means "player".\n',
                              '-- @param unit string|nil  The unit token; nil means "player".\n-- @param spell number|string  The spell ID or name.\n')
        self.assertEqual(self.codes(swapped), ['param'])
        extra = self.mutate('-- @return boolean', '-- @param more any  Extra.\n-- @return boolean')
        self.assertEqual(self.codes(extra), ['param'])

    def test_self_is_implicit_for_methods_only(self):
        listed = self.mutate('-- @param spell', '-- @param self table  The addon.\n-- @param spell')
        self.assertEqual(self.codes(listed), ['param'], 'a colon method never lists self')
        local = ('-- Runs.\n-- @param self table  The addon.\n-- @param n number  How often.\n'
                 'local function run(self, n)\n' + '    local a = n\n' * 4 + 'end\n')
        self.assertEqual(self.codes(local), [], 'an explicit self parameter is listed')
        self.assertEqual(self.codes(local.replace('-- @param self table  The addon.\n', '')), ['param'])

    def test_varargs_are_a_parameter(self):
        source = ('-- Calls.\n-- @param fn function  The function.\n-- @param ... any  Its arguments.\n'
                  '-- @return any  Its results.\nlocal function call(fn, ...)\n' + '    local a = fn\n' * 3 + '    return fn(...)\nend\n')
        self.assertEqual(self.codes(source), [])
        self.assertEqual(self.codes(source.replace('-- @param ... any  Its arguments.\n', '')), ['param'])

    def test_return_values(self):
        self.assertEqual(self.codes(self.mutate('-- @return string|nil  The reason code when false.\n', '')), ['return'], 'two values returned')
        self.assertEqual(self.codes(self.mutate('-- @return string|nil  The reason code when false.\n-- @return boolean  True when known.\n'
                                                .replace('-- @return boolean  True when known.\n', ''), '')), ['return'])
        silent = ('-- Runs.\n-- @param n number  How often.\n-- @return boolean  Whether it ran.\n'
                  'local function run(n)\n' + '    local a = n\n' * 5 + 'end\n')
        self.assertEqual(self.codes(silent), ['return'], 'a @return on a function that returns nothing')

    def test_returns_of_nested_functions_do_not_count(self):
        source = ('-- Builds a handler.\n-- @param n number  The count.\n'
                  'local function build(n)\n    local handler = function()\n        return n\n    end\n'
                  '    local a = 1\n    local b = 2\n    handler()\n    handler()\nend\n')
        self.assertEqual(self.codes(source), [])

    def test_malformed_tags(self):
        self.assertEqual(self.codes(self.mutate('-- @param spell number|string  The spell ID or name.', '-- @param spell')), ['tag'])
        self.assertEqual(self.codes(self.mutate('-- @param spell number|string  The spell ID or name.', '-- @param spell number|string')), ['tag'])
        self.assertEqual(self.codes(self.mutate('-- @return boolean  True when known.', '-- @return boolean')), ['tag'])
        one_line = self.mutate('-- @return boolean  True when known.', '-- @return boolean  True when known. @return x  Y')
        self.assertEqual(self.codes(one_line), ['tag'], 'two tags on a line')
        glued = self.mutate('-- Looks a spell up.', '-- Looks a spell up. @param spell x  Y')
        self.assertEqual(self.codes(glued), ['tag'], 'a tag in the middle of the brief line')
        late = self.mutate('-- Longer notes.', '-- Longer notes.\n-- @param extra any  After the notes.')
        self.assertEqual(self.codes(late), ['tag'], 'a tag after the longer notes')
        order = self.mutate('-- @return boolean  True when known.', '-- @return boolean  True when known.\n-- @param z any  Late.')
        self.assertIn('tag', self.codes(order), 'a @param after a @return')
        self.assertIn('tag', self.codes(self.mutate('-- @return boolean', '-- @see x  Y\n-- @return boolean')), 'an unknown tag')

    def test_types_may_contain_spaces_inside_brackets(self):
        source = self.mutate('number|string  The spell ID', 'table{id=number, name=string}  The spell')
        self.assertEqual(self.codes(source), [])
        self.assertEqual(self.codes(self.mutate('number|string  The spell ID or name.', 'table{id=number, name=string}')), ['tag'])

    def test_wrapped_descriptions_and_annotations(self):
        wrapped = self.mutate('-- @param unit string|nil  The unit token; nil means "player".',
                              '-- @param unit string|nil  The unit token;\n--   nil means "player".')
        self.assertEqual(self.codes(wrapped), [])
        annotated = self.mutate('function addon:Lookup', '---@param unit string|nil\nfunction addon:Lookup')
        self.assertEqual(self.codes(annotated), [], 'a LuaLS annotation between the header and the function is ignored')

    def test_named_functions_and_table_fields(self):
        field = 'local t = {\n    run = function(a)\n' + '        local x = a\n' * 6 + '    end,\n}\n'
        self.assertEqual(self.codes(field), [], 'a short table-field closure is a callback')
        long_field = 'local t = {\n    run = function(a)\n' + '        local x = a\n' * 16 + '    end,\n}\n'
        self.assertEqual(self.codes(long_field), ['missing'])
        assigned = 'local run\nrun = function(a)\n' + '    local x = a\n' * 6 + 'end\n'
        self.assertEqual(self.codes(assigned), ['missing'])
        member = 'function M.run(a)\n' + '    local x = a\n' * 6 + 'end\n'
        self.assertEqual(self.codes(member), ['missing'])
        anonymous = 'register(function(a)\n' + '    local x = a\n' * 8 + 'end)\n'
        self.assertEqual(self.codes(anonymous), [])
        nested = 'local function outer()\n    local function inner(a)\n' + '        local x = a\n' * 6 + '    end\n    inner(1)\nend\n'
        found = FC.check_source('x.lua', nested, frozen=set())
        self.assertEqual(sorted(v.name for v in found), ['local inner', 'local outer'], 'a nested named function is checked')

    def test_generated_regions_are_not_read(self):
        suffix = ('-- BEGIN GENERATED RM SOURCE BINDINGS\n'
                  'do\n    local function sourceGetter(name)\n' + '        local a = name\n' * 8 + '    end\nend\n'
                  '-- END GENERATED RM SOURCE BINDINGS\n')
        self.assertEqual(self.codes('local x = 1\n' + suffix), [])
        region = ('local x = 1\n-- BEGIN GENERATED THING\nfunction G(a)\n' + '    local v = a\n' * 8
                  + 'end\n-- END GENERATED THING\n')
        self.assertEqual(self.codes(region), [])
        self.assertEqual(self.codes(region.replace('-- BEGIN GENERATED THING\n', '').replace('-- END GENERATED THING\n', '')),
                         ['missing'], 'the same function outside a generated region')

    def test_frozen_helpers_are_checked_whole_and_never_inside(self):
        text = ('-- Doubles.\n-- @param n number  The number.\n-- @return number  Twice n.\n'
                'local function double(n)\n    local function inner(v)\n        local a = v\n        local b = a\n'
                '        local c = b\n        local d = c\n        return d\n    end\n    return inner(n) * 2\nend\n')
        raw = text[text.index('(n)') + 3:text.rindex('end')]
        self.assertEqual(self.codes(text, frozen={raw}), [], 'the nested function inside a frozen body is exempt')
        self.assertEqual(self.codes(text, frozen=set()), ['missing'], 'the same function when it is not frozen')
        no_return = text.replace('-- @return number  Twice n.\n', '')
        self.assertEqual(self.codes(no_return, frozen={raw}), ['return'], 'the frozen body still decides the returns')

    def test_the_baseline_ratchet(self):
        source = ('function a1(x)\n' + '    local v = x\n' * 6 + 'end\n\nfunction a2(x)\n' + '    local v = x\n' * 6 + 'end\n')
        found = FC.check_source('x.lua', source, frozen=set())
        self.assertEqual(len(found), 2)
        baseline = {found[0].key(): 1}
        fresh, stale = FC.new_violations(found, baseline)
        self.assertEqual([v.name for v in fresh], ['a2'], 'only the violation outside the baseline fails')
        self.assertEqual(stale, 0)
        fresh, stale = FC.new_violations(found[:1], {found[0].key(): 1, found[1].key(): 1})
        self.assertEqual((len(fresh), stale), (0, 1), 'a baselined violation that no longer occurs is reported as stale')
        twice = FC.check_source('x.lua', source.replace('a2', 'a1'), frozen=set())
        fresh, _ = FC.new_violations(twice, {twice[0].key(): 1})
        self.assertEqual(len(fresh), 1, 'a second violation of the same kind is new')

    def test_baseline_files_round_trip(self):
        directory = temp_dir(self)
        path = directory / 'baseline.json'
        found = FC.check_source('x.lua', 'function a1(x)\n' + '    local v = x\n' * 6 + 'end\n', frozen=set())
        FC.write_baseline(path, found)
        self.assertEqual(FC.load_baseline(path), {found[0].key(): 1})

    def test_a_path_outside_the_repository_is_an_error(self):
        directory = temp_dir(self)
        (directory / 'x.lua').write_text('return 1\n', encoding='utf-8')
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(FC.main([str(directory / 'x.lua')]), 2)

    def test_the_tree_is_the_formatters_without_the_tests(self):
        files = FC.tree_files()
        self.assertIn('main.lua', files)
        self.assertFalse([f for f in files if f.startswith(('tests/', 'Libs/', 'Locales/', 'Modules/'))])
        self.assertNotIn('Data/builtin_sources.lua', files)

    def test_summary_counts_per_directory(self):
        found = [FC.Violation('UI/a.lua', 1, 'f', 'missing', ''), FC.Violation('UI/b.lua', 1, 'g', 'missing', ''),
                 FC.Violation('Core/a.lua', 1, 'h', 'missing', ''), FC.Violation('main.lua', 1, 'i', 'missing', '')]
        self.assertEqual([row.split() for row in FC.summarize(found)], [['2', 'UI'], ['1', '.'], ['1', 'Core']])

    def test_the_shipped_tool_files_stay_documented(self):
        """A real file, mutated in memory: dropping or breaking a header in tools/builtin_modules.lua is caught."""
        text = (ROOT / 'tools' / 'builtin_modules.lua').read_text(encoding='utf-8')
        self.assertEqual(self.codes(text), [])
        self.assertEqual(self.codes(text.replace('-- @param root string|nil  The repository root; nil or empty means the current directory.\n-- @return string[]  The TOC paths.', '-- @return string[]  The TOC paths.')), ['param'])
        self.assertEqual(self.codes(text.replace('-- Lists every module TOC (fallback and flavours): inputs whose bytes decide what loads.', '')), ['brief'])


if __name__ == '__main__':
    unittest.main(verbosity=1)
