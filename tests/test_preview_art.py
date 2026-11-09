# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""The preview window's background images (Assets/Preview/) are what UI/preview.lua says they are: every theme the code names has a
wide and a tall image in the format the game reads, the classes are different pictures, nothing is louder than the chrome should be,
and the cells join without a seam, so any number of slots shows a finished picture."""
import re
import struct
import unittest
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'Assets' / 'Preview'
CELL, CELLS = 96, 5
# The picture sits under spell icons in a fight: dark and quiet. Mean luminance (0 to 255) and brightest texel (red + green + blue).
MAX_MEAN_LUMINANCE, MAX_BRIGHTNESS = 80, 640


def themes():
    """The (wide, tall) texture names UI/preview.lua lists, the neutral theme first."""
    text = (ROOT / 'UI' / 'preview.lua').read_text(encoding='utf-8')
    return re.findall(r"wide = '([\w-]+)', tall = '([\w-]+)'", text)


def header(path):
    data = path.read_bytes()[:18]
    return {'type': data[2], 'bpp': data[16], 'size': struct.unpack('<HH', data[12:16])}


def load(name):
    return Image.open(ART / f'{name}.tga').convert('RGB')


class PreviewArtTests(unittest.TestCase):
    def test_the_code_names_each_theme_once_and_only_the_ones_that_exist(self):
        pairs = themes()
        self.assertTrue(pairs)
        self.assertEqual(len(pairs), len(set(pairs)))
        on_disk = {path.stem for path in ART.glob('*-wide.tga')} | {path.stem for path in ART.glob('*-tall.tga')}
        self.assertEqual(on_disk, {name for pair in pairs for name in pair}, 'every image on disk is named, and every name has its image')

    def test_every_theme_has_its_images_in_the_format_the_game_reads(self):
        for wide, tall in themes():
            for name, size in ((wide, (512, 128)), (tall, (128, 512))):
                path = ART / f'{name}.tga'
                self.assertTrue(path.is_file(), f'{name}.tga is missing')
                info = header(path)
                self.assertEqual((info['type'], info['bpp']), (2, 32), f'{name}: an uncompressed 32-bit TGA')
                self.assertEqual(info['size'], size, f'{name}: size')
                image = Image.open(path).convert('RGBA')
                self.assertEqual(image.getchannel('A').getextrema(), (255, 255), f'{name}: fully opaque')
                self.assertTrue((ART / 'source' / f'{name}.png').is_file(), f'{name}: the PNG source')

    def test_nothing_is_louder_than_the_chrome_should_be(self):
        for wide, tall in themes():
            for name in (wide, tall):
                image = load(name)
                mean = ImageStat.Stat(image.convert('L')).mean[0]
                self.assertLessEqual(mean, MAX_MEAN_LUMINANCE, f'{name}: too bright overall ({mean:.0f})')
                brightest = max(sum(p) for p in image.getdata())
                self.assertLessEqual(brightest, MAX_BRIGHTNESS, f'{name}: a texel is too bright ({brightest})')

    def test_the_classes_are_different_pictures(self):
        thumbs = {}
        for wide, _ in themes():
            small = load(wide).convert('L').resize((64, 16), Image.BILINEAR)
            mean = ImageStat.Stat(small).mean[0] or 1
            thumbs[wide] = small.point(lambda v: min(255, int(v * 128 / mean)))
        names = sorted(thumbs)
        for index, first in enumerate(names):
            for second in names[index + 1:]:
                diff = ImageStat.Stat(ImageChops.difference(thumbs[first], thumbs[second])).mean[0]
                self.assertGreater(diff, 6, f'{first} and {second} are the same picture in another color ({diff:.1f})')

    def test_cells_join_without_a_seam(self):
        for wide, tall in themes():
            for name, horizontal in ((wide, True), (tall, False)):
                image = load(name)
                pixels = image.load()
                length = 512

                def gap(at):
                    # How different the line of texels at `at` is from the one before it.
                    total = 0
                    for other in range(128):
                        before = pixels[at - 1, other] if horizontal else pixels[other, at - 1]
                        after = pixels[at, other] if horizontal else pixels[other, at]
                        total += sum(abs(before[i] - after[i]) for i in range(3))
                    return total / (128 * 3)

                typical = sum(gap(at) for at in range(1, length)) / (length - 1)
                for cell in range(1, CELLS):
                    seam = gap(cell * CELL)
                    self.assertLessEqual(seam, max(14, typical * 3), f'{name}: a seam between cell {cell} and {cell + 1} ({seam:.1f} against {typical:.1f})')


if __name__ == '__main__':
    unittest.main()
