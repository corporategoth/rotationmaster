#!/usr/bin/env python3
"""Import original imagegen bytes, export RGBA TGA, and compose QA only.
Never draws or reconstructs artwork; contact-sheet labels are inspection aids.
"""
import argparse, hashlib, json, shutil, struct
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parent

def resized(source,size):
    # Premultiplied alpha avoids matte fringes; contain full generated canvas.
    padding=max(1,round(size*.016))
    ratio=(size-padding*2)/max(source.size)
    dims=tuple(max(1,round(v*ratio)) for v in source.size)
    art=source.convert('RGBa').resize(dims,Image.Resampling.LANCZOS).convert('RGBA')
    image=Image.new('RGBA',(size,size));image.paste(art,((size-dims[0])//2,(size-dims[1])//2));return image

def stats(image):
    a=image.getchannel('A');h=a.histogram();w,z=image.size
    return dict(size=list(image.size),mode=image.mode,alpha=list(a.getextrema()),transparent=h[0],opaque=h[255],partial=sum(h[1:255]),corners=[a.getpixel(v) for v in ((0,0),(w-1,0),(0,z-1),(w-1,z-1))],bounds=a.getbbox())

def export(root):
    manifest=json.loads((root/'provenance.json').read_text());done=[]
    for entry in manifest['entries']:
        source=root/'source'/(entry['name']+'.png')
        if not source.exists():continue
        image=Image.open(source);assert image.mode=='RGBA',(source,image.mode)
        record=dict(key=entry['key'],name=entry['name'],source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),source=stats(image),exports={})
        extrema=record['source']['alpha']
        # Emissive overlays may be entirely translucent by design. Keep those
        # original alpha values instead of forcing an opaque highlight pixel.
        assert extrema[0]==0 and extrema[1]>0,source
        if entry['kind']!='overlay':assert extrema[1]==255,source
        for size in manifest.get('runtime_sizes',[64,128]):
            output=resized(image,size);name=entry['name']+('' if size==max(manifest.get('runtime_sizes',[64,128])) else '-'+str(size))+'.tga';path=root/name
            output.save(path,format='TGA',compression=None);header=path.read_bytes()[:18];decoded=Image.open(path)
            assert header[2]==2 and header[16]==32 and header[17]&15==8
            assert decoded.mode=='RGBA' and decoded.size==(size,size) and decoded.tobytes()==output.tobytes()
            assert stats(decoded)['corners']==[0,0,0,0]
            record['exports'][str(size)]=dict(stats(decoded),path=name,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        done.append(record)
    (root/'qa').mkdir(exist_ok=True);(root/'qa'/'alpha-report.json').write_text(json.dumps(done,indent=2)+'\n')
    return done

def contact(root,records,destination):
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',12);cols=4;cellw,cellh=240,146
    sheet=Image.new('RGB',(cols*cellw,max(1,(len(records)+cols-1)//cols)*cellh),(24,28,37));draw=ImageDraw.Draw(sheet)
    for i,entry in enumerate(records):
        x,y=i%cols*cellw,i//cols*cellh;draw.text((x+6,y+4),entry['key'],font=font,fill=(245,235,215))
        source=Image.open(root/(entry['name']+'.tga'))
        for row,color in enumerate(((24,28,37),(228,225,214))):
            top=y+25+row*58;draw.rectangle((x,top,x+cellw-1,top+57),fill=color)
            left=x+10
            for size in (20,24,32):
                icon=source.convert('RGBa').resize((size,size),Image.Resampling.LANCZOS).convert('RGBA');sheet.paste(icon,(left,top+35-size),icon);draw.text((left,top+38),str(size),font=font,fill=(190,190,185) if row==0 else (48,48,44));left+=size+35
    sheet.save(destination)

def qa_pages(root,records,destination):
    """Keep actual inspection pixels intact instead of shrinking a giant grid."""
    destination.mkdir(parents=True,exist_ok=True)
    for page,start in enumerate(range(0,len(records),32),1):
        contact(root,records[start:start+32],destination/('small-%02d.png'%page))
    font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',12)
    for page,start in enumerate(range(0,len(records),16),1):
        group=records[start:start+16];sheet=Image.new('RGB',(1000,720),(24,28,37));draw=ImageDraw.Draw(sheet)
        for index,entry in enumerate(group):
            x,y=index%4*250,index//4*180;draw.text((x+6,y+4),entry['key'],font=font,fill=(245,235,215))
            source=Image.open(root/(entry['name']+'.tga'))
            for size,left in ((64,8),(128,90)):
                icon=source.convert('RGBa').resize((size,size),Image.Resampling.LANCZOS).convert('RGBA');sheet.paste(icon,(x+left,y+26),icon)
        sheet.save(destination/('large-%02d.png'%page))

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=ROOT);parser.add_argument('--record',nargs=2,metavar=('KEY','PATH'));parser.add_argument('--contact',type=Path);parser.add_argument('--qa-pages',type=Path);args=parser.parse_args();root=args.root
    manifest=json.loads((root/'provenance.json').read_text())
    if args.record:
        key,generated=args.record;entry=next(e for e in manifest['entries'] if e['key']==key);source=root/'source'/(entry['name']+'.png');source.parent.mkdir(parents=True,exist_ok=True)
        if source.exists():assert source.read_bytes()==Path(generated).read_bytes(),'existing original differs; use a versioned replacement'
        else:shutil.copyfile(generated,source)
        entry.update(status='generated',generated_path=generated,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest());(root/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
    records=export(root)
    if args.contact:contact(root,records,args.contact)
    if args.qa_pages:qa_pages(root,records,args.qa_pages)
    print(json.dumps(dict(generated=len(records),planned=len(manifest['entries']),root=str(root))))
if __name__=='__main__':main()
