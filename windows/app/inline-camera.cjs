'use strict';
const { WebContentsView, shell } = require('electron');
const cameras = require('./live-cameras.json');
class InlineCamera {
  constructor(window, catalog = () => cameras) { this.catalog = catalog; this.window = window; this.view = null; this.key = null; this.timer = null; this.generation = 0; }
  show(key, bounds) {
    const camera = this.catalog().find(c => c.embed === key);
    if (!camera) throw new Error('Camera unavailable');
    if (!bounds || !['x','y','width','height'].every(k => Number.isFinite(bounds[k]))) throw new Error('Invalid bounds');
    if (!this.window.isVisible() || this.window.isMinimized()) { this.clear(); return; }
    const [width,height] = this.window.getContentSize();
    const x = Math.max(0,Math.min(width,Math.round(bounds.x))), y = Math.max(0,Math.min(height,Math.round(bounds.y)));
    const rect = {x,y,width:Math.max(0,Math.min(width-x,Math.round(bounds.width))),height:Math.max(0,Math.min(height-y,Math.round(bounds.height)))};
    if (rect.width < 1 || rect.height < 1) { this.clear(); return; }
    if (this.key !== key) {
      this.clear(); this.key = key;
      const view = new WebContentsView({webPreferences:{contextIsolation:true,sandbox:true,nodeIntegration:false,autoplayPolicy:'no-user-gesture-required'}});
      this.view = view; const generation = this.generation;
      view.setBorderRadius(14);
      this.window.contentView.addChildView(view);
      const web = view.webContents;
      web.setWindowOpenHandler(({url}) => { if(url.startsWith('https://')) void shell.openExternal(url); return {action:'deny'}; });
      web.on('will-navigate',(event,url) => { if(url !== key) {event.preventDefault(); if(url.startsWith('https://')) void shell.openExternal(url);} });
      web.on('before-input-event',(event,input) => {
        if(input.type === 'keyDown' && input.key === 'Escape') { event.preventDefault(); this.send('camera-collapse'); }
      });
      web.on('did-fail-load',(_event,code) => {if(code !== -3) this.status('Не удалось подключиться · попробуйте обновить');});
      web.on('render-process-gone',() => this.status('Плеер остановился · нажмите «Обновить»'));
      this.status('Подключаем камеру…');
      web.loadURL(key,{httpReferrer:'https://local.sugrob.windows'}).catch(()=>{});
      let previous = -1;
      this.timer = setInterval(async () => {
        if(web.isDestroyed()) return;
        try {
          const v = await web.executeJavaScript("(()=>{const v=document.querySelector('video'),p=document.getElementById('movie_player');let r;try{r=p?.getPlayerResponse?.()}catch{}const e=document.querySelector('.ytp-error-content-wrap');const message=e&&e.getClientRects().length?e.textContent.trim().slice(0,240):'';const live=r?.microformat?.playerMicroformatRenderer?.liveBroadcastDetails?.isLiveNow;const type=live===true?'Прямой эфир':r?.videoDetails?.isLiveContent===false?'Видео':live===false?'Запись эфира':'Видео · тип эфира не подтверждён';return message?{t:0,error:true,message}:v?{t:v.currentTime,paused:v.paused,error:!!v.error,type}:null})()");
          if(generation !== this.generation) return;
          this.status(!v ? 'Ожидаем плеер · запуск — кнопкой ▶' : v.error ? ('Видео недоступно: '+(v.message||'попробуйте обновить')) : v.paused ? 'Пауза · нажмите ▶ в плеере' : previous >= 0 && v.t > previous ? ('● '+(v.type||'Видео')+' · воспроизводится') : 'Буферизация…');
          if(v) previous = v.t;
        } catch {}
      },2000);
    }
    this.view.setBounds(rect);
  }
  send(channel,value) {if(!this.window.isDestroyed()) this.window.webContents.send(channel,value);}
  status(value) {this.send('camera-status',value);}
  reload() {if(this.view && !this.view.webContents.isDestroyed()) this.view.webContents.reload();}
  clear() {
    this.generation++; clearInterval(this.timer); this.timer = null;
    if(this.view) { if(!this.window.isDestroyed()) this.window.contentView.removeChildView(this.view); if(!this.view.webContents.isDestroyed()) this.view.webContents.close(); }
    this.view = null; this.key = null;
  }
}
module.exports = {InlineCamera};
