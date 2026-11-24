const {test}=require('node:test'),assert=require('node:assert/strict');
const policy=require('../app/overlay-policy.cjs');
function window(){
 const calls=[];let visible=false;
 return {calls,isDestroyed:()=>false,isVisible:()=>visible,showInactive(){visible=true;calls.push('showInactive')},hide(){visible=false;calls.push('hide')},
 setIgnoreMouseEvents:v=>calls.push(['ignore',v]),setContentProtection:v=>calls.push(['capture',v]),
 setFocusable(){throw Error('Overlay must never change focusability')},focus(){throw Error('Overlay must never focus')},show(){throw Error('Only inactive showing is permitted')},setAlwaysOnTop(){throw Error('Never re-raise overlay during polling')}};
}
test('Repeated desktop polls do not raise, refocus or reconfigure unchanged overlays',()=>{
 const w=window();
 for(let i=0;i<100;i++){policy.configure(w,{hideCapture:false,canDrag:false});policy.visibility(w,true);}
 assert.deepEqual(w.calls,[['capture',false],'showInactive']);
 for(let i=0;i<20;i++)policy.visibility(w,false);
 assert.equal(w.calls.filter(c=>c==='hide').length,1);
 policy.visibility(w,true);assert.equal(w.calls.filter(c=>c==='showInactive').length,2);
});
test('Cloud input changes mouse hit testing only, and pause releases it once',()=>{
 const w=window();policy.configure(w,{hideCapture:false,canDrag:true});
 policy.input(w,true);policy.input(w,true);
 assert.deepEqual(w.calls,[['capture',false],['ignore',false]]);
 for(let i=0;i<20;i++)policy.configure(w,{hideCapture:false,canDrag:true});
 assert.equal(w.calls.length,2);
 policy.configure(w,{hideCapture:false,canDrag:false});policy.input(w,true);
 assert.deepEqual(w.calls.at(-1),['ignore',true]);assert.equal(w.calls.length,3);
});

test('Late helper notifications cannot touch destroyed windows',()=>{
 const w=new Proxy({isDestroyed:()=>true},{get(target,key){if(key in target)return target[key];throw Error('Destroyed native object accessed: '+String(key));}});
 for(let i=0;i<10;i++){policy.configure(w,{hideCapture:false,canDrag:true});policy.visibility(w,true);policy.visibility(w,false);policy.input(w,true);}
});
