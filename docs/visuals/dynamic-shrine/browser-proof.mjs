import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [dir,out]=process.argv.slice(2);mkdirSync(out+'/frames',{recursive:true});
const server=/^https?:/.test(dir)?null:await startStaticServer(dir,{port:0});
const base=server?.url??dir,capture=!process.argv.includes('--no-capture');
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const checks={},errors=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__SHRINE_REVIEW__}));
const click=async name=>{const b=JSON.parse((await state()).buttons_json)[name];await page.mouse.click(b.x,b.y);await page.waitForTimeout(55)};
try{
 await page.goto(base+'?shrine=review');await page.waitForFunction(()=>window.__SHRINE_REVIEW__?.buttons_json,null,{timeout:90000});
 checks.ready=(await state()).ready;checks.three_swarms=(await state()).swarms===3;
 const first=await state();await page.waitForTimeout(1100);const next=await state();
 checks.animation_moves=next.clock>first.clock&&next.pulse!==first.pulse;
 checks.rooted_stone=first.body_x===next.body_x&&first.body_y===next.body_y;
 await page.screenshot({path:out+'/review.png'});
 await click('Normal');checks.normal=(await state()).speed===1;
 await click('Half speed');checks.half=(await state()).speed===.5;
 await click('Pause');const t=(await state()).clock;await page.waitForTimeout(250);checks.pause=(await state()).clock===t;
 await click('Step');checks.step=Math.abs((await state()).clock-t-1/24)<.001;
 for(const [button,key] of [['Glow','glow'],['Vines','vines'],['Fireflies','fireflies'],['God rays','rays']]){
  await click(button);checks[key+'_off']=(await state())[key]===false;
  await click(button);checks[key+'_on']=(await state())[key]===true;
 }
 await page.goto(base+'?shrine=review&paused=1');await page.waitForFunction(()=>window.__SHRINE_REVIEW__?.paused===true,null,{timeout:90000});
 for(let i=0;i<(capture?288:0);i++){
  if(i)await click('Step');
  await page.screenshot({path:out+'/frames/'+String(i).padStart(3,'0')+'.png'});
  if(i%72===0)console.log('Godot capture '+i+'/288');
 }
 await page.screenshot({path:out+'/all-effects.png'});
 checks.no_errors=errors.length===0;
 const build=server?null:await(await page.request.get(base+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/validation.json',JSON.stringify({url:page.url(),tested_at:new Date().toISOString(),build_sha:build?.commit_sha,checks,frames:capture?288:0,errors,last:await state()},null,2));
 console.log(JSON.stringify(checks));if(!Object.values(checks).every(Boolean))process.exitCode=1;
}finally{await browser.close();if(server)await server.close()}
