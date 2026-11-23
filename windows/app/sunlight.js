'use strict';
window.Sunlight = class {
 constructor(){this.active=false;this.test=false;this.age=-1;this.wait=180+Math.random()*240;this.clock=0;this.settings={};}
 configure(active,s){if(active!==this.active || JSON.stringify(s.city)!==JSON.stringify(this.settings.city)){this.age=-1;this.test=false;this.wait=180+Math.random()*240;}this.active=active;this.settings=s;}
 preview(){this.test=true;this.age=0;}
 light(){if(this.test)return 'day';if(this.settings.city)return window.Sugrob.mood(this.settings.city).light;const h=new Date().getHours();return h<6||h>=21?'night':h<9?'dawn':h>=17?'dusk':'day';}
 reduced(){return typeof matchMedia==='function'&&matchMedia('(prefers-reduced-motion: reduce)').matches;}
 tick(dt){if(!this.reduced())this.clock+=dt;if(this.age>=0){this.age+=dt;if(this.age>=20){this.age=-1;this.test=false;this.wait=180+Math.random()*240;}}else if(this.active&&this.settings.sunDust!==false&&this.light()!=='night'&&!this.reduced()){this.wait-=dt;if(this.wait<=0)this.age=0;}}
 draw(c,w,h){if(!this.active&&!this.test)return;const light=this.light(),night=light==='night',color=night?'184,204,255':light==='dusk'?'255,166,79':light==='dawn'?'255,217,143':'255,247,219',s=Math.min(w/1000,h/700),strength=this.settings.opacity??.9,pulse=this.age>=0?Math.min(1,this.age/4)*Math.min(1,(20-this.age)/5):0;
 const ellipse=(x,y,rx,ry,angle,alpha)=>{c.save();c.translate(x,y);c.rotate(angle);c.scale(rx,ry);const g=c.createRadialGradient(0,0,0,0,0,1);g.addColorStop(0,`rgba(${color},${alpha*strength})`);g.addColorStop(.45,`rgba(${color},${alpha*strength*.24})`);g.addColorStop(.7,`rgba(${color},${alpha*strength*.035})`);g.addColorStop(.9,`rgba(${color},${alpha*strength*.001})`);g.addColorStop(1,`rgba(${color},0)`);c.fillStyle=g;c.beginPath();c.arc(0,0,1,0,Math.PI*2);c.fill();c.restore();};
 ellipse(25*s,20*s,320*s,230*s,0,night?.035:.14+pulse*.04);
 if(!night)for(let i=0;i<3;i++)ellipse((135+i*75)*s,(175+i*45)*s,(120+i*45+pulse*55)*s/2,(560+i*90)*s/2,-.4-i*.11-Math.sin(this.clock/22+i)*.025,.055+pulse*.08);
 if(!night&&this.settings.sunDust!==false&&!this.reduced()&&pulse>0)for(let i=0;i<32;i++){const phase=i*2.39996,u=Math.sin(phase+this.clock*.11)*.85,v=Math.sin(phase*1.7+this.clock*.06)*.9,mask=Math.max(0,1-u*u-v*v),x=u*75,y=v*260;ellipse((210+x*Math.cos(.5)-y*Math.sin(.5))*s,(240-x*Math.sin(.5)-y*Math.cos(.5))*s,(1.5+i%5*.55)*s/2,(1.5+i%5*.55)*s/2,0,pulse*mask*.36);}
 }
};
