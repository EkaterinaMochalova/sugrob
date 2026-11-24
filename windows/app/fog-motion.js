(function(root){
 'use strict';
 class FogMotion {
  constructor(){this.reset();}
  reset(){this.banks=Array.from({length:6},()=>({offset:0,velocity:0,clearing:0}));this.previous=null;}
  move(x,y,time,width,height){
   const old=this.previous;this.previous={x,y,time};
   const inside=p=>p&&p.x>=0&&p.x<=width&&p.y>=0&&p.y<=height*.28;
   if(!inside(this.previous)||!inside(old))return;
   const dt=time-old.time,dx=x-old.x,distance=Math.hypot(dx,y-old.y);
   if(dt<.008||dt>.2||distance<12||distance>=width*.5||distance/dt<=650)return;
   const force=Math.min(1,(distance/dt-650)/1400);
   this.banks.forEach((b,i)=>{
    const center=width*(.05+i*.18),influence=Math.exp(-Math.pow((x-center)/Math.max(120,width*.24),2));
    const direction=Math.abs(dx)>4?Math.sign(dx):(center>x?1:-1);
    b.velocity=Math.max(-240,Math.min(240,b.velocity+direction*force*influence*180));
    b.clearing=Math.min(1,b.clearing+force*influence*.7);
   });
  }
  tick(dt){for(const b of this.banks){b.offset=Math.max(-180,Math.min(180,(b.offset+b.velocity*dt)*Math.exp(-dt*.7)));b.velocity*=Math.exp(-dt*2.2);b.clearing*=Math.exp(-dt*.55);}}
 }
 if(typeof module!=='undefined')module.exports={FogMotion};else root.FogMotion=FogMotion;
})(typeof window==='undefined'?globalThis:window);
