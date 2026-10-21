import { chromium } from 'file:///C:/Users/dielp/Documents/Codex/2026-10-17/shinobi-rush-is-the-new-game/.tools/live-animation-integration/scripts/ci/smoke/node_modules/playwright/index.mjs';
import assert from 'node:assert/strict';
const browser=await chromium.launch({headless:true});
try {
 for(const viewport of [{width:1440,height:1000},{width:390,height:844}]){
  const page=await browser.newPage({viewport});const errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('response',r=>{if(r.status()>=400)errors.push(`${r.status()} ${r.url()}`)});
  await page.goto('http://127.0.0.1:8788/assets/characters/bandit/previews/');await page.waitForFunction(()=>document.querySelector('#clock').textContent.includes('FPS'));
  assert.equal(await page.locator('#speed').inputValue(),'0.5');
  for(const zoom of ['128','155','256','384']){await page.selectOption('#zoom',zoom);await page.waitForTimeout(20);assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth))}
  for(const action of ['idle','run','sprint']){
   await page.selectOption('#action',action);await page.check('#all');assert.equal(await page.locator('canvas').count(),8);
   await page.waitForTimeout(250);assert(!(await page.locator('#clock').textContent()).includes('NaN'));
   await page.uncheck('#all');
   for(const dir of ['S','SE','E','NE','N','NW','W','SW'])await page.selectOption('#direction',dir);
  }
  await page.locator('#play').click();assert.equal(await page.locator('#play').textContent(),'Play');
  await page.locator('#scrub').evaluate(el=>{el.value='3';el.dispatchEvent(new Event('input',{bubbles:true}))});assert((await page.locator('#clock').textContent()).includes('Frame 3/7'));
  await page.selectOption('#speed','1');await page.click('#reset');assert((await page.locator('#clock').textContent()).includes('Clock 0.00'));
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));assert.deepEqual(errors,[]);
  await page.screenshot({path:new URL(`browser-${viewport.width}.png`,import.meta.url).pathname.slice(1),fullPage:true});await page.close();
  console.log(`PASS browser ${viewport.width}x${viewport.height}: all states/directions, shared clock, half/normal speed, scrub, no errors/overflow`);
 }
}finally{await browser.close()}
