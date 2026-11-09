# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""The preview window's border art (Assets/Preview/) is what UI/preview.lua says it is: every theme the code names has an edge
tile and an ornament sheet in the format the game reads, the edge tiles repeat without a seam, and nothing is louder than an icon."""
import re
import struct
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Assets' / 'Preview'
# Brightest a texel may be (red + green + blue). Spell icons are far brighter; the border is chrome.
MAX_BRIGHTNESS = 600


def themes():
    """The (edge, ornament) texture names UI/preview.lua lists, neutral theme first."""
    text = (ROOT / 'UI' / 'preview.lua').read_text(encoding='utf-8')
    pairs = re.findall(r"edge = '([\w-]+)', ornament = '([\w-]+)'", text)
    return pairs


def header(path):
    data = path.read_bytes()[:18]
    return {'type': data[2], 'bpp': data[16], 'size': struct.unpack('<HH', data[12:16])}


class PreviewArtTests(unittest.TestCase):
    def test_the_code_names_the_neutral_theme_and_thirteen_classes(self):
        pairs = themes()
        self.assertEqual(len(pairs), 14)
        self.assertEqual(pairs[0], ('rotation-master-edge', 'rotation-master-ornament'))

    def test_every_theme_has_its_textures_in_the_format_the_game_reads(self):
        for edge, ornament in themes():
            for name, size in ((edge, (32, 32)), (ornament, (64, 32))):
                path = ART / f'{name}.tga'
                self.assertTrue(path.is_file(), f'{name}.tga is missing')
                info = header(path)
                self.assertEqual((info['type'], info['bpp']), (2, 32), f'{name}: an uncompressed 32-bit TGA')
                self.assertEqual(info['size'], size, f'{name}: size')
                self.assertTrue((ART / 'source' / f'{name}.png').is_file(), f'{name}: the PNG source')

    def test_edge_tiles_are_opaque_and_repeat_without_a_seam(self):
        for edge, _ in themes():
            image = Image.open(ART / f'{edge}.tga').convert('RGBA')
            pixels = image.load()
            width, height = image.size
            self.assertTrue(all(pixels[x, y][3] == 255 for x in range(width) for y in range(height)), f'{edge}: opaque')

            def gap(a, b):
                return sum(abs(pixels[a, y][i] - pixels[b, y][i]) for y in range(height) for i in range(3)) / (height * 3)

            seam = gap(width - 1, 0)
            inner = sum(gap(x, x + 1) for x in range(width - 1)) / (width - 1)
            self.assertLessEqual(seam, max(10, inner * 2.5), f'{edge}: the tile shows a seam when it repeats ({seam:.1f} against {inner:.1f})')

    def test_ornaments_have_a_corner_and_a_stud_with_room_around_them(self):
        for _, ornament in themes():
            image = Image.open(ART / f'{ornament}.tga').convert('RGBA')
            corner, stud = image.crop((0, 0, 32, 32)), image.crop((32, 0, 64, 32))
            for label, cell in (('corner', corner), ('stud', stud)):
                alpha = list(cell.getchannel('A').getdata())
                self.assertGreater(sum(1 for a in alpha if a > 0), 40, f'{ornament}: the {label} is empty')
            alpha = list(stud.getchannel('A').getdata())
            self.assertTrue(any(a == 0 for a in alpha), f'{ornament}: the stud has no transparent background')

    def test_nothing_is_louder_than_an_icon(self):
        for edge, ornament in themes():
            for name in (edge, ornament):
                image = Image.open(ART / f'{name}.tga').convert('RGBA')
                brightest = max(sum(p[:3]) for p in image.getdata() if p[3] > 0)
                self.assertLessEqual(brightest, MAX_BRIGHTNESS, f'{name}: too bright ({brightest})')


if __name__ == '__main__':
    unittest.main()
