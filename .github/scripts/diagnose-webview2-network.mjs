import puppeteer from 'puppeteer';
import fs from 'node:fs';

const pageUrl = 'https://developer.microsoft.com/en-us/microsoft-edge/webview2?form=MA13LH#download-section';
const targetVersion = '151.0.4129.101';
const output = '.github/diagnostics/webview2-network.txt';
const lines = [];
const record = (line) => {
  const text = String(line);
  lines.push(text);
  console.log(text);
};

let browser;
try {
  browser = await puppeteer.launch({
    headless: true,
    channel: 'chrome',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  page.setDefaultTimeout(60_000);

  const seen = new Set();
  const interesting = (url) => /webview|edge|runtime|download|version|api|delivery\.mp\.microsoft\.com/i.test(url);

  page.on('request', (request) => {
    if (interesting(request.url())) seen.add(`REQ ${request.method()} ${request.url()}`);
  });
  page.on('response', async (response) => {
    const url = response.url();
    if (!interesting(url)) return;
    seen.add(`RES ${response.status()} ${url}`);
    const type = response.request().resourceType();
    if (!['xhr', 'fetch', 'script'].includes(type)) return;
    try {
      const body = await response.text();
      if (/151\.0\.4129\.101|FixedVersionRuntime|WebView2/i.test(body)) {
        const compact = body.replace(/\s+/g, ' ').slice(0, 12000);
        seen.add(`BODY ${response.status()} ${type} ${url} :: ${compact}`);
      }
    } catch {}
  });

  record(`PAGE=${pageUrl}`);
  const main = await page.goto(pageUrl, { waitUntil: 'domcontentloaded', timeout: 90_000 });
  record(`MAIN_STATUS=${main?.status() ?? 'unknown'}`);
  await new Promise((resolve) => setTimeout(resolve, 8000));

  const controls = await page.evaluate(() => [...document.querySelectorAll('button, [role="button"], [role="option"], select, option')]
    .map((el) => ({
      tag: el.tagName,
      id: el.id || '',
      role: el.getAttribute('role') || '',
      text: (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim(),
      dataValue: el.getAttribute('data-value') || '',
      ariaLabel: el.getAttribute('aria-label') || '',
      ariaExpanded: el.getAttribute('aria-expanded') || '',
      className: typeof el.className === 'string' ? el.className : '',
    }))
    .filter((item) => /version|architecture|download|151\.0\.4129\.101|x64/i.test(`${item.id} ${item.text} ${item.dataValue} ${item.ariaLabel}`)));
  record(`CONTROLS=${JSON.stringify(controls)}`);

  const opened = await page.evaluate(() => {
    const normalize = (value) => (value || '').replace(/\s+/g, ' ').trim().toLowerCase();
    const candidates = [...document.querySelectorAll('button, [role="button"]')];
    const target = candidates.find((el) => el.id === 'version' || /select version|version/.test(normalize(el.innerText || el.textContent || el.getAttribute('aria-label'))));
    if (!target) return null;
    target.click();
    return { tag: target.tagName, id: target.id || '', text: (target.innerText || target.textContent || '').trim(), className: target.className || '' };
  });
  record(`VERSION_CONTROL_CLICK=${JSON.stringify(opened)}`);
  await new Promise((resolve) => setTimeout(resolve, 5000));

  const options = await page.evaluate((targetVersion) => [...document.querySelectorAll('[role="option"], option, button, li, a')]
    .map((el) => ({
      tag: el.tagName,
      id: el.id || '',
      role: el.getAttribute('role') || '',
      text: (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim(),
      dataValue: el.getAttribute('data-value') || '',
      className: typeof el.className === 'string' ? el.className : '',
    }))
    .filter((item) => item.text === targetVersion || item.dataValue === targetVersion || /151\.0\.4129\.101/.test(`${item.text} ${item.dataValue}`)), targetVersion);
  record(`TARGET_OPTIONS=${JSON.stringify(options)}`);

  for (const entry of [...seen].sort()) record(entry);
} catch (error) {
  record(`ERROR=${error?.stack || error}`);
  process.exitCode = 1;
} finally {
  fs.mkdirSync('.github/diagnostics', { recursive: true });
  fs.writeFileSync(output, `${lines.join('\n')}\n`, 'utf8');
  if (browser) await browser.close();
}
