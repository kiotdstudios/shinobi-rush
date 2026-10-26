import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [dir,out]=process.argv.slice(2);const server=await startStaticServer(dir,{port:0});const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
try{
 for(const mode of ['normal','half-speed']){
  const target=out+'/'+mode;mkdirSync(target,{recursive:true});
  await page.goto(server.url+'?kunai=recovery');await page.waitForFunction(()=>window.__KUNAI_RECOVERY__?.ready,null,{timeout:90000});
  const click=async name=>{const b=await page.evaluate(n=>JSON.parse(window.__KUNAI_RECOVERY__.buttons_json)[n],name);await page.mouse.click(b.x,b.y)};
  if(mode==='half-speed')await click('Half');
  const times=[];const t0=Date.now();
  for(let i=0;i<85;i++){
   if(i===3)await click('Character');if(i===15)await click('Miss');if(i===45)await click('Surface');
   times.push(Date.now()-t0);await page.screenshot({path:target+'/'+String(i).padStart(3,'0')+'.png'});await page.waitForTimeout(40);
  }
  writeFileSync(target+'/times.json',JSON.stringify(times));
 }
}finally{await browser.close();await server.close()}
