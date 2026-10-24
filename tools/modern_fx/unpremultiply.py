"""Convert transparent SubViewport output to straight alpha for standard sprites."""
from pathlib import Path
import numpy as np
from PIL import Image
for path in (Path(__file__).resolve().parents[2]/'client/effects/modern_atlas').glob('spell_*.png'):
    pixels=np.array(Image.open(path).convert('RGBA'))
    alpha=pixels[:,:,3:4].astype(np.float32)
    pixels[:,:,:3]=np.clip(np.rint(pixels[:,:,:3].astype(np.float32)*255/np.maximum(alpha,1)),0,255).astype(np.uint8)
    pixels[alpha[:,:,0]==0,:3]=0
    temporary=path.with_suffix('.tmp.png')
    Image.fromarray(pixels).save(temporary,optimize=True)
    Image.open(temporary).verify()
    temporary.replace(path)
