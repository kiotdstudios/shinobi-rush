import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [source,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=await startStaticServer(source,{port:0});const browser=await chromium.launch({headless:true});
try{
 for(const [name,mode,speed,ms] of [['before','Before','Normal',7400],['normal','After','Normal',7400],['half-speed','After','Half',14800]]){
  const context=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block',recordVideo:{dir:out,size:{width:1280,height:720}}});const page=await context.newPage();
  await page.goto(server.url+'?flicker=review');await page.waitForFunction(()=>window.__BODY_FLICKER__?.ready,null,{timeout:30000});
  const click=async n=>{const b=await page.evaluate(k=>JSON.parse(window.__BODY_FLICKER__.buttons_json)[k],n);await page.mouse.click(b.x,b.y)};
  await click(mode);await click(speed);await click('All 8');await page.waitForTimeout(ms);
  const final=await page.evaluate(()=>({...window.__BODY_FLICKER__}));if(final.player_count<8)throw new Error('Autoplay failed: '+JSON.stringify(final));const video=page.video();await context.close();await video.saveAs(out+'/'+name+'.webm');
  writeFileSync(out+'/'+name+'.json',JSON.stringify({mode,speed,recorded_ms:ms,extract_tail_seconds:ms/1000-.2,source:'Playwright real compositor recording, 25 FPS; extract 24 FPS, no interpolation'},null,2));console.log(name+' recorded');
 }
}finally{await browser.close();await server.close()}
