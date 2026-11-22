'use strict';
const api = window.sugrob, C = window.Sugrob, $ = id => document.getElementById(id);
let state, searchToken = 0, cameras = [];
const cameraChoices = new Map();
const seasonNames = { winter: 'Зима', spring: 'Весна', summer: 'Лето', autumn: 'Осень' };
const lightNames = { day: 'День', night: 'Ночь', dawn: 'Рассвет', dusk: 'Вечер', whiteNight: 'Белая ночь' };
function error(e) { $('error').textContent = 'Не удалось выполнить действие. Попробуйте ещё раз.'; console.error(e); }
for (const city of C.cities.filter(city => ['moscow', 'rome', 'petersburg', 'tokyo', 'florence', 'athens', 'nizhny', 'newyork'].includes(city.portrait))) {
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
  state = next; const s = next.settings;
  for (const key of Object.keys(C.defaults)) {
    const input = $(key); if (!input) continue;
    if (input.type === 'checkbox') input.checked = s[key]; else if (key !== 'city') input.value = String(s[key]);
  }
  $('city-name').textContent = s.city ? [s.city.name, s.city.admin1, s.city.country].filter(Boolean).join(', ') : 'Выбери город или оставь ручной эффект';
  const portrait = s.city && C.portrait(s.city);
  $('hero-city').textContent = s.city?.name || 'Побудем где-нибудь ещё.';
  const options = cameras.filter(c => c.id === portrait?.portrait && c.embed);
  const camera = options.find(c => c.embed === cameraChoices.get(portrait?.portrait)) || options[0];
  $('live-card').hidden = !s.city;
  $('camera-choice').hidden = options.length < 2;
  $('open-camera').hidden = !camera;
  $('camera-select').replaceChildren();
  for (const c of options) { const option = document.createElement('option'); option.value = c.embed; option.textContent = c.title; $('camera-select').append(option); }
  if (camera) {
    $('camera-select').value = camera.embed;
    $('camera-title').textContent = camera.title; $('camera-provider').textContent = camera.provider;
    $('open-camera').textContent = 'Открыть окно ↗';
    $('open-camera').onclick = () => api.openCamera(camera.embed).catch(error);
    $('camera-note').textContent = 'Настоящий свет и время города. Звук включается в плеере.';
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
  $('preview').disabled = !s.enabled || !s.atmosphere || s.paused;
  const hasSound = s.city && C.mood(s.city).soundAsset;
  $('sound-controls').hidden = !hasSound;
  $('atmosphere').parentElement.hidden = !hasSound;
  $('florence-choice').hidden = portrait?.portrait !== 'florence' || !s.sound;
  $('volume').disabled = !s.sound;
  $('refresh').disabled = !s.enabled || next.weather.loading;
  const w = next.weather;
  $('weather').textContent = !s.enabled ? 'Ручной эффект включён.' : w.error || (w.current ? `${C.description(w.current.weather_code)}, ${Math.round(w.current.temperature_2m)} °C · обновлено ${new Date(w.updatedAt).toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' })}${w.loading ? ' · обновляем…' : ''}` : 'Загружаем погоду…');
  $('window-status').textContent = next.windowStatus;
  $('error').textContent = next.persistenceError || '';
  clock();
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
      b.onclick = async () => { try { await api.select(city, state.settings.atmosphere); $('results').replaceChildren(); $('search-status').textContent = ''; } catch (e) { error(e); } };
      $('results').append(b);
    }
  } catch (e) { if (token === searchToken) error(e); }
  finally { if (token === searchToken) $('search').disabled = false; }
};
$('preview').onclick = () => api.preview().catch(error);
$('refresh').onclick = () => api.refresh().catch(error);
$('clear').onclick = () => api.clear().catch(error);
$('quit').onclick = () => api.quit().catch(error);
api.subscribe(render); api.state().then(render).catch(error); setInterval(clock, 60000);

api.cameras().then(value => { cameras = value; if (state) render(state); }).catch(error);
let advanced = false;
function showAdvanced(value) { advanced = value; for (const section of document.querySelectorAll('.advanced')) section.hidden = !advanced; $('city-section').hidden = advanced; $('settings-tab').textContent = advanced ? '← Вернуться к городу' : 'Эффекты и настройки'; }
$('settings-tab').onclick = () => showAdvanced(!advanced);

$('source-city').onclick = () => api.update({enabled:true}).catch(error);
$('source-manual').onclick = () => api.update({enabled:false}).catch(error);
$('manual-mode').onchange = () => api.update({mode:$('manual-mode').value}).catch(error);
$('quick-intensity').onchange = () => api.update({intensity:Number($('quick-intensity').value)}).catch(error);
$('quick-speed').onchange = () => api.update({speed:Number($('quick-speed').value)}).catch(error);
$('quick-pause').onclick = () => api.update({paused:!state.settings.paused}).catch(error);
$('camera-select').onchange = () => { const portrait = C.portrait(state.settings.city); cameraChoices.set(portrait.portrait, $('camera-select').value); render(state); };
