'use strict';
const leafImages = ['ochre','rust','olive'].map(name => { const image = new Image(); image.src = `assets/leaf-${name}.png`; return image; });
window.SugrobArt = {
  rgba: (t, a) => `rgba(${t.join(',')},${a})`,
  backdrop(c, w, h, m) {
    const color = m.overcast ? [196, 196, 196] : m.tint;
    const strength = m.precipitation ? .1 : m.light === 'night' ? .18 : .25;
    for (const [x, y] of [[w * .1, 0], [w, h * .88]]) {
      const g = c.createRadialGradient(x, y, 0, x, y, Math.min(w * .52, h * .65));
      g.addColorStop(0, this.rgba(color, strength)); g.addColorStop(1, this.rgba(color, 0));
      c.fillStyle = g; c.fillRect(0, 0, w, h);
    }
    if (m.fog) { const g = c.createLinearGradient(0, h, 0, h * .75); g.addColorStop(0, 'rgba(255,255,255,.10)'); g.addColorStop(1, 'rgba(255,255,255,0)'); c.fillStyle = g; c.fillRect(0, 0, w, h); }
  },
  particle(c, kind, x, y, size, rotation, tint, alpha) {
    c.save(); c.translate(x, y); c.rotate(rotation); c.scale(size / 20, size / 20);
    c.globalAlpha *= alpha; c.fillStyle = tint; c.strokeStyle = tint; c.lineWidth = 1;
    c.beginPath();
    if (kind === 'rain') { const g=c.createLinearGradient(0,-8,0,8); g.addColorStop(0,'rgba(255,255,255,0)'); g.addColorStop(.65,tint); g.addColorStop(1,'rgba(255,255,255,0)'); c.strokeStyle=g; c.lineCap='round'; c.moveTo(0,-8); c.lineTo(0,8); c.stroke(); }
    else if (kind === 'leaves') {
      const index = ['#d59746','#b96d39','#dec178'].indexOf(tint);
      const image = leafImages[Math.max(0,index)];
      c.scale(.35+.65*Math.abs(Math.sin(rotation*2+index)),1);
      if (image.complete && image.naturalWidth) c.drawImage(image,-10*image.naturalWidth/image.naturalHeight,-10,20*image.naturalWidth/image.naturalHeight,20);
    }
    else if (kind === 'snow') { c.arc(0, 0, 2.3, 0, Math.PI * 2); c.fill(); }
    else if (kind === 'gull') { c.moveTo(-12, 0); c.quadraticCurveTo(-6, -7, 0, 0); c.quadraticCurveTo(6, -7, 12, 0); c.stroke(); }
    else if (kind === 'glint') {
      const g = c.createRadialGradient(0, 0, 0, 0, 0, 8); g.addColorStop(0, tint); g.addColorStop(1, 'rgba(255,255,255,0)'); c.fillStyle = g; c.fillRect(-8, -8, 16, 16);
    } else if (kind === 'petal' || kind === 'petals') { c.moveTo(0, -8); c.bezierCurveTo(-12, -2, -7, 12, 0, 8); c.bezierCurveTo(10, 11, 12, -3, 0, -8); c.fill(); }
    else { c.moveTo(-7, -8); c.quadraticCurveTo(kind === 'olive' ? -6 : -16, 10, 8, 8); c.quadraticCurveTo(kind === 'olive' ? 6 : 16, -10, -7, -8); c.fill(); }
    c.restore();
  }
};
