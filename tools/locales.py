#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Locale tooling: stable-ID translations. Export the English, list what needs translating, build locale files from
translations, check them, reword English without losing translations, move text between catalogs, credit translators.

  python3 tools/locales.py export > strings.json          every English entry: id, key, en (and the bundle), in ID order
  python3 tools/locales.py missing deDE > todo.json       deDE's untranslated IDs and its stale IDs (English changed since)
  python3 tools/locales.py build deDE translations.json [--translator "Name" [--url URL] [--human|--ai]]
                                                          merge {id: text} into the locale files deDE owns
  python3 tools/locales.py accept deDE [ID ...]           mark stale translations as still right for the current English
  python3 tools/locales.py credit deDE --translator "Name" [--catalog class-shaman] [--strings N] [--human|--ai]
                                                          credit direct edits and update the About page
  python3 tools/locales.py check [--complete] [--require-notes] [--require-context]
                                                          validate every locale file against its English (IDs, hashes, placeholders,
                                                          headers, notes); the switches also fail for strings lacking notes/context
  python3 tools/locales.py rebuild                        rewrite every file in canonical form (headers, order, TOCs, index)
  python3 tools/locales.py bundles                        list the catalogs: the main one and each text bundle
  python3 tools/locales.py move BUNDLE KEYS.json          move the keys in KEYS.json (a JSON list) between catalogs, assigning destination IDs
                                                          and every translation (BUNDLE may be `main`)
  python3 tools/locales.py index [--check]                write (or verify) Data/text_bundle_index.lua
  python3 tools/locales.py reword "old English" "new English" [--dry-run] [--all-literals] [--tests]
                                                          change the English in code and enUS, keep the ID and every translation
  python3 tools/locales.py add KEY [TEXT] [--catalog NAME]  add a string (TEXT omitted: the key is its own English); new ID
  python3 tools/locales.py remove KEY ...                 delete strings everywhere and retire their IDs
  python3 tools/locales.py sync [--dry-run] [--prune-class] add missing literals, optionally prune unused class rotation text
  python3 tools/locales.py notes todo [--only notes|context] [--context-words N]
                                                          strings with format tokens and no notes, short strings without context,
                                                          with the code that reads them
  python3 tools/locales.py notes set notes.json           merge {id or English: [notes] | {"notes": [...], "context": "..."}}
  python3 tools/locales.py where ID|English|substring [-B N] [-A N] [-C N] [--json] [--tests]
                                                          where the source reads a string, with context lines like grep

Stable IDs. Every string has a number from tools/locale_registry.json that is never reused and never derived from the
wording. The English binds text to ID, T["English text"] = 1234, and a language binds the ID to its translation,
[1234] = "translation" (tools/locale_format.py has the layout); each translation records, in a comment
above it, the hash of the English it was made from, so a reworded English leaves its translations in place, shown in
game, and listed by `missing` as stale until a translator confirms (`accept`) or replaces them.

Each generated locale is a plain AceLocale NewLocale(addon_name, "<xx>", false, true): only the game's language
executes its file, the others return at once. The enUS file of each catalog runs last, joins the language's
ID -> translation table to its own text -> ID table T and writes L[text] = translation into the AceLocale table.

Catalogs. The main catalog is Locales/<xx>.lua, loaded at startup. Built In class rotation names and descriptions
live in Modules/RotationMaster_<Class>/Locales/. Each catalog has independent stable IDs; IDs from another catalog must
be written as catalog:id when using ID-based commands. `L["English text"]` always uses the exact English source text.
"""
import argparse
import datetime
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import locale_format as F  # noqa: E402
from copyright import TOC_LICENSE_FIELD, notice_line  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
LOCALES = F.LOCALES
lua_string = F.lua_string
text_hash = F.text_hash

REGISTRY_FILE = 'tools/locale_registry.json'
TRANSLATORS_FILE = 'tools/locale_translators.json'
BUNDLES_JSON = 'Locales/bundles.json'
INDEX_FILE = 'Data/text_bundle_index.lua'
# The interfaces every load-on-demand text add-on declares (the same list as the other Modules/ add-ons).
BUNDLE_INTERFACE = '11509, 20506, 50504, 120105, 16001'
AI_NOTE = 'AI-assisted, not yet reviewed by a native speaker'


# --------------------------------------------------------------------------------------------- catalogs

class Catalog:
    """One set of locale files: the main one (Locales/) or a text bundle (Modules/<module>/)."""

    def __init__(self, name, directory, module=None, title=None, notes=None, kind=None):
        self.name, self.directory, self.module = name, Path(directory), module
        self.title, self.notes = title, notes
        self.kind = kind

    @property
    def is_main(self):
        return self.module is None

    @property
    def is_class(self):
        return self.kind == 'class'

    # catalogs() builds fresh objects on every call: two views of the same catalog are the same catalog.
    def __eq__(self, other):
        return isinstance(other, Catalog) and other.name == self.name

    def __hash__(self):
        return hash(self.name)

    def path(self, locale):
        return self.directory / ('Locales' if self.is_class else '') / f'{locale}.lua'

    @property
    def english_path(self):
        return self.path('enUS')

    def label(self, locale):
        return locale if self.is_main else f'{locale} ({self.name})'

    def relative(self, locale='enUS'):
        return self.path(locale).relative_to(ROOT).as_posix()

    @property
    def description(self):
        if self.is_main:
            return 'Catalog "main": the text read while the game loads (Locales/, listed in locales.xml).'
        return f'Catalog "{self.name}": {self.title or self.name}, loaded on demand ({self.module}).'


def catalogs():
    """The main catalog first, then each text bundle named in Locales/bundles.json (read afresh: ROOT may change)."""
    found = [Catalog('main', ROOT / 'Locales')]
    manifest = ROOT / BUNDLES_JSON
    if manifest.exists():
        for row in json.loads(manifest.read_text(encoding='utf-8'))['bundles']:
            if row.get('kind') == 'builtin':
                continue
            found.append(Catalog(row['id'], ROOT / 'Modules' / row['module'], row['module'], row.get('title'), row.get('notes'), row.get('kind')))
    return found


def catalog_named(name):
    for catalog in catalogs():
        if catalog.name == name:
            return catalog
    raise SystemExit(f'unknown catalog {name!r}; known: {", ".join(c.name for c in catalogs())}')


# ---------------------------------------------------------------------------------------------- reading

_cache = {}


def _read(path):
    stat = path.stat()
    stamp = (stat.st_mtime_ns, stat.st_size)
    hit = _cache.get(path)
    if hit and hit[0] == stamp:
        return hit[1]
    value = path.read_text(encoding='utf-8')
    _cache[path] = (stamp, value)
    return value


def read_english_file(catalog):
    """(entries, problems) of a catalog's enUS.lua; each entry knows its catalog."""
    entries, problems = F.parse_english(_read(catalog.english_path))
    for entry in entries:
        entry.catalog = catalog
    return entries, problems


def english_entries(catalog=None):
    """Every English entry (all catalogs unless one is named), in catalog then ID order."""
    found = []
    for each in ([catalog] if catalog else catalogs()):
        if each.english_path.exists():
            found.extend(sorted(read_english_file(each)[0], key=lambda e: e.id))
    return found


def english(catalog=None):
    """key -> displayed English text."""
    return {e.key: e.text for e in english_entries(catalog)}


def by_id(catalog=None):
    return {e.id: e for e in english_entries(catalog or catalogs()[0])}


def by_key(catalog=None):
    return {e.key: e for e in english_entries(catalog)}


def owners():
    """key -> the catalog that holds its English."""
    return {e.key: e.catalog for e in english_entries()}


def read_locale_file(locale, catalog):
    """(entries, header, problems) of one translation file; ([], empty header, []) when it does not exist."""
    path = catalog.path(locale)
    if not path.exists():
        return [], {'translators': None, 'humans': None}, []
    return F.parse_locale(_read(path))


def locale_translations(locale, catalog=None):
    """Translations indexed by ID for one catalog, or (catalog, ID) for all catalogs."""
    found = {}
    for each in ([catalog] if catalog else catalogs()):
        for entry in read_locale_file(locale, each)[0]:
            found[entry.id if catalog else (each.name, entry.id)] = entry
    return found


def locale_entries(locale, catalog=None):
    """The (key, translation) entries of a locale in ID order, for IDs the English knows."""
    return [(e.key, t.text) for e, t in translated_entries(locale, catalog)]


def read_sources(locale, catalog=None):
    """key -> the English each entry was translated from (the comment above it)."""
    return {e.key: t.english for e, t in translated_entries(locale, catalog)}


def read_hashes(locale, catalog=None):
    """key -> the hash of the English each entry was translated from."""
    return {e.key: t.hash for e, t in translated_entries(locale, catalog)}


def translated_entries(locale, catalog=None):
    for each in ([catalog] if catalog else catalogs()):
        ids = by_id(each)
        for id, translation in sorted(locale_translations(locale, each).items()):
            if id in ids:
                yield ids[id], translation


def locale_files(locale):
    return [each.path(locale) for each in catalogs() if each.path(locale).exists()]


def is_locale_file(relative):
    """Whether a repository-relative path is a locale file of any catalog (they are text, not source code)."""
    relative = str(relative).replace('\\', '/')
    if re.fullmatch(r'Modules/RotationMaster_[^/]+/Locales/(?:enUS|' + '|'.join(LOCALES) + r')\.lua', relative):
        return True
    for each in catalogs():
        if relative.startswith(each.directory.relative_to(ROOT).as_posix() + '/') and Path(relative).stem in ['enUS'] + LOCALES:
            return True
    return False


# ----------------------------------------------------------------------------------- placeholder checks

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


# ------------------------------------------------------------------------------------------ the model

def today():
    return os.environ.get('RM_LOCALE_DATE') or datetime.date.today().isoformat()


class Model:
    """Everything the locale files say, in memory: English entries per catalog, the ID registry, the translator
    credits and (read on demand) each language's translations. Commands change it; `outputs()` renders the files
    that differ from disk and `write()` saves them."""

    def __init__(self):
        self.catalogs = catalogs()
        self.registry = self.load_json(REGISTRY_FILE, {'next': 1, 'retired': [], 'generated': {}, 'annotations': {}})
        self.credits = {k: v for k, v in self.load_json(TRANSLATORS_FILE, {}).items() if not k.startswith('_')}
        self.entries = {}
        for each in self.catalogs:
            self.entries[each.name] = [self._copy(e) for e in (read_english_file(each)[0] if each.english_path.exists() else [])]
        self._translations = {}
        self._dirty = set()

    # -- loading
    @staticmethod
    def load_json(relative, default):
        path = ROOT / relative
        if path.exists():
            data = json.loads(path.read_text(encoding='utf-8'))
            for key, value in default.items():
                data.setdefault(key, value)
            return data
        return default

    @staticmethod
    def _copy(entry):
        copy = F.English(entry.id, entry.key, entry.text, entry.hash, entry.line)
        copy.catalog = entry.catalog
        return copy

    def catalog(self, name):
        for each in self.catalogs:
            if each.name == name:
                return each
        raise SystemExit(f'unknown catalog {name!r}; known: {", ".join(c.name for c in self.catalogs)}')

    def all_entries(self):
        return [e for each in self.catalogs for e in self.entries[each.name]]

    def find_key(self, key):
        for e in self.all_entries():
            if e.key == key:
                return e

    def find_id(self, id, catalog='main'):
        for e in self.entries[catalog]:
            if e.id == id:
                return e

    def translations(self, locale, catalog):
        """{id: Translation}, mutable, for one language and catalog."""
        slot = (locale, catalog.name)
        if slot not in self._translations:
            self._translations[slot] = {e.id: e for e in read_locale_file(locale, catalog)[0]}
        return self._translations[slot]

    def mark(self, locale, catalog):
        self._dirty.add((locale, catalog.name))

    # -- registry
    def registry_for(self, catalog):
        name = catalog.name if isinstance(catalog, Catalog) else catalog
        if name == 'main':
            return self.registry
        return self.registry.setdefault('catalogs', {}).setdefault(name, {'next': 1, 'retired': [], 'annotations': {}})

    def new_id(self, catalog='main'):
        registry = self.registry_for(catalog)
        number = registry['next']
        registry['next'] = number + 1
        return number

    def retire(self, id, catalog='main'):
        registry = self.registry_for(catalog)
        if id not in registry['retired']:
            registry['retired'].append(id)
            registry['retired'].sort()
        registry.setdefault('annotations', {}).pop(str(id), None)
        for ids in registry.get('generated', {}).values():
            if id in ids:
                ids.remove(id)

    # -- annotations: the context and token notes a translator sees under the English
    def annotation(self, id, catalog='main'):
        return self.registry_for(catalog).setdefault('annotations', {}).get(str(id), {})

    def extras(self, entries):
        """{id: comment lines} for the entries that carry a context or token notes."""
        out = {}
        for e in entries:
            row = self.annotation(e.id, e.catalog)
            if row:
                out[e.id] = F.annotation_lines(e.text, row.get('notes'), row.get('context'))
        return out

    def set_annotation(self, id, notes=None, context=None, catalog='main'):
        """Replace the notes and/or context of an ID (None keeps, empty removes)."""
        table = self.registry_for(catalog).setdefault('annotations', {})
        row = dict(table.get(str(id), {}))
        if notes is not None:
            if notes:
                row['notes'] = [' '.join(str(n).split()) for n in notes]
            else:
                row.pop('notes', None)
        if context is not None:
            if context.strip():
                row['context'] = context.strip()
            else:
                row.pop('context', None)
        if row:
            table[str(id)] = row
        else:
            table.pop(str(id), None)

    # -- credits
    def credit_list(self, locale, catalog_name):
        return self.credits.setdefault(locale, {}).setdefault(catalog_name, [])

    def credit(self, locale, catalog_name, name, kind=None, url=None, strings=0, note=None):
        """Add or update a translator on one file; idempotent, deduplicated by name."""
        rows = self.credit_list(locale, catalog_name)
        row = next((r for r in rows if r['name'].casefold() == name.casefold()), None)
        date = today()
        if row is None:
            row = {'name': name, 'kind': kind or 'human'}
            if row['kind'] == 'ai':
                row['note'] = note or AI_NOTE
            rows.append(row)
        elif kind:
            row['kind'] = kind
            if kind == 'ai':
                row.setdefault('note', note or AI_NOTE)
            else:
                row.pop('note', None)
        if url:
            row['url'] = url
        if strings:
            row['strings'] = row.get('strings', 0) + strings
            row.setdefault('first', date)
            row['last'] = date
        # The main file lists the language's human translators of every catalog.
        self.mark(locale, self.catalogs[0])
        return row

    # -- adding, removing, moving
    def add(self, key, text=None, catalog='main', id=None):
        text = key if text is None else text
        if key != text:
            raise SystemExit('the English source key and English text must be identical')
        target = self.catalog(catalog)
        if not target.is_main and not target.is_class:
            raise SystemExit('English text must be in the main or a class catalog')
        if self.find_key(key):
            raise SystemExit(f'{key!r} already exists')
        entry = F.English(id if id is not None else self.new_id(catalog), key, text, text_hash(text), 0)
        entry.catalog = self.catalog(catalog)
        self.entries[catalog].append(entry)
        return entry

    def remove(self, key):
        entry = self.find_key(key)
        if not entry:
            raise SystemExit(f'{key!r} is not a key of any catalog')
        self.entries[entry.catalog.name].remove(entry)
        self.retire(entry.id, entry.catalog)
        for locale in LOCALES:
            each = entry.catalog
            if entry.id in self.translations(locale, each):
                del self.translations(locale, each)[entry.id]
                self.mark(locale, each)
        return entry

    def move(self, entry, target_name):
        source = entry.catalog
        target = self.catalog(target_name)
        if source == target:
            return
        if not target.is_main and not target.is_class:
            raise SystemExit('English text must be in the main or a class catalog')
        old_id = entry.id
        annotation = self.annotation(old_id, source)
        self.entries[source.name].remove(entry)
        self.retire(old_id, source)
        entry.id = self.new_id(target)
        entry.catalog = target
        if annotation:
            self.registry_for(target).setdefault('annotations', {})[str(entry.id)] = annotation
        self.entries[target.name].append(entry)
        for locale in LOCALES:
            moved = self.translations(locale, source).pop(old_id, None)
            if moved is None:
                continue
            moved.id = entry.id
            self.translations(locale, target)[entry.id] = moved
            self.mark(locale, source)
            self.mark(locale, target)
            have = {r['name'].casefold() for r in self.credit_list(locale, target.name)}
            for row in self.credit_list(locale, source.name):
                if row['name'].casefold() not in have:
                    self.credit_list(locale, target.name).append({k: v for k, v in row.items() if k not in ('strings', 'first', 'last')})
                    have.add(row['name'].casefold())

    def sync_group(self, group, texts):
        """Make the strings a generator owns (`group` in the registry) exactly `texts`, each its own English, in main."""
        owned = self.registry.setdefault('generated', {}).setdefault(group, [])
        wanted = set(texts)
        for id in list(owned):
            entry = self.find_id(id)
            if entry is not None and entry.key not in wanted:
                self.remove(entry.key)
        owned[:] = [i for i in owned if self.find_id(i) is not None]
        for text in sorted(wanted):
            entry = self.find_key(text)
            if entry is None:
                entry = self.add(text)
            if entry.id not in owned and entry.catalog.is_main and entry.text == entry.key:
                owned.append(entry.id)
        owned.sort()

    # -- rendering
    def outputs(self):
        """{repository-relative path: text} for everything this model would write that differs from disk."""
        out = {}

        def put(relative, text):
            path = ROOT / relative
            if not path.exists() or path.read_text(encoding='utf-8') != text:
                out[relative] = text
        for each in self.catalogs:
            seen = {}
            for e in self.entries[each.name]:
                if e.id in seen:
                    raise SystemExit(f'ID {e.id} is used by {seen[e.id]!r} and {e.key!r}')
                seen[e.id] = e.key
                if e.id >= self.registry_for(each)['next']:
                    raise SystemExit(f'ID {e.id} ({e.key!r}) is not below the registry counter for {each.name}')
            put(each.relative(), F.render_english(self.entries[each.name], each.description, self.extras(self.entries[each.name]), central_locale=each.is_class))
        put(REGISTRY_FILE, render_registry(self.registry))
        put(TRANSLATORS_FILE, render_translators(self.credits))
        put(INDEX_FILE, index_text(self.entries, self.catalogs))
        for locale, name in sorted(self._dirty):
            each = self.catalog(name)
            known = {e.id for e in self.entries[name]}
            rows = [t for i, t in self.translations(locale, each).items() if i in known]
            if not rows and not each.path(locale).exists():
                continue
            put(each.relative(locale), F.render_locale(locale, rows, self.credit_list(locale, name), self.extras(self.entries[name]),
                                                       humans_for(self.credits, locale, name)))
        return out

    def write(self):
        out = self.outputs()
        for relative, text in out.items():
            path = ROOT / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding='utf-8')
        for each in self.catalogs:
            if each.is_class:
                ensure_class_locales(each)
            elif not each.is_main:
                ensure_bundle_toc(each)
        for locale in LOCALES:
            for each in self.catalogs:
                if each.path(locale).exists():
                    ensure_registered(locale, each)
        _cache.clear()
        return out


def humans_for(credits, locale, catalog_name):
    """The names the About page credits for a file. The main file carries every catalog's human translators of the
    language (so the About page never has to load a bundle); a bundle file carries its own."""
    sources = [name for name in credits.get(locale, {})] if catalog_name == 'main' else [catalog_name]
    if catalog_name == 'main':
        sources.sort(key=lambda name: name != 'main')
    names, seen = [], set()
    for source in sources:
        for row in credits.get(locale, {}).get(source, []):
            if row.get('kind') != 'ai' and row['name'].casefold() not in seen:
                seen.add(row['name'].casefold())
                names.append(row['name'])
    return names


def render_registry(registry):
    lines = ['{',
             '  "_comment": "Stable string IDs, append-only (tools/locales.py owns this file). next is the ID the next new string gets; retired lists IDs of removed strings, which are never reused; generated names the IDs a generator owns (tools/generate_builtin_sources.py); annotations holds, per ID, an optional context (where the string shows and its role) and notes (one per format token, in order), which every locale file renders as comments under the English.",',
             f'  "next": {registry["next"]},',
             f'  "retired": {json.dumps(registry["retired"])},',
             '  "generated": {']
    groups = sorted(registry.get('generated', {}).items())
    for n, (name, ids) in enumerate(groups):
        lines.append(f'    {json.dumps(name)}: {json.dumps(sorted(ids))}' + (',' if n < len(groups) - 1 else ''))
    lines += ['  },', '  "annotations": {']
    rows = sorted(registry.get('annotations', {}).items(), key=lambda kv: int(kv[0]))
    for n, (id, row) in enumerate(rows):
        lines.append(f'    {json.dumps(id)}: {json.dumps(row, ensure_ascii=False)}' + (',' if n < len(rows) - 1 else ''))
    lines += ['  },', '  "catalogs": ' + json.dumps(registry.get('catalogs', {}), ensure_ascii=False, sort_keys=True, indent=2).replace('\n', '\n  '), '}', '']
    return '\n'.join(lines)


def render_translators(credits):
    comment = ('Who translated which file (tools/locales.py owns this file; it writes the "-- Translators:" header and the '
               'L[0] table of each locale file from it). kind is human or ai; only humans are credited on the About page.')
    data = {'_comment': comment}
    for locale in sorted(credits):
        data[locale] = {name: rows for name, rows in credits[locale].items() if rows}
    return json.dumps(data, ensure_ascii=False, indent=1) + '\n'


# --------------------------------------------------------------------------------- registration files

def ensure_registered(locale, catalog=None):
    catalog = catalog or catalogs()[0]
    if catalog.is_class:
        ensure_class_locales(catalog)
        return
    if catalog.is_main:
        xml = ROOT / 'locales.xml'
        text = xml.read_text(encoding='utf-8')
        present = [l for l in LOCALES if f'Locales\\{l}.lua' in text or l == locale]
        block = '\n'.join(f'<Script file="Locales\\{l}.lua" />' for l in sorted(present) + ['enUS'])
        new = re.sub(r'<Script file="Locales\\[A-Za-z]{4}\.lua" />(?:\n<Script file="Locales\\[A-Za-z]{4}\.lua" />)*',
                     lambda m: block, text, count=1)
        if new != text:
            xml.write_text(new, encoding='utf-8')
        return
    ensure_bundle_toc(catalog)


def ensure_class_locales(catalog):
    """Register a class module's translations in each flavour after its bootstrap."""
    xml = catalog.directory / 'locales.xml'
    lines = ['<?xml version="1.0" encoding="utf-8"?>',
             '<!-- ' + F.COPYRIGHT.removeprefix('-- ') + ' -->',
             '<Ui xmlns="http://www.blizzard.com/wow/ui/">']
    lines.extend(f'<Script file="Locales\\{name}" />' for name in bundle_files(catalog))
    lines.extend(['</Ui>', ''])
    content = '\n'.join(lines)
    if not xml.exists() or xml.read_text(encoding='utf-8') != content:
        xml.write_text(content, encoding='utf-8')
    for toc in catalog.directory.glob(f'{catalog.module}_*.toc'):
        text = toc.read_text(encoding='utf-8')
        if '\nbind.lua\n' in text and '\nlocales.xml\n' not in text:
            toc.write_text(text.replace('\nbind.lua\n', '\nbind.lua\nlocales.xml\n', 1), encoding='utf-8')


def bundle_files(catalog):
    """Translations first and the English last: the English file joins the language's table to its own."""
    return [f'{l}.lua' for l in LOCALES if catalog.path(l).exists()] + ['enUS.lua']


def toc_path(catalog):
    return catalog.directory / f'{catalog.module}.toc'


def ensure_bundle_toc(catalog):
    """The add-on's TOC lists the locale files first (the translations, then enUS last); a new add-on gets a whole TOC."""
    toc = toc_path(catalog)
    files = bundle_files(catalog)
    if not toc.exists():
        header = [notice_line('toc'), f'## Interface: {BUNDLE_INTERFACE}',
                  f'## Title: Rotation Master - {catalog.title or catalog.name}',
                  f'## Notes: {catalog.notes or "Text Rotation Master shows on one screen."} Rotation Master loads this itself, the first time that text is needed; it holds only translations.',
                  '## Author: PreZ', '## Version: @project-version@', '## Dependencies: RotationMaster', '## LoadOnDemand: 1',
                  '## Group: RotationMaster', '## X-Category: Action Bars', TOC_LICENSE_FIELD, '']
        toc.write_text('\n'.join(header + files) + '\n', encoding='utf-8')
        return
    lines = toc.read_text(encoding='utf-8').splitlines()
    listed = {f'{l}.lua' for l in ['enUS'] + LOCALES}
    rest = [l for l in lines if l.strip() not in listed]
    # Insert the locale files where the first of them was (or before the first non-comment file line).
    position = next((i for i, l in enumerate(lines) if l.strip() in listed), None)
    if position is not None:
        rest[position:position] = files
    else:
        for index, line in enumerate(rest):
            if line.strip() and not line.startswith('#'):
                rest[index:index] = files
                break
        else:
            rest.extend(files)
    new = '\n'.join(rest).rstrip('\n') + '\n'
    if new != toc.read_text(encoding='utf-8'):
        toc.write_text(new, encoding='utf-8')


# ---------------------------------------------------------------------------------------- the key index

def key_hash(key):
    """The 32-bit hash Core/text_bundles.lua computes: h = h * 31 + byte, modulo 2^32, over the UTF-8 bytes."""
    h = 0
    for byte in key.encode('utf-8'):
        h = (h * 31 + byte) % 4294967296
    return h


def _chunks(hashes):
    pieces = [''.join(f'{h:08x}' for h in hashes[i:i + 16]) for i in range(0, len(hashes), 16)]
    return ' ..\n            '.join(f'"{c}"' for c in pieces) if pieces else '""'


def index_text(entries, cats):
    """Data/text_bundle_index.lua from {catalog name: [English entries]}."""
    import builtin_locales
    cats = list(cats)
    entries = dict(entries)
    for row in builtin_locales.classes(ROOT):
        catalog = Catalog(row['id'], ROOT / 'Modules' / row['module'], row['module'], kind='builtin')
        cats.append(catalog)
        values = builtin_locales.read(catalog.directory / 'Locales/enUS.lua')
        entries[catalog.name] = [F.English(0, key, value, text_hash(value), 0) for key, value in values.items()]
    rows, owner_of_hash = [], {}
    for each in cats:
        if each.is_main:
            continue
        for e in entries[each.name]:
            other = owner_of_hash.setdefault(key_hash(e.key), (each.name, e.key))
            if other[0] != each.name:
                raise SystemExit(f'{e.key!r} ({each.name}) and {other[1]!r} ({other[0]}) share a 32-bit hash: '
                                 'the runtime could not tell their bundles apart; change the wording of one')
    for each in cats:
        if each.is_main:
            continue
        hashes = sorted({key_hash(e.key) for e in entries[each.name]})
        symbolic = sorted({key_hash(e.key) for e in entries[each.name] if e.key != e.text})
        rows.append(f'    {{ id = "{each.name}", module = "{each.module}", count = {len(hashes)}, keys =\n            {_chunks(hashes)},\n'
                    f'      symbolicCount = {len(symbolic)}, symbolic =\n            {_chunks(symbolic)} }},')
    return (F.COPYRIGHT + '\n'
            '-- Generated by tools/locales.py index from Locales/bundles.json and each text bundle\'s enUS.lua; do not edit.\n'
            '-- Which load-on-demand text bundle owns an English key: the sorted 32-bit hashes of every key (h = h * 31 + byte,\n'
            '-- modulo 2^32, over the UTF-8 bytes), eight hex digits each. Core/text_bundles.lua binary-searches them.\n'
            '-- `symbolic` is the subset read under a key that is not its text: an English game must load the bundle for those\n'
            '-- and for nothing else, because every other key is its own English.\n'
            'local _, addon = ...\n'
            'addon.textBundleIndex = {\n' + '\n'.join(rows) + '\n}\n')


def cmd_index(check=False):
    model = Model()
    expected = index_text(model.entries, model.catalogs)
    path = ROOT / INDEX_FILE
    if check:
        if not path.exists() or path.read_text(encoding='utf-8') != expected:
            raise SystemExit(f'{INDEX_FILE} is stale: run python3 tools/locales.py index')
        return True
    path.write_text(expected, encoding='utf-8')
    print(f'{INDEX_FILE}: {sum(len(model.entries[c.name]) for c in model.catalogs if not c.is_main)} keys in {len(model.catalogs) - 1} bundles')


# ------------------------------------------------------------------------------------------- commands

def cmd_export():
    rows = []
    for e in english_entries():
        row = {'id': e.id, 'key': e.key, 'en': e.text}
        if not e.catalog.is_main:
            row['bundle'] = e.catalog.name
        rows.append(row)
    json.dump(sorted(rows, key=lambda r: r['id']), sys.stdout, ensure_ascii=False, indent=1)


def classify(locale):
    """(untranslated entries, stale (entry, translation) pairs) for one language, in ID order."""
    have = locale_translations(locale)
    untranslated, stale = [], []
    for e in sorted(english_entries(), key=lambda e: e.id):
        t = have.get((e.catalog.name, e.id))
        if t is None:
            untranslated.append(e)
        elif t.hash != e.hash:
            stale.append((e, t))
    return untranslated, stale


def missing_rows(locale):
    untranslated, stale = classify(locale)
    rows = []
    for e in untranslated:
        rows.append({'id': e.id, 'key': e.key, 'en': e.text, 'reason': 'untranslated', 'bundle': e.catalog.name})
    for e, t in stale:
        rows.append({'id': e.id, 'key': e.key, 'en': e.text, 'reason': 'stale', 'bundle': e.catalog.name,
                     'previous_en': t.english, 'translation': t.text})
    for row in rows:
        if row['bundle'] == 'main':
            del row['bundle']
    return sorted(rows, key=lambda r: r['id'])


def cmd_missing(locale):
    """The IDs the language lacks and the IDs whose translation was made from older English; nothing else."""
    json.dump(missing_rows(locale), sys.stdout, ensure_ascii=False, indent=1)


def resolve_ids(incoming, model):
    """{(catalog, id): text}; numeric IDs refer to main, catalog:id to a named catalog."""
    out = {}
    for name, text in incoming.items():
        if isinstance(name, str) and re.fullmatch(r'[^:]+:\d+', name):
            catalog, number = name.rsplit(':', 1)
            model.catalog(catalog)
            found = model.find_id(int(number), catalog)
        elif isinstance(name, int) or (isinstance(name, str) and name.isdigit()):
            found = model.find_id(int(name))
            other = model.find_key(str(name))
            if found and other and other is not found:
                raise SystemExit(f'{name!r} is both an ID and a key; use the other spelling in the work file')
            found = found or other
        else:
            found = model.find_key(name)
        if not found:
            raise SystemExit(f'{name!r}: not an ID or key of the English')
        slot = (found.catalog.name, found.id)
        if slot in out:
            raise SystemExit(f'ID {found.catalog.name}:{found.id} supplied twice')
        out[slot] = text
    return out


def build(locale, incoming, translator=None, kind=None, url=None, note=None):
    """Merge {id or key: text} into the locale files of `locale`. Credits `translator` on every file written."""
    assert locale in LOCALES, f'unknown locale {locale}'
    model = Model()
    ids = resolve_ids(incoming, model)
    errors = []
    for (catalog, id), text in ids.items():
        entry = model.find_id(id, catalog)
        for p in problems(entry.key, entry.text, text):
            errors.append(f'{id} {entry.key[:60]!r}: {p}')
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        raise SystemExit(f'{len(errors)} problem(s); nothing written')
    for each in model.catalogs:
        mine = {i: t for (catalog, i), t in ids.items() if catalog == each.name}
        current = model.translations(locale, each)
        if not mine and not current and not each.path(locale).exists():
            continue  # a bundle with nothing to say in this language yet has no file
        changed = 0
        for id, text in mine.items():
            entry = model.find_id(id, each.name)
            old = current.get(id)
            if old is None or old.text != text or old.hash != entry.hash:
                changed += 1
            current[id] = F.Translation(id, text, entry.hash, entry.text, 0)
        model.mark(locale, each)
        if translator and mine:
            model.credit(locale, each.name, translator, kind=kind, url=url, strings=changed, note=note)
    written = model.write()
    for each in model.catalogs:
        if each.path(locale).exists():
            print(f'{each.label(locale)}: {len(model.translations(locale, each))}/{len(model.entries[each.name])} entries')
    return written


def cmd_build(locale, translation_path, **credit):
    build(locale, json.loads(Path(translation_path).read_text(encoding='utf-8')), **credit)


def cmd_accept(locale, id_args):
    """Record the current English as the one the stale translations were checked against."""
    model = Model()
    wanted = {(part.rsplit(':', 1)[0], int(part.rsplit(':', 1)[1])) if ':' in part else ('main', int(part)) for part in id_args}
    count = 0
    for each in model.catalogs:
        current = model.translations(locale, each)
        for e in model.entries[each.name]:
            t = current.get(e.id)
            if t is not None and t.hash != e.hash and (not wanted or (each.name, e.id) in wanted):
                current[e.id] = F.Translation(e.id, t.text, e.hash, e.text, 0)
                model.mark(locale, each)
                count += 1
    model.write()
    print(f'{locale}: {count} stale translation(s) accepted')


def cmd_credit(locale, translator, kind=None, url=None, strings=0, catalog_name=None):
    model = Model()
    if catalog_name:
        import builtin_locales
        row = next((r for r in builtin_locales.classes(ROOT) if r['id'] == catalog_name), None)
        if row:
            path = ROOT / 'Modules' / row['module'] / 'Locales' / f'{locale}.lua'
            if not path.exists():
                raise SystemExit(f'{path.relative_to(ROOT)} does not exist')
            model.credit(locale, catalog_name, translator, kind=kind, url=url, strings=strings)
            model.write()
            builtin_locales.write_credit_header(path, model.credit_list(locale, catalog_name))
            print(f'{locale} ({catalog_name}): credited {translator}')
            return
        model.catalog(catalog_name)
    for each in model.catalogs:
        if (not catalog_name or each.name == catalog_name) and each.path(locale).exists():
            model.translations(locale, each)
            model.credit(locale, each.name, translator, kind=kind, url=url, strings=strings)
            model.mark(locale, each)
    model.write()
    print(f'{locale}: credited {translator}')


def cmd_rebuild():
    """Rewrite every file from what it says: canonical layout, generated headers, TOCs and the index."""
    model = Model()
    for locale in LOCALES:
        for each in model.catalogs:
            if each.path(locale).exists():
                model.translations(locale, each)
                model.mark(locale, each)
    out = model.write()
    print(f'rebuilt: {len(out)} file(s) changed')


def cmd_bundles():
    for each in catalogs():
        count = len(english(each)) if each.english_path.exists() else 0
        print(f'{each.name:14} {count:5} keys  {each.directory.relative_to(ROOT).as_posix()}' + ('' if each.is_main else f'  ({each.module})'))


def cmd_move(target_name, keys_path):
    """Move keys between catalogs: their English and every locale's translation, with their IDs."""
    model = Model()
    model.catalog(target_name)
    keys = json.loads(Path(keys_path).read_text(encoding='utf-8'))
    assert isinstance(keys, list) and all(isinstance(k, str) for k in keys), 'KEYS.json must be a JSON list of strings'
    unknown = [k for k in keys if not model.find_key(k)]
    if unknown:
        raise SystemExit(f'not an English key: {unknown[0]!r} (and {len(unknown) - 1} more)')
    moving = [model.find_key(k) for k in keys if model.find_key(k).catalog.name != target_name]
    for entry in moving:
        model.move(entry, target_name)
    model.write()
    print(f'moved {len(moving)} key(s) into {target_name}')


# ------------------------------------------------------------------------------------------------ check

def cmd_check(complete=False, require_notes=False, require_context=False, context_words=3):
    failures = 0

    def fail(message):
        nonlocal failures
        failures += 1
        print(message)
    cats = catalogs()
    registry = Model.load_json(REGISTRY_FILE, {'next': 1, 'retired': [], 'generated': {}})
    credits = {k: v for k, v in Model.load_json(TRANSLATORS_FILE, {}).items() if not k.startswith('_')}
    seen_id, seen_key, en = {}, {}, {}
    for catalog in cats:
        catalog_registry = registry if catalog.is_main else registry.get('catalogs', {}).get(catalog.name, {'next': 1, 'retired': [], 'annotations': {}})
        annotations = catalog_registry.get('annotations', {})
        if not catalog.english_path.exists():
            fail(f'{catalog.relative()}: missing')
            continue
        text = _read(catalog.english_path)
        if text.split('\n', 1)[0] != F.COPYRIGHT:
            fail(f'{catalog.relative()}: the first line must be the copyright line')
        entries, parse_problems = F.parse_english(text)
        for p in parse_problems:
            fail(f'{catalog.relative()}: {p}')
        if re.search(r'(?m)^(?:local S\s*=|local P\s*=|local N\s*=|N\[)', text):
            fail(f'{catalog.relative()}: expected direct T[english] = id assignments')
        if not catalog.is_main and not catalog.is_class and entries:
            fail(f'{catalog.relative()}: text must be in the main catalog for startup loading')
        en[catalog.name] = {}
        for e in entries:
            if e.key != e.text:
                fail(f'{catalog.relative()}:{e.line}: English key must equal its displayed text')
            slot = (catalog.name, e.id)
            if slot in seen_id:
                fail(f'ID {catalog.name}:{e.id} is in both {seen_id[slot]!r} and {e.key!r}')
            seen_id.setdefault(slot, e.key)
            if e.key in seen_key:
                fail(f'{e.key!r} is in both the {seen_key[e.key]} catalog and the {catalog.name} catalog')
            seen_key.setdefault(e.key, catalog.name)
            if e.hash != text_hash(e.text):
                fail(f'{catalog.relative()}:{e.line}: ID {e.id} records hash {e.hash} but its text hashes to {text_hash(e.text)} (run `locales.py rebuild`)')
            if e.id >= catalog_registry['next']:
                fail(f'ID {catalog.name}:{e.id} is not below the registry counter {catalog_registry["next"]}')
            if e.id in catalog_registry['retired']:
                fail(f'ID {e.id} ({e.key!r}) was retired and must not be reused')
            en[catalog.name][e.id] = e
            row = annotations.get(str(e.id), {})
            want = F.annotation_lines(e.text, row.get('notes'), row.get('context'))
            if e.annotations != want:
                fail(f'{catalog.relative()}:{e.line}: ID {e.id}: the context/notes comments do not match {REGISTRY_FILE} (run `locales.py rebuild`)')
            tokens_here = F.format_tokens(e.text)
            if row.get('notes') and len(row['notes']) != len(tokens_here):
                fail(f'ID {e.id} {e.key[:50]!r}: {len(row["notes"])} note(s) for {len(tokens_here)} format token(s) {tokens_here}')
            if require_notes and tokens_here and not row.get('notes'):
                fail(f'ID {e.id} {e.key[:50]!r}: has {len(tokens_here)} format token(s) {tokens_here} and no notes (locales.py notes todo)')
            if require_context and is_short(e.text, context_words) and not row.get('context'):
                fail(f'ID {e.id} {e.key[:50]!r}: short string without context (locales.py notes todo)')
    for catalog in cats:
        annotations = (registry if catalog.is_main else registry.get('catalogs', {}).get(catalog.name, {})).get('annotations', {})
        for id in annotations:
            if (catalog.name, int(id)) not in seen_id:
                fail(f'{REGISTRY_FILE}: annotations for ID {catalog.name}:{id}, which no catalog holds')
    for group, ids in registry.get('generated', {}).items():
        for id in ids:
            if ('main', id) not in seen_id:
                fail(f'registry group {group!r} names ID {id}, which no catalog holds')
    all_ids = {(name, i): e for name, rows in en.items() for i, e in rows.items()}
    for locale in LOCALES:
        total = stale = 0
        any_file = False
        for catalog in cats:
            annotations = (registry if catalog.is_main else registry.get('catalogs', {}).get(catalog.name, {})).get('annotations', {})
            path = catalog.path(locale)
            if not path.exists():
                continue
            any_file = True
            text = _read(path)
            label = catalog.label(locale)
            if text.split('\n', 1)[0] != F.COPYRIGHT:
                fail(f'{catalog.relative(locale)}: the first line must be the copyright line')
            registrations = re.findall(r'NewLocale\(addon_name, "(\w+)", (\w+), (\w+)\)', text)
            if registrations != [(locale, 'false', 'true')]:
                fail(f'{catalog.relative(locale)}: must call NewLocale(addon_name, "{locale}", false, true) exactly once; rebuild it')
            entries, header, parse_problems = F.parse_locale(text)
            for p in parse_problems:
                fail(f'{catalog.relative(locale)}: {p}')
            rows = credits.get(locale, {}).get(catalog.name, [])
            if header['translators'] != F.translators_header(rows):
                fail(f'{catalog.relative(locale)}: the "-- Translators:" header does not match {TRANSLATORS_FILE} (run `locales.py rebuild`)')
            if header['humans'] != humans_for(credits, locale, catalog.name):
                fail(f'{catalog.relative(locale)}: the L[0] translator table does not match {TRANSLATORS_FILE} (run `locales.py rebuild`)')
            ids = set()
            for t in entries:
                if t.id in ids:
                    fail(f'{catalog.relative(locale)}:{t.line}: ID {t.id} appears twice')
                ids.add(t.id)
                english_entry = en.get(catalog.name, {}).get(t.id)
                if english_entry is None:
                    fail(f'{label} ID {t.id}: not an ID of this catalog (enUS)')
                    continue
                for p in problems(english_entry.key, english_entry.text, t.text):
                    fail(f'{label} ID {t.id} {english_entry.key[:60]!r}: {p}')
                if t.hash is not None and t.english is not None and text_hash(t.english) != t.hash:
                    fail(f'{catalog.relative(locale)}:{t.line}: ID {t.id}: the English in the comment does not match its hash {t.hash}')
                if t.annotations != F.annotation_lines(english_entry.text, annotations.get(str(t.id), {}).get('notes'), annotations.get(str(t.id), {}).get('context')):
                    fail(f'{catalog.relative(locale)}:{t.line}: ID {t.id}: the context/notes comments do not match {REGISTRY_FILE} (run `locales.py rebuild`)')
                if t.hash != english_entry.hash:
                    stale += 1
            total += len(entries)
            if catalog.is_main:
                if f'Locales\\{locale}.lua' not in (ROOT / 'locales.xml').read_text(encoding='utf-8'):
                    fail(f'{locale}: not listed in locales.xml')
            elif catalog.is_class:
                xml = catalog.directory / 'locales.xml'
                if not xml.exists() or f'file="Locales\\{locale}.lua"' not in xml.read_text(encoding='utf-8'):
                    fail(f'{catalog.relative(locale)}: not listed in {xml.relative_to(ROOT)}')
            else:
                toc = toc_path(catalog)
                if not toc.exists() or f'{locale}.lua' not in toc.read_text(encoding='utf-8').split():
                    fail(f'{catalog.relative(locale)}: not listed in {toc.relative_to(ROOT).as_posix()}')
        if any_file:
            untranslated = len(all_ids) - total
            print(f'{locale}: {total}/{len(all_ids)} entries, {stale} stale, {untranslated} untranslated')
            if complete and (stale or untranslated):
                fail(f'{locale}: not complete ({stale} stale, {untranslated} untranslated)')
    listed = re.findall(r'<Script file="Locales\\(\w+)\.lua" />', (ROOT / 'locales.xml').read_text(encoding='utf-8'))
    if listed[-1:] != ['enUS']:
        fail("locales.xml: enUS.lua must be listed last (it joins the language's table to its own English)")
    for catalog in cats:
        if catalog.is_class:
            xml = catalog.directory / 'locales.xml'
            if not xml.exists() or 'file="Locales\\enUS.lua"' not in xml.read_text(encoding='utf-8'):
                fail(f'{catalog.module}: class locales must list enUS.lua last')
            for toc in catalog.directory.glob(f'{catalog.module}_*.toc'):
                text = toc.read_text(encoding='utf-8')
                if '\nbind.lua\n' in text and '\nlocales.xml\n' not in text:
                    fail(f'{toc.relative_to(ROOT)}: class locales are not listed')
        elif not catalog.is_main:
            toc = toc_path(catalog)
            files = [l for l in toc.read_text(encoding='utf-8').split() if l.endswith('.lua')] if toc.exists() else []
            if files[-1:] != ['enUS.lua']:
                fail(f'{toc.relative_to(ROOT).as_posix()}: must list enUS.lua last')
    if len(cats) > 1:
        try:
            cmd_index(check=True)
        except SystemExit as error:
            fail(str(error))
        print('catalogs: ' + ', '.join(f'{c.name} {len(en.get(c.name, {}))}' for c in cats))
    if failures:
        raise SystemExit(f'{failures} locale problem(s)')


# ------------------------------------------------------------------------------- code: reword, add, sync

def lua_literal(value, quote='"'):
    out = [quote]
    for ch in value:
        if ch == '\\':
            out.append('\\\\')
        elif ch == quote:
            out.append('\\' + quote)
        elif ch == '\n':
            out.append('\\n')
        elif ord(ch) < 32 or ord(ch) == 127:
            out.append('\\%03d' % ord(ch))
        else:
            out.append(ch)
    out.append(quote)
    return ''.join(out)


def string_sites(source, value):
    """(start, end, in_L) of every whole string literal in Lua source whose value is `value`; in_L is the L["..."] form.
    Only a literal that is exactly the string counts: the old English inside a longer string is never touched."""
    import catalog_check
    toks = []
    for m in catalog_check.TOKEN.finditer(source):
        if m.lastgroup not in ('space', 'comment'):
            toks.append((m.lastgroup, m.group(), m.start(), m.end()))
    found = []
    for i, (kind, text, start, end) in enumerate(toks):
        if kind in ('string', 'long') and catalog_check.decode_string(text) == value:
            in_l = i >= 2 and toks[i - 2][1] == 'L' and toks[i - 1][1] == '[' and i + 1 < len(toks) and toks[i + 1][1] == ']'
            found.append((start, end, in_l))
    return found


def lua_sources(include_tests=False):
    import catalog_check
    files = list(catalog_check.sources(ROOT))
    if include_tests:
        files += sorted(p for p in (ROOT / 'tests').rglob('*.lua') if not any(part.startswith('.') for part in p.relative_to(ROOT).parts))
    return [p for p in files if not is_locale_file(p.relative_to(ROOT).as_posix())]


def cmd_reword(old, new, dry_run=False, all_literals=False, tests=False):
    """Change English in code and enUS, keeping the ID. Translations stay and become stale by hash."""
    if old == new:
        raise SystemExit('the old and new English are the same')
    model = Model()
    by_key_match = [e for e in model.all_entries() if e.key == old]
    by_text_match = [e for e in model.all_entries() if e.text == old and e.key != old]
    if len(by_key_match) + len(by_text_match) != 1:
        if not by_key_match and not by_text_match:
            raise SystemExit(f'no string has the English {old!r}')
        raise SystemExit(f'{old!r} is ambiguous: ' + ', '.join(f'ID {e.id} ({e.key[:40]!r})' for e in by_key_match + by_text_match))
    entry = (by_key_match or by_text_match)[0]
    rewrites_code = bool(by_key_match)
    if rewrites_code:
        if entry.text == entry.key:
            new_text = new
        elif entry.text == entry.key.replace('|', '||'):
            new_text = new.replace('|', '||')
        else:
            raise SystemExit(f'{old!r} is the symbolic key of ID {entry.id}; reword its English text instead of renaming a key')
        clash = model.find_key(new)
        if clash is not None:
            raise SystemExit(f'{new!r} already exists (ID {clash.id})')
    else:
        new_text = new
    plan, notes = [], []
    if rewrites_code:
        in_scope = set(lua_sources(include_tests=tests))
        for path in lua_sources(include_tests=True):
            source = path.read_text(encoding='utf-8')
            if old not in source and lua_literal(old) not in source and lua_literal(old, "'") not in source:
                continue
            sites = string_sites(source, old)
            where = path.relative_to(ROOT).as_posix()
            take = [s for s in sites if path in in_scope and (s[2] or all_literals)]
            if take:
                plan.append((path, source, take))
            for start, end, in_l in sites:
                if (start, end, in_l) in take:
                    continue
                line = source.count('\n', 0, start) + 1
                notes.append(f'{where}:{line}: spells the old English' + (' in L[...]' if in_l else ' as a plain string')
                             + (' but is outside the rewritten files (--tests)' if path not in in_scope else ' and was left alone (--all-literals changes it)'))
    count = sum(len(s) for _, _, s in plan)
    if rewrites_code and not any(in_l for _, _, sites in plan for _, _, in_l in sites) and not all_literals:
        raise SystemExit(f'no L["..."] site spells {old!r} in the addon: the key is built in code or read through a variable, '
                         'so rewording it here would leave the code reading the old text. Change the code by hand and use '
                         '`locales.py add` / `remove`, or pass --all-literals to change plain strings too.')
    print(f'ID {entry.id}: {old[:70]!r} -> {new[:70]!r}'
          + (f' ({count} code site(s) in {len(plan)} file(s))' if rewrites_code else ' (English text only; the code reads a key that does not change)'))
    for note in notes:
        print('  note: ' + note)
    if dry_run:
        return
    for path, source, sites in plan:
        for start, end, _ in sorted(sites, reverse=True):
            if source[start] == '[':  # a long bracket string keeps its level, widened if the text contains the closer
                level = re.match(r'\[(=*)\[', source[start:]).group(1)
                while ']' + level + ']' in new:
                    level += '='
                literal = f'[{level}[{new}]{level}]'
            else:
                literal = lua_literal(new, source[start])
            source = source[:start] + literal + source[end:]
        path.write_text(source, encoding='utf-8')
    if rewrites_code:
        entry.key = new
    entry.text = new_text
    entry.hash = text_hash(new_text)
    model.write()
    stale = sum(1 for locale in LOCALES if entry.id in model.translations(locale, entry.catalog))
    print(f'kept ID {entry.id}; {stale} translation(s) are now stale (python3 tools/locales.py missing <xx> lists them)')


SENTENCE_PUNCTUATION = re.compile(r'[.!?:;]')


def is_short(text, words=3):
    """A label or option a translator cannot place without context: few words, no sentence punctuation, some letters."""
    plain = F.FORMAT_SCAN.sub('', text)
    return (len(plain.split()) <= words and not SENTENCE_PUNCTUATION.search(plain.rstrip(':')) and bool(re.search(r'[^\W\d_]', plain))
            and '\n' not in plain)


def call_sites(keys):
    """{key: ["path:line", ...]} for every literal L["key"] read (concatenations of literals included) in the addon."""
    import catalog_check
    wanted = set(keys)
    found = {}
    for path in lua_sources():
        text = path.read_text(encoding='utf-8')
        if 'L[' not in text and 'L [' not in text:
            continue
        for key, line, _ in literal_reads(text):
            if key in wanted:
                found.setdefault(key, []).append(f'{path.relative_to(ROOT).as_posix()}:{line}')
    return found


def literal_reads(source):
    """(key, line, assigned) of every L[<literal or literals joined by ..>] in Lua source."""
    import catalog_check
    toks = catalog_check.tokens(source)
    out = []
    for i in range(len(toks) - 3):
        if toks[i][1] == 'L' and toks[i + 1][1] == '[' and toks[i + 2][0] in ('string', 'long'):
            parts, j = [catalog_check.decode_string(toks[i + 2][1])], i + 3
            while j + 2 < len(toks) and toks[j][1] == '.' and toks[j + 1][1] == '.' and toks[j + 2][0] in ('string', 'long'):
                parts.append(catalog_check.decode_string(toks[j + 2][1]))
                j += 3
            if j < len(toks) and toks[j][1] == ']':
                out.append((''.join(parts), toks[i][2], j + 2 < len(toks) and toks[j + 1][1] == '=' and toks[j + 2][1] != '='))
    return [(k, line, assigned) for k, line, assigned in out if not assigned]


def cmd_notes_todo(context_words=3, only=None):
    """JSON of the IDs that need a note per format token and/or a context, with the call sites that show what is passed."""
    model = Model()
    rows = []
    for e in model.all_entries():
        row = model.annotation(e.id, e.catalog)
        tokens_here = F.format_tokens(e.text)
        needs = []
        if tokens_here and not row.get('notes') and only in (None, 'notes'):
            needs.append('notes')
        if is_short(e.text, context_words) and not row.get('context') and only in (None, 'context'):
            needs.append('context')
        if needs:
            rows.append({'id': e.id, 'key': e.key, 'en': e.text, 'catalog': e.catalog.name, 'needs': needs, 'tokens': tokens_here})
    sites = call_sites([r['key'] for r in rows])
    for r in rows:
        r['sites'] = sites.get(r['key'], [])
    json.dump(sorted(rows, key=lambda r: r['id']), sys.stdout, ensure_ascii=False, indent=1)
    print()


def cmd_notes_set(path):
    """Merge {id or English: [notes] | {"notes": [...], "context": "..."}} into the registry and regenerate every file."""
    model = Model()
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    for name, value in data.items():
        if isinstance(name, str) and re.fullmatch(r'[^:]+:\d+', name):
            catalog, number = name.rsplit(':', 1)
            model.catalog(catalog)
            entry = model.find_id(int(number), catalog)
        else:
            entry = model.find_id(int(name)) if str(name).isdigit() else model.find_key(name)
        if entry is None:
            entry = next((e for e in model.all_entries() if e.text == name), None)
        if entry is None:
            raise SystemExit(f'{name!r}: not an ID or English of any string')
        if isinstance(value, list):
            value = {'notes': value}
        notes = value.get('notes')
        if notes is not None:
            tokens_here = F.format_tokens(entry.text)
            if notes and len(notes) != len(tokens_here):
                raise SystemExit(f'ID {entry.id} {entry.key[:50]!r}: {len(notes)} note(s) for {len(tokens_here)} format token(s) {tokens_here}')
            token = re.compile(r'^(%\S+|\{\{[^}]*\}\})\s*=\s*')
            notes = [token.sub('', n) if token.match(n) and token.match(n).group(1) in tokens_here else n for n in notes]
        model.set_annotation(entry.id, notes=notes, context=value.get('context'), catalog=entry.catalog)
    for locale in LOCALES:
        for each in model.catalogs:
            if each.path(locale).exists():
                model.translations(locale, each)
                model.mark(locale, each)
    out = model.write()
    print(f'notes set; {len(out)} file(s) changed')


# --------------------------------------------------------------------------------------------- where

FUNCTION_HEADER = [re.compile(r'^(\s*)(?:local\s+)?function\s+([\w.:]+)\s*\('),
                   re.compile(r'^(\s*)(?:local\s+)?([\w.:\[\]"\']+)\s*=\s*function\s*\(')]


def enclosing_function(lines, index):
    """The name of the function a source line sits in (the nearest `function` header indented less), or None."""
    indent = len(lines[index]) - len(lines[index].lstrip())
    for i in range(index, -1, -1):
        for pattern in FUNCTION_HEADER:
            m = pattern.match(lines[i])
            if m and (len(m.group(1)) < indent or i == index):
                return m.group(2)
    return None


def resolve_string(query, model):
    """The entries a `where` query names: an ID, the exact key or English, else a unique substring (case-insensitive)."""
    entries = model.all_entries()
    if re.fullmatch(r'[^:]+:\d+', str(query)):
        catalog, number = str(query).rsplit(':', 1)
        hit = [e for e in entries if e.catalog.name == catalog and e.id == int(number)]
        if hit:
            return hit, 'id'
    if str(query).isdigit():
        hit = [e for e in entries if e.catalog.is_main and e.id == int(query)]
        if hit:
            return hit, 'id'
    exact = [e for e in entries if e.key == query or e.text == query]
    if exact:
        return exact, 'exact'
    needle = str(query).casefold()
    return [e for e in entries if needle in e.key.casefold() or needle in e.text.casefold()], 'substring'


def blocks_for(lines, hits, before, after):
    """grep-style blocks: each hit with `before`/`after` lines around it, overlapping or touching ranges merged."""
    spans = []
    for hit in sorted(hits, key=lambda h: h['line']):
        first, last = max(1, hit['line'] - before), min(len(lines), hit['line'] + after)
        if spans and first <= spans[-1][1] + 1:
            spans[-1][1] = max(spans[-1][1], last)
            spans[-1][2].append(hit)
        else:
            spans.append([first, last, [hit]])
    return [{'first': first, 'last': last, 'functions': sorted({h['function'] for h in group if h['function']}),
             'lines': [{'line': n, 'text': lines[n - 1], 'hit': any(h['line'] == n for h in group)} for n in range(first, last + 1)]}
            for first, last, group in spans]


def where_report(entry, model, tests=False, before=0, after=0):
    """Everything about one string: catalog, notes/context and where the source uses it."""
    row = model.annotation(entry.id, entry.catalog)
    direct, indirect = [], []
    for path in lua_sources(include_tests=tests):
        text = path.read_text(encoding='utf-8')
        if 'L[' not in text and 'L [' not in text and entry.key not in text:
            continue
        lines = text.split('\n')
        relative = path.relative_to(ROOT).as_posix()
        reads = [line for k, line, _ in literal_reads(text) if k == entry.key]
        found = [{'line': line, 'code': lines[line - 1].strip(), 'function': enclosing_function(lines, line - 1)} for line in reads]
        weak = []
        for start, end, in_l in string_sites(text, entry.key):
            line = text.count('\n', 0, start) + 1
            if line not in reads and not in_l:
                weak.append({'line': line, 'code': lines[line - 1].strip(), 'function': enclosing_function(lines, line - 1)})
        if found:
            direct.append({'file': relative, 'hits': found, 'blocks': blocks_for(lines, found, before, after)})
        if weak:
            indirect.append({'file': relative, 'hits': weak, 'blocks': blocks_for(lines, weak, before, after)})
    return {'id': entry.id, 'key': entry.key, 'en': entry.text, 'catalog': entry.catalog.name,
            'context': row.get('context'), 'notes': row.get('notes', []), 'tokens': F.format_tokens(entry.text),
            'before': before, 'after': after, 'sites': direct, 'indirect': indirect}


def cmd_where(query, as_json=False, tests=False, before=0, after=0):
    model = Model()
    matches, how = resolve_string(query, model)
    if not matches:
        raise SystemExit(f'nothing matches {query!r}')
    if len(matches) > 1:
        print(f'{len(matches)} strings match {query!r}; name one by ID or give more of its text:', file=sys.stderr)
        for e in matches[:25]:
            print(f'  {e.id:5} [{e.catalog.name}] {e.text[:90]!r}', file=sys.stderr)
        if len(matches) > 25:
            print(f'  ... and {len(matches) - 25} more', file=sys.stderr)
        raise SystemExit(2)
    report = where_report(matches[0], model, tests, before, after)
    if as_json:
        json.dump(report, sys.stdout, ensure_ascii=False, indent=1)
        print()
        return report
    print(f'ID {report["id"]}  catalog: {report["catalog"]}')
    print(f'English: {report["en"]}')
    if report['key'] != report['en']:
        print(f'Key: {report["key"]}')
    if report['context']:
        print(f'Context: {report["context"]}')
    for number, note in enumerate(report['notes'], 1):
        print(f'{report["tokens"][number - 1] if number <= len(report["tokens"]) else "?"} #{number}: {note}')
    if not report['sites'] and not report['indirect']:
        print('\nno direct call site found (looked up dynamically?)')
    for group, title in (('sites', 'Used at'), ('indirect', 'The same text as a plain string, probably looked up through a variable, at')):
        for found in report[group]:
            for block in found['blocks']:
                functions = f' in {", ".join(block["functions"])}' if block['functions'] else ''
                print(f'\n{title} {found["file"]}:{block["first"]}-{block["last"]}{functions}' if block['last'] != block['first']
                      else f'\n{title} {found["file"]}:{block["first"]}{functions}')
                for row in block['lines']:
                    print(f'{">" if row["hit"] else " "} {row["line"]:5}  {row["text"]}')
    return report


def cmd_add(key, text, catalog_name):
    model = Model()
    entry = model.add(key, text, catalog_name)
    model.write()
    print(f'ID {entry.id}: {key[:70]!r} added to {catalog_name}')


def cmd_remove(keys):
    model = Model()
    for key in keys:
        entry = model.remove(key)
        print(f'removed ID {entry.id} {key[:70]!r} (retired)')
    model.write()


def literal_keys():
    import catalog_check
    used = {}
    for path in lua_sources():
        for key, line in catalog_check.references(path.read_text(encoding='utf-8')):
            used.setdefault(key, f'{path.relative_to(ROOT).as_posix()}:{line}')
    return used


def cmd_sync(dry_run=False, prune_class=False):
    import catalog_check
    model = Model()
    known = {e.key for e in model.all_entries()}
    main_uses = literal_keys()
    uses = dict(main_uses)
    class_uses = {}
    for each in model.catalogs:
        if not each.is_class:
            continue
        used = set()
        for path in each.directory.rglob('*.lua'):
            if 'Locales' in path.relative_to(each.directory).parts:
                continue
            for key, line in catalog_check.manifest_references(path.read_text(encoding='utf-8')):
                used.add(key)
                uses.setdefault(key, f'{path.relative_to(ROOT).as_posix()}:{line}')
        class_uses[each.name] = used
    missing = {k: w for k, w in uses.items() if k not in known}
    for key, where in sorted(missing.items(), key=lambda kv: kv[1]):
        print(f'{"would add" if dry_run else "added"} {key[:70]!r} ({where})')
        if not dry_run:
            owners = [name for name, keys in class_uses.items() if key in keys]
            model.add(key, catalog=owners[0] if len(owners) == 1 and key not in main_uses else 'main')
    unused = [(e.key, each.name) for each in model.catalogs if each.is_class
              for e in model.entries[each.name] if e.key not in class_uses[each.name]]
    if prune_class:
        for key, name in unused:
            print(f'{"would remove" if dry_run else "removed"} unused class text {key[:70]!r} ({name})')
            if not dry_run:
                model.remove(key)
    if (missing or (prune_class and unused)) and not dry_run:
        model.write()
    print(f'{len(missing)} string(s) the code reads and no catalog held')
    if (missing or (prune_class and unused)) and dry_run:
        raise SystemExit(1)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command')

    def credit_options(p, required):
        p.add_argument('--translator', required=required, help='credited name (a display name, added to every file written)')
        p.add_argument('--url', help='optional link or handle shown in the file header')
        kind = p.add_mutually_exclusive_group()
        kind.add_argument('--human', action='store_const', const='human', dest='kind', help='a human translator (the default for a new name; credited on the About page)')
        kind.add_argument('--ai', action='store_const', const='ai', dest='kind', help='an AI translator (named in the header only)')
    sub.add_parser('export')
    p = sub.add_parser('missing')
    p.add_argument('locale', choices=LOCALES)
    p = sub.add_parser('build')
    p.add_argument('locale', choices=LOCALES)
    p.add_argument('file')
    credit_options(p, False)
    p = sub.add_parser('credit')
    p.add_argument('locale', choices=LOCALES)
    p.add_argument('--strings', type=int, default=0)
    p.add_argument('--catalog', help='credit only one catalog, for example class-shaman')
    credit_options(p, True)
    p = sub.add_parser('accept')
    p.add_argument('locale', choices=LOCALES)
    p.add_argument('ids', nargs='*')
    p = sub.add_parser('check')
    p.add_argument('--complete', action='store_true', help='fail when any language has untranslated or stale IDs')
    p.add_argument('--require-notes', action='store_true', help='fail for every string with format tokens and no notes')
    p.add_argument('--require-context', action='store_true', help='fail for every short string without a context')
    p.add_argument('--context-words', type=int, default=3, help='"short" means this many words or fewer (default 3)')
    p = sub.add_parser('notes', help='author the context and token notes translators see')
    notes = p.add_subparsers(dest='notes_command', required=True)
    q = notes.add_parser('todo', help='JSON of strings with tokens and no notes, and short strings without context, with call sites')
    q.add_argument('--context-words', type=int, default=3)
    q.add_argument('--only', choices=['notes', 'context'])
    q = notes.add_parser('set', help='merge {id or English: [notes] | {"notes": [...], "context": "..."}}')
    q.add_argument('file')
    p = sub.add_parser('where', help='show where the source uses a string, with context')
    p.add_argument('query', nargs='?', help='an ID, the exact English, or a unique part of it')
    p.add_argument('--id', dest='id_query', help='the ID (for editors)')
    p.add_argument('--json', action='store_true')
    p.add_argument('--tests', action='store_true', help='also search tests/')
    p.add_argument('-B', '--before', type=int, default=0, metavar='N', help='lines of code before each use (default 0)')
    p.add_argument('-A', '--after', type=int, default=0, metavar='N', help='lines of code after each use (default 0)')
    p.add_argument('-C', '--context', type=int, default=None, metavar='N', help='lines before and after each use')
    sub.add_parser('rebuild')
    sub.add_parser('bundles')
    p = sub.add_parser('move')
    p.add_argument('bundle')
    p.add_argument('keys')
    p = sub.add_parser('index')
    p.add_argument('--check', action='store_true')
    p = sub.add_parser('reword')
    p.add_argument('old')
    p.add_argument('new')
    p.add_argument('--dry-run', action='store_true')
    p.add_argument('--all-literals', action='store_true', help='also change plain string literals equal to the old English')
    p.add_argument('--tests', action='store_true', help='also rewrite L["..."] sites under tests/')
    p = sub.add_parser('add')
    p.add_argument('key')
    p.add_argument('text', nargs='?')
    p.add_argument('--catalog', default='main')
    p = sub.add_parser('remove')
    p.add_argument('keys', nargs='+')
    p = sub.add_parser('sync')
    p.add_argument('--dry-run', action='store_true')
    p.add_argument('--prune-class', action='store_true', help='also remove class rotation texts no longer referenced by that class')
    args = parser.parse_args(argv)
    if args.command == 'export':
        cmd_export()
    elif args.command == 'missing':
        cmd_missing(args.locale)
    elif args.command == 'build':
        cmd_build(args.locale, args.file, translator=args.translator, kind=args.kind, url=args.url)
    elif args.command == 'credit':
        cmd_credit(args.locale, args.translator, kind=args.kind, url=args.url, strings=args.strings, catalog_name=args.catalog)
    elif args.command == 'accept':
        cmd_accept(args.locale, args.ids)
    elif args.command == 'check':
        cmd_check(args.complete, args.require_notes, args.require_context, args.context_words)
    elif args.command == 'notes':
        cmd_notes_todo(args.context_words, args.only) if args.notes_command == 'todo' else cmd_notes_set(args.file)
    elif args.command == 'where':
        query = args.id_query or args.query
        if not query:
            parser.error('where needs an ID, an English text or --id')
        cmd_where(query, args.json, args.tests,
                  args.context if args.context is not None else args.before, args.context if args.context is not None else args.after)
    elif args.command == 'rebuild':
        cmd_rebuild()
    elif args.command == 'bundles':
        cmd_bundles()
    elif args.command == 'move':
        cmd_move(args.bundle, args.keys)
    elif args.command == 'index':
        cmd_index(args.check)
    elif args.command == 'reword':
        cmd_reword(args.old, args.new, args.dry_run, args.all_literals, args.tests)
    elif args.command == 'add':
        cmd_add(args.key, args.text, args.catalog)
    elif args.command == 'remove':
        cmd_remove(args.keys)
    elif args.command == 'sync':
        cmd_sync(args.dry_run, args.prune_class)
    else:
        raise SystemExit(__doc__)


if __name__ == '__main__':
    main()
