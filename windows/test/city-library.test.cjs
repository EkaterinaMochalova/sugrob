const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {CityLibrary,videoID,camera}=require('../app/city-library.cjs');
const city={id:123,name:'Лиссабон',latitude:38.72,longitude:-9.14,country:'Португалия',timezone:'Europe/Lisbon'};
const link='https://www.youtube.com/watch?v=Y4G5H53X7Tw';
test('YouTube links normalize without accepting arbitrary sites, credentials or injected player parameters',()=>{
 for(const u of [link,'https://youtu.be/Y4G5H53X7Tw?t=9','https://youtube.com/live/Y4G5H53X7Tw?si=x']) assert.equal(videoID(u),'Y4G5H53X7Tw');
 for(const u of ['https://youtube.com.evil.test/watch?v=Y4G5H53X7Tw','javascript:alert(1)','file:///tmp/video','https://youtube.com@evil.test/watch?v=Y4G5H53X7Tw','https://user@youtube.com/watch?v=Y4G5H53X7Tw','https://youtube.com/@channel','https://youtube.com/watch?v=bad'])assert.equal(videoID(u),null);
 assert.equal(camera(link+'&origin=https://evil.test','Ракурс',city).embed,'https://www.youtube.com/embed/Y4G5H53X7Tw?autoplay=1&mute=1&playsinline=1');
});
test('Library persists cities without cameras, multiple cameras, edits and deletions; preview never persists',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'sugrob-library-')),file=path.join(dir,'cities.json');
 try {
  let l=new CityLibrary(file);l.mutate('save',{city});assert.equal(new CityLibrary(file).places.length,1);
  l.mutate('preview',{city,link});assert.equal(new CityLibrary(file).cameras.length,0);
  l.mutate('save',{city,link,title:'Один'});l.mutate('save',{city,link:'https://youtu.be/qBtMuRnf7BY',title:'Два'});
  l=new CityLibrary(file);assert.equal(l.cameras.length,2);
  l.mutate('save',{city,link,title:'Новое имя',replacing:l.cameras[0].embed});assert.equal(l.cameras.length,2);
  assert.ok(l.cameras.some(c=>c.title==='Новое имя'));
  l.mutate('remove-camera',{city,key:l.cameras[0].embed});assert.equal(new CityLibrary(file).cameras.length,1);
  assert.throws(()=>l.mutate('save',{city,link:'https://evil.test'}));assert.equal(new CityLibrary(file).cameras.length,1);
  l.mutate('remove-city',{city});assert.equal(new CityLibrary(file).places.length,0);
 }finally{fs.rmSync(dir,{recursive:true});}
});
