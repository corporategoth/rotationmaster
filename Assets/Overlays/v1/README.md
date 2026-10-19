# Original transparent highlight overlays

`provenance.json` selects nine independently generated painted fantasy motifs:
arcane ring, ember corners, frost shards, nature vines, lightning sweep, holy
rays, shadow claws, rune diamond, and a neutral arcane ring. Each has its own
built-in image generation call and exact recorded prompt. No external asset or
third-party image reference was used. These textures were generated for
distribution with Rotation Master.

Original generated RGBA PNGs are retained in `source/`. Selected runtime images
are uncompressed 32-bit RGBA TGA at 128 and 256 pixels, with transparent corners
and open centers. The unsuffixed selected name is 256 pixels, and `-128` is its
smaller export. Generated alpha is preserved; a fully translucent highlight
need not contain a pixel with alpha 255. `qa/alpha-report.json` records exact
source/export hashes and alpha statistics. Earlier colored ring revisions are
retained as provenance, and only manifest-selected paths should be integrated.

Most motifs use white/silver emissive cores so the addon's ADD blend and RGBA
tint controls remain useful. The colored arcane ring is intentionally separate;
its purple color limits some tint combinations. Offline previews cover dark and
light backgrounds and approximate SRC_ALPHA/ONE blending over original spell
and quiet weapon art plus a flat midtone, including white/red/green/blue tints.
They do not certify native rendering or editor integration.

From the repository root:

```sh
python3 Assets/Conditions/v2/export_icons.py --root Assets/Overlays/v1 --qa-pages /absolute/qa-directory
python3 Assets/Conditions/v2/verify_assets.py
```

The same exporter copies original PNG bytes and only resamples/exports formats
and QA sheets. It never paints or removes generated alpha. These are optional
texture overlays; procedural Glow, Pixel, and Auto Cast behavior is a separate
runtime/library concern.
