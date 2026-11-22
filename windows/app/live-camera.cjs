'use strict';
const { BrowserWindow, shell, Menu } = require('electron');
const cameras = require('./live-cameras.json');
let current;
function openCamera(id) {
  const camera = cameras.find(c => c.id === id);
  if (!camera) throw new Error('Camera unavailable');
  if (!camera.embed) return shell.openExternal(camera.watch);
  if (current && !current.isDestroyed()) current.close();
  const win = new BrowserWindow({ title: camera.title, width: 1000, height: 650, minWidth: 620, minHeight: 420,
    autoHideMenuBar: false, backgroundColor: '#172b23',
    webPreferences: { contextIsolation: true, sandbox: true, nodeIntegration: false, autoplayPolicy: 'no-user-gesture-required' } });
  current = win;
  win.setMenu(Menu.buildFromTemplate([{label: 'Камера', submenu: [
    {label: 'Обновить', accelerator: 'CmdOrCtrl+R', click: () => win.webContents.reload()},
    {label: 'Открыть в браузере', click: () => shell.openExternal(camera.watch)},
    {label: camera.provider, click: () => shell.openExternal(camera.source)},
    {type: 'separator'}, {label: 'Закрыть', role: 'close'}
  ]}]));
  win.webContents.setWindowOpenHandler(({url}) => {
    if (url.startsWith('https://')) void shell.openExternal(url);
    return {action:'deny'};
  });
  win.webContents.on('will-navigate', (event, url) => {
    if (url !== camera.embed) { event.preventDefault(); if (url.startsWith('https://')) void shell.openExternal(url); }
  });
  win.webContents.on('page-title-updated', e => e.preventDefault());
  win.webContents.on('did-fail-load', (_e, code) => { if (code !== -3) win.setTitle(`${camera.title} · не удалось загрузить`); });
  win.loadURL(camera.embed, { httpReferrer: 'https://local.sugrob.windows' }).catch(() => {});
  let previous = -1;
  const poll = setInterval(async () => {
    if (win.isDestroyed() || win.webContents.isDestroyed()) return;
    try {
      const v = await win.webContents.executeJavaScript("(()=>{const v=document.querySelector('video');return v?{t:v.currentTime,paused:v.paused,error:!!v.error}:null})()");
      if (win.isDestroyed()) return;
      const status = !v ? 'ожидаем видео' : v.error ? 'видео недоступно' : v.paused ? 'пауза · нажмите ▶' : previous >= 0 && v.t > previous ? 'воспроизводится' : 'буферизация';
      if (v) previous = v.t;
      win.setTitle(`${camera.title} · ${status} · ${camera.provider}`);
    } catch {}
  }, 3000);
  win.on('closed', () => { clearInterval(poll); if (current === win) current = null; });
}
module.exports = { openCamera, cameras };
