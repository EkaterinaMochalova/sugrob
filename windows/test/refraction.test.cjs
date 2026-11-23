const {test}=require('node:test');
const assert=require('node:assert/strict');
const {RefractionCapture}=require('../app/refraction.cjs');
const source=id=>({display_id:String(id),thumbnail:{isEmpty:()=>false,toDataURL:()=>`frame-${id}`}});
test('Desktop samples are coalesced, matched to displays and invalidated while in flight',async()=>{
 let count=0,now=1000,resolve;
 const capture=new RefractionCapture({getSources:()=>{count++;return new Promise(r=>resolve=r);}},()=>now);
 const a=capture.get(1),b=capture.get(2);assert.equal(count,1);
 resolve([source(1),source(2)]);assert.equal(await a,'frame-1');assert.equal(await b,'frame-2');
 assert.equal(await capture.get(3),null);assert.equal(count,1);
 now+=250;const pending=capture.get(1);capture.clear();resolve([source(1)]);
 assert.equal(await pending,null);assert.equal(capture.frame,null);
});
test('Denied or failed capture leaves no cached screen data',async()=>{
 const capture=new RefractionCapture({getSources:async()=>{throw Error('denied');}});
 assert.equal(await capture.get(1),null);assert.equal(capture.frame,null);
});
