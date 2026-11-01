#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Announce a release on Discord with its release notes, not just a link.

  python3 tools/discord_announce.py --tag 2.0.0-beta.2 --notes release-notes-github.md --url URL [--dry-run]

The webhook URL comes from DISCORD_WEBHOOK_URL (a plain Discord webhook, not its /github endpoint, which renders only
the release title and link). Without it nothing is sent. The notes are cut at a line boundary to fit one embed, with a
pointer to the full release page.
"""
import argparse
import json
import os
from pathlib import Path
import sys
import urllib.request

LIMIT = 3800  # Discord caps an embed description at 4096 characters; leave room for the pointer line.


def build_payload(tag, notes, url):
    prerelease = any(word in tag.lower() for word in ('alpha', 'beta'))
    body = notes.strip()
    if len(body) > LIMIT:
        cut = body[:LIMIT].rsplit('\n', 1)[0].rstrip()
        body = f'{cut}\n\n...and more: [full release notes]({url})'
    return {
        'username': 'Rotation Master',
        'embeds': [{
            'title': f'Rotation Master {tag}' + (' (test release)' if prerelease else ''),
            'url': url,
            'description': body,
            'color': 0xE67E22 if prerelease else 0x2ECC71,
        }],
        'allowed_mentions': {'parse': []},
    }


def post(webhook, payload):
    request = urllib.request.Request(
        webhook, data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json', 'User-Agent': 'RotationMaster-release-announcer'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.status


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[2])
    parser.add_argument('--tag', required=True)
    parser.add_argument('--notes', required=True, type=Path)
    parser.add_argument('--url', required=True)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args(argv)
    payload = build_payload(args.tag, args.notes.read_text(encoding='utf-8'), args.url)
    webhook = os.environ.get('DISCORD_WEBHOOK_URL', '')
    if args.dry_run or not webhook:
        print(json.dumps(payload, indent=2) if args.dry_run else 'DISCORD_WEBHOOK_URL is not set; nothing announced.')
        return 0
    print(f'Discord answered {post(webhook, payload)}.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
