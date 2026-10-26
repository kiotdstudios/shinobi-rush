import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [source,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=/^https?:/.test(source)?null:await startStaticServer(source,{port:0});
const base=server?.url??source;const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block',recordVideo:{dir:out,size:{width:1280,height:720}}});
const page=await context.newPage();const errors=[],checks={},phases=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__WATERLIFE__}));
const click=async key=>{const s=await state();const b=JSON.parse(s.buttons_json)[key];await page.mouse.click(b.x,b.y)};
try{
 await page.goto(base+'?waterlife=review');await page.waitForFunction(()=>window.__WATERLIFE__?.ready,null,{timeout:60000});
 checks.ready=true;await click('Normal');checks.normal=(await state()).speed===1;
 await click('Frog again');let before=(await state()).emissions;
 for(let i=0;i<24;i++){await page.waitForTimeout(210);const s=await state();phases.push(s.phase);if(['tongue','departure'].includes(s.phase))await page.screenshot({path:out+'/'+s.phase+'.png'});}
 let s=await state();checks.running_contacts=s.emissions>before+10;checks.plants=s.plants===6;checks.fixed_pool=s.pool===32;checks.frog_tongue=phases.includes('tongue');checks.frog_dive=phases.includes('departure');
 await click('Pause');await page.waitForTimeout(150);const held=(await state()).clock;await page.waitForTimeout(200);checks.pause=(await state()).clock===held;await click('Step');await page.waitForTimeout(70);checks.step=Math.abs((await state()).clock-held-1/24)<0.003;
 await click('Half');checks.half=(await state()).speed===.5;await click('Pause');await click('Frog again');await page.waitForTimeout(4000);await page.screenshot({path:out+'/half-speed.png'});
 await page.goto(base+'?waterlife=play');await page.waitForFunction(()=>window.__WATERLIFE_PLAY__?.ready,null,{timeout:60000});
 const play=()=>page.evaluate(()=>({...window.__WATERLIFE_PLAY__}));
 const start=await play();checks.real_starts_dry=!start.wet&&!start.aura;
 await page.keyboard.down('KeyD');await page.waitForFunction(()=>window.__WATERLIFE_PLAY__.wet&&window.__WATERLIFE_PLAY__.emissions>=2,null,{timeout:12000});await page.keyboard.up('KeyD');
 await page.waitForTimeout(450);const wet=await play();checks.real_running_water=wet.wet&&wet.aura&&wet.emissions>=2&&wet.chakra<start.chakra;await page.screenshot({path:out+'/real-water.png'});
 const count=wet.emissions;await page.waitForTimeout(600);checks.real_standing_no_spray=(await play()).emissions===count;
 await page.keyboard.down('KeyA');await page.waitForFunction(()=>window.__WATERLIFE_PLAY__.x<350,null,{timeout:12000});await page.keyboard.up('KeyA');await page.waitForTimeout(350);const dry=await play();checks.real_leaving_water=!dry.wet&&!dry.aura;
 await page.screenshot({path:out+'/real-dry.png'});
 checks.no_errors=errors.length===0;
 const build=server?null:await(await page.request.get(base+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/validation.json',JSON.stringify({url:page.url(),tested_at:new Date().toISOString(),build_sha:build?.commit_sha,checks,phases,real_gameplay:{start,wet,dry},errors},null,2));
 console.log(JSON.stringify({checks,errors}));if(!Object.values(checks).every(Boolean))process.exitCode=1;
 const video=page.video();await context.close();await video.saveAs(out+'/review.webm');
}finally{await browser.close();if(server)await server.close()}
