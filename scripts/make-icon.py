"""Generate Sugrob app icons. Requires Pillow; macOS iconutil builds the ICNS."""
from pathlib import Path
from PIL import Image, ImageDraw
import math
root = Path(__file__).resolve().parents[1]
scale = 2
im = Image.new('RGBA', (1024*scale,1024*scale))
d = ImageDraw.Draw(im)
def box(b): return tuple(round(x*scale) for x in b)
d.rounded_rectangle(box((64,64,960,960)), radius=200*scale, fill='#F5F3E9')
# A six-fold snow crystal, generous strokes remain legible at Dock size.
ink='#293F36'
def stroke(a,b,width):
 d.line([tuple(v*scale for v in a),tuple(v*scale for v in b)],fill=ink,width=width*scale)
 r=width/2
 for x,y in [a,b]: d.ellipse(box((x-r,y-r,x+r,y+r)),fill=ink)
cx,cy=512,493
for k in range(6):
 a=math.pi/3*k-math.pi/2
 ux,uy=math.cos(a),math.sin(a)
 stroke((cx,cy),(cx+ux*270,cy+uy*270),36)
 for radius,branch in [(155,76),(237,50)]:
  x,y=cx+ux*radius,cy+uy*radius
  for side in [-1,1]:
   b=a+side*math.pi/3
   stroke((x,y),(x+math.cos(b)*branch,y+math.sin(b)*branch),27)
# Quiet underline suggests a snowdrift without competing with the crystal.
d.rounded_rectangle(box((386,828,638,844)),radius=8*scale,fill='#B6C3B1')
im=im.resize((1024,1024),Image.Resampling.LANCZOS)
im.save(root/'app-icon'/'Sugrob.png')
im.save(root/'windows'/'app'/'icon.ico',sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
im.resize((256,256),Image.Resampling.LANCZOS).save(root/'windows'/'app'/'icon.png')
im.save(root/'app-icon'/'Sugrob.icns')
