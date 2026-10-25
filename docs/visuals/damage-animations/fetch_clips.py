"""Download indexed PixelLab images into controlled source paths, never extract archives."""
from pathlib import Path
import concurrent.futures, json, urllib.request, io
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[3]
DOC=Path(__file__).parent
state_file=DOC/'state.json'
jobs=json.loads((state_file if state_file.exists() else DOC/'pilot-receipts.json').read_text())
def fetch(item):
    who,name,direction,jid,count,source_dir=item
    out=ROOT/f'assets/characters/{who}/damage/source/{source_dir}'
    out.resolve().relative_to((ROOT/f'assets/characters/{who}/damage/source').resolve())
    out.mkdir(parents=True,exist_ok=True)
    paths=[]
    for i in range(count+1):
        path=out/f'{i:03}.png'
        if not path.exists():
            url=f'https://api.pixellab.ai/mcp/images/{jid}/download?index={i}'
            with urllib.request.urlopen(url,timeout=90) as response:blob=response.read(2_000_001)
            assert blob.startswith(b'\x89PNG\r\n\x1a\n') and len(blob)<=2_000_000
            im=Image.open(io.BytesIO(blob));assert im.size==(128,128) and im.mode=='RGBA',(im.size,im.mode)
            path.write_bytes(blob)
        paths.append(path)
    sheet=Image.new('RGBA',(8*128,((count+8)//8)*152),'#263944')
    draw=ImageDraw.Draw(sheet)
    for i,path in enumerate(paths):
        x,y=(i%8)*128,(i//8)*152
        sheet.alpha_composite(Image.open(path),(x,y+20))
        draw.text((x+4,y+3),f'{who} {name} {direction} {i}',fill='white')
    sheet.save(DOC/f'{who}-{name}-{direction}-source.png')
    return who,name,len(paths)
if __name__=='__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(fetch,[(j['character'],j['animation'],j['direction'],j['job_id'],j['frame_count'],j.get('source_dir') or f"{j['animation']}/{j['direction']}") for j in jobs if j.get('state','completed')=='completed']):print(result)
