'use strict';
const { app, BrowserWindow, ipcMain, Tray, Menu, nativeImage, screen, powerMonitor, session, dialog } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { createInterface } = require('node:readline');
const { pathToFileURL } = require('node:url');
const core = require('./core.js');
const { openCamera, cameras } = require('./live-camera.cjs');
const { WeatherService } = require('./weather.cjs');
let settings, settingsWindow, tray, helper, quitting = false, windows = [], foreground = null;
let windowStatus = 'Определяем края окон…', persistenceError = null, settingsPath;
const overlays = new Map();
const weather = new WeatherService(broadcast);
const smoke = process.argv.includes('--smoke-test');
if (smoke) app.setPath('userData', path.join(app.getPath('temp'), `sugrob-smoke-${process.pid}`));
function snapshot() { return { settings, weather: weather.state, windowStatus, persistenceError }; }
function send(win, channel, data) { if (win && !win.isDestroyed() && !win.webContents.isDestroyed()) win.webContents.send(channel, data); }
function broadcast() {
  if (!settings) return;
  send(settingsWindow, 'state', snapshot());
  for (const win of overlays.values()) send(win, 'state', { ...snapshot(), audioLeader: win === overlays.values().next().value });
  if (tray) { tray.setToolTip(settings.enabled ? `Сугроб · ${settings.city.name}` : 'Сугроб'); tray.setContextMenu(menu()); }
}
function menu() {
  return Menu.buildFromTemplate([
    { label: 'Настройки…', click: showSettings },
    { label: settings.paused ? 'Продолжить' : 'Пауза', click: () => update({ paused: !settings.paused }) },
    { label: 'Смести всё', click: clear }, { type: 'separator' }, { label: 'Выйти', click: () => app.quit() }
  ]);
}
function save() {
  try {
    const temp = settingsPath + '.tmp'; fs.writeFileSync(temp, JSON.stringify(settings, null, 2));
    fs.renameSync(temp, settingsPath); persistenceError = null;
  } catch { persistenceError = 'Не удалось сохранить настройки. Проверьте доступ к папке пользователя.'; }
}
function update(patch) {
  const before = settings;
  // City selection has a separate validation path; renderer cannot set arbitrary preferences.
  const allowed = Object.fromEntries(Object.entries(patch || {}).filter(([key]) => key in core.defaults && key !== 'city'));
  settings = core.normalize({ ...settings, ...allowed });
  if (before.openAtLogin !== settings.openAtLogin) {
    try { app.setLoginItemSettings({ openAtLogin: settings.openAtLogin, path: process.execPath, args: ['--background'] }); }
    catch { settings.openAtLogin = before.openAtLogin; }
  }
  save(); applyWindows();
  if (before.enabled !== settings.enabled) weather.select(settings.enabled ? settings.city : null);
  broadcast(); return snapshot();
}
function clear() { for (const win of overlays.values()) send(win, 'clear'); }
function secure(win) {
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.webContents.on('will-navigate', event => event.preventDefault());
}
function preferences() { return { preload: path.join(__dirname, 'preload.cjs'), contextIsolation: true, sandbox: true, nodeIntegration: false, backgroundThrottling: false, autoplayPolicy: 'no-user-gesture-required' }; }
function showSettings() {
  if (settingsWindow && !settingsWindow.isDestroyed()) { settingsWindow.show(); settingsWindow.focus(); return; }
  settingsWindow = new BrowserWindow({ title: 'Сугроб', width: 980, height: 850, minWidth: 760, minHeight: 600,
    backgroundColor: '#f5f3e9', autoHideMenuBar: true, show: false, icon: path.join(__dirname, 'icon.png'), webPreferences: preferences() });
  secure(settingsWindow);
  settingsWindow.loadFile(path.join(__dirname, 'settings.html'));
  settingsWindow.once('ready-to-show', () => { settingsWindow.show(); broadcast(); });
  settingsWindow.on('close', event => { if (!quitting) { event.preventDefault(); settingsWindow.hide(); } });
}
function applyWindows() {
  for (const [id, win] of overlays) {
    win.setContentProtection(settings.hideInScreenshots);
    win.setAlwaysOnTop(true, 'screen-saver');
    const display = screen.getAllDisplays().find(d => d.id === id);
    const front = windows.find(w => w.id === foreground);
    const b = display?.bounds;
    const full = b && front && front.x <= b.x + 2 && front.y <= b.y + 2 && front.x + front.width >= b.x + b.width - 2 && front.y + front.height >= b.y + b.height - 2;
    if (!settings.overFullScreen && full) win.hide();
    else if (!win.isVisible()) win.showInactive();
  }
}
function rebuild() {
  for (const win of overlays.values()) win.close();
  overlays.clear();
  for (const display of screen.getAllDisplays()) {
    const win = new BrowserWindow({ ...display.bounds, frame: false, transparent: true, backgroundColor: '#00000000',
      hasShadow: false, resizable: false, movable: false, focusable: false, skipTaskbar: true,
      fullscreenable: false, show: false, webPreferences: preferences() });
    win.setIgnoreMouseEvents(true); win.setAlwaysOnTop(true, 'screen-saver'); secure(win);
    overlays.set(display.id, win);
    win.loadFile(path.join(__dirname, 'overlay.html'));
    win.once('ready-to-show', () => { applyWindows(); broadcast(); environment(); });
  }
}
function environment() {
  if (!settings) return;
  const cursor = screen.getCursorScreenPoint();
  for (const [id, win] of overlays) {
    const d = screen.getAllDisplays().find(item => item.id === id); if (!d) continue;
    send(win, 'environment', { cursor: { x: cursor.x - d.bounds.x, y: cursor.y - d.bounds.y },
      ground: d.workArea.y + d.workArea.height - d.bounds.y,
      windows: settings.onWindows ? windows.map(w => ({ ...w, x: w.x - d.bounds.x, y: w.y - d.bounds.y })) : [] });
  }
}
function startHelper() {
  if (process.platform !== 'win32') { windowStatus = 'Края окон доступны только на Windows.'; return; }
  const script = fs.readFileSync(path.join(__dirname, 'windows.ps1'), 'utf8').replace('__SUGROB_PID__', String(process.pid));
  const executable = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
  helper = spawn(executable, ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  const unavailable = () => { windows = []; windowStatus = 'Края окон недоступны. Накопление внизу экрана работает.'; broadcast(); };
  helper.on('error', unavailable); helper.on('exit', unavailable);
  helper.stderr.on('data', () => {});
  createInterface({ input: helper.stdout }).on('line', line => {
    try {
      const data = JSON.parse(line);
      windows = (Array.isArray(data.windows) ? data.windows : []).map(w => ({ id: w.id, ...screen.screenToDipRect(null, { x: w.x, y: w.y, width: w.width, height: w.height }) }));
      foreground = data.foreground;
      if (windowStatus !== 'Края окон доступны.') { windowStatus = 'Края окон доступны.'; broadcast(); }
      applyWindows();
    } catch {}
  });
}
function authorized(event, settingsOnly = false) {
  if (event.senderFrame !== event.sender.mainFrame) throw new Error('Invalid frame');
  const expected = pathToFileURL(path.join(__dirname, settingsOnly ? 'settings.html' : 'overlay.html')).href;
  const isSettings = event.sender === settingsWindow?.webContents && event.sender.getURL() === pathToFileURL(path.join(__dirname, 'settings.html')).href;
  if (!isSettings && (settingsOnly || ![...overlays.values()].some(w => w.webContents === event.sender) || event.sender.getURL() !== expected)) throw new Error('Invalid sender');
}
if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', () => { if (app.isReady()) showSettings(); });
  app.on('window-all-closed', () => {});
  app.on('before-quit', () => { quitting = true; helper?.kill(); weather.close(); });
  app.whenReady().then(async () => {
    app.setAppUserModelId('local.sugrob.windows');
    Menu.setApplicationMenu(null);
    settingsPath = path.join(app.getPath('userData'), 'settings.json');
    try { settings = core.normalize(JSON.parse(fs.readFileSync(settingsPath, 'utf8'))); } catch { settings = core.normalize(); }
    session.defaultSession.setPermissionRequestHandler((_web, _permission, callback) => callback(false));
    session.defaultSession.setPermissionCheckHandler(() => false);
    ipcMain.handle('state', e => { authorized(e); return { ...snapshot(), audioLeader: e.sender === overlays.values().next().value?.webContents }; });
    ipcMain.handle('update', (e, patch) => { authorized(e, true); return update(patch); });
    ipcMain.handle('select', (e, value, atmosphere) => {
      authorized(e, true); const city = core.validCity(value); if (!city) throw new Error('Invalid city');
      settings.city = city; settings.enabled = true; if (typeof atmosphere === 'boolean') settings.atmosphere = atmosphere;
      save(); weather.select(city); broadcast(); return snapshot();
    });
    ipcMain.handle('search', async (e, query) => { authorized(e, true); try { return { cities: await weather.search(query) }; } catch { return { error: 'Не удалось найти город. Проверьте интернет и повторите.' }; } });
    ipcMain.handle('cameras', e => { authorized(e, true); return cameras; });
    ipcMain.handle('open-camera', (e, id) => { authorized(e, true); return openCamera(id); });
    ipcMain.handle('refresh', e => { authorized(e, true); void weather.refresh(); });
    ipcMain.handle('preview', e => { authorized(e, true); for (const win of overlays.values()) send(win, 'preview'); });
    ipcMain.handle('clear', e => { authorized(e, true); clear(); });
    ipcMain.handle('quit', e => { authorized(e, true); app.quit(); });
    tray = new Tray(nativeImage.createFromPath(path.join(__dirname, 'icon.png')));
    tray.on('click', showSettings); tray.on('double-click', showSettings);
    rebuild(); startHelper(); broadcast();
    if (!process.argv.includes('--background')) showSettings();
    weather.select(settings.enabled ? settings.city : null);
    setInterval(() => void weather.refresh(), 15 * 60 * 1000).unref();
    setInterval(environment, 80).unref();
    for (const name of ['display-added', 'display-removed', 'display-metrics-changed']) screen.on(name, rebuild);
    powerMonitor.on('resume', () => { void weather.refresh(); environment(); });
    if (smoke) {
      await new Promise(resolve => setTimeout(resolve, 3500));
      const result = await settingsWindow.webContents.executeJavaScript('({presets:document.querySelectorAll("#presets button").length,title:document.title})');
      if (result.presets !== 6 || overlays.size === 0) throw new Error('Smoke test failed');
      console.log('SMOKE PASS: settings and overlay loaded'); app.quit();
    }
  }).catch(error => { dialog.showErrorBox('Сугроб', error.message); app.exit(1); });
}
