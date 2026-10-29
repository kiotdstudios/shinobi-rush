import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [source,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=await startStaticServer(source);
const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block',recordVideo:{dir:out,size:{width:1280,height:720}}});
const page=await context.newPage(),errors=[],started=Date.now(),segments=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
await page.goto(server.url+'?waterlife=review');
await page.waitForFunction(()=>window.__WATERLIFE__?.ready,null,{timeout:120000});
for(const [name,key,duration] of [['normal','Normal',5000],['half-speed','Half',8500]]){
 const button=await page.evaluate(key=>JSON.parse(window.__WATERLIFE__.buttons_json)[key],key);
 await page.mouse.click(button.x,button.y);const begin=(Date.now()-started)/1000;
 await page.waitForTimeout(duration);segments.push({name,begin,end:(Date.now()-started)/1000});
 await page.screenshot({path:out+'/'+name+'.png'});
}
const video=page.video();await context.close();await video.saveAs(out+'/review.webm');await browser.close();await server.close();
writeFileSync(out+'/capture.json',JSON.stringify({segments,errors},null,2));console.log(JSON.stringify({segments,errors}));process.exit(errors.length?1:0);
