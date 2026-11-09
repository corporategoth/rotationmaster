#!/usr/bin/env python3
# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

"""Rebuild Shaman textures and game-layout QA; requires Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent
GEN = ROOT / 'source' / 'generated'
L = Image.Resampling.LANCZOS
N = Image.Resampling.NEAREST


def painting(kind):
    if kind == 'w':
        im = Image.open(GEN / 'shaman-row-final.png').convert('RGB')
        # 2110 x 422: an exact 5:1 native-pixel crop, no geometric distortion.
        master = im.crop((0, 70, 2110, 492))
    else:
        im = Image.open(GEN / 'shaman-column-final.png').convert('RGB')
        # 360 x 1800: an exact 1:5 native-pixel crop.
        master = im.crop((215, 0, 575, 1800))
    master = master.point(lambda p: round(p * .65))
    master.save(GEN / f'shaman-{kind}-master.png')
    size = (1280, 256) if kind == 'w' else (256, 1280)
    whole = master.resize(size, L).convert('RGBA')
    cells = []
    for i in range(5):
        box = (i*256, 0, (i+1)*256, 256) if kind == 'w' else (0, i*256, 256, (i+1)*256)
        cell = whole.crop(box)
        cell.save(ROOT / 'source' / f'shaman-{kind}{i+1}.png')
        cell.save(ROOT / f'shaman-{kind}{i+1}.tga', compression=None)
        cells.append(cell)
    return master, cells


def border():
    atlas = Image.new('RGBA', (256, 64))
    d = ImageDraw.Draw(atlas)
    for y, lit in [(0, False), (16, True)]:
        d.rectangle((0,y+2,255,y+13), fill=(22,16,13,255))
        d.rectangle((0,y+3,255,y+11), fill=(72,48,32,255))
        d.line((0,y+4,255,y+4), fill=(139,108,72,255))
        d.line((0,y+11,255,y+11), fill=(39,27,21,255))
        for x in range(8,256,16):
            d.polygon([(x-4,y+7),(x,y+5),(x+4,y+7),(x,y+9)], fill=(36,80,74,255) if not lit else (73,155,139,255))
            d.point((x,y+7), fill=(93,57,29,255) if not lit else (191,112,50,255))
    # Corner is a symmetric solid carved joint, so all four reflections work.
    d.rounded_rectangle((0,32,15,47), radius=3, fill=(23,17,13,255), outline=(110,83,54,255), width=2)
    d.polygon([(8,35),(12,40),(8,44),(4,40)], fill=(69,100,86,255))
    for x, lit in [(16,False),(32,True)]:
        d.ellipse((x+1,33,x+14,46), fill=(24,19,15,255), outline=(122,94,61,255), width=2)
        d.ellipse((x+5,37,x+10,42), fill=(37,78,72,255) if not lit else (83,164,145,255))
        if lit: d.point((x+7,39), fill=(198,125,59,255))
    atlas.save(ROOT/'source'/'shaman-border.png')
    atlas.save(ROOT/'shaman-border.tga', compression=None)
    return atlas


def window(cells, atlas, n, k=0, vertical=False):
    w,h = (64,64*n) if vertical else (64*n,64)
    out = Image.new('RGBA',(w,h))
    names = ['spell','totem','buff','combat','resources']
    for i in range(n):
        xy=(0,i*64) if vertical else (i*64,0)
        cell=cells[i].resize((64,64),N)
        out.alpha_composite(cell,xy)
        if i < k:
            icon=Image.open(ROOT.parent/'Conditions'/'source'/f'{names[i]}.png').convert('RGBA').resize((64,64),L)
            out.alpha_composite(icon,xy)
    for i in range(n):
        rail=atlas.crop((0,16 if i<k else 0,256,32 if i<k else 16)).resize((64,6),N)
        if vertical:
            rail=rail.transpose(Image.Transpose.ROTATE_90)
            out.alpha_composite(rail,(0,i*64)); out.alpha_composite(ImageOps.mirror(rail),(w-6,i*64))
        else:
            out.alpha_composite(rail,(i*64,0)); out.alpha_composite(ImageOps.flip(rail),(i*64,h-6))
    corner=atlas.crop((0,32,16,48)).resize((6,6),N)
    for x,flipx in [(0,False),(w-6,True)]:
        for y,flipy in [(0,False),(h-6,True)]:
            c=ImageOps.mirror(corner) if flipx else corner
            if flipy: c=ImageOps.flip(c)
            out.alpha_composite(c,(x,y))
    for i in range(1,n):
        x0=32 if i<k else 16
        stud=atlas.crop((x0,32,x0+16,48)).resize((6,6),N)
        if vertical:
            out.alpha_composite(stud,(0,i*64-3)); out.alpha_composite(stud,(w-6,i*64-3))
        else:
            out.alpha_composite(stud,(i*64-3,0)); out.alpha_composite(stud,(i*64-3,h-6))
    return out.convert('RGB').resize((w*3,h*3),N)


def qa(wmaster,tmaster,w,t,a):
    sheet=Image.new('RGB',(1050,2700),(17,19,23)); d=ImageDraw.Draw(sheet); y=12
    rows=[(f'{n} empty slots',w,n,0,False) for n in range(1,6)] + [('5 slots, 2 active',w,5,2,False),('5 slots, 5 active',w,5,5,False)]
    for label,c,n,k,v in rows:
        d.text((15,y),label,fill=(205,205,205)); y+=18
        panel=window(c,a,n,k,v); sheet.paste(panel,(15,y)); y+=panel.height+15
    d.text((15,y),'3 and 5 vertical slots, empty',fill=(205,205,205)); y+=18
    sheet.paste(window(t,a,3,0,True),(15,y)); sheet.paste(window(t,a,5,0,True),(250,y))
    sheet.crop((0,0,1050,y+960+15)).save(ROOT/'qa'/'shaman.png')
    # Both masters are presented at their exact native crop size.
    full=Image.new('RGB',(wmaster.width+tmaster.width+30,max(wmaster.height+2*(wmaster.height)+20,tmaster.height)),(17,19,23))
    full.paste(wmaster,(0,0)); full.paste(tmaster,(wmaster.width+30,0))
    c=wmaster.crop((4*wmaster.width//5,0,wmaster.width,wmaster.height))
    full.paste(c.resize((c.width*2,c.height*2),N),(0,wmaster.height+20))
    full.save(ROOT/'qa'/'shaman-full.png')


if __name__ == '__main__':
    (ROOT/'qa').mkdir(exist_ok=True)
    wm,w=painting('w'); tm,t=painting('t'); a=border(); qa(wm,tm,w,t,a)
