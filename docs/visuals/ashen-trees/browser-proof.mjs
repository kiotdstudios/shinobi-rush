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
const state=()=>page.evaluate(()=>({...window.__ASHEN_REVIEW__}));
const wait=ms=>page.waitForTimeout(ms);
const click=async name=>{const b=JSON.parse((await state()).buttons_json)[name];await page.mouse.click(b.x,b.y);await wait(100)};
try{
 await page.goto(server.url+'?frame=0');
 await page.waitForFunction(()=>window.__ASHEN_REVIEW__?.ready&&window.__ASHEN_REVIEW__.buttons_json,null,{timeout:60000});
 await wait(500);
 await page.screenshot({path:out+'/review.png'});
 checks.ready=(await state()).pool_size===72;
 await click('Pause');let s=await state();await wait(800);const half=(await state()).clock-s.clock;
 await click('Normal');s=await state();await wait(800);const normal=(await state()).clock-s.clock;
 checks.half_speed=half>0.2&&half<0.75&&normal>half*1.4;
 await click('Pause');s=await state();await wait(300);checks.pause=(await state()).clock===s.clock;
 await click('Step');checks.step=Math.abs((await state()).clock-s.clock-1/24)<0.001;
 await click('Wind');checks.wind_toggle=!(await state()).wind;
 await click('Ash');checks.ash_toggle=!(await state()).ash;
 await click('Root glow');checks.heat_toggle=!(await state()).heat;
 await click('Compare Blightwood');checks.compare=(await state()).compare;
 await page.screenshot({path:out+'/blightwood-comparison.png'});
 await click('Game zoom');checks.game_zoom=(await state()).game_zoom;
 await page.screenshot({path:out+'/gameplay-scale.png'});
 await page.goto(server.url+'?frame=0');
 await page.waitForFunction(()=>window.__ASHEN_REVIEW__?.buttons_json,null,{timeout:60000});await wait(250);
 for(let i=0;i<192;i++){
  if(i){await click('Step')}
  await page.screenshot({path:out+'/frames/'+String(i).padStart(3,'0')+'.png'});
  if(i%48===0)console.log('Captured actual Godot frame '+i+'/192');
 }
 checks.captured=192;
 checks.no_errors=errors.length===0;
 writeFileSync(out+'/browser-validation.json',JSON.stringify({checks,errors,half_delta:half,normal_delta:normal,last:await state()},null,2));
 console.log(JSON.stringify(checks));
 if(!Object.entries(checks).every(([k,v])=>k==='captured'||v===true))process.exitCode=1;
}finally{await browser.close();await server.close()}
