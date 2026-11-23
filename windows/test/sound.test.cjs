const {test}=require('node:test');const assert=require('node:assert/strict');const vm=require('node:vm');const fs=require('node:fs');const path=require('node:path');
test('Audio is silent by default, fades, reuses the loop, and stops when disabled',()=>{
 let now=0;let next=0;const timers=new Map(), created=[];
 class Audio { constructor(src){this.src=src;this.volume=0;this.paused=true;created.push(this);}play(){this.paused=false;return Promise.resolve();}pause(){this.paused=true;} }
 const context={window:{},Audio,Date:{now:()=>now},setInterval:fn=>{timers.set(++next,fn);return next;},clearInterval:id=>timers.delete(id)};
 vm.createContext(context);vm.runInContext(fs.readFileSync(path.join(__dirname,'../app/sound.js'),'utf8'),context);
 const sound=new context.window.Soundscape();sound.sync(false,'tokyo-street',.25);assert.equal(created.length,0);
 sound.sync(true,'rome-pantheon',.4);assert.equal(created.length,1);assert.equal(created[0].volume,0);assert.equal(created[0].loop,true);
 now=1000;for(const fn of [...timers.values()])fn();assert.equal(created[0].volume,.2);
 sound.sync(true,'rome-pantheon',.6);assert.equal(created.length,1);
 assert.equal(created[0].src,'assets/rome-pantheon.mp3');
 sound.sync(true,null,.6);now=2000;for(const fn of [...timers.values()])fn();assert.equal(created[0].paused,true);assert.equal(created[0].volume,0);
});

test('Thunder follows strikes with delay, one shot, and cancels on pause or source change',()=>{
 let next=0;const pending=new Map(),created=[];
 class Audio {constructor(src){this.src=src;this.volume=0;this.paused=true;this.loop=false;created.push(this);}play(){this.paused=false;return Promise.resolve();}pause(){this.paused=true;}}
 const context={window:{},Audio,Date,Math,setInterval:()=>++next,clearInterval(){},setTimeout:(fn,delay)=>{assert.ok(delay>=800&&delay<=1800);pending.set(++next,fn);return next;},clearTimeout:id=>pending.delete(id)};
 vm.createContext(context);vm.runInContext(fs.readFileSync(path.join(__dirname,'../app/sound.js'),'utf8'),context);
 const sound=new context.window.Soundscape();
 sound.sync(true,'weather-rain',.4,true,'storm');assert.equal(created.length,1);
 sound.strike();sound.strike();assert.equal(pending.size,1);assert.equal(created.length,1);
 const [id,fn]=[...pending][0];pending.delete(id);fn();assert.equal(created[1].src,'assets/weather-thunder.mp3');assert.equal(created[1].loop,false);assert.equal(created[1].volume,.2);
 sound.strike();sound.sync(false,null,.4,true,'storm');assert.equal(pending.size,0);assert.equal(created[1].paused,true);
 sound.sync(true,'weather-rain',.4,true,'storm');sound.strike();sound.sync(true,'rome-pantheon',.4,false,'storm');assert.equal(pending.size,0);
 sound.strike();assert.equal(pending.size,0);
 sound.sync(true,null,.4,true,null);sound.strike();assert.equal(pending.size,1);
 sound.sync(true,'weather-rain',.4,true,'rain');assert.equal(pending.size,0);
});
