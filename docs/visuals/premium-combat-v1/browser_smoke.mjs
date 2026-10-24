import {writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const {chromium}=await import(process.env.PLAYWRIGHT_MODULE||new URL('../../../scripts/ci/smoke/node_modules/playwright/index.mjs',import.meta.url).href);
const url=process.argv[2]||'http://127.0.0.1:8778/assets/characters/player/previews/premium-combat-poc/index.html';
const browser=await chromium.launch({headless:true});
const results=[];
try{
 for(const mobile of [false,true]){
  const context=await browser.newContext({viewport:mobile?{width:390,height:844}:{width:1280,height:900},isMobile:mobile,hasTouch:mobile,deviceScaleFactor:1});
  const page=await context.newPage(),errors=[],missing=[];
  page.on('pageerror',e=>errors.push(String(e)));page.on('response',r=>{if(r.status()>=400)missing.push([r.status(),r.url()]);});
  await page.goto(url);await page.waitForFunction(()=>window.premiumCombatState?.ready);
  let state=await page.evaluate(()=>window.premiumCombatState);assert.equal(state.speed,.5);assert.equal(state.loaded_images,74);assert.equal(state.profile,'runtime');
  await page.locator('#pause').click();
  for(const name of ['run','light1','light2','light3','dodge','dash_attack']){
   await page.selectOption('#action',name);await page.waitForFunction(n=>window.premiumCombatState.animation===n,name);
   state=await page.evaluate(()=>window.premiumCombatState);assert.equal(state.body_by_weapon.katana,state.body_by_weapon.straight_sword);
   await page.locator('#step').click();await page.waitForFunction(()=>window.premiumCombatState.frame===1);
  }
  for(const [name,time] of [['light1',83.334],['light2',100.001],['light3',150.001],['dash_attack',100.001]]){
   await page.selectOption('#action',name);await page.evaluate(t=>window.premiumCombatSeek(t),time);
   await page.waitForFunction(()=>window.premiumCombatState.phase==='active');
   assert((await page.locator('#readout').textContent()).includes('hit_contact'));
  }
  await page.selectOption('#action','sequence');await page.evaluate(()=>window.premiumCombatSeek(0));
  for(const [time,name] of [[950.001,'light2'],[1166.668,'light3'],[1516.668,'dodge'],[2436.668,'dash_attack']]){
   await page.evaluate(t=>window.premiumCombatSeek(t),time);await page.waitForFunction(n=>window.premiumCombatState.animation===n,name);
  }
  await page.selectOption('#profile','authored');await page.waitForFunction(()=>Math.abs(window.premiumCombatState.duration_ms-2583.333333)<.01);
  await page.selectOption('#profile','runtime');await page.waitForFunction(()=>Math.abs(window.premiumCombatState.duration_ms-2836.666667)<.01);
  await page.evaluate(()=>window.premiumCombatSeek(0));
  await page.selectOption('#speed','1');await page.locator('#pause').click();
  const t0=await page.evaluate(()=>window.premiumCombatState.time_ms);await page.waitForTimeout(120);const t1=await page.evaluate(()=>window.premiumCombatState.time_ms);assert(t1>t0);
  await page.locator('#pause').click();await page.selectOption('#speed','.5');
  await page.locator('#body').uncheck();await page.locator('#weapon').uncheck();await page.locator('#vfx').uncheck();
  await page.waitForTimeout(40);
  const empty=await page.locator('#katana').evaluate(c=>{const a=c.getContext('2d').getImageData(0,0,c.width,c.height).data;return !a.some(v=>v);});assert(empty);
  for(const id of ['body','weapon','vfx'])await page.locator('#'+id).check();
  await page.locator('#anchors').check();await page.selectOption('#zoom','1');
  await page.evaluate(()=>window.premiumCombatSeek(834));await page.waitForTimeout(50);
  await page.screenshot({path:`docs/visuals/premium-combat-v1/browser-${mobile?'mobile':'desktop'}-native.png`,fullPage:true});
  await page.selectOption('#zoom','1.2115384615384615');await page.screenshot({path:`docs/visuals/premium-combat-v1/browser-${mobile?'mobile':'desktop'}-close.png`,fullPage:true});
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'horizontal page overflow');
  const start=performance.now();await page.reload();await page.waitForFunction(()=>window.premiumCombatState?.ready);const reload_ms=performance.now()-start;
  assert.deepEqual(errors,[]);assert.deepEqual(missing,[]);
  results.push({viewport:mobile?'390x844 touch':'1280x900 desktop',status:'PASS',loaded_images:state.loaded_images,controls:'all six actions; legal runtime transitions; two timing profiles; pause/play/step; shared bodies; layer toggles; normal/half; native/close; reload',contact_events:4,errors,missing,reload_ms:Math.round(reload_ms)});
  await context.close();
 }
 await writeFile('docs/visuals/premium-combat-v1/browser-smoke.json',JSON.stringify({url,engine:'Playwright Chromium',results},null,2)+'\n');console.log(JSON.stringify(results,null,2));
}finally{await browser.close();}
