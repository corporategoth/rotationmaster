"""The shipped locale file formats: how tools/locales.py writes them and every other tool reads them.

Pure functions over text; nothing here knows where the repository is. Two kinds of file, one per catalog and
language (the main catalog in Locales/, each load-on-demand text bundle in Modules/<module>/):

  enUS.lua    [id] = English text, hash comment above each entry. Entries read under a key that is not their text
              (a symbolic key such as "Default.X.Name", or text whose pipes are doubled for display) are written
              [id] = { key, English text } in a section of their own: an English client reads only that section.
  <xx>.lua    -- <hash> English: the English this translation was made from (wrapped over comment lines)
              [id] = "translation",

IDs are stable numbers (tools/locale_registry.json); the hash is a short digest of the English text, so a
translation whose recorded hash differs from the current English is known to be stale.
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


def render_english(entries, description, extras=None):
    """The enUS.lua of a catalog from entries with .id .key .text .hash, in ID order."""
    symbolic = sorted((e for e in entries if e.key != e.text), key=lambda e: e.id)
    plain = sorted((e for e in entries if e.key == e.text), key=lambda e: e.id)
    lines = [COPYRIGHT, *ENGLISH_NOTICE, f'-- {description}',
             'local addon_name, addon = ...', '',
             'local L = LibStub("AceLocale-3.0"):NewLocale(addon_name, "enUS", true, true)',
             '-- The game language\'s translation, set by that language\'s file (loaded before this one); nil for English.',
             'local T = addon.translation',
             'addon.translation = nil',
             'addon.localeIsTranslated = T ~= nil', '',
             '-- Read under a key that is not their text: [id] = { key, English }. An English game reads only these.',
             'local S = {']
    for e in symbolic:
        lines.append(f'-- {e.hash}')
        lines.extend((extras or {}).get(e.id, ()))
        lines.append(f'[{e.id}] = {{ {lua_string(e.key)}, {lua_string(e.text)} }},')
    lines += ['}', 'for id, entry in pairs(S) do L[entry[1]] = T and T[id] or entry[2] end',
              'S = nil',
              'if not T then return end', '',
              '-- Read under their own text: [id] = English. Only a translated game reads these; the untranslated stay absent.',
              'local E = {']
    for e in plain:
        lines.append(f'-- {e.hash}')
        lines.extend((extras or {}).get(e.id, ()))
        lines.append(f'[{e.id}] = {lua_string(e.text)},')
    lines += ['}', 'for id, text in pairs(E) do', '    local translation = T[id]', '    if translation then L[text] = translation end', 'end', '']
    return '\n'.join(lines)


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


class Translation:
    def __init__(self, id, text, hash, english, line, annotations=()):
        self.id, self.text, self.hash, self.english, self.line = id, text, hash, english, line
        self.annotations = list(annotations)


PLAIN = re.compile(r'^\[(\d+)\] = (' + STRING + r'),$')
SYMBOLIC = re.compile(r'^\[(\d+)\] = \{ (' + STRING + r'), (' + STRING + r') \},$')
DIGEST = re.compile(r'^-- ([0-9a-f]{%d})$' % HASH_LENGTH)
TRANSLATION_ENTRY = re.compile(r'^\[(\d+)\] = (' + STRING + r'),?\s*$')
TRANSLATORS = re.compile(r'^-- Translators: (.*)$')
HUMANS = re.compile(r'^L\[0\] = \{ ?(.*?) ?\}$')


def parse_english(text):
    """(entries, problems) of an enUS.lua."""
    entries, problems, pending, extra = [], [], None, []
    for number, line in enumerate(text.split('\n'), 1):
        m = DIGEST.match(line)
        if m:
            pending, extra = m.group(1), []
            continue
        if pending is not None and (ANNOTATION_START.match(line) or (extra and CONTINUATION.match(line))):
            extra.append(line)
            continue
        m, symbolic = PLAIN.match(line), False
        if not m:
            m, symbolic = SYMBOLIC.match(line), True
        if not m:
            if line.startswith('['):
                problems.append(f'line {number}: not an entry this format knows: {line[:60]!r}')
            continue
        if pending is None:
            problems.append(f'line {number}: entry {m.group(1)} has no hash comment above it')
        if symbolic:
            key, value = decode_lua_string(m.group(2)), decode_lua_string(m.group(3))
        else:
            key = value = decode_lua_string(m.group(2))
        entries.append(English(int(m.group(1)), key, value, pending, number, extra))
        pending, extra = None, []
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
