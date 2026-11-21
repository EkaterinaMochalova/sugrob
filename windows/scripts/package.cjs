const path = require('node:path');
(async () => {
  const { packager } = await import('@electron/packager');
  const arch = process.env.SUGROB_ARCH || 'x64';
  if (!['x64', 'arm64'].includes(arch)) throw new Error('SUGROB_ARCH must be x64 or arm64');
  const output = await packager({ dir: path.join(__dirname, '..'), name: 'Sugrob', executableName: 'Sugrob',
    platform: 'win32', arch, electronVersion: '45.4.1', asar: true, overwrite: true,
    electronZipDir: process.env.SUGROB_ELECTRON_ZIPS,
    out: path.join(__dirname, '..', 'dist'), icon: path.join(__dirname, '..', 'app', 'icon.ico'),
    ignore: [/^\/app\/assets\/.*\.wav$/, /^\/app\/city-media($|\/)/, /^\/dist($|\/)/, /^\/test($|\/)/, /^\/scripts($|\/)/, /^\/node_modules($|\/)/],
    win32metadata: { ProductName: 'Сугроб', FileDescription: 'Sugrob — погода и атмосфера городов' }
  });
  console.log(output.join('\n'));
})().catch(error => { console.error(error); process.exit(1); });
