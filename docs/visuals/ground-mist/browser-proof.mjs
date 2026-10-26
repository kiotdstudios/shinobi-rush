import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
const [source,out]=process.argv.slice(2);mkdirSync(out,{recursive:true});
const server=/^https?:/.test(source)?null:await startStaticServer(source,{port:0});
const base=server?.url??source;
const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block',recordVideo:{dir:out,size:{width:1280,height:720}}});
const page=await context.newPage(), errors=[], checks={};
page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
const state=()=>page.evaluate(()=>({...window.__MIST_REVIEW__}));
const click=async key=>{const s=await state();const b=JSON.parse(s.buttons_json)[key];await page.mouse.click(b.x,b.y)};
try {
 await page.goto(base+'?mist=review');
 await page.waitForFunction(()=>window.__MIST_REVIEW__?.ready,null,{timeout:90000});
 let s=await state();checks.sources=s.sources===4;checks.fixed_pool=s.capacity===48;checks.wisps=s.visible>=6;checks.player_clearing=s.clearing<.09;
 const old=s.ribbon_x;await page.waitForTimeout(1000);checks.drift=(await state()).ribbon_x!==old;
 await page.screenshot({path:out+'/normal.png'});
 await click('Half');await page.waitForFunction(()=>window.__MIST_REVIEW__.speed===.5);checks.half=true;
 await page.waitForTimeout(1800);await page.screenshot({path:out+'/half.png'});
 await click('Pause');await page.waitForFunction(()=>window.__MIST_REVIEW__.paused);const held=(await state()).clock;await page.waitForTimeout(350);checks.pause=(await state()).clock===held;
 await click('Mist');await page.waitForFunction(()=>window.__MIST_REVIEW__.visible===0);checks.toggle_off=true;
 await page.screenshot({path:out+'/mist-off.png'});
 await click('Mist');await page.waitForFunction(()=>window.__MIST_REVIEW__.visible>0);checks.toggle_on=true;
 await click('Pause');await click('Normal');await page.waitForFunction(()=>window.__MIST_REVIEW__.speed===1);
 const before=(await state()).x;await page.keyboard.down('KeyD');await page.waitForTimeout(700);await page.keyboard.up('KeyD');checks.real_player_moves=(await state()).x>before+20;
 await page.screenshot({path:out+'/player-moving.png'});
 // The canonical game must discover real map anchors too; no forced source fixtures here.
 await page.goto(base+'?mist=inspect');await page.waitForFunction(()=>window.__GROUND_MIST__?.ready&&window.__GROUND_MIST__.sources>0,null,{timeout:90000});
 const live=await page.evaluate(()=>({...window.__GROUND_MIST__}));checks.world_sources=live.sources>0&&live.sources<=24;checks.world_pool=live.capacity===48;checks.world_visible=live.visible>0;
 await page.screenshot({path:out+'/world.png'});
 checks.no_errors=errors.length===0;
 const build=server?null:await(await page.request.get(base+'build-info.json?v='+Date.now())).json();
 writeFileSync(out+'/validation.json',JSON.stringify({tested_at:new Date().toISOString(),url:base,build_sha:build?.commit_sha,checks,world:live,errors},null,2));
 console.log(JSON.stringify({checks,errors}));if(!Object.values(checks).every(Boolean))process.exitCode=1;
 const video=page.video();await context.close();await video.saveAs(out+'/review.webm');
} finally {await browser.close();if(server)await server.close()}
