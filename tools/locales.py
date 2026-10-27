#!/usr/bin/env python3
"""Locale tooling: export enUS strings, build locale files from translations, move strings between the main
catalog and the load-on-demand text bundles, and check that every translation keeps the original's placeholders.

  python3 tools/locales.py export > strings.json          all enUS entries (main and bundles), in file order
  python3 tools/locales.py missing deDE > todo.json      entries deDE lacks or whose English changed
  python3 tools/locales.py build deDE translations.json  merge {key: text} into the locale files deDE owns
  python3 tools/locales.py check                         validate every locale file against its English
  python3 tools/locales.py rebuild                       rewrite every locale from its own entries (format change, keys left enUS)
  python3 tools/locales.py bundles                       list the catalogs: the main one and each text bundle
  python3 tools/locales.py move BUNDLE KEYS.json         move the keys in KEYS.json (a JSON list) from the main catalog into BUNDLE
                                                         (or `main`: back out of a bundle), with every translation
  python3 tools/locales.py index [--check]               write (or verify) Data/text_bundle_index.lua

A translation file maps the enUS key to the translated text. Keys are never translated. Each built locale records
the English it was translated from, so `missing` also reports entries whose English changed since.

Each generated locale is a plain AceLocale NewLocale(addon_name, "<xx>"): only the game's language is applied, the
others return at once and are collected.

Catalogs. The main catalog is Locales/<xx>.lua (listed in locales.xml, loaded with the addon). A text bundle is the
same set of ten files plus enUS.lua inside a load-on-demand add-on Modules/<module>/ (listed in that add-on's TOC),
named in Locales/bundles.json. English is still the key: `L["English text"]` reads the same wherever the text lives,
and Core/text_bundles.lua loads the bundle that owns a key the first time the key is read. A key lives in exactly one
catalog. Data/text_bundle_index.lua is how the runtime finds the owner: the sorted 32-bit hashes of every bundle's keys.
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
-- Records the locale each file registers, so check can prove it is its own.
local registered,calls=nil,0
LibStub=function()return{NewLocale=function(_,_,locale)registered=locale;calls=calls+1;return L end}end
-- enUS builds some keys from the color codes globals.lua defines first.
assert(loadfile('globals.lua'))('RotationMaster',{})
registered,calls=nil,0
local chunk=assert(loadfile(path));chunk('RotationMaster')
local function q(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
local out={}
for _,k in ipairs(order)do local v=entries[k];out[#out+1]='['..q(k)..','..(v==true and 'true' or q(v))..']'end
io.write('{"locale":'..(registered and q(registered) or 'null')..',"registrations":'..calls..',"entries":['..table.concat(out,',')..']}')
'''


def run_reader(path):
    """A locale file run by the real Lua parser: the locale it registered and its entries."""
    # The reader is passed on stdin, so `...` holds the path argument.
    result = subprocess.run(['luajit', '-', str(path)], input=READER.encode(), capture_output=True, cwd=ROOT)
    if result.returncode:
        raise SystemExit(f'{path}: {result.stderr.decode().strip()}')
    # The reader escapes control bytes only; strings are UTF-8 text.
    return json.loads(result.stdout.decode('utf-8'))


def read_lua(path):
    """Entries of a locale file as an ordered list of (key, value)."""
    return [(k, v) for k, v in run_reader(path)['entries']]


# --------------------------------------------------------------------------------------------- catalogs

BUNDLES_JSON = 'Locales/bundles.json'
INDEX_FILE = 'Data/text_bundle_index.lua'
# The interfaces every load-on-demand text add-on declares (the same list as the other Modules/ add-ons).
BUNDLE_INTERFACE = '11509, 20506, 30405, 38002, 40402, 50504, 120105, 16001'


class Catalog:
    """One set of locale files: the main one (Locales/) or a text bundle (Modules/<module>/)."""

    def __init__(self, name, directory, module=None, title=None, notes=None):
        self.name, self.directory, self.module = name, Path(directory), module
        self.title, self.notes = title, notes

    @property
    def is_main(self):
        return self.module is None

    # catalogs() builds fresh objects on every call: two views of the same catalog are the same catalog.
    def __eq__(self, other):
        return isinstance(other, Catalog) and other.name == self.name

    def __hash__(self):
        return hash(self.name)

    def path(self, locale):
        return self.directory / f'{locale}.lua'

    @property
    def english_path(self):
        return self.path('enUS')

    def label(self, locale):
        return locale if self.is_main else f'{locale} ({self.name})'

    def relative(self, locale='enUS'):
        return self.path(locale).relative_to(ROOT).as_posix()


def catalogs():
    """The main catalog first, then each text bundle named in Locales/bundles.json (read afresh: ROOT may change)."""
    found = [Catalog('main', ROOT / 'Locales')]
    manifest = ROOT / BUNDLES_JSON
    if manifest.exists():
        for row in json.loads(manifest.read_text(encoding='utf-8'))['bundles']:
            found.append(Catalog(row['id'], ROOT / 'Modules' / row['module'], row['module'], row.get('title'), row.get('notes')))
    return found


def catalog_named(name):
    for catalog in catalogs():
        if catalog.name == name:
            return catalog
    raise SystemExit(f'unknown catalog {name!r}; known: {", ".join(c.name for c in catalogs())}')


def english(catalog=None):
    """enUS entries: key -> displayed English (the key itself when the value is true). All catalogs unless one is named."""
    result = {}
    for each in ([catalog] if catalog else catalogs()):
        if each.english_path.exists():
            for key, value in read_lua(each.english_path):
                result[key] = key if value is True else value
    return result


def owners():
    """key -> the catalog that holds its English."""
    result = {}
    for each in catalogs():
        if each.english_path.exists():
            for key, _ in read_lua(each.english_path):
                result.setdefault(key, each)
    return result


def locale_entries(locale, catalog=None):
    """The (key, value) entries of a locale in file order, across all catalogs unless one is named."""
    found = []
    for each in ([catalog] if catalog else catalogs()):
        if each.path(locale).exists():
            found.extend(read_lua(each.path(locale)))
    return found


def locale_files(locale):
    return [each.path(locale) for each in catalogs() if each.path(locale).exists()]


def is_locale_file(relative):
    """Whether a repository-relative path is a locale file of any catalog (they are text, not source code)."""
    relative = str(relative).replace('\\', '/')
    for each in catalogs():
        if relative.startswith(each.directory.relative_to(ROOT).as_posix() + '/') and Path(relative).stem in ['enUS'] + LOCALES:
            return True
    return False


SOURCE_MARK = re.compile(r'^-- en: (.*)$')


def read_sources(locale, catalog=None):
    """English each entry was translated from, recorded as a comment above it (all catalogs unless one is named)."""
    sources = {}
    for each in ([catalog] if catalog else catalogs()):
        path = each.path(locale)
        if not path.exists():
            continue
        pending = None
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


FORMAT_SCAN = re.compile(r'%%|%[-+#0]*\d*(?:\.\d+)?[sdifgqxXc]')


class _Format:
    # Scan %% as one token so its second % never starts a specifier.
    pattern = r'%%|%[-+#0]*\d*(?:\.\d+)?[sdifgqxXc]'

    @staticmethod
    def findall(text):
        return [t for t in FORMAT_SCAN.findall(text) if t != '%%']

    @staticmethod
    def search(text):
        return bool(_Format.findall(text))


FORMAT = _Format


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


ENGLISH_HEADER = ['local addon_name = ...', '', 'local L = LibStub("AceLocale-3.0"):NewLocale(addon_name, "enUS", true)', 'if not L then return end']


def write_locale(locale, entries, sources, catalog=None):
    catalog = catalog or catalogs()[0]
    lines = ['-- Generated by tools/locales.py from reviewed translations; edit the',
             '-- translation and rebuild rather than this file. Each "-- en:" line is the',
             '-- English this entry was translated from (see `tools/locales.py missing`).',
             'local addon_name = ...',
             f'local L = LibStub("AceLocale-3.0"):NewLocale(addon_name, "{locale}")',
             'if not L then return end']
    for key, text in entries:
        lines.append('-- en: ' + json.dumps(sources[key], ensure_ascii=False))
        lines.append(f'L[{lua_string(key)}] = {lua_string(text)}')
    catalog.path(locale).write_text('\n'.join(lines) + '\n', encoding='utf-8')


def ensure_registered(locale, catalog=None):
    catalog = catalog or catalogs()[0]
    if catalog.is_main:
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
        return
    ensure_bundle_toc(catalog)


def bundle_files(catalog):
    return ['enUS.lua'] + [f'{l}.lua' for l in LOCALES if catalog.path(l).exists()]


def toc_path(catalog):
    return catalog.directory / f'{catalog.module}.toc'


def ensure_bundle_toc(catalog):
    """The add-on's TOC lists the locale files first (enUS, then the others in order); a new add-on gets a whole TOC."""
    toc = toc_path(catalog)
    files = bundle_files(catalog)
    if not toc.exists():
        header = [f'## Interface: {BUNDLE_INTERFACE}',
                  f'## Title: Rotation Master - {catalog.title or catalog.name}',
                  f'## Notes: {catalog.notes or "Text Rotation Master shows on one screen."} Rotation Master loads this itself, the first time that text is needed; it holds only translations.',
                  '## Author: PreZ', '## Version: @project-version@', '## Dependencies: RotationMaster', '## LoadOnDemand: 1',
                  '## Group: RotationMaster', '## X-Category: Action Bars', '## X-License: MIT', '']
        toc.write_text('\n'.join(header + files) + '\n', encoding='utf-8')
        return
    lines = toc.read_text(encoding='utf-8').splitlines()
    listed = {f'{l}.lua' for l in ['enUS'] + LOCALES}
    rest = [l for l in lines if l.strip() not in listed]
    # Insert the locale files before the first non-comment file line (or at the end when there is none).
    for index, line in enumerate(rest):
        if line.strip() and not line.startswith('#'):
            rest[index:index] = files
            break
    else:
        rest.extend(files)
    new = '\n'.join(rest).rstrip('\n') + '\n'
    if new != toc.read_text(encoding='utf-8'):
        toc.write_text(new, encoding='utf-8')


def cmd_export():
    owner = owners()
    rows = []
    for key, value in english().items():
        row = {'key': key, 'en': value}
        if not owner[key].is_main:
            row['bundle'] = owner[key].name
        rows.append(row)
    json.dump(rows, sys.stdout, ensure_ascii=False, indent=1)


def cmd_missing(locale):
    en = english()
    have = dict(locale_entries(locale))
    sources = read_sources(locale)
    todo = [{'key': k, 'en': v} for k, v in en.items() if k not in have or sources.get(k) != v]
    json.dump(todo, sys.stdout, ensure_ascii=False, indent=1)


def cmd_build(locale, translation_path):
    build(locale, json.loads(Path(translation_path).read_text(encoding='utf-8')))


def build(locale, incoming):
    assert locale in LOCALES, f'unknown locale {locale}'
    en = english()
    owner = owners()
    errors = []
    for key, text in incoming.items():
        if key not in en:
            errors.append(f'{key!r}: not an enUS key')
            continue
        for p in problems(key, en[key], text):
            errors.append(f'{key!r}: {p}')
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        raise SystemExit(f'{len(errors)} problem(s); nothing written')
    for catalog in catalogs():
        mine = {k: v for k, v in incoming.items() if owner[k] == catalog}
        wanted = english(catalog)
        path = catalog.path(locale)
        current = dict(read_lua(path)) if path.exists() else {}
        sources = read_sources(locale, catalog)
        if not mine and not path.exists() and not catalog.is_main:
            continue  # a bundle with nothing to say in this locale yet has no file
        for key, text in mine.items():
            current[key] = text
            sources[key] = en[key]
        entries = [(k, current[k]) for k in wanted if k in current]
        write_locale(locale, entries, sources, catalog)
        ensure_registered(locale, catalog)
        print(f'{catalog.label(locale)}: {len(entries)}/{len(wanted)} entries')


def cmd_rebuild():
    """Rewrite every existing locale from its own entries: a format change, or keys that left enUS."""
    for locale in LOCALES:
        if any(each.path(locale).exists() for each in catalogs()):
            build(locale, {})


def cmd_bundles():
    for each in catalogs():
        count = len(english(each)) if each.english_path.exists() else 0
        print(f'{each.name:14} {count:5} keys  {each.directory.relative_to(ROOT).as_posix()}' + ('' if each.is_main else f'  ({each.module})'))


# ----------------------------------------------------------------------------------------- the key index

def key_hash(key):
    """The 32-bit hash Core/text_bundles.lua computes: h = h * 31 + byte, modulo 2^32, over the UTF-8 bytes."""
    h = 0
    for byte in key.encode('utf-8'):
        h = (h * 31 + byte) % 4294967296
    return h


def index_text():
    rows = []
    owner_of_hash = {}
    for each in catalogs():
        if each.is_main:
            continue
        for key in english(each):
            other = owner_of_hash.setdefault(key_hash(key), (each.name, key))
            if other[0] != each.name:
                raise SystemExit(f'{key!r} ({each.name}) and {other[1]!r} ({other[0]}) share a 32-bit hash: '
                                 'the runtime could not tell their bundles apart; change the wording of one')
    for each in catalogs():
        if each.is_main:
            continue
        hashes = sorted({key_hash(k) for k in english(each)})
        chunks = [''.join(f'{h:08x}' for h in hashes[i:i + 16]) for i in range(0, len(hashes), 16)]
        keys = ' ..\n            '.join(f'"{c}"' for c in chunks) if chunks else '""'
        rows.append(f'    {{ id = "{each.name}", module = "{each.module}", count = {len(hashes)}, keys =\n            {keys} }},')
    return ('-- Generated by tools/locales.py index from Locales/bundles.json and each text bundle\'s enUS.lua; do not edit.\n'
            '-- Which load-on-demand text bundle owns an English key: the sorted 32-bit hashes of every key (h = h * 31 + byte,\n'
            '-- modulo 2^32, over the UTF-8 bytes), eight hex digits each. Core/text_bundles.lua binary-searches them.\n'
            'local _, addon = ...\n'
            'addon.textBundleIndex = {\n' + '\n'.join(rows) + '\n}\n')


def cmd_index(check=False):
    path = ROOT / INDEX_FILE
    expected = index_text()
    if check:
        if not path.exists() or path.read_text(encoding='utf-8') != expected:
            raise SystemExit(f'{INDEX_FILE} is stale: run python3 tools/locales.py index')
        return True
    path.write_text(expected, encoding='utf-8')
    print(f'{INDEX_FILE}: {sum(len(english(c)) for c in catalogs() if not c.is_main)} keys in {len(catalogs()) - 1} bundles')


# --------------------------------------------------------------------------------------------- moving keys

def cmd_move(target_name, keys_path):
    """Move keys between catalogs: their English lines and every locale's translation (with its English source)."""
    target = catalog_named(target_name)
    keys = json.loads(Path(keys_path).read_text(encoding='utf-8'))
    assert isinstance(keys, list) and all(isinstance(k, str) for k in keys), 'KEYS.json must be a JSON list of strings'
    owner = owners()
    unknown = [k for k in keys if k not in owner]
    if unknown:
        raise SystemExit(f'not an enUS key: {unknown[0]!r} (and {len(unknown) - 1} more)')
    moving = [k for k in keys if owner[k] != target]
    wanted = set(moving)
    by_source = {}
    for key in moving:
        by_source.setdefault(owner[key], []).append(key)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import catalog_check
    # 1. English lines: remove them from each source file and append them to the target, in their source order.
    moved_lines = []
    for source, source_keys in by_source.items():
        text = source.english_path.read_text(encoding='utf-8')
        lines = text.split('\n')
        drop = set()
        for key, line, assigned, _ in catalog_check.literal_sites(text):
            if assigned and key in wanted:
                drop.add(line - 1)
        for index in sorted(drop):
            if not lines[index].startswith('L[') or lines[index].count('\n'):
                raise SystemExit(f'{source.relative()}:{index + 1}: not a single-line entry; move it by hand')
        moved_lines.extend((source.name, lines[index]) for index in sorted(drop))
        source.english_path.write_text('\n'.join(l for i, l in enumerate(lines) if i not in drop), encoding='utf-8')
    if not target.english_path.exists():
        target.directory.mkdir(parents=True, exist_ok=True)
        target.english_path.write_text('\n'.join(ENGLISH_HEADER) + '\n', encoding='utf-8')
    existing = target.english_path.read_text(encoding='utf-8').rstrip('\n')
    target.english_path.write_text(existing + '\n' + '\n'.join(line for _, line in moved_lines) + '\n', encoding='utf-8')
    # 2. Translations: each locale's entries move with their recorded English.
    for locale in LOCALES:
        for source, source_keys in by_source.items():
            if not source.path(locale).exists():
                continue
            entries = dict(read_lua(source.path(locale)))
            sources = read_sources(locale, source)
            moving_here = [k for k in source_keys if k in entries]
            if not moving_here:
                continue
            kept = [(k, v) for k, v in entries.items() if k not in wanted]
            write_locale(locale, kept, sources, source)
            ensure_registered(locale, source)
            target_entries = dict(read_lua(target.path(locale))) if target.path(locale).exists() else {}
            target_sources = read_sources(locale, target)
            for key in moving_here:
                target_entries[key] = entries[key]
                target_sources[key] = sources[key]
            order = [k for k in english(target) if k in target_entries]
            write_locale(locale, [(k, target_entries[k]) for k in order], target_sources, target)
            ensure_registered(locale, target)
    cmd_index()
    print(f'moved {len(moving)} key(s) into {target.name}')


# ------------------------------------------------------------------------------------------------ check

def cmd_check():
    failures = 0
    cats = catalogs()
    en = {}
    seen = {}
    for catalog in cats:
        if not catalog.english_path.exists():
            print(f'{catalog.relative()}: missing'); failures += 1
            continue
        mine = english(catalog)
        en[catalog.name] = mine
        for key in mine:
            if key in seen:
                print(f'{key!r} is in both the {seen[key]} catalog and the {catalog.name} catalog'); failures += 1
            seen.setdefault(key, catalog.name)
    all_english = english()
    for locale in LOCALES:
        total_entries = total_stale = total_known = 0
        any_file = False
        for catalog in cats:
            path = catalog.path(locale)
            if not path.exists():
                continue
            any_file = True
            result = run_reader(path)
            entries = [(k, v) for k, v in result['entries']]
            if result['locale'] != locale or result['registrations'] != 1:
                print(f'{catalog.relative(locale)}: must call NewLocale(addon_name, "{locale}") exactly once (registered '
                      f'{result["locale"]!r} {result["registrations"]} time(s)); rebuild it'); failures += 1
            sources = read_sources(locale, catalog)
            for key, text in entries:
                if key not in en.get(catalog.name, {}):
                    where = 'another catalog' if key in all_english else 'enUS'
                    print(f'{catalog.label(locale)} {key!r}: not a key of this catalog ({where})'); failures += 1
                    continue
                for p in problems(key, en[catalog.name][key], text):
                    print(f'{catalog.label(locale)} {key!r}: {p}'); failures += 1
                if sources.get(key) != en[catalog.name][key]:
                    total_stale += 1
            total_entries += len(entries)
            if catalog.is_main:
                if f'Locales\\{locale}.lua' not in (ROOT / 'locales.xml').read_text(encoding='utf-8'):
                    print(f'{locale}: not listed in locales.xml'); failures += 1
            else:
                toc = toc_path(catalog)
                if not toc.exists() or f'{locale}.lua' not in toc.read_text(encoding='utf-8').split():
                    print(f'{catalog.relative(locale)}: not listed in {toc.relative_to(ROOT).as_posix()}'); failures += 1
        if any_file:
            print(f'{locale}: {total_entries}/{len(all_english)} entries, {total_stale} translated from older English')
    for catalog in cats:
        if not catalog.is_main:
            toc = toc_path(catalog)
            text = toc.read_text(encoding='utf-8').split() if toc.exists() else []
            if 'enUS.lua' not in text:
                print(f'{toc.relative_to(ROOT).as_posix()}: does not list enUS.lua'); failures += 1
    if len(cats) > 1:
        try:
            cmd_index(check=True)
        except SystemExit as error:
            print(error); failures += 1
        print('catalogs: ' + ', '.join(f'{c.name} {len(en.get(c.name, {}))}' for c in cats))
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
    elif args[:1] == ['rebuild']:
        cmd_rebuild()
    elif args[:1] == ['bundles']:
        cmd_bundles()
    elif args[:1] == ['move'] and len(args) == 3:
        cmd_move(args[1], args[2])
    elif args[:1] == ['index']:
        cmd_index('--check' in args)
    else:
        raise SystemExit(__doc__)
