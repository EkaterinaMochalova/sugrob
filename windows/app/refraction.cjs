'use strict';
// One short-lived in-memory sample shared by displays. No disk/network I/O.
class RefractionCapture {
 constructor(capturer,now=()=>Date.now()){this.capturer=capturer;this.now=now;this.frame=null;this.at=0;this.pending=null;this.generation=0;}
 clear(){this.generation++;this.frame=null;this.at=0;}
 async get(displayID){
  if(this.frame&&this.now()-this.at<220)return this.pick(displayID);
  if(!this.pending){
   const generation=this.generation;
   this.pending=this.capturer.getSources({types:['screen'],thumbnailSize:{width:1920,height:1920},fetchWindowIcons:false})
    .then(sources=>{if(generation===this.generation){this.frame=sources;this.at=this.now();}})
    .catch(()=>{this.frame=null;}).finally(()=>{this.pending=null;});
  }
  await this.pending;
  return this.pick(displayID);
 }
 pick(id){const source=this.frame?.find(s=>s.display_id===String(id));return source&&!source.thumbnail.isEmpty()?source.thumbnail.toDataURL():null;}
}
module.exports={RefractionCapture};
