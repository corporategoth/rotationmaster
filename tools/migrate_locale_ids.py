#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""One-time converter (historical): English-text-keyed locale files -> stable-ID locale files. Kept so the migration
can be audited and re-proved; it is of no use once the repository is converted.

  python3 tools/migrate_locale_ids.py convert      rewrite every catalog's locale files in place from the old layout
  python3 tools/migrate_locale_ids.py prove OLD    prove nothing was lost, against a copy of the OLD tree (see below)

The old layout: `L["English text"] = "translation"` per line, an `-- en: "..."` comment above it recording the
English it was translated from, enUS as `L["English text"] = true` (or a different displayed text). The new layout is
tools/locale_format.py's.

convert assigns IDs sequentially in file order (the main catalog, then each text bundle), keeps every translation, and
records, as each entry's hash, the hash of the English the OLD file said it was translated from. Where that differs from
the current English the entry is stale by hash: shown in game, listed by `locales.py missing`, never silently blessed.
Every file is credited to Claude (AI, not reviewed by a native speaker).

prove OLD loads the old tree and the new tree as the game does (tools/locale_dump.lua, under lua5.1 and luajit) for the
English and each of the ten languages and requires L[key] to be identical for every key of every catalog.
    git archive <old commit> | tar -x -C <scratch>/old     # OLD
"""
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import locale_format as F  # noqa: E402
import locales as L  # noqa: E402

ROOT = L.ROOT

# The old reader: a locale file run by the real Lua parser with a recording stand-in for AceLocale.
READER = r'''
local path=...
local entries,order={},{}
local L=setmetatable({},{__newindex=function(_,k,v)
  if entries[k]==nil then order[#order+1]=k end
  entries[k]=v
end})
local registered,calls=nil,0
LibStub=function()return{NewLocale=function(_,_,locale)registered=locale;calls=calls+1;return L end}end
assert(loadfile('globals.lua'))('RotationMaster',{})
registered,calls=nil,0
local chunk=assert(loadfile(path));chunk('RotationMaster')
local function q(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
local out={}
for _,k in ipairs(order)do local v=entries[k];out[#out+1]='['..q(k)..','..(v==true and 'true' or q(v))..']'end
io.write('{"locale":'..(registered and q(registered) or 'null')..',"registrations":'..calls..',"entries":['..table.concat(out,',')..']}')
'''


def run_reader(path, root):
    result = subprocess.run(['luajit', '-', str(path)], input=READER.encode(), capture_output=True, cwd=root)
    if result.returncode:
        raise SystemExit(f'{path}: {result.stderr.decode().strip()}')
    return json.loads(result.stdout.decode('utf-8'))


def old_sources(path):
    """key -> the English recorded in the `-- en:` comment above its entry."""
    sources, pending = {}, None
    for line in path.read_text(encoding='utf-8').splitlines():
        if line.startswith('-- en: '):
            pending = json.loads(line[len('-- en: '):])
        elif line.startswith('L[') and pending is not None:
            key = json.loads(line[2:line.index('] = ')])
            sources[key] = pending
            pending = None
    return sources


def old_catalog(catalog, root):
    """({key: displayed English}, ordered keys, {locale: ({key: translation}, {key: recorded English})})."""
    path = catalog.english_path
    english, order = {}, []
    for key, value in run_reader(path, root)['entries']:
        english[key] = key if value is True else value
        order.append(key)
    translations = {}
    for locale in L.LOCALES:
        file = catalog.path(locale)
        if file.exists():
            result = run_reader(file, root)
            translations[locale] = ({k: v for k, v in result['entries']}, old_sources(file))
    return english, order, translations


def convert(root=ROOT):
    L.ROOT = root
    catalogs = L.catalogs()
    docs_begin, docs_end = '-- BEGIN GENERATED RM PUBLIC HELPER DOCS', '-- END GENERATED RM PUBLIC HELPER DOCS'
    main_text = catalogs[0].english_path.read_text(encoding='utf-8')
    import catalog_check
    block = main_text.split(docs_begin, 1)[1].split(docs_end, 1)[0]
    generated_keys = {key for key, _, assigned, _ in catalog_check.literal_sites(block) if assigned}
    model = L.Model()
    model.registry = {'next': 1, 'retired': [], 'generated': {'public-helper-docs': []}, 'annotations': {}}
    model.credits = {}
    model.entries = {c.name: [] for c in catalogs}
    stats = Counter()
    seen = {}
    for catalog in catalogs:
        english, order, translations = old_catalog(catalog, root)
        for key in order:
            if key in seen:
                raise SystemExit(f'{key!r} is in both {seen[key]} and {catalog.name}')
            seen[key] = catalog.name
            entry = model.add(english[key], catalog=catalog.name if catalog.is_class else 'main')
            if key in generated_keys:
                model.registry['generated']['public-helper-docs'].append(entry.id)
            stats['entries'] += 1
            stats['symbolic'] += entry.key != entry.text
        by_key = {key: model.find_key(english[key]) for key in order}
        for locale, (values, sources) in translations.items():
            rows = model.translations(locale, catalog)
            for key, text in values.items():
                if key not in by_key:
                    raise SystemExit(f'{catalog.label(locale)}: {key!r} is not a key of its English')
                entry = by_key[key]
                recorded = sources.get(key)
                if recorded is None:
                    raise SystemExit(f'{catalog.label(locale)}: {key!r} has no "-- en:" source comment')
                if text is True:
                    text = key
                rows[entry.id] = F.Translation(entry.id, text, F.text_hash(recorded), recorded, 0)
                stats['translations'] += 1
                if recorded != entry.text:
                    stats['stale'] += 1
                    stats[f'stale {locale}'] += 1
            model.mark(locale, catalog)
            model.credit(locale, catalog.name, 'Claude', kind='ai', strings=len(values))
            # The migration records who wrote the strings, not when: leave the dates out.
            for row in model.credit_list(locale, catalog.name):
                row.pop('first', None)
                row.pop('last', None)
    model.registry['generated']['public-helper-docs'].sort()
    out = model.write()
    print(f'converted: {stats["entries"]} entries ({stats["symbolic"]} read under a key that is not their text), '
          f'{stats["translations"]} translations, {stats["stale"]} stale by hash; {len(out)} file(s) written')
    for key in sorted(k for k in stats if k.startswith('stale ')):
        print(f'  {key}: {stats[key]}')
    return stats


# ---------------------------------------------------------------------------------------------- proof

def dump(root, client, keys_file, out_file, interpreter):
    result = subprocess.run([interpreter, str(ROOT / 'tools/locale_dump.lua'), str(root), client, str(keys_file), str(out_file)],
                            capture_output=True, text=True, cwd=ROOT)
    if result.returncode:
        raise SystemExit(f'{interpreter} {client} {root}: {result.stderr.strip()}')
    return dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)


def prove(old_root, scratch):
    """L[key] of the old tree equals L[key] of the new tree, for every key, client language and interpreter."""
    old_root, scratch = Path(old_root), Path(scratch)
    scratch.mkdir(parents=True, exist_ok=True)
    keys = scratch / 'keys.txt'
    # Every key of the current tree: a string the old tree lacks would read differently and show up as a mismatch.
    all_keys = [e.key for e in L.english_entries()]
    newer = 0
    keys.write_text('\n'.join(k.encode('utf-8').hex() for k in all_keys) + '\n')
    report = {}
    mismatches = 0
    for interpreter in ('lua5.1', 'luajit'):
        for client in ['enUS'] + L.LOCALES:
            old_out, new_out = scratch / f'old-{client}.txt', scratch / f'new-{client}.txt'
            old_stats = dump(old_root, client, keys, old_out, interpreter)
            new_stats = dump(ROOT, client, keys, new_out, interpreter)
            old_lines, new_lines = old_out.read_text().splitlines(), new_out.read_text().splitlines()
            bad = [i for i, (a, b) in enumerate(zip(old_lines, new_lines)) if a != b]
            if len(old_lines) != len(new_lines):
                bad.append(-1)
            mismatches += len(bad)
            report[(interpreter, client)] = (len(old_lines), len(bad), old_stats, new_stats)
            for index in bad[:5]:
                if index >= 0:
                    key = bytes.fromhex(all_keys[index].encode().hex()).decode()
                    print(f'MISMATCH {interpreter} {client} {key[:70]!r}')
    for (interpreter, client), (count, bad, old_stats, new_stats) in report.items():
        print(f'{interpreter:7} {client}: {count} keys compared, {bad} differ; memory KB at start old {old_stats["boot"]} new {new_stats["boot"]}, '
              f'after reading everything old {old_stats["all"]} new {new_stats["all"]}')
    print(f'proof: {len(all_keys)} keys x {len(L.LOCALES) + 1} clients x 2 interpreters, {mismatches} mismatch(es)'
          + (f' ({newer} string(s) added since the conversion are not compared)' if newer else ''))
    return mismatches


def main(argv):
    if argv[:1] == ['convert']:
        convert()
    elif argv[:1] == ['prove'] and len(argv) in (2, 3):
        scratch = argv[2] if len(argv) == 3 else '/var/tmp/rm/prove'
        sys.exit(1 if prove(argv[1], scratch) else 0)
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main(sys.argv[1:])
