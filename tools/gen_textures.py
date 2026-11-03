import sys
import numpy as np
from PIL import Image

N = 64
ROOT = sys.argv[1] if len(sys.argv) > 1 else "."

YY, XX = np.mgrid[0:N, 0:N]


def fnoise(seed, beta=1.8, ax=1.0, ay=1.0):
    r = np.random.default_rng(seed)
    fx = np.fft.fftfreq(N)[None, :] * N
    fy = np.fft.fftfreq(N)[:, None] * N
    f = np.sqrt((fx * ax) ** 2 + (fy * ay) ** 2)
    f[0, 0] = 1.0
    amp = 1.0 / f ** (beta / 2.0)
    amp[0, 0] = 0.0
    a = np.fft.ifft2(np.fft.fft2(r.standard_normal((N, N))) * amp).real
    lo, hi = np.percentile(a, 2), np.percentile(a, 98)
    return np.clip((a - lo) / (hi - lo), 0.0, 1.0)


def mixn(seed, w=(0.5, 0.3, 0.2), betas=(2.8, 1.6, 0.5), ax=1.0, ay=1.0):
    t = 0.0
    for i, (wi, bi) in enumerate(zip(w, betas)):
        t = t + wi * fnoise(seed * 7 + i, bi, ax, ay)
    return np.clip(t / sum(w), 0.0, 1.0)


def smooth(a, e0, e1):
    t = np.clip((a - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def ramp(v, stops):
    xs = [s[0] for s in stops]
    return np.stack([np.interp(v, xs, [s[1][c] for s in stops]) for c in range(3)], -1)


def grit(arr, seed, s=0.08):
    r = np.random.default_rng(seed)
    return arr * (1.0 + (r.random((N, N, 1)) - 0.5) * s * 2.0)


def speckle(arr, seed, p=0.03, amt=0.25):
    r = np.random.default_rng(seed)
    m = r.random((N, N)) < p
    s = np.where(r.random((N, N)) < 0.5, 1.0 - amt, 1.0 + amt)
    return arr * np.where(m, s, 1.0)[..., None]


def disk(cx, cy, rad):
    return (XX - cx) ** 2 + (YY - cy) ** 2 <= rad * rad


def over(arr, mask, color, a=1.0):
    m = (mask.astype(float) * a)[..., None]
    return arr * (1.0 - m) + np.array(color, float) * m


def mul(arr, mask, k):
    return arr * (1.0 + (k - 1.0) * mask.astype(float))[..., None]


def grade(arr):
    lum = arr @ np.array([0.3, 0.59, 0.11])
    arr = lum[..., None] + (arr - lum[..., None]) * 0.88
    arr = arr * np.array([0.99, 1.0, 0.94])
    return np.clip(arr, 0, 255)


STONE = [(0, (30, 33, 26)), (0.35, (70, 75, 60)), (0.65, (108, 111, 95)), (1, (156, 157, 143))]
DIRT = [(0, (26, 19, 11)), (0.5, (68, 51, 32)), (1, (112, 92, 66))]
GRASS = [(0, (20, 31, 17)), (0.5, (52, 71, 36)), (1, (104, 120, 70))]
SAND = [(0, (118, 106, 76)), (0.5, (164, 150, 112)), (1, (204, 192, 154))]
WOOD = [(0, (26, 17, 10)), (0.45, (66, 45, 28)), (0.8, (100, 76, 52)), (1, (128, 108, 84))]
PLANK = [(0, (56, 37, 22)), (0.5, (102, 73, 44)), (1, (150, 118, 78))]
STEEL = [(0, (38, 46, 54)), (0.5, (82, 96, 108)), (1, (138, 152, 162))]


def cracks(seed, depth=0.5, width=0.022):
    ridge = np.abs(fnoise(seed, 2.4) - 0.5)
    return 1.0 - depth * smooth(width - ridge, 0.0, width)


def stone(seed=11):
    v = mixn(seed)
    c = ramp(v, STONE)
    c = c * cracks(seed + 30)[..., None]
    c = speckle(c, seed + 1, 0.04, 0.22)
    return grit(c, seed + 2, 0.05)


def dirt(seed=21):
    v = mixn(seed, (0.4, 0.3, 0.3), (2.4, 1.2, 0.2))
    c = ramp(v, DIRT)
    pebbles = fnoise(seed + 5, 0.6) > 0.9
    c = over(c, pebbles, (104, 98, 84), 0.55)
    c = speckle(c, seed + 3, 0.05, 0.3)
    return grit(c, seed + 4, 0.06)


def grass_top(seed=31):
    v = mixn(seed, (0.35, 0.35, 0.3), (2.6, 1.0, 0.1))
    c = ramp(v, GRASS)
    tufts = fnoise(seed + 5, 0.9) > 0.88
    c = over(c, tufts, (118, 126, 72), 0.35)
    c = speckle(c, seed + 3, 0.06, 0.28)
    return grit(c, seed + 4, 0.07)


def grass_side(seed=41):
    base = dirt(seed + 1)
    top = grass_top(seed + 2)
    r = np.random.default_rng(seed)
    h = 11 + 5 * fnoise(seed + 9, 1.0)[0] + r.integers(-2, 3, N)
    h = np.clip(h, 8, 20)
    hm = YY < h[None, :]
    out = np.where(hm[..., None], top * (0.78 + 0.22 * (1.0 - YY / 22.0))[..., None], base)
    edge = (YY >= h[None, :]) & (YY < h[None, :] + 4)
    out = mul(out, edge, 0.72)
    return out


def sand(seed=51):
    grain = mixn(seed, (0.3, 0.3, 0.4), (2.0, 1.0, 0.1))
    ripple = 0.5 + 0.5 * np.sin((YY / N + 0.08 * fnoise(seed + 4, 3.0)) * 2 * np.pi * 5)
    v = np.clip(0.65 * grain + 0.35 * ripple * 0.8, 0, 1)
    c = ramp(v, SAND)
    c = speckle(c, seed + 3, 0.05, 0.18)
    return grit(c, seed + 5, 0.05)


def snow(seed=61):
    v = mixn(seed, (0.5, 0.3, 0.2), (3.0, 1.6, 0.4))
    c = ramp(v, [(0, (148, 156, 164)), (0.5, (204, 210, 212)), (1, (236, 238, 236))])
    sp = np.random.default_rng(seed).random((N, N)) > 0.985
    c = over(c, sp, (250, 252, 252), 0.8)
    return grit(c, seed + 2, 0.03)


def bedrock(seed=71):
    v = mixn(seed, (0.5, 0.3, 0.2), (2.2, 1.4, 0.5))
    c = ramp(v, [(0, (6, 6, 8)), (0.6, (24, 24, 26)), (1, (56, 56, 60))])
    c = c * cracks(seed + 8, 0.7, 0.03)[..., None]
    return grit(c, seed + 2, 0.08)


def ore(seed, kind):
    c = stone(seed + 100)
    b = fnoise(seed, 1.7)
    m = smooth(b, 0.76, 0.8)
    if kind == "coal":
        v = mixn(seed + 3, (0.6, 0.4), (1.2, 0.4))
        lump = ramp(v, [(0, (6, 6, 8)), (0.6, (22, 22, 26)), (1, (60, 62, 66))])
    else:
        v = mixn(seed + 3, (0.6, 0.4), (1.4, 0.6))
        lump = ramp(v, [(0, (74, 38, 24)), (0.5, (128, 68, 40)), (1, (176, 106, 62))])
    rim = smooth(b, 0.72, 0.76) * (1.0 - m)
    c = mul(c, rim, 0.55)
    c = c * (1 - m[..., None]) + lump * m[..., None]
    if kind == "iron":
        fl = fnoise(seed + 9, 0.8) > 0.93
        c = over(c, fl, (150, 160, 168), 0.5)
    return grit(c, seed + 4, 0.05)


def bark(seed=81, dark=1.0):
    v = mixn(seed, (0.5, 0.3, 0.2), (2.0, 1.4, 0.6), ax=1.0, ay=8.0)
    c = ramp(v, WOOD)
    fis = np.abs(fnoise(seed + 5, 1.6, 1.0, 9.0) - 0.5)
    c = c * (1.0 - 0.6 * smooth(0.03 - fis, 0.0, 0.03))[..., None]
    c = speckle(c, seed + 6, 0.03, 0.2)
    return grit(c, seed + 7, 0.05) * dark


def planks(seed=91, rows=4):
    ph = N // rows
    out = np.zeros((N, N, 3))
    r = np.random.default_rng(seed)
    for i in range(rows):
        g = mixn(seed + i * 3, (0.5, 0.3, 0.2), (2.0, 1.4, 0.6), ax=8.0, ay=1.0)
        c = ramp(np.clip(g + (r.random() - 0.5) * 0.25, 0, 1), PLANK)
        out[i * ph:(i + 1) * ph] = c[i * ph:(i + 1) * ph]
    ly = YY % ph
    out = mul(out, ly == 0, 0.35)
    out = mul(out, ly == 1, 1.12)
    out = mul(out, ly == ph - 1, 0.82)
    for i in range(rows):
        cy = i * ph + ph // 2
        for cx in (6, 57):
            out = over(out, disk(cx, cy, 1.6), (30, 22, 16), 0.9)
            out = over(out, disk(cx - 1, cy - 1, 0.8), (150, 140, 124), 0.4)
    out = speckle(out, seed + 40, 0.02, 0.2)
    return grit(out, seed + 41, 0.04)


def bricks(seed, stops, tint=1.0, mortar=(18, 19, 15)):
    v = mixn(seed)
    base = ramp(v, stops)
    base = base * cracks(seed + 30, 0.35, 0.018)[..., None]
    row = YY // 16
    off = (row % 2) * 16
    bx = (XX + off) % N
    bid = row * 2 + bx // 32
    rr = np.random.default_rng(seed + 5)
    var = 0.86 + 0.28 * rr.random(8)
    base = base * var[bid][..., None] * tint
    lx = bx % 32
    ly = YY % 16
    mort = (ly < 2) | (lx < 2)
    base = mul(base, ly == 2, 1.18)
    base = mul(base, ly >= 14, 0.8)
    mn = 0.8 + 0.4 * fnoise(seed + 9, 0.8)
    mc = np.array(mortar, float)[None, None, :] * mn[..., None]
    out = np.where(mort[..., None], mc, base)
    out = speckle(out, seed + 7, 0.03, 0.2)
    return grit(out, seed + 8, 0.05)


def sandstone(seed=101):
    v = mixn(seed, (0.6, 0.3, 0.1), (2.6, 1.4, 0.4), ax=7.0, ay=1.0)
    band = 0.5 + 0.5 * np.sin((YY / N + 0.05 * fnoise(seed + 3, 3.0)) * 2 * np.pi * 4)
    vv = np.clip(0.7 * v + 0.3 * band, 0, 1)
    c = ramp(vv, [(0, (104, 84, 56)), (0.5, (152, 128, 88)), (1, (192, 168, 124))])
    c = speckle(c, seed + 3, 0.05, 0.18)
    return grit(c, seed + 5, 0.05)


def metal(seed, stops=STEEL):
    v = mixn(seed, (0.4, 0.3, 0.3), (2.0, 1.2, 0.6), ax=9.0, ay=1.0)
    c = ramp(v, stops)
    sc = fnoise(seed + 4, 0.5, 9.0, 1.0) > 0.95
    c = over(c, sc, (180, 190, 196), 0.25)
    return grit(c, seed + 6, 0.04)


def rivet(arr, cx, cy, color=(36, 38, 40)):
    arr = over(arr, disk(cx + 1, cy + 1, 3.4), (10, 10, 12), 0.5)
    arr = over(arr, disk(cx, cy, 3.0), color, 1.0)
    arr = over(arr, disk(cx - 1, cy - 1, 1.2), (170, 176, 180), 0.55)
    return arr


def iron_block(seed=111):
    c = metal(seed)
    b = 5
    inner = (XX >= b) & (XX < N - b) & (YY >= b) & (YY < N - b)
    c = mul(c, inner, 0.88)
    top = (YY < b) | (XX < b)
    bot = (YY >= N - b) | (XX >= N - b)
    c = mul(c, top & ~inner, 1.25)
    c = mul(c, bot & ~inner, 0.65)
    c = mul(c, (YY == b) & inner, 0.7)
    for cx, cy in ((10, 10), (N - 11, 10), (10, N - 11), (N - 11, N - 11)):
        c = rivet(c, cx, cy)
    streak = fnoise(seed + 9, 1.6, 1.0, 10.0)
    rust = smooth(streak, 0.62, 0.9) * (0.35 + 0.65 * (YY / N))
    c = c * (1 - 0.5 * rust[..., None]) + np.array([118, 62, 34]) * (0.5 * rust[..., None])
    return c


def fortified(seed=121):
    c = bricks(seed, [(0, (22, 25, 28)), (0.5, (52, 58, 64)), (1, (88, 96, 104))], 1.0, (10, 11, 13))
    f = metal(seed + 2, [(0, (24, 28, 32)), (0.5, (56, 64, 72)), (1, (96, 106, 114))])
    b = 6
    inner = (XX >= b) & (XX < N - b) & (YY >= b) & (YY < N - b)
    c = np.where(inner[..., None], c, f)
    c = mul(c, (YY == b - 1) | (XX == b - 1), 0.55)
    c = mul(c, (YY < 2) | (XX < 2), 1.3)
    c = mul(c, (YY >= N - 2) | (XX >= N - 2), 0.6)
    for cx, cy in ((3, 3), (N - 4, 3), (3, N - 4), (N - 4, N - 4)):
        c = over(c, disk(cx, cy, 1.9), (130, 78, 48), 1.0)
        c = over(c, disk(cx - 0.5, cy - 0.5, 0.7), (190, 140, 96), 0.7)
    return c


def workbench_side(seed=131):
    c = planks(seed, 4) * 0.9
    c = mul(c, YY < 12, 1.12)
    c = mul(c, (YY >= 12) & (YY < 14), 0.45)
    frame = ((XX >= 8) & (XX < N - 8) & (YY >= 20) & (YY < N - 6))
    inner = ((XX >= 11) & (XX < N - 11) & (YY >= 23) & (YY < N - 9))
    c = mul(c, frame & ~inner, 0.5)
    c = mul(c, inner, 0.85)
    c = mul(c, inner & (XX >= 31) & (XX <= 32), 0.5)
    c = over(c, disk(26, 40, 2.0), (30, 26, 22), 1.0)
    c = over(c, disk(37, 40, 2.0), (30, 26, 22), 1.0)
    c = over(c, disk(25.5, 39.5, 0.8), (150, 140, 120), 0.5)
    return c


def workbench_top(seed=141):
    c = planks(seed, 4) * 1.05
    edge = (XX < 4) | (XX >= N - 4) | (YY < 4) | (YY >= N - 4)
    c = mul(c, edge, 0.62)
    c = mul(c, ((XX == 4) | (YY == 4)) & ~edge, 0.7)
    r = np.random.default_rng(seed)
    for _ in range(14):
        x = r.integers(8, 52)
        y = r.integers(8, 56)
        ln = r.integers(4, 10)
        c = over(c, (YY == y) & (XX >= x) & (XX < x + ln), (170, 140, 100), 0.3)
    return c


def torch_base(seed=151):
    c = bark(seed, 0.55)
    ash = fnoise(seed + 5, 1.2) > 0.82
    c = over(c, ash, (88, 88, 82), 0.35)
    r = np.random.default_rng(seed)
    em = r.random((N, N)) > 0.997
    c = over(c, em, (210, 110, 40), 0.9)
    return c


def tile_set():
    return {
        "grass_top": grass_top(),
        "grass_side": grass_side(),
        "dirt": dirt(),
        "stone": stone(),
        "bedrock": bedrock(),
        "sand": sand(),
        "snow": snow(),
        "coal_ore": ore(201, "coal"),
        "iron_ore": ore(211, "iron"),
        "wood": bark(),
        "plank": planks(),
        "stone_brick": bricks(161, STONE),
        "sandstone": sandstone(),
        "iron_block": iron_block(),
        "fortified_brick": fortified(),
        "workbench_side": workbench_side(),
        "workbench_top": workbench_top(),
        "torch_base": torch_base(),
    }


def to_img(arr, alpha=None):
    rgb = np.clip(grade(arr), 0, 255).astype(np.uint8)
    a = np.full((N, N, 1), 255, np.uint8) if alpha is None else alpha[..., None].astype(np.uint8)
    return Image.fromarray(np.concatenate([rgb, a], -1), "RGBA")


SS = 256


def label_canvas(draw_fn, angle=0.0):
    from PIL import ImageDraw
    im = Image.new("L", (SS, SS), 0)
    d = ImageDraw.Draw(im)
    draw_fn(d)
    if angle:
        im = im.rotate(angle, resample=Image.NEAREST, center=(SS / 2, SS / 2))
    a = np.array(im).reshape(N, SS // N, N, SS // N).transpose(0, 2, 1, 3).reshape(N, N, -1)
    out = np.zeros((N, N), np.int32)
    labs = [k for k in np.unique(a) if k != 0]
    best = np.zeros((N, N))
    for k in labs:
        cnt = (a == k).sum(-1)
        sel = cnt > best
        out = np.where(sel, k, out)
        best = np.where(sel, cnt, best)
    empty = (a == 0).sum(-1)
    out = np.where(empty >= 9, 0, out)
    return out


def outline(lab):
    m = lab > 0
    p = np.pad(m, 1)
    nb = p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return nb & ~m


def finish_item(arr, lab):
    ol = outline(lab)
    arr = over(arr, ol, (8, 8, 10), 1.0)
    alpha = np.where((lab > 0) | ol, 255, 0)
    return to_img(arr, alpha)


def sword_item():
    def draw(d):
        d.polygon([(128, 14), (142, 40), (142, 160), (114, 160), (114, 40)], fill=1)
        d.rectangle([123, 40, 128, 156], fill=2)
        d.rectangle([129, 40, 142, 160], fill=3)
        d.rectangle([72, 160, 184, 178], fill=4)
        d.rectangle([118, 178, 138, 224], fill=5)
        d.ellipse([112, 220, 144, 252], fill=6)
    lab = label_canvas(draw, -45)
    blade = metal(301, [(0, (60, 70, 80)), (0.5, (120, 134, 146)), (1, (200, 210, 216))])
    guard = ramp(mixn(302, (0.5, 0.5), (1.5, 0.5)), [(0, (46, 32, 20)), (1, (132, 100, 58))])
    wrap = 0.5 + 0.5 * np.sin((XX + YY) / N * 2 * np.pi * 9)
    grip = ramp(wrap * 0.7 + 0.3 * fnoise(303, 1.0), [(0, (30, 20, 14)), (1, (84, 58, 38))])
    out = np.zeros((N, N, 3))
    out = np.where((lab == 1)[..., None], blade, out)
    out = np.where((lab == 2)[..., None], blade * 0.62, out)
    out = np.where((lab == 3)[..., None], blade * 1.18, out)
    out = np.where((lab == 4)[..., None], guard, out)
    out = np.where((lab == 5)[..., None], grip, out)
    out = np.where((lab == 6)[..., None], guard * 1.15, out)
    return finish_item(out, lab)


def coal_item():
    th = np.linspace(0, 2 * np.pi, 90)
    r = 92 + 12 * np.sin(3 * th + 1) + 8 * np.sin(5 * th + 2) + 5 * np.sin(8 * th)

    def draw(d):
        pts = [(128 + rr * np.cos(t), 134 + rr * 0.82 * np.sin(t)) for rr, t in zip(r, th)]
        d.polygon(pts, fill=1)
    lab = label_canvas(draw)
    light = 1.0 - (XX + YY) / (2.0 * N)
    v = np.clip(0.55 * light + 0.45 * mixn(311, (0.6, 0.4), (1.8, 0.8)), 0, 1)
    c = ramp(v, [(0, (6, 6, 8)), (0.5, (24, 25, 29)), (1, (78, 80, 86))])
    facet = np.abs(fnoise(312, 2.0) - 0.5) < 0.018
    c = mul(c, facet, 0.5)
    sp = np.random.default_rng(313).random((N, N)) > 0.985
    c = over(c, sp, (130, 136, 142), 0.7)
    m = lab > 0
    p = np.pad(m, 2)
    inner = p[2:-2, 2:-2] & p[:-4, 2:-2] & p[4:, 2:-2] & p[2:-2, :-4] & p[2:-2, 4:]
    c = mul(c, m & ~inner, 0.6)
    return finish_item(c, lab)


def iron_item():
    def draw(d):
        d.polygon([(70, 92), (186, 92), (218, 134), (38, 134)], fill=1)
        d.polygon([(38, 134), (218, 134), (208, 184), (48, 184)], fill=2)
        d.rectangle([40, 134, 216, 138], fill=3)
    lab = label_canvas(draw)
    v = mixn(321, (0.5, 0.3, 0.2), (2.0, 1.2, 0.6), ax=6.0, ay=1.0)
    top = ramp(v, [(0, (74, 70, 66)), (0.5, (126, 124, 120)), (1, (178, 176, 170))])
    front = top * 0.62
    rustm = smooth(fnoise(322, 1.5), 0.55, 0.8)[..., None]
    rust = ramp(fnoise(323, 1.2), [(0, (92, 46, 28)), (1, (170, 98, 56))])
    out = np.zeros((N, N, 3))
    out = np.where((lab == 1)[..., None], top, out)
    out = np.where((lab == 2)[..., None], front, out)
    out = np.where((lab == 3)[..., None], top * 1.2, out)
    out = out * (1 - 0.7 * rustm) + rust * 0.7 * rustm
    out = grit(out, 324, 0.05)
    return finish_item(out, lab)


def main():
    import os
    os.makedirs(ROOT + "/art/tiles", exist_ok=True)
    os.makedirs(ROOT + "/art/items", exist_ok=True)
    tiles = tile_set()
    for k, v in tiles.items():
        to_img(v).save(f"{ROOT}/art/tiles/{k}.png")
    items = {"sword": sword_item(), "coal": coal_item(), "iron": iron_item()}
    for k, v in items.items():
        v.save(f"{ROOT}/art/items/{k}.png")
    names = list(tiles) + list(items)
    cols = 6
    rows = (len(names) + cols - 1) // cols
    cell = 128
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (14, 15, 12, 255))
    for i, n in enumerate(names):
        p = f"{ROOT}/art/{'items' if n in items else 'tiles'}/{n}.png"
        im = Image.open(p).resize((cell, cell), Image.NEAREST)
        sheet.paste(im, ((i % cols) * cell, (i // cols) * cell), im)
    sheet.save(ROOT + "/art/reference_sheet.png")


main()
