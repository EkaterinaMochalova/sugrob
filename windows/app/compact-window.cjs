'use strict';
class CompactWindow {
 constructor(){this.frames=new WeakMap();}
 set(window,compact){
  if(!window||window.isDestroyed())return;
  if(compact){
   if(this.frames.has(window))return;
   this.frames.set(window,{bounds:window.getBounds(),maximized:window.isMaximized()});
   if(window.isMaximized())window.unmaximize();
   window.setMinimumSize(360,320);window.setSize(540,460);
  }else{
   const saved=this.frames.get(window);if(!saved)return;
   window.setMinimumSize(760,600);window.setBounds(saved.bounds);if(saved.maximized)window.maximize();
   this.frames.delete(window);
  }
 }
}
module.exports={CompactWindow};
