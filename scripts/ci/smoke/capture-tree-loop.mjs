import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const output='build/trees-loop';mkdirSync(output,{recursive:true});
const server=await startStaticServer('../blossom-trees-web-3',{port:0});
const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage({viewport:{width:1280,height:720}});
 await page.goto(server.url+'?trees=review');
 await page.waitForFunction(()=>window.__BLOSSOM_STATE__?.review===true);
 await page.mouse.click(203,649);await page.waitForFunction(()=>window.__BLOSSOM_STATE__.paused);
 await page.mouse.click(438,649);await page.waitForFunction(()=>!window.__BLOSSOM_STATE__.leaves);
 await page.mouse.click(225,689);await page.waitForFunction(()=>window.__BLOSSOM_STATE__.selected===2);
 const start=await page.evaluate(()=>window.__BLOSSOM_STATE__.phase),hashes=[];
 for(let i=0;i<96;i++){
  await page.waitForFunction(expected=>window.__BLOSSOM_STATE__.phase===expected,(start+i)%96);
  const png=await page.screenshot({clip:{x:480,y:180,width:320,height:420},path:`${output}/${String(i).padStart(3,'0')}.png`});
  hashes.push(createHash('sha256').update(png).digest('hex'));
  await page.mouse.click(258,649);
 }
 await page.waitForFunction(expected=>window.__BLOSSOM_STATE__.phase===expected,start);
 writeFileSync(output+'/capture.json',JSON.stringify({frames:96,start_phase:start,returned_phase:await page.evaluate(()=>window.__BLOSSOM_STATE__.phase),unique:new Set(hashes).size,hashes},null,2));
 console.log('96 real shader frames captured; unique',new Set(hashes).size);
}finally{await browser.close();await server.close()}
