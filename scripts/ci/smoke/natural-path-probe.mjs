import {chromium} from 'playwright';
import {mkdirSync,writeFileSync} from 'node:fs';
import path from 'node:path';
import {startStaticServer} from './lib/serve.mjs';
const arg=n=>{const i=process.argv.indexOf('--'+n);return i<0?undefined:process.argv[i+1]};
const out=arg('out-dir');mkdirSync(out,{recursive:true});
const server=arg('serve-dir')?await startStaticServer(arg('serve-dir')):null;
const base=arg('url')||server.url;
const browser=await chromium.launch({headless:true});
const checks=[],errors=[],states={};
const check=(name,ok,detail)=>{checks.push({name,ok,detail});console.log(`${ok?'PASS':'FAIL'} ${name}`)};
try{
 for(const mode of ['before','after']){
  const context=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block'});
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
  await page.goto(base+(base.includes('?')?'&':'?')+'path=review'+(mode==='before'?'&path_before=1':''));
  await page.waitForFunction(()=>window.__PATH_REVIEW__?.ready===true,null,{timeout:180000});
  await page.waitForTimeout(1000);
  const state=()=>page.evaluate(()=>({...window.__PATH_REVIEW__}));
  const start=await state();states[mode]=start;
  check(mode+' uses actual main map',start.floor_count>2000,start);
  check(mode+' comparison selected',start.natural===(mode==='after'),start);
  await page.screenshot({path:path.join(out,mode+'.png')});
  await page.mouse.click(630,550);
  await page.keyboard.down('KeyD');await page.waitForTimeout(1300);await page.keyboard.up('KeyD');
  const moved=await state();
  check(mode+' player can cross clearing',moved.player_x>start.player_x+20,{start,moved});
  await page.keyboard.down('KeyS');await page.waitForTimeout(700);await page.keyboard.up('KeyS');
  await page.screenshot({path:path.join(out,mode+'-movement.png')});
  await context.close();
 }
 check('floor/object counts unchanged',states.before.floor_count===states.after.floor_count,states);
 check('collision obstacle count unchanged',states.before.obstacles===states.after.obstacles,states);
 check('no browser/engine errors',errors.length===0,errors);
}catch(e){check('probe completed',false,String(e))}
finally{
 await browser.close();if(server)await server.close();
 writeFileSync(path.join(out,'result.json'),JSON.stringify({checks,errors,states,utc:new Date().toISOString()},null,2));
}
process.exit(checks.every(x=>x.ok)?0:1);
