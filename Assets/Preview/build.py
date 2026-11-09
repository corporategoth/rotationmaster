# Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

from PIL import Image, ImageDraw, ImageFont, ImageOps
from pathlib import Path
import math
P=Path(__file__).parent
S=P/'source'; Q=P/'qa'
S.mkdir(exist_ok=True); Q.mkdir(exist_ok=True)
# base, bevel, inlay, accent, motif, description
T={
'rotation-master':((38,40,47),(143,113,65),(65,68,78),(94,75,125),'trigem','Gunmetal and slate; aged gold, blue/violet/orange gems'),
'warrior':((42,39,40),(120,113,103),(77,40,42),(133,55,54),'rivet','Blackened steel, riveted plate and worn red leather; crimson'),
'paladin':((78,77,70),(156,135,87),(115,113,99),(167,148,104),'sun','White-gray marble and brass; warm white-gold'),
'hunter':((41,52,39),(119,106,74),(63,81,52),(104,130,74),'arrow','Stitched dark-green leather and horn; hunter green'),
'rogue':((32,35,32),(118,102,68),(59,59,44),(116,120,58),'cross','Black leather, brass studs and chain; dull poison green'),
'priest':((77,72,72),(150,138,111),(106,99,101),(111,85,130),'ring','Ivory and pale-gold filigree; violet'),
'deathknight':((36,44,51),(101,117,126),(49,66,76),(83,133,153),'rune','Runed iron; frost blue'),
'shaman':((53,48,40),(119,107,83),(58,76,72),(65,119,115),'spiral','Weathered wood and stone; teal and blue'),
'mage':((39,39,60),(108,110,135),(54,51,84),(104,92,151),'star','Indigo stone and silver filigree; violet blue'),
'warlock':((40,39,41),(108,104,92),(63,50,65),(91,118,64),'horn','Charcoal bone and thorn; fel green and purple'),
'monk':((55,64,52),(125,122,88),(79,105,80),(113,148,108),'bead','Jade, lacquered wood and bamboo; soft jade'),
'druid':((48,45,36),(119,104,68),(61,75,48),(105,133,70),'leaf','Dark bark and vines; moon gold and living green'),
'demonhunter':((33,37,36),(100,99,101),(54,65,49),(104,130,66),'glaive','Black spiked iron; fel green and magenta-purple'),
'evoker':((43,52,49),(137,106,67),(53,81,76),(98,139,124),'scale','Bronze, teal dragon scales and obsidian; ember gold')}
ref=Image.open(S/'material-reference.png').convert('RGB')
# Crop a single neutral interlace section; mirroring enforces seamless length.
tex=ref.crop((360,235,670,435)).resize((16,32),Image.Resampling.LANCZOS).convert('L')
tex=ImageOps.autocontrast(tex)
font=ImageFont.load_default()
def c(v,a=255): return tuple(v)+(a,)
def mix(a,b,t): return tuple(round(a[i]*(1-t)+b[i]*t) for i in range(3))
def make(name,vals):
 base,metal,inlay,accent,motif,_=vals
 # 4x drawing for clean tiny bevels
 k=4; im=Image.new('RGBA',(128,128)); d=ImageDraw.Draw(im)
 def rect(box,col): d.rectangle(tuple(int(x*k) for x in box),fill=c(col))
 def line(points,col,w=1): d.line([(int(x*k),int(y*k)) for x,y in points], fill=c(col),width=int(w*k),joint='curve')
 # Repeat mirrored source luminance gives continuous detailed material surface.
 pix=tex.load()
 for y in range(32):
  for x in range(32):
   v=pix[min(x,31-x),y]/255
   col=mix(base,metal,max(0,min(.52,(v-.16)*.58)))
   rect((x,y,x+1,y+1),col)
 rect((0,0,32,1),mix(base,(0,0,0),.65)); rect((0,30,32,32),mix(base,(0,0,0),.65))
 for y,col in [(2,mix(base,metal,.35)),(4,metal),(6,mix(base,metal,.35)),(25,mix(base,metal,.35)),(27,metal),(29,mix(base,metal,.35))]: rect((0,y,32,y+1),col)
 rect((0,10,32,22),inlay)
 # understated symmetric periodic carved motifs
 line([(0,16),(4,12),(8,16),(12,20),(16,16),(20,12),(24,16),(28,20),(32,16)],mix(metal,base,.25),1.3)
 line([(0,16),(4,20),(8,16),(12,12),(16,16),(20,20),(24,16),(28,12),(32,16)],mix(metal,base,.43),1)
 for x in (8,24):
  d.ellipse(((x-1.7)*k,14.3*k,(x+1.7)*k,17.7*k),fill=c(accent),outline=c(mix(metal,base,.3)),width=k)
 edge=im.resize((32,32),Image.Resampling.LANCZOS)
 # Force exact first/last columns, including corners.
 for y in range(32): edge.putpixel((31,y),edge.getpixel((0,y)))
 # subdued corner setting with rounded silhouette; cutout is transparent.
 sheet=Image.new('RGBA',(256,128)); d=ImageDraw.Draw(sheet)
 def poly(points,fill,outline=None,w=1):
  p=[(int(x*k),int(y*k)) for x,y in points]; d.polygon(p,fill=c(fill));
  if outline: d.line(p+[p[0]],fill=c(outline),width=w*k,joint='curve')
 def ellipse(box,fill,outline=None,w=1): d.ellipse(tuple(int(x*k) for x in box),fill=c(fill),outline=c(outline) if outline else None,width=w*k)
 def ln(points,col,w=1): d.line([(int(x*k),int(y*k)) for x,y in points],fill=c(col),width=w*k,joint='curve')
 dark=mix(base,(0,0,0),.45); hi=mix(metal,(180,169,138),.15)
 poly([(2,2),(21,2),(29,7),(31,15),(25,15),(19,11),(11,11),(11,19),(15,25),(15,31),(7,29),(2,21)],base,dark,2)
 poly([(4,4),(21,4),(27,8),(27,11),(19,8),(8,8),(8,19),(11,27),(8,27),(4,21)],metal,dark,1)
 poly([(8,8),(19,8),(24,12),(19,15),(15,19),(12,24),(8,19)],inlay,dark,1)
 poly([(8,8),(14,9),(18,14),(14,18),(9,14)],metal,dark,1)
 poly([(10,10),(14,10),(16,14),(14,16),(10,14)],accent,dark,1)
 # centred symmetrical stud with strong silhouette and palette-specific glyph
 ellipse((34,2,62,30),dark); ellipse((36,4,60,28),metal,dark,1); ellipse((39,7,57,25),inlay,dark,1)
 if motif=='rivet':
  ellipse((42,10,54,22),metal,dark,1); ellipse((46,12,50,16),hi)
 elif motif in ('trigem','star','scale','horn'):
  poly([(48,8),(55,16),(48,24),(41,16)],accent,dark,1)
  ln([(48,9),(48,23)],hi,1); ln([(42,16),(54,16)],mix(accent,hi,.35),1)
  if motif=='trigem':
   poly([(43,16),(48,11),(48,21)],(76,99,135)); poly([(48,11),(53,16),(48,21)],(137,91,68))
  if motif=='horn': ln([(41,13),(38,9),(40,16)],metal,2); ln([(55,13),(58,9),(56,16)],metal,2)
 elif motif in ('sun','cross','rune','glaive'):
  if motif=='sun':
   for a in range(0,360,45):
    a=math.radians(a); ln([(48+5*math.cos(a),16+5*math.sin(a)),(48+9*math.cos(a),16+9*math.sin(a))],accent,2)
   ellipse((44,12,52,20),hi,dark,1)
  elif motif=='cross':
   ln([(43,11),(53,21)],accent,2); ln([(53,11),(43,21)],accent,2); ellipse((46,14,50,18),hi)
  elif motif=='rune':
   ln([(45,10),(45,22),(51,17),(45,14),(51,10)],accent,2)
  else:
   ln([(40,19),(44,12),(48,10),(46,16),(40,19)],accent,2); ln([(56,19),(52,12),(48,10),(50,16),(56,19)],accent,2)
 elif motif=='ring': ellipse((42,10,54,22),accent,hi,1); ellipse((45,13,51,19),inlay)
 elif motif=='spiral':
  ln([(43,18),(43,13),(46,11),(51,11),(53,14),(53,19),(50,21),(46,20),(46,16),(49,15),(50,17)],accent,2)
 elif motif=='bead': ellipse((42,10,54,22),accent,dark,1); ellipse((45,12,48,15),hi)
 elif motif=='arrow': poly([(48,8),(55,19),(50,18),(48,23),(46,18),(41,19)],accent,dark,1)
 elif motif=='leaf':
  poly([(48,9),(54,12),(53,19),(48,23),(43,19),(42,12)],accent,dark,1); ln([(48,10),(48,22)],hi,1)
 sheet=sheet.resize((64,32),Image.Resampling.LANCZOS)
 for kind,img in [('edge',edge),('ornament',sheet)]:
  img.save(S/f'{name}-{kind}.png'); img.save(P/f'{name}-{kind}.tga',compression=None)
 return edge,sheet
assets={n:make(n,v) for n,v in T.items()}
def scaled(im,size): return im.resize((size,size),Image.Resampling.LANCZOS)
def assembly(name,icon,n=3,vertical=False):
 e=max(6,min(16,math.floor(icon*.125+.5))); w=icon*(1 if vertical else n); h=icon*(n if vertical else 1)
 out=Image.new('RGBA',(w+2*e,h+2*e)); ed,sh=assets[name]; tile=scaled(ed,e); corner=scaled(sh.crop((0,0,32,32)),e); stud=scaled(sh.crop((32,0,64,32)),e)
 for x in range(0,w,e):
  part=tile.crop((0,0,min(e,w-x),e)); out.alpha_composite(part,(e+x,0)); out.alpha_composite(ImageOps.flip(part),(e+x,e+h))
 left=tile.transpose(Image.Transpose.ROTATE_90); right=tile.transpose(Image.Transpose.ROTATE_270)
 for y in range(0,h,e):
  part=left.crop((0,0,e,min(e,h-y))); out.alpha_composite(part,(0,e+y)); part=right.crop((0,0,e,min(e,h-y))); out.alpha_composite(part,(e+w,e+y))
 for xy,im in [((0,0),corner),((e+w,0),ImageOps.mirror(corner)),((0,e+h),ImageOps.flip(corner)),((e+w,e+h),ImageOps.flip(ImageOps.mirror(corner)))]: out.alpha_composite(im,xy)
 d=ImageDraw.Draw(out); colors=[(172,64,35),(30,109,165),(143,104,40),(62,133,62),(133,57,145)]
 for i in range(n):
  x=e+(0 if vertical else i*icon); y=e+(i*icon if vertical else 0)
  d.rectangle((x,y,x+icon-1,y+icon-1),fill=colors[i]); d.ellipse((x+icon*.18,y+icon*.18,x+icon*.82,y+icon*.82),fill=tuple(min(255,int(v*1.35)) for v in colors[i])); d.polygon([(x+icon*.5,y+icon*.17),(x+icon*.75,y+icon*.5),(x+icon*.5,y+icon*.83),(x+icon*.25,y+icon*.5)],fill=(203,180,105))
 for i in range(1,n):
  if vertical:
   out.alpha_composite(stud.transpose(Image.Transpose.ROTATE_90),(0,e+i*icon-e//2)); out.alpha_composite(stud.transpose(Image.Transpose.ROTATE_270),(e+w,e+i*icon-e//2))
  else:
   out.alpha_composite(stud,(e+i*icon-e//2,0)); out.alpha_composite(ImageOps.flip(stud),(e+i*icon-e//2,e+h))
 return out
names=list(T); rowh=500; W=1350
contact=Image.new('RGB',(W,rowh*14),(24,25,29)); d=ImageDraw.Draw(contact)
for ix,name in enumerate(names):
 y=ix*rowh; d.rectangle((0,y,W,y+rowh//2-1),fill=(31,32,37)); d.rectangle((0,y+rowh//2,W,y+rowh-1),fill=(210,210,204))
 for half in range(2):
  yy=y+half*rowh//2; d.text((8,yy+6),name,fill=(225,225,225) if not half else (30,30,30),font=font)
  layouts=[(48,3,False,110),(96,3,False,290)]
  if ix<6: layouts.append((64,5,False,620))
  if ix<4: layouts.append((64,3,True,990))
  for size,n,vert,x in layouts:
   a=assembly(name,size,n,vert)
 
   contact.paste(a,(x,yy+25),a)
contact.save(Q/'contact.png')
# Dedicated crops at actual 4x nearest-neighbour magnification.
detail=Image.new('RGB',(1250,540),(37,38,42)); d=ImageDraw.Draw(detail)
for i,name in enumerate(('rotation-master','druid')):
 a=assembly(name,96); e=12; corner=a.crop((0,0,32,32)).resize((128,128),Image.Resampling.NEAREST); stud=a.crop((e+96-16,0,e+96+16,32)).resize((128,128),Image.Resampling.NEAREST)
 x=20+i*620; d.text((x,15),name+' - corner / joint at 4x',fill='white',font=font); detail.paste(corner,(x,40),corner); detail.paste(stud,(x+155,40),stud)
 a=assembly(name,64,3,True); c1=a.crop((0,0,26,26)).resize((104,104),Image.Resampling.NEAREST); s=a.crop((0,6+64-13,26,6+64+13)).resize((104,104),Image.Resampling.NEAREST); d.text((x,210),'column corner / joint at 4x',fill='white',font=font); detail.paste(c1,(x,235),c1); detail.paste(s,(x+130,235),s)
detail.save(Q/'detail.png')
