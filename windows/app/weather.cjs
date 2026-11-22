'use strict';
const { validCity } = require('./core.js');
async function json(url, signal) {
  const response = await fetch(url, { signal: AbortSignal.any([signal, AbortSignal.timeout(20000)]), redirect: 'error' });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response.json();
}
class WeatherService {
  constructor(onChange, request = json) {
    this.onChange = onChange; this.request = request; this.city = null;
    this.state = { loading: false, current: null, error: null, updatedAt: null };
    this.generation = 0; this.searchGeneration = 0;
  }
  select(city) {
    this.controller?.abort(); this.generation++; this.city = city;
    this.state = { loading: false, current: null, error: null, updatedAt: null };
    this.onChange();
    if (city) void this.refresh();
  }
  async refresh() {
    if (!this.city || this.state.loading) return;
    const token = ++this.generation, city = this.city;
    this.controller = new AbortController();
    this.state.loading = true; this.state.error = null; this.onChange();
    try {
      const u = new URL('https://api.open-meteo.com/v1/forecast');
      u.search = new URLSearchParams({ latitude: city.id === -2 ? 41.9022 : city.latitude, longitude: city.id === -2 ? 12.4573 : city.longitude, current: 'temperature_2m,weather_code,precipitation', temperature_unit: 'celsius' });
      const data = await this.request(u, this.controller.signal);
      if (token !== this.generation) return;
      if (!Number.isFinite(data.current?.temperature_2m) || !Number.isInteger(data.current?.weather_code)) throw new Error('Invalid weather');
      this.state.current = data.current; this.state.updatedAt = Date.now();
    } catch {
      if (token !== this.generation) return;
      this.state.current = null;
      this.state.error = 'Погода недоступна. Реальные осадки скрыты, атмосфера продолжает работать. Повторим через 15 минут.';
    } finally {
      if (token === this.generation) { this.state.loading = false; this.onChange(); }
    }
  }
  async search(query) {
    this.searchController?.abort(); const token = ++this.searchGeneration;
    query = String(query).trim().slice(0, 120);
    if (query.length < 2) return [];
    this.searchController = new AbortController();
    const u = new URL('https://geocoding-api.open-meteo.com/v1/search');
    u.search = new URLSearchParams({ name: query, count: 8, language: 'ru' });
    const data = await this.request(u, this.searchController.signal);
    if (token !== this.searchGeneration) return [];
    return (Array.isArray(data.results) ? data.results : []).map(validCity).filter(Boolean);
  }
  close() { this.controller?.abort(); this.searchController?.abort(); this.generation++; this.searchGeneration++; }
}
module.exports = { WeatherService };
