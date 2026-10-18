#!/usr/bin/env python3
"""Check literal locale references; list long first-party prose for translation review."""
from pathlib import Path
import argparse
import json
import re
import sys

# Tokens retain position and Lua string values, skipping comments and whitespace.
TOKEN = re.compile(r'(?P<comment>--\[(?P<ceq>=*)\[.*?\](?P=ceq)\]|--[^\n]*)'
                   r'|(?P<long>\[(?P<eq>=*)\[.*?\](?P=eq)\])'
                   r'|(?P<string>"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')'
                   r'|(?P<word>[A-Za-z_][A-Za-z_0-9]*)|(?P<space>\s+)|(?P<other>.)', re.S)


def decode_string(text):
    if text.startswith('['):
        match = re.match(r'\[(=*)\[', text)
        n = len(match.group(0))
        return text[n:-n].lstrip('\n')
    escapes = {'a': '\a', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r', 't': '\t', 'v': '\v'}
    return re.sub(r'\\(\d{1,3}|\r?\n|.)', lambda m: chr(int(m[1])) if m[1].isdigit()
                  else escapes.get(m[1], m[1]), text[1:-1])


def tokens(source):
    return [(m.lastgroup, m.group(), source.count('\n', 0, m.start()) + 1)
            for m in TOKEN.finditer(source) if m.lastgroup not in ('space', 'comment')]


def references(source):
    ts = tokens(source)
    for i in range(len(ts) - 3):
        if ts[i][1] == 'L' and ts[i+1][1] == '[' and ts[i+2][0] in ('string', 'long') and ts[i+3][1] == ']':
            yield decode_string(ts[i+2][1]), ts[i][2]


def sources(root):
    excluded = {'Libs', 'tests', 'docs', 'work', 'Web'}
    return sorted(p for p in root.rglob('*.lua')
                  if not any(part.startswith('.') or part in excluded for part in p.relative_to(root).parts)
                  and p.name != 'template.lua')


def check(root):
    known = {key for key, _ in references((root / 'Locales/enUS.lua').read_text())}
    issues = []
    for path in sources(root):
        if 'Locales' in path.relative_to(root).parts:
            continue
        for key, line in references(path.read_text()):
            if key not in known:
                issues.append(f'{path.relative_to(root)}:{line}: missing enUS key {key!r}')
    return issues


def inventory(root):
    items = []
    for path in sources(root):
        if 'Locales' in path.relative_to(root).parts:
            continue
        source = path.read_text()
        ts = tokens(source)
        for i, (kind, text, line) in enumerate(ts):
            if kind not in ('string', 'long'):
                continue
            value = decode_string(text)
            is_key = i >= 2 and ts[i-2][1] == 'L' and ts[i-1][1] == '['
            if not is_key and len(value) >= 50 and len(value.split()) >= 7:
                items.append({'file': str(path.relative_to(root)), 'line': line, 'text': value})
    return {'scope': 'Heuristic long raw-string candidates, not a complete translation inventory; review fragments and dynamic keys separately.',
            'candidates': items}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, help='explicitly write raw-prose review inventory')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    issues = check(root)
    for issue in issues:
        print(issue)
    if args.inventory:
        args.inventory.write_text(json.dumps(inventory(root), indent=2) + '\n')
    print(f'Literal localization references: {len(issues)} missing keys')
    return bool(issues)


if __name__ == '__main__':
    sys.exit(main())
