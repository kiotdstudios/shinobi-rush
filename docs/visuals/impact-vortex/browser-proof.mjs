import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [source,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=/^https?:/.test(source)?null:await startStaticServer(source,{port:0});const base=server?.url??source;
const browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});const checks={},errors=[],cases=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__IMPACT_VORTEX__}));
const click=async n=>{const b=JSON.parse((await state()).buttons_json)[n];await page.mouse.click(b.x,b.y)};
try{
 await page.goto(base+'?impact=review');await page.waitForFunction(()=>window.__IMPACT_VORTEX__?.ready,null,{timeout:60000});checks.ready=true;
 await click('Normal');checks.normal=(await state()).speed===1;
 for(const dir of ['S','SE','E','NE','N','NW','W','SW']){const old=(await state()).impacts;await click(dir);await page.waitForTimeout(170);const s=await state();cases.push({dir,...s});checks['real_knockback_'+dir]=s.impacts>=old+2&&s.player_kind==='knockback'&&s.bandit_kind==='knockback';if(dir==='SE')await page.screenshot({path:out+'/knockback.png'});await page.waitForTimeout(600);}
 await click('SE');await page.waitForTimeout(450);let s=await state();checks.vortex_wrap=s.vortex_pairs===5&&s.log_visible&&s.log_collision&&Math.abs(s.log_rotation)>.01;await page.screenshot({path:out+'/wrap.png'});
 await page.waitForTimeout(850);s=await state();checks.log_bounce=s.log_visible&&s.log_collision&&s.log_rotation>1.4;await page.screenshot({path:out+'/bounce.png'});
 await page.waitForTimeout(900);s=await state();checks.log_dissolve=!s.log_visible&&!s.log_collision;await page.screenshot({path:out+'/dissolve.png'});
 await page.waitForTimeout(1100);checks.cleanup=(await state()).log_age===-1;
 await click('Half');checks.half=(await state()).speed===.5;await click('Replay');await page.waitForTimeout(800);await page.screenshot({path:out+'/half-speed.png'});
 checks.stationary_recoil_samples=(await state()).snapshots>0;checks.fixed_pool=(await state()).pool===12;checks.no_errors=errors.length===0;
 const build=server?null:await(await page.request.get(base+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/validation.json',JSON.stringify({url:page.url(),tested_at:new Date().toISOString(),build_sha:build?.commit_sha,checks,cases,errors},null,2));console.log(JSON.stringify({checks,errors:errors.slice(0,20)}));if(!Object.values(checks).every(Boolean))process.exitCode=1;
}finally{await browser.close();if(server)await server.close()}
