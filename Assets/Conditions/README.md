# Original condition icon family

These sixteen semantic icons are original raster artwork generated separately
with the built-in `image_gen.imagegen` tool, with `transparent_background: true`.
They are bundled artwork; the addon does not generate or download images at run
time. No existing game icon or third-party reference image was used as input.

## Files and use

- `source/<name>.png`: original 1254 × 1254 RGBA generator output, copied byte
  for byte and retained with its generated transparency.
- `<name>.tga`: 128 × 128 uncompressed 32-bit RGBA runtime texture.
- `<name>-64.tga`: 64 × 64 uncompressed 32-bit RGBA companion texture.
- `provenance.json`: exact per-asset prompts, tool, transparency setting, and
  generation source paths. This is the complete prompt set used for the family.
- `qa/alpha-report.json`: source SHA-256 hashes, pixel dimensions, alpha coverage,
  corner alpha, content bounds, and verified TGA format information.
- `qa/contact-small.png`: actual-size 20/24/32 px previews on dark and light.
- `qa/contact-large.png`: actual-size 64/128 px previews on dark and light.

Use the dynamic addon folder name followed by `Assets\\Conditions\\<name>`;
WoW resolves the TGA without a filename extension. Use the `-64` variant when a
smaller source texture is appropriate. Both runtime sizes are powers of two.

| Name | Semantic motif | Suggested family |
| --- | --- | --- |
| combat | Crossed silver/iron axes with red wrap | Combat state |
| character | Steel-and-gold helm with blue crest | Character identity/class/group |
| spell | Violet/cyan arcane flame and rune shard | Spell availability/knowledge |
| buff | Golden sun shield with green aura | Beneficial auras |
| debuff | Violet skull and green curse | Harmful auras |
| item | Red potion in bronze holder | Inventory/consumables |
| weapon | Silver sword with gold guard | Weapons/equipment |
| spatial | Bronze compass and luminous arrows | Range/location/distance |
| resources | Ruby heart with blue mana crescent | Health/power/statistics |
| pet | Indigo wolf head | Pet/pet spells |
| talent | Open book with cyan branching rune | Talents/trees |
| casting | Gloved hand holding orange fireball | Casting/channeling |
| logic | Three linked gold rings and violet crystal | Logical/unit relationships |
| totem | Wooden ritual face with turquoise and feathers | Totems |
| environment | Green hill, gold sun, blue sky crescent | Instance/outdoors/zone |
| time | Bronze hourglass with blue bulbs and gold sand | Cooldown/duration/history |

## Rebuild and checks

Run `python3 Assets/Conditions/export_icons.py` with Pillow available. It copies
originals only when missing, resizes in premultiplied alpha to avoid dark edge
fringes, contains the full source within a square with a small transparent
margin, and exports TGA plus QA sheets. It never paints replacement artwork or
removes generated content. An existing original PNG is not overwritten.

The exporter reopens every TGA and verifies decoded RGBA bytes match the resize,
dimensions match 64 or 128, image type is 2 (uncompressed true-color), depth is
32 bits, and the descriptor declares 8 alpha bits. All sixteen originals and
all thirty-two runtime exports have alpha extrema 0–255. Original transparent
coverage is 39.91–76.45%; 128 px export coverage is 45.90–77.45%. Every export
corner is transparent. The precise per-file results are in the alpha report.

Visual inspection of both contact sheets found distinct major silhouettes and
color cues at 20–32 px, with interior detail becoming clearer at 64–128 px.
There are no opaque square backgrounds or visible white matte rectangles on
either contrasting background. At 20 px, fine faces, runes, and engraving are
not individually legible; the larger emblem supplies recognition. These are
asset-format and visual-preview checks, not an in-game acceptance test.
