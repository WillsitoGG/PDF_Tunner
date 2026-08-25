import puppeteer from "puppeteer";

const [version, architecture] = process.argv.slice(2);
const allowedArchitectures = new Set(["x64", "x86", "arm64"]);
const allowedHosts = new Set([
  "msedge.sf.dl.delivery.mp.microsoft.com",
  "msedge.b.tlu.dl.delivery.mp.microsoft.com",
]);

if (!version || !/^\d+\.\d+\.\d+\.\d+$/.test(version)) {
  throw new Error("Usage: node pdf-tunner-resolve-webview2-fixed.mjs <version> <x64|x86|arm64>");
}
if (!allowedArchitectures.has(architecture)) {
  throw new Error(`Unsupported WebView2 architecture: ${architecture ?? "<missing>"}`);
}

const downloadPage = "https://developer.microsoft.com/en-us/microsoft-edge/webview2";
const normalize = (value) => value.replace(/\s+/g, " ").trim().toLowerCase();

async function launchBrowser() {
  const options = {
    headless: true,
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-blink-features=AutomationControlled",
    ],
  };

  try {
    return await puppeteer.launch({ ...options, channel: "chrome" });
  } catch (error) {
    console.error(`Installed Chrome launch failed; using Puppeteer's browser: ${error.message}`);
    return await puppeteer.launch(options);
  }
}

const browser = await launchBrowser();
try {
  const page = await browser.newPage();
  page.setDefaultTimeout(60_000);
  await page.goto(downloadPage, { waitUntil: "domcontentloaded", timeout: 90_000 });

  async function selectField(id, desiredText) {
    const selector = `button#${id}`;
    await page.waitForSelector(selector);
    const current = await page.$eval(selector, (element) => element.innerText);
    if (normalize(current) === normalize(desiredText)) return;

    await page.click(selector);
    await page.waitForFunction(
      (desired) =>
        [...document.querySelectorAll("button.px-dropdown__item")].some((item) => {
          const rect = item.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0 && item.innerText.trim().toLowerCase() === desired.toLowerCase();
        }),
      {},
      desiredText,
    );

    const clicked = await page.evaluate((desired) => {
      const item = [...document.querySelectorAll("button.px-dropdown__item")].find((candidate) => {
        const rect = candidate.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0 && candidate.innerText.trim().toLowerCase() === desired.toLowerCase();
      });
      if (!item) return false;
      item.click();
      return true;
    }, desiredText);

    if (!clicked) throw new Error(`WebView2 ${id} option was not found: ${desiredText}`);

    await page.waitForFunction(
      (fieldId, desired) => {
        const field = document.querySelector(`button#${fieldId}`);
        return field && field.innerText.trim().toLowerCase() === desired.toLowerCase();
      },
      {},
      id,
      desiredText,
    );
  }

  await selectField("version", version);
  await selectField("architecture", architecture);

  const downloadButton =
    "button.common-button.common-button--icon-after.block-webview2__download-button.block-webview2__download-button";
  await page.waitForSelector(downloadButton);
  await page.click(downloadButton);

  const eulaDownloadLink =
    "a.common-button-v1.common-button-v1--null.webview-eula-popup__button.webview-eula-popup__button";
  await page.waitForSelector(eulaDownloadLink);
  const href = await page.$eval(eulaDownloadLink, (element) => element.href);

  const resolved = new URL(href);
  const host = resolved.hostname.toLowerCase();
  if (resolved.protocol !== "https:" || !allowedHosts.has(host)) {
    throw new Error(`Refusing WebView2 URL outside approved Microsoft Edge CDN hosts: ${resolved.href}`);
  }
  if (!resolved.pathname.toLowerCase().endsWith(".cab")) {
    throw new Error(`Resolved WebView2 payload is not a CAB archive: ${resolved.href}`);
  }
  if (/PA30|PA19/i.test(resolved.href)) {
    throw new Error(`Resolved WebView2 payload appears to be a delta package: ${resolved.href}`);
  }

  process.stdout.write(resolved.href);
} finally {
  await browser.close();
}
