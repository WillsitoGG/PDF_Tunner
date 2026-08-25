import puppeteer from "puppeteer";
import fs from "node:fs";

const [version = "151.0.4129.101", architecture = "x64", output = "webview2-resolver-diagnostic.txt"] = process.argv.slice(2);
const pageUrl = "https://developer.microsoft.com/en-us/microsoft-edge/webview2/?form=MA13LH#download-section";
const allowedHosts = new Set([
  "msedge.sf.dl.delivery.mp.microsoft.com",
  "msedge.b.tlu.dl.delivery.mp.microsoft.com",
]);
const lines = [];
const log = (value = "") => {
  const text = typeof value === "string" ? value : JSON.stringify(value, null, 2);
  lines.push(text);
  console.log(text);
};
const visible = (element) => {
  const rect = element.getBoundingClientRect();
  const style = getComputedStyle(element);
  return rect.width > 0 && rect.height > 0 && style.visibility !== "hidden" && style.display !== "none";
};

async function dumpInteractive(page, label) {
  const rows = await page.evaluate(() =>
    [...document.querySelectorAll("button, a, [role='option'], [role='button'], [role='listbox']")]
      .filter((element) => {
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        return rect.width > 0 && rect.height > 0 && style.visibility !== "hidden" && style.display !== "none";
      })
      .map((element) => ({
        tag: element.tagName,
        id: element.id || "",
        role: element.getAttribute("role") || "",
        text: (element.innerText || element.textContent || "").replace(/\s+/g, " ").trim().slice(0, 180),
        href: element.href || "",
        className: typeof element.className === "string" ? element.className : "",
        ariaExpanded: element.getAttribute("aria-expanded") || "",
      }))
      .filter((item) => item.text || item.href),
  );
  log(`=== ${label} ===`);
  log(rows);
}

async function clickControl(page, candidates, description) {
  const clicked = await page.evaluate(({ candidates }) => {
    const normalize = (value) => (value || "").replace(/\s+/g, " ").trim().toLowerCase();
    const controls = [...document.querySelectorAll("button, [role='button'], a")];
    for (const expected of candidates) {
      const target = controls.find((element) => {
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        if (!(rect.width > 0 && rect.height > 0) || style.visibility === "hidden" || style.display === "none") return false;
        const text = normalize(element.innerText || element.textContent);
        return element.id === expected || text === normalize(expected);
      });
      if (target) {
        target.click();
        return { tag: target.tagName, id: target.id || "", text: (target.innerText || target.textContent || "").trim(), className: target.className || "" };
      }
    }
    return null;
  }, { candidates });
  if (!clicked) throw new Error(`Could not find ${description}: ${candidates.join(" | ")}`);
  log(`Clicked ${description}: ${JSON.stringify(clicked)}`);
  await new Promise((resolve) => setTimeout(resolve, 1200));
}

async function clickExactOption(page, desired, description) {
  const clicked = await page.evaluate((desired) => {
    const normalize = (value) => (value || "").replace(/\s+/g, " ").trim().toLowerCase();
    const selectors = ["button", "[role='option']", "a", "li"];
    for (const selector of selectors) {
      const target = [...document.querySelectorAll(selector)].find((element) => {
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        return rect.width > 0 && rect.height > 0 && style.visibility !== "hidden" && style.display !== "none" && normalize(element.innerText || element.textContent) === normalize(desired);
      });
      if (target) {
        target.click();
        return { tag: target.tagName, id: target.id || "", text: (target.innerText || target.textContent || "").trim(), className: target.className || "" };
      }
    }
    return null;
  }, desired);
  if (!clicked) throw new Error(`Could not find ${description} option: ${desired}`);
  log(`Clicked ${description} option: ${JSON.stringify(clicked)}`);
  await new Promise((resolve) => setTimeout(resolve, 1200));
}

let browser;
try {
  browser = await puppeteer.launch({
    headless: true,
    channel: "chrome",
    args: ["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage"],
  });
  const page = await browser.newPage();
  page.setDefaultTimeout(60_000);

  const interestingNetwork = new Set();
  page.on("request", (request) => {
    const url = request.url();
    if (/webview|edge|download|api|delivery\.mp\.microsoft\.com/i.test(url)) interestingNetwork.add(`REQ ${request.method()} ${url}`);
  });
  page.on("response", (response) => {
    const url = response.url();
    if (/webview|edge|download|api|delivery\.mp\.microsoft\.com/i.test(url)) interestingNetwork.add(`RES ${response.status()} ${url}`);
  });

  log(`Target: ${version} / ${architecture}`);
  log(`Page: ${pageUrl}`);
  await page.goto(pageUrl, { waitUntil: "domcontentloaded", timeout: 90_000 });
  await new Promise((resolve) => setTimeout(resolve, 5000));
  await dumpInteractive(page, "initial interactive DOM");

  await clickControl(page, ["version", "Select Version"], "version control");
  await dumpInteractive(page, "after opening version selector");
  await clickExactOption(page, version, "version");

  await clickControl(page, ["architecture", "Select Architecture"], "architecture control");
  await dumpInteractive(page, "after opening architecture selector");
  await clickExactOption(page, architecture, "architecture");

  await dumpInteractive(page, "after selections");
  await clickControl(page, ["Download"], "download control");
  await dumpInteractive(page, "after opening EULA/download modal");

  const cabCandidates = await page.evaluate(() =>
    [...document.querySelectorAll("a[href]")]
      .map((element) => element.href)
      .filter((href) => /\.cab(?:$|[?#])/i.test(href)),
  );
  log("=== CAB candidates ===");
  log(cabCandidates);

  const accepted = cabCandidates.find((href) => {
    try {
      const parsed = new URL(href);
      return parsed.protocol === "https:" && allowedHosts.has(parsed.hostname.toLowerCase()) && !/PA30|PA19/i.test(parsed.href);
    } catch {
      return false;
    }
  });
  if (!accepted) throw new Error("No approved full Fixed WebView2 CAB URL was exposed by the Microsoft EULA modal.");

  log(`RESOLVED_CAB=${accepted}`);
  log("=== interesting network ===");
  [...interestingNetwork].forEach((entry) => log(entry));
} catch (error) {
  log(`ERROR=${error?.stack || error}`);
  throw error;
} finally {
  fs.writeFileSync(output, `${lines.join("\n")}\n`, "utf8");
  if (browser) await browser.close();
}
