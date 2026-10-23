import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';import assert from 'node:assert/strict';
const out='build/chakra-blue-browser';mkdirSync(out,{recursive:true});
const server=await startStaticServer('.',{port:0}),browser=await chromium.launch({headless:true}),errors=[],results=[];
try {for(const viewport of [{width:1000,height:850},{width:390,height:844}]){
 const p=await browser.newPage({viewport});p.on('pageerror',e=>errors.push(String(e)));p.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 await p.goto(server.url+'docs/visuals/chakra-blue-v2/review.html');await p.waitForFunction(()=>window.__CHARGE_REVIEW__?.ready);
 const state=()=>p.evaluate(()=>({...window.__CHARGE_REVIEW__}));
 assert.equal((await state()).loaded,96);assert.equal((await state()).speed,.5);
 await p.getByRole('button',{name:'Pause',exact:true}).click();await p.waitForFunction(()=>window.__CHARGE_REVIEW__.paused);const fixed=(await state()).index;await p.waitForTimeout(170);assert.equal((await state()).index,fixed);
 await p.locator('#mode').selectOption('sustain');await p.waitForFunction(()=>window.__CHARGE_REVIEW__.mode==='sustain');assert.equal((await state()).mode,'sustain');
 const seen=new Set();for(let n=0;n<64;n++){const s=await state();assert(s.paused);assert(s.index>=16&&s.index<80);assert(!seen.has(s.index));seen.add(s.index);await p.getByRole('button',{name:'Step frame',exact:true}).click();await p.waitForFunction(old=>window.__CHARGE_REVIEW__.index===16+(old-16+1)%64,s.index)}
 assert.equal((await state()).index,16);
 await p.getByLabel('Player for scale').uncheck();await p.waitForFunction(()=>!window.__CHARGE_REVIEW__.body);assert.equal((await state()).body,false);await p.getByLabel('Player for scale').check();await p.waitForFunction(()=>window.__CHARGE_REVIEW__.body);
 await p.getByRole('button',{name:'Normal',exact:true}).click();await p.waitForFunction(()=>window.__CHARGE_REVIEW__.speed===1);assert.equal((await state()).speed,1);const a=(await state()).index;await p.waitForTimeout(500);const fast=((await state()).index-a+64)%64;
 await p.getByRole('button',{name:'Half speed',exact:true}).click();await p.waitForFunction(()=>window.__CHARGE_REVIEW__.speed===.5);const b=(await state()).index;await p.waitForTimeout(500);const slow=((await state()).index-b+64)%64;
 assert(fast>=9&&fast<=16);assert(slow>=4&&slow<=9);assert(fast>slow);
 await p.getByRole('button',{name:'Pause',exact:true}).click();await p.screenshot({path:`${out}/${viewport.width}.png`,fullPage:true});
 results.push({viewport,loaded:96,stepped_loop:64,normal_frames_per_half_second:fast,half_speed_frames_per_half_second:slow});await p.close();
 }assert.deepEqual(errors,[]);writeFileSync(out+'/result.json',JSON.stringify({result:'PASS',results,errors},null,2));console.log('PASS:96 loaded,64 unique loop keys, pause/step/speed/body controls, desktop + phone viewport;0 browser errors');
}catch(e){console.error(errors);throw e}finally{await browser.close();await server.close()}
