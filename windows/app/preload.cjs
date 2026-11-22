const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('sugrob', {
  cameras: () => ipcRenderer.invoke('cameras'),
  openCamera: id => ipcRenderer.invoke('open-camera', id),
  state: () => ipcRenderer.invoke('state'),
  update: patch => ipcRenderer.invoke('update', patch),
  select: (city, atmosphere) => ipcRenderer.invoke('select', city, atmosphere),
  search: query => ipcRenderer.invoke('search', query),
  refresh: () => ipcRenderer.invoke('refresh'),
  preview: () => ipcRenderer.invoke('preview'),
  onPreview: callback => { const listener = () => callback(); ipcRenderer.on('preview', listener); return () => ipcRenderer.removeListener('preview', listener); },
  clear: () => ipcRenderer.invoke('clear'),
  quit: () => ipcRenderer.invoke('quit'),
  subscribe: callback => { const listener = (_, state) => callback(state); ipcRenderer.on('state', listener); return () => ipcRenderer.removeListener('state', listener); },
  onEnvironment: callback => { const listener = (_, data) => callback(data); ipcRenderer.on('environment', listener); return () => ipcRenderer.removeListener('environment', listener); },
  onClear: callback => { const listener = () => callback(); ipcRenderer.on('clear', listener); return () => ipcRenderer.removeListener('clear', listener); }
});
