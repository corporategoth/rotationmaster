#!/usr/bin/env python3
"""Copy original imagegen assets, resize RGBA exports, and build inspection sheets.

No artwork is drawn or reconstructed here. Pillow only contains/resizes generated
pixels, writes uncompressed RGBA TGA, and composites labelled QA previews.
Run from any directory: python3 Assets/Conditions/export_icons.py
"""
from pathlib import Path
import hashlib
import json
import shutil

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
MANIFEST = json.loads((ROOT / 'provenance.json').read_text())
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13)
DARK = (24, 28, 37, 255)
LIGHT = (226, 223, 211, 255)


def contain_rgba(source, size):
    # Premultiplied resampling avoids dark fringes on partially transparent edges.
    padding = max(2, round(size * 0.047))
    limit = size - 2 * padding
    ratio = min(limit / source.width, limit / source.height)
    dims = (max(1, round(source.width * ratio)), max(1, round(source.height * ratio)))
    resized = source.convert('RGBa').resize(dims, Image.Resampling.LANCZOS).convert('RGBA')
    output = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    output.paste(resized, ((size - dims[0]) // 2, (size - dims[1]) // 2))
    return output


def alpha_stats(image):
    alpha = image.getchannel('A')
    counts = alpha.histogram()
    total = image.width * image.height
    return {
        'mode': image.mode, 'size': list(image.size), 'alpha_extrema': list(alpha.getextrema()),
        'transparent_pixels': counts[0], 'opaque_pixels': counts[255],
        'partial_alpha_pixels': sum(counts[1:255]),
        'transparent_percent': round(100 * counts[0] / total, 2),
        'nonzero_alpha_bounds': list(alpha.getbbox()),
        'corner_alpha': [alpha.getpixel(p) for p in ((0, 0), (image.width - 1, 0),
                         (0, image.height - 1), (image.width - 1, image.height - 1))],
    }


def export():
    records = []
    for entry in MANIFEST['entries']:
        name = entry['name']
        source_path = ROOT / 'source' / (name + '.png')
        generated_path = Path(entry['generated_path'])
        if not source_path.exists():
            shutil.copyfile(generated_path, source_path)
        original_bytes = source_path.read_bytes()
        source = Image.open(source_path)
        if source.mode != 'RGBA':
            raise ValueError(f'{name}: source must contain generated RGBA alpha, got {source.mode}')
        info = {'name': name, 'source_sha256': hashlib.sha256(original_bytes).hexdigest(),
                'source': alpha_stats(source), 'exports': {}}
        for size in (64, 128):
            image = contain_rgba(source, size)
            suffix = '-64' if size == 64 else ''
            path = ROOT / (name + suffix + '.tga')
            # Preserve reviewed exports byte-for-byte; create only missing assets.
            if not path.exists():
                image.save(path, format='TGA', compression=None)
            decoded = Image.open(path)
            header = path.read_bytes()[:18]
            assert header[2] == 2 and header[16] == 32 and header[17] & 15 == 8
            assert decoded.mode == 'RGBA' and decoded.size == (size, size)
            assert decoded.tobytes() == image.tobytes()
            assert decoded.getchannel('A').getextrema() == (0, 255)
            info['exports'][str(size)] = dict(alpha_stats(decoded),
                tga_type=header[2], bits_per_pixel=header[16], alpha_bits=header[17] & 15)
        records.append(info)
    (ROOT / 'qa' / 'alpha-report.json').write_text(json.dumps(records, indent=2) + '\n')
    return records


def contact_sheet(filename, sizes, cell_width, row_height):
    rows = (len(MANIFEST['entries']) + 3) // 4
    sheet = Image.new('RGBA', (cell_width * 4, row_height * rows), DARK)
    draw = ImageDraw.Draw(sheet)
    for index, entry in enumerate(MANIFEST['entries']):
        left, top = (index % 4) * cell_width, (index // 4) * row_height
        draw.text((left + 10, top + 6), entry['name'], fill=(244, 233, 207), font=FONT)
        for row, background in enumerate((DARK, LIGHT)):
            y = top + 28 + row * (max(sizes) + 21)
            draw.rectangle((left, y, left + cell_width - 1, y + max(sizes) + 20), fill=background)
            x = left + 10
            original = Image.open(ROOT / (entry['name'] + '.tga')).convert('RGBA')
            for size in sizes:
                icon = original if size == 128 else original.convert('RGBa').resize((size, size), Image.Resampling.LANCZOS).convert('RGBA')
                sheet.alpha_composite(icon, (x, y + max(sizes) - size))
                color = (213, 216, 226) if row == 0 else (54, 51, 44)
                draw.text((x, y + max(sizes) + 2), str(size), fill=color, font=FONT)
                x += size + 15
    sheet.convert('RGB').save(ROOT / 'qa' / filename)


if __name__ == '__main__':
    records = export()
    contact_sheet('contact-small.png', (20, 24, 32), 180, 142)
    contact_sheet('contact-large.png', (64, 128), 240, 334)
    print(f'Validated {len(records)} original RGBA PNGs and {len(records) * 2} uncompressed 32-bit RGBA TGAs.')
    for info in records:
        src, runtime = info['source'], info['exports']['128']
        print(f"{info['name']:12} source {src['size']} alpha {src['alpha_extrema']} "
              f"transparent {src['transparent_percent']:5.2f}% / 128px {runtime['transparent_percent']:5.2f}%")
