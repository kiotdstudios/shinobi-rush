import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync} from 'node:fs';
const out=process.argv[3];mkdirSync(out,{recursive:true});
const server=await startStaticServer(process.argv[2],{port:0});
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
try{
 for(const frame of [0,24,96]){
  await page.goto(server.url+'?frame='+frame);
  await page.waitForFunction(()=>window.__ASHEN_REVIEW__?.buttons_json,null,{timeout:60000});
  for(const name of ['Ash','Root glow']){
   const b=await page.evaluate(n=>JSON.parse(window.__ASHEN_REVIEW__.buttons_json)[n],name);
   await page.mouse.click(b.x,b.y);await page.waitForTimeout(120);
  }
  await page.waitForTimeout(200);
  await page.screenshot({path:out+'/wind-'+frame+'.png'});
 }
}finally{await browser.close();await server.close()}
