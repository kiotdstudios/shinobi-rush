import {chromium} from 'playwright';
import {mkdirSync,writeFileSync} from 'node:fs';
import path from 'node:path';
import {startStaticServer} from './lib/serve.mjs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir');mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir')):null;
const base=arg('url')||server.url;
const browser=await chromium.launch({headless:true});
const checks=[],errors=[];
const check=(name,ok,detail)=>{checks.push({name,ok,detail});console.log(`${ok?'PASS':'FAIL'} ${name}`)};
const context=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block'});
const page=await context.newPage();
page.on('pageerror',e=>errors.push(String(e)));
page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
const tap=async key=>{await page.keyboard.down(key);await page.waitForTimeout(800);await page.keyboard.up(key);await page.waitForTimeout(500)};
try{
 if(arg('expected-sha')){
  const response=await fetch(new URL('build-info.json?v='+Date.now(),base));
  const build=await response.json();check('exact deployed commit',build.commit_sha===arg('expected-sha'),build);
 }
 await page.goto(base+'?integration_inspect=1');
 await page.waitForFunction(()=>window.__INTEGRATION_REVIEW__?.ready===true,null,{timeout:180000});
 const state=()=>page.evaluate(()=>({...window.__INTEGRATION_REVIEW__}));
 await page.waitForFunction(()=>JSON.parse(window.__INTEGRATION_REVIEW__.crews_json).length===4,null,{timeout:60000});
 const start=await state(),crews=JSON.parse(start.crews_json);
 check('four live bandits in two crews',crews.length===4&&new Set(crews).size===2,crews);
 await page.mouse.click(640,500);await page.keyboard.down('KeyD');
 await page.waitForFunction(x=>window.__INTEGRATION_REVIEW__.player_x>x+8,start.player_x,{timeout:30000});
 await page.keyboard.up('KeyD');await page.waitForTimeout(500);
 await tap('KeyI');
 await page.waitForFunction(()=>window.__INTEGRATION_REVIEW__.menu_open===true,null,{timeout:30000});
 await tap('ArrowDown');await tap('ArrowDown');
 await page.waitForFunction(()=>window.__INTEGRATION_REVIEW__.menu_cursor===2,null,{timeout:30000});
 const before=await state(),count=JSON.parse(before.inventory_json).kunai;
 await tap('Digit1');
 await page.waitForFunction(n=>JSON.parse(window.__INTEGRATION_REVIEW__.inventory_json).kunai===n-1,count,{timeout:30000});
 check('real menu Square drops one kunai',JSON.parse((await state()).inventory_json).kunai===count-1,await state());
 await page.screenshot({path:path.join(out,'inventory-square-drop.png')});
 await tap('KeyI');await page.waitForTimeout(1800);
 const dropped=await state();
 check('drop stays after unpausing inside pickup radius',JSON.parse(dropped.inventory_json).kunai===count-1&&JSON.parse(dropped.kunai_drops_json).some(d=>d.owned),dropped);
 await page.screenshot({path:path.join(out,'world-drop.png')});
 await page.keyboard.down('KeyA');
 await page.waitForFunction(x=>window.__INTEGRATION_REVIEW__.player_x<x-80,dropped.player_x,{timeout:30000});
 await page.keyboard.up('KeyA');await page.waitForTimeout(800);
 await page.keyboard.down('KeyD');
 await page.waitForFunction(n=>JSON.parse(window.__INTEGRATION_REVIEW__.inventory_json).kunai===n,count,{timeout:30000});
 await page.keyboard.up('KeyD');
 check('leave and return recovers dropped kunai',JSON.parse((await state()).inventory_json).kunai===count,await state());
 await page.goto(base+'?bombs=review');
 await page.waitForFunction(()=>window.__BOMB_REVIEW__?.ready===true,null,{timeout:120000});
 const buttons=JSON.parse(await page.evaluate(()=>window.__BOMB_REVIEW__.buttons_json));
 await page.mouse.click(buttons['Throw smoke'].x,buttons['Throw smoke'].y);
 await page.waitForFunction(()=>JSON.parse(window.__BOMB_REVIEW__.bombs_json).some(b=>b.kind==='smoke_tag_bomb'&&b.detonated&&b.cover_radius>20&&b.banks===3),null,{timeout:60000});
 const smoke=JSON.parse(await page.evaluate(()=>window.__BOMB_REVIEW__.bombs_json));
 check('smoke has three animated banks and active sight cover',smoke.some(b=>b.banks===3&&b.cover_radius>20),smoke);
 await page.screenshot({path:path.join(out,'smoke-screen.png')});
 check('no engine/browser errors',errors.length===0,errors);
}catch(e){check('probe completed',false,String(e))}
finally{
 await page.keyboard.up('KeyA');await page.keyboard.up('KeyD');
 await context.close();await browser.close();if(server)await server.close();
 writeFileSync(path.join(out,'result.json'),JSON.stringify({checks,errors,utc:new Date().toISOString()},null,2));
}
process.exit(checks.every(x=>x.ok)?0:1);
