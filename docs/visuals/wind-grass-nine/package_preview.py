from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
frames=[Image.open(ROOT/f'build/grass-loop/{i:03}.png').convert('RGB') for i in range(144)]
palette=frames[0].quantize(colors=256)
frames=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
frames[0].save(ROOT/'docs/visuals/wind-grass-nine/grass-wind-144.gif',save_all=True,append_images=frames[1:],duration=[50 if i%6==5 else 40 for i in range(144)],loop=0,optimize=True,disposal=1)
print('PASS packaged144 real grass wind frames, six-second loop, nearest/no dither')
