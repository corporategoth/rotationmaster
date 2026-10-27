#!/usr/bin/env python3
"""Build and verify the Rotation Master release package, offline.

Reproduces what the BigWigs packager (`release.sh`, vendored under tools/vendor/bigwigs-packager)
makes from this repository's `.pkgmeta`, without a network, a token or a `zip` binary, so a
developer can dry-run a release and CI can attach the very same layout as an artifact. The
packager remains what uploads; `--parity` proves the two agree.

  python3 tools/package_release.py --check                     build RotationMaster-<version>.zip and verify it
  python3 tools/package_release.py --tag 2.0.0-beta.1 --check  the same, as that tag would be packaged
  python3 tools/package_release.py --check-zip FILE            verify a zip someone else built (the packager's)
  python3 tools/package_release.py --classify 2.0.0-beta.1     print release, beta or alpha (and exit)
  python3 tools/package_release.py --parity                    compare with the real packager in a scratch clone

What goes in the package: the files git tracks, minus dotfiles and the `.pkgmeta` ignore list, with
`@project-*@` keywords replaced, `--@do-not-package@` blocks removed, project TOCs stripped of their
`## Interface-*` lines, LF line endings, and each `move-folders` module moved to its own top-level
folder. A CHANGELOG.md in the checkout (tools/release_notes.py writes it) is added as the manual
changelog. Nothing outside the checkout is read.

`--check` fails when the package holds a path that is not for the game (tests, tools, docs, .claude,
sources, secrets), lacks a required file, has a TOC that disagrees with the supported clients or lists
a file that is missing, or has a file or zip over the size limits.
"""
import argparse
import fnmatch
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PACKAGER = ROOT / 'tools' / 'vendor' / 'bigwigs-packager' / 'release.sh'

# Interface numbers the main TOC must declare, one per supported client. Adding a client is a
# deliberate edit here and in RotationMaster.toc (docs/dev/architecture.md, "Add a client").
SUPPORTED_CLIENTS = {
    11509: 'Classic Era / Season of Discovery 1.15.9',
    20506: 'TBC Anniversary 2.5.6',
    30405: 'Wrath of the Lich King Classic 3.4.5',
    38002: 'Wrath Titan Reforged 3.80.2',
    40402: 'Cataclysm Classic 4.4.2',
    50504: 'Mists of Pandaria Classic 5.5.4',
    120105: 'Retail (Midnight) 12.1.5',
    16001: 'WoW Forever 1.60.1',
}

# Folders that never belong at the top of an addon folder (compared case-insensitively). A vendored
# library deeper down may carry its own docs or tests; these may not appear beside the addon's own files.
TOP_ONLY_COMPONENTS = {'tests', 'tools', 'docs', 'outputs', 'web', 'ci', 'scripts'}
# Folders that never belong anywhere in a package.
FORBIDDEN_COMPONENTS = {'node_modules', '__pycache__'}
FORBIDDEN_FILES = {'readme.md', 'contributing.md', 'claude.md', 'agents.md', 'todo', 'makefile', 'package.json',
                   'package-lock.json', 'pyproject.toml', 'requirements.txt', 'changelog.md.orig'}
FORBIDDEN_SUFFIXES = ('.py', '.sh', '.svg', '.psd', '.xcf', '.png', '.jpg', '.jpeg', '.zip', '.gz', '.bak', '.orig',
                      '.rej', '.swp', '.log', '.pyc', '.pem', '.key', '.env')
# Files that must be in every package: the TOC, the licenses the data and fonts require, the load lists. The third-party
# notice carries the WowSims MIT notice that the Built In rotations written from its APLs depend on.
REQUIRED = ['RotationMaster/RotationMaster.toc', 'RotationMaster/LICENSE', 'RotationMaster/Fonts/OFL.txt',
            'RotationMaster/THIRD_PARTY_NOTICES.md', 'RotationMaster/embeds.xml', 'RotationMaster/locales.xml']
NOTICE = 'Copyright (c) 2022 wowsims team'
TOC_SUFFIXES = ['', '-Mainline', '_Mainline', '-Classic', '_Classic', '-Vanilla', '_Vanilla', '-BCC', '_BCC', '-TBC',
                '_TBC', '-Wrath', '_Wrath', '-WOTLKC', '_WOTLKC', '-Cata', '_Cata', '-Mists', '_Mists', '-Camelot', '_Camelot']
TEXT_PATTERNS = ('*.lua', '*.md', '*.toc', '*.txt', '*.xml')
KEYWORD = re.compile(r'@project-(?:version|revision|hash|abbreviated-hash|author|date-iso|date-integer|timestamp)@')
UNSUPPORTED = re.compile(r'@(?:file|build)-[a-z-]+@|@(?:non-)?(?:alpha|debug|no-lib-strip|localization|retail|version-[a-z]+)\b[^@\n]*@')
MAX_FILE_KB = 4096
MAX_ZIP_MB = 50


class PackageError(Exception):
    pass


def git(root, *args, check=True):
    done = subprocess.run(['git', '-C', str(root), *args], capture_output=True)
    if check and done.returncode:
        raise PackageError(f'git {" ".join(args)} failed: {done.stderr.decode(errors="replace").strip()}')
    return done.stdout.decode('utf-8', 'replace').strip() if done.returncode == 0 else ''


def classify(tag):
    """The packager's rule: the word alpha, else the word beta, anywhere in the tag; no tag is alpha."""
    if not tag:
        return 'alpha'
    lowered = tag.lower()
    return 'alpha' if 'alpha' in lowered else 'beta' if 'beta' in lowered else 'release'


def parse_pkgmeta(path):
    """The subset of .pkgmeta this repository uses, read the way release.sh reads it."""
    meta = {'package-as': None, 'move-folders': {}, 'ignore': [], 'changelog': None}
    phase = None
    for raw in Path(path).read_text(encoding='utf-8').splitlines():
        line = raw.rstrip('\r')
        if re.match(r'\s*#', line) or not line.strip():
            continue
        if not line.startswith(' '):
            key, _, value = line.partition(':')
            phase, value = key.strip(), value.strip()
            if phase == 'package-as':
                meta['package-as'] = value
            elif phase == 'manual-changelog' and value:
                meta['changelog'] = value
            continue
        body = line.strip()
        if body.startswith('- ') and phase == 'ignore':
            meta['ignore'].append(body[2:].strip())
        elif phase == 'move-folders' and ':' in body and not body.startswith('-'):
            key, _, value = body.partition(':')
            meta['move-folders'][key.strip()] = value.strip()
        elif phase == 'manual-changelog' and body.startswith('filename:'):
            meta['changelog'] = body.partition(':')[2].strip()
    if not meta['package-as']:
        raise PackageError('.pkgmeta has no package-as')
    return meta


def ignore_globs(root, items):
    """release.sh's translation of an ignore entry into shell globs."""
    globs = []
    for item in items:
        item = item[:-2] if item.endswith('/*') else item
        target = root / item
        if target.is_dir():
            globs.append(item + '/*')
        elif target.is_file():
            globs.append(item)
        else:
            globs.extend([item, item + '/*'])
    return globs


def project_info(root, tag=None, version=None):
    """The values release.sh derives from git: version, revision, hash, author and times."""
    head = git(root, 'rev-parse', 'HEAD')
    stamp = int(git(root, 'show', '--no-patch', '--format=%at', 'HEAD'))
    gmt = time.gmtime(stamp)
    if not version:
        if tag:
            version = tag
        else:
            on_tag = git(root, 'tag', '--points-at', 'HEAD', '--sort=-v:refname').splitlines()
            version = on_tag[0] if on_tag else (
                git(root, 'describe', '--tags', '--abbrev=7', '--exclude=*[Aa][Ll][Pp][Hh][Aa]*', check=False)
                or git(root, 'describe', '--tags', '--always', '--abbrev=7'))
            tag = on_tag[0] if on_tag else None
    return {
        'version': version, 'tag': tag, 'type': classify(tag),
        'revision': git(root, 'rev-list', '--count', head), 'hash': head,
        'abbreviated-hash': git(root, 'show', '--no-patch', '--abbrev=7', '--format=%h', 'HEAD'),
        'author': git(root, 'show', '--no-patch', '--format=%an', 'HEAD'),
        'timestamp': str(stamp),
        'date-iso': time.strftime('%Y-%m-%dT%H:%M:%SZ', gmt),
        'date-integer': time.strftime('%Y%m%d%H%M%S', gmt),
    }


def tracked_files(root):
    names = subprocess.run(['git', '-C', str(root), 'ls-files', '-z'], capture_output=True, check=True).stdout.split(b'\0')
    return sorted(n.decode('utf-8') for n in names if n and (root / n.decode('utf-8')).is_file())


def drop_blocks(text, start, end):
    """sed '/start/,/end/d': remove each marked range, markers included."""
    kept, skipping = [], False
    for line in text.split('\n'):
        if not skipping and start in line:
            skipping = True
        if not skipping:
            kept.append(line)
        elif end in line:
            skipping = False
    return '\n'.join(kept)


def process_text(relative, data, info, project_toc):
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        return data
    if UNSUPPORTED.search(text) and not relative.startswith(('Libs/', 'tests/')):
        raise PackageError(f'{relative}: uses a packager keyword this tool does not reproduce; use release.sh')
    if relative.endswith('.lua'):
        text = drop_blocks(text, '--@do-not-package@', '--@end-do-not-package@')
    elif relative.endswith('.toc'):
        text = drop_blocks(text, '#@do-not-package@', '#@end-do-not-package@')
        if project_toc:
            if text.startswith('﻿'):
                text = text[1:]
            text = '\n'.join(line for line in text.split('\n') if not line.startswith('## Interface-'))
    elif relative.endswith('.xml'):
        text = drop_blocks(text, '<!--@do-not-package@-->', '<!--@end-do-not-package@-->')
    for key in ('revision', 'hash', 'abbreviated-hash', 'author', 'date-iso', 'date-integer', 'timestamp', 'version'):
        text = text.replace(f'@project-{key}@', info[key])
    return '\n'.join(line.rstrip('\r') for line in text.split('\n')).encode('utf-8')


def project_tocs(root, meta):
    """TOCs release.sh treats as project TOCs: the root's and each move-folders root's, by its candidate suffixes."""
    found = {f'{meta["package-as"]}{suffix}.toc' for suffix in TOC_SUFFIXES}
    tocs = set(found)
    for source, target in meta['move-folders'].items():
        if '/' not in target:
            folder = source.split('/', 1)[1]
            tocs |= {f'{folder}/{target}{suffix}.toc' for suffix in TOC_SUFFIXES}
    return tocs


def build_files(root, meta, info, changelog=None):
    """The package as {path inside the zip: bytes}."""
    patterns = ignore_globs(root, meta['ignore'])
    project = project_tocs(root, meta)
    package = meta['package-as']
    files = {}
    for relative in tracked_files(root):
        if any(part.startswith('.') for part in relative.split('/')):
            continue
        if any(fnmatch.fnmatchcase(relative, pattern) for pattern in patterns):
            continue
        data = (root / relative).read_bytes()
        if relative.endswith(tuple(p[1:] for p in TEXT_PATTERNS)):
            data = process_text(relative, data, info, relative in project)
        files[relative] = data
    if meta['changelog']:
        source = Path(changelog) if changelog else root / meta['changelog']
        if source.is_file():
            files[meta['changelog']] = process_text(meta['changelog'], source.read_bytes(), info, False)
    layout = {}
    moved = {src.split('/', 1)[1]: dst for src, dst in meta['move-folders'].items()}
    for relative, data in files.items():
        top = next((folder for folder in moved if relative.startswith(folder + '/')), None)
        if top:
            layout[f'{moved[top]}/{relative[len(top) + 1:]}'] = data
        else:
            layout[f'{package}/{relative}'] = data
    return layout


def write_zip(layout, destination, info):
    stamp = time.gmtime(int(info['timestamp']))
    date_time = (max(1980, stamp.tm_year), stamp.tm_mon, stamp.tm_mday, stamp.tm_hour, stamp.tm_min, stamp.tm_sec)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in sorted(layout):
            entry = zipfile.ZipInfo(name, date_time)
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o644 << 16
            archive.writestr(entry, layout[name], zipfile.ZIP_DEFLATED, 9)
    return destination


# ---------------------------------------------------------------------------------------- checking

def toc_directives(text):
    return {m.group(1): m.group(2).strip() for m in re.finditer(r'^## ([A-Za-z0-9-]+):[ \t]*(.*)$', text, re.M)}


def toc_files(text):
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            yield line.replace('\\', '/')


def xml_files(text):
    text = re.sub(r'<!--.*?-->', '', text, flags=re.S)
    for match in re.finditer(r'<(?:Script|Include)\s+file="([^"]+)"', text):
        yield match.group(1).replace('\\', '/')


def resolve(base, reference):
    """A path a TOC or XML names, joined to the directory that file is in; a case-sensitive lookup."""
    parts = []
    for part in (base + '/' + reference if base else reference).split('/'):
        if part == '..':
            if parts:
                parts.pop()
        elif part not in ('', '.'):
            parts.append(part)
    return '/'.join(parts)


def check_layout(layout, meta, version, source_root=ROOT, interfaces=None, max_file_kb=MAX_FILE_KB, zip_bytes=None,
                 max_zip_mb=MAX_ZIP_MB):
    """Return the list of problems with a package, given as {path: bytes}."""
    problems = []
    package = meta['package-as']
    modules = sorted(set(meta['move-folders'].values()))
    expected_tops = {package, *modules}
    names = set(layout)
    lowered = {}
    for name in sorted(names):
        lowered.setdefault(name.lower(), []).append(name)
    for variants in lowered.values():
        if len(variants) > 1:
            problems.append(f'paths differ only by case (breaks on Windows and macOS): {", ".join(variants)}')
    tops = {name.split('/', 1)[0] for name in names}
    for top in sorted(tops - expected_tops):
        problems.append(f'unexpected top-level entry in the zip: {top}')
    for top in sorted(expected_tops - tops):
        problems.append(f'missing top-level folder: {top}')
    for name in sorted(names):
        parts = name.split('/')
        if name.startswith('/') or '..' in parts or '\\' in name:
            problems.append(f'unsafe path: {name}')
        for index, part in enumerate(parts):
            if part.startswith('.'):
                problems.append(f'dotfile in the package: {name}')
                break
            low = part.lower()
            if low in FORBIDDEN_COMPONENTS or (low in TOP_ONLY_COMPONENTS and index == 1):
                problems.append(f'development path in the package: {name}')
                break
        base = parts[-1].lower()
        if len(parts) == 2 and base in FORBIDDEN_FILES:
            problems.append(f'development file in the package: {name}')
        elif base.endswith(FORBIDDEN_SUFFIXES):
            problems.append(f'file type that is not for the game: {name}')
        if len(layout[name]) > max_file_kb * 1024:
            problems.append(f'{name} is {len(layout[name]) // 1024} KB (limit {max_file_kb} KB)')
    for required in REQUIRED:
        if required not in names:
            problems.append(f'required file is missing: {required}')
    if NOTICE.encode() not in layout.get('RotationMaster/THIRD_PARTY_NOTICES.md', NOTICE.encode()):
        problems.append(f'RotationMaster/THIRD_PARTY_NOTICES.md does not carry the WowSims MIT notice ("{NOTICE}")')
    for module in modules:
        if f'{module}/{module}.toc' not in names:
            problems.append(f'module has no {module}.toc: {module}')
    wanted = interfaces if interfaces is not None else set(SUPPORTED_CLIENTS)
    for name in sorted(n for n in names if n.endswith('.toc')):
        try:
            text = layout[name].decode('utf-8')
        except UnicodeDecodeError:
            problems.append(f'{name}: not UTF-8')
            continue
        if text.startswith('﻿'):
            problems.append(f'{name}: has a byte order mark')
        directives = toc_directives(text)
        numbers = [part.strip() for part in directives.get('Interface', '').split(',') if part.strip()]
        if not numbers or not all(re.fullmatch(r'\d{5,6}', n) for n in numbers):
            problems.append(f'{name}: ## Interface must list client numbers, got {directives.get("Interface")!r}')
        else:
            declared = {int(n) for n in numbers}
            if name == f'{package}/{package}.toc' and declared != wanted:
                problems.append(f'{name}: ## Interface is {sorted(declared)}; the supported clients are {sorted(wanted)}')
            elif not declared <= wanted:
                problems.append(f'{name}: ## Interface names an unsupported client: {sorted(declared - wanted)}')
        if directives.get('Version') != version:
            problems.append(f'{name}: ## Version is {directives.get("Version")!r}, expected {version!r}')
        base = name.rsplit('/', 1)[0] if '/' in name else ''
        for reference in toc_files(text):
            target = resolve(base, reference)
            if target not in names:
                problems.append(f'{name}: lists {reference}, which is not in the package')
    for name in sorted(n for n in names if n.endswith('.xml')):
        try:
            text = layout[name].decode('utf-8')
        except UnicodeDecodeError:
            continue
        base = name.rsplit('/', 1)[0] if '/' in name else ''
        for reference in xml_files(text):
            target = resolve(base, reference)
            if target not in names:
                problems.append(f'{name}: includes {reference}, which is not in the package')
    for name in sorted(n for n in names if n.endswith(tuple(p[1:] for p in TEXT_PATTERNS))):
        text = layout[name].decode('utf-8', 'replace')
        if KEYWORD.search(text):
            problems.append(f'{name}: an @project-*@ keyword was not replaced')
        if '\r' in text:
            problems.append(f'{name}: has CR line endings')
    if zip_bytes is not None and zip_bytes > max_zip_mb * 1024 * 1024:
        problems.append(f'the zip is {zip_bytes // (1024 * 1024)} MB (limit {max_zip_mb} MB)')
    return problems


def read_zip(path):
    layout = {}
    with zipfile.ZipFile(path) as archive:
        bad = archive.testzip()
        if bad:
            raise PackageError(f'{path}: corrupt entry {bad}')
        seen = set()
        for info in archive.infolist():
            if info.filename.endswith('/'):
                continue
            if info.filename in seen:
                raise PackageError(f'{path}: duplicate entry {info.filename}')
            seen.add(info.filename)
            layout[info.filename] = archive.read(info)
    return layout


def describe(layout, zip_path=None):
    """The package layout, one line per top-level folder."""
    rows = {}
    for name, data in layout.items():
        top = name.split('/', 1)[0]
        count, size = rows.get(top, (0, 0))
        rows[top] = (count + 1, size + len(data))
    lines = [f'{top:34s} {count:5d} files {size / 1024:10.0f} KB' for top, (count, size) in sorted(rows.items())]
    total = sum(len(d) for d in layout.values())
    lines.append(f'{"total":34s} {len(layout):5d} files {total / 1024:10.0f} KB')
    if zip_path:
        lines.append(f'zip: {Path(zip_path).name}  {Path(zip_path).stat().st_size / 1024:.0f} KB')
    return '\n'.join(lines)


# ------------------------------------------------------------------------------------------ parity

def parity(root, version_arg, meta):
    """Package a scratch clone with the vendored release.sh and compare with this tool's output byte for byte."""
    if not PACKAGER.is_file():
        raise PackageError('the vendored packager is missing')
    if git(root, 'status', '--porcelain', '--untracked-files=no'):
        print('note: uncommitted changes are not in a clone; commit them first to compare them', file=sys.stderr)
    with tempfile.TemporaryDirectory(prefix='rm-parity-') as scratch:
        clone, out = Path(scratch) / 'clone', Path(scratch) / 'out'
        common = git(root, 'rev-parse', '--git-common-dir')
        common = str((root / common).resolve()) if not os.path.isabs(common) else common
        subprocess.run(['git', 'clone', '-q', '--shared', '--no-checkout', common, str(clone)], check=True)
        subprocess.run(['git', '-C', str(clone), 'checkout', '-q', git(root, 'rev-parse', 'HEAD')], check=True)
        changelog = clone / (meta['changelog'] or 'CHANGELOG.md')
        changelog.write_text('# Parity fixture\n\n- one line\n', encoding='utf-8')
        env = dict(os.environ)
        for name in ('GITHUB_REF', 'GITHUB_REF_NAME', 'GITHUB_ACTIONS'):
            env.pop(name, None)
        command = ['bash', str(PACKAGER), '-d', '-z', '-u', '-e', '-l', '-r', str(out), '-t', str(clone)]
        done = subprocess.run(command, capture_output=True, env=env)
        if done.returncode:
            raise PackageError('release.sh failed:\n' + done.stdout.decode(errors='replace')[-2000:] + done.stderr.decode(errors='replace')[-2000:])
        theirs = {}
        for path in sorted(out.rglob('*')):
            if path.is_file():
                theirs[path.relative_to(out).as_posix()] = path.read_bytes()
        info = project_info(clone)
        ours = build_files(clone, meta, info)
        only_ours, only_theirs = sorted(set(ours) - set(theirs)), sorted(set(theirs) - set(ours))
        different = sorted(n for n in set(ours) & set(theirs) if ours[n] != theirs[n])
        print(f'parity: {len(ours)} files here, {len(theirs)} from release.sh, version {info["version"]}')
        for label, names in (('only in this tool', only_ours), ('only in release.sh', only_theirs), ('different bytes', different)):
            for name in names[:20]:
                print(f'  {label}: {name}')
            if len(names) > 20:
                print(f'  {label}: ... and {len(names) - 20} more')
        return not (only_ours or only_theirs or different)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--root', type=Path, default=ROOT, help='The checkout to package (default: this one).')
    parser.add_argument('--tag', help='Package as this tag (version = the tag; beta or alpha from its name).')
    parser.add_argument('--version', help='Override the version string without changing the release type.')
    parser.add_argument('--out', type=Path, help='Directory for the zip (default: <root>/.release).')
    parser.add_argument('--changelog', type=Path, help='Manual changelog to include (default: <root>/CHANGELOG.md when present).')
    parser.add_argument('--check', action='store_true', help='Verify the package after building it.')
    parser.add_argument('--check-zip', type=Path, metavar='ZIP', help='Verify an existing zip instead of building one.')
    parser.add_argument('--classify', metavar='TAG', help='Print release, beta or alpha for a tag and exit.')
    parser.add_argument('--parity', action='store_true', help='Compare with the vendored release.sh in a scratch clone.')
    parser.add_argument('--interfaces', help='Comma-separated Interface numbers instead of the supported-client table.')
    parser.add_argument('--max-file-kb', type=int, default=MAX_FILE_KB)
    parser.add_argument('--max-zip-mb', type=int, default=MAX_ZIP_MB)
    parser.add_argument('--github-output', action='store_true', help='Print version, type and prerelease as key=value lines.')
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        if args.classify is not None:
            print(classify(args.classify))
            return 0
        meta = parse_pkgmeta(root / '.pkgmeta')
        interfaces = {int(n) for n in args.interfaces.split(',')} if args.interfaces else None
        if args.check_zip:
            version = args.version or args.tag
            layout = read_zip(args.check_zip)
            if not version:
                toc = layout.get(f'{meta["package-as"]}/{meta["package-as"]}.toc', b'').decode('utf-8', 'replace')
                version = toc_directives(toc).get('Version', '')
            print(describe(layout, args.check_zip))
            problems = check_layout(layout, meta, version, root, interfaces, args.max_file_kb,
                                    args.check_zip.stat().st_size, args.max_zip_mb)
            return report(problems)
        if args.parity:
            return 0 if parity(root, args.version, meta) else 1
        info = project_info(root, args.tag, args.version)
        if args.github_output:
            print(f'version={info["version"]}\ntype={info["type"]}\nprerelease={"true" if info["type"] != "release" else "false"}')
        layout = build_files(root, meta, info, args.changelog)
        zip_path = write_zip(layout, (args.out or root / '.release') / f'{meta["package-as"]}-{info["version"]}.zip', info)
        print(f'{info["type"]} {info["version"]} -> {zip_path}')
        print(describe(layout, zip_path))
        if args.check:
            return report(check_layout(layout, meta, info['version'], root, interfaces, args.max_file_kb,
                                       zip_path.stat().st_size, args.max_zip_mb))
        return 0
    except PackageError as error:
        print(f'package_release: {error}', file=sys.stderr)
        return 2


def report(problems):
    for problem in problems[:60]:
        print(f'FAIL {problem}')
    if len(problems) > 60:
        print(f'FAIL ... and {len(problems) - 60} more')
    print('package check:', f'{len(problems)} problem(s)' if problems else 'ok')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
