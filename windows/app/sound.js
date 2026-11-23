'use strict';
window.Soundscape = class {
  constructor() { this.audio = null; this.track = null; this.timers = new Map(); this.thunderJob=null; this.thunderAudio=null; this.thunderAllowed=false; this.thunderContext=null; this.thunderVolume=0; }
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
  strike() {
    if(!this.thunderAllowed || this.thunderJob!==null) return;
    this.thunderJob=setTimeout(()=>{
      this.thunderJob=null;
      if(!this.thunderAllowed) return;
      if(this.thunderAudio) this.thunderAudio.pause();
      this.thunderAudio=new Audio('assets/weather-thunder.mp3');
      this.thunderAudio.volume=this.thunderVolume;
      this.thunderAudio.play().catch(()=>{});
    },800+Math.random()*1000);
  }
  sync(enabled, track, volume, weatherSound=false, effect=null) {
    const allowed=!!enabled && weatherSound;
    if(!allowed || effect!==this.thunderContext) {
      if(this.thunderJob!==null) clearTimeout(this.thunderJob);
      this.thunderJob=null;
      if(this.thunderAudio) { this.thunderAudio.pause(); this.thunderAudio.src=''; this.thunderAudio=null; }
    }
    this.thunderAllowed=allowed;this.thunderContext=effect;
    this.thunderVolume=Math.min(1,Math.max(0,volume))*.5;
    if(this.thunderAudio) this.thunderAudio.volume=this.thunderVolume;
    if (!enabled || !track) {
      if(this.audio) this.fade(this.audio,0,true);
      this.audio=null;this.track=null;return;
    }
    if(this.track!==track) {
      if(this.audio) this.fade(this.audio,0,true);
      this.audio=new Audio(`assets/${track}.mp3`);this.audio.loop=true;this.audio.volume=0;
      this.audio.play().catch(()=>{});this.track=track;
    }
    this.fade(this.audio,Math.min(1,Math.max(0,volume))*.5);
  }
};
