import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const dir=process.argv[2],out=process.argv[3];mkdirSync(out+'/frames',{recursive:true});
const server=await startStaticServer(dir,{port:0});
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const errors=[],checks={};
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__FIRE_REVIEW__}));
const wait=ms=>page.waitForTimeout(ms);
const click=async name=>{const b=JSON.parse((await state()).buttons_json)[name];await page.mouse.click(b.x,b.y);await wait(100)};
try{
 await page.goto(server.url+'?paused=1');
 await page.waitForFunction(()=>window.__FIRE_REVIEW__?.ready&&window.__FIRE_REVIEW__.buttons_json,null,{timeout:60000});
 await wait(500);
 await page.screenshot({path:out+'/review.png'});
 checks.ready=(await state()).capacity===210;
 await click('Sound');await page.waitForFunction(()=>window.__FIRE_REVIEW__.sound===true);
 const before=await state();await click('Pause');await page.waitForFunction(()=>window.__FIRE_REVIEW__.paused===false);await wait(3000);await click('Pause');await page.waitForFunction(()=>window.__FIRE_REVIEW__.paused===true);
 const after=await state();checks.synced_audio=after.pops>before.pops&&after.pops-before.pops===after.audio_pops-before.audio_pops;
 await click('Sound');await page.waitForFunction(()=>window.__FIRE_REVIEW__.sound===false);checks.mute=true;
 const c=(await state()).clock;await wait(250);checks.pause=(await state()).clock===c;
 await click('Step');await page.waitForFunction(c=>window.__FIRE_REVIEW__.clock>c,c);checks.step=Math.abs((await state()).clock-c-1/24)<.001;
 for(const name of ['Smoke','Sparks','Lighting']){await click(name);await page.waitForFunction(n=>window.__FIRE_REVIEW__[n]===false,name.toLowerCase());checks[name.toLowerCase()]=true;await click(name);await page.waitForFunction(n=>window.__FIRE_REVIEW__[n]===true,name.toLowerCase())}
 await click('Half speed');checks.half_speed=(await state()).speed===.5;
 await page.goto(server.url+'?paused=1');await page.waitForFunction(()=>window.__FIRE_REVIEW__?.buttons_json&&window.__FIRE_REVIEW__.paused===true,null,{timeout:60000});await wait(250);
 for(let i=0;i<192;i++){
  if(i){const c=(await state()).clock;await click('Step');await page.waitForFunction(c=>window.__FIRE_REVIEW__.clock>c,c)}
  await page.screenshot({path:out+'/frames/'+String(i).padStart(3,'0')+'.png'});
  if(i%48===0)console.log('Captured actual Godot frame '+i+'/192');
 }
 checks.captured=192;
 checks.no_errors=errors.length===0;
 writeFileSync(out+'/browser-validation.json',JSON.stringify({checks,errors,last:await state()},null,2));
 console.log(JSON.stringify(checks));
 if(!Object.entries(checks).every(([k,v])=>k==='captured'||v===true))process.exitCode=1;
}finally{await browser.close();await server.close()}
