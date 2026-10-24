import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir');mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir'),{port:0}):null;
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'});
const errors=[],checks={},samples=[];
const wait=ms=>new Promise(r=>setTimeout(r,ms));
const state=()=>page.evaluate(()=>({...window.__FLICKER_PROOF__}));
const clean=s=>s.body_visible&&!s.flicker_active&&!s.ghost_visible&&!s.effect_visible;
const click=async(x,y)=>{await page.mouse.click(x,y);await wait(100)};
const until=async(fn)=>{for(let i=0;i<80;i++){const s=await state();if(fn(s))return s;await wait(100)}throw Error('State timeout '+JSON.stringify(await state()))};
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
try{
 await page.goto((server?server.url:arg('base-url'))+'?kunai=proof');
 await page.waitForFunction(()=>window.__FLICKER_PROOF__?.ready===true,null,{timeout:90000});
 checks.ready=clean(await state());
 await click(274,180);checks.double_requires_combo=(await state()).double_count===0;
 await page.keyboard.press('j');await page.keyboard.press('j');
 const combo=await until(s=>s.combo_hits===2&&s.attack===0);
 checks.buffered_two_hits=combo.double_count===0&&combo.traversals===0;
 await click(274,180);const double=await until(s=>s.double_count===1&&clean(s));
 checks.double_clean=double.traversals===2&&double.vanishes===2&&double.reappears===2;
 checks.retreat_displacement=Math.hypot(double.x-combo.x,double.y-combo.y)>100;
 await click(127,232);checks.half_speed=(await state()).speed===0.5;
 await page.screenshot({path:out+'/01-half-ready.png'});
 for(let i=0;i<8;i++){await page.keyboard.press('Space');await wait(300)}
 const repeated=await until(clean);checks.repeated_recovery=repeated.traversals>=10;
 await page.keyboard.press('Space');await page.keyboard.press('Tab');await wait(150);
 const inspected=await state();checks.inspection_cleans=inspected.inspection&&clean(inspected);
 await page.keyboard.press('Tab');checks.inspection_exit=!(await until(s=>!s.inspection)).inspection;
 await click(46,232);checks.normal_speed=(await state()).speed===1;
 await page.keyboard.press('Space');await page.keyboard.press('j');
 await until(s=>clean(s)&&s.attack===0);checks.buffered_reengage=clean(await state());
 await page.keyboard.down('w');await wait(100);await page.keyboard.press('Space');await page.keyboard.up('w');
 await page.keyboard.down('d');await wait(100);await page.keyboard.up('d');await until(clean);
 checks.direction_interrupt=clean(await state());
 await click(450,180);await page.keyboard.press('j');await page.keyboard.press('j');await until(s=>s.combo_hits===2&&s.attack===0);
 await click(127,232);await page.mouse.click(274,180);
 for(let i=0;i<10;i++){samples.push(await state());await wait(30)}
 await page.screenshot({path:out+'/02-double-review.png'});await until(clean);
 checks.no_errors=errors.length===0;
 writeFileSync(out+'/flicker-proof-probe.json',JSON.stringify({checks,errors,combo,double,repeated,samples,final:await state()},null,2));
 console.log(JSON.stringify(checks));process.exitCode=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
