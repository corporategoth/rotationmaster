# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
"""Guard the single publisher for mirrored addon releases."""
import hashlib
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]


class ReleaseRouting(unittest.TestCase):
    @staticmethod
    def archive(content, level):
        out = io.BytesIO()
        with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=level) as z:
            z.writestr('RotationMaster/test.lua', content)
        return out.getvalue()

    def github_step(self, existing=False, digest=None, prerelease='true', existing_zip=None):
        with tempfile.TemporaryDirectory(prefix='rm-release-routing-') as tmp:
            root = Path(tmp)
            (root / '.release').mkdir()
            archive = root / '.release/RotationMaster-2.0.0-beta.1.zip'
            archive.write_bytes(self.archive(b'checked content' * 500, 9) if existing_zip else b'checked archive')
            checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
            (root / '.release/package.sha256').write_text(f'{checksum}  .release/{archive.name}\n')
            (root / 'release-notes-github.md').write_text('notes\n')
            fake = root / 'gh'
            fake.write_text(f'''#!{sys.executable}
import json, os, pathlib, sys
args = sys.argv[1:]
state = pathlib.Path(os.environ['FAKE_STATE'])
log = pathlib.Path(os.environ['FAKE_LOG'])
with log.open('a') as out: out.write(' '.join(args) + '\\n')
if args[:2] == ['release', 'view']:
    if not state.exists(): raise SystemExit(1)
    if '--json' in args:
        asset = os.environ.get('FAKE_DIGEST', '')
        print(json.dumps({{'assets': [{{'name': 'RotationMaster-2.0.0-beta.1.zip', 'digest': asset}}] if asset else []}}))
elif args[:2] == ['release', 'create']:
    state.touch()
elif args[:2] == ['release', 'download']:
    import shutil
    source = os.environ.get('FAKE_DOWNLOAD')
    if not source: raise SystemExit(1)
    target = pathlib.Path(args[args.index('--dir') + 1])
    target.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target / 'RotationMaster-2.0.0-beta.1.zip')
''')
            fake.chmod(0o755)
            state, log = root / 'exists', root / 'calls'
            if existing:
                state.touch()
            download = root / 'existing.zip'
            if existing_zip:
                download.write_bytes(existing_zip)
            workflow = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
            block = workflow.split('      - name: Publish GitHub release\n', 1)[1].split('        run: |\n', 1)[1]
            block = block.split('      - name:', 1)[0]
            script = '\n'.join(line[10:] for line in block.splitlines()) + '\n'
            env = {**os.environ, 'PATH': str(root) + os.pathsep + os.environ['PATH'],
                   'TAG': '2.0.0-beta.1', 'GITHUB_REPOSITORY': 'owner/repo', 'PRERELEASE': prerelease,
                   'FAKE_STATE': str(state), 'FAKE_LOG': str(log), 'FAKE_DIGEST': digest or '',
                   'FAKE_DOWNLOAD': str(download) if existing_zip else ''}
            result = subprocess.run(['bash', '-c', script], cwd=root, env=env, capture_output=True, text=True)
            if existing_zip and result.returncode == 0:
                self.assertEqual(archive.read_bytes(), existing_zip)
                self.assertEqual((root / '.release/package.sha256').read_text(),
                                 f'{hashlib.sha256(existing_zip).hexdigest()}  .release/{archive.name}\n')
            return result, log.read_text(), checksum

    def test_github_release_creates_prerelease_with_checked_zip(self):
        result, calls, _ = self.github_step()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('release create 2.0.0-beta.1', calls)
        self.assertIn('--prerelease', calls)
        self.assertIn('release upload 2.0.0-beta.1', calls)

    def test_github_release_never_replaces_a_different_asset(self):
        result, calls, _ = self.github_step(existing=True, digest='sha256:not-the-checked-zip')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Existing release asset differs', result.stderr)
        self.assertNotIn('release upload', calls)

    def test_github_release_keeps_an_identical_existing_asset(self):
        digest = 'sha256:' + hashlib.sha256(b'checked archive').hexdigest()
        result, calls, _ = self.github_step(existing=True, digest=digest)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('release create', calls)
        self.assertNotIn('release upload', calls)

    def test_github_release_reuses_existing_zip_when_contents_match(self):
        previous = self.archive(b'checked content' * 500, 1)
        result, calls, _ = self.github_step(existing=True, digest='sha256:' + hashlib.sha256(previous).hexdigest(),
                                             existing_zip=previous)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('release download', calls)
        self.assertIn('Equivalent release asset', result.stdout)
        self.assertNotIn('release upload', calls)

    def test_github_release_refuses_zip_with_different_contents(self):
        previous = self.archive(b'not the same content', 1)
        result, calls, _ = self.github_step(existing=True, digest='sha256:' + hashlib.sha256(previous).hexdigest(),
                                             existing_zip=previous)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Existing release asset differs', result.stderr)
        self.assertNotIn('release upload', calls)

    def test_github_owns_site_uploads(self):
        workflow = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
        self.assertIn('tags:', workflow)
        self.assertIn('needs: [static, tests]', workflow)
        self.assertIn('name: Upload to addon sites', workflow)
        for name in ('CF_API_KEY', 'WAGO_API_TOKEN', 'WOWI_API_TOKEN'):
            self.assertIn('secrets.' + name, workflow)
        self.assertNotIn('GITHUB_OAUTH:', workflow)
        self.assertIn('release_plan.py', workflow)
        self.assertIn('package_release.py --tag "${TAG}" --check', workflow)
        self.assertIn('sha256sum -c .release/package.sha256', workflow)
        self.assertIn('"${args[@]}" -c -z -o', workflow)
        self.assertIn('name: Publish GitHub release', workflow)
        self.assertIn('gh release upload', workflow)
        self.assertIn('--prerelease', workflow)

    def test_gitea_cannot_upload_addon_sites(self):
        workflow = (ROOT / '.gitea/workflows/release.yml').read_text(encoding='utf-8')
        for name in ('CF_API_KEY', 'WAGO_API_TOKEN', 'WOWI_API_TOKEN'):
            self.assertNotIn('secrets.' + name, workflow)
        self.assertIn('gitea_release.py', workflow)
        self.assertNotIn('name: Upload to addon sites', workflow)
        self.assertNotIn('Upload to CurseForge, Wago and WoWInterface', workflow)


if __name__ == '__main__':
    unittest.main()
