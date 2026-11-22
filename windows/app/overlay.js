'use strict';
const C = window.Sugrob, art = window.SugrobArt, api = window.sugrob;
const canvas = document.getElementById('scene'), ctx = canvas.getContext('2d');
const background = document.createElement('canvas'), bg = background.getContext('2d');
let w = 1, h = 1, dpr = 1, state, mode = 'snow', mood, moodKey = '', modeKey = '', ground = 0;
let beads = [];
let falling = [], resting = [], motes = [], windows = [], cursor = { x: -1000, y: -1000 };
const sounds = new window.Soundscape();
const photos = Object.fromEntries(['autumn','olive','pine','maple','cherry','gull'].map(name => { const image = new Image(); image.src = `assets/${name}.png`; return [name, image]; }));
let events = [], eventWait = 1;
let lastFrame = 0, spawnDebt = 0, moteWait = 2, time = 0, lastClock = 0;
function resize() {
  w = innerWidth; h = innerHeight; dpr = Math.min(devicePixelRatio || 1, 2);
  canvas.width = Math.ceil(w * dpr); canvas.height = Math.ceil(h * dpr); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  background.width = w; background.height = h; moodKey = ''; resting = []; updateMood();
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
  mode = s.enabled ? C.currentEffect(next.weather.current) : s.mode;
  const key = String(mode);
  if (key !== modeKey) { beads = []; falling = []; resting = []; spawnDebt = 0; modeKey = key; }
  updateMood();
  sounds.sync(next.audioLeader && s.atmosphere && s.sound && !s.paused, mood?.profile === 'florence' && s.florenceBells ? 'florence-bells' : mood?.soundAsset, s.volume);
}
function release(p) { p.surface = null; p.vx = (Math.random() - .5) * 85; p.vy = 22; p.life = 3; falling.push(p); }
api.onEnvironment(data => {
  cursor = data.cursor; ground = data.ground;
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
api.onClear(() => { beads = []; for (const p of resting) release(p); resting = []; motes = []; });
api.subscribe(renderState); api.state().then(renderState);
function spawn(s) {
  const kind = mode, scale = .6 + Math.random() * .9;
  falling.push({ kind, collectsOnWindows: Math.random() < .15, x: Math.random() * (w + 40) - 20, y: -25, vx: kind === 'rain' ? 0 : (Math.random() - .5) * 20,
    vy: (kind === 'rain' ? 640 * scale : 28 + Math.random() * 40), size: (kind === 'snow' ? 12 : 17) * scale * s.size,
    rotation: kind === 'rain' ? .04 : Math.random() * 6, phase: Math.random() * 6, alpha: kind === 'rain' ? .18 + Math.random() * .24 : .45 + Math.random() * .5,
    tint: kind === 'leaves' ? ['#d59746', '#b96d39', '#dec178'][Math.floor(Math.random() * 3)] : kind === 'petals' ? '#f4bacf' : kind === 'rain' ? '#b2c9dc' : '#f5f8ff' });
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
function tick(dt) {
  const s = state.settings; time += dt;
  if (Date.now() - lastClock > 60000) { lastClock = Date.now(); updateMood(); }
  if (mode) {
    spawnDebt += dt * (mode === 'rain' ? 110 : 42) * s.intensity * w / 1440;
    while (spawnDebt >= 1 && falling.length < 900) { spawn(s); spawnDebt--; }
    spawnDebt = Math.min(spawnDebt, 4);
  }
  const surfaces = s.onWindows ? windows : [];
  const floor = s.onGround ? (ground || h) - 3 : null;
  const piles = new Map();
  for (const p of resting) { const key = `${p.surface}:${Math.floor(p.x / 9)}`; piles.set(key, (piles.get(key) || 0) + 1); }
  falling = falling.filter(p => {
    const oldY = p.y;
    if (s.cursor && p.kind !== 'rain' && Math.hypot(p.x - cursor.x, p.y - cursor.y) < 65) p.vx += Math.sign(p.x - cursor.x) * 110 * dt;
    p.x += (p.vx + (p.kind === 'rain' ? -24 : Math.sin(time + p.phase) * 14)) * dt * s.speed;
    p.y += p.vy * dt * s.speed; if (p.kind !== 'rain') p.rotation += dt * .35;
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
    return mode==='rain' && b.age<4 && current && current.y===b.surface.y && (b.surface.id==='ground' || current.x===b.surface.x);
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
  for (const p of resting) art.particle(ctx, p.kind, p.x, p.y, p.size, p.rotation, p.tint, p.alpha);
  for (const p of falling) art.particle(ctx, p.kind, p.x, p.y, p.size, p.rotation, p.tint, p.alpha);
  for (const b of beads) {
    const slide=Math.max(0,b.age-1.5);
    ctx.globalAlpha=s.opacity*Math.min(1,(4-b.age)/1.5)*.6;
    ctx.fillStyle='#b0d0e5';ctx.beginPath();ctx.ellipse(b.x,b.y+slide*slide*10,b.size,1.3+slide,0,0,Math.PI*2);ctx.fill();
  }
  ctx.globalAlpha = 1;
}
function frame(now) {
  requestAnimationFrame(frame);
  if (!state) { lastFrame = now; return; }
  const dt = lastFrame ? Math.min(.05, Math.max(0, (now - lastFrame) / 1000)) : 0; lastFrame = now;
  if (!state.settings.paused) tick(dt);
  draw();
}
addEventListener('resize', resize); resize(); requestAnimationFrame(frame);
