# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""The preview window's background art (Assets/Preview/) is what UI/preview.lua says it is: every theme the code names has its ten
cell paintings and its border sheet in the format the game reads, nothing is louder than the chrome should be, the cells of a story
join without a seam, and no cell has a blurred patch where the painting should be."""
import re
import struct
import unittest
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageStat

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Assets' / 'Preview'
CELL = 256
# The painting sits under spell icons in a fight: dark and quiet. Mean luminance (0 to 255) and brightest texel (red + green + blue).
MAX_MEAN_LUMINANCE, MAX_BRIGHTNESS = 80, 640


def themes():
    """{prefix: names} for the textures UI/preview.lua lists: five row cells, five column cells, the border sheet."""
    text = (ROOT / 'UI' / 'preview.lua').read_text(encoding='utf-8')
    block = text[text.index('local ART_THEMES'):text.index('local BORDER_PIECES')]
    found = {}
    for name in re.findall(r"'([a-z]+-(?:[wt][1-5]|border))'", block):
        found.setdefault(name.split('-')[0], []).append(name)
    return found


def header(path):
    data = path.read_bytes()[:18]
    return {'type': data[2], 'bpp': data[16], 'size': struct.unpack('<HH', data[12:16])}


def load(name, mode='RGB'):
    return Image.open(ART / f'{name}.tga').convert(mode)


class PreviewArtTests(unittest.TestCase):
    def test_the_code_names_each_texture_and_only_the_ones_that_exist(self):
        listed = themes()
        self.assertTrue(listed)
        for prefix, names in listed.items():
            self.assertEqual(len(names), 11, f'{prefix}: five row cells, five column cells, a border')
        on_disk = {path.stem for path in ART.glob('*.tga')}
        self.assertEqual(on_disk, {name for names in listed.values() for name in names}, 'every file is named and every name has its file')

    def test_every_texture_is_in_the_format_the_game_reads(self):
        for prefix, names in themes().items():
            for name in names:
                path = ART / f'{name}.tga'
                info = header(path)
                self.assertEqual((info['type'], info['bpp']), (2, 32), f'{name}: an uncompressed 32-bit TGA')
                border = name.endswith('border')
                self.assertEqual(info['size'], (256, 64) if border else (CELL, CELL), f'{name}: size')
                if not border:
                    self.assertEqual(load(name, 'RGBA').getchannel('A').getextrema(), (255, 255), f'{name}: fully opaque')
                self.assertTrue((ART / 'source' / f'{name}.png').is_file(), f'{name}: the PNG source')

    def test_nothing_is_louder_than_the_chrome_should_be(self):
        for names in themes().values():
            for name in names:
                image = load(name, 'RGBA')
                solid = [p for p in image.getdata() if p[3] > 0]
                self.assertTrue(solid, f'{name}: empty')
                brightest = max(sum(p[:3]) for p in solid)
                self.assertLessEqual(brightest, MAX_BRIGHTNESS, f'{name}: a texel is too bright ({brightest})')
                if not name.endswith('border'):
                    mean = ImageStat.Stat(image.convert('L')).mean[0]
                    self.assertLessEqual(mean, MAX_MEAN_LUMINANCE, f'{name}: too bright overall ({mean:.0f})')

    def test_the_cells_of_a_story_join_without_a_seam(self):
        for prefix, names in themes().items():
            for letter, horizontal in (('w', True), ('t', False)):
                cells = [load(f'{prefix}-{letter}{n}') for n in range(1, 6)]
                for first, second in zip(cells, cells[1:]):
                    a, b = first.load(), second.load()
                    inside, across = [], []
                    for k in range(CELL):
                        # The last line of one cell, the first line of the next, and the two lines before the end of the first.
                        p = a[CELL - 1, k] if horizontal else a[k, CELL - 1]
                        q = b[0, k] if horizontal else b[k, 0]
                        r = a[CELL - 2, k] if horizontal else a[k, CELL - 2]
                        across.append(sum(abs(p[i] - q[i]) for i in range(3)))
                        inside.append(sum(abs(p[i] - r[i]) for i in range(3)))
                    seam, typical = sum(across) / CELL / 3, sum(inside) / CELL / 3
                    self.assertLessEqual(seam, max(10, typical * 3), f'{prefix}-{letter}: a seam between cells ({seam:.1f} against {typical:.1f})')

    def test_no_cell_has_a_blurred_patch_in_the_middle(self):
        for prefix, names in themes().items():
            for letter in ('w', 't'):
                ratios = []
                for n in range(1, 6):
                    grey = load(f'{prefix}-{letter}{n}').convert('L')
                    sharp = ImageChops.difference(grey, grey.filter(ImageFilter.GaussianBlur(1.2)))
                    whole = ImageStat.Stat(sharp).mean[0] or 1e-6
                    middle = ImageStat.Stat(sharp.crop((64, 64, 192, 192))).mean[0]
                    ratios.append(middle / whole)
                self.assertGreater(sum(ratios) / len(ratios), 0.6, f'{prefix}-{letter}: the middle of the cells is blurrier than the rest ({ratios})')


if __name__ == '__main__':
    unittest.main()
