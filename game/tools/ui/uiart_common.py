"""Shared helpers for the Famiglia UI art generator (see make_ui_art.py).

Everything is numpy float arrays in 0..1. Noise is band-limited through an FFT
filter, which makes it seamless (periodic) by construction.
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(GAME, "assets", "ui")
FONTS = os.path.join(GAME, "assets", "fonts")


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float) / 255.0


# The brief's palette.
PAPER = hexc("e9dfc7")
PAPER2 = hexc("d9ccae")
LEDGER_PAPER = hexc("ece5cb")
NEWS = hexc("ddd5bf")
TELEGRAM = hexc("ecdcaa")
INK = hexc("1e140a")
OX = hexc("8b1e1a")
NAVY = hexc("2b3a55")
BRASS = hexc("b08d57")
GREEN = hexc("2f4a38")
SEPIA = hexc("5a3f24")


def font(name, size):
    """Load a font; "File.ttf@900" selects a weight on a variable font."""
    wght = None
    if "@" in name:
        name, wght = name.split("@")
    f = ImageFont.truetype(os.path.join(FONTS, name), size)
    if wght:
        f.set_variation_by_axes([int(wght)])
    return f


def save(arr, rel):
    """Save an HxWx4 (or HxWx3) float array as PNG under assets/ui/<rel>."""
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    a = np.clip(arr, 0.0, 1.0)
    mode = "RGBA" if a.shape[2] == 4 else "RGB"
    Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), mode).save(path, optimize=True)
    return path


def save_img(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    return path


def pnoise(h, w, cutoff, rng, per=256.0):
    """Seamless band-limited noise, zero mean, unit std. `cutoff` = cycles per `per` px."""
    wn = rng.standard_normal((h, w))
    F = np.fft.fft2(wn)
    fy = np.fft.fftfreq(h)[:, None] * per
    fx = np.fft.fftfreq(w)[None, :] * per
    r = np.sqrt(fy * fy + fx * fx)
    n = np.real(np.fft.ifft2(F * np.exp(-(r / cutoff) ** 2)))
    n -= n.mean()
    n /= n.std() + 1e-9
    return n


def fbm(h, w, base, octaves, rng, gain=0.5):
    s = np.zeros((h, w))
    a = 1.0
    tot = 0.0
    for i in range(octaves):
        s += a * pnoise(h, w, base * 2 ** i, rng)
        tot += a
        a *= gain
    return s / tot


def to_arr(img):
    return np.asarray(img, dtype=np.float64) / 255.0


def from_mask(m):
    return Image.fromarray((np.clip(m, 0, 1) * 255 + 0.5).astype(np.uint8), "L")


def blur(m, r):
    return to_arr(from_mask(m).filter(ImageFilter.GaussianBlur(r)))


def shift(m, dx, dy):
    """Shift a 2D array by integer pixels (content moves by +dx,+dy), zero fill."""
    out = np.zeros_like(m)
    h, w = m.shape
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = m[ys0:ys1, xs0:xs1]
    return out


def erode(m, r):
    size = int(r) * 2 + 1
    return to_arr(from_mask(m).filter(ImageFilter.MinFilter(size)))


def dilate(m, r):
    size = int(r) * 2 + 1
    return to_arr(from_mask(m).filter(ImageFilter.MaxFilter(size)))


def down(m, factor):
    """Box/lanczos downsample a 2D mask or HxWxC array by an integer factor."""
    if m.ndim == 2:
        img = from_mask(m)
        return to_arr(img.resize((m.shape[1] // factor, m.shape[0] // factor), Image.LANCZOS))
    chans = [down(m[..., c], factor) for c in range(m.shape[2])]
    return np.stack(chans, -1)


def premul_down(rgba, factor):
    """Downsample RGBA with premultiplied alpha so edges don't fringe."""
    a = rgba[..., 3]
    rgb = rgba[..., :3] * a[..., None]
    rgb_d = down(rgb, factor)
    a_d = down(a, factor)
    out = np.zeros(rgb_d.shape[:2] + (4,))
    out[..., :3] = rgb_d / np.maximum(a_d[..., None], 1e-4)
    out[..., 3] = a_d
    return np.clip(out, 0, 1)


def over(dst, src_rgb, src_a):
    """Composite src over dst (both straight alpha). dst HxWx4."""
    da = dst[..., 3]
    oa = src_a + da * (1 - src_a)
    rgb = (src_rgb * src_a[..., None] + dst[..., :3] * (da * (1 - src_a))[..., None]) / np.maximum(oa[..., None], 1e-6)
    out = np.empty_like(dst)
    out[..., :3] = rgb
    out[..., 3] = oa
    return out


def mix(a, b, t):
    t = np.asarray(t)
    if t.ndim == 2:
        t = t[..., None]
    return a * (1 - t) + b * t


def wrapped_dist(X, Y, cx, cy, w, h):
    dx = (X - cx + w / 2) % w - w / 2
    dy = (Y - cy + h / 2) % h - h / 2
    return np.sqrt(dx * dx + dy * dy)


def paper_tile(size, base, seed, cloud=0.045, grain=0.03, fibres=260, fox=5, fox_amt=0.22,
               specks=0, light_fibres=0.05, dark_fibres=0.10):
    """A seamless paper tile (size x size) -> HxWx3 float."""
    rng = np.random.default_rng(seed)
    h = w = size
    lum = 1.0 + fbm(h, w, 2.2, 4, rng) * cloud + pnoise(h, w, 150, rng) * grain
    # fibres at 2x, drawn with wrap-around so the tile stays seamless
    S = 2
    layers = []
    for layer in range(2):
        im = Image.new("L", (w * S, h * S), 0)
        d = ImageDraw.Draw(im)
        for _ in range(fibres // 2):
            x, y = rng.uniform(0, w * S), rng.uniform(0, h * S)
            L = rng.uniform(5, 22) * S
            a = rng.uniform(0, 2 * math.pi)
            curv = rng.uniform(-0.12, 0.12)
            pts = []
            px, py = x, y
            for t in range(7):
                pts.append((px, py))
                a += curv
                px += math.cos(a) * L / 6
                py += math.sin(a) * L / 6
            val = int(rng.integers(90, 230))
            for ox in (-w * S, 0, w * S):
                for oy in (-h * S, 0, h * S):
                    d.line([(p[0] + ox, p[1] + oy) for p in pts], fill=val, width=1)
        layers.append(to_arr(im.resize((w, h), Image.LANCZOS)))
    lum -= layers[0] * dark_fibres
    lum += layers[1] * light_fibres
    rgb = base[None, None, :] * lum[..., None]
    X, Y = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    foxcol = np.array([0.62, 0.45, 0.26])
    fx = np.zeros((h, w))
    for _ in range(fox):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(2.0, 9.0)
        dd = wrapped_dist(X, Y, cx, cy, w, h)
        fx = np.maximum(fx, np.exp(-(dd / r) ** 2) * rng.uniform(0.4, 1.0))
        # a few satellite dots
        for _ in range(int(rng.integers(0, 4))):
            sx, sy = cx + rng.normal(0, r * 1.5), cy + rng.normal(0, r * 1.5)
            dd = wrapped_dist(X, Y, sx, sy, w, h)
            fx = np.maximum(fx, np.exp(-(dd / (r * 0.3)) ** 2) * 0.7)
    rgb = mix(rgb, foxcol * base * 1.05, fx * fox_amt)
    if specks:
        sp = np.zeros((h, w))
        for _ in range(specks):
            cx, cy = rng.uniform(0, w), rng.uniform(0, h)
            dd = wrapped_dist(X, Y, cx, cy, w, h)
            sp = np.maximum(sp, np.clip(1.2 - dd / rng.uniform(0.4, 1.1), 0, 1) * rng.uniform(0.3, 0.9))
        rgb = mix(rgb, INK, sp * 0.55)
    return np.clip(rgb, 0, 1)


def edge_fn(n, P, amp, rng, kmax=48, rough=1.0):
    """Periodic (period P) edge displacement for n samples, 0..amp."""
    x = np.arange(n) + 0.5
    f = np.zeros(n)
    for k in range(1, kmax):
        a = (1.0 / k ** 0.75) * rng.uniform(0.3, 1.0) * (rough if k > 10 else 1.0)
        f += a * np.sin(2 * np.pi * k * x / P + rng.uniform(0, 2 * np.pi))
    f = (f - f.min()) / (f.max() - f.min() + 1e-9)
    return f * amp


def text_mask(text, fnt, pad=0, spacing=0):
    """Render text to an L mask array trimmed to its bbox (+pad)."""
    if spacing:
        widths = [fnt.getbbox(ch)[2] - fnt.getbbox(ch)[0] if ch != " " else fnt.size * 0.35 for ch in text]
        adv = [fnt.getlength(ch) for ch in text]
        tw = int(sum(adv) + spacing * (len(text) - 1)) + 2
    else:
        tw = int(fnt.getlength(text)) + 2
    asc, desc = fnt.getmetrics()
    im = Image.new("L", (tw + 2 * pad + 8, asc + desc + 2 * pad + 8), 0)
    d = ImageDraw.Draw(im)
    if spacing:
        x = pad + 4
        for ch in text:
            d.text((x, pad + 4), ch, font=fnt, fill=255)
            x += fnt.getlength(ch) + spacing
    else:
        d.text((pad + 4, pad + 4), text, font=fnt, fill=255)
    bb = im.getbbox()
    im = im.crop((bb[0] - pad, bb[1] - pad, bb[2] + pad, bb[3] + pad))
    return to_arr(im)
