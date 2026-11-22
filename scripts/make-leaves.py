"""Draw translucent autumn leaf sprites with tapered veins; requires Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw
import math, random, shutil
root=Path(__file__).resolve().parents[1]
for variant,(name,color,width,bend) in enumerate([('ochre',(181,126,44),57,12),('rust',(153,75,39),49,-13),('olive',(143,133,62),63,6)]):
 random.seed(variant)
 w,h=192,256
 mask=Image.new('L',(w,h));d=ImageDraw.Draw(mask)
 def axis(t):return 91+bend*math.sin(t*math.pi)
 def half(t):return width*math.sin(math.pi*t)**0.82*(0.86+0.14*t)
 pts=[]
 for side in [-1,1]:
  indices=range(61) if side==-1 else range(60,-1,-1)
  for i in indices:
   t=i/60; tooth=1 if i%2 else .93
   pts.append((axis(t)+side*half(t)*tooth*(1 if side<0 else .88),21+204*t))
 d.polygon(pts,fill=255)
 im=Image.new('RGBA',(w,h));px=im.load()
 for y in range(h):
  for x in range(w):
   if mask.getpixel((x,y)):
    t=max(0,min(1,(y-21)/204));shade=.86+.19*(x/w)+.10*math.sin(t*7)+random.uniform(-.035,.035)
    px[x,y]=tuple(int(min(255,c*shade)) for c in color)+(245,)
 d=ImageDraw.Draw(im)
 vein=tuple(int(c*.60) for c in color)+(180,)
 center=[(axis(i/60),21+204*i/60) for i in range(61)]
 d.line(center,fill=vein,width=2)
 d.line([(axis(1),224),(86,247)],fill=vein,width=3)
 for j in range(1,8):
  t=j/9
  for side in [-1,1]:
   tip=max(0,t-.14)
   points=[(axis(t),21+204*t),(axis(t)+side*half(t)*.42,21+204*(t-.055)),(axis(tip)+side*half(tip)*.88,21+204*tip)]
   d.line(points,fill=vein,width=1)
 im.save(root/'assets'/f'leaf-{name}.png')
 shutil.copy(root/'assets'/f'leaf-{name}.png',root/'windows'/'app'/'assets'/f'leaf-{name}.png')
# Review sheet at enlarged and actual particle sizes.
sheet=Image.new('RGB',(540,310),'#f5f3e9')
for i,name in enumerate(['ochre','rust','olive']):
 im=Image.open(root/'assets'/f'leaf-{name}.png');sheet.paste(im,(i*180,0),im)
 small=im.resize((24,32),Image.Resampling.LANCZOS);sheet.paste(small,(i*180+80,270),small)
sheet.save('/private/tmp/sugrob-leaves-preview.png')
