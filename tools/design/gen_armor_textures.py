#!/usr/bin/env python3
"""Generates tileable PBR texture sets for the hero armour models
(assets/textures/armor/<set>_{albedo,normal,roughness,metallic,emission}.png).

Sets:
  dark_steel     blackened hammered plate with scratches and worn highlights
  infernal_steel dark steel split by glowing lava cracks (emission map)
  cloth          heavy dyed wool (greyscale, tinted in the material)
  leather        dark worn leather straps / grips

All maps tile seamlessly (FFT-filtered noise and wrap-around Voronoi).
Run:  python3 tools/design/gen_armor_textures.py
"""
import os
import numpy as np
from PIL import Image

N = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "armor")
rng = np.random.default_rng(1666)


def fnoise(scale, power=2.0, seed=None):
    """Periodic fractal noise: white noise shaped by 1/f^power in frequency space."""
    r = np.random.default_rng(seed) if seed is not None else rng
    w = r.standard_normal((N, N))
    fx = np.fft.fftfreq(N)[:, None]
    fy = np.fft.fftfreq(N)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / (f * scale + 1e-3) ** power
    amp *= np.exp(-(f * N / (scale * 1.0)) ** 2 * 0.0)
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * amp))
    out -= out.min()
    return out / out.max()


def band(lo, hi):
    """Band-limited periodic noise with features between N/hi and N/lo pixels."""
    w = rng.standard_normal((N, N))
    fx = np.fft.fftfreq(N)[:, None] * N
    fy = np.fft.fftfreq(N)[None, :] * N
    f = np.sqrt(fx * fx + fy * fy)
    m = np.exp(-((np.log(f + 1e-6) - np.log((lo + hi) * 0.5)) ** 2) / (2 * 0.45 ** 2))
    m[0, 0] = 0
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * m))
    out -= out.min()
    return out / out.max()


def voronoi_edges(cells, seed):
    """Distance to the nearest Voronoi edge (F2 - F1), tileable."""
    r = np.random.default_rng(seed)
    pts = r.random((cells, 2)) * N
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    f1 = np.full((N, N), 1e9, np.float32)
    f2 = np.full((N, N), 1e9, np.float32)
    for px, py in pts:
        dx = np.abs(xx - px)
        dx = np.minimum(dx, N - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, N - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        f1 = np.where(closer, d, f1)
    return f2 - f1


def scratches(count, seed, length=(40, 220)):
    """Thin straight scratches (value 1 inside), wrapped around the tile."""
    r = np.random.default_rng(seed)
    img = np.zeros((N, N), np.float32)
    for _ in range(count):
        x, y = r.random(2) * N
        a = r.random() * np.pi
        ln = r.uniform(*length)
        depth = r.uniform(0.3, 1.0)
        steps = int(ln)
        xs = (x + np.cos(a) * np.arange(steps)).astype(int) % N
        ys = (y + np.sin(a) * np.arange(steps)).astype(int) % N
        fade = np.sin(np.linspace(0, np.pi, steps)) * depth
        np.maximum.at(img, (ys, xs), fade)
    return img


def blur(img, k=1):
    out = img.copy()
    for _ in range(k):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5.0
    return out


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + nz * nz)
    # OpenGL convention (Godot): +Y up in the green channel.
    n = np.stack([-dx / l, dy / l, nz / l], -1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name, arr):
    os.makedirs(OUT, exist_ok=True)
    if arr.dtype != np.uint8:
        arr = (np.clip(arr, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(arr).save(os.path.join(OUT, name + ".png"), optimize=True)
    print("wrote", name)


def rgb(c, v):
    return np.stack([v * c[0], v * c[1], v * c[2]], -1)


def steel_base(seed_off=0):
    hammer = band(10, 28)            # hammer dents
    grain = band(120, 300)            # fine brushed grain
    large = fnoise(3.0, 1.6, 11 + seed_off)
    sc = blur(scratches(220, 3 + seed_off, (30, 140)), 1) * 0.7
    sc_big = blur(scratches(18, 5 + seed_off, (150, 420)), 2) * 0.8
    height = hammer * 0.55 + grain * 0.12 - sc * 0.5 - sc_big * 0.8
    return hammer, grain, large, sc, sc_big, height


def gen_dark_steel():
    hammer, grain, large, sc, sc_big, height = steel_base()
    wear = np.clip((sc * 1.2 + sc_big * 1.0), 0, 1)
    grime = np.clip((large - 0.45) * 2.2, 0, 1)
    v = 0.055 + 0.05 * hammer + 0.03 * grain
    v = v * (1 - grime * 0.45) + wear * 0.22
    alb = rgb((0.92, 0.95, 1.05), v)
    save("dark_steel_albedo", alb)
    save("dark_steel_normal", normal_from_height(height, 6.0))
    rough = 0.34 + 0.18 * grain + 0.3 * grime - 0.18 * wear
    save("dark_steel_roughness", rough)
    save("dark_steel_metallic", 0.92 - grime * 0.35)


def gen_infernal():
    hammer, grain, large, sc, sc_big, height = steel_base(7)
    e1 = voronoi_edges(34, 21)
    e2 = voronoi_edges(140, 22)
    warp = band(8, 30)
    width = 2.2 + warp * 4.0
    crack = np.clip(1.0 - e1 / width, 0, 1) ** 1.5
    crack2 = np.clip(1.0 - e2 / (1.0 + warp * 1.5), 0, 1) ** 2 * 0.7
    mask_big = np.clip((fnoise(4.0, 1.4, 31) - 0.25) * 2.0, 0, 1)
    c = np.clip(crack * (0.55 + 0.45 * mask_big) + crack2 * mask_big * 0.8, 0, 1)
    rim = np.clip(blur(c, 4) * 1.6 - c, 0, 1)          # scorched margin round the cracks
    wear = np.clip(sc * 1.1 + sc_big * 0.9, 0, 1)
    v = 0.05 + 0.045 * hammer + 0.025 * grain + wear * 0.18
    v *= 1 - rim * 0.6
    alb = rgb((1.0, 0.93, 0.9), v)
    alb = alb * (1 - c[..., None]) + np.stack([0.55 * c, 0.12 * c, 0.02 * c], -1)
    save("infernal_steel_albedo", alb)
    save("infernal_steel_normal", normal_from_height(height - c * 1.4 - rim * 0.4, 6.0))
    save("infernal_steel_roughness", np.clip(0.36 + 0.2 * grain - 0.15 * wear + c * 0.4 + rim * 0.25, 0, 1))
    save("infernal_steel_metallic", np.clip(0.9 - c * 0.9 - rim * 0.3, 0, 1))
    hot = np.clip(c * 1.25, 0, 1)
    em = np.stack([hot, hot ** 1.6 * 0.55, hot ** 3 * 0.12], -1)
    save("infernal_steel_emission", em)


def gen_cloth():
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    k = 2 * np.pi * 96 / N
    weave = (np.sin(xx * k) * np.sin(yy * k) * 0.5 + 0.5)
    fibre = band(200, 450)
    blot = fnoise(3.0, 1.5, 41)
    wear = np.clip((band(6, 18) - 0.62) * 3.0, 0, 1)
    v = 0.5 + 0.18 * weave + 0.12 * fibre - 0.25 * (blot - 0.5) - wear * 0.2
    save("cloth_albedo", np.stack([v, v, v], -1))
    save("cloth_normal", normal_from_height(weave * 0.8 + fibre * 0.3, 3.0))
    save("cloth_roughness", np.clip(0.85 + 0.1 * fibre, 0, 1))
    save("cloth_metallic", np.zeros((N, N)))


def gen_leather():
    cells = np.clip(voronoi_edges(1400, 51) / 5.0, 0, 1)
    pores = band(150, 400)
    blot = fnoise(3.0, 1.5, 52)
    sc = blur(scratches(300, 53, (20, 90)), 1)
    v = 0.1 + 0.025 * cells + 0.03 * pores + 0.05 * (blot - 0.5) + sc * 0.08
    save("leather_albedo", rgb((1.0, 0.72, 0.52), v * 1.4))
    save("leather_normal", normal_from_height(cells * 0.6 + pores * 0.3 - sc * 0.5, 3.5))
    save("leather_roughness", np.clip(0.6 + 0.15 * pores - sc * 0.2, 0, 1))
    save("leather_metallic", np.zeros((N, N)))


if __name__ == "__main__":
    gen_dark_steel()
    gen_infernal()
    gen_cloth()
    gen_leather()
