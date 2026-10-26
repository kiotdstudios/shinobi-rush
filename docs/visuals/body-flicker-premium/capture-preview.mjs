import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [source,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=await startStaticServer(source,{port:0});const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
 await page.goto(server.url+'?flicker=review');await page.waitForFunction(()=>window.__BODY_FLICKER__?.ready,null,{timeout:30000});
 const click=async name=>{const b=await page.evaluate(n=>JSON.parse(window.__BODY_FLICKER__.buttons_json)[n],name);await page.mouse.click(b.x,b.y)};
 for(const [name,mode,speed] of [['before','Before','Normal'],['normal','After','Normal'],['half-speed','After','Half']]){
  const dir=out+'/'+name;mkdirSync(dir,{recursive:true});await click(mode);await click(speed);await click('All 8');
  const timings=[];const start=Date.now();
  const duration=name==='half-speed'?14500:7300;
  while(Date.now()-start<duration){const t=Date.now();const n=timings.length;await page.screenshot({path:dir+'/'+String(n).padStart(4,'0')+'.png'});timings.push(t);await page.waitForTimeout(35)}
  writeFileSync(dir+'/timings.json',JSON.stringify(timings));
 }
}finally{await browser.close();await server.close()}
