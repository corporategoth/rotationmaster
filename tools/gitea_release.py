#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Create or update the Gitea release for a tag and attach the package, using only the standard library.

  python3 tools/gitea_release.py --tag 2.0.0-beta.1 --notes notes.md --asset .release/RotationMaster-2.0.0-beta.1.zip --prerelease

Environment (set by Gitea Actions): GITHUB_SERVER_URL and GITHUB_REPOSITORY locate the repository, and a token
in GITEA_TOKEN, RELEASE_TOKEN or GITHUB_TOKEN authorizes the call (the first one that is set). --api-url and
--repo override the first two. The token is sent only in the Authorization header and never printed.

Safe to run again for the same tag: an existing release is updated (notes, prerelease flag) and an asset of the same
name is replaced. Nothing here touches GitHub: the repository is a push mirror and receives the release through
Gitea's own mirroring, never from this script.
"""
import argparse
import json
import mimetypes
import os
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid


class ApiError(Exception):
    pass


def request(method, url, token, body=None, content_type='application/json'):
    data = None
    headers = {'Authorization': f'token {token}', 'Accept': 'application/json'}
    if body is not None:
        data = body if isinstance(body, bytes) else json.dumps(body).encode('utf-8')
        headers['Content-Type'] = content_type
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            raw = response.read()
            return response.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as error:
        detail = error.read().decode('utf-8', 'replace')[:300]
        error.close()
        if error.code == 404 and method == 'GET':
            return 404, None
        raise ApiError(f'{method} {url} -> HTTP {error.code}: {detail}') from None
    except urllib.error.URLError as error:
        raise ApiError(f'{method} {url} failed: {error.reason}') from None


def multipart(field, filename, payload):
    boundary = uuid.uuid4().hex
    kind = mimetypes.guess_type(filename)[0] or 'application/octet-stream'
    head = (f'--{boundary}\r\nContent-Disposition: form-data; name="{field}"; filename="{filename}"\r\n'
            f'Content-Type: {kind}\r\n\r\n').encode()
    return head + payload + f'\r\n--{boundary}--\r\n'.encode(), f'multipart/form-data; boundary={boundary}'


def publish(api, repo, token, tag, name, notes, prerelease, assets, dry_run=False, log=print):
    base = f'{api}/api/v1/repos/{repo}'
    quoted = urllib.parse.quote(tag, safe='')
    status, release = request('GET', f'{base}/releases/tags/{quoted}', token)
    payload = {'tag_name': tag, 'name': name, 'body': notes, 'draft': False, 'prerelease': prerelease}
    if dry_run:
        log(f'dry run: would {"update" if release else "create"} release {tag} (prerelease={prerelease}) with {len(assets)} asset(s)')
        return None
    if release:
        _, release = request('PATCH', f'{base}/releases/{release["id"]}', token, payload)
        log(f'updated release {tag} (id {release["id"]})')
    else:
        _, release = request('POST', f'{base}/releases', token, payload)
        log(f'created release {tag} (id {release["id"]})')
    _, existing = request('GET', f'{base}/releases/{release["id"]}/assets', token)
    for asset in assets:
        path = Path(asset)
        for old in existing or []:
            if old.get('name') == path.name:
                request('DELETE', f'{base}/releases/{release["id"]}/assets/{old["id"]}', token)
                log(f'replaced existing asset {path.name}')
        body, content_type = multipart('attachment', path.name, path.read_bytes())
        _, created = request('POST', f'{base}/releases/{release["id"]}/assets?name={urllib.parse.quote(path.name)}', token,
                             body, content_type)
        log(f'attached {path.name} ({path.stat().st_size // 1024} KB)')
    return release


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--name', help='Release title (default: the tag).')
    parser.add_argument('--notes', type=Path, required=True, help='Markdown file for the release body.')
    parser.add_argument('--asset', action='append', default=[], type=Path, help='File to attach (repeatable).')
    parser.add_argument('--prerelease', action='store_true')
    parser.add_argument('--api-url', default=os.environ.get('GITHUB_SERVER_URL'))
    parser.add_argument('--repo', default=os.environ.get('GITHUB_REPOSITORY'))
    parser.add_argument('--dry-run', action='store_true', help='Look the release up and say what would happen.')
    args = parser.parse_args(argv)
    token = next((os.environ[v] for v in ('GITEA_TOKEN', 'RELEASE_TOKEN', 'GITHUB_TOKEN') if os.environ.get(v)), None)
    if not (args.api_url and args.repo and token):
        print('gitea_release: need GITHUB_SERVER_URL, GITHUB_REPOSITORY and a token (GITEA_TOKEN, RELEASE_TOKEN or GITHUB_TOKEN)', file=sys.stderr)
        return 2
    for asset in args.asset:
        if not asset.is_file():
            print(f'gitea_release: asset not found: {asset}', file=sys.stderr)
            return 2
    try:
        publish(args.api_url.rstrip('/'), args.repo, token, args.tag, args.name or args.tag,
                args.notes.read_text(encoding='utf-8'), args.prerelease, args.asset, args.dry_run)
    except ApiError as error:
        print(f'gitea_release: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
