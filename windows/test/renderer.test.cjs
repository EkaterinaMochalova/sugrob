const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const C = require('../app/core.js');
function renderer() {
  let environment, clear, preview, lightningPreview;
  const drawing = new Proxy({}, { get(target, prop) {
    if (prop in target) return target[prop];
    if (String(prop).startsWith('create')) return () => ({ addColorStop() {} });
    return (...args) => { for (const value of args) if (typeof value === 'number') assert.ok(Number.isFinite(value), `Non-finite ${String(prop)} coordinate`); };
  }, set(target, prop, value) { target[prop] = value; return true; } });
  const canvas = () => ({ getContext: () => drawing });
  const initial = { settings: C.normalize(), weather: { current: null } };
  const context = { document: { getElementById: canvas, createElement: canvas }, innerWidth: 1920, innerHeight: 1080,
    Soundscape: class { sync() {} strike() {} }, Image: class { complete = true; naturalWidth = 1536; naturalHeight = 1024; },
    devicePixelRatio: 1.5, addEventListener() {}, requestAnimationFrame() {}, console,
    sugrob: { onLightningPreview(fn) { lightningPreview = fn; }, onPreview(fn) { preview = fn; }, onEnvironment(fn) { environment = fn; }, onClear(fn) { clear = fn; }, subscribe() {}, state: async () => initial } };
  context.window = context; vm.createContext(context);
  for (const file of ['core.js', 'art.js', 'overlay.js']) vm.runInContext(fs.readFileSync(path.join(__dirname, '../app', file), 'utf8'), context, { filename: file });
  return { run: source => vm.runInContext(source, context), environment: data => environment(data), clear: () => clear(), preview: () => preview(), lightningPreview: () => lightningPreview() };
}
test('Canvas renderer handles all portraits and weather modes with bounded particle counts', () => {
  const r = renderer();
  for (const city of C.cities) {
    r.run(`renderState(${JSON.stringify({ settings: C.normalize({ enabled: true, city, atmosphere: true }), weather: { current: { weather_code: 0 } } })})`);
    r.run('for (let i=0;i<2000;i++) { tick(.04); draw(); }');
    assert.ok(r.run('motes.length') <= 10); assert.equal(r.run('falling.length'), 0);
  }
  for (const mode of ['snow', 'rain', 'leaves', 'petals']) {
    r.run(`renderState(${JSON.stringify({ settings: C.normalize({ mode, drift: 300 }), weather: { current: null } })})`);
    r.environment({ cursor: { x: -100, y: -100 }, ground: 500, windows: [{ id: 'a', x: 0, y: 200, width: 1600, height: 200 }] });
    r.run('for (let i=0;i<1500;i++) { tick(.04); draw(); }');
    assert.ok(r.run('falling.length') <= 900); assert.ok(r.run('resting.length') <= 300);
    if (mode === 'rain') assert.equal(r.run('resting.length'), 0);
    else assert.ok(r.run('resting.length') > 0);
    r.environment({ cursor: { x: -100, y: -100 }, ground: 500, windows: [] });
    assert.equal(r.run('resting.filter(p=>p.surface==="a").length'), 0);
  }
});
test('Pause freezes particles; clear removes accumulation; exact clear weather is empty', () => {
  const r = renderer();
  r.run(`renderState(${JSON.stringify({ settings: C.normalize({ paused: false }), weather: { current: null } })})`);
  r.run('for(let i=0;i<300;i++) frame(i*40)');
  const before = r.run('JSON.stringify(falling)');
  r.run('state.settings.paused=true; for(let i=300;i<600;i++) frame(i*40)');
  assert.equal(r.run('JSON.stringify(falling)'), before);
  r.clear(); assert.equal(r.run('resting.length'), 0);
  r.run(`renderState(${JSON.stringify({ settings: C.normalize({ enabled: true, city: C.cities[0], atmosphere: false }), weather: { current: { weather_code: 0 } } })})`);
  r.run('for(let i=0;i<100;i++) tick(.04)');
  assert.equal(r.run('falling.length + resting.length + motes.length'), 0);
  assert.equal(r.run('mood'), null);
});

test('Preview schedules an edge event and pause suppresses it', () => {
  const r = renderer();
  r.run(`renderState(${JSON.stringify({settings:C.normalize({enabled:true,city:C.cities[2],atmosphere:true}),weather:{current:null}})})`);
  r.preview(); assert.equal(r.run('events.length'), 1);
  r.run('for(let i=0;i<30;i++){tick(.04);draw();}');
  assert.ok(r.run('events[0].age') > 0);
  r.run('state.settings.paused=true;events=[]');r.preview();assert.equal(r.run('events.length'),0);
});

test('Rain crosses window tops and the dock without landing, then exits the screen', () => {
  const r = renderer();
  r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'rain',cursor:false,onWindows:true,onGround:true}),weather:{current:null}})})`);
  r.environment({cursor:{x:-100,y:-100},ground:500,windows:[{id:'a',x:0,y:200,width:1920,height:800}]});
  r.run("falling=[{kind:'rain',x:600,y:190,vx:0,vy:580,phase:0,alpha:1}]; spawnDebt=0; state.settings.intensity=0; tick(.04)");
  assert.equal(r.run('falling.length'),1);
  assert.ok(r.run('falling[0].y')>200);
  r.run('for(let i=0;i<20;i++)tick(.04)');
  assert.equal(r.run('falling.length'),1);
  assert.ok(r.run('falling[0].y')>500);
  assert.equal(r.run('resting.length'),0);
  r.run('for(let i=0;i<40;i++)tick(.04)');
  assert.equal(r.run('falling.length'),0);
});

test('Rain beads stay bounded, slide and disappear; clearing removes them',()=>{
 const r=renderer();
 r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'rain',cursor:false,onWindows:true}),weather:{current:null}})})`);
 r.environment({cursor:{x:-100,y:-100},ground:1000,windows:[{id:'a',x:0,y:200,width:1920,height:500}]});
 r.run("beads=[{x:400,y:200,surface:{id:'a',x:0,y:200},age:0,size:2.5}];state.settings.intensity=0;falling=[];for(let i=0;i<50;i++)tick(.04)");
 assert.equal(r.run('beads.length'),1);assert.ok(r.run('beads[0].age')>1.5);
 r.run('for(let i=0;i<60;i++)tick(.04)');assert.equal(r.run('beads.length'),0);
 r.run("beads=[{x:400,y:200,surface:{id:'a',x:0,y:200},age:0,size:2.5}]");r.clear();assert.equal(r.run('beads.length'),0);
});

test('Rain stays aligned and switching source preserves the same rain particles', () => {
 const r=renderer(); const city=C.cities.find(c=>c.portrait==='rome');
 r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'rain',cursor:false}),weather:{current:null}})})`);
 r.run('for(let i=0;i<15;i++)tick(.016)');
 assert.ok(r.run('falling.length')>0);
 assert.ok(r.run('falling.every(p=>p.rotation===.04 && p.vx===0)'));
 const before=r.run('JSON.stringify(falling)');
 r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'rain',enabled:true,city,cursor:false}),weather:{current:{weather_code:61,precipitation:0.1}}})})`);
 assert.equal(r.run('JSON.stringify(falling)'),before);
 r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'snow'}),weather:{current:null}})})`);
 assert.equal(r.run('falling.length'),0);
});
test('Animation advances on every display frame, including 120 Hz', () => {
 const r=renderer();r.run(`renderState(${JSON.stringify({settings:C.normalize(),weather:{current:null}})})`);r.run('frame(1000)');const before=r.run('time');
 r.run('frame(1000+1000/120)');assert.ok(r.run('time')>before);
});

test('Foreground snow crosses window edges while background snow collects', () => {
 const r=renderer();
 r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'snow',cursor:false}),weather:{current:null}})})`);
 r.environment({cursor:{x:-100,y:-100},ground:900,windows:[{id:'a',x:0,y:200,width:1920,height:700}]});
 r.run("falling=[false,true].map(collectsOnWindows=>({kind:'snow',collectsOnWindows,x:600,y:199,vx:0,vy:80,phase:0,alpha:1,rotation:0}));state.settings.intensity=0;tick(.04)");
 assert.equal(r.run('falling.length'),1);
 assert.ok(r.run('falling[0].y')>200);
 assert.equal(r.run('resting.length'),1);
});

test('Petals pass in front of windows while a small background layer settles', () => {
 const r=renderer();
 r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'petals',cursor:false}),weather:{current:null}})})`);
 r.environment({cursor:{x:-100,y:-100},ground:900,windows:[{id:'a',x:0,y:200,width:1920,height:700}]});
 r.run("falling=[false,true].map(collectsOnWindows=>({kind:'petals',collectsOnWindows,x:600,y:199,vx:0,vy:80,phase:0,alpha:1,rotation:0}));state.settings.intensity=0;tick(.04)");
 assert.equal(r.run('falling.length'),1);
 assert.ok(r.run('falling[0].y')>200);
 assert.equal(r.run('resting.length'),1);
});
test('Clouds drift horizontally, stay bounded, pause and disappear in clear weather', () => {
 const r=renderer();
 r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'clouds',cursor:true}),weather:{current:null}})})`);
 assert.equal(r.run('falling.length'),5);
 const x=r.run('falling[0].x'),y=r.run('falling[0].y');
 r.run('tick(.04);draw()');
 assert.ok(r.run('falling[0].x')>x);assert.equal(r.run('falling[0].y'),y);
 r.run('for(let i=0;i<10000;i++)tick(.04)');assert.ok(r.run('falling.length')<=8);assert.equal(r.run('resting.length'),0);
 const still=r.run('JSON.stringify(falling)');r.run('state.settings.paused=true;frame(1000);frame(1040)');assert.equal(r.run('JSON.stringify(falling)'),still);
 r.run(`renderState(${JSON.stringify({settings:C.normalize({enabled:true,city:C.cities[0]}),weather:{current:{weather_code:2,precipitation:0}}})})`);
 assert.equal(r.run('mode'),'clouds');
 r.run(`renderState(${JSON.stringify({settings:C.normalize({enabled:true,city:C.cities[0]}),weather:{current:{weather_code:0,precipitation:0}}})})`);
 assert.equal(r.run('falling.length'),0);
});

test('Storm produces rain and a brief bounded bolt, disables flashes and clears on mode change', () => {
 const r = renderer();
 r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'storm'}),weather:{current:null}})})`);
 r.run('stormWait=0; tick(.04); draw()');
 assert.equal(r.run('bolt.points.length'),65);
 assert.ok(r.run('falling.every(p=>p.kind==="rain")'));
 r.run('for(let i=0;i<20;i++)tick(.04)');
 assert.equal(r.run('bolt'),null);
 assert.ok(r.run('stormWait>10'));
 r.run('state.settings.lightning=false; stormWait=0; tick(.04)');
 assert.equal(r.run('bolt'),null);
 r.run('state.settings.lightning=true; stormWait=0; tick(.04); state.settings.paused=true; frame(1); frame(100)');
 assert.equal(r.run('bolt.age'),0);
 r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'clouds'}),weather:{current:null}})})`);
 assert.equal(r.run('bolt'),null);
});

test('Clouds fill the upper band without reaching screen center at maximum size', () => {
 const r = renderer();
 r.run(`renderState(${JSON.stringify({settings:C.normalize({mode:'clouds',size:2.5}),weather:{current:null}})})`);
 assert.equal(r.run('falling.length'),5);
 assert.equal(r.run('new Set(falling.map(p=>p.variant)).size'),3);
 assert.ok(r.run('falling.every(p=>p.y>=Math.min(150,h*.08) && p.y<=Math.min(150,h*.16) && p.size<=168 && p.alpha<=.36)'));
 r.run('for(let i=0;i<2000;i++){tick(.05);draw()}');
 assert.ok(r.run('falling.length<=7 && falling.every(p=>p.y+p.size/2<h*.3)'));
});

test('Lightning button previews once in clear weather without switching source', () => {
 const r=renderer();
 r.run(`renderState(${JSON.stringify({settings:C.normalize({enabled:true,city:C.cities[0]}),weather:{current:{weather_code:0,precipitation:0}}})})`);
 r.lightningPreview(); assert.equal(r.run('previewBolt.points.length'),65); assert.equal(r.run('mode'),null);
 r.run('tick(.1)'); r.lightningPreview(); assert.equal(r.run('previewBolt.age'),.1);
 r.run('for(let i=0;i<15;i++)tick(.05)'); assert.equal(r.run('previewBolt'),null);
 r.run('time+=3; state.settings.paused=true'); r.lightningPreview(); assert.equal(r.run('previewBolt'),null);
 r.run('state.settings.paused=false; state.settings.lightning=false'); r.lightningPreview(); assert.equal(r.run('previewBolt'),null);
});

test('Lightning spans screen height with fine branches and bounded geometry',()=>{
 const r=renderer();
 for(let i=0;i<100;i++) {
  r.run('bolt=makeBolt()');
  assert.ok(r.run('bolt.points[0][1]===0 && bolt.points.at(-1)[1]>=h*.95'));
  assert.equal(r.run('bolt.branches.length'),27);
  assert.ok(r.run('[bolt.points,...bolt.branches.map(b=>b.points)].flat().every(([x,y])=>Number.isFinite(x)&&Number.isFinite(y)&&x>=0&&x<=w&&y>=0&&y<=h)'));
 }
});
