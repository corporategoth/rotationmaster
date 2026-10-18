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

loaded = {path.resolve() for path in entries}
for path in sorted((root / 'Defaults').rglob('*.lua')):
    if path.resolve() not in loaded:
        errors.append(f'Packaged default is not loaded: {path.relative_to(root)}')

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

for error in errors:
    print(error)
print(f'{len(sources)} Lua sources; {len(entries)} TOC/XML entries; {len(errors)} errors')
sys.exit(bool(errors))
