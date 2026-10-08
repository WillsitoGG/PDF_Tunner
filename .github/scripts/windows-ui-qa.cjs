'use strict';
const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require('playwright-core');
const evidence=process.argv[2], fixture=process.argv[3];
const report={sourceRun:129,mode:'native-Tauri-WebView2-CDP',start:new Date().toISOString()};
(async function(){
  let browser;
  try {
    browser=await chromium.connectOverCDP('http://127.0.0.1:9222',{timeout:20000});
    let pages=browser.contexts().flatMap(c=>c.pages());
    for(let i=0;i<15&&pages.length===0;i++){
      await new Promise(resolve=>setTimeout(resolve,1000));
      pages=browser.contexts().flatMap(c=>c.pages());
    }
    report.tabs=await Promise.all(pages.map(async p=>({url:p.url(),title:await p.title().catch(()=>null)})));
    const page=pages.find(p=>/tauri|localhost|127\.0\.0\.1/i.test(p.url()))||pages[0];
    if(!page)throw new Error('No WebView2 application page rendered');
    await page.locator('body').waitFor({state:'visible',timeout:30000});
    await page.waitForTimeout(4000);
    report.title=await page.title();
    report.url=page.url();
    report.content=(await page.locator('body').innerText()).slice(0,10000);
    report.controls=await page.locator('button,a,[role="button"]').count();
    try{await page.screenshot({path:path.join(evidence,'webview2-ui.png'),timeout:15000});report.screenshot=true;}
    catch(err){report.screenshotError=String(err);}
    if(report.content.trim().length<30||report.controls<3)throw new Error('Rendered UI lacks real text/controls');
    const input=page.locator('input[type="file"]');
    report.fileInputCount=await input.count();
    if(report.fileInputCount){
      await input.first().setInputFiles(fixture,{timeout:15000});
      await page.waitForTimeout(4000);
      const changed=(await page.locator('body').innerText()).slice(0,10000);
      report.fileUploadAttempted=true;
      report.fileNameVisible=changed.includes(path.basename(fixture));
      report.bodyChanged=changed!==report.content;
      try{await page.screenshot({path:path.join(evidence,'webview2-after-upload.png'),timeout:15000});}catch{}
    } else {report.fileUploadAttempted=false;report.note='PDF input not visible at landing page: file-open flow not certified';}
    report.status='PASS_UI_RENDER';
  } catch(err){report.status='FAIL';report.error=String(err);process.exitCode=1;}
  finally {
    report.finished=new Date().toISOString();
    fs.writeFileSync(path.join(evidence,'ui-result.json'),JSON.stringify(report,null,2));
    if(browser)await browser.close().catch(()=>{});
  }
})().catch(err=>{process.stderr.write(String(err));process.exitCode=1;});
