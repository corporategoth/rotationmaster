"""Validate every Lua source and the addon's actual TOC/XML load graph."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
errors = []
sources = sorted(root.rglob('*.lua'))
for path in sources:
    result = subprocess.run(['luac5.1', '-p', str(path)], capture_output=True)
    if result.returncode:
        errors.append(result.stderr.decode(errors='replace').strip())

seen, entries = set(), []
def walk(path):
    if not path.is_file():
        errors.append(f'Missing TOC/XML dependency: {path.relative_to(root)}')
        return
    entries.append(path)
    if path.suffix.lower() != '.xml' or path in seen:
        return
    seen.add(path)
    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:
        errors.append(f'{path}: {exc}')
        return
    for node in tree.iter():
        reference = node.get('file')
        if reference:
            walk(path.parent / reference.replace('\\', '/'))

for line in (root / 'RotationMaster.toc').read_text().splitlines():
    line = line.strip()
    if line and not line.startswith('#'):
        walk(root / line)

main_entries = {path.resolve() for path in entries}

# Built In packs ship as load-on-demand addons, one per class:
# Modules/<Addon>/ holds one folder per edition and one client-flavour TOC per
# edition, <Addon>_<Flavor>.toc, listing bind.lua then only that folder's files.
# The unsuffixed <Addon>.toc is what any other client falls back to: it loads
# nothing. Every module TOC is walked like the main one, and every Lua file
# under Modules/ must be listed by exactly one edition's TOCs. Flavours of one
# edition (Forever's _Camelot and _Forever) must be byte-identical.
FLAVOR_EDITIONS = {'TBC': 'tbc', 'Camelot': 'forever', 'Forever': 'forever', 'Standard': 'retail',
                   'Vanilla': 'era', 'Mists': 'mop', 'Cata': 'cata', 'Wrath': 'wrath'}
listings = {}
bootstrap = None
modules = sorted(path for path in (root / 'Modules').iterdir()
                 if path.is_dir() and any(path.rglob('*'))) if (root / 'Modules').is_dir() else []
def toc_files(toc):
    return [line.strip() for line in toc.read_text().splitlines() if line.strip() and not line.strip().startswith('#')]
for module in modules:
    name = module.name
    fallback = module / f'{name}.toc'
    tocs = sorted(module.glob('*.toc'))
    if not fallback.is_file():
        errors.append(f'Module lacks its fallback TOC: {fallback.relative_to(root)}')
        continue
    editions = {}
    for toc in tocs:
        text = toc.read_text()
        for header in ('## LoadOnDemand: 1', '## Dependencies: RotationMaster'):
            if header not in text.splitlines():
                errors.append(f'Module TOC lacks "{header}": {toc.relative_to(root)}')
        if not re.search(r'^## Interface: \d', text, re.M):
            errors.append(f'Module TOC lacks an Interface: {toc.relative_to(root)}')
        entries.append(toc)
        if toc == fallback:
            if toc_files(toc):
                errors.append(f'Fallback module TOC must load nothing: {toc.relative_to(root)}')
            continue
        match = re.fullmatch(re.escape(name) + r'_([A-Za-z]+)\.toc', toc.name)
        edition = match and FLAVOR_EDITIONS.get(match.group(1))
        if not edition:
            errors.append(f'Unknown module TOC flavour: {toc.relative_to(root)}')
            continue
        if edition in editions:
            if editions[edition].read_bytes() != toc.read_bytes():
                errors.append(f'Flavour TOCs of one edition differ: {toc.relative_to(root)}')
            continue
        editions[edition] = toc
        files = toc_files(toc)
        if not files or files[0] != 'bind.lua':
            errors.append(f'Module TOC must load bind.lua first: {toc.relative_to(root)}')
        for line in files:
            path = module / line.replace('\\', '/')
            walk(path)
            if line != 'bind.lua':
                if not line.startswith(edition + '/'):
                    errors.append(f'{toc.relative_to(root)} lists a file outside {edition}/: {line}')
                listings.setdefault(path.resolve(), []).append(toc)
    if (module / 'bind.lua').is_file():
        content = (module / 'bind.lua').read_bytes()
        if bootstrap is None:
            bootstrap = content
        elif content != bootstrap:
            errors.append(f'Module bootstrap differs from the others: {(module / "bind.lua").relative_to(root)}')
for module in modules:
    for path in sorted(module.rglob('*.lua')):
        if path.name == 'bind.lua' and path.parent == module:
            continue
        count = len(listings.get(path.resolve(), []))
        if count != 1:
            errors.append(f'Module file is listed by {count} edition TOCs, not exactly one: {path.relative_to(root)}')
        if path.resolve() in main_entries:
            errors.append(f'Module file is also loaded by RotationMaster.toc: {path.relative_to(root)}')
for path in sorted((root / 'Defaults').rglob('*.lua')) if (root / 'Defaults').is_dir() else []:
    errors.append(f'Packaged default outside a load-on-demand module: {path.relative_to(root)}')

manifest = json.loads((root / 'Libs/UPSTREAM.json').read_text())
vendor_files = {'UPSTREAM.json'}
for name, library in manifest['libraries'].items():
    folder = root / 'Libs' / name
    for relative, expected in library['files'].items():
        vendor_files.add(f'{name}/{relative}')
        path = folder / relative
        if not path.is_file():
            errors.append(f'Missing pinned vendor file: {path.relative_to(root)}')
        elif hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            errors.append(f'Vendor hash mismatch: {path.relative_to(root)}')
for relative, expected in manifest.get('notices', {}).items():
    vendor_files.add(relative)
    path = root / 'Libs' / relative
    if not path.is_file():
        errors.append(f'Missing vendor notice: Libs/{relative}')
    elif hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        errors.append(f'Vendor notice hash mismatch: Libs/{relative}')
actual = {str(path.relative_to(root / 'Libs')) for path in (root / 'Libs').rglob('*') if path.is_file()}
for extra in sorted(actual - vendor_files):
    errors.append(f'Unpinned vendor file: Libs/{extra}')

# Native icon controls resolve these literal names into owned TGA assets.
# Checking references catches missing artwork before the client silently omits it.
for path in sorted((root / 'UI').glob('*.lua')):
    for match in re.finditer(r"CreateWorkbench(?:Labeled)?IconButton\([^,\n]+,\s*(['\"])([^'\"]+)\1", path.read_text()):
        icon = root / 'Assets' / 'Controls' / (match.group(2) + '.tga')
        if not icon.is_file():
            errors.append(f'Missing control texture: {icon.relative_to(root)} ({path.relative_to(root)})')

# The release packager drops every .pkgmeta ignore path. Nothing the client
# loads, and no texture the artwork catalog or a control names, may be among them.
pkgmeta = (root / '.pkgmeta').read_text().splitlines() if (root / '.pkgmeta').is_file() else []
ignored = [line.strip()[2:].strip() for line in pkgmeta if line.startswith('  - ')]
# Each module must leave the zip as its own top-level AddOns folder.
moved = dict(re.fullmatch(r'  (\S+): (\S+)', line).groups() for line in pkgmeta
             if re.fullmatch(r'  (\S+): (\S+)', line))
for module in modules:
    source = f'RotationMaster/Modules/{module.name}'
    if moved.pop(source, None) != module.name:
        errors.append(f'.pkgmeta move-folders lacks {source}: {module.name}')
for source, target in sorted(moved.items()):
    errors.append(f'.pkgmeta moves a folder that is not a module: {source}: {target}')
def packaged(relative):
    return not any(relative == item or relative.startswith(item.rstrip('/') + '/') for item in ignored)
runtime = {str(path.relative_to(root)) for path in entries}
if (root / 'Data/artwork.lua').is_file():
    runtime |= {m.group(1).replace('\\\\', '/') + '.tga' for m in
                re.finditer(r'root\.\."(Assets[^"]+)"', (root / 'Data/artwork.lua').read_text())}
runtime |= {str(path.relative_to(root)) for path in (root / 'Assets' / 'Controls').glob('*.tga')}
for relative in sorted(runtime):
    if not packaged(relative):
        errors.append(f'Release package would omit a runtime file: {relative}')
    elif not (root / relative).is_file():
        errors.append(f'Missing runtime file: {relative}')

for error in errors:
    print(error)
print(f'{len(sources)} Lua sources; {len(entries)} TOC/XML entries; {len(errors)} errors')
sys.exit(bool(errors))
