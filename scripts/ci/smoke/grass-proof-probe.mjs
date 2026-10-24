import {chromium} from 'playwright';
import {startStaticServer} from './lib/serve.mjs';
import {analyzeInPage} from './lib/pixels.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir');mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir'),{port:0}):null;
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:720},serviceWorkers:'block'}),analysis=await browser.newPage();
const checks={},errors=[],views=[];
const wait=ms=>new Promise(r=>setTimeout(r,ms));
const state=()=>page.evaluate(()=>({...window.__GRASS_STATE__}));
const click=async(x,y)=>{await page.mouse.click(x,y);await wait(250)};
const diff=async(a,b,w,h)=>analysis.evaluate(analyzeInPage,{pngBase64:b.toString('base64'),prevPngBase64:a.toString('base64'),w,h,diffThreshold:24});
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
try{
 await page.goto((server?server.url:arg('base-url'))+'?grass=review');
 await page.waitForFunction(()=>window.__GRASS_STATE__?.ready&&window.__GRASS_STATE__.sample_cells===9,null,{timeout:90000});
 const initial=await state();checks.nine_roles=initial.roles===9&&initial.sample_cells===9;
 checks.world_patches=initial.ground_cells===247&&initial.tall_cells>50&&initial.tall_cells<160;
 await click(35,689);
 await page.screenshot({path:out+'/01-nine-assembled.png'});
 await click(127,649);checks.half=(await state()).speed===0.5;
 await click(203,649);const a=await state();await wait(500);checks.pause=(await state()).time===a.time;
 await click(258,649);const stepped=await state();checks.step=Math.abs(stepped.time-a.time-1/24)<0.002&&stepped.phase===(a.phase+1)%144;
 await click(330,649);checks.wind_toggle=!(await state()).wind;
 await click(410,649);checks.gust=Math.abs((await state()).strength-1.6)<0.001;
 await click(330,649);await click(224,689);
 checks.blade_view=(await state()).selected==='blade';
 const tips={x:510,y:255,width:270,height:185},roots={x:565,y:465,width:150,height:65};
 const ta=await page.screenshot({clip:tips}),ra=await page.screenshot({clip:roots});
 for(let i=0;i<36;i++)await page.mouse.click(258,649);
 await wait(500);
 const tb=await page.screenshot({clip:tips}),rb=await page.screenshot({clip:roots});
 const tipStats=await diff(ta,tb,270,185),rootStats=await diff(ra,rb,150,65);
 checks.visible_bending=tipStats.changedRatio>0.005;checks.planted_roots=rootStats.changedRatio<0.002;
 await page.screenshot({path:out+'/02-blade-gust.png'});
 for(const [view,x]of [['nine',35],['meadow',100],['close',167],['blade',224],['player',277]]){
  await click(x,689);views.push(await state());if(view==='meadow'||view==='close')await page.screenshot({path:out+`/${view}.png`});
 }
 checks.all_views=views.every((s,i)=>s.selected===['nine','meadow','close','blade','player'][i]);
 await click(46,649);checks.normal=(await state()).speed===1&&!(await state()).paused;
 await click(410,649);checks.gust_reset=(await state()).strength===1;
 await wait(2000);const last=await state();checks.stable_budget=last.ground_cells===initial.ground_cells&&last.tall_cells===initial.tall_cells;
 checks.no_errors=errors.length===0;
 writeFileSync(out+'/grass-proof-probe.json',JSON.stringify({checks,errors,initial,tipStats,rootStats,views,last},null,2));console.log(JSON.stringify(checks));
 process.exitCode=Object.values(checks).every(Boolean)?0:1;
}finally{await browser.close();if(server)await server.close()}
