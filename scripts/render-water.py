"""Analytic water-lens sprites: surface normals, Fresnel rim and soft reflected light.
Straight-alpha PNGs, no opaque background. No screen capture or user imagery.
"""
from pathlib import Path
import tempfile
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[1]
n=192
yy,xx=np.mgrid[-1.35:1.35:complex(n),-1.2:1.2:complex(n)]
def smooth(a,b,x):
 t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)
for variant in range(3):
 # A droplet pinned to vertical glass is broad at the bottom and pulled at its neck.
 y=yy/1.05
 width=.78*(1+(.05 if variant<2 else .18)*y+.045*np.sin(y*6+variant))
 x=(xx-.035*np.sin(y*3+variant))/width
 q=x*x+y*y
 edge=1-smooth(.92,1.02,q)
 z=np.sqrt(np.maximum(0,1-q))
 nx=x*.78; ny=y*.9; nz=z
 norm=np.sqrt(nx*nx+ny*ny+nz*nz)+1e-6
 nx/=norm;ny/=norm;nz/=norm
 fresnel=.02+.98*(1-nz)**5
 # Broad reflected daylight plus a small soft highlight, neither a drawn outline.
 reflected=np.exp(-((nx+.45)**2/.045+(ny+.55)**2/.025))
 lower=np.exp(-((nx-.12)**2/.25+(ny-.82)**2/.018))
 upper=np.exp(-((nx+.1)**2/.4+(ny+.75)**2/.045))
 shadow=np.exp(-((ny-.15)**2/.45))*fresnel
 light=np.clip(reflected*.78+lower*.25+upper*.13,0,.9)
 dark=np.clip(shadow*.65+(.09*(1-z)),0,.4)
 a=(1-(1-light)*(1-dark))*edge
 # Transparent low-frequency body; the substrate remains visible.
 gray=np.where(a>1e-6,light/(light+dark+1e-6),0)
 rgba=np.stack([gray,gray,gray,a],axis=-1)
 Image.fromarray(np.uint8(np.clip(rgba,0,1)*255)).save(root/'assets'/f'water-lens-{variant}.png')
# Inspection at real size and magnified on both light and dark grounds.
out=Image.new('RGB',(900,420),(235,234,230))
for side,color in [(0,(235,234,230)),(450,(31,40,49))]:
 for j in range(3):
  im=Image.open(root/'assets'/f'water-lens-{j}.png')
  out.paste(color,(side,0,side+450,420))
 # Draw after backgrounds.
for side in [0,450]:
 for j in range(3):
  im=Image.open(root/'assets'/f'water-lens-{j}.png').resize((120,120))
  out.paste(im,(side+20+j*140,60),im)
  tiny=im.resize((24,28))
  out.paste(tiny,(side+60+j*140,260),tiny)
out.save(Path(tempfile.gettempdir())/'water-lens-proof.png')
