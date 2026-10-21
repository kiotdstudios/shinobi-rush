"""Fetch ONLY URLs returned by get_character; bulk archive is locked while jobs run."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import re,json,zipfile,subprocess
ROOT=Path(__file__).resolve().parent;text=(ROOT/'character-status.txt').read_text(encoding='utf-8')
jobs=[];frames={'rotations':{},'animations':{}};section=None;action=None
for line in text.splitlines():
 if line=='rotations:':section='rotations';continue
 if line.startswith('animations ('):section='animations';continue
 if section=='rotations':
  match=re.match(r'  ([a-z-]+): (https://\S+)',line)
  if match:
   direction,url=match.groups();path=f'Idle/rotations/{direction}.png';frames['rotations'][direction]=path;jobs.append((path,url))
 elif section=='animations':
  match=re.match(r'  ([a-zA-Z0-9_-]+) — ',line)
  if match:
   action={'breathing-idle':'bandit_idle_v1','running-8-frames':'bandit_run_v1'}.get(match.group(1),match.group(1));frames['animations'].setdefault(action,{})
  match=re.match(r'    ([a-z-]+): (https://\S+) \(i=0\.\.(\d+)\)',line)
  if match and action:
   direction,url,last=match.groups();paths=[]
   for i in range(int(last)+1):
    path=f'Idle/animations/{action}/{direction}/frame_{i:03}.png';paths.append(path);jobs.append((path,url.replace('{i}',str(i))))
   frames['animations'][action][direction]=paths
cache=ROOT/'cache';old=json.loads((ROOT/'cache-urls.json').read_text()) if (ROOT/'cache-urls.json').exists() else {}
def fetch(job):
 path,url=job;dest=cache/path;dest.parent.mkdir(parents=True,exist_ok=True)
 if not dest.exists() or old.get(path)!=url:
  data=subprocess.run(['curl.exe','--fail','--silent','--show-error','--retry','3','--retry-all-errors','--connect-timeout','20','--max-time','60',url],capture_output=True,check=True).stdout
  assert data[:8]==b'\x89PNG\r\n\x1a\n';dest.write_bytes(data)
 return path,url
with ThreadPoolExecutor(max_workers=8) as pool:results=list(pool.map(fetch,jobs))
(ROOT/'cache-urls.json').write_text(json.dumps(dict(results),indent=2)+'\n')
metadata={'states':[{'character':{'id':'cc675e30-2723-4145-b03f-c0d245294305'},'folder':'Idle','frames':frames}]}
with zipfile.ZipFile(ROOT/'character.zip','w',zipfile.ZIP_DEFLATED) as z:
 z.writestr('metadata.json',json.dumps(metadata))
 for path,url in results:z.write(cache/path,path)
print('Downloaded/cached',len(results),'native PNGs; clips',{k:list(v) for k,v in frames['animations'].items()})
