import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir')??'build/grass-loop';mkdirSync(out,{recursive:true});
const server=await startStaticServer(arg('serve-dir')??'../wind-grass-web-3',{port:0}),browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage({viewport:{width:1280,height:720}});
 await page.goto(server.url+'?grass=review');await page.waitForFunction(()=>window.__GRASS_STATE__?.sample_cells===9);
 await page.mouse.click(203,649);await page.waitForFunction(()=>window.__GRASS_STATE__.paused);
 await page.mouse.click(224,689);await page.waitForFunction(()=>window.__GRASS_STATE__.selected==='blade');
 await page.mouse.click(410,649);await page.waitForFunction(()=>window.__GRASS_STATE__.strength>1.5);
 const start=await page.evaluate(()=>window.__GRASS_STATE__.phase),hashes=[];
 for(let i=0;i<144;i++){
  await page.waitForFunction(expected=>window.__GRASS_STATE__.phase===expected,(start+i)%144);
  const png=await page.screenshot({clip:{x:510,y:250,width:270,height:295},path:`${out}/${String(i).padStart(3,'0')}.png`});
  hashes.push(createHash('sha256').update(png).digest('hex'));await page.mouse.click(258,649);
 }
 await page.waitForFunction(expected=>window.__GRASS_STATE__.phase===expected,start);
 writeFileSync(out+'/capture.json',JSON.stringify({frames:144,start_phase:start,returned_phase:await page.evaluate(()=>window.__GRASS_STATE__.phase),unique:new Set(hashes).size,hashes},null,2));
 console.log('144 real grass wind renders; unique',new Set(hashes).size);
}finally{await browser.close();await server.close()}
