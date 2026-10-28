#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Per-locale translation status: what is missing, stale, untranslated or invalid.

A wrapper over tools/locales.py (which owns reading, checking and building locale files).

  python3 tools/translation_status.py                       table for every locale
  python3 tools/translation_status.py deDE frFR             only those
  python3 tools/translation_status.py --json                machine-readable summary
  python3 tools/translation_status.py --json --details      with the key lists
  python3 tools/translation_status.py --fail-on invalid,orphans   exit 1 when any locale has that (for CI)

Columns:
  complete    translated from the current English (identical-to-English entries count when they are names)
  missing     the key has no entry; the game shows English
  stale       translated from English that has since changed (`-- en:` comment differs)
  same        equal to the English and not a name: probably never translated
  invalid     placeholders, color codes or format specifiers differ from the English (locales.py check fails)
  orphans     entries whose key left enUS

Not flagged as "same": strings with no words once placeholders are removed, proper nouns and product names
(tools/translation_exempt.json, the supported addons in tools/integration_projects.json, and strings that
8 or more locales leave unchanged), keys listed under keep_english for that locale, and, as "cognate" (reported
apart), strings identical to English in 3 or more locales, which are usually loanwords.
"""
import argparse
import json
import sys

import translation_lib as T

FAIL_KEYS = {'missing', 'stale', 'same', 'invalid', 'orphans'}


def summarize(corpus, locale, details):
    state = corpus.classify(locale)
    reasons = {}
    for reason in state['exempt'].values():
        reasons[reason] = reasons.get(reason, 0) + 1
    total = len(corpus.english)
    summary = {
        'entries': len(corpus.entries[locale]), 'english': total, 'complete': len(state['complete']),
        'missing': len(state['missing']), 'stale': len(state['stale']), 'same': len(state['suspect']),
        'invalid': len(state['invalid']), 'orphans': len(state['orphans']),
        'identical_exempt': dict(sorted(reasons.items())),
        'coverage_percent': round(100.0 * len(state['complete']) / total, 2) if total else 100.0,
    }
    if details:
        summary['keys'] = {
            'missing': state['missing'], 'stale': state['stale'], 'same': state['suspect'],
            'invalid': state['invalid'], 'orphans': state['orphans'],
            'cognate': sorted(k for k, r in state['exempt'].items() if r == 'cognate'),
        }
    return summary


def table(rows):
    header = ['locale', 'entries', 'complete', 'missing', 'stale', 'same', 'invalid', 'orphans', 'coverage']
    lines = [header]
    for locale, row in rows.items():
        lines.append([locale, row['entries'], row['complete'], row['missing'], row['stale'], row['same'],
                      row['invalid'], row['orphans'], f'{row["coverage_percent"]:.1f}%'])
    widths = [max(len(str(line[i])) for line in lines) for i in range(len(header))]
    out = []
    for n, line in enumerate(lines):
        out.append('  '.join(str(cell).rjust(widths[i]) if i else str(cell).ljust(widths[i]) for i, cell in enumerate(line)))
        if n == 0:
            out.append('  '.join('-' * w for w in widths))
    return '\n'.join(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('locales', nargs='*', help='Locales to report (default: all ten).')
    parser.add_argument('--json', action='store_true', help='Print JSON instead of a table.')
    parser.add_argument('--details', action='store_true', help='Include the key lists (JSON only).')
    parser.add_argument('--fail-on', default='', help='Comma list of ' + ', '.join(sorted(FAIL_KEYS)) + ': exit 1 if any locale has one.')
    args = parser.parse_args(argv)
    unknown = [l for l in args.locales if l not in T.LOCALES]
    if unknown:
        parser.error(f'unknown locale {", ".join(unknown)}; known: {", ".join(T.LOCALES)}')
    fail_on = {part.strip() for part in args.fail_on.split(',') if part.strip()}
    if fail_on - FAIL_KEYS:
        parser.error(f'--fail-on knows {", ".join(sorted(FAIL_KEYS))}')
    corpus = T.Corpus()
    rows = {locale: summarize(corpus, locale, args.details) for locale in (args.locales or T.LOCALES)}
    if args.json:
        json.dump({'source': 'Locales/enUS.lua', 'english_entries': len(corpus.english), 'locales': rows},
                  sys.stdout, ensure_ascii=False, indent=1)
        print()
    else:
        print(f'{len(corpus.english)} English entries\n')
        print(table(rows))
        note = [k for k in ('same', 'stale') if any(row[k] for row in rows.values())]
        if note:
            print('\nNext: python3 tools/translation_todo.py <locale> writes the work file; see docs/translators/README.md')
    failed = sorted(f'{locale} {key}={rows[locale][key]}' for locale in rows for key in fail_on if rows[locale][key])
    if failed:
        print('translation_status: ' + '; '.join(failed), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
