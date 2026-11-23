'use strict';
const api = window.sugrob, C = window.Sugrob, $ = id => document.getElementById(id);
let state, searchToken = 0, cameras = [];
let selectedCamera = null, expanded = false, draftCamera = null, replacingCamera = null;
const cameraChoices = new Map();
let cameraCollapsed = localStorage.getItem('cameraCollapsed') === 'true';
const seasonNames = { winter: 'Зима', spring: 'Весна', summer: 'Лето', autumn: 'Осень' };
const lightNames = { day: 'День', night: 'Ночь', dawn: 'Рассвет', dusk: 'Вечер', whiteNight: 'Белая ночь' };
function error(e) { $('error').textContent = 'Не удалось выполнить действие. Попробуйте ещё раз.'; console.error(e); }
for (const city of C.cities.filter(city => ['moscow', 'rome', 'petersburg', 'tokyo', 'florence', 'athens', 'nizhny', 'newyork', 'yerevan'].includes(city.portrait))) {
  const button = document.createElement('button'); button.textContent = city.name; button.dataset.city = city.portrait;
  button.onclick = () => { showAdvanced(false); api.select(city, true).catch(error); }; $('presets').append(button);
}
for (const [key, value] of Object.entries(C.defaults)) {
  const input = $(key); if (!input || key === 'city') continue;
  input.addEventListener('change', () => {
    const next = input.type === 'checkbox' ? input.checked : typeof value === 'number' ? Number(input.value) : key === 'atmosphere' ? input.value === 'true' : input.value;
    api.update({ [key]: next }).catch(error);
  });
}
function clock() {
  if (!state?.settings.city) { $('city-clock').textContent = ''; return; }
  const m = C.mood(state.settings.city);
  $('hero-clock').textContent = `${m.time} · ${state.settings.city.country || ''} · ${seasonNames[m.season]}`;
  $('city-clock').textContent = `${m.time} · ${seasonNames[m.season]} · ${lightNames[m.light]}`;
}
function render(next) {
  if(state?.settings.city?.id!==next.settings.city?.id){draftCamera=null;replacingCamera=null;$('custom-link').value='';$('custom-title').value='';$('custom-message').textContent='';}
  state = next; const s = next.settings;
  cameras=next.cameras||cameras;renderLibrary();
  document.documentElement.dataset.theme = s.theme || "sage";
  for (const key of Object.keys(C.defaults)) {
    const input = $(key); if (!input) continue;
    if (input.type === 'checkbox') input.checked = s[key]; else if (key !== 'city') input.value = String(s[key]);
  }
  $('city-name').textContent = s.city ? [s.city.name, s.city.admin1, s.city.country].filter(Boolean).join(', ') : 'Выбери город или оставь ручной эффект';
  const portrait = s.city && C.portrait(s.city);
  $('hero-city').textContent = s.city?.name || 'Побудем где-нибудь ещё.';
  const options = cameras.filter(c => (c.id === portrait?.portrait || c.id === 'custom:'+s.city?.id) && c.embed);
  const camera = (draftCamera?.id==='custom:'+s.city?.id ? draftCamera : null) || options.find(c => c.embed === cameraChoices.get(String(s.city?.id))) || options[0];
  $('live-card').hidden = !s.city || advanced;
  $('camera-choice').hidden = options.length < 2;
  selectedCamera = camera || null;
  $('camera-viewport').hidden = !camera || cameraCollapsed;
  $('collapse-video').hidden = !camera;
  $('collapse-video').textContent = cameraCollapsed ? 'Показать видео' : 'Свернуть видео';
  $('collapse-video').setAttribute('aria-expanded',String(!cameraCollapsed));
  document.body.classList.toggle('camera-collapsed',cameraCollapsed);
  $('expand-camera').hidden = !camera;
  $('reload-camera').hidden = !camera;
  $('camera-select').replaceChildren();
  for (const c of options) { const option = document.createElement('option'); option.value = c.embed; option.textContent = c.title; $('camera-select').append(option); }
  if (camera) {
    $('camera-select').value = camera.embed;
    $('camera-title').textContent = camera.title; $('camera-provider').textContent = camera.provider;
  } else {
    $('camera-title').textContent = 'Камера внутри приложения пока недоступна';
    $('camera-provider').textContent = ''; $('camera-note').textContent = 'Погода города доступна. Новые ракурсы появятся здесь.';
  }
  $('source-city').disabled = !s.city;
  $('source-city').setAttribute('aria-pressed', String(s.enabled));
  $('source-manual').setAttribute('aria-pressed', String(!s.enabled));
  $('manual-controls').hidden = s.enabled;
  $('manual-mode').value = s.mode;
  $('quick-intensity').value = s.intensity; $('quick-speed').value = s.speed;
  $('quick-pause').textContent = s.paused ? 'Продолжить эффекты' : 'Пауза эффектов';
  for (const button of $('presets').children) button.setAttribute('aria-pressed', String(button.dataset.city === portrait?.portrait));
  $('city-detail').textContent = s.city ? 'Погода выбранного города на рабочем столе.' : '';
  $('atmosphere').disabled = !s.city;
  $('strength').disabled = !s.enabled || !s.atmosphere; $('mode').disabled = s.enabled;
  $('test-sunlight').disabled = s.paused;
  $('test-lightning').disabled = s.paused || !s.lightning || matchMedia('(prefers-reduced-motion: reduce)').matches;
  $('preview').disabled = !s.enabled || !s.atmosphere || s.paused;
  const hasSound = s.city && C.mood(s.city).soundAsset;
  $('sound-controls').hidden = false;
  const weatherSound = s.soundSource === 'weather';
  $('volume').parentElement.hidden = weatherSound;
  $('weather-volume-label').hidden = !weatherSound;
  const track = C.soundTrack(s,next.weather.current);
  $('sound-note').textContent = weatherSound ? (track ? 'Дождь непрерывен · гром через 0,8–1,8 с после молнии.' : 'Для этой погоды звука пока нет — тишина.') : (hasSound ? 'Запись города, не прямая трансляция.' : 'Для этого города записи пока нет.');
  $('atmosphere').parentElement.hidden = !hasSound;
  $('florence-choice').hidden = portrait?.portrait !== 'florence' || !s.sound || weatherSound;
  $('volume').disabled = !s.sound;
  $('refresh').disabled = !s.enabled || next.weather.loading;
  const w = next.weather;
  $('weather').textContent = !s.enabled ? 'Ручной эффект включён.' : w.error || (w.current ? `${s.city?.id === -2 ? "Район Ватикана · " : ""}${C.currentDescription(w.current)}, ${Math.round(w.current.temperature_2m)} °C · обновлено ${new Date(w.updatedAt).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}${w.loading ? ' · обновляем…' : ''}` : 'Загружаем погоду…');
  $('window-status').textContent = next.windowStatus;
  $('error').textContent = next.persistenceError || '';
  clock(); syncCamera();
}
$('query').addEventListener('input', () => { searchToken++; $('results').replaceChildren(); $('search-status').textContent = ''; $('search').disabled = false; });
$('search-form').onsubmit = async event => {
  event.preventDefault(); const token = ++searchToken; $('search').disabled = true; $('results').replaceChildren(); $('search-status').textContent = 'Ищем город…';
  try {
    const result = await api.search($('query').value);
    if (token !== searchToken) return;
    $('search-status').textContent = result.error || (result.cities.length ? 'Выбери подходящий город:' : 'Город не найден. Попробуй другое название.');
    for (const city of result.cities || []) {
      const b = document.createElement('button'); b.textContent = [city.name, city.admin1, city.country].filter(Boolean).join(', ');
      b.onclick = async () => { try { await api.select(C.portrait(city)||city, state.settings.atmosphere); $('results').replaceChildren(); $('search-status').textContent = ''; $('custom-camera').scrollIntoView({block:'center'}); } catch (e) { error(e); } };
      $('results').append(b);
    }
  } catch (e) { if (token === searchToken) error(e); }
  finally { if (token === searchToken) $('search').disabled = false; }
};
$('reset-clouds').onclick = () => api.resetClouds().catch(error);
$('test-sunlight').onclick = () => api.previewSunlight().catch(error);
$('test-lightning').onclick = () => api.previewLightning().catch(error);
$('preview').onclick = () => api.preview().catch(error);
$('refresh').onclick = () => api.refresh().catch(error);
$('clear').onclick = () => api.clear().catch(error);
$('hide-to-tray').onclick = () => api.hideToTray().catch(error);
$('quit').onclick = () => api.quit().catch(error);
api.subscribe(render); api.state().then(render).catch(error); setInterval(clock, 60000);

api.cameras().then(value => { cameras = value; if (state) render(state); }).catch(error);
let advanced = false;
function showAdvanced(value) { advanced = value; for (const section of document.querySelectorAll('.advanced')) section.hidden = !advanced; $('city-section').hidden = advanced; $('custom-camera').hidden=advanced; $('settings-tab').textContent = advanced ? '← Вернуться к городу' : 'Эффекты и настройки'; $('live-card').hidden = advanced || !state?.settings.city; setExpanded(false); syncCamera(); }
$('settings-tab').onclick = () => showAdvanced(!advanced);

$('source-city').onclick = () => api.update({enabled:true}).catch(error);
$('source-manual').onclick = () => api.update({enabled:false}).catch(error);
$('manual-mode').onchange = () => api.update({mode:$('manual-mode').value}).catch(error);
$('quick-intensity').onchange = () => api.update({intensity:Number($('quick-intensity').value)}).catch(error);
$('quick-speed').onchange = () => api.update({speed:Number($('quick-speed').value)}).catch(error);
$('quick-pause').onclick = () => api.update({paused:!state.settings.paused}).catch(error);
$('camera-select').onchange = () => { const portrait = C.portrait(state.settings.city); cameraChoices.set(String(state.settings.city.id), $('camera-select').value); render(state); };

let cameraFrame;
function syncCamera() {
  cancelAnimationFrame(cameraFrame);
  cameraFrame = requestAnimationFrame(() => {
    if (!selectedCamera || cameraCollapsed || advanced || document.hidden) { api.cameraLayout(null).catch(error); return; }
    const r = $('camera-viewport').getBoundingClientRect();
    api.cameraLayout(selectedCamera.embed,{x:r.x,y:r.y,width:r.width,height:r.height}).catch(error);
  });
}
function setExpanded(value) {
  if (value && cameraCollapsed) { cameraCollapsed = false; localStorage.setItem('cameraCollapsed','false'); render(state); }
  expanded = value;
  document.body.classList.toggle('camera-expanded',value);
  $('expand-camera').textContent = value ? '↙' : '⛶';
  $('expand-camera').setAttribute('aria-label',value ? 'Вернуться к городу' : 'Развернуть вид');
  syncCamera();
}
$('collapse-video').onclick = () => { setExpanded(false); cameraCollapsed = !cameraCollapsed; localStorage.setItem('cameraCollapsed',String(cameraCollapsed)); render(state); };
$('expand-camera').onclick = () => setExpanded(!expanded);
$('reload-camera').onclick = () => api.cameraReload().catch(error);
document.addEventListener('keydown',e => { if(e.key === 'Escape') setExpanded(false); });
document.addEventListener('visibilitychange',syncCamera);
window.addEventListener('resize',syncCamera);
new ResizeObserver(syncCamera).observe($('camera-viewport'));
api.onCameraStatus(value => { $('camera-note').textContent = value; });
api.onCameraCollapse(() => setExpanded(false));
api.onCameraLayout(syncCamera);

function renderLibrary(){
 $('saved-presets').replaceChildren();
 for(const place of state.places||[]){
  if(C.cities.some(c=>c.id===place.city.id))continue;
  const b=document.createElement('button');b.textContent=[place.city.name,place.city.country].filter(Boolean).join(' · ');
  b.setAttribute('aria-pressed',String(place.city.id===state.settings.city?.id));
  b.onclick=()=>{draftCamera=null;replacingCamera=null;showAdvanced(false);api.select(place.city,true).catch(error);};
  $('saved-presets').append(b);
 }
 const city=state.settings.city,place=(state.places||[]).find(p=>p.city.id===city?.id);
 $('custom-cancel').hidden=!draftCamera;
 $('custom-save').disabled=!city;$('custom-preview').disabled=!city;$('custom-delete').hidden=!place;
 $('custom-list').replaceChildren();
 for(const c of place?.cameras||[]){
  const row=document.createElement('div'),label=document.createElement('span'),edit=document.createElement('button'),remove=document.createElement('button');
  label.textContent=c.title;edit.textContent='Изменить';remove.textContent='Удалить';
  edit.onclick=()=>{$('custom-link').value=c.watch;$('custom-title').value=c.title;replacingCamera=c.embed;draftCamera=null;};
  remove.onclick=async()=>{try{await api.library('remove-camera',{city,key:c.embed});draftCamera=null;replacingCamera=null;render(await api.state());}catch(e){$('custom-message').textContent=e.message;}};
  row.append(label,edit,remove);$('custom-list').append(row);
 }
}
$('add-city').onclick=()=>{showAdvanced(false);$('city-section').querySelector('details').open=true;$('query').focus();$('city-section').scrollIntoView({block:'center'});};
$('custom-preview').onclick=async()=>{
 try{draftCamera=await api.library('preview',{city:state.settings.city,link:$('custom-link').value,title:$('custom-title').value});cameraCollapsed=false;render(await api.state());$('live-card').scrollIntoView({block:'start'});$('custom-message').textContent='Предпросмотр открыт выше. Если автор запретил встраивание, плеер сообщит об этом.';}
 catch(e){$('custom-message').textContent=e.message;}
};
$('custom-save').onclick=async()=>{
 try{await api.library('save',{city:state.settings.city,link:$('custom-link').value,title:$('custom-title').value,replacing:replacingCamera});draftCamera=null;replacingCamera=null;$('custom-link').value='';$('custom-title').value='';$('custom-message').textContent='Сохранено';render(await api.state());}
 catch(e){$('custom-message').textContent=e.message;}
};
$('custom-cancel').onclick=async()=>{draftCamera=null;await api.library('clear-preview',{city:state.settings.city});render(await api.state());};
$('custom-delete').onclick=async()=>{try{await api.library('remove-city',{city:state.settings.city});draftCamera=null;replacingCamera=null;render(await api.state());}catch(e){$('custom-message').textContent=e.message;}};
$('custom-link').oninput=()=>{draftCamera=null;if(state)render(state);};
