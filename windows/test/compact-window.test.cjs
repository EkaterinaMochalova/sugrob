const {test}=require('node:test');const assert=require('node:assert/strict');const {CompactWindow}=require('../app/compact-window.cjs');
test('Compact mode restores original bounds and maximized state, and repeat clicks do not overwrite them',()=>{
 let bounds={x:40,y:70,width:1100,height:850},maximized=true,min;
 const win={isDestroyed:()=>false,getBounds:()=>({...bounds}),isMaximized:()=>maximized,unmaximize:()=>maximized=false,maximize:()=>maximized=true,setMinimumSize:(...v)=>min=v,setSize:(width,height)=>Object.assign(bounds,{width,height}),setBounds:b=>bounds=b};
 const mode=new CompactWindow();mode.set(win,true);assert.deepEqual(min,[360,320]);assert.equal(bounds.width,540);assert.equal(maximized,false);
 mode.set(win,true);mode.set(win,false);assert.deepEqual(bounds,{x:40,y:70,width:1100,height:850});assert.equal(maximized,true);assert.deepEqual(min,[760,600]);
 mode.set(win,false);assert.equal(bounds.width,1100);
});
