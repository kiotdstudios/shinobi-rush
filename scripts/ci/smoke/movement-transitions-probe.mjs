import {chromium} from 'playwright';
import {mkdirSync,writeFileSync} from 'node:fs';
import path from 'node:path';
import {startStaticServer} from './lib/serve.mjs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir');mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir')):null;
const base=arg('url')||server.url;
const browser=await chromium.launch({headless:true});
const results=[],errors=[];
const check=(name,ok,detail)=>{results.push({name,ok,detail});console.log(`${ok?'PASS':'FAIL'} ${name}`)};
try{
 for(const mode of ['before','after']){
  const context=await browser.newContext({viewport:{width:1280,height:720},recordVideo:{dir:path.join(out,mode),size:{width:1280,height:720}},serviceWorkers:'block'});
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
  await page.goto(base+(base.includes('?')?'&':'?')+'movement=review'+(mode==='before'?'&before=1':''));
  await page.waitForFunction(()=>window.__MOVEMENT_REVIEW__?.ready===true,null,{timeout:120000});
  await page.mouse.click(620,600);
  const state=()=>page.evaluate(()=>({...window.__MOVEMENT_REVIEW__}));
  const start=await state();
  await page.keyboard.down('KeyD');await page.waitForTimeout(350);
  const moved=await state();
  check(mode+' real input moves immediately',moved.player_x>start.player_x+5,moved);
  await page.keyboard.down('KeyW');await page.keyboard.up('KeyD');await page.waitForTimeout(350);
  await page.keyboard.down('KeyS');await page.keyboard.up('KeyW');await page.waitForTimeout(350);
  await page.keyboard.up('KeyS');await page.waitForTimeout(300);
  await page.screenshot({path:path.join(out,mode+'-brake.png')});
  await page.keyboard.down('ShiftLeft');await page.keyboard.down('KeyA');await page.waitForTimeout(350);
  await page.keyboard.up('KeyA');await page.keyboard.up('ShiftLeft');await page.waitForTimeout(300);
  await page.keyboard.down('KeyD');await page.waitForTimeout(30);await page.keyboard.press('KeyJ');await page.waitForTimeout(80);
  const attack=await state();
  check(mode+' attack interrupts traversal',!attack.player_animation.startsWith('move_'),attack);
  await page.keyboard.up('KeyD');await page.waitForTimeout(1200);
  await page.waitForTimeout(3000);
  const end=await state(),events=JSON.parse(end.events_json);
  if(mode==='after'){
   for(const kind of ['start','stop','pivot'])check('player '+kind+' observed',events.player[kind]>0,events);
   for(const kind of ['start','stop'])check('bandit '+kind+' observed in real patrol',events.bandit[kind]>0,events);
   check('bandit patrol keeps moving',Math.hypot(end.bandit_x-start.bandit_x,end.bandit_y-start.bandit_y)>10,{start,end});
  }else check('before comparison disables only transitions',Object.keys(events.player).length===0&&Object.keys(events.bandit).length===0,events);
  await page.screenshot({path:path.join(out,mode+'-gameplay.png')});
  writeFileSync(path.join(out,mode+'-state.json'),JSON.stringify({start,end,events},null,2));
  await context.close();
 }
 check('no browser/engine errors',errors.length===0,errors);
}catch(e){check('probe completed',false,String(e))}
finally{
 await browser.close();if(server)await server.close();
 writeFileSync(path.join(out,'result.json'),JSON.stringify({results,errors,utc:new Date().toISOString()},null,2));
}
process.exit(results.every(x=>x.ok)?0:1);
