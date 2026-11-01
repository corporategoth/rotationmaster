# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""The Discord announcement carries the notes, stays within embed limits and never pings."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import discord_announce  # noqa: E402

URL = 'https://example.invalid/releases/tag/2.0.0-beta.2'


class DiscordAnnounce(unittest.TestCase):
    def test_short_notes_are_sent_whole(self):
        payload = discord_announce.build_payload('2.0.0-beta.2', '## Highlights\n- One\n', URL)
        embed = payload['embeds'][0]
        self.assertEqual(embed['description'], '## Highlights\n- One')
        self.assertEqual(embed['url'], URL)
        self.assertIn('test release', embed['title'])
        self.assertEqual(payload['allowed_mentions'], {'parse': []})

    def test_long_notes_are_cut_at_a_line_with_a_pointer(self):
        notes = '\n'.join(f'- line {n} ' + 'x' * 60 for n in range(200))
        description = discord_announce.build_payload('2.0.0', notes, URL)['embeds'][0]['description']
        self.assertLessEqual(len(description), 4096)
        self.assertTrue(description.endswith(f'[full release notes]({URL})'))
        self.assertNotIn('test release', discord_announce.build_payload('2.0.0', 'x', URL)['embeds'][0]['title'])


if __name__ == '__main__':
    unittest.main()
