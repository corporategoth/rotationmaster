#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Decide what a release of a tag does, and say it before anything is uploaded.

  python3 tools/release_plan.py --tag 2.0.0-beta.1 [--dry-run] [--wowi-beta] [--allow-missing-tokens]

Reads which credentials are present from the environment (CF_API_KEY, WOWI_API_TOKEN, WAGO_API_TOKEN: only
whether each is non-empty; values are never read into output) and prints key=value lines for the workflow:

  type         release | beta | alpha                 (from the tag name, as the packager decides)
  prerelease   true | false                           (the Gitea release flag)
  sites        space-separated sites that will receive the file: curseforge wago wowinterface
  packager     arguments for tools/vendor/bigwigs-packager/release.sh

Rules:
  - every tag goes to CurseForge and Wago, as release, beta or alpha files (the packager sets the type from the tag);
  - WoWInterface has no beta channel: a beta or alpha tag is not uploaded there unless --wowi-beta
    (repository variable WOWI_UPLOAD_BETA=true), because it would become the current download for everyone;
  - a site that should receive the file but has no credential fails the plan, so a release can never silently
    skip a site; --allow-missing-tokens turns that into a warning and skips the site;
  - --dry-run builds the package and uploads nothing (the packager's -d).
GitHub Actions publishes to addon sites without passing a GitHub release credential to the packager; the Gitea
release is mirrored separately.
"""
import argparse
import os
import sys

SITES = (('curseforge', 'CF_API_KEY', '-p 0'), ('wago', 'WAGO_API_TOKEN', '-a 0'), ('wowinterface', 'WOWI_API_TOKEN', '-w 0'))


def release_type(tag):
    lowered = tag.lower()
    return 'alpha' if 'alpha' in lowered else 'beta' if 'beta' in lowered else 'release'


def plan(tag, environ, dry_run=False, wowi_beta=False, allow_missing=False):
    kind = release_type(tag)
    wanted = {'curseforge': True, 'wago': True, 'wowinterface': kind == 'release' or wowi_beta}
    sites, flags, problems, notes = [], ['-d'] if dry_run else [], [], []
    for site, variable, skip_flag in SITES:
        if not wanted[site]:
            flags.append(skip_flag)
            notes.append(f'{site}: not uploaded for a {kind} tag' + ('' if site != 'wowinterface' else ' (no beta channel there; set WOWI_UPLOAD_BETA=true to upload anyway)'))
        elif dry_run:
            notes.append(f'{site}: would be uploaded (dry run)')
        elif environ.get(variable):
            sites.append(site)
            notes.append(f'{site}: will be uploaded ({variable} is set)')
        elif allow_missing:
            flags.append(skip_flag)
            notes.append(f'{site}: SKIPPED, {variable} is not set (--allow-missing-tokens)')
        else:
            problems.append(f'{site}: {variable} is not set; add it under repository Settings > Actions > Secrets')
    if dry_run:
        sites = [s for s, _, _ in SITES if wanted[s]]
    return {'type': kind, 'prerelease': 'false' if kind == 'release' else 'true', 'sites': sites,
            'packager': ' '.join(['-u', '-e', '-l', *flags]).strip(), 'notes': notes, 'problems': problems}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--wowi-beta', action='store_true', help='Upload beta and alpha tags to WoWInterface too.')
    parser.add_argument('--allow-missing-tokens', action='store_true')
    args = parser.parse_args(argv)
    result = plan(args.tag, os.environ, args.dry_run, args.wowi_beta, args.allow_missing_tokens)
    for note in result['notes']:
        print(f'# {note}', file=sys.stderr)
    for problem in result['problems']:
        print(f'ERROR {problem}', file=sys.stderr)
    print(f'type={result["type"]}')
    print(f'prerelease={result["prerelease"]}')
    print(f'sites={" ".join(result["sites"])}')
    print(f'packager={result["packager"]}')
    return 1 if result['problems'] else 0


if __name__ == '__main__':
    sys.exit(main())
