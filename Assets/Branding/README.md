# Rotation Master logo

The selected first design (tri-school rotation) is the source artwork in `rotation-master.png`. It retains transparency. The detailed game artwork uses the 256×256 RGBA TGA export in `rotation-master.tga`. The constants in `constants.lua` select the detailed or small-size variant for each surface.

Resize the PNG with alpha preserved to regenerate the TGA. No runtime image-generation or third-party addon is needed.

The small-size companion in `rotation-master-small.png` removes interior filigree and the central crystal, retaining three clean school-colored arrows and a transparent center. `rotation-master-small.tga` is its 128×128 uncompressed RGBA runtime export. `addon.logoTexture` uses this version for compact headers and broker/minimap icons. The Settings launcher uses the detailed `addon.logoArtworkTexture` at 96×96.

The companion was edited with the built-in image generator using the selected detailed artwork as reference. Prompt: simplify the same blue/purple/orange three-arrow rotation for 16–40 px use; remove symbols, stars, flame/frost filigree, tiny rim decorations and central crystal; retain clear arrowheads, restrained gold/dark bevels and transparent exterior/center. ImageMagick only resizes/converts runtime exports. Both source artworks remain available.
