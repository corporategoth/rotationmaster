# Effects

**Effects** are highlight styles. The [General](/help/general#highlight-style) tab picks the effect for the main recommendation and the default for cooldowns; each [cooldown](/help/cooldowns) can pick its own. Effects are shared by all your characters.

Select an effect in the list to edit it, or choose **New**. The image beside **Name** and **Type** previews the draft (in white, at normal size; real highlights use the profile or cooldown colour, size and position).

## Effect types

| Type | What it looks like | Its settings |
|---|---|---|
| **Texture** | A single image over the button. | The image. Colour, size and position come from the profile or cooldown. |
| **Pixel** | Short lines running around the button's border. | Lines (1–20), Frequency, Length, Thickness (1–5). |
| **Auto Cast** | Groups of sparkling particles circling the button. | Particles (1–4 per group), Frequency, Scale. |
| **Glow** | The familiar Blizzard button glow. | Frequency. |
| **Proc Glow** | The animated proc border from action bars. Falls back to Pixel on clients that cannot show it. | Duration (0.1–5 s), and whether to play the opening burst. |
| **Dazzle** | One image cycling through a sequence of colours. | The image, seconds between colours, the colour sequence. |
| **Animate** | A sequence of images, like a flip book. | Seconds between images, the image sequence. |
| **Pulse** | One image cycling through sizes. | The image, seconds between sizes, the size sequence. |
| **Rotate** | One image turning through evenly spaced angles. | The image, seconds per step, Steps (2–36), Reverse. |
| **Custom** | A sequence where every step has its own image, angle, size and colour. | Seconds between steps, the step sequence. |

**Frequency** for Pixel and Auto Cast is in cycles per second: larger is faster and a negative value reverses direction; 0 uses the library default. For the sequence types it is the number of seconds between steps, and the sequence repeats after the last step.

## Images

Texture, Dazzle, Pulse and Rotate use one image for the whole effect; Animate and Custom choose an image on each sequence step. The arrow beside an image field opens a catalog of bundled overlays with previews. You can also type a texture path or a numeric file ID from the game or another addon.

## Sequences

Sequence steps play in order and repeat. **Add step** (on the Sequence heading) appends a step; drag it into a gap to insert. Drag a step to reorder it, hold **Ctrl** to carry the following steps too, and use the red trash to remove one. Changing an effect's type resets its sequence, because each type stores different values.

## Saving, sharing and deleting

Edits stay in a draft until **Apply**. A new effect needs a unique name before it can be applied.

Below the list are **New**, **Duplicate**, **Import/Export** and **Compare**. Importing shows the original name and lets you create a renamed copy or replace the selected effect.

The red trash at the top right deletes an effect after a warning. Any profile or cooldown that used it then needs another effect; RM does not silently change them for you.
