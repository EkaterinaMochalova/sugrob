const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm'), path = require('node:path');
const cameras = require('../app/live-cameras.json');
test('Desktop platforms share six camera destinations and only official YouTube embeds', () => {
 assert.deepEqual(cameras, JSON.parse(fs.readFileSync(path.join(__dirname,'../../live-cameras.json'))));
 assert.equal(new Set(cameras.map(c=>c.id)).size,6);
 for(const c of cameras) {
  assert.equal(new URL(c.watch).protocol,'https:');
  if(c.embed) {assert.equal(new URL(c.embed).hostname,'www.youtube.com'); assert.match(new URL(c.embed).pathname,/^\/embed\/[\w-]{11}$/);}
 }
});
test('Camera windows reject arbitrary IDs, isolate remote content and release timers on close', async () => {
 const windows=[], opened=[], timers=new Set();
 class Window {
  constructor(options){this.options=options;this.events={};this.webContents={setWindowOpenHandler:f=>this.popup=f,on:(k,f)=>this.events[k]=f};windows.push(this);}
  loadURL(url,options){this.url=url;this.request=options;return Promise.resolve();}
  on(k,f){this.events[k]=f;}
  setMenu(menu){this.menu=menu;}
  isDestroyed(){return !!this.dead;}
  close(){this.dead=true;this.events.closed();}
 }
 const ctx={module:{exports:{}},require:n=>n==='electron'?{BrowserWindow:Window,Menu:{buildFromTemplate:m=>m},shell:{openExternal:u=>opened.push(u)}}:cameras,setInterval:f=>{timers.add(f);return f},clearInterval:f=>timers.delete(f)};
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../app/live-camera.cjs'),'utf8'),ctx);
 const {openCamera}=ctx.module.exports;
 assert.throws(()=>openCamera('https://untrusted.example'));
 openCamera('moscow');assert.equal(windows.length,0);assert.equal(opened[0],cameras.find(c=>c.id==='moscow').watch);
 openCamera('florence');let w=windows[0];assert.equal(w.options.webPreferences.nodeIntegration,false);assert.equal(w.options.webPreferences.sandbox,true);assert.equal(w.options.webPreferences.preload,undefined);
 assert.match(w.request.httpReferrer,/^https:\/\/local\.sugrob/);
 assert.equal(w.popup({url:'file:///etc/passwd'}).action,'deny');assert.equal(opened.length,1);
 openCamera('rome');assert.ok(w.dead);assert.equal(timers.size,1);
 windows[1].close();assert.equal(timers.size,0);
});
