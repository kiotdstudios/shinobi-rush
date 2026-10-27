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
try{
 const context=await browser.newContext({viewport:{width:1280,height:720},serviceWorkers:'block'});
 const page=await context.newPage();
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
 await page.goto(base+(base.includes('?')?'&':'?')+'pathdirt=review');
 await page.waitForFunction(()=>window.__PATH_DIRT_REVIEW__?.ready===true,null,{timeout:180000});
 const state=()=>page.evaluate(()=>({...window.__PATH_DIRT_REVIEW__}));
 const start=await state();
 check('native transition tiles placed in actual map',start.pieces===121,start);
 check('dedicated builder filter exists',start.filter===true,start);
 await page.screenshot({path:path.join(out,'gameplay.png')});
 await page.mouse.click(640,500);
 await page.keyboard.down('KeyD');await page.waitForTimeout(1100);await page.keyboard.up('KeyD');
 const moved=await state();
 check('real player crosses blended ground',moved.player_x>start.player_x+20,{start,moved});
 await page.screenshot({path:path.join(out,'movement.png')});
 check('no engine/browser errors',errors.length===0,errors);
 await context.close();
}catch(e){check('probe completed',false,String(e))}
finally{
 await browser.close();if(server)await server.close();
 writeFileSync(path.join(out,'result.json'),JSON.stringify({checks,errors,utc:new Date().toISOString()},null,2));
}
process.exit(checks.every(x=>x.ok)?0:1);
