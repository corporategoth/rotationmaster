# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Shared helpers for the translation tools (translation_status.py, translation_todo.py, translation_apply.py).

Everything about reading and writing locale files stays in tools/locales.py; this module only classifies
what that module reads. It never writes a locale file itself.
"""
from collections import Counter
import json
from pathlib import Path
import re
import sys

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import locales as L  # noqa: E402

ROOT = L.ROOT
LOCALES = L.LOCALES
EXEMPT_PATH = TOOLS / 'translation_exempt.json'
GLOSSARY_PATH = ROOT / 'docs' / 'translators' / 'glossary.md'

# An English string identical in this many locales is a name or loanword everywhere ("universal");
# in this many it is probably one in this language too ("cognate", reported, not asked for).
UNIVERSAL_VOTES = 8
COGNATE_VOTES = 3

PROVIDER_LABEL = re.compile(r'^(?:CurseForge|GitHub|WoWInterface|Wago Addons|WowUp Hub|WoWAce|Tukui|Blizzard)\b')
WORD = re.compile(r"[^\W\d_]+(?:['’][^\W\d_]+)?", re.U)
SCRIPT = {'ruRU': ('Cyrillic', re.compile('[Ѐ-ӿ]')),
          'koKR': ('Hangul', re.compile('[가-힣]')),
          'zhCN': ('Han', re.compile('[一-鿿]')),
          'zhTW': ('Han', re.compile('[一-鿿]'))}


def load_exempt():
    if EXEMPT_PATH.exists():
        return json.loads(EXEMPT_PATH.read_text(encoding='utf-8'))
    return {'names': [], 'keep_english': {}}


def save_exempt(data):
    data['names'] = sorted(set(data.get('names', [])), key=str.lower)
    data['keep_english'] = {loc: sorted(set(keys)) for loc, keys in sorted(data.get('keep_english', {}).items()) if keys}
    EXEMPT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')


def strip_tokens(text):
    """The words of a string with placeholders, color codes and {{variables}} removed."""
    text = L.ALTERNATIVE.sub(lambda m: m.group(2).replace('|', ' '), text)
    text = L.VARIABLE.sub(' ', text)
    text = L.TOKEN.sub(' ', text)
    text = L.FORMAT_SCAN.sub(' ', text)
    return text


def words_of(text):
    return WORD.findall(strip_tokens(text))


def known_names(exempt):
    """Words that are names: the exempt list, the supported addons, and strings every locale leaves alone."""
    names = set()
    for phrase in exempt.get('names', []):
        names.update(words_of(phrase))
    projects = ROOT / 'tools' / 'integration_projects.json'
    if projects.exists():
        for identity in json.loads(projects.read_text(encoding='utf-8')).get('integrations', {}):
            names.update(words_of(identity))
    return names


class Corpus:
    """enUS plus every locale file, read once."""

    def __init__(self, locales=None):
        self.english = L.english()
        self.locales = list(locales or LOCALES)
        self.entries = {}
        self.sources = {}
        for locale in LOCALES:
            # Every catalog: the main one and each load-on-demand text bundle.
            self.entries[locale] = dict(L.locale_entries(locale))
            self.sources[locale] = L.read_sources(locale)
        self.exempt = load_exempt()
        self.names = known_names(self.exempt)
        votes = Counter()
        for locale in LOCALES:
            for key, value in self.entries[locale].items():
                if key in self.english and value == self.english[key] and self.sources[locale].get(key) == value:
                    votes[key] += 1
        self.votes = votes
        for key, count in votes.items():
            if count >= UNIVERSAL_VOTES:
                self.names.update(words_of(self.english[key]))

    def identical_reason(self, locale, key):
        """Why an entry equal to its English is acceptable, or None when it looks untranslated."""
        english = self.english[key]
        if key in self.exempt.get('keep_english', {}).get(locale, ()):
            return 'keep-english'
        words = words_of(english)
        if not words:
            return 'no-words'
        if PROVIDER_LABEL.match(english) or all(w in self.names for w in words):
            return 'name'
        if len(words) == 1 and (re.fullmatch(r'[A-Z0-9_]{2,}', words[0]) or re.search(r'[a-z][A-Z]', words[0])):
            return 'name'
        if self.votes[key] >= UNIVERSAL_VOTES:
            return 'universal'
        if self.votes[key] >= COGNATE_VOTES:
            return 'cognate'
        return None

    def classify(self, locale):
        """Keys of one locale by state: complete, missing, stale, identical (suspect), exempt, invalid, orphans."""
        entries, sources = self.entries[locale], self.sources[locale]
        out = {'complete': [], 'missing': [], 'stale': [], 'suspect': [], 'exempt': {}, 'invalid': {}, 'orphans': []}
        for key, english in self.english.items():
            if key not in entries:
                out['missing'].append(key)
                continue
            value = entries[key]
            problems = L.problems(key, english, value)
            if problems:
                out['invalid'][key] = problems
            if sources.get(key) != english:
                out['stale'].append(key)
            elif value == english:
                reason = self.identical_reason(locale, key)
                if reason is None:
                    out['suspect'].append(key)
                else:
                    out['exempt'][key] = reason
                    out['complete'].append(key)
            else:
                out['complete'].append(key)
        out['orphans'] = [key for key in entries if key not in self.english]
        out['complete'] = [key for key in out['complete'] if key not in out['invalid']]
        return out


# ------------------------------------------------------------------------------------- glossary

def read_glossary(path=GLOSSARY_PATH):
    """{English term: {locale: translation}} from the glossary's tables."""
    glossary = {}
    if not Path(path).exists():
        return glossary
    header = None
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        if not line.startswith('|'):
            header = None
            continue
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if cells and cells[0].lower() in ('term', 'english'):
            header = cells
        elif header and len(cells) == len(header) and not set(''.join(cells)) <= set('-: '):
            term = cells[0].strip('`')
            row = {loc: cell for loc, cell in zip(header[1:], cells[1:]) if loc in LOCALES and cell not in ('', '-', '—')}
            if row:
                glossary[term] = row
    return glossary


# Glossary terms that are also ordinary English words: in a sentence a hit says nothing, so they only count
# when the string is short (a label, a button).
COMMON_WORDS = {'Yes', 'No', 'Any', 'All', 'None', 'Always', 'AND', 'OR', 'NOT', 'Add', 'Check', 'Copy', 'Search',
                'General', 'Name', 'Scale', 'Apply', 'Cancel', 'Reset', 'Edit', 'Delete', 'Enable', 'Disable'}


def glossary_hits(english, locale, glossary):
    """Glossary terms that occur in an English string, with this locale's wording."""
    found = []
    words = WORD.findall(strip_tokens(english))
    lowered = ' '.join(w.lower() for w in words)
    for term, row in glossary.items():
        if term in COMMON_WORDS and len(words) > 2:
            continue
        if locale in row:
            needle = re.escape(term.lower())
            if re.search(rf'(?<![a-z]){needle}(?:s|es)?(?![a-z])', lowered):
                found.append({'term': term, 'translation': row[locale]})
    return found


# ---------------------------------------------------------------------------------- source context

AREAS = [('Help/', 'help text'), ('UI/', 'editor window'), ('Core/', 'core message or label'),
         ('Conditions/', 'condition name or help'), ('Platform/', 'client message'), ('Diagnostics/', 'diagnostic report'),
         ('Modules/', 'Built In premade'), ('Data/', 'data'), ('Integrations/', 'integration'), ('Functions/', 'function help'),
         ('Analytics/', 'analytics')]


def key_area(key, files):
    if key.startswith('Help.'):
        return 'help text'
    if key.startswith('Default.'):
        return 'Built In premade name or description'
    if key.startswith('TalentTree.'):
        return 'talent tree name'
    for prefix, area in AREAS:
        if any(f.startswith(prefix) for f in files):
            return area
    return None


def source_index(keys):
    """{key: ["path:line", ...]} for literal L["key"] reads in the addon's own Lua, for just these keys."""
    import catalog_check
    wanted = set(keys)
    found = {}
    for path in catalog_check.sources(ROOT):
        relative = path.relative_to(ROOT).as_posix()
        if L.is_locale_file(relative):
            continue
        text = path.read_text(encoding='utf-8', errors='replace')
        if 'L[' not in text:
            continue
        for key, line in catalog_check.references(text):
            if key in wanted:
                found.setdefault(key, []).append(f'{relative}:{line}')
    return found


def placeholders(english):
    return L.tokens(english)
