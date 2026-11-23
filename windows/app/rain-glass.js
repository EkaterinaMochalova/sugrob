'use strict';
const waterLenses=[0,1,2].map(i=>{const im=new Image();im.src='assets/water-lens-'+i+'.png';return im;});
window.RainGlass = class {
 constructor(){this.drops=[];this.wait=5;this.active=false;this.w=1;this.h=1;this.strength=1;this.age=100;this.desktop=null;}
 configure(active,w,h,strength){this.active=active;this.w=w;this.h=h;this.strength=strength;if(!active)this.clear();}
 setDesktop(image){this.desktop=image;}
 clear(){this.desktop=null;this.drops=[];this.wait=5;this.age=100;}
 reduced(){return typeof matchMedia==='function'&&matchMedia('(prefers-reduced-motion: reduce)').matches;}
 drop(x,y,r,moving){return {x,y,r,moving,age:0,hold:.8+Math.random()*2,phase:Math.random()*6.28,v:0,points:[],variant:Math.floor(Math.random()*3),absorbed:false};}
 burst(){
  if(this.w<=1||this.h<=1)return;
  this.age=0;this.drops=[];
  for(let i=0;i<3;i++){
   const x=this.w*(.12+i*.32+(Math.random()-.5)*.1),y=this.h*(.08+Math.random()*.24);
   this.drops.push(this.drop(x,y,7+Math.random()*3,true));
   // Beads on the route are collected by the larger drop.
   for(let j=1;j<6;j++)this.drops.push(this.drop(x+(Math.random()-.5)*10,y+j*65,1.5+Math.random()*2.5,false));
  }
  for(let i=0;i<35;i++)this.drops.push(this.drop(this.w*Math.random(),this.h*Math.random(),.8+Math.random()*3.4,false));
 }
 preview(){if(!this.active||this.reduced())return;this.burst();this.wait=38+Math.random()*20;}
 tick(dt){
  if(!this.active)return;if(this.reduced()){this.clear();return;}
  this.age+=dt;this.wait-=dt;
  if(this.wait<=0){this.burst();this.wait=38+Math.random()*20;}
  if(this.age>18){this.drops=[];return;}
  for(const d of this.drops){
   d.age+=dt;
   if(!d.moving||d.absorbed)continue;
   const oldY=d.y;
   if(d.age>d.hold){
    const target=Math.sin(d.age*1.45+d.phase)>.6?10:55+d.r*6;
    d.v+=(target-d.v)*Math.min(1,dt*2.5);
    d.y+=d.v*dt;d.x+=Math.sin(d.y*.027+d.phase)*dt*8;
   }
   for(const b of this.drops)if(!b.moving&&!b.absorbed&&b.y>=oldY-d.r&&b.y<=d.y+d.r&&Math.abs(b.x-d.x)<d.r+b.r){
    b.absorbed=true;d.r=Math.min(13,Math.sqrt(d.r*d.r+b.r*b.r*.65));d.v+=12;
   }
   const last=d.points.at(-1);if(!last||Math.hypot(last[0]-d.x,last[1]-d.y)>4)d.points.push([d.x,d.y,this.age]);
   d.points=d.points.filter(p=>this.age-p[2]<2.4).slice(-60);
  }
  this.drops=this.drops.filter(d=>!d.absorbed&&d.y<this.h+30);
 }
 draw(c){
  const pulse=Math.min(1,this.age/1.5)*Math.min(1,Math.max(0,(18-this.age)/3));
  if(pulse<=0)return;
  c.save();
  for(const d of this.drops){
   const alpha=this.strength*pulse;
   c.lineCap='butt';
   for(let i=1;i<d.points.length;i++){
    const a=d.points[i-1],b=d.points[i],fade=Math.max(0,1-(this.age-b[2])/2.4);
    c.globalAlpha=alpha*fade;
    c.lineWidth=d.r*.4;c.strokeStyle='rgba(20,26,30,.09)';c.beginPath();c.moveTo(a[0],a[1]);c.lineTo(b[0],b[1]);c.stroke();
    c.lineWidth=.65;c.strokeStyle='rgba(255,255,255,.12)';c.beginPath();c.moveTo(a[0]+d.r*.18,a[1]);c.lineTo(b[0]+d.r*.18,b[1]);c.stroke();
   }
   c.globalAlpha=alpha*(d.moving?.9:.7);
   const im=waterLenses[d.variant],stretch=d.moving?1+Math.min(.4,d.v/400):1;
   if(this.desktop){
    const frame=this.desktop,rx=d.r,ry=d.r*stretch,sx=frame.naturalWidth/this.w,sy=frame.naturalHeight/this.h;
    // Nested lens zones: stronger magnification at the centre, near-neutral at the rim.
    // Draw outer-to-inner so the union remains an ellipse, never a screenshot rectangle.
    for(let ring=10;ring>=1;ring--){
     const r=ring/10,factor=.62+.42*r*r;
     c.save();c.beginPath();c.ellipse(d.x,d.y,rx*r,ry*r,0,0,Math.PI*2);c.clip();
     c.drawImage(frame,(d.x-rx*r*factor)*sx,(d.y-ry*r*factor)*sy,rx*r*2*factor*sx,ry*r*2*factor*sy,d.x-rx*r,d.y-ry*r,rx*r*2,ry*r*2);c.restore();
    }
   }
   if(im.complete&&im.naturalWidth)c.drawImage(im,d.x-d.r*1.55,d.y-d.r*1.55*stretch,d.r*3.1,d.r*3.1*stretch);
  }
  c.restore();
 }
};
