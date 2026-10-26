#!/usr/bin/env python3
"""Regenerate tests/fixtures/wowsims/ from a checkout of the Rotation Master website.

The golden tests (tests/wowsims_golden.lua) hold the Lua converter to what the website's converter makes of real
WowSims presets. This copies a representative subset of the website's fixtures and golden outputs, the two real
exports a player made on wowsims.com, and the Built In rotations the website's export golden is made from, and
reduces the website's id data to the ids those files mention (so the fixture stays small and every id's answer is
exactly what the full lists would give).

  python3 tools/wowsims_test_data.py PATH_TO_WEBSITE_CHECKOUT

Needs node (to read the website's Built In rotations through its own code). Review the diff before committing.
The presets are from the WowSims repositories (MIT, tests/fixtures/wowsims/LICENSE-wowsims-MIT.txt).
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'tests' / 'fixtures' / 'wowsims'
FILES = [
    'era_ele.apl.json', 'era_mage_p1.apl.json', 'era_hunter_p1.apl.json', 'era_warrior_dps_reck.apl.json',
    'sod_elemental_shaman_phase_6.apl.json', 'sod_mage_p5_fire.apl.json', 'sod_hunter_p6_ranged_killshot.apl.json',
    'tbcnew_ele.apl.json', 'tbcnew_druid_balance_default.apl.json', 'tbcnew_shaman_enhancement_default.apl.json',
    'tbcnew_warrior_dps_fury.apl.json',
    'wotlk_ele_default.apl.json', 'wotlk_arms.apl.json', 'cata_shaman_elemental_default.apl.json',
    'cata_warrior_arms_arms.apl.json', 'mop_ele.apl.json', 'mop_feral.apl.json', 'mop_monk_brewmaster_default.apl.json',
    'forever_mage_dps_frost.apl.json', 'forever_shaman_enhancement_default.apl.json', 'forever_warrior_dps_arms.apl.json',
    'forever_rogue_dps_default.apl.json',
]
REAL = ['classic-era-shaman-ele.export.json', 'forever-shaman-ele.export.json']
BUILTINS = ['rm.era.shaman.elemental.wowsims', 'rm.sod.warlock.shadow.wowsims', 'rm.era.priest.dps.wowsims',
            'rm.tbc.shaman.enhancement.wowsims', 'rm.tbc.hunter.ranged.wowsims', 'rm.mop.shaman.enhancement.wowsims',
            'rm.mop.deathknight.blood.wowsims', 'rm.forever.druid.balance', 'rm.forever.druid.feral']
EDITIONS = ['era', 'tbc', 'progression', 'forever']

NODE = r'''
import {createBuiltins} from '%(site)s/server/builtins.mjs';
import {encodeExport} from '%(site)s/codec/export.mjs';
import {decodeImport} from '%(site)s/codec/import.mjs';
import {classifyExport} from '%(site)s/site/kinds.mjs';
const isMap=v=>v instanceof Map;
const isList=v=>isMap(v)&&[...Array(v.size).keys()].every(i=>v.has(i+1));
const plainOf=(v,depth=0)=>{ if(depth>80)return null; if(isMap(v)){ if(isList(v))return [...Array(v.size).keys()].map(i=>plainOf(v.get(i+1),depth+1)); const out={}; for(const [k,x] of v)out[String(k)]=plainOf(x,depth+1); return out;} return v;};
const stepOf=step=>{ if(!isMap(step))return null; const out={}; for(const [k,x] of step){ if(k==='onTrue'||k==='onFalse'||k==='conditions')continue; out[String(k)]=plainOf(x);} const cond=step.get('conditions'); out.conditions=isMap(cond)&&cond.size?plainOf(cond):null; if(step.get('type')==='branch'){ out.onTrue=listItems(step.get('onTrue'));out.onFalse=listItems(step.get('onFalse'));} return out;};
const listItems=list=>isMap(list)?[...Array(list.size).keys()].map(i=>stepOf(list.get(i+1))).filter(Boolean):[];
const b=createBuiltins().load();
const out={};
for(const id of %(ids)s){
  const pack=b.packs.get(id);
  const decoded=decodeImport(encodeExport(pack.envelope,{compress:true}).text);
  const info=classifyExport(decoded.value);
  const envelope=decoded.value.get('format')==='RotationMaster';
  const body=envelope?decoded.value.get('body'):decoded.value;
  out[id]={editions:info.declared?.editions||[],class:info.declared?.class,rotation:listItems(body.get('rotation')),cooldowns:listItems(body.get('cooldowns'))};
}
process.stdout.write(JSON.stringify(out));
'''


def collect(value, spells, items):
    if isinstance(value, dict):
        for key, child in value.items():
            if key in ('spellId', 'auraId', 'talentId', 'runeId') and isinstance(child, int):
                spells.add(child)
            if key == 'spellId' and isinstance(child, dict):
                pass
            if key == 'itemId' and isinstance(child, int):
                items.add(child)
            collect(child, spells, items)
    elif isinstance(value, list):
        for child in value:
            collect(child, spells, items)


def collect_rm(value, spells, items):
    """The ids a Rotation Master rotation body names: step actions and condition fields."""
    if isinstance(value, dict):
        kind = value.get('type')
        action = value.get('action')
        if kind in ('spell', 'any', 'pet') and isinstance(action, int):
            spells.add(action)
        if kind == 'item' and isinstance(action, list):
            items.update(x for x in action if isinstance(x, int))
        if isinstance(value.get('spell'), int):
            spells.add(value['spell'])
        if isinstance(value.get('item'), list):
            items.update(x for x in value['item'] if isinstance(x, int))
        for child in value.values():
            collect_rm(child, spells, items)
    elif isinstance(value, list):
        for child in value:
            collect_rm(child, spells, items)


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    site = Path(sys.argv[1]).resolve()
    src = site / 'tests' / 'fixtures' / 'wowsims'
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'real').mkdir(exist_ok=True)
    sources = json.loads((src / 'SOURCES.json').read_text())
    golden = json.loads((src / 'golden.json').read_text())
    real_sources = json.loads((src / 'real' / 'SOURCES.json').read_text())
    real_golden = json.loads((src / 'real' / 'golden.json').read_text())
    export_golden = json.loads((src / 'export-golden.json').read_text())
    shutil.copy(src / 'LICENSE-wowsims-MIT.txt', OUT / 'LICENSE-wowsims-MIT.txt')
    spells, items = set(), set()
    for name in FILES:
        shutil.copy(src / name, OUT / name)
        collect(json.loads((src / name).read_text()), spells, items)
    for name in REAL:
        shutil.copy(src / 'real' / name, OUT / 'real' / name)
        collect(json.loads((src / 'real' / name).read_text()), spells, items)
    (OUT / 'SOURCES.json').write_text(json.dumps(
        {'note': sources['note'], 'license': sources['license'], 'files': {n: sources['files'][n] for n in FILES}},
        indent=1) + '\n')
    (OUT / 'golden.json').write_text(json.dumps({n: golden[n] for n in FILES}, indent=1) + '\n')
    (OUT / 'real' / 'SOURCES.json').write_text(json.dumps(
        {'note': real_sources['note'], 'files': {n: real_sources['files'][n] for n in REAL}}, indent=1) + '\n')
    (OUT / 'real' / 'golden.json').write_text(json.dumps({n: real_golden[n] for n in REAL}, indent=1) + '\n')
    node = NODE % {'site': str(site), 'ids': json.dumps(BUILTINS)}
    script = OUT / '.export-bodies.mjs'
    script.write_text(node)
    try:
        bodies = json.loads(subprocess.run(['node', str(script)], capture_output=True, text=True, check=True).stdout)
    finally:
        script.unlink()
    (OUT / 'export-bodies.json').write_text(json.dumps(bodies, indent=1) + '\n')
    (OUT / 'export-golden.json').write_text(json.dumps(export_golden, indent=1) + '\n')
    for body in bodies.values():
        collect_rm(body, spells, items)
    # Ids the verifiers answer for: the ones the files mention, the potions and the rank ladders those touch.
    ids = {}
    for edition in EDITIONS:
        data = json.loads((site / 'wowsims' / 'ids' / f'{edition}.json').read_text())
        known = json.loads((site / 'site' / 'reference' / f'known-{edition}.json').read_text())
        keep = set(spells)
        for src_ in data['sources']:
            for ladder in src_.get('ladders', []):
                if any(pair[0] in spells for pair in ladder):
                    keep.update(pair[0] for pair in ladder)
        keep_items = set(items)
        for src_ in data['sources']:
            keep_items.update(src_.get('manaPotions', []))

        def narrow(entry):
            return {'spell': sorted(set(entry.get('spell', [])) & keep), 'pet': sorted(set(entry.get('pet', [])) & keep),
                    'item': sorted(set(entry.get('item', [])) & keep_items)}
        rm = {'edition': edition, 'all': narrow(known['all']),
              'classes': {cls: narrow(entry) for cls, entry in sorted(known['classes'].items())}}
        sims = []
        for src_ in data['sources']:
            sims.append({'repo': src_['repo'], 'ref': src_['ref'], 'url': src_['url'],
                         'spells': {cls: sorted(set(list_) & keep) for cls, list_ in sorted(src_['spells'].items())},
                         'items': sorted(set(src_['items']) & keep_items), 'itemsTotal': len(src_['items'])})
        ladders, seen = [], set()
        for src_ in data['sources']:
            for ladder in src_.get('ladders', []):
                key = tuple(map(tuple, ladder))
                if key not in seen and any(pair[0] in spells for pair in ladder):
                    seen.add(key)
                    ladders.append(ladder)
        potions = sorted({p for src_ in data['sources'] for p in src_.get('manaPotions', [])}, reverse=True)
        ids[edition] = {'rm': rm, 'sims': sims, 'ladders': ladders, 'potions': potions}
    (OUT / 'ids-subset.json').write_text(json.dumps(ids, separators=(',', ':')) + '\n')
    print(f'wrote {len(FILES)} presets, {len(REAL)} real exports, {len(BUILTINS)} Built In bodies, ids for '
          f'{len(spells)} spells and {len(items)} items')


if __name__ == '__main__':
    main()
