# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""The shipped locale file formats: how tools/locales.py writes them and every other tool reads them.

Pure functions over text; nothing here knows where the repository is. Two kinds of file, one per catalog and
language (the main catalog in Locales/, each load-on-demand text bundle in Modules/<module>/):

  enUS.lua    N["English text"] = id, the one place the English is bound to its number, with a hash comment above each
              entry (and its Context/token-note comments). An English client builds no N. What it needs besides that is
              written before the early return, in tables of their own:
                S       [id] = { key, English } for a symbolic key such as "Default.X.Name" (key and text really differ),
                        and one table per key prefix, [id] = English, for "TalentTree." .. English;
                P       the keys whose English is the key with every | doubled for chat (listed by key; they are N
                        entries like any other, so a translated game binds them to their translation too).
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


def render_english(entries, description, extras=None):
    """The enUS.lua of a catalog from entries with .id .key .text .hash, in ID order.

    Every string binds its English to its ID once, `N["English text"] = 1234`; the languages bind the ID to the translation.
    What an English game needs besides that (it loads no N and no translation) is written before the early return: the strings
    read under another key (S, and one table per key prefix) and the keys whose English doubles their pipes (P)."""
    extras = extras or {}
    ordered = sorted(entries, key=lambda e: e.id)
    kinds = {e.id: kind_of(e.key, e.text) for e in ordered}
    symbolic = [e for e in ordered if kinds[e.id] == 'symbolic']
    piped = [e for e in ordered if kinds[e.id] == 'piped']
    prefixed = {prefix: [e for e in ordered if kinds[e.id] == 'prefixed' and prefix_of(e.key) == prefix] for prefix in PREFIXES}
    named = [e for e in ordered if kinds[e.id] in ('plain', 'piped')]

    def entry_lines(e, line):
        return [f'-- {e.hash}', *extras.get(e.id, ()), line]
    lines = [COPYRIGHT, *ENGLISH_NOTICE, f'-- {description}',
             'local addon_name, addon = ...', '',
             'local L = LibStub("AceLocale-3.0"):NewLocale(addon_name, "enUS", true, true)',
             '-- The game language\'s translation, set by that language\'s file (loaded before this one); nil for English.',
             'local T = addon.translation',
             'addon.translation = nil',
             'addon.localeIsTranslated = T ~= nil', '']
    if symbolic:
        lines += ['-- Read under a key that is not their text: [id] = { key, English }. An English game reads these.',
                  'local S = {']
        for e in symbolic:
            lines += entry_lines(e, f'[{e.id}] = {{ {lua_string(e.key)}, {lua_string(e.text)} }},')
        lines += ['}', 'for id, entry in pairs(S) do', '    L[entry[1]] = T and T[id] or entry[2]', 'end', 'S = nil', '']
    for prefix, group in prefixed.items():
        if group:
            name = block_name(prefix)
            lines += [f'-- Read under "{prefix}" followed by their English: [id] = English. An English game reads these.',
                      f'local {name} = {{ -- keys are {lua_string(prefix)} followed by the English']
            for e in group:
                lines += entry_lines(e, f'[{e.id}] = {lua_string(e.text)},')
            lines += ['}', f'for id, text in pairs({name}) do', f'    L[{lua_string(prefix)} .. text] = T and T[id] or text', 'end', f'{name} = nil', '']
    if piped:
        lines += ['-- Read under their own text (they are in N below), displayed with every | doubled, as chat needs it.',
                  'local P = { -- keys whose English is the key with every | doubled']
        lines += [f'{lua_string(e.key)},' for e in piped]
        lines += ['}', '']
    lines.append('if not T then')
    if piped:
        lines += ['    for _, key in ipairs(P) do', '        L[key] = (key:gsub("|", "||"))', '    end', '']
    lines += ['    return', 'end', '']
    lines += ['-- Every string read under its own text binds it to its ID: N["English text"] = id. Only a translated game builds',
              '-- this; the languages bind the ID to the translation, and an untranslated text stays absent (it reads as itself).',
              'local N = {}']
    for e in named:
        lines += entry_lines(e, f'N[{lua_string(e.key)}] = {e.id}')
    lines += ['', 'for text, id in pairs(N) do', '    local translation = T[id]', '', '    if translation then', '        L[text] = translation', '    end', 'end']
    if piped:
        lines += ['', '-- An untranslated string that doubles its pipes still shows the doubled English.',
                  'for _, key in ipairs(P) do', '    if not T[N[key]] then', '        L[key] = (key:gsub("|", "||"))', '    end', 'end']
    lines.append('')
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

    @property
    def kind(self):
        return kind_of(self.key, self.text)


class Translation:
    def __init__(self, id, text, hash, english, line, annotations=()):
        self.id, self.text, self.hash, self.english, self.line = id, text, hash, english, line
        self.annotations = list(annotations)


PLAIN = re.compile(r'^\[(\d+)\] = (' + STRING + r'),$')
SYMBOLIC = re.compile(r'^\[(\d+)\] = \{ (' + STRING + r'), (' + STRING + r') \},$')
NAMED = re.compile(r'^N\[(' + STRING + r')\] = (\d+)$')
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
            if line.startswith(('[', 'N[')):
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
