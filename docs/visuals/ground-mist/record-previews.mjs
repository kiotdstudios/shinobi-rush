import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [source,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=await startStaticServer(source,{port:0}),browser=await chromium.launch({headless:true});
const records=[];
try{
 for(const [name,speed,seconds] of [['normal',1,8],['half-speed',.5,16]]){
  const ctx=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block',recordVideo:{dir:out,size:{width:1280,height:720}}});
  const page=await ctx.newPage();await page.goto(server.url+'?mist=review');
  await page.waitForFunction(()=>window.__MIST_REVIEW__?.ready,null,{timeout:90000});
  if(speed===.5){const b=await page.evaluate(()=>JSON.parse(window.__MIST_REVIEW__.buttons_json).Half);await page.mouse.click(b.x,b.y);await page.waitForFunction(()=>window.__MIST_REVIEW__.speed===.5)}
  const start=await page.evaluate(()=>window.__MIST_REVIEW__.clock);
  await page.waitForTimeout(seconds*1000);
  const end=await page.evaluate(()=>window.__MIST_REVIEW__.clock);
  await page.screenshot({path:out+'/'+name+'.png'});
  const video=page.video();await ctx.close();await video.saveAs(out+'/'+name+'.webm');
  records.push({name,speed,wall_seconds:seconds,start_clock:start,end_clock:end});
 }
 writeFileSync(out+'/recordings.json',JSON.stringify(records,null,2));
}finally{await browser.close();await server.close()}
