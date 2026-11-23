const { test } = require('node:test');
const assert = require('node:assert/strict');
const C = require('../app/core.js');
const { WeatherService } = require('../app/weather.cjs');
test('Eight city portraits, winter/summer clocks and daylight-saving time', () => {
  assert.equal(C.cities.length, 8);
  const winter = new Date('2026-01-15T12:00:00Z'), summer = new Date('2026-06-15T12:00:00Z');
  const times = [['15:00', '15:00'], ['13:00', '14:00'], ['14:00', '15:00'], ['15:00', '15:00'], ['21:00', '21:00'], ['13:00', '14:00'], ['15:00', '15:00'], ['07:00', '08:00']];
  C.cities.forEach((city, i) => {
    assert.equal(C.portrait(C.validCity(city)).portrait, city.portrait);
    assert.equal(C.mood(city, winter).time, times[i][0]); assert.equal(C.mood(city, summer).time, times[i][1]);
    assert.equal(C.mood(city, winter).season, 'winter'); assert.equal(C.mood(city, summer).season, 'summer');
  });
  assert.equal(C.mood(C.cities[6], new Date('2026-10-15T10:00:00Z')).particle, 'leaf');
  assert.equal(C.mood(C.cities[3], new Date('2026-06-15T20:30:00Z')).light, 'whiteNight');
  assert.equal(C.mood(C.cities[0], new Date('2026-06-15T20:30:00Z')).light, 'night');
  assert.equal(C.mood(C.cities[4], new Date('2026-04-15T03:00:00Z')).particle, 'petal');
  assert.equal(C.mood(C.cities[4], new Date('2026-11-15T03:00:00Z')).particle, 'leaf');
  assert.equal(C.mood({ ...C.cities[4], timezone: undefined }, winter).time, '21:00');
  assert.equal(C.mood({ ...C.cities[4], latitude: -35 }, winter).season, 'summer');
});
test('Weather codes never invent precipitation; atmosphere works offline', () => {
  for (const code of [71,73,75,77,85,86]) assert.equal(C.effect(code), 'snow');
  for (const code of [51,53,55,56,57,61,63,65,66,67,80,81,82]) assert.equal(C.effect(code), 'rain');
  for (const code of [0,1,2,3,45,48,999,null,undefined]) assert.equal(C.effect(code), null);
  assert.equal(C.mood(C.cities[0]).precipitation, false);
  assert.equal(C.mood(C.cities[0], new Date(), 71).precipitation, true);
});
test('Stored settings are bounded and cities validated', () => {
  assert.equal(C.normalize({ enabled: true }).enabled, false);
  assert.equal(C.normalize({ intensity: 100 }).intensity, 3);
  assert.equal(C.normalize({ intensity: 'x' }).intensity, 1);
  assert.equal(C.normalize({ mode: 'script', openAtLogin: 'yes' }).mode, 'snow');
  assert.equal(C.normalize({ openAtLogin: 'yes' }).openAtLogin, false);
  assert.equal(C.validCity({ ...C.cities[0], latitude: 91 }), null);
  assert.equal(C.validCity({ ...C.cities[0], timezone: '../../etc' }).timezone, undefined);
  const settings = C.normalize({ ...C.defaults, enabled: true, city: C.cities[5], mode: 'petals' });
  assert.deepEqual(C.normalize(JSON.parse(JSON.stringify(settings))), settings);
});
test('Particles land on visible edges, never behind a covering window', () => {
  const a = { id: 'front', x: 0, y: 100, width: 200, height: 200 };
  const b = { id: 'back', x: 0, y: 150, width: 400, height: 200 };
  assert.deepEqual(C.landing(80, 80, 160, [a,b], 600), { id: 'front', y: 100 });
  assert.equal(C.landing(80, 120, 160, [a,b], 600), null);
  assert.deepEqual(C.landing(300, 120, 160, [a,b], 600), { id: 'back', y: 150 });
  assert.deepEqual(C.landing(500, 580, 610, [], 600), { id: 'ground', y: 600 });
  assert.equal(C.landing(500, 580, 610, [], null), null);
});
const settle = () => new Promise(resolve => setImmediate(resolve));
test('Search Unicode, optional fields and empty results', async () => {
  let url;
  const service = new WeatherService(() => {}, async u => { url = u; return { results: [C.cities[0], { id: 7 }] }; });
  const result = await service.search('Нижний Новгород');
  assert.equal(url.searchParams.get('name'), 'Нижний Новгород'); assert.equal(result.length, 1);
  service.request = async () => ({}); assert.deepEqual(await service.search('xxyy'), []);
});
test('Weather failure clears stale data, retry recovers and manual mode cancels', async () => {
  const service = new WeatherService(() => {}, async () => ({ current: { temperature_2m: -2, weather_code: 71 } }));
  service.select(C.cities[0]); await settle(); assert.equal(service.state.current.weather_code, 71);
  service.request = async () => { throw new Error('offline'); };
  await service.refresh(); assert.equal(service.state.current, null); assert.ok(service.state.error);
  service.request = async () => ({ current: { temperature_2m: 18, weather_code: 0 } });
  await service.refresh(); assert.equal(service.state.error, null); assert.equal(service.state.current.weather_code, 0);
  service.select(null); assert.equal(service.state.current, null); assert.equal(service.state.loading, false);
});
test('Slow old-city response cannot replace a newer selection', async () => {
  const pending = [];
  const service = new WeatherService(() => {}, u => new Promise(resolve => pending.push({ u, resolve })));
  service.select(C.cities[0]); service.select(C.cities[4]);
  pending[1].resolve({ current: { temperature_2m: 20, weather_code: 61 } }); await settle();
  pending[0].resolve({ current: { temperature_2m: -5, weather_code: 71 } }); await settle();
  assert.equal(service.city.name, 'Токио'); assert.equal(service.state.current.weather_code, 61);
  service.select(C.cities[1]); service.select(null);
  pending[2].resolve({ current: { temperature_2m: 20, weather_code: 61 } }); await settle();
  assert.equal(service.state.current, null);
});
test('Malformed current weather is an error, not invented clear weather', async () => {
  const service = new WeatherService(() => {}, async () => ({ current: { weather_code: 71 } }));
  service.select(C.cities[0]); await settle(); assert.equal(service.state.current, null); assert.ok(service.state.error);
});

test('Presence chooses seasonal imagery and sound is opt-in', () => {
  assert.equal(C.defaults.sound, false);
  assert.equal(C.normalize({volume: 10}).volume, 1);
  assert.equal(C.mood(C.cities[4], new Date('2026-04-15T12:00:00Z')).edgeAsset, 'cherry');
  assert.equal(C.mood(C.cities[4], new Date('2026-10-15T12:00:00Z')).edgeAsset, 'maple');
  assert.equal(C.mood(C.cities[0], new Date('2026-01-15T12:00:00Z')).edgeAsset, null);
  assert.equal(C.mood(C.cities[2]).edgeAsset, 'olive');
  assert.equal(C.mood(C.cities[3]).soundAsset, null);
  assert.equal(C.mood(C.cities[3], new Date(), 61).soundAsset, null);
});

test('Only Florence, Rome and Tokyo have recordings, regardless of precipitation',()=>{
 const expected={florence:'florence-market',rome:'rome-pantheon',tokyo:'tokyo-street'};
 for(const city of C.cities) for(const code of [0,61,71]) assert.equal(C.mood(city,new Date(),code).soundAsset,expected[city.portrait]||null);
});

test('New York observes US daylight saving; Nizhny stays on Moscow time and both are silent',()=>{
 const ny=C.cities.find(c=>c.portrait==='newyork'),nn=C.cities.find(c=>c.portrait==='nizhny');
 assert.equal(C.mood(ny,new Date('2026-01-15T12:00:00Z')).time,'07:00');
 assert.equal(C.mood(ny,new Date('2026-07-15T12:00:00Z')).time,'08:00');
 assert.equal(C.mood(nn,new Date('2026-07-15T12:00:00Z')).time,'15:00');
 assert.equal(C.mood(ny).soundAsset,null); assert.equal(C.mood(nn).soundAsset,null);
});

test('City effects require positive measured precipitation', () => {
 const C = require('../app/core.js');
 assert.equal(C.currentEffect({weather_code:80,precipitation:0}),null);
 assert.equal(C.currentEffect({weather_code:80}),null);
 assert.equal(C.currentEffect({weather_code:80,precipitation:0.1}),'rain');
 assert.equal(C.currentEffect({weather_code:71,precipitation:0.1}),'snow');
});

test('Saved Rome coordinates request the Vatican district and precipitation', async () => {
 const service = new WeatherService(()=>{},async u=>{
  assert.equal(u.searchParams.get('latitude'),'41.9022');
  assert.equal(u.searchParams.get('longitude'),'12.4573');
  assert.ok(u.searchParams.get('current').includes('precipitation'));
  return {current:{temperature_2m:18,weather_code:80,precipitation:0}};
 });
 service.city={id:-2,latitude:41.90,longitude:12.50};
 await service.refresh();
 assert.equal(C.currentEffect(service.state.current),null);
 service.close();
});

test('Weather label agrees with dry, wet and missing precipitation', () => {
 for (const weather_code of [61,71,80,95]) {
  assert.equal(C.currentDescription({weather_code,precipitation:0}),'Без осадков');
  assert.equal(C.currentDescription({weather_code}),'Нет данных об осадках');
 }
 assert.equal(C.currentDescription({weather_code:61,precipitation:0.1}),'Дождь');
 assert.equal(C.currentDescription({weather_code:0,precipitation:0}),'Ясно');
});

test('Storm and palettes survive settings validation; dry weather stays clear', () => {
 for(const theme of ['sage','sand','blue','rocks','clouds']) assert.equal(C.normalize({theme,mode:'storm'}).theme,theme);
 assert.equal(C.normalize({theme:'invalid'}).theme,'sage');
 assert.equal(C.normalize({mode:'storm',lightning:false}).lightning,false);
 for(const weather_code of [95,96,97,99]) {
  assert.equal(C.currentEffect({weather_code,precipitation:.2}),'storm');
  assert.equal(C.currentDescription({weather_code,precipitation:.2}),'Гроза');
  assert.equal(C.currentEffect({weather_code,precipitation:0}),null);
 }
});

test('Weather audio follows manual or city weather and never falls back to city audio',()=>{
 const city=C.cities.find(c=>c.portrait==='rome');
 for(const mode of ['rain','storm']) {
  const s=C.normalize({city,mode,soundSource:'weather',atmosphere:false,weatherVolume:.7});
  assert.equal(C.soundTrack(s,null),'weather-'+mode);
  assert.equal(s.weatherVolume,.7);
 }
 const s=C.normalize({city,enabled:true,mode:'rain',soundSource:'weather'});
 assert.equal(C.soundTrack(s,{weather_code:95,precipitation:.5}),'weather-storm');
 assert.equal(C.soundTrack(s,{weather_code:61,precipitation:0}),null);
 assert.equal(C.soundTrack(s,null),null);
 assert.equal(C.soundTrack({...s,enabled:false,mode:'snow'},null),null);
 assert.equal(C.soundTrack({...s,soundSource:'city'},null),'rome-pantheon');
});
