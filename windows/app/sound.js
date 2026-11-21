'use strict';
window.Soundscape = class {
  constructor() { this.audio = null; this.track = null; this.timers = new Map(); }
  fade(audio, target, stop = false) {
    clearInterval(this.timers.get(audio));
    const from = audio.volume, started = Date.now();
    const timer = setInterval(() => {
      const t = Math.min(1,(Date.now()-started)/800);
      audio.volume = from + (target-from)*t;
      if (t === 1) { clearInterval(timer);this.timers.delete(audio);if(stop) { audio.pause();audio.src=''; } }
    },40);
    this.timers.set(audio,timer);
  }
  sync(enabled, track, volume) {
    if (!enabled || !track) {
      if(this.audio) this.fade(this.audio,0,true);
      this.audio=null;this.track=null;return;
    }
    if(this.track!==track) {
      if(this.audio) this.fade(this.audio,0,true);
      this.audio=new Audio(`assets/${track}.wav`);this.audio.loop=true;this.audio.volume=0;
      this.audio.play().catch(()=>{});this.track=track;
    }
    this.fade(this.audio,Math.min(1,Math.max(0,volume))*.5);
  }
};
