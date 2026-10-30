#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Report how hard the authored Lua is to read. A report only: it never fails and never edits a file.

  python3 tools/readability_report.py                 the worst files first, with totals
  python3 tools/readability_report.py --all           every file, not just the worst 40
  python3 tools/readability_report.py UI/foo.lua ...  only these files
  python3 tools/readability_report.py --json out.json machine-readable rows as well

Per file: lines, the longest line, lines over 120 and over 140 columns, `;` that separate statements on one line (a `;`
inside a table constructor or an argument list is a field separator and is not counted), functions without a comment
on the line above them, and comment lines per hundred code lines. The files measured are the ones people edit:
everything the formatter may touch (`tools/format_lua.py`), not vendored libraries, generated tables, locale catalogs,
premade rotation data or tests.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import format_lua  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SKIP_PREFIXES = ('Libs/', 'LibsAugment/', 'Locales/', 'Modules/', 'tests/', 'tools/vendor/')
SKIP_FILES = {'Data/builtin_sources.lua', 'Data/artwork.lua', 'Data/text_bundle_index.lua', 'Data/talent_trees.lua'}


def authored_files():
    out = subprocess.run(['git', '-C', str(ROOT), 'ls-files', '*.lua'], capture_output=True, text=True, check=True).stdout
    return [p for p in out.splitlines() if not p.startswith(SKIP_PREFIXES) and p not in SKIP_FILES]


def measure(path):
    source = (ROOT / path).read_text(encoding='utf-8')
    authored, _ = format_lua.split_generated(source)
    lines = authored.split('\n')
    lengths = [len(line) for line in lines]
    semicolons = 0
    uncommented_functions = 0
    comment_lines = sum(1 for line in lines if line.lstrip().startswith('--'))
    code_lines = sum(1 for line in lines if line.strip() and not line.lstrip().startswith('--'))
    try:
        tokens = format_lua.lex(authored)
    except format_lua.FormatError:
        tokens = []
    depth = 0
    for token in tokens:
        if token.kind == 'op':
            if token.text in '({[':
                depth += 1
            elif token.text in ')}]':
                depth -= 1
            elif token.text == ';' and depth == 0:
                semicolons += 1
    for index, line in enumerate(lines):
        stripped = line.lstrip()
        if (stripped.startswith('function ') or stripped.startswith('local function ')) and index:
            if not lines[index - 1].lstrip().startswith('--') and len(line) - len(stripped) == 0:
                uncommented_functions += 1
    return {
        'file': path,
        'lines': len(lines),
        'max': max(lengths) if lengths else 0,
        'over120': sum(1 for n in lengths if n > 120),
        'over140': sum(1 for n in lengths if n > 140),
        'semicolons': semicolons,
        'bare_functions': uncommented_functions,
        'comments_per_100': round(100.0 * comment_lines / code_lines, 1) if code_lines else 0.0,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('files', nargs='*')
    parser.add_argument('--all', action='store_true')
    parser.add_argument('--json')
    args = parser.parse_args(argv)
    rows = [measure(path) for path in (args.files or authored_files())]
    rows.sort(key=lambda r: (-(r['over140'] * 3 + r['over120'] + r['semicolons'] * 2), r['file']))
    shown = rows if (args.all or args.files) else rows[:40]
    print('%-44s %6s %5s %7s %7s %5s %6s %7s' % ('file', 'lines', 'max', '>120', '>140', ';', 'bare', 'cmt/100'))
    for row in shown:
        print('%-44s %6d %5d %7d %7d %5d %6d %7.1f' % (row['file'], row['lines'], row['max'], row['over120'],
                                                      row['over140'], row['semicolons'], row['bare_functions'],
                                                      row['comments_per_100']))
    total = {key: sum(r[key] for r in rows) for key in ('lines', 'over120', 'over140', 'semicolons', 'bare_functions')}
    print('\n%d files, %d lines: %d over 120 columns, %d over 140, %d statement-joining ";", %d top-level functions with no '
          'comment above them' % (len(rows), total['lines'], total['over120'], total['over140'], total['semicolons'],
                                  total['bare_functions']))
    if args.json:
        Path(args.json).write_text(json.dumps(rows, indent=1) + '\n', encoding='utf-8')
    return 0


if __name__ == '__main__':
    sys.exit(main())
