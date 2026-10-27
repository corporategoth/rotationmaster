#!/usr/bin/env python3
"""Prove that a formatting-only change left the compiled program alone.

  python3 tools/bytecode_equal.py                      every Lua file that differs from HEAD, compared with HEAD
  python3 tools/bytecode_equal.py --base main F ...    these files, compared with the revision `main`
  python3 tools/bytecode_equal.py --catalog            also compare the Built In helper function texts

For each file the version in the base revision and the version in the working tree are compiled with `luac5.1` and with
`luajit -bl`, and the listings are compared after removing what depends on layout only (line numbers, addresses, the
chunk name). Comments and whitespace never reach the bytecode, so equal listings mean the same program under both
interpreters. A file whose listings differ is reported with the first differing line; a file that did not exist in the
base revision is skipped.

`--catalog` additionally compares, between the base revision and the working tree, the text of every function the Built In
catalog records as a helper (`Data/builtin_sources.lua`, modules[*].bindings[*].code). Saved custom copies and exported
bundles bind to the hash of that text (`tests/private_helper_identities.lua`), so it has to be byte for byte the same.

Exit status 0 when everything compared equal, 1 when something differs, 2 when a tool could not run.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.run(['git', '-C', str(ROOT)] + list(args), capture_output=True)


def changed_files(base):
    out = git('diff', '--name-only', '--diff-filter=M', base, '--', '*.lua').stdout.decode()
    return [line for line in out.splitlines() if line]


def luac_listing(path):
    result = subprocess.run(['luac5.1', '-p', '-l', '-l', str(path)], capture_output=True, text=True, errors='replace')
    if result.returncode != 0:
        return None
    text = result.stdout.replace(str(path), 'chunk')
    text = re.sub(r'\[\d+\]', '', text)
    text = re.sub(r'<chunk:\d+,\d+>', '<chunk>', text)
    return re.sub(r'0x[0-9a-f]+', '0x', text)


def luajit_listing(path):
    result = subprocess.run(['luajit', '-bl', str(path)], capture_output=True, text=True, errors='replace')
    if result.returncode != 0:
        return None
    text = re.sub(r'-- BYTECODE -- [^\n]*?:\d+-\d+', '-- BYTECODE -- chunk', result.stdout)
    return re.sub(r'; [^\s:]*\.lua:\d+', '; chunk', text)


def first_difference(a, b):
    left, right = a.split('\n'), b.split('\n')
    for number, (x, y) in enumerate(zip(left, right), 1):
        if x != y:
            return 'line %d: %r != %r' % (number, x, y)
    return 'length %d != %d' % (len(left), len(right))


def compare_file(base, relative, scratch):
    blob = git('show', '%s:%s' % (base, relative))
    if blob.returncode != 0:
        return 'skipped (not in %s)' % base
    old = scratch / 'old.lua'
    new = scratch / 'new.lua'
    old.write_bytes(blob.stdout)
    new.write_bytes((ROOT / relative).read_bytes())
    for name, lister in (('luac5.1', luac_listing), ('luajit', luajit_listing)):
        first, second = lister(old), lister(new)
        if first is None or second is None:
            return '%s could not compile it' % name
        if first != second:
            return '%s listings differ at %s' % (name, first_difference(first, second))
    return None


def catalog_codes(source):
    script = (
        "local addon={} local chunk=assert(loadfile(arg[1])) chunk('RotationMaster',addon)\n"
        "local out={} for path,module in pairs(addon.BuiltinSourceCatalog.modules) do\n"
        "for alias,b in pairs(module.bindings) do if b.kind=='function' then out[#out+1]=path..':'..alias..'='..b.code end end end\n"
        "table.sort(out) for _,line in ipairs(out) do print((line:gsub('.',function(c) return string.format('%02x',c:byte()) end))) end\n")
    result = subprocess.run(['lua5.1', '-e', 'arg={[1]=%r} ' % str(source) + script], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr)
    return result.stdout.split('\n')


def compare_catalog(base, scratch):
    old = scratch / 'catalog_old.lua'
    old.write_bytes(git('show', '%s:Data/builtin_sources.lua' % base).stdout)
    before, after = catalog_codes(old), catalog_codes(ROOT / 'Data' / 'builtin_sources.lua')
    problems = []
    if len(before) != len(after):
        problems.append('helper count %d != %d' % (len(before), len(after)))
    for left, right in zip(before, after):
        if left != right:
            name = bytes.fromhex(left).decode('utf-8', 'replace').split('=', 1)[0]
            problems.append('helper text changed: ' + name)
    return problems


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('files', nargs='*')
    parser.add_argument('--base', default='HEAD')
    parser.add_argument('--catalog', action='store_true')
    args = parser.parse_args(argv)
    files = args.files or changed_files(args.base)
    status = 0
    with tempfile.TemporaryDirectory() as scratch_name:
        scratch = Path(scratch_name)
        equal = 0
        for relative in files:
            if relative == 'Data/builtin_sources.lua':
                continue
            problem = compare_file(args.base, relative, scratch)
            if problem is None:
                equal += 1
            else:
                print('%s: %s' % (relative, problem))
                if not problem.startswith('skipped'):
                    status = 1
        print('%d file(s) compile identically to %s' % (equal, args.base))
        if args.catalog:
            for problem in compare_catalog(args.base, scratch):
                print(problem)
                status = 1
            if status == 0:
                print('Built In helper function texts are unchanged')
    return status


if __name__ == '__main__':
    sys.exit(main())
