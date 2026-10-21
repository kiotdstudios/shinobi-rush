const $=id=>document.getElementById(id);
const manifest=await fetch('../bandit_128.art.json?v=sprint-arms-v3').then(r=>{if(!r.ok)throw Error(r.status);return r.json()});
const cache=new Map();
await Promise.all(Object.values(manifest.animations).flatMap(a=>Object.values(a.frames).flat()).map(async path=>{const im=new Image();im.src='../'+path+'?v=sprint-arms-v3';await im.decode();cache.set(path,im)}));
let elapsed=0,previous=performance.now(),playing=true,cards=[];
function build(){cards=[];$('grid').replaceChildren();const a=manifest.animations[$('action').value];const dirs=$('all').checked?manifest.directions:[$('direction').value];
for(const dir of dirs){const article=document.createElement('article'),label=document.createElement('p'),canvas=document.createElement('canvas');label.textContent=`${$('action').value} · ${dir}`;canvas.width=128;canvas.height=128;article.append(label,canvas);$('grid').append(article);cards.push({canvas,dir,frames:a.frames[dir]??[]})}
$('scrub').max=Math.max(0,...cards.map(c=>c.frames.length-1));elapsed=0;render()}
function render(){const a=manifest.animations[$('action').value],frame=Math.floor(elapsed*a.authored_fps);for(const card of cards){card.canvas.style.width=`min(100%, ${$('zoom').value}px)`;const ctx=card.canvas.getContext('2d');ctx.clearRect(0,0,128,128);if(card.frames.length)ctx.drawImage(cache.get(card.frames[frame%card.frames.length]),0,0)}const n=cards[0]?.frames.length??0;$('scrub').value=n?frame%n:0;$('clock').textContent=`Clock ${elapsed.toFixed(2)} s · Frame ${n?frame%n:0}/${Math.max(0,n-1)} · ${a.authored_fps*Number($('speed').value)} FPS`}
for(const id of ['action','direction','all'])$(id).addEventListener('change',build);
$('play').onclick=()=>{playing=!playing;$('play').textContent=playing?'Pause':'Play'};
$('reset').onclick=()=>{elapsed=0;render()};
$('scrub').oninput=()=>{playing=false;$('play').textContent='Play';elapsed=Number($('scrub').value)/manifest.animations[$('action').value].authored_fps;render()};
function tick(now){if(playing)elapsed+=(now-previous)/1000*Number($('speed').value);previous=now;render();requestAnimationFrame(tick)}build();requestAnimationFrame(tick);
