// node Icon/render.js  -> renders icon.svg / icon-ios.svg to PNGs (needs `playwright` with Chromium).
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const b = await chromium.launch();
  const out = process.argv[2] || __dirname;
  const job = async (svg, size, file, transparent) => {
    const p = await b.newPage({ viewport: { width: size, height: size }, deviceScaleFactor: 1 });
    const s = fs.readFileSync(path.join(__dirname, svg), 'utf8').replace('width="1024" height="1024"', `width="${size}" height="${size}"`);
    await p.setContent(`<body style="margin:0;background:transparent">${s}</body>`);
    await p.screenshot({ path: path.join(out, file), omitBackground: transparent });
    await p.close();
  };
  fs.mkdirSync(out, { recursive: true });
  for (const s of [16, 32, 64, 128, 256, 512, 1024]) await job('icon.svg', s, `mac-${s}.png`, true);
  await job('icon-ios.svg', 1024, 'ios-1024.png', false);
  await b.close();
})();
