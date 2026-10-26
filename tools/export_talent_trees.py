#!/usr/bin/env python3
"""Export the talent tree names (Data/talent_trees.lua) as plain JSON.

  python3 tools/export_talent_trees.py           write Data/talent_trees.json
  python3 tools/export_talent_trees.py --check   fail when the JSON is not what the Lua table says

The tree conditions save a tree as its position in the talent window (1, 2 or
3). This file says which tree that is for each client family and class, so the
website can show names too. Shape:

  {"version": 1, "order": "...", "familyOrder": ["era", ...],
   "families": {"era": {"label": "...", "basis": "...",
                        "classes": {"SHAMAN": ["Elemental", "Enhancement", "Restoration"], ...}}}}

Each class list is the tree names in talent-window order, so the saved number n
is the nth name (1-based). The names are English; the addon translates them
through its locale files and prefers the game's own names for the player's
class.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Data/talent_trees.lua'
TARGET = ROOT / 'Data/talent_trees.json'

# Loads the real source with the two globals it needs and serializes the plain
# data table it publishes. Keys are sorted so the output is stable.
READER = r'''
LibStub=function()return{GetLocale=function()return setmetatable({},{__index=function(_,k)return k end})end}end
local addon={Platform={}}
assert(loadfile('Data/talent_trees.lua'))('RotationMaster',addon)
local function q(s)return '"'..s:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"'end
local function dump(v)
  if type(v)=='string' then return q(v) end
  if type(v)=='number' then return tostring(v) end
  if #v>0 then local out={};for i,x in ipairs(v)do out[i]=dump(x)end;return '['..table.concat(out,',')..']' end
  local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
  local out={};for _,k in ipairs(keys)do out[#out+1]=q(k)..':'..dump(v[k])end
  return '{'..table.concat(out,',')..'}'
end
io.write(dump(addon.TalentTrees.data))
'''


def build():
    result = subprocess.run(['luajit', '-'], input=READER.encode(), capture_output=True, cwd=ROOT)
    if result.returncode:
        raise SystemExit(f'{SOURCE}: {result.stderr.decode().strip()}')
    data = json.loads(result.stdout.decode('utf-8'))
    return json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + '\n'


def main(argv):
    text = build()
    if argv[:1] == ['--check']:
        if not TARGET.exists() or TARGET.read_text(encoding='utf-8') != text:
            raise SystemExit(f'{TARGET.relative_to(ROOT)} is out of date: run python3 tools/export_talent_trees.py')
        return 0
    if argv:
        raise SystemExit(__doc__)
    TARGET.write_text(text, encoding='utf-8')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
