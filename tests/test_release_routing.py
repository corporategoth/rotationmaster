# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.
"""Guard the single publisher for mirrored addon releases."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ReleaseRouting(unittest.TestCase):
    def test_github_owns_site_uploads(self):
        workflow = (ROOT / '.github/workflows/release.yml').read_text(encoding='utf-8')
        self.assertIn('tags:', workflow)
        self.assertIn('needs: [static, tests]', workflow)
        self.assertIn('name: Upload to addon sites', workflow)
        for name in ('CF_API_KEY', 'WAGO_API_TOKEN', 'WOWI_API_TOKEN'):
            self.assertIn('secrets.' + name, workflow)
        self.assertNotIn('GITHUB_OAUTH:', workflow)
        self.assertIn('release_plan.py', workflow)
        self.assertIn('check-zip', workflow)

    def test_gitea_cannot_upload_addon_sites(self):
        workflow = (ROOT / '.gitea/workflows/release.yml').read_text(encoding='utf-8')
        for name in ('CF_API_KEY', 'WAGO_API_TOKEN', 'WOWI_API_TOKEN'):
            self.assertNotIn('secrets.' + name, workflow)
        self.assertIn('gitea_release.py', workflow)
        self.assertNotIn('name: Upload to addon sites', workflow)
        self.assertNotIn('Upload to CurseForge, Wago and WoWInterface', workflow)


if __name__ == '__main__':
    unittest.main()
