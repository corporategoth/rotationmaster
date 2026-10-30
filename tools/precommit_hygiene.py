#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Small repository guards the pre-commit configuration calls. Check-only: nothing is rewritten.

  precommit_hygiene.py forbidden [FILES]   paths that must not be committed (planning documents, local settings, outputs)
  precommit_hygiene.py secrets FILES       credential-shaped text in the given files
  precommit_hygiene.py endings FILES       carriage returns or a byte order mark in text the game and tools read as LF
  precommit_hygiene.py lua-syntax FILES    every Lua file parses with the Lua 5.1 compiler (luac5.1 -p)

Without FILES, forbidden/secrets/endings look at everything git tracks. A guard prints one line per problem
and exits 1; it never edits a file (the whitespace fixers in .pre-commit-config.yaml do that).
"""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

# Documents that describe intended work. The repository records how things are (docs/ and README),
# so a plan, a to-do list or a proposal lives outside it and only the result is committed.
PLANNING_NAME = re.compile(r'^(plan|plans|planning|todo|to-do|roadmap|design-proposal|proposal|rfc|brainstorm|migration-plan)([-_. 0-9].*)?$', re.I)
PLANNING_DIRS = ('docs/plans/', 'docs/plan/', 'docs/adr/', 'docs/projects/', 'docs/proposals/', 'docs/superpowers/', 'docs/roadmap/')
FORBIDDEN_EXACT = {
    '.claude/settings.local.json': 'personal Claude settings (machine-local; never committed)',
}
FORBIDDEN_PREFIX = (
    ('outputs/', 'generated output belongs outside the repository'),
    ('Web/', 'the website lives in its own repository'),
    ('.release/', 'package build output'),
    ('dist/', 'package build output'),
    ('.tools/', 'downloaded tools'),
)
FORBIDDEN_SUFFIX = ('.bak', '.orig', '.rej', '.pem', '.p12', '.pfx', '.kdbx')
FORBIDDEN_NAMES = {'id_rsa', 'id_ed25519', '.env', '.netrc'}
GENERATED_ROOT = {'CHANGELOG.md'}

SECRET_PATTERNS = [
    ('private key block', re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----')),
    ('GitHub token', re.compile(r'\bgh[pousr]_[A-Za-z0-9]{30,}\b')),
    ('GitHub fine-grained token', re.compile(r'\bgithub_pat_[A-Za-z0-9_]{40,}\b')),
    ('AWS access key id', re.compile(r'\bAKIA[0-9A-Z]{16}\b')),
    ('Slack token', re.compile(r'\bxox[abprs]-[A-Za-z0-9-]{20,}\b')),
    ('bearer or token header with a literal value',
     re.compile(r'(?i)authorization:\s*(?:bearer|token)\s+(?!\$|\{\{|<|%|"?\$)[A-Za-z0-9._\-]{20,}')),
    ('release credential assigned a literal',
     re.compile(r'(?i)\b(?:CF_API_KEY|CF_API_TOKEN|WOWI_API_TOKEN|WAGO_API_TOKEN|GITHUB_OAUTH|CURSEFORGE_TOKEN|GITEA_TOKEN)\b'
                r'["\']?\s*[:=]\s*["\']?(?!\$|\{\{|<|%|\*|["\']|\s|$)[A-Za-z0-9._\-]{16,}')),
    ('password or secret assigned a literal',
     re.compile(r'(?i)\b(?:password|passwd|secret|api[_-]?key)\b["\']?\s*[:=]\s*["\'][^"\'$\s{<%*]{12,}["\']')),
]
# Files whose text legitimately discusses credentials (this guard, the docs that name the secrets, the fixtures).
SECRET_SKIP = ('tools/precommit_hygiene.py', 'tools/test_devtools.py', 'Libs/', 'Locales/', 'tests/', 'Assets/', 'Fonts/')
LF_ONLY = ('.lua', '.toc', '.xml', '.py', '.md', '.yml', '.yaml', '.txt', '.json')
LF_SKIP = ('Libs/', 'LibsAugment/', 'Fonts/', 'tests/fixtures/', 'tools/vendor/')


def tracked(root=ROOT):
    out = subprocess.run(['git', '-C', str(root), 'ls-files', '-z'], capture_output=True, check=True).stdout
    return [n.decode('utf-8') for n in out.split(b'\0') if n]


def relative(name):
    path = Path(name)
    if path.is_absolute():
        try:
            return path.resolve().relative_to(ROOT).as_posix()
        except ValueError:
            return path.as_posix()
    return path.as_posix()


def check_forbidden(names):
    problems = []
    for name in names:
        base = name.rsplit('/', 1)[-1]
        stem = base.rsplit('.', 1)[0] if '.' in base else base
        if name in FORBIDDEN_EXACT:
            problems.append(f'{name}: {FORBIDDEN_EXACT[name]}')
        elif name.startswith(PLANNING_DIRS):
            problems.append(f'{name}: planning documents are not committed (docs describe how things are)')
        elif name.startswith('docs/') and name.endswith(('.md', '.txt', '.rst')) and PLANNING_NAME.match(stem):
            problems.append(f'{name}: looks like a plan, to-do list or proposal; docs describe how things are, not plans')
        elif any(name.startswith(prefix) for prefix, _ in FORBIDDEN_PREFIX):
            why = next(why for prefix, why in FORBIDDEN_PREFIX if name.startswith(prefix))
            problems.append(f'{name}: {why}')
        elif name.endswith(FORBIDDEN_SUFFIX) or base in FORBIDDEN_NAMES or name in GENERATED_ROOT:
            problems.append(f'{name}: not committed (backup copy, key material, or a generated file)')
    return problems


def check_secrets(names):
    problems = []
    for name in names:
        if name.startswith(SECRET_SKIP):
            continue
        path = ROOT / name
        if not path.is_file() or path.stat().st_size > 2_000_000:
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except (UnicodeDecodeError, OSError):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            for label, pattern in SECRET_PATTERNS:
                if pattern.search(line):
                    problems.append(f'{name}:{number}: looks like a {label}')
    return problems


def check_endings(names):
    problems = []
    for name in names:
        if not name.endswith(LF_ONLY) or name.startswith(LF_SKIP):
            continue
        path = ROOT / name
        if not path.is_file():
            continue
        data = path.read_bytes()
        if b'\r' in data:
            problems.append(f'{name}: has carriage returns (the repository is LF; the packager would rewrite them anyway)')
        if data.startswith(b'\xef\xbb\xbf') and name.endswith(('.lua', '.toc', '.xml')):
            problems.append(f'{name}: starts with a byte order mark')
    return problems


def check_lua(names):
    lua = [str(ROOT / n) for n in names if n.endswith('.lua') and (ROOT / n).is_file()]
    if not lua:
        return []
    luac = shutil.which('luac5.1') or shutil.which('luac')
    if not luac:
        return ['luac5.1 is not installed; install lua5.1 (the Lua 5.1 compiler is the syntax authority)']
    problems = []
    for start in range(0, len(lua), 200):
        done = subprocess.run([luac, '-p', *lua[start:start + 200]], capture_output=True, text=True)
        if done.returncode:
            problems.extend(line.replace(str(ROOT) + '/', '') for line in done.stderr.splitlines() if line.strip())
    return problems


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('guard', choices=['forbidden', 'secrets', 'endings', 'lua-syntax'])
    parser.add_argument('files', nargs='*')
    args = parser.parse_args(argv)
    names = [relative(n) for n in args.files] if args.files else tracked()
    problems = {'forbidden': check_forbidden, 'secrets': check_secrets, 'endings': check_endings,
                'lua-syntax': check_lua}[args.guard](names)
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
