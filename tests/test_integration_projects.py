"""Offline onboarding guard for every supported addon and release/source host."""
import copy
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def generator():
    path = ROOT / 'tools/generate_integration_projects.py'
    assert path.is_file(), 'integration provider coverage guard is missing'
    spec = importlib.util.spec_from_file_location('integration_projects', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def example():
    channels = ('curseforge', 'wowinterface', 'wago', 'wowuphub', 'github')
    coverage = {key: {'status': 'not_found', 'query': f'Example on {key}',
                      'evidence': ['Search performed; no matching author project verified.']}
                for key in channels}
    coverage['curseforge']['status'] = 'verified'
    coverage['github']['status'] = 'verified'
    links = [dict(provider='curseforge', label='CurseForge', url='https://www.curseforge.com/wow/addons/example',
                  primary=True, note='Publisher lists TBC.', families=['tbc']),
             dict(provider='github', label='GitHub', url='https://github.com/author/example',
                  primary=False, note='Official source repository; choose the correct release.', families=[])]
    return {'checked': '2026-10-20', 'integrations': {'Example': {'links': links, 'coverage': coverage, 'scope': {'families': ['tbc'], 'evidence': ['Publisher declares TBC.']}}}}


class CoverageGuard(unittest.TestCase):
    def test_every_channel_is_checked_and_github_survives_a_primary_download_link(self):
        g = generator(); data = example(); g.validate(data, {'Example'})
        output = g.render_projects(data)
        self.assertIn('https://github.com/author/example', output)
        self.assertIn('https://www.curseforge.com/wow/addons/example', output)

    def test_new_supported_addon_requires_a_matching_record(self):
        with self.assertRaisesRegex(ValueError, 'identities'):
            generator().validate(example(), {'Example', 'NewAddon'})

    def test_omitting_a_provider_search_is_rejected(self):
        data = example(); del data['integrations']['Example']['coverage']['wowuphub']
        with self.assertRaisesRegex(ValueError, 'channels'):
            generator().validate(data, {'Example'})

    def test_no_pretend_negative_or_unverified_without_an_actual_attempt(self):
        for status in ('not_found', 'unverified'):
            data = example(); row = data['integrations']['Example']['coverage']['wago']
            row.update(status=status, query='', evidence=[])
            with self.assertRaisesRegex(ValueError, 'evidence'):
                generator().validate(data, {'Example'})

    def test_verified_channel_requires_a_project_link(self):
        data = example(); data['integrations']['Example']['coverage']['wago']['status'] = 'verified'
        with self.assertRaisesRegex(ValueError, 'verified'):
            generator().validate(data, {'Example'})

    def test_provider_label_cannot_hide_a_mismatched_domain(self):
        data = example(); data['integrations']['Example']['links'][1]['url'] = 'https://example.com/github'
        with self.assertRaisesRegex(ValueError, 'host'):
            generator().validate(data, {'Example'})

    def test_duplicate_urls_and_silent_link_limits_are_rejected(self):
        data = example(); links = data['integrations']['Example']['links']; links.append(copy.deepcopy(links[1]))
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            generator().validate(data, {'Example'})
        data = example(); base = data['integrations']['Example']['links'][1]
        data['integrations']['Example']['links'] += [dict(base, url=f'https://github.com/author/repo{i}') for i in range(31)]
        with self.assertRaisesRegex(ValueError, '32'):
            generator().validate(data, {'Example'})

    def test_one_primary_first_and_notes_are_required(self):
        data = example(); data['integrations']['Example']['links'][1]['primary'] = True
        with self.assertRaisesRegex(ValueError, 'primary'):
            generator().validate(data, {'Example'})
        data = example(); data['integrations']['Example']['links'][0]['note'] = ''
        with self.assertRaisesRegex(ValueError, 'note'):
            generator().validate(data, {'Example'})

    def test_url_controls_and_malformed_ports_are_rejected(self):
        for url in ('https://github.com/author/repo\x00suffix', 'https://github.com/author/repo\x7f', 'https://github.com:bad/author/repo', 'https://github.com:444/author/repo'):
            data = example(); data['integrations']['Example']['links'][1]['url'] = url
            with self.assertRaises(ValueError, msg=repr(url)):
                generator().validate(data, {'Example'})

    def test_progression_requires_explicit_branches(self):
        data = example(); data['integrations']['Example']['scope']['families'] = ['progression']
        with self.assertRaisesRegex(ValueError, 'progression'):
            generator().validate(data, {'Example'})
        data['integrations']['Example']['scope']['progression'] = ['cata']
        generator().validate(data, {'Example'})

    def test_advertised_client_scope_and_explicit_version_bounds_require_evidence(self):
        data = example(); del data['integrations']['Example']['scope']
        with self.assertRaisesRegex(ValueError, 'scope'):
            generator().validate(data, {'Example'})
        data = example(); data['integrations']['Example']['scope']['interfaceRanges'] = {'tbc': {'min': 20506, 'max': 20507}}
        with self.assertRaisesRegex(ValueError, 'evidence'):
            generator().validate(data, {'Example'})
        data['integrations']['Example']['scope']['interfaceRanges']['tbc']['evidence'] = ['Explicit publisher version bounds, not inferred from an older TOC.']
        generator().validate(data, {'Example'})

    def test_official_project_website_is_first_and_can_be_a_root_domain(self):
        data = example(); data['integrations']['Example']['links'].append(dict(provider='author', label='Official website', url='https://example.org/', primary=False, note='Official addon website.', families=[]))
        with self.assertRaisesRegex(ValueError, 'official website'):
            generator().validate(data, {'Example'})
        links = data['integrations']['Example']['links']
        links[0]['primary'] = False
        website = links.pop(); website['primary'] = True; links.insert(0, website)
        generator().validate(data, {'Example'})

    def test_generator_changes_only_owned_block_and_emits_valid_lua(self):
        g = generator(); data = example()
        source = "local providers={\n {'Example','Example','Description.'},\n}\n" + g.BEGIN + '\nold\n' + g.END + '\nreturn providers\n'
        result = g.build_output(source, data)
        self.assertTrue(result.startswith(source.split(g.BEGIN)[0]))
        self.assertTrue(result.endswith('\nreturn providers\n'))
        self.assertEqual(g.build_output(result, data), result)
        with tempfile.NamedTemporaryFile(suffix='.lua') as handle:
            handle.write(result.encode()); handle.flush()
            subprocess.run(['luac5.1', '-p', handle.name], check=True)


if __name__ == '__main__':
    unittest.main()
