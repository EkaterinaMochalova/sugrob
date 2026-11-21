const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const C=require('../app/core.js');
const folder=path.join(__dirname,'../app/city-media');
function page(id){
 const elements={},timeouts=[];
 function node(){return {style:{},events:{},currentTime:0,duration:20,readyState:4,paused:true,addEventListener(k,fn){this.events[k]=fn},remove(){this.removed=true},play(){this.paused=false;return Promise.resolve()},pause(){this.paused=true}};}
 const ctx={Sugrob:C,URLSearchParams,location:{search:'?city='+id,hash:''},document:{getElementById(id){return elements[id]??=node()},addEventListener(){}},window:{addEventListener(){}},setInterval(){},setTimeout(fn){timeouts.push(fn);return 1},clearTimeout(){}};
 vm.createContext(ctx);vm.runInContext(fs.readFileSync(path.join(folder,'view.js'),'utf8'),ctx);
 return {elements,timeouts,run:s=>vm.runInContext(s,ctx)};
}
test('All available city views resolve bundled media; Petersburg uses a photo',()=>{
 for(const id of ['rome','florence','moscow','tokyo','petersburg','athens']){
  const p=page(id);assert.match(p.elements.clock.textContent,/Авто/);
  const media=id==='petersburg'?p.elements.photo:p.elements.a;
  assert.ok(fs.existsSync(path.join(folder,media.src)));
  if(id==='petersburg'){assert.ok(p.elements.pause.hidden);assert.equal(p.elements.photo.style.display,'block');}
  else{assert.equal(media.paused,false);assert.equal(p.elements.b.src,media.src);}
 }
});
test('Loop crossfades to a second video and pause freezes both players',()=>{
 const p=page('rome');p.elements.a.currentTime=19;p.elements.a.events.timeupdate();
 assert.equal(p.elements.b.paused,false);assert.equal(p.elements.b.style.opacity,'1');
 p.elements.pause.onclick();assert.equal(p.elements.a.paused,true);assert.equal(p.elements.b.paused,true);
 p.timeouts[0]();assert.equal(p.run('active===b'),true);assert.equal(p.elements.b.paused,true);
 p.elements.pause.onclick();assert.equal(p.elements.b.paused,false);
});
test('Lighting follows destination time, including DST, independently of device zone',()=>{
 const rome=C.cities.find(c=>c.portrait==='rome'),tokyo=C.cities.find(c=>c.portrait==='tokyo');
 assert.equal(C.mood(rome,new Date('2026-11-21T22:00:00Z')).time,'23:00');
 assert.equal(C.mood(rome,new Date('2026-07-21T22:00:00Z')).time,'00:00');
 assert.equal(C.mood(tokyo,new Date('2026-11-21T22:00:00Z')).time,'07:00');
 assert.equal(C.mood(rome,new Date('2026-11-21T22:00:00Z')).light,'night');
});
