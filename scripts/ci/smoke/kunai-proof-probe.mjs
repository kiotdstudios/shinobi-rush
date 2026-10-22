import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir');mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir'),{port:0}):null;
const browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const wait=ms=>new Promise(r=>setTimeout(r,ms));const errors=[];const checks={};const samples=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__KUNAI_PROOF__}));
const click=async(x,y)=>{await page.mouse.click(x,y);await wait(350)};
try{
 await page.goto((server?server.url:arg('base-url'))+'?kunai=proof');
 await page.waitForFunction(()=>window.__KUNAI_PROOF__?.ready===true,null,{timeout:90000});
 checks.half_default=(await state()).speed===0.5;
 for(let i=0;i<90;i++){samples.push(await state());await wait(100)}
 checks.all_actions=['guard','light1','light2','light3','dodge','dash_attack','run'].every(a=>samples.some(s=>s.animation===a));
 checks.weapon_persists=samples.every(s=>s.weapon_visible===true);
 await page.screenshot({path:out+'/01-sequence.png'});
 await click(228,163);const a=await state();await wait(500);const b=await state();checks.pause=a.paused&&b.time_ms===a.time_ms;
 await click(308,163);const stepped=await state();checks.step=stepped.paused&&stepped.time_ms!==b.time_ms;
 await click(144,163);checks.normal=(await state()).speed===1;
 await click(62,163);checks.half=(await state()).speed===0.5;
 await click(196,217);await click(80,365);
 const selected=await state();checks.action_select=selected.animation==='light3'&&Math.abs(selected.duration_ms-483.3333)<0.01;
 await click(308,163);checks.behind=(await state()).weapon_layer==='behind';
 await click(308,163);const contact=await state();checks.front_contact=contact.weapon_layer==='front'&&contact.swipe_visible;
 await click(357,217);await page.screenshot({path:out+'/02-contact-inspect.png'});
 await click(300,265);const scrubbed=await state();checks.scrub=scrubbed.paused&&scrubbed.time_ms>scrubbed.duration_ms*0.4&&scrubbed.time_ms<scrubbed.duration_ms*0.6;
 checks.no_errors=errors.length===0;
 console.log(JSON.stringify(checks));writeFileSync(out+'/kunai-proof-probe.json',JSON.stringify({checks,errors,samples,selected,contact,scrubbed},null,2));process.exitCode=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
