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
