import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [dir,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=/^https?:/.test(dir)?null:await startStaticServer(dir,{port:0});
const base=server?.url??dir;const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});const checks={},errors=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__BOMB_REVIEW__}));
const click=async name=>{const b=JSON.parse((await state()).buttons_json)[name];await page.mouse.click(b.x,b.y);await page.waitForTimeout(80)};
try{
 await page.goto(base+'?bombs=review');await page.waitForFunction(()=>window.__BOMB_REVIEW__?.ready,null,{timeout:90000});
 checks.ready=(await state()).ready===true;
 await page.screenshot({path:out+'/pickups.png'});
 await click('Half speed');checks.half=(await state()).speed===.5;
 await click('Pause');const t=(await state()).clock;await page.waitForTimeout(150);checks.pause=(await state()).clock===t;
 await click('Pause');await click('Normal');checks.normal=(await state()).speed===1;
 await click('Collect both');checks.collected=(await state()).collected&&(await state()).explosive_count===1&&(await state()).smoke_count===1;
 await click('Throw explosive');await page.waitForTimeout(550);checks.explosive_lands=JSON.parse((await state()).bombs_json).some(b=>b.kind==='tag_bomb'&&b.phase===1);
 await page.waitForTimeout(1200);checks.explosive_detonates=JSON.parse((await state()).bombs_json).some(b=>b.kind==='tag_bomb'&&b.detonated);
 await page.screenshot({path:out+'/explosion.png'});
 await click('Throw smoke');await page.waitForTimeout(550);checks.smoke_lands=JSON.parse((await state()).bombs_json).some(b=>b.kind==='smoke_tag_bomb'&&b.phase===1);
 await page.waitForTimeout(1600);const smoke=JSON.parse((await state()).bombs_json).find(b=>b.kind==='smoke_tag_bomb');checks.smoke_detonates=smoke?.detonated===true;checks.smoke_no_damage=smoke?.damaged===0;
 await page.screenshot({path:out+'/smoke.png'});
 await page.waitForTimeout(4900);checks.smoke_cleanup=!JSON.parse((await state()).bombs_json).some(b=>b.kind==='smoke_tag_bomb');
 checks.no_errors=errors.length===0;const build=server?null:await(await page.request.get(base+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/validation.json',JSON.stringify({url:page.url(),tested_at:new Date().toISOString(),build_sha:build?.commit_sha,checks,errors},null,2));
 console.log(JSON.stringify({checks,errors}));if(!Object.values(checks).every(Boolean))process.exitCode=1;
}finally{await browser.close();if(server)await server.close()}
