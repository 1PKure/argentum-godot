"""Run once immediately after bake.gd: straight alpha and a compact RGBA palette."""
from pathlib import Path
import numpy as np
from PIL import Image
path = Path(__file__).resolve().parents[2]/'client/effects/modern_atlas/meditation.png'
pixels = np.array(Image.open(path).convert('RGBA'))
alpha = pixels[:,:,3:4].astype(np.float32)
pixels[:,:,:3] = np.clip(np.rint(pixels[:,:,:3].astype(np.float32)*255/np.maximum(alpha,1)),0,255).astype(np.uint8)
pixels[alpha[:,:,0]==0,:3] = 0
image = Image.fromarray(pixels).quantize(colors=256,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE)
image.save(path,optimize=True)
