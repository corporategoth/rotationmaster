#!/usr/bin/env python3
"""Run, on Lua 5.1, the suites that exercise the Lua files you changed. Seconds, not minutes.

  python3 tools/fast_tests.py Core/rotation_scope.lua UI/window.lua     as the pre-commit hook calls it
  python3 tools/fast_tests.py --staged                                  the files staged in git
  python3 tools/fast_tests.py --list Core/rotation_scope.lua            only say which suites it would run

A suite is picked when it is in tools/check's command list and
  - it is a changed test itself (tests/<name>.lua), or
  - its name is the changed file's name, starts with it (`tests/rotation_scope_*.lua`), ends with it, or is
    prefixed by the file's folder (`Platform/unit_health.lua` -> `tests/platform_unit_health.lua`), or
  - for a Built In pack, it is the class scenario suite for that edition (`tests/defaults_tbc_mage.lua`).
Nothing is picked for a file with no suite of its own; that is what the full suite at push time and CI are for.
At most --max suites run (default 25); more than that means a shared file changed and the full suite is the
right tool. A failing suite prints its output and the exit status is 1.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import time

import check_all

ROOT = Path(__file__).resolve().parents[1]
LOCALE_CODES = {'enUS', 'deDE', 'esES', 'esMX', 'frFR', 'itIT', 'koKR', 'ptBR', 'ruRU', 'zhCN', 'zhTW'}
EDITIONS = {'era': 'era', 'tbc': 'tbc', 'forever': 'forever', 'retail': 'retail', 'mop': 'mop'}


def candidates(changed):
    """Test file stems (without tests/ and .lua) a changed file maps to, exact or prefix."""
    exact, loose = set(), set()
    for path in changed:
        parts = path.split('/')
        stem = parts[-1].rsplit('.', 1)[0]
        if parts[0] == 'tests' and path.endswith('.lua') and len(parts) == 2:
            exact.add(stem)
            continue
        # A text bundle's locale files (Modules/RotationMaster_HelpText/deDE.lua, ...) are locale files like Locales/*.lua.
        if parts[0] == 'Modules' and len(parts) == 3 and stem in LOCALE_CODES:
            loose.update(('client_locale', 'locale_fallback', 'text_bundles'))
            continue
        if parts[0] == 'Modules' and len(parts) >= 4 and parts[1].startswith('RotationMaster_'):
            edition, klass = EDITIONS.get(parts[2]), parts[1][len('RotationMaster_'):].lower()
            if edition:
                loose.add(f'defaults_{edition}_{klass}')
            continue
        if parts[0] == 'Locales':
            loose.update(('client_locale', 'locale_fallback', 'text_bundles'))
        elif path.endswith('.lua') and parts[0] not in ('Libs', 'LibsAugment'):
            loose.add(stem)
            if len(parts) > 1:
                loose.add(f'{parts[0].lower()}_{stem}')
    return exact, loose


def select(changed, commands):
    exact, loose = candidates(changed)
    picked = []
    for command in commands:
        if command[0] != 'lua5.1' or len(command) < 2 or not command[1].startswith('tests/'):
            continue
        stem = command[1][len('tests/'):].rsplit('.', 1)[0]
        if stem in exact or any(stem == name or stem.startswith(name + '_') or stem.endswith('_' + name) for name in loose):
            if command not in picked:
                picked.append(command)
    return picked


def staged():
    out = subprocess.run(['git', '-C', str(ROOT), 'diff', '--cached', '--name-only', '--diff-filter=ACMR'],
                         capture_output=True, text=True, check=True).stdout
    return [line for line in out.splitlines() if line]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('files', nargs='*', help='Changed files, relative to the repository root.')
    parser.add_argument('--staged', action='store_true', help='Use the files staged in git.')
    parser.add_argument('--list', action='store_true', help='Print the suites and exit.')
    parser.add_argument('--max', type=int, default=25, help='Run at most this many suites (default 25).')
    parser.add_argument('--baseline', default=str(ROOT / 'tools' / 'known_failures.txt'),
                        help='Suites known to fail (see tools/check_all.py --baseline); their failure is reported, not fatal.')
    args = parser.parse_args(argv)
    changed = staged() if args.staged else [os.path.relpath(f, ROOT) if os.path.isabs(f) else f for f in args.files]
    picked = select(changed, check_all.collect())
    if args.list:
        for command in picked:
            print(' '.join(command))
        return 0
    if not picked:
        print('fast-tests: no suite is named after the changed files; the full suite runs at push')
        return 0
    if len(picked) > args.max:
        print(f'fast-tests: {len(picked)} suites match; skipped, the full suite runs at push')
        return 0
    known = check_all.load_baseline(args.baseline) if Path(args.baseline).exists() else set()
    failed, tolerated, began = [], [], time.time()
    for command in picked:
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        if done.returncode:
            if check_all.label(command) in known:
                tolerated.append(command)
                continue
            failed.append(command)
            print(f'FAIL {" ".join(command)}')
            print(re.sub(r'^', '    ', (done.stdout + done.stderr).strip()[-3000:], flags=re.M))
    note = f', {len(tolerated)} known failing (tools/known_failures.txt)' if tolerated else ''
    print(f'fast-tests: {len(picked) - len(failed) - len(tolerated)} of {len(picked)} suite(s) passed{note} in {time.time() - began:.1f}s')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
