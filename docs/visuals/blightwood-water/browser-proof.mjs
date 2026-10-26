import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const dir=process.argv[2],out=process.argv[3];mkdirSync(out+'/frames',{recursive:true});
const server=/^https?:/.test(dir)?null:await startStaticServer(dir,{port:0});
const baseUrl=server?server.url:dir;
const capture=!process.argv.includes('--no-capture');
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const errors=[],checks={};
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__WATER_REVIEW__}));
const wait=ms=>page.waitForTimeout(ms);
const click=async name=>{const b=JSON.parse((await state()).buttons_json)[name];await page.mouse.click(b.x,b.y);await wait(35)};
try{
 await page.goto(baseUrl+'?water=review&paused=1');
 await page.waitForFunction(()=>window.__WATER_REVIEW__?.ready&&window.__WATER_REVIEW__.buttons_json,null,{timeout:60000});
 await wait(500);
 await page.screenshot({path:out+'/review.png'});
 checks.ready=(await state()).drops===18;
 const start=await state();await click('Pause');await page.waitForFunction(()=>window.__WATER_REVIEW__.paused===false);await wait(350);await click('Pause');
 const moved=await state();checks.flowing_cascade=moved.fall_frame!==start.fall_frame;checks.foam_moves=moved.foam_frame!==start.foam_frame;checks.spray_moves=moved.drop_x!==start.drop_x;
 await click('Normal');checks.normal_speed=(await state()).speed===1;
 await click('Half speed');checks.half_speed=(await state()).speed===.5;
 const c=(await state()).clock;await wait(250);checks.pause=(await state()).clock===c;
 await click('Step');checks.step=Math.abs((await state()).clock-c-1/24)<.001;
 await click('Spray / foam');checks.separate_spray_toggle=!(await state()).spray;await click('Spray / foam');
 await page.screenshot({path:out+'/effects-in-motion.png'});
 await page.goto(baseUrl+'?water=review&paused=1');await page.waitForFunction(()=>window.__WATER_REVIEW__?.buttons_json&&window.__WATER_REVIEW__.paused===true,null,{timeout:60000});await wait(250);
 for(let i=0;i<(capture?192:0);i++){
  if(i){const c=(await state()).clock;await click('Step');await page.waitForFunction(c=>window.__WATER_REVIEW__.clock>c,c)}
  await page.screenshot({path:out+'/frames/'+String(i).padStart(3,'0')+'.png'});
  if(i%48===0)console.log('Captured actual Godot frame '+i+'/192');
 }
 checks.captured=capture?192:0;
 checks.no_errors=errors.length===0;
 const deployed=server?null:await(await page.request.get(baseUrl+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/browser-validation.json',JSON.stringify({url:page.url(),tested_at:new Date().toISOString(),build_sha:deployed?.commit_sha??null,checks,errors,last:await state()},null,2));
 console.log(JSON.stringify(checks));
 if(!Object.entries(checks).every(([k,v])=>k==='captured'||v===true))process.exitCode=1;
}finally{await browser.close();if(server)await server.close()}
