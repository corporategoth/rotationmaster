#!/usr/bin/env python3
"""Locale tooling: export enUS strings, build locale files from translations,
and check that every translation keeps the original's placeholders.

  python3 tools/locales.py export > strings.json          all enUS entries, in file order
  python3 tools/locales.py missing deDE > todo.json      entries deDE lacks or whose English changed
  python3 tools/locales.py build deDE translations.json  merge {key: text} into Locales/deDE.lua
  python3 tools/locales.py check                         validate every Locales/*.lua against enUS

A translation file maps the enUS key to the translated text. Keys are never
translated. Each built locale records the English it was translated from, so
`missing` also reports entries whose English changed since.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ['deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW']

READER = r'''
local path=...
local entries,order={},{}
local L=setmetatable({},{__newindex=function(_,k,v)
  if entries[k]==nil then order[#order+1]=k end
  entries[k]=v
end})
LibStub=function()return{NewLocale=function()return L end}end
-- enUS builds some keys from the color codes globals.lua defines first.
assert(loadfile('globals.lua'))('RotationMaster',{})
local chunk=assert(loadfile(path));chunk('RotationMaster')
local function q(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
local out={}
for _,k in ipairs(order)do local v=entries[k];out[#out+1]='['..q(k)..','..(v==true and 'true' or q(v))..']'end
io.write('['..table.concat(out,',')..']')
'''


def read_lua(path):
    """Entries of a locale file as an ordered list of (key, value) via the real Lua parser."""
    # The reader is passed on stdin, so `...` holds the path argument.
    result = subprocess.run(['luajit', '-', str(path)], input=READER.encode(), capture_output=True, cwd=ROOT)
    if result.returncode:
        raise SystemExit(f'{path}: {result.stderr.decode().strip()}')
    # The reader escapes control bytes only; strings are UTF-8 text.
    return [(k, v) for k, v in json.loads(result.stdout.decode('utf-8'))]


def english():
    """enUS entries: key -> displayed English (the key itself when the value is true)."""
    return {k: (k if v is True else v) for k, v in read_lua(ROOT / 'Locales/enUS.lua')}


SOURCE_MARK = re.compile(r'^-- en: (.*)$')


def read_sources(locale):
    """English each entry was translated from, recorded as a comment above it."""
    path = ROOT / f'Locales/{locale}.lua'
    sources, pending = {}, None
    if not path.exists():
        return sources
    for line in path.read_text(encoding='utf-8').splitlines():
        m = SOURCE_MARK.match(line)
        if m:
            pending = json.loads(m.group(1))
        elif line.startswith('L[') and pending is not None:
            key = read_key(line)
            sources[key] = pending
            pending = None
    return sources


def read_key(line):
    m = re.match(r'L\[("(?:[^"\\]|\\.)*")\]', line)
    return json.loads(m.group(1)) if m else None


# Placeholders and markup that must survive translation unchanged.
TOKEN = re.compile(r'%(?:\d+\$)?[-+#0]*\d*(?:\.\d+)?[sdifgqxXc]|%%|\|\||\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t|\|n|\\n|\n')
# {{name}} and {name} are substituted by name: keep them verbatim. {{!?a|b}} is
# a positive|negative pair the runtime picks from (Core/condition_description,
# Core/conditions): translate both texts, keep the pair and its "!" marker.
VARIABLE = re.compile(r'\{\{[A-Za-z_][A-Za-z0-9_]*\}\}|(?<!\{)\{[A-Za-z_][A-Za-z0-9_]*\}(?!\})')
ALTERNATIVE = re.compile(r'\{\{(!?)([^{}]*)\}\}')


FORMAT = re.compile(r'%[-+#0]*\d*(?:\.\d+)?[sdifgqxXc]')


def tokens(text):
    found = VARIABLE.findall(text)
    def alternative(m):
        marker, body = m.group(1), m.group(2)
        if '|' not in body:
            return m.group(0)
        parts = body.split('|')
        found.append(f'{{{{{marker}alternatives:{len(parts)}}}}}' if all(p.strip() for p in parts) else '{{empty alternative}}')
        for part in parts:  # the pipes here separate texts; they are not escapes
            found.extend(TOKEN.findall(part))
        return '\0'
    found.extend(TOKEN.findall(ALTERNATIVE.sub(alternative, text)))
    return sorted(found)


def lua_string(text):
    out = ['"']
    for ch in text:
        if ch == '\\':
            out.append('\\\\')
        elif ch == '"':
            out.append('\\"')
        elif ch == '\n':
            out.append('\\n')
        elif ord(ch) < 32 or ord(ch) == 127:
            out.append('\\%03d' % ord(ch))
        else:
            out.append(ch)
    out.append('"')
    return ''.join(out)


def problems(key, en, text):
    found = []
    if not isinstance(text, str) or not text.strip():
        found.append('empty translation')
        return found
    if tokens(en) != tokens(text):
        found.append(f'placeholders differ: {tokens(en)} vs {tokens(text)}')
    # string.format has no positional arguments: specifiers must keep their order.
    elif FORMAT.findall(en) != FORMAT.findall(text):
        found.append(f'format specifiers reordered: {FORMAT.findall(en)} vs {FORMAT.findall(text)}')
    # A string with format codes goes through string.format: a lone % there must be %%.
    if FORMAT.search(en) or '%%' in en:
        if '%' in re.sub(r'%%|' + FORMAT.pattern, '', text):
            found.append('bare % in a formatted string (write %%)')
    if re.search(r'%\d+\$', text):
        found.append('positional format specifier (unsupported by Lua)')
    if len(text) > max(64, len(en) * 4):
        found.append('suspiciously long')
    return found


def write_locale(locale, entries, sources):
    lines = ['-- Generated by tools/locales.py from reviewed translations; edit the',
             '-- translation and rebuild rather than this file. Each "-- en:" line is the',
             '-- English this entry was translated from (see `tools/locales.py missing`).',
             'local addon_name = ...',
             f'local L = LibStub("AceLocale-3.0"):NewLocale(addon_name, "{locale}")',
             'if not L then return end']
    for key, text in entries:
        lines.append('-- en: ' + json.dumps(sources[key], ensure_ascii=False))
        lines.append(f'L[{lua_string(key)}] = {lua_string(text)}')
    (ROOT / f'Locales/{locale}.lua').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def ensure_registered(locale):
    xml = ROOT / 'locales.xml'
    text = xml.read_text(encoding='utf-8')
    line = f'<Script file="Locales\\{locale}.lua" />'
    if line not in text:
        anchor = '<Script file="Locales\\enUS.lua" />'
        assert anchor in text
        registered = [l for l in LOCALES if f'Locales\\{l}.lua' in text or l == locale]
        block = '\n'.join(f'<Script file="Locales\\{l}.lua" />' for l in sorted(registered))
        text = re.sub(r'(<Script file="Locales\\enUS\.lua" />)(\n<Script file="Locales\\[a-z]{2}[A-Z]{2}\.lua" />)*',
                      lambda m: anchor + '\n' + block, text)
        xml.write_text(text, encoding='utf-8')


def cmd_export():
    json.dump([{'key': k, 'en': v} for k, v in english().items()], sys.stdout, ensure_ascii=False, indent=1)


def cmd_missing(locale):
    en = english()
    path = ROOT / f'Locales/{locale}.lua'
    have = dict(read_lua(path)) if path.exists() else {}
    sources = read_sources(locale)
    todo = [{'key': k, 'en': v} for k, v in en.items() if k not in have or sources.get(k) != v]
    json.dump(todo, sys.stdout, ensure_ascii=False, indent=1)


def cmd_build(locale, translation_path):
    assert locale in LOCALES, f'unknown locale {locale}'
    en = english()
    incoming = json.loads(Path(translation_path).read_text(encoding='utf-8'))
    path = ROOT / f'Locales/{locale}.lua'
    current = dict(read_lua(path)) if path.exists() else {}
    sources = read_sources(locale)
    errors = []
    for key, text in incoming.items():
        if key not in en:
            errors.append(f'{key!r}: not an enUS key')
            continue
        for p in problems(key, en[key], text):
            errors.append(f'{key!r}: {p}')
        current[key] = text
        sources[key] = en[key]
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        raise SystemExit(f'{len(errors)} problem(s); nothing written')
    entries = [(k, current[k]) for k in en if k in current]
    write_locale(locale, entries, sources)
    ensure_registered(locale)
    print(f'{locale}: {len(entries)}/{len(en)} entries')


def cmd_check():
    en = english()
    failures = 0
    for locale in LOCALES:
        path = ROOT / f'Locales/{locale}.lua'
        if not path.exists():
            continue
        entries = read_lua(path)
        sources = read_sources(locale)
        stale = 0
        for key, text in entries:
            if key not in en:
                print(f'{locale} {key!r}: not an enUS key'); failures += 1
                continue
            for p in problems(key, en[key], text):
                print(f'{locale} {key!r}: {p}'); failures += 1
            if sources.get(key) != en[key]:
                stale += 1
        if f'Locales\\{locale}.lua' not in (ROOT / 'locales.xml').read_text(encoding='utf-8'):
            print(f'{locale}: not listed in locales.xml'); failures += 1
        print(f'{locale}: {len(entries)}/{len(en)} entries, {stale} translated from older English')
    if failures:
        raise SystemExit(f'{failures} locale problem(s)')


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['export']:
        cmd_export()
    elif args[:1] == ['missing'] and len(args) == 2:
        cmd_missing(args[1])
    elif args[:1] == ['build'] and len(args) == 3:
        cmd_build(args[1], args[2])
    elif args[:1] == ['check']:
        cmd_check()
    else:
        raise SystemExit(__doc__)
