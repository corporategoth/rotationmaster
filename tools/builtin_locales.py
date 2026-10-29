#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Validate each Built In rotation's direct ID-derived name and description in every language."""
import json
import re
from pathlib import Path
import locale_format as F

ROOT = Path(__file__).resolve().parents[1]
ASSIGNMENT = re.compile(r'^L\[(' + F.STRING + r')\] = (' + F.STRING + r')$')
ROTATION = re.compile(r"id='(rm\.[^']+)',revision=\d+")


def classes(root=ROOT):
    path = Path(root) / 'Locales/bundles.json'
    if not path.exists():
        return []
    manifest = json.loads(path.read_text(encoding='utf-8'))
    return [row for row in manifest.get('bundles', []) if row.get('kind') == 'builtin']


def read(path):
    entries = {}
    for line_number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        match = ASSIGNMENT.fullmatch(line)
        if match:
            key, text = map(F.decode_lua_string, match.groups())
            if key in entries:
                raise ValueError(f'{path}:{line_number}: duplicate key {key!r}')
            entries[key] = text
    return entries


def write_credit_header(path, credits):
    """Update only the translator credit on a directly edited Built In locale file."""
    text = path.read_text(encoding='utf-8')
    lines = text.splitlines()
    header = F.translators_header(credits)
    lines = [line for line in lines if not line.startswith('-- Translators: ')]
    lines.insert(1, header)
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def rotation_keys(module):
    ids = []
    for path in sorted(module.glob('*/*.lua')):
        source = path.read_text(encoding='utf-8')
        found = ROTATION.findall(source)
        if found and re.search(r'\b(?:nameKey|descriptionKey)\s*=', source):
            raise ValueError(f'{path}: Built In locale keys are derived from the rotation ID')
        ids.extend(found)
    if len(ids) != len(set(ids)):
        raise ValueError(f'{module}: duplicate Built In rotation ID')
    return {id + suffix for id in ids for suffix in ('.Name', '.Description')}


def check(root=ROOT):
    import locales
    issues = []
    credit_file = Path(root) / 'tools/locale_translators.json'
    credits = json.loads(credit_file.read_text(encoding='utf-8')) if credit_file.exists() else None
    for row in classes(root):
        module = Path(root) / 'Modules' / row['module']
        try:
            expected = rotation_keys(module)
            english = read(module / 'Locales/enUS.lua')
            for locale in ['enUS'] + F.LOCALES:
                path = module / 'Locales' / (locale + '.lua')
                entries = read(path)
                if locale != 'enUS' and credits is not None:
                    header = F.translators_header(credits.get(locale, {}).get(row['id'], []))
                    if header not in path.read_text(encoding='utf-8').splitlines():
                        issues.append(f'{path}: translator credit header does not match locale_translators.json')
                for key in sorted(expected - entries.keys()):
                    issues.append(f'{path}: missing {key}')
                for key in sorted(entries.keys() - expected):
                    issues.append(f'{path}: unused {key}')
                if locale != 'enUS':
                    for key in entries.keys() & english.keys():
                        for problem in locales.problems(key, english[key], entries[key]):
                            issues.append(f'{path}: {key}: {problem}')
            xml = (module / 'locales.xml').read_text(encoding='utf-8')
            listed = re.findall(r'<Script file="Locales\\([A-Za-z]{4})\.lua" />', xml)
            if listed != ['enUS'] + F.LOCALES:
                issues.append(f'{module}/locales.xml: expected English first, then each translation')
        except (OSError, ValueError) as error:
            issues.append(str(error))
    return issues


if __name__ == '__main__':
    problems = check()
    for problem in problems:
        print(problem)
    print(f'Built In locale checks: {len(problems)} issues')
    raise SystemExit(bool(problems))
