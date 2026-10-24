from pathlib import Path
import concurrent.futures,urllib.request,zipfile,re
ROOT=Path(__file__).resolve().parents[3];S=ROOT/'assets/environment/blightwood_shorelines/source'
JOBS={'grass':'51372a6f-7221-4c5b-98d3-936cecf8537d','dirt':'7218731e-526f-4099-a0b3-e8401381ce70','rock':'449d7ed3-1510-4537-a907-4c4780080ef2'}
def fetch(family):
 archive=S/f'{family}-source.zip'
 if not archive.exists():
  if family=='grass' and (S/'grass-download.bin').exists():(S/'grass-download.bin').rename(archive)
  else:
   with urllib.request.urlopen(f'https://api.pixellab.ai/mcp/tiles-pro/{JOBS[family]}/download',timeout=120) as r:archive.write_bytes(r.read())
 with zipfile.ZipFile(archive) as z:
  files=[i for i in z.infolist() if i.filename.endswith('.png')];assert len(files)==16
  for item in files:
   assert item.file_size<1000000
   index=int(re.search(r'_(\d+)\.png$',item.filename)[1]);assert 0<=index<16
   data=z.read(item);assert data.startswith(b'\x89PNG');(S/f'{family}-{index:02}.png').write_bytes(data)
 return family
if __name__=='__main__':
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
  for family in pool.map(fetch,JOBS):print(family+'16 sources saved',flush=True)
