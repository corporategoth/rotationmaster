# Shaman preview artwork

Run `python Assets/Preview/build.py` with Pillow installed. The build reads the saved generator outputs, crops without stretching, applies a uniform 0.65 exposure multiplier, resamples each complete master with Lanczos, slices it, draws the atlas, and assembles both QA sheets. It does not call the generator.

## Files and geometry

- `shaman-w1.tga` through `shaman-w5.tga`: row cells, left to right.
- `shaman-t1.tga` through `shaman-t5.tga`: column cells, top to bottom.
- Corresponding lossless PNGs are in `source/`. Every cell is 256 × 256, opaque RGBA; TGAs are uncompressed 32-bit.
- `source/generated/shaman-w-master.png` is the 2110 × 422 native-pixel row crop, and `shaman-t-master.png` is the 360 × 1800 native-pixel column crop. Both contain the exposure adjustment. Original generated images and intermediate attempts are retained alongside them. The final row crop is (0, 70, 2110, 492); the column crop is (215, 0, 575, 1800), in Pillow's exclusive-right/bottom coordinates. Both are exact 5:1 or 1:5 without stretching. The whole master is resampled before slicing to preserve continuous joins.
- `shaman-border.tga` and `source/shaman-border.png`: 256 × 64 RGBA atlas, transparent outside artwork. y=0–15 dim rail; y=16–31 lit rail; y=32–47: corner x=0–15, dim stud x=16–31, lit stud x=32–47; y=48–63 transparent. Rail ends match. The border is drawn by the build script as carved wood, dark outline, and turquoise/ember inlay.
- `qa/shaman.png`: 64-pixel cells with 6-pixel border, at 3× nearest-neighbour zoom. It shows all empty row prefixes, two and five active icons, and three- and five-cell columns. The icons are actual PNGs from `Assets/Conditions/source/`. Rails are lit per active slot; joint studs light only when both adjoining slots are active. Corners are mirrored.
- `qa/shaman-full.png`: both masters at native crop resolution and a 2× nearest-neighbour enlargement of the fifth row cell.

| Cell | Chapter |
| --- | --- |
| 1 | Dusk totem circle and first fire |
| 2 | Wind and feathers over the red mesa |
| 3 | Lightning storm over the mesa |
| 4 | Teal river canyon and water spirits |
| 5 | Four lit earth, fire, water and wind totems beneath stars |

Each orientation is one generated image, cropped as a whole and sliced. Cell boundaries retain the original continuous scene. Some prefix endings cut through landscape rather than resolving into a discrete foreground object; the column's transitions are more like stacked vistas than a single uninterrupted terrain. The count motifs are not consistently legible, and the outer wind figure in the row is close to the edge.

## Provenance

Built-in imagegen was used with the earlier `qa/shaman-full.png` as a mood reference. Initial row prompt:

> Use case: illustration-story. Create a richly detailed, dark muted fantasy game background painting as one continuous panoramic landscape, composed for cropping the central horizontal 5:1 strip. Across that strip, left to right in five equal chapters: dusk carved wood and feather totem circle with first fire; wind and feathers over red mesa; lightning storm over mesa; teal river canyon with water spirits; finally FOUR clearly separated large lit totems representing earth, fire, water and wind together under stars. Keep the four totems entirely within the rightmost fifth of the strip. Natural rock, tree or cliff transitions at each fifth, continuous across boundaries. Full sharp painted detail throughout, no fog boxes, blur, blank centers, frames, lettering or UI. Shaman spirit walk, carved wood and stone, turquoise inlay, muted ember, storm grey, dusk to night. Dark subdued lighting. High detail. Reference the supplied shaman painting for mood, not its blurry centers.

Initial column prompt:

> Use case: illustration-story. Create a richly detailed dark muted fantasy game background painting, a single continuous vertical landscape composed for cropping the central vertical 1:5 strip. Across that strip, top to bottom in five equal chapters: dusk carved wood and feather totem circle with first fire; wind and feathers over red mesa; lightning storm over mesa; teal river canyon with water spirits; finally FOUR clearly separated large lit totems representing earth, fire, water and wind together under stars. Keep all four totems entirely within the bottom fifth of the strip. Natural rock, tree or cliff transitions at each fifth, continuous across boundaries. Full sharp painted detail throughout, no fog boxes, blur, blank centers, frames, lettering or UI. Shaman spirit walk, carved wood and stone, turquoise inlay, muted ember, storm grey, dusk to night. Dark subdued lighting. High detail. Reference the supplied shaman painting for mood, not its blurry centers.

Column retry prompt:

> Create a single continuous vertical fantasy game painting. CRITICAL COMPOSITION: the finished image will be cropped to only the CENTRAL 40% OF THE IMAGE WIDTH, full height. Put ALL important subjects in that central narrow strip and use the sides only as expendable landscape. Within the central strip arrange five equal stacked chapters, top to bottom: carved wood and feather totem circle at dusk with fire; wind and feathers over red mesa; mesa lightning storm; turquoise water spirits in a canyon; then FOUR distinct large, clearly separated slender elemental totems standing SIDE BY SIDE together in the narrow central strip, earth, fire, water and wind, under starry sky. All four totems must be fully visible inside the central 40% width. Continuous scenery flowing across chapter boundaries. No panel dividers, no fog boxes, no blurred centers, no text. Rich, sharp detailed painted wood and stone, teal, muted orange, storm grey. Dark, subdued, shaman spirit walk.

Column final edit, using the retry as input:

> Edit this vertical painting. Preserve the continuous landscape and mood. At the bottom, arrange FOUR distinct slender elemental totems (earth fire water wind) in a very tight group, all four complete totems, heads and bases, fitting inside the CENTER 35% of the image width and BOTTOM 20% of image height, with visible margin on both sides. All four in one row and clearly separated. Maintain stars behind them. Other chapters remain continuous and full detail. No text or panel lines.

Row edits, each using the previous result as input:

> Edit this panorama. Preserve the existing landscape and mood. Place the entire group of FOUR elemental totems closer together and shift it right, so all four complete totems fit inside the RIGHTMOST 18% of the image, with visible space at both sides of the group. Four clear separate figures, earth fire water wind, under stars, their heads and bases inside the central horizontal 60% of image height. Keep the rest of the landscape continuous and detailed. No text, no panel lines.

> Edit this wide panorama. On its far right, make the group of four elemental totems significantly smaller and much more tightly clustered; shift the entire group to the RIGHT. The complete group including the earth figure must fit within the rightmost 15 percent of the whole image, with room at the right edge. Four separate totems earth fire water wind. Preserve the rest of the image and its landscape. No text.

> Edit only the four tiny totems at the far right: make each of the four elemental totems twice as tall and the group twice as wide, while keeping all four complete figures entirely inside the rightmost fifth of the image, with margins. They are the focal point of that fifth. Earth fire water wind, clearly separated. Preserve rest of continuous landscape and stars.
