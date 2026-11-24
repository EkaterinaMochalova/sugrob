'use strict';
let refractionPending=false,refractionEpoch=0;
const C = window.Sugrob, art = window.SugrobArt, api = window.sugrob;
const canvas = document.getElementById('scene'), ctx = canvas.getContext('2d');
const background = document.createElement('canvas'), bg = background.getContext('2d');
let w = 1, h = 1, dpr = 1, state, mode = 'snow', mood, moodKey = '', modeKey = '', ground = 0;
let cloudModifier = false;
let cloudIndex = 0, cloudDrag = null, cloudInput = false;
let stormWait = 8, bolt = null, previewBolt = null, lastPreview = -100;
let beads = [];
let falling = [], resting = [], motes = [], windows = [], cursor = { x: -1000, y: -1000 };
const sounds = new window.Soundscape();
const sunlight = new window.Sunlight();
const glass = new window.RainGlass();
const fogMotion = new window.FogMotion();
const photos = Object.fromEntries(['autumn','olive','pine','maple','cherry','gull'].map(name => { const image = new Image(); image.src = `assets/${name}.png`; return [name, image]; }));
let events = [], eventWait = 1;
let lastFrame = 0, spawnDebt = 0, moteWait = 2, time = 0, lastClock = 0;
function resize() {
  w = innerWidth; h = innerHeight; dpr = Math.min(devicePixelRatio || 1, 2);
  canvas.width = Math.ceil(w * dpr); canvas.height = Math.ceil(h * dpr); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  background.width = w; background.height = h; moodKey = ''; resting = []; updateMood();
  if(state){clearRefraction();glass.configure((mode==='rain'||mode==='storm')&&state.settings.rainGlass!==false,w,h,state.settings.opacity);}
}
function updateMood() {
  if (!state) return;
  const s = state.settings;
  const next = s.atmosphere && s.city ? C.mood(s.city, new Date(), state.weather.current?.weather_code) : null;
  const key = JSON.stringify(next && { ...next, time: undefined });
  if (key !== moodKey) { moodKey = key; mood = next; motes = []; events = []; eventWait = 1; bg.clearRect(0, 0, w, h); if (mood) art.backdrop(bg, w, h, mood); }
}
function renderState(next) {
  state = next; const s = state.settings;
  if(!s.dragClouds || s.paused) finishCloudDrag();
  if(s.paused)fogMotion.previous=null;
  mode = s.enabled ? C.currentEffect(next.weather.current) : s.mode;
  if(mode!=='fog')fogMotion.reset();
  const key = String(mode);
  if (key !== modeKey) {
    if(mode&&!(typeof matchMedia==='function'&&matchMedia('(prefers-reduced-motion: reduce)').matches))canvas.animate?.([{opacity:0},{opacity:1}],{duration:900,easing:'ease-out'});
    finishCloudDrag(); stormWait = 8; bolt = null; beads = []; falling = []; resting = []; spawnDebt = 0; modeKey = key; if (mode === 'clouds') for(let i=0;i<5;i++){spawn(s);falling[falling.length-1].x=w*(.04+i*.23);} }
  updateMood();
  clearRefraction();glass.configure((mode==='rain'||mode==='storm')&&s.rainGlass!==false,w,h,s.opacity);
  sunlight.configure(mode === 'sunny',s);
  sounds.sync(next.audioLeader && s.sound && !s.paused, C.soundTrack(s,next.weather.current), s.soundSource === 'weather' ? s.weatherVolume : s.volume, s.soundSource === 'weather' && s.lightning !== false,mode);
}
function cloudAt(x,y) {
 if(!state?.settings.dragClouds||state.settings.paused||mode!=='clouds')return null;
 return [...falling].reverse().find(p=>{if(p.kind!=='clouds')return false;const aspect=p.variant===1?2:3;return ((x-p.x)/(p.size*aspect*p.stretch*.42))**2+((y-p.y)/(p.size*.34))**2<=1;})||null;
}
function cloudHitMode(){const next=cloudModifier&&(!!cloudDrag||!!cloudAt(cursor.x,cursor.y));canvas.style.cursor=cloudDrag?'grabbing':next?'grab':'default';if(next!==cloudInput){cloudInput=next;api.cloudInteractive(next);}}
function finishCloudDrag(){if(!cloudDrag)return;const p=cloudDrag.cloud;cloudDrag=null;api.saveCloudLevel(p.variant,C.clamp(p.y/h,0,1)).catch(()=>{});}
// Mouse events also work when Electron forwards native WM_MOUSEMOVE without pointer events.
addEventListener('mousedown',e=>{
 if(e.button!==0||!e.ctrlKey)return;cloudModifier=true;const p=cloudAt(e.clientX,e.clientY);if(!p)return;
 cloudDrag={cloud:p,dx:e.clientX-p.x,dy:e.clientY-p.y};
 cursor={x:e.clientX,y:e.clientY};cloudHitMode();e.preventDefault();
});
function moveCloudMouse(e){
 cloudModifier=e.ctrlKey===true;
 cursor={x:e.clientX,y:e.clientY};
 if(cloudDrag){
  if(e.buttons===0||!cloudModifier){finishCloudDrag();}
  else {const p=cloudDrag.cloud;p.x=C.clamp(e.clientX-cloudDrag.dx,10,w-10);p.y=C.clamp(e.clientY-cloudDrag.dy,10,h-10);}
 }
 cloudHitMode();
}
addEventListener('mousemove',moveCloudMouse);
addEventListener('mouseup',()=>{finishCloudDrag();cloudHitMode();});
addEventListener('blur',()=>{finishCloudDrag();cursor={x:-1000,y:-1000};cloudHitMode();});
api.onResetClouds(()=>{cloudDrag=null;for(const p of falling)if(p.kind==='clouds')p.y=Math.min(150,h*(.08+Math.random()*.08));cloudHitMode();});
function release(p) { p.surface = null; p.vx = (Math.random() - .5) * 85; p.vy = 22; p.life = 3; falling.push(p); }
api.onEnvironment(data => {
  cloudModifier=data.cloudModifier===true;if(!cloudModifier)finishCloudDrag();
  cursor = data.cursor;cloudHitMode(); ground = data.ground;
  if(mode==='fog'&&!state?.settings.paused&&!(typeof matchMedia==='function'&&matchMedia('(prefers-reduced-motion: reduce)').matches))fogMotion.move(cursor.x,h-cursor.y,Date.now()/1000,w,h);
  else fogMotion.previous=null;
  const previous = new Map(windows.map(win => [win.id, win])); windows = data.windows;
  const next = new Map(windows.map(win => [win.id, win]));
  resting = resting.filter(p => {
    const a = previous.get(p.surface), b = next.get(p.surface);
    const moved = p.surface !== 'ground' && (!a || !b || a.x !== b.x || a.y !== b.y || a.width !== b.width);
    const covered = b && windows.slice(0, windows.indexOf(b)).some(v => p.x >= v.x && p.x <= v.x + v.width && b.y >= v.y && b.y < v.y + v.height);
    if (moved || covered) { release(p); return false; } return true;
  });
});
api.onPreview(() => { if (state?.settings.enabled && !state.settings.paused && mood) { events = []; eventWait = 35; showEvent(); } });
api.onRainGlassPreview(()=>{if(!state?.settings.paused)glass.preview();});
api.onClear(() => { glass.clear(); beads = []; for (const p of resting) release(p); resting = []; motes = []; });
api.subscribe(renderState); api.state().then(renderState);
function spawn(s) {
  if (mode === 'clouds') { const variant=cloudIndex++%3,level=s.cloudLevels?.[variant]; falling.push({kind:'clouds',x:-500,y:Number.isFinite(level)&&level>=0&&level<=1?h*level:Math.min(150,h*(.08+Math.random()*.08)),vx:4+Math.random()*3,size:(90+Math.random()*50)*Math.min(s.size,1.2),variant,stretch:.85+Math.random()*.25,rotation:0,alpha:.22+Math.random()*.14,tint:'#eeeeee'}); return; }
  const kind = mode === 'storm' ? 'rain' : mode, scale = .6 + Math.random() * .9;
  falling.push({ kind, collectsOnWindows: Math.random() < .15, x: Math.random() * (w + 40) - 20, y: -25, vx: kind === 'rain' ? 0 : (Math.random() - .5) * 20,
    vy: (kind === 'rain' ? 640 * scale : 28 + Math.random() * 40), size: (kind === 'snow' ? 12 : kind === 'leaves' ? 30 : 17) * scale * s.size,
    rotation: kind === 'rain' ? .04 : Math.random() * 6, phase: Math.random() * 6, alpha: kind === 'rain' ? .18 + Math.random() * .24 : .45 + Math.random() * .5,
    tint: kind === 'leaves' ? ['#d59746', '#b96d39', '#dec178'][Math.floor(Math.random() * 3)] : kind === 'petals' ? (Math.random()<.5 ? '#f4bacf' : '#fae5ea') : kind === 'rain' ? '#b2c9dc' : '#f5f8ff' });
}
function showEvent() {
  if (!mood || events.length >= 2) return;
  events.push({ age: 0, duration: 23, asset: mood.edgeAsset, night: mood.light === 'night', tint: mood.tint });
}
function drawEvents(s) {
  for (const event of events) {
    const enter = C.clamp(event.age / 5, 0, 1), leave = C.clamp((event.age - 17) / 6, 0, 1);
    const ease = u => u * u * (3 - 2 * u);
    const visible = ease(enter) * (1 - ease(leave));
    const image = photos[event.asset];
    if (image?.complete && image.naturalWidth) {
      const width = Math.min(520, w * .36), height = width * image.naturalHeight / image.naturalWidth;
      ctx.save(); ctx.globalAlpha = s.strength * visible * (event.night ? .67 : .86);
      ctx.translate(w + width * (.10 + (1-visible)*.82), h * .28);
      ctx.rotate(Math.sin(event.age / 3.2) * .03);
      ctx.drawImage(image, -width, -height/2, width, height); ctx.restore();
    }
    ctx.save(); ctx.globalAlpha = s.strength * visible * .20;
    const x = w + 150 - event.age / 23 * w * .7;
    ctx.translate(x, h * .8); ctx.scale(4, 1);
    const g = ctx.createRadialGradient(0,0,0,0,0,80); g.addColorStop(0,art.rgba(event.tint,.7));g.addColorStop(1,art.rgba(event.tint,0));
    ctx.fillStyle = g; ctx.fillRect(-80,-80,160,160);ctx.restore();
  }
}
function spawnMote() {
  const kind = mood.particle;
  motes.push({ kind, x: w + 100, y: kind === 'gull' ? h * .2 : Math.random() * h * .38,
    age: 0, duration: kind === 'gull' ? 24 : 30, rotation: 0, size: kind === 'gull' ? 92 : 10 + Math.random() * 13,
    tint: kind === 'leaf' ? '#d89a51' : kind === 'olive' ? '#b0c596' : art.rgba(mood.tint, .8) });
}
function makeBolt() {
  function channel(start,end,spread,levels) {
    let points=[start,end];
    for(let level=0;level<levels;level++) {
      const next=[points[0]];
      for(let i=1;i<points.length;i++) {
        const a=points[i-1],b=points[i];
        next.push([Math.max(4,Math.min(w-4,(a[0]+b[0])/2+(Math.random()*2-1)*spread)),(a[1]+b[1])/2],b);
      }
      points=next;spread*=.52;
    }
    return points;
  }
  const start=[w*(.35+Math.random()*.3),0];
  const end=[Math.max(w*.15,Math.min(w*.85,start[0]+w*(Math.random()*.4-.2))),h*.98];
  const points=channel(start,end,w*.09,6),branches=[];
  for(let i=8;i<=48;i+=5) {
    const origin=points[i], side=i%2===0?-1:1;
    const tip=[Math.max(8,Math.min(w-8,origin[0]+side*w*(.12+Math.random()*.23))),Math.min(h-8,origin[1]+h*(.12+Math.random()*.26))];
    const branch=channel(origin,tip,w*.035,4);
    branches.push({points:branch,width:.9,glow:3,alpha:.62});
    for(const j of [5,10]) {
      const twigEnd=[Math.max(4,Math.min(w-4,branch[j][0]+side*w*(.04+Math.random()*.08))),Math.min(h-4,branch[j][1]+h*(.04+Math.random()*.09))];
      branches.push({points:channel(branch[j],twigEnd,w*.012,3),width:.45,glow:1,alpha:.38});
    }
  }
  return {age:0,points,branches};
}
api.onSunlightPreview(() => { if(state && !state.settings.paused) sunlight.preview(); });
api.onLightningPreview(() => {
  const reduced = typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
  if(!state || state.settings.paused || !state.settings.lightning || reduced || time-lastPreview<3) return;
  lastPreview=time; previewBolt=makeBolt(); sounds.strike();
});
function tick(dt) {
  if(typeof matchMedia==='function'&&matchMedia('(prefers-reduced-motion: reduce)').matches)fogMotion.reset();else fogMotion.tick(dt);
  const s = state.settings; time += dt; sunlight.tick(dt); glass.tick(dt);
  if(previewBolt) { previewBolt.age+=dt; if(previewBolt.age>=.65 || !s.lightning) previewBolt=null; }
  const reduced = typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (mode === 'storm' && s.lightning !== false && !reduced) {
    if (bolt) { bolt.age += dt; if (bolt.age >= .65) bolt = null; }
    stormWait -= dt;
    if (stormWait <= 0) {
      stormWait = 12 + Math.random()*12;
      bolt = makeBolt(); sounds.strike();
    }
  } else { bolt = null; stormWait = 8; }
  if (Date.now() - lastClock > 60000) { lastClock = Date.now(); updateMood(); }
  if (mode && mode !== 'sunny' && mode !== 'fog') {
    spawnDebt += dt * (mode === 'clouds' ? .025 : (mode === 'rain' || mode === 'storm') ? 110 : 42) * s.intensity * w / 1440;
    while (spawnDebt >= 1 && falling.length < (mode === 'clouds' ? 7 : 900)) { spawn(s); spawnDebt--; }
    spawnDebt = Math.min(spawnDebt, 4);
  }
  const surfaces = s.onWindows ? windows : [];
  const floor = s.onGround ? (ground || h) - 3 : null;
  const piles = new Map();
  for (const p of resting) { const key = `${p.surface}:${Math.floor(p.x / 9)}`; piles.set(key, (piles.get(key) || 0) + 1); }
  falling = falling.filter(p => {
    if(p.kind === 'clouds'){if(p===cloudDrag?.cloud)return true;p.x+=p.vx*dt*s.speed;return p.x<w+p.size*3;}
    const oldY = p.y;
    if (s.cursor && p.kind !== 'rain' && Math.hypot(p.x - cursor.x, p.y - cursor.y) < 65) p.vx += Math.sign(p.x - cursor.x) * 110 * dt;
    p.x += (p.vx + (p.kind === 'rain' ? -24 : Math.sin(time + p.phase) * 14)) * dt * s.speed;
    p.y += p.vy * dt * s.speed; if (p.kind !== 'rain') p.rotation += dt * (p.kind === 'leaves' ? .22 : .35);
    if (p.life !== undefined) { p.life -= dt; p.alpha = Math.min(p.alpha, Math.max(0, p.life / 3)); if (p.life <= 0) return false; }
    if (p.kind === 'rain') {
      const hit = C.landing(p.x, oldY, p.y, surfaces, floor);
      if (hit && Math.random() < .12) {
        const nearby = beads.find(b => b.surface.id === hit.id && Math.abs(b.x-p.x)<8 && b.age<1.5);
        if (nearby) nearby.size=Math.min(5,nearby.size+.5);
        else if(beads.length<100) beads.push({x:p.x,y:hit.y,surface:hit,age:0,size:2.5});
      }
    }
    const surface = p.kind !== 'rain' && p.life === undefined ? C.landing(p.x, oldY, p.y, surfaces, floor) : null;
    if (surface && (surface.id === 'ground' || p.collectsOnWindows)) {
      if (p.kind !== 'rain') {
        const key = `${surface.id}:${Math.floor(p.x / 9)}`;
        if (surface.id !== 'ground' && (piles.get(key) || 0) >= 10) return true;
        const depth = Math.min(24, (piles.get(key) || 0) * 1.6); piles.set(key, (piles.get(key) || 0) + 1);
        p.y = surface.y - depth; p.surface = surface.id; resting.push(p);
      }
      return false;
    }
    return p.y < h + 40 && p.x > -100 && p.x < w + 100;
  });
  resting = resting.filter(p => {
    if ((!s.onGround && p.surface === 'ground') || (!s.onWindows && p.surface !== 'ground') || (s.cursor && Math.hypot(p.x - cursor.x, p.y - cursor.y) < 45)) { release(p); return false; }
    return true;
  });
  beads = beads.filter(b => {
    b.age += dt;
    const current = b.surface.id === 'ground' ? (s.onGround ? {y:floor,x:0,width:w}:null) : surfaces.find(x=>x.id===b.surface.id);
    return (mode==='rain' || mode==='storm') && b.age<4 && current && current.y===b.surface.y && (b.surface.id==='ground' || current.x===b.surface.x);
  });
  if (resting.length > s.drift) resting.splice(0, resting.length - s.drift);
  if (mood) { eventWait -= dt; if(eventWait <= 0) { showEvent(); eventWait = 32 + Math.random()*16; } }
  events = events.filter(e => { e.age += dt; return e.age < e.duration; });
  if (mood && !mood.precipitation) {
    moteWait -= dt;
    if (moteWait <= 0 && motes.length < 10) { spawnMote(); moteWait = mood.particle === 'gull' ? 24 + Math.random() * 21 : 3 + Math.random() * 5; }
  }
  motes = motes.filter(p => { p.age += dt; p.x -= dt * ((w + 200) / p.duration + Math.sin(p.age) * 4); p.y += dt * (p.kind === 'gull' ? 3 + Math.sin(p.age)*3 : h * .5 / 30); if (p.kind !== 'gull') p.rotation += dt * .07; return p.age < p.duration; });
}
function draw() {
  const s = state.settings; ctx.clearRect(0, 0, w, h);
  sunlight.draw(ctx,w,h);
  if(mode==='fog')drawGroundFog(ctx,w,h,state.settings);
  if(s.dragClouds && !s.paused && mode==='clouds'){
    ctx.save();ctx.globalAlpha=1;ctx.fillStyle='rgba(255,255,255,0.004)';
    for(const p of falling){ctx.beginPath();ctx.ellipse(p.x,p.y,p.size*(p.variant===1?2:3)*p.stretch*.42,p.size*.34,0,0,Math.PI*2);ctx.fill();}
    ctx.restore();
  }
  if (false && mood) { ctx.globalAlpha = s.strength * (.82 + Math.sin(time / 14) * .17); ctx.drawImage(background, 0, 0); ctx.globalAlpha = s.strength;
    for (const p of motes) {
      const alpha = .72 * Math.min(1, p.age / 3, (p.duration - p.age) / 4);
      if (p.kind === 'gull' && photos.gull.complete && photos.gull.naturalWidth) {
        ctx.save();ctx.globalAlpha *= alpha;ctx.drawImage(photos.gull,p.x-p.size/2,p.y-p.size/4,p.size,p.size*photos.gull.naturalHeight/photos.gull.naturalWidth);ctx.restore();
      } else art.particle(ctx,p.kind,p.x,p.y,p.size,p.rotation,p.tint,alpha);
    }
    drawEvents(s);
  }
  ctx.globalAlpha = s.opacity;
  for (const p of resting) art.particle(ctx, p.kind, p.x, p.y, p.size, p.rotation, p.tint, p.alpha, p.variant, p.stretch);
  for (const p of falling) art.particle(ctx, p.kind, p.x, p.y, p.size, p.rotation, p.tint, p.alpha, p.variant, p.stretch);
  for (const b of beads) {
    const slide=Math.max(0,b.age-1.5);
    ctx.globalAlpha=s.opacity*Math.min(1,(4-b.age)/1.5)*.6;
    ctx.fillStyle='#b0d0e5';ctx.beginPath();ctx.ellipse(b.x,b.y+slide*slide*10,b.size,1.3+slide,0,0,Math.PI*2);ctx.fill();
  }
  for (const flash of [bolt,previewBolt]) {
  if (flash && !s.paused && s.lightning !== false) {
    ctx.save();
    for(const part of [{points:flash.points,width:2.4,glow:9,alpha:1},...flash.branches]) {
      ctx.globalAlpha=s.opacity*.9*Math.exp(-flash.age*7)*part.alpha;
      ctx.strokeStyle='#ffffff';ctx.lineWidth=part.width;ctx.lineJoin='round';ctx.lineCap='round';ctx.shadowColor='#ffffff';ctx.shadowBlur=part.glow;
      ctx.beginPath();part.points.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.stroke();
    }
    ctx.restore();
  }
  }
  ctx.globalAlpha = 1; glass.draw(ctx);
}
function frame(now) {
  requestAnimationFrame(frame);
  if (!state) { lastFrame = now; return; }
  const dt = lastFrame ? Math.min(.05, Math.max(0, (now - lastFrame) / 1000)) : 0; lastFrame = now;
  if (!state.settings.paused) tick(dt);
  cloudHitMode();
  draw();
}
addEventListener('resize', resize); resize(); requestAnimationFrame(frame);

// Only the trusted local overlay receives screen pixels. At most one request/decode in flight.

function clearRefraction(){refractionEpoch++;glass.setDesktop(null);}
setInterval(async()=>{
 const allowed=state?.settings.rainRefraction&&!state.settings.paused&&glass.active&&glass.drops.length>0;
 if(!allowed){clearRefraction();return;}
 if(refractionPending||!api.captureRefraction)return;
 refractionPending=true;const epoch=refractionEpoch;
 try{
  const data=await api.captureRefraction();
  if(!data){glass.setDesktop(null);return;}
  const image=new Image();image.src=data;await image.decode();
  if(epoch===refractionEpoch&&state?.settings.rainRefraction&&!state.settings.paused&&glass.active&&glass.drops.length)glass.setDesktop(image);
 }catch{glass.setDesktop(null);}finally{refractionPending=false;}
},250);

function drawGroundFog(c,width,height,s){
 const t=typeof matchMedia==='function'&&matchMedia('(prefers-reduced-motion: reduce)').matches?0:time;
 const band=Math.min(height*.28,230*Math.min(1.4,Math.max(.7,s.size)));
 const amount=Math.min(1.8,Math.max(.3,s.intensity));
 for(let i=0;i<6;i++){
  const rx=width*(.9+.13*(i%3))/2,ry=band*(1.7+.13*(i%2))/2;
  const x=width*(.05+i*.18+Math.sin(t*s.speed*.023+i*1.9)*.10)+fogMotion.banks[i].offset;
  const y=height+band*(.12+.10*Math.sin(t*s.speed*.017+i));
  c.save();c.translate(x,y);c.scale(rx,ry);
  c.globalAlpha=s.opacity*amount*(.85+.15*Math.sin(t*s.speed*.019+i))*(1-fogMotion.banks[i].clearing*.9);
  const g=c.createRadialGradient(0,0,0,0,0,1);
  g.addColorStop(0,'rgba(219,224,222,.12)');g.addColorStop(.5,'rgba(219,224,222,.06)');g.addColorStop(1,'rgba(219,224,222,0)');
  c.fillStyle=g;c.fillRect(-1,-1,2,2);c.restore();
 }
}
