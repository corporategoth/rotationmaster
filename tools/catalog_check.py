#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

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
    # The line of each token is counted incrementally from the previous one: counting from the start of the file for
    # every token is quadratic, which made the catalog gate take over a minute on the shipped locales.
    found, line, position = [], 1, 0
    for m in TOKEN.finditer(source):
        line += source.count('\n', position, m.start())
        position = m.start()
        if m.lastgroup not in ('space', 'comment'):
            found.append((m.lastgroup, m.group(), line))
    return found


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


LOCALE_NAMES = {'enUS', 'deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW'}


def bundle_modules(root):
    """The add-on folders of the load-on-demand text bundles (Locales/bundles.json), if the repository has any."""
    manifest = Path(root) / 'Locales/bundles.json'
    if not manifest.exists():
        return []
    return [row['module'] for row in json.loads(manifest.read_text(encoding='utf-8')).get('bundles', [])]


def bundle_english(root):
    """Paths of each text bundle's enUS.lua, which define keys just as Locales/enUS.lua does."""
    return [Path(root) / 'Modules' / module / 'enUS.lua' for module in bundle_modules(root)
            if (Path(root) / 'Modules' / module / 'enUS.lua').exists()]


def is_bundle_locale_file(root, path):
    relative = path.relative_to(root).parts
    return len(relative) == 3 and relative[0] == 'Modules' and relative[1] in bundle_modules(root) and path.stem in LOCALE_NAMES


def sources(root):
    """Lua sources that read keys. Locale files (the main ones and each text bundle's) define them and are not listed."""
    excluded = {'Libs', 'tests', 'docs', 'work'}
    root = Path(root)
    return sorted(p for p in root.rglob('*.lua')
                  if not any(part.startswith('.') or part in excluded for part in p.relative_to(root).parts)
                  and p.name != 'template.lua' and not is_bundle_locale_file(root, p))


def check(root):
    base = list(literal_sites((root / 'Locales/enUS.lua').read_text()))
    known = {key for key, _, assigned, value in base if assigned and not invalid_base_value(value)}
    issues = []
    for key, line, assigned, value in base:
        if assigned and invalid_base_value(value):
            issues.append(f'Locales/enUS.lua:{line}: invalid enUS value for {key!r}')
        elif not assigned and key not in known:
            issues.append(f'Locales/enUS.lua:{line}: missing enUS key {key!r}')
    # A key a text bundle holds reads exactly like a main one; it must be defined once, in one catalog.
    for path in bundle_english(root):
        label = path.relative_to(root).as_posix()
        entries = list(literal_sites(path.read_text()))
        for key, line, assigned, value in entries:
            if assigned and invalid_base_value(value):
                issues.append(f'{label}:{line}: invalid enUS value for {key!r}')
            elif assigned and key in known:
                issues.append(f'{label}:{line}: {key!r} is also defined in Locales/enUS.lua')
        known |= {key for key, _, assigned, value in entries if assigned and not invalid_base_value(value)}
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


# Optional translation readiness checks. The existing check(root) API above is
# deliberately unchanged; these counts cover literal assignments, not all Lua.
FORMAT_KINDS = {'printf', 'summary', 'announcement', 'markup'}


def _literal_dictionary(source, first_write=False):
    entries, duplicates, conflicts, invalid, unchecked, true_keys = {}, [], [], [], [], set()
    declared = set()
    operators = {'and', 'or', '+', '-', '*', '/', '%', '^', '.', '<', '>', '=', '~', '(', '[', ':'}
    for key, line, assigned, rhs in literal_sites(source):
        if not assigned:
            continue
        declared.add(key)
        kind, text, _ = rhs[0]
        value = None
        if kind in ('string', 'long') or text == 'true':
            if len(rhs) == 1 or rhs[1][1] not in operators:
                value = key if text == 'true' else decode_string(text)
        if invalid_base_value(rhs):
            invalid.append((key, line))
        elif value is None:
            unchecked.append(key)
        if key in entries:
            duplicates.append(key)
            if value is not None and entries[key] is not None and entries[key] != value:
                conflicts.append((key, line))
        if not first_write or key not in entries:
            entries[key] = value
            true_keys.discard(key)
            if text == 'true' and value is not None:
                true_keys.add(key)
    return entries, declared, duplicates, conflicts, invalid, sorted(set(unchecked)), true_keys


def _computed_key_sites(source):
    ts = tokens(source)
    return sum(1 for i in range(len(ts)-3) if ts[i][1] == 'L' and ts[i+1][1] == '['
               and not (ts[i+2][0] in ('string', 'long') and ts[i+3][1] == ']'))


def _registration(source):
    """Read only an exact NewLocale(..., literalLocale, literalDefault) call."""
    ts = tokens(source)
    found = []
    for i in range(len(ts)-2):
        if ts[i][1] != 'NewLocale' or ts[i+1][1] != '(':
            continue
        args, arg, depth = [], [], 1
        for token in ts[i+2:]:
            text = token[1]
            if text == '(':
                depth += 1
            elif text == ')':
                depth -= 1
                if depth == 0:
                    args.append(arg)
                    break
            if text == ',' and depth == 1:
                args.append(arg); arg = []
            else:
                arg.append(token)
        if len(args) >= 2 and len(args[1]) == 1 and args[1][0][0] in ('string', 'long'):
            default = len(args) >= 3 and len(args[2]) == 1 and args[2][0][1] == 'true'
            found.append((decode_string(args[1][0][1]), default))
    return found


def _printf(text):
    directives, escaped, i = [], 0, 0
    while i < len(text):
        if text[i] != '%':
            i += 1; continue
        if text.startswith('%%', i):
            escaped += 1; i += 2; continue
        if re.match(r'%\d+\$', text[i:]):
            raise ValueError('positional printf syntax is unsupported by Lua 5.1')
        match = re.match(r'%[-+ #0]*\d*(?:\.\d*)?[cdiouxXeEfgGqs]', text[i:])
        if not match:
            raise ValueError('malformed or unsupported printf directive')
        directives.append(match.group()); i += len(match.group())
    return directives, escaped


def _summary(text):
    from collections import Counter
    slots, predicates, escapes, i = [], [], [], 0
    while i < len(text):
        if text.startswith('{{{{', i) or text.startswith('}}}}', i):
            escapes.append(text[i:i+4]); i += 4
        elif text.startswith('{{', i):
            end = text.find('}}', i+2)
            if end < 0:
                raise ValueError('unclosed summary predicate')
            body = text[i+2:end]; primary = body.startswith('!')
            if primary:
                body = body[1:]
            if not re.fullmatch(r'[^|{}]*\|[^|{}]*', body):
                raise ValueError('malformed summary predicate')
            predicates.append(primary); i = end+2
        elif text[i] == '{':
            end = text.find('}', i+1)
            name = text[i+1:end] if end >= 0 else ''
            if not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', name):
                raise ValueError('malformed summary slot')
            slots.append(name); i = end+1
        elif text[i] == '}':
            raise ValueError('unmatched summary brace')
        else:
            i += 1
    return Counter(slots), tuple(predicates), Counter(escapes)


def _announcement(text):
    from collections import Counter
    names = re.findall(r'\{\{([A-Za-z_][A-Za-z_0-9]*)\}\}', text)
    rest = re.sub(r'\{\{[A-Za-z_][A-Za-z_0-9]*\}\}', '', text)
    if '{{' in rest or '}}' in rest:
        raise ValueError('malformed announcement token')
    return Counter(names)


def _markup(text):
    """Protect WoW tokens/payloads; ordinary link captions remain human text."""
    result, i, link = [], 0, False
    while i < len(text):
        if text[i] != '|':
            i += 1; continue
        code = text[i:i+2]
        if code == '||':
            result.append(code); i += 2
        elif code == '|c':
            payload = text[i+2:i+10]
            if not re.fullmatch(r'[A-Fa-f0-9]{8}', payload):
                raise ValueError('malformed color payload')
            result.append(code+payload); i += 10
        elif code == '|r':
            result.append(code); i += 2
        elif code in ('|T', '|A', '|H'):
            if link and code == '|H':
                raise ValueError('nested hyperlink')
            closing = {'|T':'|t', '|A':'|a', '|H':'|h'}[code]
            end = text.find(closing, i+2)
            if end < 0:
                raise ValueError('unclosed markup payload')
            result.append(text[i:end+2]); i = end+2
            if code == '|H':
                link = True
        elif code == '|h' and link:
            result.append(code); link = False; i += 2
        elif code in ('|h', '|t', '|a'):
            raise ValueError('unmatched markup delimiter')
        elif len(code) == 2 and code[1].isalpha():
            raise ValueError('unsupported markup token '+code)
        else:
            # A standalone pipe is ordinary prose, not an invented WoW tag.
            i += 1
    if link:
        raise ValueError('unclosed hyperlink caption')
    return result


def _consumer_contracts(root):
    contracts = {}
    for path in sources(root):
        if 'Locales' in path.relative_to(root).parts:
            continue
        source = path.read_text()
        if 'format' not in source:
            continue
        ts = tokens(source)
        for i in range(len(ts)-8):
            if [t[1] for t in ts[i:i+6]] == ['string', '.', 'format', '(', 'L', '['] \
                    and ts[i+6][0] in ('string', 'long') and ts[i+7][1] == ']' and ts[i+8][1] in (',', ')'):
                contracts.setdefault(decode_string(ts[i+6][1]), set()).add('printf')
    return contracts


def locale_report(root, contracts=None, require_complete=False, english_reuse=None):
    """Report known literal coverage. No Lua execution or locale-list inference.

    Missing translations are allowed by default and remain explicit fallback
    gaps. Unknown/computed assignments are never certified as translated text.
    Contracts may classify keys as printf/summary/announcement/markup; help
    examples are not classified from their punctuation alone.
    """
    import xml.etree.ElementTree as ET
    root = Path(root)
    issues, locales, loaded = [], {}, []
    try:
        for node in ET.parse(root/'locales.xml').iter():
            ref = node.get('file')
            if ref:
                path = Path(ref.replace('\\', '/'))
                if path.is_absolute() or '..' in path.parts or path.parts[:1] != ('Locales',):
                    issues.append('locales.xml: unsupported locale path '+ref)
                else:
                    loaded.append(path.as_posix())
    except (OSError, ET.ParseError) as exc:
        issues.append('locales.xml: '+str(exc))
    if not loaded or loaded[0] != 'Locales/enUS.lua':
        issues.append('locales.xml: load enUS first for explicit fallback accounting')
    if len(loaded) != len(set(loaded)):
        issues.append('locales.xml: duplicate locale file')
    for path in sorted((root/'Locales').glob('*.lua')):
        if path.relative_to(root).as_posix() not in loaded:
            issues.append(str(path.relative_to(root))+': locale file not loaded')
    base_source = (root/'Locales/enUS.lua').read_text()
    base, _, _, _, _, _, _ = _literal_dictionary(base_source, True)
    known = {k for k, v in base.items() if v is not None}
    classified = _consumer_contracts(root)
    for key, kinds in (contracts or {}).items():
        if key not in base:
            issues.append('format contract: unknown English key '+repr(key))
        if not isinstance(kinds, list) or any(not isinstance(k, str) or k not in FORMAT_KINDS for k in kinds):
            issues.append('format contract: invalid kinds for '+repr(key)); continue
        classified.setdefault(key, set()).update(kinds)
    allowed_english = {}
    for code, keys in (english_reuse or {}).items():
        if not isinstance(keys, list) or any(not isinstance(k, str) or k not in base for k in keys):
            issues.append('English reuse policy: unknown or invalid keys for '+repr(code))
            continue
        allowed_english[code] = set(keys)
    signatures = {'printf':_printf, 'summary':_summary, 'announcement':_announcement, 'markup':_markup}
    computed = 0
    for name in dict.fromkeys(loaded):
        path = root/name
        if not path.is_file():
            issues.append(name+': missing locale file'); continue
        code = path.stem; source = path.read_text()
        registration = _registration(source)
        if registration != [(code, code == 'enUS')]:
            issues.append(name+': registration must match filename and only enUS may be default')
        values, declared, duplicates, conflicts, invalid, unchecked, true_keys = _literal_dictionary(source, code == 'enUS')
        computed += _computed_key_sites(source)
        for key, line in conflicts:
            issues.append(f'{name}:{line}: conflicting duplicate key {key!r}')
        for key, line in invalid:
            issues.append(f'{name}:{line}: invalid locale value for {key!r}')
        extra = sorted(declared - set(base))
        if code != 'enUS':
            for key in extra:
                issues.append(f'{name}: extra key {key!r}')
        missing = sorted(known-declared)
        english = sorted(k for k, v in values.items() if v is not None and k in known and v == base[k])
        key_reuse = sorted(k for k in true_keys if k in known and values[k] != base[k])
        translated = sorted(k for k, v in values.items() if v is not None and k in known and v != base[k] and k not in true_keys)
        intentional = sorted(set(english) & allowed_english.get(code, set()))
        complete = not missing and not unchecked and not invalid and not extra and not conflicts and not key_reuse and (code == 'enUS' or set(english) <= set(intentional))
        if require_complete and code != 'enUS' and not complete:
            issues.append(name+': incomplete literal translation coverage')
        locales[code] = {'file':name, 'explicit':sum(v is not None for v in values.values()),
                         'translated':translated, 'english_reuse':english, 'key_reuse':key_reuse,
                         'intentional_english':intentional, 'missing':missing,
                         'fallback':missing if code != 'enUS' else [], 'extra':extra,
                         'duplicates':duplicates, 'unchecked':unchecked, 'complete':complete}
        for key, kinds in classified.items():
            if key not in known or values.get(key) is None:
                continue
            for kind in sorted(kinds):
                try:
                    expected = signatures[kind](base[key])
                    actual = signatures[kind](values[key])
                    if expected != actual:
                        raise ValueError('signature differs from English')
                except ValueError as exc:
                    issues.append(f'{name}: {kind} contract for {key!r}: {exc}')
    targets = [x for code, x in locales.items() if code != 'enUS']
    for code in allowed_english:
        if code not in locales or code == 'enUS':
            issues.append('English reuse policy: no installed non-English locale '+repr(code))
    if require_complete and not targets:
        issues.append('No non-English locales installed; translation readiness is unverified')
    return {'scope':'Known literal-key coverage only; computed keys/values and unclassified consumers require runtime/manual review.',
            'issues':issues, 'base_keys':len(known), 'computed_key_sites':computed,
            'locales':locales, 'literal_complete':bool(targets) and not issues and all(x['complete'] for x in targets),
            'runtime_complete':None,
            'classified_keys':{k:sorted(v) for k, v in classified.items()}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, help='explicitly write raw-prose review inventory')
    parser.add_argument('--locales', action='store_true', help='check installed locale coverage and classified formats')
    parser.add_argument('--locale-report', type=Path, help='write explicit literal locale readiness JSON (implies --locales)')
    parser.add_argument('--contracts', type=Path, help='JSON English key to list of printf/summary/announcement/markup contracts')
    parser.add_argument('--allow-english', type=Path, help='JSON locale to intentionally unchanged English key list')
    parser.add_argument('--require-complete', action='store_true', help='fail incomplete literal coverage or unattested English reuse (implies --locales)')
    args = parser.parse_args()
    def policy(path):
        if path is None:
            return None
        try:
            value = json.loads(path.read_text())
            if not isinstance(value, dict):
                raise ValueError('expected a JSON object')
            return value
        except (OSError, ValueError) as exc:
            parser.error(str(path)+': '+str(exc))
    contracts, allowed = policy(args.contracts), policy(args.allow_english)
    root = Path(__file__).resolve().parents[1]
    issues = check(root)
    if args.locales or args.locale_report or args.contracts or args.allow_english or args.require_complete:
        report = locale_report(root, contracts, args.require_complete, allowed)
        issues.extend(report['issues'])
        if args.locale_report:
            args.locale_report.write_text(json.dumps(report, indent=2, ensure_ascii=False)+'\n')
        print(report['scope'])
        for code, row in report['locales'].items():
            print(f"{code}: explicit={row['explicit']}; translated={len(row['translated'])}; "
                  f"English reuse={len(row['english_reuse'])}; lookup-key reuse={len(row['key_reuse'])}; "
                  f"missing={len(row['missing'])}; "
                  f"unchecked={len(row['unchecked'])}; literal complete={row['complete']}")
        print('Static coverage does not certify runtime completeness or linguistic quality.')
    for issue in issues:
        print(issue)
    if args.inventory:
        args.inventory.write_text(json.dumps(inventory(root), indent=2) + '\n')
    print(f'Literal localization checks: {len(issues)} issues')
    return bool(issues)


if __name__ == '__main__':
    sys.exit(main())
