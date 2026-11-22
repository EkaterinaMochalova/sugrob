const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('sugrob', {
  cameras: () => ipcRenderer.invoke('cameras'),
  cameraLayout: (key,bounds) => ipcRenderer.invoke('camera-layout',key,bounds),
  cameraReload: () => ipcRenderer.invoke('camera-reload'),
  onCameraStatus: callback => ipcRenderer.on('camera-status',(_,value)=>callback(value)),
  onCameraCollapse: callback => ipcRenderer.on('camera-collapse',()=>callback()),
  onCameraLayout: callback => ipcRenderer.on('camera-layout',()=>callback()),
  state: () => ipcRenderer.invoke('state'),
  update: patch => ipcRenderer.invoke('update', patch),
  select: (city, atmosphere, preserveSource = true) => ipcRenderer.invoke('select', city, atmosphere, preserveSource),
  search: query => ipcRenderer.invoke('search', query),
  refresh: () => ipcRenderer.invoke('refresh'),
  previewLightning: () => ipcRenderer.invoke('preview-lightning'),
  onLightningPreview: callback => { const listener = () => callback(); ipcRenderer.on('preview-lightning', listener); return () => ipcRenderer.removeListener('preview-lightning', listener); },
  preview: () => ipcRenderer.invoke('preview'),
  onPreview: callback => { const listener = () => callback(); ipcRenderer.on('preview', listener); return () => ipcRenderer.removeListener('preview', listener); },
  clear: () => ipcRenderer.invoke('clear'),
  quit: () => ipcRenderer.invoke('quit'),
  subscribe: callback => { const listener = (_, state) => callback(state); ipcRenderer.on('state', listener); return () => ipcRenderer.removeListener('state', listener); },
  onEnvironment: callback => { const listener = (_, data) => callback(data); ipcRenderer.on('environment', listener); return () => ipcRenderer.removeListener('environment', listener); },
  onClear: callback => { const listener = () => callback(); ipcRenderer.on('clear', listener); return () => ipcRenderer.removeListener('clear', listener); }
});
