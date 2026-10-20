#!/usr/bin/env python3
"""Validate five-host research coverage and emit the offline addon link catalog."""
import argparse
from datetime import date
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
BEGIN = '-- BEGIN GENERATED INTEGRATION PROJECTS'
END = '-- END GENERATED INTEGRATION PROJECTS'
CHANNELS = {'curseforge', 'wowinterface', 'wago', 'wowuphub', 'github'}
HOSTS = {'curseforge': {'curseforge.com', 'www.curseforge.com'},
         'wowinterface': {'wowinterface.com', 'www.wowinterface.com'},
         'wago': {'addons.wago.io'}, 'wowuphub': {'wowup.io', 'www.wowup.io'},
         'github': {'github.com'}}
FAMILIES = {'retail', 'forever', 'era', 'progression', 'tbc'}


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def supported_ids(source):
    match = re.search(r'local providers=\{\n(.*?)\n\}', source, re.S)
    if not match:
        raise ValueError('supported integration identities declaration missing')
    ids = re.findall(r"^\s*\{'([^']+)'", match[1], re.M)
    if not ids or len(ids) != len(set(ids)):
        raise ValueError('supported integration identities empty or duplicated')
    return set(ids)


def validate(data, ids):
    date.fromisoformat(data['checked'])
    records = data['integrations']
    if set(records) != set(ids):
        raise ValueError('integration identities do not match the supported catalog')
    for identity, record in records.items():
        coverage, links = record['coverage'], record['links']
        scope = record.get('scope')
        if not isinstance(scope, dict) or not isinstance(scope.get('families'), list) or not set(scope['families']) <= FAMILIES:
            raise ValueError(f'{identity}: declared client scope required')
        if not scope.get('evidence') or not all(nonempty(item) for item in scope['evidence']):
            raise ValueError(f'{identity}: client scope evidence required')
        if not scope['families'] and scope.get('unknown') is not True:
            raise ValueError(f'{identity}: unknown scope must be explicit')
        if 'progression' in scope['families'] and not scope.get('progression'):
            raise ValueError(f'{identity}: explicit progression branches required')
        if not set(scope.get('progression', [])) <= {'wrath', 'cata', 'mists'}:
            raise ValueError(f'{identity}: invalid progression scope')
        for family, bounds in scope.get('interfaceRanges', {}).items():
            if family not in scope['families'] or not bounds.get('evidence') or not all(nonempty(item) for item in bounds['evidence']):
                raise ValueError(f'{identity}: explicit interface bounds require family evidence')
            low, high = bounds.get('min', 0), bounds.get('max', 999999)
            if type(low) is not int or type(high) is not int or not 0 <= low <= high <= 999999:
                raise ValueError(f'{identity}: invalid interface bounds')
        if set(coverage) != CHANNELS:
            raise ValueError(f'{identity}: all five provider channels must be checked')
        if not 1 <= len(links) <= 32:
            raise ValueError(f'{identity}: expected 1..32 links; never silently truncate')
        seen, linked = set(), set()
        for link in links:
            provider, url = link['provider'], link['url']
            if provider not in CHANNELS | {'author'}:
                raise ValueError(f'{identity}: invalid provider')
            parsed = urlsplit(url)
            if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.port not in (None, 443) or re.search(r'[\s|\x00-\x1f\x7f]', url):
                raise ValueError(f'{identity}: invalid project URL')
            if provider in HOSTS and parsed.hostname not in HOSTS[provider]:
                raise ValueError(f'{identity}: provider host mismatch')
            if provider != 'author' and (len(parsed.path.strip('/').split('/')) < (2 if provider == 'github' else 1) or not parsed.path.strip('/')):
                raise ValueError(f'{identity}: project URL must identify an addon, not a provider homepage')
            if url in seen:
                raise ValueError(f'{identity}: duplicate project URL')
            seen.add(url); linked.add(provider)
            if type(link['primary']) is not bool:
                raise ValueError(f'{identity}: primary must be boolean')
            for field in ('label', 'note'):
                if not nonempty(link[field]) or any(ord(c) < 32 for c in link[field]):
                    raise ValueError(f'{identity}: nonempty printable {field} required')
            if not isinstance(link['families'], list) or not set(link['families']) <= FAMILIES or len(link['families']) != len(set(link['families'])):
                raise ValueError(f'{identity}: invalid edition evidence')
        if sum(link['primary'] for link in links) != 1 or links[0]['primary'] is not True:
            raise ValueError(f'{identity}: exactly one primary link, listed first')
        for provider, proof in coverage.items():
            if proof['status'] not in {'verified', 'not_found', 'unverified'}:
                raise ValueError(f'{identity}: invalid coverage status')
            if not nonempty(proof.get('query')) or not isinstance(proof.get('evidence'), list) or not proof['evidence'] or not all(nonempty(item) for item in proof['evidence']):
                raise ValueError(f'{identity}/{provider}: record actual search/source evidence')
            if proof['status'] == 'verified' and provider not in linked:
                raise ValueError(f'{identity}/{provider}: verified coverage has no project link')
            if proof['status'] == 'not_found' and provider in linked:
                raise ValueError(f'{identity}/{provider}: found URL contradicts not_found')


def lua(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if type(value) is bool:
        return 'true' if value else 'false'
    if type(value) is int:
        return str(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(item) for item in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(key) + ']=' + lua(item) for key, item in value.items()) + '}'
    raise ValueError('unsupported generated field type')


def render_projects(data):
    rows = [BEGIN, '-- Generated by tools/generate_integration_projects.py; publisher evidence checked ' + data['checked'] + '.', 'local projects={']
    for identity, record in data['integrations'].items():
        fields = [{key: entry[key] for key in ('provider', 'label', 'url', 'primary', 'note', 'families')} for entry in record['links']]
        rows.append(' [' + lua(identity) + ']=' + lua(fields) + ',')
    rows += ['}', 'local scopes={']
    for identity, record in data['integrations'].items():
        scope = {key: value for key, value in record['scope'].items() if key != 'evidence'}
        scope['interfaceRanges'] = {family: {key: value for key, value in bounds.items() if key != 'evidence'} for family, bounds in scope.get('interfaceRanges', {}).items()}
        rows.append(' [' + lua(identity) + ']=' + lua(scope) + ',')
    return '\n'.join(rows + ['}', END])


def build_output(source, data):
    validate(data, supported_ids(source))
    if source.count(BEGIN) != 1 or source.count(END) != 1:
        raise ValueError('exactly one generated integration project block is required')
    start, end = source.index(BEGIN), source.index(END) + len(END)
    if start >= end:
        raise ValueError('invalid generated integration project block')
    return source[:start] + render_projects(data) + source[end:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    try:
        data = json.loads((ROOT / 'tools/integration_projects.json').read_text())
        path = ROOT / 'Integrations/catalog.lua'; source = path.read_text()
        output = build_output(source, data)
        if output != source:
            if args.write:
                path.write_text(output)
            else:
                raise ValueError('stale integration project catalog; run tools/generate_integration_projects.py --write')
        count = sum(len(record['links']) for record in data['integrations'].values())
        print(f'Integration projects: {len(data["integrations"])} addons, {count} links; all five provider searches recorded')
        return 0
    except (KeyError, TypeError, ValueError, OSError) as error:
        print('Integration project check: ' + str(error))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
