# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""User-facing English is American English: no British variants in enUS, help or docs.

Scans what players and authors read: every enUS key and value, the string
literals of the addon's own Lua (help text, condition help, report text,
premade source titles; comments and identifiers are not shown, so they are
skipped) and the Markdown docs. Game names keep Blizzard's own US spelling,
such as the Paladin's Judgement, so they are not in the list.
"""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from catalog_check import TOKEN, decode_string  # noqa: E402

_OUR = ('colo', 'behavio', 'favo', 'hono', 'armo', 'neighbo', 'flavo', 'humo', 'labo', 'rumo', 'vapo', 'odo',
        'endeavo', 'vigo', 'valo', 'harbo', 'rigo', 'savio', 'splendo', 'parlo', 'cando', 'clamo', 'fervo', 'ardo',
        'tumo', 'demeano')
_ISE = ('real', 'organ', 'recogn', 'optim', 'priorit', 'initial', 'custom', 'minim', 'maxim', 'summar', 'categor',
        'normal', 'serial', 'synchron', 'author', 'util', 'visual', 'final', 'special', 'memor', 'sanit', 'local',
        'standard', 'emphas', 'apolog', 'critic', 'capital', 'central', 'character', 'general', 'harmon', 'legal',
        'mobil', 'modern', 'neutral', 'personal', 'random', 'rational', 'stabil', 'symbol', 'token', 'econom',
        'familiar', 'formal', 'global', 'ideal', 'jeopard', 'marginal', 'penal', 'regular', 'steril', 'subsid')
_LL = ('cancel', 'travel', 'model', 'label', 'level', 'signal', 'fuel', 'total', 'counsel', 'channel', 'tunnel',
       'quarrel', 'dial', 'equal', 'unravel', 'marshal', 'shovel', 'snorkel', 'swivel', 'jewel')
_WORDS = ('centre', 'centres', 'centred', 'metre', 'metres', 'litre', 'litres', 'fibre', 'fibres', 'theatre', 'calibre',
          'sombre', 'spectre', 'lustre', 'meagre', 'sabre', 'sceptre', 'manoeuvre', 'manoeuvres',
          'grey', 'greys', 'greyed', 'greying', 'greyish', 'greyness',
          'analyse', 'analysed', 'analyses', 'analysing', 'paralyse', 'paralysed', 'catalyse',
          'licence', 'licences', 'defence', 'defences', 'offence', 'offences', 'pretence',
          'catalogue', 'catalogues', 'catalogued', 'analogue', 'programme', 'programmes',
          'whilst', 'amongst', 'learnt', 'spelt', 'aluminium', 'tyre', 'tyres', 'cheque', 'cheques', 'artefact',
          'artefacts', 'ageing', 'practise', 'practised', 'practises', 'practising', 'storey', 'storeys', 'sulphur',
          'mould', 'moulds', 'smoulder', 'plough', 'aeroplane', 'acknowledgement', 'acknowledgements',
          'enrolment', 'fulfilment', 'instalment', 'skilful', 'wilful', 'marvellous', 'jewellery', 'traveller',
          'travellers', 'focussed', 'focussing', 'speciality')
BRITISH = re.compile(
    r'\b(?:'
    + '|'.join(_WORDS)
    + r'|(?:' + '|'.join(_OUR) + r')urs?(?:ed|ing|ite|ites|able|ably|ful|less)?'
    + r'|(?:' + '|'.join(_ISE) + r')is(?:e|es|ed|ing|ation|ations|er|ers)'
    + r'|(?:' + '|'.join(_LL) + r')l(?:ed|ing)'
    + r')\b', re.I)

SKIP = ('Libs/', 'LibsAugment/', 'tests/', 'Locales/')
TRANSLATIONS = ('deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW')
# Known exceptions, by file and literal. The capture status 'cancelled' is the
# value OnCPUProfileFinished, OnCPURuntimeCaptureFinished and
# OnMemoryCaptureFinished receive (and the report's first line); the
# legacy-equivalence suites pin it through whole-file predecessor fixtures, so
# renaming it is its own change.
ALLOWED = {('Diagnostics/cpu.lua', 'cancelled'), ('Diagnostics/cpu_runtime.lua', 'cancelled'),
           ('Diagnostics/memory.lua', 'cancelled')}


def british(text):
    return sorted({m.group(0) for m in BRITISH.finditer(text)})


def lua_strings(source):
    for match in TOKEN.finditer(source):
        if match.lastgroup in ('string', 'long'):
            yield source.count('\n', 0, match.start()) + 1, decode_string(match.group())


def findings():
    found = []
    # The English of every catalog (the main one and each load-on-demand text bundle), never the translations.
    sources = [ROOT / 'Locales/enUS.lua']
    sources += sorted(ROOT.glob('Modules/*/enUS.lua'))
    sources += sorted(p for p in ROOT.rglob('*.lua')
                      if not str(p.relative_to(ROOT)).startswith(SKIP) and '.tools' not in p.parts
                      and not (p.parent.parent.name == 'Modules' and p.stem in TRANSLATIONS + ('enUS',)))
    for path in sources:
        for line, text in lua_strings(path.read_text(encoding='utf-8')):
            for word in british(text):
                if (str(path.relative_to(ROOT)), text) not in ALLOWED:
                    found.append(f'{path.relative_to(ROOT)}:{line}: {word}')
    docs = sorted((ROOT / 'docs').rglob('*.md')) + sorted(ROOT.glob('Modules/*.md')) + sorted(ROOT.glob('Assets/**/*.md'))
    for path in docs + [ROOT / 'tests/README.md']:
        for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            for word in british(line):
                found.append(f'{path.relative_to(ROOT)}:{number}: {word}')
    return found


class USSpellingTests(unittest.TestCase):
    def test_detector_catches_british_and_accepts_american(self):
        for word in ('colour', 'coloured', 'behaviour', 'favourite', 'centre', 'grey', 'greyed', 'optimised',
                     'organise', 'recognised', 'analyse', 'licence', 'defence', 'catalogue', 'cancelled',
                     'cancelling', 'travelled', 'modelled', 'labelled', 'levelling', 'channelling',
                     'acknowledgement', 'whilst'):
            self.assertEqual(british('a ' + word + ' b'), [word], word)
        for word in ('color', 'colored', 'behavior', 'favorite', 'center', 'gray', 'grayed', 'optimized',
                     'organize', 'recognized', 'analyze', 'license', 'defense', 'catalog', 'canceled',
                     'canceling', 'cancellation', 'traveled', 'modeled', 'labeled', 'leveling', 'channeling',
                     'acknowledgment', 'while', 'Judgement', 'Greymane', 'categories', 'priorities',
                     'summaries', 'advise', 'exercise', 'otherwise', 'precise', 'raise', 'devise', 'premise'):
            self.assertEqual(british('a ' + word + ' b'), [], word)

    def test_user_facing_text_uses_american_spelling(self):
        found = findings()
        self.assertEqual(found, [], 'British spellings in user-facing text:\n  ' + '\n  '.join(found))


if __name__ == '__main__':
    unittest.main()
