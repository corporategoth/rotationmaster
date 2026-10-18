#!/usr/bin/env python3
"""Rebuild original RM control textures. Requires rsvg-convert and ImageMagick."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'Assets' / 'Controls'
SHAPES = {
    'grip': '<g fill="white" stroke="none"><circle cx="11" cy="7" r="2"/><circle cx="21" cy="7" r="2"/><circle cx="11" cy="16" r="2"/><circle cx="21" cy="16" r="2"/><circle cx="11" cy="25" r="2"/><circle cx="21" cy="25" r="2"/></g>',
    'play': '<path d="M9 5 27 16 9 27Z" fill="white" stroke="none"/>',
    'center': '<circle cx="16" cy="16" r="8"/><path d="M16 3v6m0 14v6M3 16h6m14 0h6"/>',
    'plus': '<path d="M16 6v20M6 16h20"/>',
    'branch': '<path d="M16 5v12M16 17 7 26m9-9 9 9M7 19v7h7m4 0h7v-7"/>',
    'group-add': '<rect x="19" y="3" width="9" height="7" rx="1"/><rect x="19" y="22" width="9" height="7" rx="1"/><path d="M19 6H13v19h6M3 16h8m-4-4v8"/>',
    'transfer': '<path d="M5 9h20m-5-5 5 5-5 5M27 23H7m5-5-5 5 5 5"/>',
    'expand-all': '<rect x="4" y="4" width="24" height="24" rx="2"/><path d="M16 9v14M9 16h14"/>',
    'collapse-all': '<rect x="4" y="4" width="24" height="24" rx="2"/><path d="M9 16h14"/>',
    'compare': '<rect x="3" y="5" width="10" height="22" rx="1"/><rect x="19" y="5" width="10" height="22" rx="1"/><path d="M6 11h4m-4 5h4m12 0h4m-4 5h4"/>',
    'info': '<circle cx="16" cy="16" r="12"/><path d="M16 14v10m0-16v1"/>',
    'preview': '<circle cx="16" cy="16" r="4"/><path d="M2 16s5-9 14-9 14 9 14 9-5 9-14 9S2 16 2 16Z"/>',
    'warning': '<path d="M16 3 30 28H2ZM16 11v8m0 4v1"/>',
    'close': '<path d="m8 8 16 16M24 8 8 24"/>',
    'check': '<path d="m6 17 7 7L27 8"/>',
    'help': '<circle cx="16" cy="16" r="12"/><path d="M12 11a4 4 0 0 1 8 1c0 3-4 3-4 6m0 5v.1"/>',
    'up': '<path d="M16 25V7m-8 8 8-8 8 8"/>',
    'down': '<path d="M16 7v18m-8-8 8 8 8-8"/>',
    'copy': '<rect x="11" y="11" width="15" height="15" rx="2"/><path d="M21 7V6H6v15h1"/>',
    'trash': '<path d="M7 9h18M12 9V5h8v4M9 10l1 17h12l1-17M14 14v9m4-9v9"/>',
    'ungroup': '<path d="M5 9V5h22v4M5 23v4h22v-4"/><rect x="4" y="12" width="9" height="8" rx="1"/><rect x="19" y="12" width="9" height="8" rx="1"/>',
    'undo': '<path d="M11 7 4 14l7 7M5 14h13a9 9 0 0 1 9 9"/>',
    'redo': '<path d="m21 7 7 7-7 7m6-7H14a9 9 0 0 0-9 9"/>',
    'chevron-right': '<path d="m11 6 11 10-11 10Z" fill="white" stroke="none"/>',
    'chevron-double-down': '<path d="m7 7 9 8 9-8M7 17l9 8 9-8"/>',
    'chevron-down': '<path d="m6 11 10 11 10-11Z" fill="white" stroke="none"/>',
}

def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    images = {name: f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="white" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">{shape}</g></svg>\n' for name, shape in SHAPES.items()}
    images['color-hue'] = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="16"><defs><linearGradient id="g"><stop stop-color="red"/><stop offset=".167" stop-color="yellow"/><stop offset=".333" stop-color="lime"/><stop offset=".5" stop-color="cyan"/><stop offset=".667" stop-color="blue"/><stop offset=".833" stop-color="magenta"/><stop offset="1" stop-color="red"/></linearGradient></defs><path fill="url(#g)" d="M0 0h256v16H0z"/></svg>'
    for name,color,x1,y1,x2,y2 in [('saturation','white','0','0','1','0'),('value','black','0','1','0','0')]:
        images['color-'+name] = f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><defs><linearGradient id="g" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"><stop stop-color="{color}"/><stop offset="1" stop-color="{color}" stop-opacity="0"/></linearGradient></defs><path fill="url(#g)" d="M0 0h128v128H0z"/></svg>'
    images['card-border'] = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect x="1" y="1" width="62" height="62" rx="7" fill="none" stroke="white" stroke-width="2"/></svg>\n'
    images['card-fill'] = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" rx="8" fill="white"/></svg>\n'
    for name, source in images.items():
        path = ASSETS / (name + '.svg')
        path.write_text(source)
        png = subprocess.run(['rsvg-convert', str(path)], check=True, capture_output=True).stdout
        subprocess.run(['magick', 'png:-', '-type', 'TrueColorAlpha', '-depth', '8', '-compress', 'none', str(ASSETS / (name + '.tga'))], input=png, check=True)

if __name__ == '__main__':
    main()
