(function (root) {
  'use strict';
  const cities = [
    { id: -1, name: 'Москва', latitude: 55.75, longitude: 37.62, country: 'Россия', timezone: 'Europe/Moscow', portrait: 'moscow', detail: 'Ветка появляется из-за края, серебристый свет и тихий ветер.' },
    { id: -2, name: 'Рим', latitude: 41.9022, longitude: 12.4573, country: 'Италия', timezone: 'Europe/Rome', portrait: 'rome', detail: 'Живая хвоя пинии, медовый свет и мягкий шелест.' },
    { id: -3, name: 'Афины', latitude: 37.98, longitude: 23.73, country: 'Греция', timezone: 'Europe/Athens', portrait: 'athens', detail: 'Оливковая ветка покачивается в бело-голубом свете.' },
    { id: -4, name: 'Санкт-Петербург', latitude: 59.94, longitude: 30.31, country: 'Россия', timezone: 'Europe/Moscow', portrait: 'petersburg', detail: 'Отражения воды, редкие чайки и жемчужные июньские ночи.' },
    { id: -5, name: 'Токио', latitude: 35.68, longitude: 139.69, country: 'Япония', timezone: 'Asia/Tokyo', portrait: 'tokyo', detail: 'Ветка сакуры весной, клён осенью, проходящие отблески ночью.' },
    { id: -6, name: 'Флоренция', latitude: 43.77, longitude: 11.25, country: 'Италия', timezone: 'Europe/Rome', portrait: 'florence', detail: 'Тосканская хвоя, терракотовый вечерний свет и шелест.' },
    { id: -7, name: 'Нижний Новгород', latitude: 56.33, longitude: 44.00, country: 'Россия', timezone: 'Europe/Moscow', portrait: 'nizhny', detail: 'Тёплые отражения, ветка из-за края и дыхание воды.' },
    { id: -8, name: 'Нью-Йорк', latitude: 40.7128, longitude: -74.0060, country: 'США', timezone: 'America/New_York', portrait: 'newyork', detail: 'Погода и местное время Нью-Йорка.' }
  ];
  const defaults = { theme: 'sage', lightning: true, enabled: false, atmosphere: true, city: null, mode: 'snow', paused: false,
    intensity: 1, speed: 1, size: 1, opacity: 0.85, strength: 0.65, sound: false, florenceBells: false, volume: 0.25, onGround: true, onWindows: true,
    cursor: true, drift: 1800, hideInScreenshots: false, overFullScreen: false, openAtLogin: false };
  const clamp = (n, a, b) => Math.min(b, Math.max(a, n));
  function validCity(value) {
    if (!value || typeof value.name !== 'string' || !value.name.trim() || !Number.isFinite(value.id) ||
        !Number.isFinite(value.latitude) || Math.abs(value.latitude) > 90 ||
        !Number.isFinite(value.longitude) || Math.abs(value.longitude) > 180) return null;
    let timezone;
    try { if (typeof value.timezone === 'string') { new Intl.DateTimeFormat('en', { timeZone: value.timezone }); timezone = value.timezone; } } catch {}
    return { id: value.id, name: value.name.slice(0, 120), latitude: value.latitude, longitude: value.longitude,
      country: typeof value.country === 'string' ? value.country.slice(0, 120) : '',
      admin1: typeof value.admin1 === 'string' ? value.admin1.slice(0, 120) : '', timezone };
  }
  function normalize(input = {}) {
    const s = { ...defaults };
    for (const key of Object.keys(defaults)) {
      if (typeof defaults[key] === 'boolean' && typeof input[key] === 'boolean') s[key] = input[key];
    }
    for (const [key, min, max] of [['intensity', .1, 3], ['speed', .3, 2.5], ['size', .5, 2.5], ['opacity', .1, 1], ['strength', .15, 1], ['volume', 0, 1], ['drift', 300, 6000]]) {
      if (Number.isFinite(input[key])) s[key] = clamp(input[key], min, max);
    }
    if (['snow', 'rain', 'leaves', 'petals', 'clouds', 'storm'].includes(input.mode)) s.mode = input.mode;
    if (['sage','sand','blue','rocks','clouds'].includes(input.theme)) s.theme = input.theme;
    if (input.theme === 'lavender') s.theme = 'blue';
    s.city = validCity(input.city);
    if (!s.city) s.enabled = false;
    return s;
  }
  function effect(code) {
    if ([95,96,97,99].includes(code)) return 'storm';
    if ([71, 73, 75, 77, 85, 86].includes(code)) return 'snow';
    if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].includes(code)) return 'rain';
    return null;
  }
  function currentEffect(current) {
    if ([2,3].includes(current?.weather_code)) return 'clouds';
    return Number.isFinite(current?.precipitation) && current.precipitation > 0 ? effect(current.weather_code) : null;
  }
  function currentDescription(current) {
    if (effect(current?.weather_code)) {
      if (!Number.isFinite(current?.precipitation) || current.precipitation < 0) return 'Нет данных об осадках';
      if (current.precipitation === 0) return 'Без осадков';
    }
    return description(current?.weather_code);
  }
  function description(code) {
    if ([0, 1].includes(code)) return 'Ясно';
    if ([2, 3].includes(code)) return 'Облачно';
    if ([45, 48].includes(code)) return 'Туман';
    if ([95, 96, 97, 99].includes(code)) return 'Гроза';
    if ([51, 53, 55, 56, 57].includes(code)) return 'Морось';
    return effect(code) === 'snow' ? 'Снег' : effect(code) === 'rain' ? 'Дождь' : 'Неизвестные условия';
  }
  function portrait(city) { return cities.find(c => Math.abs(c.latitude - city.latitude) < .2 && Math.abs(c.longitude - city.longitude) < .2); }
  function localParts(city, date) {
    const timeZone = city.timezone || portrait(city)?.timezone;
    if (timeZone) {
      const p = Object.fromEntries(new Intl.DateTimeFormat('en-GB', { timeZone, hourCycle: 'h23', month: 'numeric', hour: '2-digit', minute: '2-digit' }).formatToParts(date).map(p => [p.type, p.value]));
      return { month: +p.month, hour: +p.hour, minute: +p.minute };
    }
    const d = new Date(date.getTime() + Math.round(city.longitude / 15) * 3600000);
    return { month: d.getUTCMonth() + 1, hour: d.getUTCHours(), minute: d.getUTCMinutes() };
  }
  function mood(city, date = new Date(), code = null) {
    const p = localParts(city, date), profile = portrait(city)?.portrait || 'neutral';
    const month = city.latitude < 0 ? (p.month + 5) % 12 + 1 : p.month;
    const season = month >= 3 && month <= 5 ? 'spring' : month >= 6 && month <= 8 ? 'summer' : month >= 9 && month <= 11 ? 'autumn' : 'winter';
    const hour = p.hour + p.minute / 60;
    const spread = Math.min(Math.abs(city.latitude) / 15, 4) * Math.cos((month - 6) * Math.PI / 6);
    const dawn = 6 - spread / 2, dusk = 18 + spread / 2;
    let light = hour < dawn - 1 || hour >= dusk + 1 ? 'night' : hour < dawn + 1 ? 'dawn' : hour >= dusk - 1 ? 'dusk' : 'day';
    if (profile === 'petersburg' && p.month === 6 && (hour >= 22 || hour < 3)) light = 'whiteNight';
    let particle = light === 'night' ? 'glint' : profile === 'petersburg' && season !== 'winter' ? 'gull' : profile === 'athens' ? 'olive' : season === 'autumn' ? 'leaf' : season === 'spring' && ['tokyo', 'neutral'].includes(profile) ? 'petal' : 'glint';
    let tint = { nizhny: [172, 207, 224], rome: [255, 204, 110], athens: [166, 219, 255], florence: [242, 153, 102], tokyo: [255, 186, 207] }[profile] || [194, 217, 255];
    if (light === 'night') tint = profile === 'tokyo' ? [212, 89, 163] : profile === 'nizhny' ? [235, 183, 112] : [102, 140, 209];
    if (light === 'dawn') tint = [232, 184, 194];
    if (light === 'dusk') tint = [255, 153, 87];
    if (light === 'whiteNight') tint = [166, 199, 242];
    const edgeAsset = ['rome','florence'].includes(profile) ? 'pine' : profile === 'athens' ? 'olive' : profile === 'tokyo' ? (season === 'spring' ? 'cherry' : season === 'autumn' ? 'maple' : null) : season === 'autumn' ? 'autumn' : null;
    const soundAsset = ({florence:'florence-market',rome:'rome-pantheon',tokyo:'tokyo-street'})[profile] || null;
    return { profile, season, light, particle, tint, edgeAsset, soundAsset, precipitation: !!effect(code), overcast: [2, 3, 45, 48].includes(code), fog: [45, 48].includes(code), time: `${String(p.hour).padStart(2, '0')}:${String(p.minute).padStart(2, '0')}` };
  }
  // Windows arrive front-to-back. A covered edge must never collect particles.
  function landing(x, oldY, newY, windows, ground) {
    for (let i = 0; i < windows.length; i++) {
      const w = windows[i];
      if (x < w.x || x > w.x + w.width || oldY > w.y || newY < w.y) continue;
      if (windows.slice(0, i).some(v => x >= v.x && x <= v.x + v.width && w.y >= v.y && w.y < v.y + v.height)) continue;
      return { id: w.id, y: w.y };
    }
    return ground !== null && oldY <= ground && newY >= ground ? { id: 'ground', y: ground } : null;
  }
  const api = { cities, defaults, normalize, validCity, effect, currentEffect, currentDescription, description, portrait, mood, localParts, clamp, landing };
  if (typeof module !== 'undefined') module.exports = api;
  else root.Sugrob = api;
})(globalThis);
