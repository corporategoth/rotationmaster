#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Built In rotation display names: derive, apply, check and document them.

The rule (also in Modules/README.md and tests/builtin_names.lua): the name keeps only what
tells a premade apart from its siblings, the variant, source or approach. It never repeats what
the rotation list already shows or the player already knows: the class, the edition, and a
specialization the pack declares in body.specs (the row shows it). Where a pack declares no
specialization (Classic and Burning Crusade clients, Mists "before a specialization", the
Mists Unholy Death Knight), the role or build it is for stays, because nothing else says it.
A Season of Discovery pack keeps "SoD", because Classic Era packs also load there.

  tools/builtin_names.py check              validate the names in Locales/enUS.lua
  tools/builtin_names.py apply              rewrite the Default.*.Name English from BASE names + OVERRIDES (IDs kept)
  tools/builtin_names.py docs               write docs/builtin-name-changes.md (before/after, from BASE)
"""
import glob
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = 'fe90efd'  # the revision whose names are "before"

CLASSES = ['Death Knight', 'Demon Hunter', 'Druid', 'Evoker', 'Hunter', 'Mage', 'Monk', 'Paladin', 'Priest',
           'Rogue', 'Shaman', 'Warlock', 'Warrior']
EDITION_WORDS = ['Retail', 'MoP', 'Forever', 'Season of Discovery', 'Mists of Pandaria', 'Classic Era', 'TBC', 'Burning Crusade']
SPECS = ['Beast Mastery', 'No specialization', 'Blood', 'Frost', 'Unholy', 'Devourer', 'Havoc', 'Vengeance', 'Balance', 'Feral',
         'Guardian', 'Restoration', 'Augmentation', 'Devastation', 'Preservation', 'Marksmanship', 'Survival', 'Arcane',
         'Fire', 'Brewmaster', 'Mistweaver', 'Windwalker', 'Holy', 'Protection', 'Retribution', 'Discipline', 'Shadow',
         'Assassination', 'Outlaw', 'Subtlety', 'Elemental', 'Enhancement', 'Affliction', 'Demonology', 'Destruction',
         'Arms', 'Fury', 'Combat']

# Names the rule cannot make well from the old text. Keyed by pack id.
OVERRIDES = {}
try:
    exec((Path(__file__).with_name('builtin_names_overrides.py')).read_text())
except FileNotFoundError:
    pass


def git_show(rev, path):
    return subprocess.run(['git', '-C', str(ROOT), 'show', f'{rev}:{path}'], capture_output=True, text=True, check=True).stdout


def current_names():
    """Default.*.Name -> displayed English, from the generated English catalogs."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import locales
    return {k: v for k, v in locales.english().items() if re.fullmatch(r'Default\.[^"]+\.Name', k)}


def read_names(text):
    """Names from an English file of the OLD layout (the BASE revision): L["Default.x.Name"] = "text"."""
    names = {}
    for line in text.split('\n'):
        m = re.match(r'L\["(Default\.[^"]+\.Name)"\] = "(.*)"\s*$', line)
        if m:
            names[m.group(1)] = m.group(2)
    return names


def packs():
    rows = []
    for f in sorted(glob.glob(str(ROOT / 'Modules/*/*/*.lua'))):
        if f.endswith(('bind.lua', 'blocks.lua')):
            continue
        s = Path(f).read_text()
        for m in re.finditer(r"id='(rm\.[^']+)',revision=(\d+)", s):
            tail = s[m.end():]
            nk = re.search(r"nameKey='([^']+)'", tail).group(1)
            head = tail[tail.index('body={'):][:160]
            head = head.split('switch=')[0].split('cooldowns=')[0].split('rotation=')[0]
            pr = re.search(r'priority=(-?\d+)', head)
            sp = re.search(r'specs=\{([\d,]*)\}', head)
            parts = m.group(1).split('.')
            rows.append(dict(file=f, id=m.group(1), revision=int(m.group(2)), nameKey=nk, edition=parts[1], cls=parts[2],
                             priority=int(pr.group(1)) if pr else 0, specs=(sp.group(1) or None) if sp else None))
    return rows


def capital(text):
    return text[:1].upper() + text[1:]


def derive(old, row):
    """The short name for one pack, from its old name."""
    m = re.match(r'^(?:(SoD|Forever) )?(' + '|'.join(CLASSES) + r'): (.*)$', old)
    if not m:
        raise ValueError('unexpected old name: ' + old)
    prefix, head = m.group(1), m.group(3)
    paren = ''
    m2 = re.match(r'^(.*?) \((.*)\)$', head)
    if m2:
        head, paren = m2.group(1), m2.group(2)
    sod = prefix == 'SoD'
    if 'Season of Discovery' in paren:
        sod = True
        paren = re.sub(r'Season of Discovery,? ?', '', paren)
    for word in ('Retail', 'MoP', 'Forever'):
        paren = re.sub(r'^' + word + r'(, |$)', '', paren)
    paren = paren.strip(', ')
    single = row['specs'] is not None and ',' not in row['specs']
    if single:
        for spec in sorted(SPECS, key=len, reverse=True):
            if head == spec or head.startswith(spec + ' ') or head.startswith(spec + ','):
                head = head[len(spec):].lstrip(', ')
                break
    reference = False
    if re.search(r'\breference\b', head):
        reference = True
        head = re.sub(r'\s*\breference\b', '', head).strip()
    if re.search(r'\breference\b', paren):
        reference = True
        paren = re.sub(r'\s*\breference\b', '', paren).strip()
    if head.lower() == 'blizzard assisted' and not paren:
        pass
    base = head
    if reference:
        base = (base + ' reference').strip()
    if not base and paren and not reference and not sod:
        return capital(paren)
    notes = ([ 'SoD' ] if sod else []) + ([paren] if paren else [])
    if not base:
        base = '' if notes else 'Recommended'
    text = capital(base) if base else ''
    if notes:
        text = (text + ' (' + ', '.join(notes) + ')').strip() if text else capital(', '.join(notes)) if not sod else '(' + ', '.join(notes) + ')'
    return capital(text)


def new_names(base_names, rows):
    out = {}
    for row in rows:
        old = base_names[row['nameKey']]
        out[row['nameKey']] = OVERRIDES.get(row['id']) or derive(old, row)
    return out


def check(names, rows):
    errors = []
    seen = {}
    for row in rows:
        name = names.get(row['nameKey'])
        if not name:
            errors.append(f"{row['id']}: no name")
            continue
        cls = [c for c in CLASSES if re.search(r'\b' + re.escape(c) + r'\b', name)]
        if cls:
            errors.append(f"{row['id']}: {name!r} names its class")
        if re.search(r'\b(Retail|MoP|Forever|Season of Discovery|Classic Era|TBC)\b', name):
            errors.append(f"{row['id']}: {name!r} names its edition")
        if ':' in name.split(' (')[0]:
            errors.append(f"{row['id']}: {name!r} has a class prefix")
        if name != name.strip() or name[-1] in '.,;:!' or name[0] != name[0].upper():
            errors.append(f"{row['id']}: {name!r} punctuation or capitalization")
        if row['specs'] and ',' not in row['specs']:
            for spec in ('No specialization',):
                if name.startswith(spec):
                    errors.append(f"{row['id']}: {name!r} names its specialization")
        group = 'era' if row['edition'] in ('era', 'sod') else row['edition']
        key = (row['cls'], group, row['specs'], name)
        if key in seen:
            errors.append(f"{row['id']} and {seen[key]}: both named {name!r}")
        seen[key] = row['id']
    return errors


def apply(rows, base_names):
    """Set the Default.*.Name English from BASE names + OVERRIDES (keeps each string's ID; translations become stale)."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import locales
    model = locales.Model()
    for key, name in new_names(base_names, rows).items():
        entry = model.find_key(key)
        assert entry, key
        entry.text = name
        entry.hash = locales.text_hash(name)
    model.write()


SPEC_NAMES = {'250': 'Blood', '251': 'Frost', '252': 'Unholy', '577': 'Havoc', '581': 'Vengeance', '1480': 'Devourer',
              '102': 'Balance', '103': 'Feral', '104': 'Guardian', '105': 'Restoration', '1467': 'Devastation',
              '1468': 'Preservation', '1473': 'Augmentation', '253': 'Beast Mastery', '254': 'Marksmanship', '255': 'Survival',
              '62': 'Arcane', '63': 'Fire', '64': 'Frost', '268': 'Brewmaster', '269': 'Windwalker', '270': 'Mistweaver',
              '65': 'Holy', '66': 'Protection', '70': 'Retribution', '256': 'Discipline', '257': 'Holy', '258': 'Shadow',
              '259': 'Assassination', '260': 'Outlaw', '261': 'Subtlety', '262': 'Elemental', '263': 'Enhancement',
              '264': 'Restoration', '265': 'Affliction', '266': 'Demonology', '267': 'Destruction', '71': 'Arms', '72': 'Fury',
              '73': 'Protection'}
for _id in ('1455', '1456', '1447', '1465', '1448', '1449', '1450', '1451', '1452', '1453', '1444', '1454', '1446'):
    SPEC_NAMES[_id] = 'No specialization'
EDITIONS = {'era': 'Classic Era', 'sod': 'Season of Discovery', 'tbc': 'TBC', 'forever': 'Forever', 'mop': 'Mists of Pandaria', 'retail': 'Retail'}


def docs(rows, base_names, names):
    lines = ['# Built In rotation names: before and after', '',
             'Generated by `tools/builtin_names.py docs` (before = `' + BASE + '`). Do not edit by hand.', '',
             'The rule is in `Modules/README.md`. A name keeps only the variant, source or approach; the class, the edition',
             'and a declared specialization are shown by the list row (and, on the website, by the tags under the name).',
             'Packs that declare no specialization (every Classic Era, Season of Discovery, TBC and Forever pack, the Mists "before a',
             'specialization" packs and the Mists Unholy Death Knight) keep the role or build they are for. Season of Discovery packs keep',
             '"SoD" because Classic Era packs load there too. A bare name (nothing to tell it from its siblings but being the main',
             'premade of its specialization) is "Recommended". No collision inside one class, edition and specialization needed a',
             'distinguishing word added; the four names worded by hand are marked.', '',
             '| Class | Edition | Specialization | Pack | Before | After | Note |', '|---|---|---|---|---|---|---|']
    notes = {}
    for row in rows:
        old = base_names[row['nameKey']]
        auto = derive(old, row)
        new = names[row['nameKey']]
        if row['id'] in OVERRIDES and OVERRIDES[row['id']] != auto:
            notes[row['id']] = 'worded by hand'
    order = {'retail': 0, 'mop': 1, 'forever': 2, 'tbc': 3, 'era': 4, 'sod': 5}
    for row in sorted(rows, key=lambda r: (CLASSES.index(next(c for c in CLASSES if c.replace(' ', '').lower() == r['cls'])), order[r['edition']], r['id'])):
        cls = next(c for c in CLASSES if c.replace(' ', '').lower() == row['cls'])
        lines.append('| {} | {} | {} | `{}` | {} | {} | {} |'.format(
            cls, EDITIONS[row['edition']], ('Combat' if (row['edition'], row['specs']) == ('mop', '260') else SPEC_NAMES.get(row['specs'], row['specs'])) if row['specs'] else 'not tied to one', row['id'], base_names[row['nameKey']].replace('|', '\\|'),
            names[row['nameKey']].replace('|', '\\|'), notes.get(row['id'], '')))
    (ROOT / 'docs/builtin-name-changes.md').write_text('\n'.join(lines) + '\n')


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'check'
    rows = packs()
    if cmd == 'check':
        names = current_names()
        errors = check(names, rows)
        print('\n'.join(errors) or f'{len(rows)} names ok')
        return 1 if errors else 0
    base_names = read_names(git_show(BASE, 'Locales/enUS.lua'))
    if cmd == 'apply':
        apply(rows, base_names)
        return 0
    if cmd == 'docs':
        docs(rows, base_names, current_names())
        return 0
    if cmd == 'preview':
        names = new_names(base_names, rows)
        for row in rows:
            print(f"{row['id'][3:]:48} | {base_names[row['nameKey']]} => {names[row['nameKey']]}")
        errors = check(names, rows)
        print('\n'.join(errors))
        return 0
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main())
