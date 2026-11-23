'use strict';
window.RainGlass = class {
 constructor(){this.drops=[];this.wait=5;this.active=false;this.w=1;this.h=1;this.strength=1;}
 configure(active,w,h,strength){this.active=active;this.w=w;this.h=h;this.strength=strength;if(!active)this.clear();}
 clear(){this.drops=[];this.wait=5;}
 reduced(){return typeof matchMedia==='function'&&matchMedia('(prefers-reduced-motion: reduce)').matches;}
 burst(){
  if(this.w<=1||this.h<=1)return;
  for(let i=0,n=Math.min(3,7-this.drops.length);i<n;i++)this.drops.push({x:this.w*(.1+Math.random()*.8),y:this.h*(.07+Math.random()*.48),r:2.2+Math.random()*2,age:0,hold:.7+Math.random()*1.8,life:12+Math.random()*7,phase:Math.random()*6.28,v:0,points:[]});
 }
 preview(){if(!this.active||this.reduced())return;this.burst();this.wait=20+Math.random()*18;}
 tick(dt){
  if(!this.active)return;if(this.reduced()){this.clear();return;}
  this.wait-=dt;if(this.wait<=0){this.burst();this.wait=20+Math.random()*18;}
  this.drops=this.drops.filter(d=>{
   d.age+=dt;if(d.age>d.life||d.y>this.h+12)return false;
   if(d.age>d.hold){const target=28+30*Math.max(0,Math.sin(d.age*1.3+d.phase));d.v+=(target-d.v)*Math.min(1,dt*1.8);d.y+=d.v*dt;d.x+=Math.sin(d.age*.8+d.phase)*dt*2;}
   const last=d.points.at(-1);if(!last||Math.hypot(last[0]-d.x,last[1]-d.y)>2)d.points.push([d.x,d.y]);
   if(d.points.length>28)d.points.shift();return true;
  });
 }
 draw(c){
  c.save();
  for(const d of this.drops){
   c.globalAlpha=this.strength*Math.min(1,d.age/.8)*Math.min(1,Math.max(0,(d.life-d.age)/2));
   c.lineCap='round';c.lineWidth=.75;c.strokeStyle='rgba(217,217,217,.12)';c.beginPath();
   d.points.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.stroke();
   const stretch=1+Math.min(.65,d.v/90);
   c.lineWidth=.7;c.strokeStyle='rgba(31,31,31,.19)';c.fillStyle='rgba(255,255,255,.025)';
   c.beginPath();c.ellipse(d.x,d.y,d.r,d.r*stretch,0,0,Math.PI*2);c.fill();c.stroke();
   c.strokeStyle='rgba(255,255,255,.4)';c.beginPath();c.moveTo(d.x-d.r*.65,d.y+d.r*.4);
   c.quadraticCurveTo(d.x-d.r*.5,d.y+d.r*stretch,d.x+d.r*.25,d.y+d.r*stretch*.7);c.stroke();
  }
  c.restore();
 }
};
