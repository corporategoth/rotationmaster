# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""The shipped locale file formats: how tools/locales.py writes them and every other tool reads them.

Pure functions over text; nothing here knows where the repository is. Each catalog has an English file and translation files.

  enUS.lua    T["English text"] = id, with a hash and optional context comments. The English string is exactly the
              source lookup key. On load, it joins its IDs to the current language and writes L[text] = translation.
  <xx>.lua    -- <hash> English: the English this translation was made from
              [id] = "translation",

IDs are stable within each catalog (tools/locale_registry.json); the same number may appear in another catalog.
A hash identifies stale translations when the English changes.
"""
import hashlib
import re

COPYRIGHT = ('-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license '
             '(MIT + Attribution); see the LICENSE file for details.')

LOCALES = ['deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW']
HASH_LENGTH = 8
WRAP = 100
STRING = r'"(?:[^"\\]|\\.)*"'


def text_hash(text):
    """The short digest recorded beside a translation: sha256 of the UTF-8 English text, first eight hex digits."""
    return hashlib.sha256(text.encode('utf-8')).hexdigest()[:HASH_LENGTH]


# ------------------------------------------------------------------------------------------ Lua strings

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


_SIMPLE = {'a': '\a', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r', 't': '\t', 'v': '\v'}


def decode_lua_string(literal):
    """The value of a quoted Lua string literal (the escapes Lua 5.1 defines)."""
    body = literal[1:-1]
    return re.sub(r'\\(\d{1,3}|\r?\n|.)', lambda m: chr(int(m[1])) if m[1].isdigit() else _SIMPLE.get(m[1], m[1]), body)


# ----------------------------------------------------------------------------------- English comments

def escape_comment(text):
    return text.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r')


def unescape_comment(text):
    return re.sub(r'\\(.)', lambda m: {'n': '\n', 'r': '\r'}.get(m[1], m[1]), text)


def english_comment(digest, text, width=WRAP):
    """`-- <hash> English: text`, wrapped over continuation lines (`--     more`) at single spaces."""
    lines = []
    prefix = f'-- {digest} English: '
    current = prefix
    first = True
    for token in escape_comment(text).split(' '):
        candidate = token if first else ' ' + token
        if not first and len(current) + len(candidate) > width and current.strip() != prefix.strip():
            lines.append(current)
            current = '--     ' + token
        else:
            current += candidate
        first = False
    lines.append(current)
    return lines


FORMAT_SCAN = re.compile(r'%%|%[-+#0]*\d*(?:\.\d+)?[sdifgqxXc]')


def format_tokens(text):
    """The string.format specifiers of an English text, in order (%% is a literal percent and not one)."""
    return [t for t in FORMAT_SCAN.findall(text) if t != '%%']


def annotation_lines(text, notes=None, context=None, width=WRAP):
    """The comment lines under the English comment: `-- Context: ...` (what the string is and where it shows), then one
    `-- %s #1: what goes in, e.g. ...` per format token, in token order."""
    lines = []
    if context:
        first = True
        for paragraph in str(context).split('\n'):
            current = '-- Context: ' if first else '--     '
            started = False
            for token in paragraph.split():
                candidate = token if not started else ' ' + token
                if started and len(current) + len(candidate) > width:
                    lines.append(current)
                    current = '--     ' + token
                else:
                    current += candidate
                started = True
            lines.append(current)
            first = False
    tokens = format_tokens(text)
    for number, note in enumerate(notes or [], 1):
        label = tokens[number - 1] if number <= len(tokens) else '?'
        lines.append(f'-- {label} #{number}: ' + ' '.join(str(note).split()))
    return lines


ANNOTATION_START = re.compile(r'^-- (?:Context: |\S+ #\d+: )')
HASH_LINE = re.compile(r'^-- ([0-9a-f]{%d}) English: ?(.*)$' % HASH_LENGTH)
CONTINUATION = re.compile(r'^--     (.*)$')


# ------------------------------------------------------------------------------------------- headers

ENGLISH_NOTICE = [
    '-- Generated by tools/locales.py; do not edit by hand. The English text of one catalog, by stable ID.',
    '-- Add, reword, move or remove text with `python3 tools/locales.py add|reword|move|remove` (docs/translators/README.md).',
]
TRANSLATION_NOTICE = [
    '-- Generated by tools/locales.py. To translate, change only the string after "=" and leave the comment lines',
    '-- and the numbers alone; then run `python3 tools/locales.py check` (docs/translators/README.md).',
]


# Key prefixes whose English is the rest of the key ("TalentTree.Arms" reads "Arms"): written as `[id] = "Arms"` under the prefix.
PREFIXES = ['TalentTree.']


def kind_of(key, text):
    """How an English entry is read: `plain` (under its own text), `piped` (under its own text, displayed with every | doubled
    for chat), `prefixed` (under PREFIX + its text) or `symbolic` (under a key that has nothing to do with the text)."""
    if key == text:
        return 'plain'
    if '|' in key and text == key.replace('|', '||'):
        return 'piped'
    if any(key.startswith(prefix) and key[len(prefix):] == text for prefix in PREFIXES):
        return 'prefixed'
    return 'symbolic'


def prefix_of(key):
    return next(prefix for prefix in PREFIXES if key.startswith(prefix))


def block_name(prefix):
    return prefix.rstrip('.')


def render_english(entries, description, extras=None, central_locale=False):
    """Bind each exact English source string to its stable translation ID."""
    extras = extras or {}
    ordered = sorted(entries, key=lambda entry: entry.id)
    keys = set()
    for entry in ordered:
        if entry.key != entry.text:
            raise ValueError(f"English key and display text differ for ID {entry.id}")
        if entry.key in keys:
            raise ValueError(f"Duplicate English key for ID {entry.id}")
        keys.add(entry.key)
    locale_lines = (['LibStub("AceLocale-3.0"):NewLocale(addon_name, "enUS", true, true)',
                     'local host = RotationMasterBuiltIns',
                     'local L = LibStub("AceLocale-3.0"):GetLocale(host and host.localeName or addon_name:match("^(.-)_[^_]+$") or addon_name)']
                    if central_locale else ['local L = LibStub("AceLocale-3.0"):NewLocale(addon_name, "enUS", true, true)'])
    lines = [COPYRIGHT, *ENGLISH_NOTICE, f'-- {description}',
             'local addon_name, addon = ...', '', *locale_lines,
             'local translations = addon.translation',
             'addon.translation = nil',
             'addon.localeIsTranslated = translations ~= nil', '',
             '-- The key is the exact English text used by the source; the value is its stable ID.',
             'local T = {}']
    for entry in ordered:
        lines.extend([f'-- {entry.hash}', *extras.get(entry.id, ()),
                      f'T[{lua_string(entry.key)}] = {entry.id}'])
    lines += ['', 'for text, id in pairs(T) do', '    L[text] = translations and translations[id] or text', 'end', '']
    return "\n".join(lines)


def translators_header(credits):
    """`-- Translators:` line: everyone who translated part of a file, the AI included."""
    parts = []
    for c in credits:
        detail = []
        if c.get('kind') == 'ai':
            detail.append(c.get('note') or 'AI-assisted, not yet reviewed by a native speaker')
        count = c.get('strings')
        if count:
            span = c.get('first') if c.get('first') == c.get('last') else f"{c.get('first')} to {c.get('last')}" if c.get('first') else ''
            detail.append(f'{count} string{"" if count == 1 else "s"}' + (f', {span}' if span else ''))
        name = c['name'] + (f' <{c["url"]}>' if c.get('url') else '')
        parts.append(name + (f' ({"; ".join(detail)})' if detail else ''))
    return '-- Translators: ' + (', '.join(parts) if parts else 'none yet')


def render_locale(locale, entries, credits, extras=None, humans=None):
    """A translation file. entries: objects with .id .hash .english (the English it was made from) .text, in ID order."""
    humans = humans if humans is not None else [c['name'] for c in credits if c.get('kind') != 'ai']
    lines = [COPYRIGHT, *TRANSLATION_NOTICE, translators_header(credits),
             'local addon_name, addon = ...', '',
             f'local L = LibStub("AceLocale-3.0"):NewLocale(addon_name, "{locale}", false, true)',
             'if not L then return end', '',
             '-- Human translators the About page credits (display names only; the AI is named in the header above).',
             'L[0] = {' + (' ' + ', '.join(lua_string(n) for n in humans) + ' ' if humans else '') + '}', '',
             'addon.translation = {']
    for e in sorted(entries, key=lambda e: e.id):
        lines.extend(english_comment(e.hash, e.english))
        lines.extend((extras or {}).get(e.id, ()))
        lines.append(f'[{e.id}] = {lua_string(e.text)},')
    lines += ['}', '']
    return '\n'.join(lines)


# --------------------------------------------------------------------------------------------- parsing

class English:
    def __init__(self, id, key, text, hash, line, annotations=()):
        self.id, self.key, self.text, self.hash, self.line = id, key, text, hash, line
        self.annotations = list(annotations)

    @property
    def symbolic(self):
        return self.key != self.text

    @property
    def kind(self):
        return kind_of(self.key, self.text)


class Translation:
    def __init__(self, id, text, hash, english, line, annotations=()):
        self.id, self.text, self.hash, self.english, self.line = id, text, hash, english, line
        self.annotations = list(annotations)


PLAIN = re.compile(r'^\[(\d+)\] = (' + STRING + r'),$')
SYMBOLIC = re.compile(r'^\[(\d+)\] = \{ (' + STRING + r'), (' + STRING + r') \},$')
NAMED = re.compile(r'^[NT]\[(' + STRING + r')\] = (\d+)$')
PREFIX_BLOCK = re.compile(r'^local \w+ = \{ -- keys are (' + STRING + r') followed by the English$')
PIPED_BLOCK = re.compile(r'^local P = \{ -- keys whose English is the key with every \| doubled$')
S_BLOCK = re.compile(r'^local S = \{$')
DIGEST = re.compile(r'^-- ([0-9a-f]{%d})$' % HASH_LENGTH)
TRANSLATION_ENTRY = re.compile(r'^\[(\d+)\] = (' + STRING + r'),?\s*$')
TRANSLATORS = re.compile(r'^-- Translators: (.*)$')
HUMANS = re.compile(r'^L\[0\] = \{ ?(.*?) ?\}$')


def parse_english(text):
    """(entries, problems) of an enUS.lua."""
    entries, problems, pending, extra = [], [], None, []
    mode, prefix, piped = None, None, []
    for number, line in enumerate(text.split('\n'), 1):
        m = DIGEST.match(line)
        if m:
            pending, extra = m.group(1), []
            continue
        if pending is not None and (ANNOTATION_START.match(line) or (extra and CONTINUATION.match(line))):
            extra.append(line)
            continue
        if line == '}':
            mode = None
            continue
        if S_BLOCK.match(line):
            mode = 'S'
            continue
        m = PREFIX_BLOCK.match(line)
        if m:
            mode, prefix = 'prefix', decode_lua_string(m.group(1))
            continue
        if PIPED_BLOCK.match(line):
            mode = 'P'
            continue
        if mode == 'P':
            m = re.match(r'^(' + STRING + r'),$', line)
            if m:
                piped.append(decode_lua_string(m.group(1)))
            elif line:
                problems.append(f'line {number}: not a key of the P list: {line[:60]!r}')
            continue
        key = value = id = None
        if mode == 'S':
            m = SYMBOLIC.match(line)
            if m:
                id, key, value = int(m.group(1)), decode_lua_string(m.group(2)), decode_lua_string(m.group(3))
        elif mode == 'prefix':
            m = PLAIN.match(line)
            if m:
                id, value = int(m.group(1)), decode_lua_string(m.group(2))
                key = prefix + value
        else:
            m = NAMED.match(line)
            if m:
                id, key = int(m.group(2)), decode_lua_string(m.group(1))
                value = key
        if id is None:
            if line.startswith(('[', 'N[', 'T[')):
                problems.append(f'line {number}: not an entry this format knows: {line[:60]!r}')
            continue
        if pending is None:
            problems.append(f'line {number}: entry {id} has no hash comment above it')
        entries.append(English(id, key, value, pending, number, extra))
        pending, extra = None, []
    # A key listed in P is displayed with every | doubled.
    by_key = {e.key: e for e in entries}
    for key in piped:
        entry = by_key.get(key)
        if entry is None or entry.key != entry.text:
            problems.append(f'P lists {key[:60]!r}, which is not an N entry')
        else:
            entry.text = key.replace('|', '||')
    return entries, problems


def parse_locale(text):
    """(entries, header, problems) of a translation file; header = {'translators': line, 'humans': [names]}."""
    entries, problems, header = [], [], {'translators': None, 'humans': None}
    pending, extra = None, []
    for number, line in enumerate(text.split('\n'), 1):
        m = HASH_LINE.match(line)
        if m:
            pending, extra = [m.group(1), [m.group(2)]], []
            continue
        if pending is not None and (ANNOTATION_START.match(line) or (extra and CONTINUATION.match(line))):
            extra.append(line)
            continue
        m = CONTINUATION.match(line)
        if m and pending is not None:
            pending[1].append(m.group(1))
            continue
        m = TRANSLATION_ENTRY.match(line)
        if m:
            if pending is None:
                problems.append(f'line {number}: entry {m.group(1)} has no "-- <hash> English:" comment above it')
                digest, english = None, None
            else:
                digest, english = pending[0], unescape_comment(' '.join(pending[1]))
            entries.append(Translation(int(m.group(1)), decode_lua_string(m.group(2)), digest, english, number, extra))
            pending, extra = None, []
            continue
        if line.startswith('['):
            problems.append(f'line {number}: not an entry this format knows: {line[:60]!r}')
        m = TRANSLATORS.match(line)
        if m and header['translators'] is None:
            header['translators'] = line
        m = HUMANS.match(line)
        if m and header['humans'] is None:
            header['humans'] = [decode_lua_string(s) for s in re.findall(STRING, m.group(1))]
    return entries, header, problems
