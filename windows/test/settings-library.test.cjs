const {test}=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const C=require('../app/core.js'),{CityLibrary}=require('../app/city-library.cjs');
test('Settings preview, save and delete flow keeps draft out of saved list and displays validation errors',async()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'sugrob-ui-'));
 try{
  const lib=new CityLibrary(path.join(dir,'cities.json'));
  const city={id:123,name:'Лиссабон',latitude:38.72,longitude:-9.14,timezone:'Europe/Lisbon'};
  const snapshot=()=>({settings:C.normalize({city}),weather:{current:null},places:lib.places,cameras:lib.cameras});
  class Element{
   constructor(){this.children=[];this.dataset={};this.style={};this.value='';this.type='text';this.parentElement={};this.classList={toggle(){}};}
   addEventListener(){}setAttribute(){}append(...v){this.children.push(...v)}replaceChildren(...v){this.children=v}
   querySelector(){return new Element()}scrollIntoView(){}focus(){}getBoundingClientRect(){return {x:0,y:0,width:600,height:340}}
  }
  const html=fs.readFileSync(path.join(__dirname,'../app/settings.html'),'utf8'),elements={};
  for(const m of html.matchAll(/id="([^"]+)"/g))elements[m[1]]=new Element();
  const api=new Proxy({state:async()=>snapshot(),cameras:async()=>[],library:async(a,v)=>lib.mutate(a,v)}, {get:(o,k)=>o[k]||(()=>Promise.resolve())});
  const ctx={Sugrob:C,sugrob:api,console,document:{getElementById:id=>elements[id]||null,createElement:()=>new Element(),documentElement:new Element(),body:new Element(),querySelectorAll:()=>[],addEventListener(){}},
   localStorage:{getItem(){return null},setItem(){}},matchMedia:()=>({matches:false}),setInterval(){},requestAnimationFrame(){},cancelAnimationFrame(){},addEventListener(){},ResizeObserver:class{observe(){}}};
  ctx.window=ctx;vm.createContext(ctx);vm.runInContext(fs.readFileSync(path.join(__dirname,'../app/settings.js'),'utf8'),ctx);
  await new Promise(r=>setImmediate(r));
  elements['custom-link'].value='https://evil.test';
  await elements['custom-preview'].onclick();assert.match(elements['custom-message'].textContent,/HTTPS/);assert.equal(lib.places.length,0);
  elements['custom-link'].value='https://youtu.be/Y4G5H53X7Tw';
  elements['custom-title'].value='Набережная';
  await elements['custom-preview'].onclick();assert.equal(lib.places.length,0);assert.equal(elements['camera-title'].textContent,'Набережная');
  await elements['custom-save'].onclick();assert.equal(lib.places.length,1);assert.equal(elements['saved-presets'].children.length,1);assert.equal(elements['camera-title'].textContent,'Набережная');
  await elements['custom-delete'].onclick();assert.equal(lib.places.length,0);assert.equal(elements['saved-presets'].children.length,0);
 }finally{fs.rmSync(dir,{recursive:true});}
});
