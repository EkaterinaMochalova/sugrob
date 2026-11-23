'use strict';
const fs = require('node:fs');
const C = require('./core.js');
function videoID(text) {
  try {
    const u = new URL(String(text).trim());
    if(u.protocol !== 'https:' || u.username || u.password || u.port) return null;
    const parts=u.pathname.split('/').filter(Boolean);
    let id;
    if(u.hostname==='youtu.be' && parts.length===1) id=parts[0];
    if(['youtube.com','www.youtube.com','m.youtube.com'].includes(u.hostname)) {
      if(u.pathname==='/watch') id=u.searchParams.get('v');
      else if(parts.length===2 && ['live','embed','shorts'].includes(parts[0])) id=parts[1];
    }
    return /^[\w-]{11}$/.test(id||'') ? id : null;
  } catch { return null; }
}
function camera(text,title,city) {
  const id=videoID(text);
  if(!id) throw new Error('Нужна HTTPS-ссылка на конкретное видео YouTube.');
  const watch='https://www.youtube.com/watch?v='+id;
  return {id:'custom:'+city.id,title:String(title||'').trim().slice(0,120)||'Моя камера',provider:'YouTube · добавлено вами',
    embed:'https://www.youtube.com/embed/'+id+'?autoplay=1&mute=1&playsinline=1',watch,source:watch};
}
class CityLibrary {
  constructor(file) {
    this.file=file;this.places=[];this.preview=null;
    try { this.places=JSON.parse(fs.readFileSync(file,'utf8')).slice(0,200).flatMap(p=>{
      const city=C.validCity(p.city);if(!city)return [];
      return [{city,cameras:(Array.isArray(p.cameras)?p.cameras:[]).slice(0,50).flatMap(c=>{try{return [camera(c.watch,c.title,city)];}catch{return [];}})}];
    }); }catch{}
  }
  get cameras(){return this.places.flatMap(p=>p.cameras);}
  mutate(action,value={}) {
    const city=C.validCity(value.city);if(!city)throw new Error('Сначала выбери город из поиска.');
    if(action==='preview'){this.preview=camera(value.link,value.title,city);return this.preview;}
    if(action==='clear-preview'){this.preview=null;return null;}
    const next=JSON.parse(JSON.stringify(this.places));
    let place=next.find(p=>p.city.id===city.id);
    if(action==='save'){
      const cam=String(value.link||'').trim()?camera(value.link,value.title,city):null;
      if(!place){if(next.length>=200)throw new Error('Список городов заполнен.');place={city,cameras:[]};next.push(place);}
      if(cam){place.cameras=place.cameras.filter(c=>c.embed!==cam.embed && c.embed!==value.replacing);if(place.cameras.length>=50)throw new Error('Слишком много камер.');place.cameras.push(cam);}
    } else if(action==='remove-camera'){if(place)place.cameras=place.cameras.filter(c=>c.embed!==value.key);}
    else if(action==='remove-city'){const i=next.indexOf(place);if(i>=0)next.splice(i,1);}
    else throw new Error('Неизвестное действие');
    fs.writeFileSync(this.file+'.tmp',JSON.stringify(next));fs.renameSync(this.file+'.tmp',this.file);
    this.places=next;this.preview=null;return null;
  }
}
module.exports={CityLibrary,videoID,camera};
