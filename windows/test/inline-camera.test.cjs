const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const cameras=require('../app/live-cameras.json');
function setup(catalog){
 const views=[],timers=new Set(),messages=[],children=[];
 class WebContentsView {
  constructor(options){this.options=options;this.events={};this.webContents={
   on:(k,f)=>this.events[k]=f,setWindowOpenHandler:f=>this.popup=f,
   loadURL:(url)=>{this.url=url;return Promise.resolve()},isDestroyed:()=>!!this.dead,close:()=>{this.dead=true},reload:()=>{this.reloaded=true}
  };views.push(this);}
  setBorderRadius(r){this.radius=r} setBounds(b){this.bounds=b}
 }
 const win={visible:true,isVisible(){return this.visible},isMinimized:()=>false,isDestroyed:()=>false,getContentSize:()=>[1000,800],webContents:{send:(...args)=>messages.push(args)},contentView:{addChildView:v=>children.push(v),removeChildView:v=>children.splice(children.indexOf(v),1)}};
 const ctx={module:{exports:{}},require:n=>n==='electron'?{WebContentsView,shell:{openExternal:()=>{}}}:cameras,setInterval:f=>{timers.add(f);return f},clearInterval:f=>timers.delete(f)};
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../app/inline-camera.cjs'),'utf8'),ctx);
 return {host:new ctx.module.exports.InlineCamera(win,catalog),win,views,timers,messages,children};
}
test('Inline camera keeps the player during resize, replaces it on city switch and releases it on hide',()=>{
 const {host,win,views,timers,children}=setup(),a=cameras[0].embed,b=cameras[1].embed;
 host.show(a,{x:260,y:160,width:700,height:400});
 host.show(a,{x:20,y:100,width:960,height:640});
 assert.equal(views.length,1);assert.equal(views[0].bounds.width,960);assert.equal(timers.size,1);
 host.show(b,{x:260,y:160,width:700,height:400});
 assert.ok(views[0].dead);assert.equal(children.length,1);assert.equal(timers.size,1);
 win.visible=false;host.show(b,{x:0,y:0,width:100,height:100});
 assert.ok(views[1].dead);assert.equal(children.length,0);assert.equal(timers.size,0);
 win.visible=true;host.show(b,{x:260,y:160,width:700,height:400});assert.equal(views.length,3);host.clear();assert.equal(timers.size,0);
});
test('Inline remote view is isolated, accepts only catalog URLs and returns Escape to dashboard',()=>{
 const {host,views,messages}=setup();
 assert.throws(()=>host.show('https://evil.example',{x:0,y:0,width:10,height:10}));
 assert.throws(()=>host.show(cameras[0].embed,{x:NaN,y:0,width:10,height:10}));assert.equal(views.length,0);
 host.show(cameras[0].embed,{x:20,y:100,width:99999,height:99999});
 const v=views[0];assert.equal(v.options.webPreferences.sandbox,true);assert.equal(v.options.webPreferences.nodeIntegration,false);assert.equal(v.options.webPreferences.preload,undefined);
 assert.equal(v.bounds.width,980);assert.equal(v.bounds.height,700);
 let prevented=false;v.events['before-input-event']({preventDefault:()=>prevented=true},{type:'keyDown',key:'Escape'});
 assert.ok(prevented);assert.ok(messages.some(m=>m[0]==='camera-collapse'));host.clear();
});

test('Saved and preview cameras are allowed only while present in the trusted catalog',()=>{
 let entries=[{embed:'https://www.youtube.com/embed/Y4G5H53X7Tw?autoplay=1&mute=1&playsinline=1'}];
 const {host,views}=setup(()=>entries),key=entries[0].embed,bounds={x:0,y:0,width:600,height:340};
 host.show(key,bounds);assert.equal(views.length,1);
 entries=[];assert.throws(()=>host.show(key,bounds));host.clear();assert.ok(views[0].dead);
});
test('Playback labels distinguish confirmed live, recording, unknown and embed errors',()=>{
 const source=fs.readFileSync(path.join(__dirname,'../app/inline-camera.cjs'),'utf8');
 const script=source.match(/executeJavaScript\("([^"]+)"\)/)[1];
 function read(response,error=''){
  return vm.runInNewContext(script,{document:{
   getElementById:()=>({getPlayerResponse:()=>response}),
   querySelector:s=>s==='video'?{currentTime:10,paused:false,error:null}:{getClientRects:()=>error?[1]:[],textContent:error}
  }});
 }
 assert.equal(read({microformat:{playerMicroformatRenderer:{liveBroadcastDetails:{isLiveNow:true}}}}).type,'Прямой эфир');
 assert.equal(read({microformat:{playerMicroformatRenderer:{liveBroadcastDetails:{isLiveNow:false}}},videoDetails:{isLiveContent:true}}).type,'Запись эфира');
 assert.equal(read({videoDetails:{isLiveContent:false}}).type,'Видео');
 assert.match(read({}).type,/не подтверждён/);
 assert.equal(read({},'Автор запретил встраивание').error,true);
});
