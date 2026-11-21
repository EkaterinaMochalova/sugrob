"""Original procedural sound design, not field recordings. No external audio assets."""
import math, random, struct, wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'assets'
RATE=22050
COUNT=RATE*24
for name in ['wind','water','leaves','rain']:
 rng=random.Random(name)
 slow=mid=0.0
 samples=[]
 for i in range(COUNT):
  t=i/RATE
  n=rng.uniform(-1,1)
  slow+=0.004*(n-slow)
  mid+=0.055*(n-mid)
  swell=.65+.18*math.sin(2*math.pi*t/8)+.1*math.sin(2*math.pi*t/3)
  if name=='wind':v=slow*2.3*swell+mid*.14
  elif name=='water':v=mid*.52*(.5+.5*math.sin(2*math.pi*t/6)**2)+slow*.7
  elif name=='leaves':v=(n-mid)*.055*(.3+.7*math.sin(2*math.pi*t/4)**8)+slow*.6
  else:v=(n-mid)*.055+mid*.38+slow*.3
  samples.append(v)
 # Equal-power transition from the end into the beginning, then remove overlap.
 overlap=RATE
 for i in range(overlap):
  u=i/overlap
  samples[i]=samples[COUNT-overlap+i]*math.cos(u*math.pi/2)+samples[i]*math.sin(u*math.pi/2)
 samples=samples[:-overlap]
 peak=max(abs(v) for v in samples)
 with wave.open(str(ROOT/(name+'.wav')),'wb') as out:
  out.setnchannels(2);out.setsampwidth(2);out.setframerate(RATE)
  # A short decorrelation makes the ambience broad without discrete musical notes.
  out.writeframes(b''.join(struct.pack('<hh',int(v/peak*8500),int(samples[(i+157)%len(samples)]/peak*8500)) for i,v in enumerate(samples)))
 print(name+'.wav')
