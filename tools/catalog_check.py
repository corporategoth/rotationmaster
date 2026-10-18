#!/usr/bin/env python3
"""Check literal locale definitions and references; inventory raw prose for translation review."""
from pathlib import Path
import argparse
import json
import re
import sys

# Tokens retain position and Lua string values, skipping comments and whitespace.
TOKEN = re.compile(r'(?P<comment>--\[(?P<ceq>=*)\[.*?\](?P=ceq)\]|--[^\n]*)'
                   r'|(?P<long>\[(?P<eq>=*)\[.*?\](?P=eq)\])'
                   r'|(?P<string>"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')'
                   r'|(?P<number>0[xX][0-9A-Fa-f]+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)'
                   r'|(?P<word>[A-Za-z_][A-Za-z_0-9]*)|(?P<space>\s+)|(?P<other>.)', re.S)


def decode_string(text):
    if text.startswith('['):
        match = re.match(r'\[(=*)\[', text)
        n = len(match.group(0))
        value = re.sub(r'\r\n|\n\r|\r', '\n', text[n:-n])
        return value[1:] if value.startswith('\n') else value
    escapes = {'a': '\a', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r', 't': '\t', 'v': '\v'}
    return re.sub(r'\\(\d{1,3}|\r?\n|.)', lambda m: chr(int(m[1])) if m[1].isdigit()
                  else escapes.get(m[1], m[1]), text[1:-1])


def tokens(source):
    return [(m.lastgroup, m.group(), source.count('\n', 0, m.start()) + 1)
            for m in TOKEN.finditer(source) if m.lastgroup not in ('space', 'comment')]


def literal_sites(source):
    """Literal L keys with assignment/read context; this is not a Lua evaluator."""
    ts = tokens(source)
    for i in range(len(ts) - 3):
        if ts[i][1] == 'L' and ts[i+1][1] == '[' and ts[i+2][0] in ('string', 'long') and ts[i+3][1] == ']':
            assigned = i+5 < len(ts) and ts[i+4][1] == '=' and ts[i+5][1] != '='
            yield decode_string(ts[i+2][1]), ts[i][2], assigned, ts[i+5:i+10] if assigned else None


def references(source):
    for key, line, _, _ in literal_sites(source):
        yield key, line


def invalid_base_value(value):
    # AceLocale's base entries are strings or true. Infer only scalar literals
    # and empty constructors/functions; nontrivial Lua expressions need review.
    kind, text, _ = value[0]
    offset = 1 if text == '-' and len(value) > 1 and value[1][0] == 'number' else 0
    invalid = text in {'nil', 'false'} or kind == 'number' or offset == 1
    if text == '{' and len(value) > 1 and value[1][1] == '}':
        offset, invalid = 1, True
    elif text == 'function' and [token[1] for token in value[1:4]] == ['(', ')', 'end']:
        offset, invalid = 3, True
    if invalid:
        following = value[offset+1][1] if offset+1 < len(value) else None
        # A literal can begin a computed string expression (false or "text",
        # 17 .. " suffix", {} and "text"). Do not infer the expression's type.
        operators = {'and', 'or', '+', '-', '*', '/', '%', '^', '.', '<', '>', '=', '~', '(', '[', ':'}
        return following not in operators
    return False


def sources(root):
    excluded = {'Libs', 'tests', 'docs', 'work', 'Web'}
    return sorted(p for p in root.rglob('*.lua')
                  if not any(part.startswith('.') or part in excluded for part in p.relative_to(root).parts)
                  and p.name != 'template.lua')


def check(root):
    base = list(literal_sites((root / 'Locales/enUS.lua').read_text()))
    known = {key for key, _, assigned, value in base if assigned and not invalid_base_value(value)}
    issues = []
    for key, line, assigned, value in base:
        if assigned and invalid_base_value(value):
            issues.append(f'Locales/enUS.lua:{line}: invalid enUS value for {key!r}')
        elif not assigned and key not in known:
            issues.append(f'Locales/enUS.lua:{line}: missing enUS key {key!r}')
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
    print(f'Literal localization checks: {len(issues)} issues')
    return bool(issues)


if __name__ == '__main__':
    sys.exit(main())
