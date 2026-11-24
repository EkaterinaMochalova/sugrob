const {test}=require('node:test'),assert=require('node:assert/strict');
const {FogMotion}=require('../app/fog-motion.js');
test('Fog reacts only to fast lower-screen movement and returns gently',()=>{
 const f=new FogMotion(),move=(x,y,t)=>f.move(x,y,t,1200,800),power=()=>f.banks.reduce((s,b)=>s+b.clearing,0);
 move(100,40,0);move(105,40,.05);assert.equal(power(),0);
 move(205,40,.1);assert.ok(power()>0);f.tick(.05);assert.ok(f.banks.some(b=>b.offset>0));
 for(let i=0;i<400;i++)f.tick(.05);assert.ok(power()<.001);assert.ok(f.banks.every(b=>Math.abs(b.offset)<.01));
 f.reset();move(100,400,0);move(200,400,.05);assert.equal(power(),0);
 f.reset();move(100,40,0);move(200,40,1);assert.equal(power(),0);
 f.reset();move(-100,40,0);move(100,40,.05);assert.equal(power(),0);
 f.reset();move(100,40,0);move(1000,40,.05);assert.equal(power(),0);
});
test('Repeated sweeps remain bounded and reset releases all impulses',()=>{
 const f=new FogMotion();for(let i=0;i<2000;i++){f.move(300+(i%2)*120,40,i*.05,1200,800);f.tick(.05);}
 assert.ok(f.banks.every(b=>Math.abs(b.offset)<=180&&Math.abs(b.velocity)<=240&&b.clearing<=1));
 f.reset();assert.ok(f.banks.every(b=>!b.offset&&!b.velocity&&!b.clearing));assert.equal(f.previous,null);
});
