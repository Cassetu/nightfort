import argparse
import numpy as np
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument("input")
p.add_argument("name")
p.add_argument("--kind", choices=["tile", "item"], default="tile")
p.add_argument("--root", default=".")
p.add_argument("--size", type=int, default=64)
p.add_argument("--murk", type=float, default=0.35)
p.add_argument("--darken", type=float, default=1.1)
a = p.parse_args()

im = Image.open(a.input).convert("RGBA")
w, h = im.size
s = min(w, h)
im = im.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))
im = im.resize((a.size, a.size), Image.LANCZOS)
arr = np.array(im).astype(float)
rgb = arr[..., :3]
alpha = arr[..., 3]

if a.kind == "tile":
    n = a.size
    t = np.sin(np.linspace(0, np.pi, n))
    wgt = np.outer(t, t)[..., None]
    shifted = np.roll(rgb, (n // 2, n // 2), (0, 1))
    rgb = rgb * wgt + shifted * (1.0 - wgt)
    alpha = np.full_like(alpha, 255)
else:
    alpha = np.where(alpha >= 128, 255, 0)

lum = (rgb @ np.array([0.299, 0.587, 0.114]))[..., None]
rgb = lum + (rgb - lum) * (1.0 - a.murk)
rgb = rgb * np.array([0.98, 1.0, 0.92])
rgb = 255.0 * (np.clip(rgb / 255.0, 0, 1) ** a.darken)

out = np.concatenate([np.clip(rgb, 0, 255), alpha[..., None]], -1).astype(np.uint8)
folder = "tiles" if a.kind == "tile" else "items"
path = f"{a.root}/art/{folder}/{a.name}.png"
Image.fromarray(out, "RGBA").save(path)
print(path)
