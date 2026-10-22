// Read-only telemetry; every state change below uses real mouse/keyboard input.
import { chromium } from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import { startStaticServer } from '../../../scripts/ci/smoke/lib/serve.mjs';
import { mkdirSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
const target=process.argv[2]||'../chakra-review-web', out=process.argv[3]||'build/chakra-browser';
const capture=process.argv.includes('--capture');
mkdirSync(out,{recursive:true}); if(capture)mkdirSync(out+'/frames',{recursive:true});
const server=target.startsWith('https:')?null:await startStaticServer(target,{port:0});
const base=server?.url||target, checks=[],errors=[];
const b=await chromium.launch({headless:true});
const p=await b.newPage({viewport:{width:1280,height:720}});
p.on('pageerror',e=>errors.push(String(e)));
p.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|^ERROR:/.test(m.text()))errors.push(m.text())});
const ck=(name,ok,detail='')=>{checks.push({name,ok,detail});console.log(`${ok?'PASS':'FAIL'} ${name} ${detail}`);if(!ok)throw Error(name)};
const st=()=>p.evaluate(()=>({...window.__CHAKRA_STATE__}));
async function click(name){const rect=JSON.parse((await st()).controls_json)[name];if(!rect)throw Error('missing control '+name);await p.mouse.click(rect[0]+rect[2]/2,rect[1]+rect[3]/2);await p.waitForTimeout(65)}
try{
 await p.goto(base+'?chakra=review');
 await p.waitForFunction(()=>window.__CHAKRA_STATE__?.ready,null,{timeout:90000});
 await p.waitForTimeout(300);
 ck('eight directions and default half speed',(await st()).directions===8&&(await st()).speed===.5);
 await p.screenshot({path:out+'/review.png'});
 await click('Pause');let a=await st();await p.waitForTimeout(350);let c=await st();
 ck('pause freezes exact timeline',a.time===c.time&&c.paused);
 await click('Step');ck('single authored phase step',(await st()).phase===(c.phase+1)%96);
 a=await st();for(let i=0;i<96;i++)await click('Step');
 ck('96 phase loop returns exactly',(await st()).phase===a.phase);
 for(const dir of ['S','SE','E','NE','N','NW','W','SW']){await click(dir);ck('direction '+dir,(await st()).direction===dir);await p.screenshot({path:out+'/direction-'+dir+'.png'})}
 for(const color of ['Violet','Amber','Crimson','Jade','Blue']){await click(color);ck('palette '+color,(await st()).color===color);await p.screenshot({path:out+'/palette-'+color+'.png'})}
 for(const [label,id] of [['Flame','aura'],['Spirals','wisps'],['Ground','ground']]){await click(label);ck('separate '+id,JSON.parse((await st()).layers_json)[id]===false);await click(label)}
 await click('Charge on/off');await p.waitForTimeout(500);ck('charge fades out',(await st()).opacity===0);
 await click('Charge on/off');await p.waitForTimeout(500);ck('charge fades in',(await st()).opacity===1);
 await click('Normal');a=await st();await p.waitForTimeout(500);c=await st();ck('normal speed advances',c.speed===1&&!c.paused&&c.time!==a.time);
 await click('Half speed');a=await st();await p.waitForTimeout(500);c=await st();ck('half speed advances',c.speed===.5&&!c.paused&&c.time!==a.time);
 await click('Gameplay zoom');ck('gameplay zoom available',(await st()).zoom>0);
 await click('Inspect 2x');ck('inspect zoom',(await st()).zoom===2);
 // Reload to the default framing before exporting the complete rendered loop.
 if(capture){
  await p.reload();await p.waitForFunction(()=>window.__CHAKRA_STATE__?.ready,null,{timeout:90000});await click('Pause');await click('S');
  const hashes=new Set();
  for(let i=0;i<96;i++){
   let state=await st();const png=await p.screenshot({path:out+'/frames/'+String(state.phase).padStart(3,'0')+'.png',clip:{x:420,y:35,width:440,height:510}});
   hashes.add(createHash('sha256').update(png).digest('hex'));await click('Step');
   if(i%16===0)console.log('captured',i+1,'/96');
  }
  ck('96 distinct rendered phases',hashes.size===96,String(hashes.size));
 }
 await p.goto(base+'?camera=close');
 await p.waitForFunction(()=>window.__SHINOBI_READY__&&window.__CHAKRA_GAME__?.ready,null,{timeout:90000});
 await p.locator('canvas').click({position:{x:640,y:360}});
 await p.keyboard.down('KeyR');await p.waitForFunction(()=>window.__CHAKRA_GAME__.presenting);
 let game=await p.evaluate(()=>({...window.__CHAKRA_GAME__}));
 ck('hold R displays charge body',game.body_visible&&!game.base_visible);
 await p.waitForTimeout(400);await p.screenshot({path:out+'/in-game.png'});
 await p.keyboard.up('KeyR');await p.waitForTimeout(450);
 game=await p.evaluate(()=>({...window.__CHAKRA_GAME__}));ck('release restores production body',!game.presenting&&!game.body_visible&&game.base_visible&&game.opacity===0);
 await p.keyboard.down('KeyR');await p.waitForFunction(()=>window.__CHAKRA_GAME__.presenting);
 const before=await p.evaluate(()=>({...window.__SHINOBI_STATE__}));await p.keyboard.down('KeyD');await p.waitForTimeout(350);
 game=await p.evaluate(()=>({...window.__CHAKRA_GAME__}));const after=await p.evaluate(()=>({...window.__SHINOBI_STATE__}));
 ck('moving cancels visual and preserves movement',!game.presenting&&after.x>before.x);
 await p.keyboard.up('KeyD');await p.keyboard.up('KeyR');
 // BUILD tab observed in the actual in-game screenshot at the right edge.
 await p.mouse.click(1230,420);await p.waitForFunction(()=>window.__EDITOR_STATE__?.open);
 await p.keyboard.down('KeyR');await p.waitForTimeout(200);
 ck('world builder blocks charge preview',!(await p.evaluate(()=>window.__CHAKRA_GAME__.presenting)));
 await p.keyboard.up('KeyR');
 ck('no browser or Godot runtime errors',errors.length===0,errors.join('\n'));
}catch(e){errors.push(String(e));process.exitCode=1;await p.screenshot({path:out+'/failure.png'}).catch(()=>{})}
finally{writeFileSync(out+'/proof.json',JSON.stringify({base,checks,errors},null,2));await b.close();await server?.close()}
