// Run with PLAYWRIGHT_MODULE pointing to the installed Playwright index.mjs.
import {writeFile,mkdir} from 'node:fs/promises';
const {chromium}=await import(process.env.PLAYWRIGHT_MODULE||'playwright');
const out=new URL('./qa/',import.meta.url);await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:900}});const errors=[];
page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});page.on('response',r=>{if(r.status()>=400)errors.push(`${r.status()} ${r.url()}`)});
await page.goto((process.env.REVIEW_BASE||'http://127.0.0.1:8777')+'/assets/characters/player/previews/running-jutsu/index.html');
await page.waitForFunction(()=>window.jutsuReviewState?.ready);await page.locator('#play').click();
const results=[];
for(let i=0;i<50;i++){
 await page.locator('#scrub').fill(String(i));await page.waitForFunction(n=>window.jutsuReviewState.frame===n&&!window.jutsuReviewState.playing,i);
 const r=await page.evaluate(async i=>{
  const meta=await fetch('../../study/running-jutsu/jutsu_review.json').then(r=>r.json());const f=meta.frames[i];
  const im=new Image();im.src='../../study/running-jutsu/'+f.sprint_source;await im.decode();
  const tmp=document.createElement('canvas');tmp.width=tmp.height=128;tmp.getContext('2d').drawImage(im,0,0);
  const expected=tmp.getContext('2d').getImageData(0,0,128,128).data;
  const actual=document.getElementById('body').getContext('2d').getImageData(0,0,192,192).data;
  let legErrors=0,partialBodyAlpha=0,bodyPixels=0;
  for(let y=80;y<128;y++)for(let x=0;x<128;x++)if(expected[(y*128+x)*4+3]||x<94||y>=96)for(let c=0;c<4;c++)if(expected[(y*128+x)*4+c]!==actual[((y+32)*192+x+32)*4+c])legErrors++;
  for(let p=3;p<actual.length;p+=4){if(actual[p])bodyPixels++;if(actual[p]!==0&&actual[p]!==255)partialBodyAlpha++;}
  return {frame:i,stage:f.stage,sprint:f.sprint_phase,legErrors,partialBodyAlpha,bodyPixels,hand:f.lightning_hand_px};
 },i);
 if(r.legErrors||r.partialBodyAlpha||r.bodyPixels<1000)throw Error(JSON.stringify(r));results.push(r);
}
await page.locator('#scrub').fill('19');
const charged=await page.locator('#full').evaluate(c=>c.toDataURL());await page.locator('#lightning').uncheck();
if(charged===await page.locator('#full').evaluate(c=>c.toDataURL()))throw Error('Lightning toggle failed');
await page.locator('#scrub').fill('11');const smeared=await page.locator('#full').evaluate(c=>c.toDataURL());await page.locator('#multiples').uncheck();
if(smeared===await page.locator('#full').evaluate(c=>c.toDataURL()))throw Error('Multiples toggle failed');
if(!await page.evaluate(()=>document.getElementById('full').toDataURL()===document.getElementById('body').toDataURL()))throw Error('Body/effect separation failed');
await page.locator('#anchors').check();if(!await page.locator('#body').evaluate(c=>{const p=c.getContext('2d').getImageData(96,148,1,1).data;return p[0]===88&&p[1]===224&&p[2]===191&&p[3]===255}))throw Error('Foot origin failed');await page.locator('#anchors').uncheck();
await page.locator('#scrub').fill('49');await page.locator('#step').click();await page.waitForFunction(()=>window.jutsuReviewState.frame===0);
await page.locator('#speed').selectOption('0.5');await page.waitForFunction(()=>window.jutsuReviewState.speed===0.5);
await page.locator('#speed').selectOption('1');await page.locator('#restart').click();await page.locator('#play').click();await page.waitForFunction(()=>window.jutsuReviewState.loops>=2,{},{timeout:6000});await page.locator('#play').click();
await page.locator('#lightning').check();await page.locator('#multiples').check();await page.locator('#scrub').fill('19');
await page.screenshot({path:new URL('desktop.png',out).pathname.replace(/^\/(.:)/,'$1'),fullPage:true});
await page.setViewportSize({width:390,height:844});
const layout=await page.evaluate(()=>({viewport:innerWidth,width:document.documentElement.scrollWidth,canvases:[...document.querySelectorAll('canvas')].map(c=>({w:c.getBoundingClientRect().width,h:c.getBoundingClientRect().height}))}));
if(layout.width>layout.viewport||layout.canvases.some(c=>Math.abs(c.w-c.h)>.1))throw Error(JSON.stringify(layout));
await page.screenshot({path:new URL('mobile.png',out).pathname.replace(/^\/(.:)/,'$1'),fullPage:true});
await page.locator('#zoom').selectOption('1.211538');const gameSize=await page.locator('#full').evaluate(c=>c.getBoundingClientRect().width);if(Math.abs(gameSize-232.6153)>.1)throw Error('Game close zoom failed');
await browser.close();if(errors.length)throw Error(JSON.stringify(errors));
const report={result:'PASS',frames:results,mobile:layout,gameCloseCanvas:gameSize,loops:2,controls:true,errors};await writeFile(new URL('browser.json',out),JSON.stringify(report,null,2));
console.log(JSON.stringify({result:'PASS',frames:50,legPixelsExact:true,bodyBinaryAlpha:true,independentEffects:true,loops:2,mobile:true,errors}));
