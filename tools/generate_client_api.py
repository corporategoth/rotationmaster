#!/usr/bin/env python3
"""Generate tests/fixtures/client_api_<client>.lua: what each real client provides.

For every client global or C_* function the addon references (and every name a
Blizzard_Deprecated* fallback defines), record whether the client provides it
natively, only while the loadDeprecationFallbacks CVar is on, or not at all.
Test fixtures build their WoW environment from these manifests, so a removed
global is nil there exactly as it is in the game.

Inputs are read as data, never executed:
  --ui DIR         one directory per branch (live, forever, classic,
                   classic_anniversary, classic_era), each a checkout of
                   Gethe/wow-ui-source at that branch (Blizzard's own UI code
                   and generated API documentation).
  --resources DIR  the same branch directories from Ketho/BlizzardInterfaceResources
                   (Resources/GlobalAPI.lua and FrameXML.lua are in-game dumps of
                   every global function, taken with the CVar off; LuaEnum,
                   GlobalStrings/enUS, Frames and CVars are dumps of the rest).
Without --write it only reports whether the committed manifests are current.
"""
import argparse, json, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# client key -> (branch, WOW_PROJECT_ID, TOC family, TOC game) for TOC load conditions
CLIENTS = {
    'retail': ('live', 1, 'mainline', 'standard', 'Mainline', 'Standard'),
    'forever': ('forever', 18, 'mainline', 'camelot', 'Mainline', 'Camelot'),
    'mists': ('classic', 19, 'classic', 'mists', 'Classic', 'Mists'),
    'tbc': ('classic_anniversary', 5, 'classic', 'tbc', 'Classic', 'TBC'),
    'era': ('classic_era', 2, 'classic', 'vanilla', 'Classic', 'Vanilla'),
}
LUA_STD = set('''assert collectgarbage dofile error getfenv getmetatable ipairs load loadfile loadstring next pairs
 pcall print rawequal rawget rawset select setfenv setmetatable tonumber tostring type unpack xpcall string table
 math coroutine os io debug bit _G _VERSION gcinfo module require newproxy'''.split())
# Optional third-party addons the addon integrates with when present, and
# globals the addon defines itself (frames, slash handlers, saved variables).
FOREIGN = set('''LibStub addonName LuaWorkbench MI2_GetMobData RealMobHealth ECSLoader ExtendedCharacterStats WeakAuras
 SyncUI_ActionBar SyncUI_MultiBar SyncUI_PetBar SyncUI_SideBar RotationMasterFrontmostDialog RotationMasterDB'''.split())


def addon_files():
    files = [l.strip().replace('\\', '/') for l in (ROOT / 'RotationMaster.toc').read_text().splitlines()
             if l.strip().endswith('.lua') and not l.startswith('#')]
    files.append('LibsAugment/FAIAP.lua')
    for m in re.finditer(r'file="([^"]+\.lua)"', (ROOT / 'locales.xml').read_text()):
        files.append(m.group(1).replace('\\', '/'))
    return [f for f in files if not f.startswith('Libs/')]


INS = re.compile(r'^\s*\d+\s+\[(\d+)\]\s+(\w+)\s+(-?\d+)(?:\s+(-?\d+))?(?:\s+(-?\d+))?(?:\s*;\s*(.*))?$')


def addon_references():
    """Global names and NS.Field paths read by addon (non-test, non-vendor) code, via luac -l."""
    used, assigned, strings = set(), set(), set()
    for f in addon_files():
        out = subprocess.run(['luac5.1', '-l', '-p', str(ROOT / f)], capture_output=True, text=True, check=True).stdout
        reg = {}
        for line in out.splitlines():
            if line.startswith(('main <', 'function <')):
                reg = {}
                continue
            m = INS.match(line)
            if not m:
                continue
            _, op, a, b, c, comment = m.groups()
            a = int(a)
            if op == 'GETGLOBAL':
                reg[a] = comment.strip()
                used.add(reg[a])
                continue
            if op == 'SETGLOBAL':
                assigned.add(comment.strip())
            elif op == 'GETTABLE' and int(b) in reg and comment and c is not None and int(c) < 0:
                km = re.search(r'"([^"]*)"\s*$', comment)
                if km:
                    base = reg[int(b)]
                    path = km.group(1) if base == '_G' else base + '.' + km.group(1)
                    used.add(path)
                    reg[a] = path
                    continue
            reg.pop(a, None)
        for m in re.finditer(r'''(["'])([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\1''', (ROOT / f).read_text()):
            strings.add(m.group(2))
    names = set()
    for n in used:
        top = n.split('.')[0]
        if top in LUA_STD or top in FOREIGN or top in assigned:
            continue
        if n.count('.') > 1 and top != 'Enum':
            continue
        if '.' in n and not (top.startswith('C_') or top == 'Enum'):
            continue
        names.add(n)
    return names, strings


def dump_names(path):
    return set(re.findall(r'^\t"([^"]+)",', path.read_text(errors='replace'), re.M))


def enum_paths(path):
    paths, stack = set(), []
    for line in path.read_text(errors='replace').splitlines():
        m = re.match(r'^(\t*)(\w+) = (\{)?', line)
        if not m:
            continue
        depth = len(m.group(1))
        stack = stack[:depth] + [m.group(2)]
        paths.add('.'.join(stack))
    return paths


def deprecated_definitions(ui, fam, game, Fam, Game):
    """name -> {'forwards': C_NS.Fn or None} for every fallback that loads on this client."""
    base = ui / 'Interface/AddOns'
    defs = {}
    for toc in sorted(base.glob('*/*.toc')):
        if 'Deprecat' not in toc.parent.name:
            continue
        txt = toc.read_text(errors='replace')
        allowed = None
        for line in txt.splitlines():
            m = re.match(r'##\s*AllowLoadGameType:\s*(.*)', line)
            if m:
                allowed = {t.strip().lower() for t in m.group(1).split(',')}
        if allowed is not None and not ({fam, game} & allowed):
            continue
        for line in txt.splitlines():
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            m = re.match(r'^(\S+)(?:\s+\[AllowLoadGameType\s+([^\]]+)\])?', line)
            cond = m.group(2)
            if cond and not ({fam, game} & {t.strip().lower() for t in cond.split(',')}):
                continue
            f = toc.parent / m.group(1).replace('[Game]', Game).replace('[Family]', Fam).replace('\\', '/')
            if f.suffix != '.lua' or not f.exists():
                continue
            src = f.read_text(errors='replace')
            if 'loadDeprecationFallbacks' not in src:
                continue
            for m2 in re.finditer(r'^(\t?)function\s+([A-Za-z_][\w.]*)\s*\((.*?)^\1end', src, re.M | re.S):
                fw = re.search(r'\b(C_\w+\.\w+)\s*\(', m2.group(3))
                defs.setdefault(m2.group(2), fw.group(1) if fw else None)
            for m2 in re.finditer(r'^(\t?)([A-Za-z_][\w.]*)\s*=\s*(function\b.*?^\1end|[^\n]+)', src, re.M | re.S):
                n, v = m2.group(2), m2.group(3).strip()
                if n == 'local' or n in defs:
                    continue
                fw = re.search(r'\b(C_\w+\.\w+)\s*\(', v) if v.startswith('function') else re.match(r'(C_\w+\.\w+)\s*;?$', v)
                defs[n] = fw.group(1) if fw else None
    return defs


# The source tree of every branch carries other flavours' files (Classic/, Mists/,
# Bindings_Mists.xml ...); only this client's flavour folders and shared ones load.
FLAVOURS = {'Mainline', 'Camelot', 'Standard', 'Classic', 'Vanilla', 'TBC', 'Wrath', 'Cata', 'Mists'}
LOADED = {'retail': {'Mainline', 'Standard'}, 'forever': {'Mainline', 'Camelot'},
          'mists': {'Classic', 'Mists'}, 'tbc': {'Classic', 'TBC'}, 'era': {'Classic', 'Vanilla'}}


def other_flavour(path, client):
    parts = set(path.parts[:-1]) | set(re.findall(r'_([A-Za-z]+)$', path.stem))
    return bool((parts & FLAVOURS) - LOADED[client])


def provided_values(ui, res, client):
    """Non-function globals the client defines: strings, enums, frames, fonts, FrameXML variables."""
    R = res / 'Resources'
    values = set(re.findall(r'^([A-Za-z_]\w*) = ', (R / 'GlobalStrings/enUS.lua').read_text(errors='replace'), re.M))
    values |= enum_paths(R / 'LuaEnum.lua')
    values |= dump_names(R / 'Frames.lua')
    used_caps = set()
    base = ui / 'Interface'
    for f in base.rglob('*'):
        rel = f.relative_to(base)
        if f.suffix not in ('.lua', '.xml') or 'Deprecat' in str(rel) or other_flavour(rel, client):
            continue
        src = f.read_text(errors='replace')
        if f.suffix == '.lua':
            src = re.sub(r'--\[(=*)\[.*?\]\1\]', '', src, flags=re.S)
            src = re.sub(r'--[^\n]*', '', src)
            values |= set(re.findall(r'^\t?(?:_G\.)?([A-Za-z_]\w*)\s*=(?!=)', src, re.M))
            values |= set(re.findall(r'^function\s+([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)\s*\(', src, re.M))
            # Constants generated at load (e.g. NORMAL_FONT_COLOR_CODE from the
            # color database) are visible only as free references in Blizzard code.
            used_caps |= set(re.findall(r'(?<![\w.:])([A-Z][A-Z0-9_]{2,})(?![\w])', src))
        else:
            for m in re.finditer(r'<(\w+)\s[^>]*?\bname="([A-Za-z_]\w*)"[^>]*>', src):
                if m.group(1) in ('Font', 'FontFamily') or 'virtual="true"' not in m.group(0):
                    values.add(m.group(2))
    return values, used_caps


def classify(names, strings):
    surfaces = {}
    for client, (branch, project, fam, game, Fam, Game) in CLIENTS.items():
        ui, res = Path(args.ui) / branch, Path(args.resources) / branch
        functions = dump_names(res / 'Resources/GlobalAPI.lua') | dump_names(res / 'Resources/FrameXML.lua')
        values, caps = provided_values(ui, res, client)
        spaces = {n.split('.')[0] for n in functions if '.' in n}
        cvar = re.search(r'\["loadDeprecationFallbacks"\] = \{"(\w*)"', (res / 'Resources/CVars.lua').read_text(errors='replace'))
        surfaces[client] = dict(functions=functions, values=values, caps=caps, spaces=spaces,
                                deprecated=deprecated_definitions(ui, fam, game, Fam, Game), project=project,
                                version=(ui / 'version.txt').read_text().strip(), cvar=cvar and cvar.group(1),
                                build=re.search(r'GetBuildInfo\(\) => "([^"]+)", "(\d+)"', (res / 'README.md').read_text()).groups())
    every_function = set().union(*[s['functions'] for s in surfaces.values()])
    every_deprecated = set().union(*[set(s['deprecated']) for s in surfaces.values()])
    # String literals the addon uses as API names (condition requirements,
    # namespace lookups by name) need the same classification.
    successors = set(re.findall(r"=\s*'([\w.]+)'", (ROOT / 'tests/fixtures/client_api_successors.lua').read_text()))
    forwards = {fw for s in surfaces.values() for fw in s['deprecated'].values() if fw}
    names = set(names) | successors | forwards | {s for s in strings if (s in every_function or s in every_deprecated)
                         and re.fullmatch(r'C_\w+\.\w+|[A-Z][a-z0-9]+[A-Z]\w*', s)}

    def provided(s, n):
        if n in s['functions'] or n in s['values'] or (n in s['spaces'] and '.' not in n):
            return True
        return re.fullmatch(r'[A-Z][A-Z0-9_]{2,}', n) is not None and n in s['caps']

    out = {}
    for client, s in surfaces.items():
        status = {}
        for n in sorted(names | set(s['deprecated'])):
            if provided(s, n):
                status[n] = 'native'
            elif n in s['deprecated']:
                status[n] = 'deprecated'
            else:
                status[n] = None
        out[client] = status
    # Absent: 'removed' when an older client line still has it natively (or it
    # is a plain global the addon was written against), 'never' for a C_* or
    # Enum path no client ever gave this one.
    older = {'retail': ('mists', 'tbc', 'era'), 'forever': ('mists', 'tbc', 'era')}
    for client, status in out.items():
        for n, v in status.items():
            if v is not None:
                continue
            natives = [c for c in CLIENTS if out[c].get(n) == 'native']
            if n.startswith(('C_', 'Enum', 'WOW_PROJECT_')):
                status[n] = 'never'
            elif client in older and any(c in older[client] for c in natives):
                status[n] = 'removed'
            elif client not in older and natives and all(c in older for c in natives):
                status[n] = 'never'
            else:
                status[n] = 'removed'
    return surfaces, out


def lua_string(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def render(client, surface, status):
    branch = CLIENTS[client][0]
    lines = ['-- GENERATED by tools/generate_client_api.py from Blizzard\'s own client data; do not edit.',
             '-- What the real %s client provides, for every client global and C_* function Rotation' % client,
             '-- Master references (and every name a Blizzard_Deprecated* fallback defines there):',
             '--   native      provided with loadDeprecationFallbacks off',
             '--   deprecated  provided only while loadDeprecationFallbacks is on (value: the C_* API it wraps)',
             '--   removed     not provided at all (an older client line, or an older build, had it)',
             '--   never       a C_*/Enum path this client never had',
             'return {',
             '    client=%s, project=%d, branch=%s,' % (lua_string(client), surface['project'], lua_string(branch)),
             '    sourceVersion=%s, dumpBuild=%s, fallbackCVarDefault=%s,' % (
                 lua_string(surface['version']), lua_string('.'.join(surface['build'])), lua_string(surface['cvar'] or '')),
             '    sources={ui=%s, resources=%s},' % (lua_string(args.ui_rev.get(branch, '')), lua_string(args.res_rev.get(branch, ''))),
             '    native={']
    for n in sorted(k for k, v in status.items() if v == 'native'):
        lines.append('        %s,' % lua_string(n))
    lines.append('    },')
    lines.append('    deprecated={')
    for n in sorted(k for k, v in status.items() if v == 'deprecated'):
        fw = surface['deprecated'].get(n)
        lines.append('        [%s]=%s,' % (lua_string(n), lua_string(fw) if fw else 'true'))
    lines.append('    },')
    lines.append('    -- Globals outside the client: Lua\'s own, and optional addons/the addon\'s own frames.')
    lines.append('    excluded={%s},' % ','.join(lua_string(n) for n in sorted(LUA_STD | FOREIGN)))
    for kind in ('removed', 'never'):
        lines.append('    %s={' % kind)
        for n in sorted(k for k, v in status.items() if v == kind):
            lines.append('        %s,' % lua_string(n))
        lines.append('    },')
    lines.append('}')
    return '\n'.join(lines) + '\n'


parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
parser.add_argument('--ui', required=True)
parser.add_argument('--resources', required=True)
parser.add_argument('--ui-rev', default='{}', help='JSON branch->commit of the --ui checkouts')
parser.add_argument('--res-rev', default='{}', help='JSON branch->commit of the --resources checkouts')
parser.add_argument('--write', action='store_true')
args = parser.parse_args()
args.ui_rev, args.res_rev = json.loads(args.ui_rev), json.loads(args.res_rev)
names, strings = addon_references()
surfaces, statuses = classify(names, strings)
stale = []
for client in CLIENTS:
    path = ROOT / 'tests/fixtures' / ('client_api_%s.lua' % client)
    text = render(client, surfaces[client], statuses[client])
    if args.write:
        path.write_text(text)
    elif not path.exists() or path.read_text() != text:
        stale.append(path.name)
if stale:
    print('Client API manifests are stale: ' + ', '.join(stale) + '. Run with --write.')
    sys.exit(1)
print('Client API manifests ' + ('written.' if args.write else 'are current.'))
