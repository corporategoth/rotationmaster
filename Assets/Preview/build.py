#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Rebuild the Shaman textures and exact-prefix preview sheets (requires Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
RESAMPLE = Image.Resampling.LANCZOS
ZOOM = 3


def texture(kind):
    size = (512, 128) if kind == 'wide' else (128, 512)
    image = Image.open(ROOT / 'source' / 'generated' / f'shaman-{kind}.png').convert('RGB')
    image = image.resize(size, RESAMPLE)
    # Global exposure reduction retains continuous transitions and tames highlights.
    image = image.point(lambda v: round(v * 0.58)).convert('RGBA')
    image.save(ROOT / 'source' / f'shaman-{kind}.png')
    image.save(ROOT / f'shaman-{kind}.tga', compression=None)
    return image


def window(img, n, vertical=False, icons=False):
    # The full short axis is shown; the long axis is clipped at 96 texels/slot.
    crop = (0, 0, 128, 96*n) if vertical else (0, 0, 96*n, 128)
    size = (68, 64*n+4) if vertical else (64*n+4, 68)
    canvas = img.crop(crop).resize(size, RESAMPLE).convert('RGBA')
    if icons:
        for i, name in enumerate(('spell', 'totem')):
            icon = Image.open(ROOT.parent / 'Conditions' / 'source' / f'{name}.png').convert('RGBA')
            icon = icon.resize((64, 64), RESAMPLE)
            canvas.alpha_composite(icon, (2 + i*64, 2))
    return canvas.convert('RGB').resize((size[0]*ZOOM, size[1]*ZOOM), Image.Resampling.NEAREST)


def qa(wide, tall):
    font = ImageFont.load_default()
    sheet = Image.new('RGB', (1100, 2550), (17, 19, 23))
    draw = ImageDraw.Draw(sheet)
    y = 15
    for n in range(1, 6):
        draw.text((18, y), f'{n} empty slot(s)', font=font, fill=(197, 200, 202))
        y += 20
        panel = window(wide, n)
        sheet.paste(panel, (18, y))
        y += panel.height + 18
    draw.text((18, y), '5 slots: two icons, three empty', font=font, fill=(197, 200, 202))
    y += 20
    panel = window(wide, 5, icons=True)
    sheet.paste(panel, (18, y))
    y += panel.height + 18
    draw.text((18, y), '3 and 5 vertical slots', font=font, fill=(197, 200, 202))
    y += 20
    sheet.paste(window(tall, 3, True), (18, y))
    sheet.paste(window(tall, 5, True), (270, y))
    sheet.crop((0, 0, 1100, y + (64*5+4)*3 + 18)).save(ROOT / 'qa' / 'shaman.png')
    full = Image.new('RGB', (1440+30+384, 1536), (17, 19, 23))
    full.paste(wide.crop((0, 0, 480, 128)).convert('RGB').resize((1440, 384), Image.Resampling.NEAREST), (0, 0))
    full.paste(tall.crop((0, 0, 128, 480)).convert('RGB').resize((384, 1440), Image.Resampling.NEAREST), (1470, 0))
    full.save(ROOT / 'qa' / 'shaman-full.png')


if __name__ == '__main__':
    (ROOT / 'source').mkdir(exist_ok=True)
    (ROOT / 'qa').mkdir(exist_ok=True)
    qa(texture('wide'), texture('tall'))
