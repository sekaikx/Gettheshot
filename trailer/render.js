const { chromium } = require('playwright');
(async () => {
  const args = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => console.log('console:', m.text()));
  page.on('pageerror', e => console.log('ERR', e.message));
  await page.goto('file://' + __dirname + '/trailer.html');
  const times = args[0] === 'all' ? [...Array(900).keys()].map(i => i / 30) : args.map(Number);
  for (let i = 0; i < times.length; i++) {
    await page.evaluate(t => draw(t), times[i]);
    const name = args[0] === 'all' ? `frames/f${String(i).padStart(4, '0')}.jpg` : `preview_${times[i]}.jpg`;
    await page.screenshot({ path: name, type: 'jpeg', quality: 92 });
  }
  await browser.close();
})();
