# Original condition artwork, version 2

`provenance.json` selects 153 independent original bitmap designs: every one of
the 141 Built In condition tags, nine condition category selectors, and AND,
OR, and NOT. The six packaged category UUIDs and All/Switch/Other selector
identities are recorded in the manifest. The original sixteen family icons in
the parent directory remain available for existing saved selections.

Every selected design came from a separate built-in image generation call with
its own concept prompt. The prompts use painted high-fantasy materials, magical
energy, and large subject/qualifier silhouettes. They are not recolored copies
or crops from an atlas. No third-party artwork was downloaded or used as a
reference. The exact prompts, original output paths, source SHA256 values,
semantic source evidence, selected runtime paths, and earlier revisions are in
the manifest. These assets were generated for distribution with Rotation Master.

`source/*.png` retains original generated RGBA bytes. Selected runtime textures
are uncompressed 32-bit RGBA TGA, at 64 and 128 pixels. The unsuffixed selected
name is the 128-pixel texture; `-64` is its smaller export. The exporter contains
the complete generated canvas with a narrow transparent margin and resamples
in premultiplied alpha. It does not paint, reconstruct, recolor, or erase art.

`earlier_versions` are provenance, not active selections. In particular,
`zonepvp.png` and its old unsuffixed TGA exports were rejected because generation
introduced recognizable game faction emblems. Use the selected original blank
flags in `zonepvp-r2` instead. Release packaging should include selected runtime
paths, not indiscriminately include superseded textures. Source originals and
audit reports can be retained separately from the runtime package.

From the repository root:

```sh
python3 Assets/Conditions/v2/export_icons.py --qa-pages /absolute/qa-directory
python3 Assets/Conditions/v2/verify_assets.py
lua5.1 tools/collect_builtin_sources.lua > /absolute/current-inventory.json
python3 Assets/Conditions/v2/verify_assets.py --inventory /absolute/current-inventory.json
```

The tools require Pillow; contact sheets additionally use DejaVu Sans. Import a
new original with `--record KEY /absolute/generated.png`, using a new versioned
manifest name before replacement. The exporter refuses to overwrite differing
original PNG bytes. `qa/alpha-report.json` records selected image hashes, alpha
statistics, dimensions, and reopened export checks. The verifier checks exact
current tag coverage when supplied an inventory, distinct source and decoded
runtime hashes, RGBA TGA headers, power-of-two dimensions, and transparent corners.

All selected designs were inspected on dark/light backgrounds at actual 20,
24, and 32 pixels and at 64/128 pixels. Refined durations retain large subject
and timer halves; logic uses merging, alternative, and blocked paths. These are
offline visual and format checks. In-game rendering, color settings, filtering,
and placement still require native acceptance; file existence alone does not
prove that a consuming UI uses the selected mapping.

## World-state and edition conditions

The twenty conditions of `docs/world-and-edition-conditions.md` and the eight
Assisted Combat, rune, specialization, weapon type and progress conditions that
reused another condition's icon until now each have a design of their own. They
came from one built-in image generation call per design (run through
`codex exec`, prompts recorded in `provenance.json` unchanged except for the
subject), recorded with `export_icons.py --record KEY <generated.png>`. The
Mythic+ keystone design was generated twice: the first result read as a
recognizable game icon (a spiral rune), so the shipped design replaces it with
an engraved chevron on a plain obelisk. Offline checks only, as above.
