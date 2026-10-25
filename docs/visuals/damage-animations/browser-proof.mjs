import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [dir,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=/^https?:/.test(dir)?null:await startStaticServer(dir,{port:0});
const base=server?.url??dir,capture=!process.argv.includes('--no-capture');
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const checks={},errors=[];
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__DAMAGE_REVIEW__}));
const click=async name=>{const b=JSON.parse((await state()).buttons_json)[name];await page.mouse.click(b.x,b.y);await page.waitForTimeout(55)};
try{
 await page.goto(base+'?damage=review&paused=1');await page.waitForFunction(()=>window.__DAMAGE_REVIEW__?.buttons_json,null,{timeout:90000});
 checks.ready=(await state()).ready===true;checks.sixteen_actors=(await state()).count===16;
 await page.screenshot({path:out+'/all-directions.png'});
 await click('Normal');checks.normal=(await state()).speed===1;
 await click('Half speed');checks.half=(await state()).speed===.5;
 const t=(await state()).clock;await page.waitForTimeout(200);checks.pause=(await state()).clock===t;
 await click('Step');checks.step=Math.abs((await state()).clock-t-1/24)<.001;
 for(const direction of ['S','SE','E','NE','N','NW','W','SW']){
  await click(direction);checks['heading_'+direction]=(await state()).focus===direction&&(await state()).ready===true;
 }
 await click('All headings');checks.all_headings=(await state()).focus==='All headings';
 for(const [button,action,n] of [['Hit reaction','hit_react',8],['Knockback','knockback',12],['Death','death',16]]){
  await click(button);checks[action+'_select']=(await state()).action===action;
  for(let i=0;i<n+2;i++)await click('Step');
  const end=await state(),frames=JSON.parse(end.frames_json);
  checks[action+'_end']=end.finished===true&&frames.every(i=>i===n-1);
  for(let i=0;i<3;i++)await click('Step');checks[action+'_holds']=JSON.parse((await state()).frames_json).every(i=>i===n-1);
  await page.screenshot({path:out+'/'+action+'-all.png'});
 }
 await click('Knockback');await click('Travel');checks.travel_on=(await state()).travel===true;
 await click('Travel');checks.travel_off=(await state()).travel===false;
 await click('Replay');const start=(await state()).clock;await page.waitForTimeout(250);checks.replay_advances=(await state()).clock>start;
 await click('Pause');
 if(capture){
  for(const focus of ['All headings','SE']){
   await click(focus);
   for(const [button,action,n] of [['Hit reaction','hit_react',8],['Knockback','knockback',12],['Death','death',16]]){
    const target=out+'/'+(focus==='SE'?'SE':'all')+'/'+action;mkdirSync(target,{recursive:true});
    await click(button);
    for(let i=0;i<n+12;i++){
     if(i)await click('Step');
     await page.screenshot({path:target+'/'+String(i).padStart(3,'0')+'.png'});
    }
    console.log('Captured '+focus+' '+action);
   }
  }
 }
 checks.no_errors=errors.length===0;
 const build=server?null:await(await page.request.get(base+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/validation.json',JSON.stringify({url:page.url(),tested_at:new Date().toISOString(),build_sha:build?.commit_sha,checks,errors,last:await state(),capture},null,2));
 console.log(JSON.stringify(checks));if(!Object.values(checks).every(Boolean))process.exitCode=1;
}finally{await browser.close();if(server)await server.close()}
