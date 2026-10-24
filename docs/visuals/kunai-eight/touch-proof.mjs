import {chromium} from '../../../scripts/ci/smoke/node_modules/playwright/index.mjs';
import {startStaticServer} from '../../../scripts/ci/smoke/lib/serve.mjs';
import {mkdirSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const out=process.env.KUNAI_OUT||'build/kunai-eight-touch';mkdirSync(out,{recursive:true});
const server=process.env.KUNAI_URL?null:await startStaticServer('../kunai-eight-final-web',{port:0});
const b=await chromium.launch({headless:true});const results=[];
try {for(const viewport of [{width:390,height:844},{width:844,height:390}]) {
 const context=await b.newContext({viewport,isMobile:true,hasTouch:true,deviceScaleFactor:1});
 const p=await context.newPage(),errors=[];p.on('pageerror',e=>errors.push(String(e)));
 await p.goto((process.env.KUNAI_URL||server.url)+'?kunai=directions');
 await p.waitForFunction(()=>window.__KUNAI_EIGHT__?.ready,null,{timeout:120000});
 const tap=async label=>{const r=await p.evaluate(label=>JSON.parse(window.__KUNAI_EIGHT__.controls_json)[label],label);const box=await p.locator('canvas').boundingBox();
  const scale=Math.min(box.width/1280,box.height/720),ox=box.x+(box.width-1280*scale)/2,oy=box.y+(box.height-720*scale)/2;
  await p.touchscreen.tap(ox+(r[0]+r[2]/2)*scale,oy+(r[1]+r[3]/2)*scale);await p.waitForTimeout(80)};
 await tap('Pause');assert(await p.evaluate(()=>window.__KUNAI_EIGHT__.paused));
 await tap('NW');assert.equal(await p.evaluate(()=>window.__KUNAI_EIGHT__.direction),'NW');
 await tap('Step');assert.equal(await p.evaluate(()=>window.__KUNAI_EIGHT__.frame),1);
 await tap('bandit');assert.equal(await p.evaluate(()=>window.__KUNAI_EIGHT__.character),'bandit');
 await p.screenshot({path:`${out}/${viewport.width}x${viewport.height}.png`});assert.deepEqual(errors,[]);
 results.push({viewport,result:'PASS',errors});await context.close();
 }writeFileSync(`${out}/touch.json`,JSON.stringify(results,null,2));console.log('PASS: portrait and landscape phone emulation, actual touch direction/step/skin controls');
} finally {await b.close();if(server)await server.close()}
