from pathlib import Path
import json, urllib.request, concurrent.futures
p=Path('assets/environment/blightwood_water/source')
jobs={'surface_base':'26e80d32-973d-4c0d-9e00-f9feb0d46ef4','waterfall_base':'1bf6156f-6425-4c1a-94db-02dfbdd07686','foam_base':'d8a1b33f-7de2-44c3-bde3-719e750a058c','surface':'053beb03-8def-4dc6-944e-82bf7a19dcd0','foam':'f0803fa4-a672-426e-aec0-2517d1c44926','waterfall':'b1b91e05-6ad6-4dad-8e4a-8fb1aea9548d'}
(p/'pixellab-jobs.json').write_text(json.dumps({'provider':'PixelLab','jobs':jobs,'selected_candidates':{'surface':2,'foam':3,'waterfall':0},'source_frames':17,'delivered_frames':16,'loop_closure':'Drop final pinned input duplicate; no frame interpolation.'},indent=2))
def download(pair):
 name,job,i=pair;target=p/f'{name}-{i:02}.png'
 if not target.exists():
  with urllib.request.urlopen(f'https://api.pixellab.ai/mcp/images/{job}/download?index={i}',timeout=90) as r:target.write_bytes(r.read())
 return target.name
if __name__=='__main__':
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
  for name in pool.map(download,[(name,jobs[name],i) for name in ['surface','foam','waterfall'] for i in range(17)]): print(name,flush=True)
