import numpy as np, sys, glob, os
from PIL import Image

def erode(m):
    p=np.pad(m,1,constant_values=True); o=m.copy()
    for dy in (-1,0,1):
        for dx in (-1,0,1):
            o&=p[1+dy:1+dy+m.shape[0],1+dx:1+dx+m.shape[1]]
    return o
def nbrs(m):
    p=np.pad(m,1).astype(int); t=0
    for dy in (-1,0,1):
        for dx in (-1,0,1):
            if dy or dx: t=t+p[1+dy:1+dy+m.shape[0],1+dx:1+dx+m.shape[1]]
    return t
def clean(im):
    a=np.array(im.convert('RGBA')).astype(np.int32)
    rgb=a[...,:3]; al=a[...,3]
    solid=al>=128
    for _ in range(2):
        mx=rgb.max(-1); mn=rgb.min(-1)
        whiteish=(mn>205)&((mx-mn)<28)
        er=erode(solid)
        edge=solid&~er
        kill=edge&whiteish
        solid=solid&~kill
    # remove isolated specks
    solid&=nbrs(solid)>=2
    # bleed interior colour into remaining 1px edge pixels that are brighter than their interior neighbours
    er=erode(solid)
    edge=solid&~er
    out=a.copy()
    inter=er
    for y,x in zip(*np.nonzero(edge)):
        ys=slice(max(0,y-1),y+2); xs=slice(max(0,x-1),x+2)
        m=inter[ys,xs]
        if m.any():
            nb=rgb[ys,xs][m]
            cur=rgb[y,x]
            if cur.mean()>nb.mean()+25:
                out[y,x,:3]=np.median(nb,axis=0)
    out[...,3]=np.where(solid,255,0)
    out[~solid,:3]=0
    return Image.fromarray(out.astype(np.uint8),'RGBA')
if __name__=='__main__':
    d=sys.argv[1]; dst=sys.argv[2]; os.makedirs(dst,exist_ok=True)
    for f in sorted(glob.glob(d+'/tree_*.png')):
        clean(Image.open(f)).save(os.path.join(dst,os.path.basename(f)))
