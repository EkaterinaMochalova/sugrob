'use strict';
// Overlays never become focusable. Mouse hit testing does not require keyboard focus.
const states = new WeakMap();
function state(win) {
  if (!states.has(win)) states.set(win, { ignore: true, protected: undefined, canDrag: false });
  return states.get(win);
}
function input(win, interactive) {
  if (!win || win.isDestroyed()) return;
  const s = state(win), ignore = !(s.canDrag && interactive === true);
  if (s.ignore !== ignore) {
    win.setIgnoreMouseEvents(ignore, {forward:true});
    s.ignore = ignore;
  }
}
function configure(win, {hideCapture, canDrag}) {
  if (!win || win.isDestroyed()) return;
  const s = state(win);
  s.canDrag = canDrag;
  if (s.protected !== hideCapture) {
    win.setContentProtection(hideCapture);
    s.protected = hideCapture;
  }
  if (!canDrag) input(win, false);
}
function visibility(win, visible) {
  if (!win || win.isDestroyed()) return;
  if (visible && !win.isVisible()) win.showInactive();
  else if (!visible && win.isVisible()) win.hide();
}
module.exports = {configure,input,visibility};
