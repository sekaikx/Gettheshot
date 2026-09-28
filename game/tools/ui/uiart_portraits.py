"""Woodcut / steel-engraving portrait medallions for dialogs (called from make_ui_art.py).

A portrait is described as tone regions (darkness 0..1 plus the direction the graver
follows in that region) and ink strokes for the features. It is rendered as a line
screen: each region is cut with parallel (slightly curved) lines whose thickness grows
with darkness, and a cross-hatch layer is added in the shadows. The result sits in an
oval medallion with a twisted-rope border on cream paper.

Coordinates are units: x 0..100 across, y 0..125 down.
"""
import math
import numpy as np
from PIL import Image, ImageDraw
from uiart_common import (to_arr, from_mask, blur, erode, down, pnoise, paper_tile, save, mix,
                          PAPER, INK, OX)


class Plate:
    def __init__(self, final_w, S=4, seed=0):
        self.S = S
        self.fw = final_w
        self.W = final_w * S
        self.H = int(final_w * 1.25) * S
        self.u = self.W / 100.0
        self.rng = np.random.default_rng(seed)
        self.X, self.Y = np.meshgrid(np.arange(self.W) + 0.5, np.arange(self.H) + 0.5)
        self.D = np.zeros((self.H, self.W))
        self.Ucoord = np.zeros((self.H, self.W))
        self.V = np.zeros((self.H, self.W))
        self.outl = np.zeros((self.H, self.W))
        self.feat = Image.new("L", (self.W, self.H), 0)
        self.fd = ImageDraw.Draw(self.feat)
        self.carve = Image.new("L", (self.W, self.H), 0)
        self.cd = ImageDraw.Draw(self.carve)

    # -- geometry helpers
    def P(self, pts):
        return [(x * self.u, y * self.u) for x, y in pts]

    def mask(self, kind, *a):
        im = Image.new("L", (self.W, self.H), 0)
        d = ImageDraw.Draw(im)
        if kind == "poly":
            d.polygon(self.P(a[0]), fill=255)
        elif kind == "ell":
            x0, y0, x1, y1 = a
            d.ellipse([x0 * self.u, y0 * self.u, x1 * self.u, y1 * self.u], fill=255)
        elif kind == "rect":
            x0, y0, x1, y1 = a
            d.rectangle([x0 * self.u, y0 * self.u, x1 * self.u, y1 * self.u], fill=255)
        elif kind == "chord":
            x0, y0, x1, y1, s, e = a
            d.chord([x0 * self.u, y0 * self.u, x1 * self.u, y1 * self.u], s, e, fill=255)
        return to_arr(im)

    def region(self, m, d, angle, curv=0.0, c=(50, 60), outline=False, lit=None):
        """Fill mask m with darkness d (scalar or array); graver lines at `angle` degrees.
        lit=(lx, ly, cx, cy, r, amt): add form shading (darker away from the light)."""
        a = math.radians(angle)
        cx, cy = c[0] * self.u, c[1] * self.u
        dx, dy = self.X - cx, self.Y - cy
        along = dx * math.cos(a) + dy * math.sin(a)
        perp = -dx * math.sin(a) + dy * math.cos(a)
        u = perp + curv * along * along / (30 * self.u)
        dd = np.full_like(self.D, d) if np.isscalar(d) else d
        if lit:
            lx, ly, lcx, lcy, lr, amt = lit
            nx = (self.X - lcx * self.u) / (lr * self.u)
            ny = (self.Y - lcy * self.u) / (lr * self.u)
            dot = np.clip(-(nx * lx + ny * ly), -1, 1)
            dd = dd + amt * (0.5 - 0.5 * dot)
        sel = m > 0.5
        self.D = np.where(sel, dd, self.D)
        self.Ucoord = np.where(sel, u, self.Ucoord)
        self.V = np.where(sel, along, self.V)
        if outline:
            self.outline(m)

    def darken(self, m, amt, soft=2.0):
        mm = blur(m, soft * self.S) if soft else m
        self.D = np.clip(self.D + mm * amt, 0, 1.2)

    def outline(self, m, w=1.1):
        e = erode((m > 0.5).astype(float), max(1, int(w * self.S)))
        self.outl = np.maximum(self.outl, (m > 0.5) * (1 - e))

    def stroke(self, pts, w, carve=False):
        d = self.cd if carve else self.fd
        pp = self.P(pts)
        wd = max(1, int(w * self.u))
        d.line(pp, fill=255, width=wd, joint="curve")
        for x, y in (pp[0], pp[-1]):
            r = wd / 2.2
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)

    def blob(self, kind, *a, carve=False):
        d = self.cd if carve else self.fd
        if kind == "ell":
            x0, y0, x1, y1 = a
            d.ellipse([x0 * self.u, y0 * self.u, x1 * self.u, y1 * self.u], fill=255)
        elif kind == "poly":
            d.polygon(self.P(a[0]), fill=255)

    def ring(self, x0, y0, x1, y1, w, carve=False):
        d = self.cd if carve else self.fd
        d.ellipse([x0 * self.u, y0 * self.u, x1 * self.u, y1 * self.u], outline=255, width=max(1, int(w * self.u)))

    def dots(self, m, density, r=0.35, seed=0):
        rng = np.random.default_rng(seed)
        ys, xs = np.nonzero(m[::4, ::4] > 0.5)
        n = int(len(xs) * density)
        if n == 0:
            return
        idx = rng.choice(len(xs), n, replace=False)
        for i in idx:
            x, y = xs[i] * 4, ys[i] * 4
            rr = r * self.u * rng.uniform(0.6, 1.2)
            self.fd.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)

    # -- render
    def render(self, period):
        S = self.S
        per = period * S
        wob = pnoise(self.H, self.W, 30, self.rng, per=self.W) * 0.06 * per
        u = (self.Ucoord + wob) / per
        tri = np.abs(u - np.floor(u) - 0.5) * 2  # 1 at line centre .. 0 between
        D = np.clip(self.D, 0, 1.3)
        ink = np.clip((tri - (1 - D * 0.95)) * 5 + 0.5, 0, 1) * (D > 0.04)
        # cross hatch in the shadows
        v = (self.V + wob) / per
        tri2 = np.abs(v - np.floor(v) - 0.5) * 2
        D2 = np.clip((D - 0.55) * 1.7, 0, 1)
        ink = np.maximum(ink, np.clip((tri2 - (1 - D2 * 0.9)) * 5 + 0.5, 0, 1) * (D2 > 0.02))
        ink = np.maximum(ink, np.clip((D - 1.0) * 8, 0, 1))
        ink = np.maximum(ink, self.outl)
        ink = np.maximum(ink, to_arr(self.feat))
        ink = ink * (1 - to_arr(self.carve))
        return down(ink, S)


# ------------------------------------------------------------------------------ parts

L = (-0.55, -0.45)  # light from the upper left


def base(pl, dark_bg=0.16):
    """Background line screen inside the oval (horizontal lines, darker to the right)."""
    full = np.ones((pl.H, pl.W))
    d = dark_bg + 0.20 * (pl.X / pl.W) + 0.06 * (pl.Y / pl.H)
    pl.region(full, d, 0)


def coat(pl, d=0.72, lapels=True, shirt=True, tie=True, shoulders=(6, 98), neck_w=11, open_v=True, collar_up=False):
    l, r = shoulders
    body = [(l - 6, 126), (l, 102), (18, 92), (37, 85.5), (63, 85.5), (82, 92), (r, 102), (r + 6, 126)]
    m = pl.mask("poly", body)
    pl.region(m, d, 62, lit=(L[0], L[1], 50, 110, 50, 0.3), outline=True)
    if shirt:
        v = [(50 - neck_w, 86), (50, 116 if open_v else 100), (50 + neck_w, 86)]
        ms = pl.mask("poly", v)
        pl.region(ms, 0.06, 90, outline=True)
        # collar points
        for s in (-1, 1):
            cp = [(50 + s * 1, 90), (50 + s * (neck_w + 1), 85), (50 + s * (neck_w - 2), 97)]
            mc = pl.mask("poly", cp)
            pl.region(mc, 0.04, 90, outline=True)
    if tie:
        t = [(48, 92), (52, 92), (54.5, 112), (50, 118), (45.5, 112)]
        mt = pl.mask("poly", t)
        pl.region(mt, 0.9, 30, outline=True)
        pl.stroke([(47.5, 90.5), (52.5, 90.5)], 1.2)
    if lapels:
        for s in (-1, 1):
            lp = [(50 + s * (neck_w + 1), 86), (50 + s * 3, 116), (50 + s * 17, 100), (50 + s * 13, 94)]
            mlp = pl.mask("poly", lp)
            pl.region(mlp, d - 0.12 if s < 0 else d + 0.08, 100 if s < 0 else 80, outline=True)


def neck(pl, w=10, d=0.35, top=70, bottom=92):
    w *= 0.82
    d *= 0.8
    m = pl.mask("rect", 50 - w, top, 50 + w, bottom)
    pl.region(m, d, 95, lit=(L[0], 0.0, 50, 80, 12, 0.35))
    pl.darken(pl.mask("rect", 50 - w, top, 50 + w, top + 10), 0.35, soft=3)


def head(pl, rx=17.0, ry=22.0, cx=50.0, cy=56.0, jaw=1.0, d=0.06, ears=True):
    pts = []
    for i in range(64):
        t = i / 64 * 2 * math.pi
        x, y = math.cos(t), math.sin(t)
        if y > 0:  # jaw
            x *= 1 - (1 - jaw) * y * y * 0.8 if jaw < 1 else 1 + (jaw - 1) * y * 0.5
        pts.append((cx + x * rx, cy + y * ry))
    if ears:
        for s in (-1, 1):
            me = pl.mask("ell", cx + s * rx - 3.5, cy - 6, cx + s * rx + 3.5, cy + 7)
            pl.region(me, 0.3 if s < 0 else 0.55, 90, outline=True)
            pl.stroke([(cx + s * (rx + 0.5), cy - 3), (cx + s * (rx + 1.8), cy + 1), (cx + s * (rx + 0.3), cy + 4)], 0.9)
    m = pl.mask("poly", pts)
    pl.region(m, d, 100, curv=0.35, c=(cx, cy), outline=True, lit=(L[0], L[1], cx - 2, cy - 4, rx * 1.15, 0.62))
    return m


def face(pl, cx=50.0, cy=56.0, rx=17.0, ry=22.0, brow=1.0, eyes="open", nose=1.0, mouth="flat",
         lines=0, glasses=False, lashes=False, lips=False):
    ey = cy - ry * 0.02
    ex = rx * 0.42
    # sockets and the shadow side of the nose
    for s in (-1, 1):
        pl.darken(pl.mask("ell", cx + s * ex - 4.5, ey - 4, cx + s * ex + 4.5, ey + 2.5), 0.22 if s < 0 else 0.32, soft=2.5)
    pl.darken(pl.mask("poly", [(cx + 1, ey + 2), (cx + 4.5, cy + ry * 0.33), (cx + 1, cy + ry * 0.36)]), 0.35, soft=1.5)
    pl.darken(pl.mask("ell", cx - 5, cy + ry * 0.62, cx + 5, cy + ry * 0.78), 0.18, soft=2)
    # brows
    bw = 1.2 + 0.9 * brow
    for s in (-1, 1):
        pl.stroke([(cx + s * (ex - 4.5), ey - 5.2 + (0.8 if brow > 1.4 else 0)), (cx + s * ex, ey - 6.2),
                   (cx + s * (ex + 4.8), ey - 5.0)], bw)
    # eyes
    for s in (-1, 1):
        x = cx + s * ex
        if eyes == "narrow":
            pl.stroke([(x - 3.2, ey), (x, ey - 0.9), (x + 3.2, ey)], 1.3)
            pl.blob("ell", x - 1.1, ey - 1.0, x + 1.1, ey + 0.6)
        else:
            pl.stroke([(x - 3.4, ey + 0.3), (x - 1.5, ey - 1.5), (x + 1.5, ey - 1.5), (x + 3.4, ey + 0.2)], 1.2)
            pl.stroke([(x - 2.4, ey + 1.6), (x + 2.2, ey + 1.5)], 0.6)
            pl.blob("ell", x - 1.35, ey - 1.2, x + 1.35, ey + 1.3)
            pl.blob("ell", x - 0.9, ey - 1.0, x - 0.2, ey - 0.3, carve=True)
        if lashes:
            for k in range(4):
                lx = x - 2.8 + k * 1.9
                pl.stroke([(lx, ey - 1.2), (lx + s * 0.3 - 0.4, ey - 3.0)], 0.5)
    # nose
    nb = cy + ry * 0.33
    pl.stroke([(cx + 1.2, ey + 1.5), (cx + 2.2 * nose, nb - 3), (cx + 2.8 * nose, nb)], 0.9)
    pl.stroke([(cx - 3.0 * nose, nb - 0.3), (cx - 1.2, nb + 1.1), (cx + 1.2, nb + 1.1), (cx + 3.2 * nose, nb - 0.3)], 0.9)
    pl.blob("ell", cx - 2.4, nb - 0.8, cx - 0.8, nb + 0.6)
    pl.blob("ell", cx + 0.9, nb - 0.8, cx + 2.5, nb + 0.6)
    # mouth
    my = cy + ry * 0.55
    if mouth == "flat":
        pl.stroke([(cx - 5.5, my + 0.2), (cx, my + 0.6), (cx + 5.5, my)], 1.1)
    elif mouth == "smirk":
        pl.stroke([(cx - 5.5, my + 0.8), (cx, my + 0.6), (cx + 5.5, my - 0.8)], 1.1)
    elif mouth == "frown":
        pl.stroke([(cx - 5.5, my + 1.2), (cx, my), (cx + 5.5, my + 1.2)], 1.1)
    elif mouth == "smile":
        pl.stroke([(cx - 5.0, my - 0.6), (cx, my + 1.2), (cx + 5.0, my - 0.6)], 1.0)
    pl.stroke([(cx - 2.5, my + 3.0), (cx + 2.5, my + 3.0)], 0.7)
    if lips:
        pl.blob("poly", [(cx - 4.5, my + 0.2), (cx - 1.5, my - 1.4), (cx, my - 0.8), (cx + 1.5, my - 1.4),
                         (cx + 4.5, my + 0.2), (cx + 1.8, my + 2.4), (cx - 1.8, my + 2.4)])
    # chin and age lines
    pl.stroke([(cx - 3, cy + ry * 0.86), (cx, cy + ry * 0.9), (cx + 3, cy + ry * 0.86)], 0.6)
    if lines >= 1:
        for s in (-1, 1):
            pl.stroke([(cx + s * 4.2, nb + 0.5), (cx + s * 6.3, my + 1.5)], 0.7)
    if lines >= 2:
        pl.stroke([(cx - 5, ey - 9), (cx + 5, ey - 9.2)], 0.5)
        for s in (-1, 1):
            pl.stroke([(cx + s * (ex + 3.8), ey + 1), (cx + s * (ex + 5.5), ey - 0.5)], 0.5)
    if glasses:
        for s in (-1, 1):
            pl.ring(cx + s * ex - 4.3, ey - 3.8, cx + s * ex + 4.3, ey + 4.0, 0.8)
            pl.stroke([(cx + s * (ex - 2), ey - 2.6), (cx + s * (ex - 0.4), ey - 3.2)], 0.9, carve=True)
        pl.stroke([(cx - ex + 4.3, ey - 0.5), (cx - 1.5, ey - 1.2), (cx + 1.5, ey - 1.2), (cx + ex - 4.3, ey - 0.5)], 0.7)
        for s in (-1, 1):
            pl.stroke([(cx + s * (ex + 4.3), ey - 0.5), (cx + s * (rx + 0.3), ey - 1.5)], 0.7)


def mustache(pl, cx, y, kind="walrus"):
    if kind == "walrus":
        pts = [(cx - 8, y + 3.5), (cx - 5, y - 0.5), (cx, y - 1.2), (cx + 5, y - 0.5), (cx + 8, y + 3.5), (cx + 4, y + 2), (cx, y + 2.2), (cx - 4, y + 2)]
        pl.blob("poly", pts)
        for k in range(6):
            x = cx - 6 + k * 2.4
            pl.stroke([(x, y - 0.2), (x + 0.3, y + 1.8)], 0.35, carve=True)
    elif kind == "pencil":
        pl.stroke([(cx - 4.8, y + 0.8), (cx - 1, y), (cx + 1, y), (cx + 4.8, y + 0.8)], 0.7)
    elif kind == "full":
        pts = [(cx - 6.5, y + 2), (cx - 4, y - 0.7), (cx, y - 1), (cx + 4, y - 0.7), (cx + 6.5, y + 2), (cx, y + 1.6)]
        pl.blob("poly", pts)


def stubble(pl, cx, cy, rx, ry, density=0.12, seed=3):
    m = pl.mask("chord", cx - rx * 0.95, cy - ry * 0.35, cx + rx * 0.95, cy + ry * 1.0, 10, 170)
    m *= 1 - pl.mask("ell", cx - 6, cy + ry * 0.45, cx + 6, cy + ry * 0.72)
    pl.dots(m, density, r=0.28, seed=seed)


def cigar(pl, x, y, ang=12):
    a = math.radians(ang)
    L_ = 13
    ex, ey = x + math.cos(a) * L_, y + math.sin(a) * L_
    pl.stroke([(x, y), (ex, ey)], 2.6)
    pl.stroke([(x + 1.5, y + 0.25), (ex - 2.5, ey - 0.45)], 0.6, carve=True)
    pl.blob("ell", ex - 1.4, ey - 1.4, ex + 1.4, ey + 1.4, carve=True)
    pl.ring(ex - 1.4, ey - 1.4, ex + 1.4, ey + 1.4, 0.5)
    for k in range(3):
        pl.stroke([(ex + 1 + k * 1.2, ey - 3 - k * 3), (ex + 2.8 + k * 0.6, ey - 5.5 - k * 3), (ex + 1.4 + k, ey - 8 - k * 3)], 0.45)


# hats ------------------------------------------------------------------------

def fedora(pl, d=0.8, brim_y=38, tilt=0.0, wide=1.0):
    crown = [(31, brim_y + 2), (32.5, 24 + tilt), (39, 17.5 + tilt), (46, 18 + tilt), (50, 21.5 + tilt), (54, 18 + tilt),
             (61, 17.5 + tilt), (67.5, 24 + tilt), (69, brim_y + 2)]
    pl.region(pl.mask("poly", crown), d, 72, lit=(L[0], L[1], 48, 26, 22, 0.25), outline=True)
    band = pl.mask("rect", 31, brim_y - 5, 69, brim_y + 1)
    pl.region(band, 1.0, 0, outline=True)
    bw = 32 * wide
    brim = pl.mask("ell", 50 - bw, brim_y - 4, 50 + bw, brim_y + 7)
    brim *= 1 - pl.mask("rect", 0, 0, 100, brim_y - 2) * (1 - pl.mask("rect", 31, 0, 69, 200))
    pl.region(brim, d + 0.1, 5, lit=(L[0], 0, 50, brim_y, bw, 0.2), outline=True)
    pl.stroke([(50 - bw * 0.93, brim_y + 1.5), (50, brim_y + 6.5), (50 + bw * 0.93, brim_y + 1.5)], 0.9, carve=True)
    pl.stroke([(49.5, 22 + tilt), (48.8, 28 + tilt), (49.8, 32 + tilt)], 0.8, carve=True)
    return brim_y + 6


def police_cap(pl):
    top = pl.mask("ell", 22, 22, 78, 36)
    pl.region(top, 0.62, 0, lit=(L[0], L[1], 50, 29, 28, 0.3), outline=True)
    band = pl.mask("poly", [(30, 30), (70, 30), (68, 44), (32, 44)])
    pl.region(band, 0.95, 0, outline=True)
    pl.stroke([(31, 37), (69, 37)], 0.6, carve=True)
    visor = pl.mask("chord", 30, 34, 70, 52, 0, 180)
    pl.region(visor, 1.05, 10, outline=True)
    pl.stroke([(33, 46), (50, 50.5), (67, 46)], 0.8, carve=True)
    # badge on the band
    sh = [(50, 29), (54, 31), (54, 36), (50, 39.5), (46, 36), (46, 31)]
    pl.blob("poly", sh, carve=True)
    pl.blob("poly", [(50, 30.8), (52.6, 32.2), (52.6, 35.4), (50, 37.6), (47.4, 35.4), (47.4, 32.2)])
    pl.blob("ell", 49.1, 32.6, 50.9, 34.4, carve=True)
    return 48


def cloche(pl):
    dome = pl.mask("ell", 30, 22, 70, 66) * pl.mask("rect", 0, 0, 100, 50)
    pl.region(dome, 0.55, 110, curv=0.6, c=(50, 40), lit=(L[0], L[1], 48, 36, 22, 0.35), outline=True)
    brim = pl.mask("poly", [(27, 50), (31, 44), (50, 46), (69, 44), (73, 50), (72, 56), (66, 52), (50, 50.5), (34, 52), (28, 56)])
    pl.region(brim, 0.75, 0, outline=True)
    band = pl.mask("poly", [(31, 44), (50, 45.8), (69, 44), (69.5, 40), (50, 41.5), (30.5, 40)])
    pl.region(band, 1.0, 0, outline=True)
    pl.ring(58, 36.5, 66, 44.5, 0.7)
    for k in range(6):
        a = k * math.pi / 3
        pl.stroke([(62, 40.5), (62 + math.cos(a) * 3.6, 40.5 + math.sin(a) * 3.6)], 0.4, carve=True)
    pl.ring(60, 38.5, 64, 42.5, 0.5)
    return 50


def flat_cap(pl, d=0.65):
    body = pl.mask("poly", [(31, 44), (32, 34), (40, 29), (52, 27.5), (63, 29), (70, 34), (71, 42)])
    pl.region(body, d, 20, lit=(L[0], L[1], 48, 34, 22, 0.3), outline=True)
    bill = pl.mask("chord", 32, 38, 74, 52, 180, 360)
    bill *= 1 - pl.mask("rect", 0, 0, 100, 42)
    bill = np.maximum(bill, pl.mask("poly", [(33, 42), (72, 40), (73, 46), (34, 46)]))
    pl.region(bill, d + 0.28, 0, outline=True)
    pl.stroke([(40, 30), (38, 43)], 0.6)
    pl.stroke([(52, 28), (52, 41)], 0.6)
    pl.stroke([(63, 29.5), (65, 41)], 0.6)
    return 47


def newsboy(pl, d=0.6):
    body = pl.mask("ell", 26, 22, 76, 46)
    pl.region(body, d, 30, lit=(L[0], L[1], 46, 30, 26, 0.3), outline=True)
    for x0, x1 in ((34, 30), (44, 42), (56, 58), (66, 72)):
        pl.stroke([(51, 24), (x0, 31), (x1, 42)], 0.6)
    pl.blob("ell", 49.5, 21.5, 53.5, 25.5)
    bill = pl.mask("poly", [(32, 42), (70, 41), (73, 48), (50, 50), (31, 47)])
    pl.region(bill, 0.95, 0, outline=True)
    return 48


def watch_cap(pl):
    dome = pl.mask("ell", 31, 20, 69, 56) * pl.mask("rect", 0, 0, 100, 40)
    pl.region(dome, 0.55, 90, lit=(L[0], L[1], 48, 32, 20, 0.3), outline=True)
    cuff = pl.mask("rect", 30.5, 36, 69.5, 46)
    pl.region(cuff, 0.72, 90, outline=True)
    for k in range(15):
        x = 32 + k * 2.6
        pl.stroke([(x, 36.8), (x, 45.2)], 0.45, carve=True)
    for k in range(8):
        x = 35 + k * 4.2
        pl.stroke([(x, 24 + abs(x - 50) * 0.35), (x + (x - 50) * 0.08, 35.5)], 0.45)
    return 47


def bowler(pl):
    dome = pl.mask("ell", 33, 16, 67, 50) * pl.mask("rect", 0, 0, 100, 40)
    pl.region(dome, 0.85, 75, lit=(L[0], L[1], 46, 26, 16, 0.3), outline=True)
    band = pl.mask("rect", 33, 34.5, 67, 40)
    pl.region(band, 1.05, 0)
    brim = pl.mask("ell", 26, 37, 74, 45)
    brim *= 1 - pl.mask("rect", 33.5, 0, 66.5, 40)
    pl.region(brim, 0.95, 0, outline=True)
    pl.stroke([(28, 40), (50, 44), (72, 40)], 0.7, carve=True)
    pl.stroke([(40, 22), (37, 33)], 1.0, carve=True)
    return 44


def hair(pl, kind, cx=50, cy=56, rx=17, ry=22):
    if kind == "slick":
        m = pl.mask("ell", cx - rx - 0.5, cy - ry - 1.5, cx + rx + 0.5, cy + ry * 0.2)
        m *= 1 - pl.mask("ell", cx - rx + 2, cy - ry * 0.62, cx + rx - 2, cy + ry * 1.6)
        m = np.maximum(m, pl.mask("poly", [(cx - rx, cy - 4), (cx - rx + 2, cy - 12), (cx - rx + 4, cy - 4)]))
        pl.region(m, 0.9, 165, curv=-0.4, c=(cx, cy - ry), outline=True)
        pl.stroke([(cx - 7, cy - ry + 0.5), (cx - 6, cy - ry * 0.7)], 0.7, carve=True)
    elif kind == "short":
        m = pl.mask("ell", cx - rx - 0.5, cy - ry - 1, cx + rx + 0.5, cy + ry * 0.1)
        m *= 1 - pl.mask("ell", cx - rx + 2.5, cy - ry * 0.55, cx + rx - 2.5, cy + ry * 1.6)
        pl.region(m, 0.62, 120, outline=True)
    elif kind == "bald":
        for s in (-1, 1):
            m = pl.mask("ell", cx + s * rx - 4, cy - 10, cx + s * rx + 4, cy + 3)
            m *= 1 - pl.mask("ell", cx - rx + 1.5, cy - ry, cx + rx - 1.5, cy + ry)
            pl.region(m, 0.6, 70, outline=True)
        pl.stroke([(cx - 8, cy - ry + 3), (cx - 4, cy - ry + 1.8)], 0.8, carve=True)
    elif kind == "bob":
        for s in (-1, 1):
            m = pl.mask("poly", [(cx + s * (rx - 5), cy - 8), (cx + s * (rx + 3), cy - 8), (cx + s * (rx + 4), cy + 6),
                                 (cx + s * (rx + 1), cy + 13), (cx + s * (rx - 3), cy + 8)])
            pl.region(m, 0.85, 60 * s, outline=True)
            for k in range(3):
                y = cy - 4 + k * 5
                xx = cx + s * (rx + 0.5)
                pl.stroke([(xx - 2 * s, y - 1.5), (xx, y + 1.2), (xx + 1.8 * s, y - 0.8)], 0.5, carve=True)


# ------------------------------------------------------------------------------ people

def p_boss(pl):
    base(pl)
    coat(pl, d=0.78)
    # pinstripes
    for k in range(-8, 9):
        x = 50 + k * 5.5
        pl.stroke([(x, 92), (x + k * 0.6, 126)], 0.35, carve=True)
    pl.blob("poly", [(26, 100), (32, 98.5), (33, 102), (27, 103)], carve=True)
    neck(pl, 10.5)
    head(pl, 17.5, 22, jaw=1.08)
    fedora(pl, d=0.78, brim_y=38)
    pl.darken(pl.mask("rect", 32, 41, 68, 47), 0.3, soft=2)
    face(pl, rx=17.5, brow=1.8, mouth="smirk", lines=1)
    cigar(pl, 53, 68.5, ang=18)


def p_crewman(pl):
    base(pl)
    coat(pl, d=0.62, tie=False, lapels=True)
    pl.region(pl.mask("poly", [(40, 86), (50, 104), (60, 86)]), 0.15, 90, outline=True)
    for s in (-1, 1):
        pl.stroke([(50 + s * 9, 94), (50 + s * 11, 126)], 1.4)
    neck(pl, 11.5, d=0.4)
    head(pl, 18, 21.5, jaw=1.1)
    newsboy(pl)
    pl.darken(pl.mask("rect", 32, 45, 68, 50), 0.3, soft=2)
    face(pl, rx=18, ry=21.5, brow=1.9, mouth="frown", nose=1.35, lines=1)
    stubble(pl, 50, 56, 18, 21.5, 0.07, seed=5)
    pl.stroke([(58, 52), (63, 61)], 0.6, carve=True)
    pl.stroke([(58.4, 52.4), (63.4, 61.4)], 0.35)


def p_cop(pl):
    base(pl)
    coat(pl, d=0.84, tie=False, lapels=False, shirt=False)
    col = pl.mask("poly", [(38, 84), (62, 84), (63, 94), (37, 94)])
    pl.region(col, 0.95, 0, outline=True)
    for y in (100, 110, 120):
        pl.blob("ell", 48.5, y - 1.5, 51.5, y + 1.5, carve=True)
        pl.ring(48.5, y - 1.5, 51.5, y + 1.5, 0.4)
    pl.stroke([(50, 94), (50, 126)], 0.6, carve=True)
    pl.blob("poly", [(26, 100), (30, 98), (32, 102), (28, 104)], carve=True)
    neck(pl, 10)
    head(pl, 17.5, 22)
    police_cap(pl)
    pl.darken(pl.mask("rect", 32, 47, 68, 51), 0.3, soft=2)
    face(pl, rx=17.5, brow=1.3, mouth="flat", lines=2)
    mustache(pl, 50, 67.5, "walrus")


def p_shopkeeper(pl):
    base(pl)
    coat(pl, d=0.3, tie=False, lapels=False, shirt=False, shoulders=(4, 96))
    for s in (-1, 1):
        pl.stroke([(50 + s * 20, 92), (50 + s * 23, 126)], 0.5)
    apron = pl.mask("poly", [(34, 100), (66, 100), (70, 126), (30, 126)])
    pl.region(apron, 0.04, 90, outline=True)
    for s in (-1, 1):
        pl.stroke([(50 + s * 15.5, 100), (50 + s * 12, 86)], 1.3)
    pl.region(pl.mask("poly", [(41, 86), (50, 96), (59, 86)]), 0.08, 90, outline=True)
    pl.blob("poly", [(44, 88), (50, 91), (56, 88), (56, 93), (50, 91.5), (44, 93)])
    neck(pl, 10.5)
    head(pl, 17.5, 22.5, jaw=1.12)
    hair(pl, "bald", ry=22.5)
    face(pl, rx=17.5, ry=22.5, brow=0.9, mouth="smile", lines=2, glasses=True)
    mustache(pl, 50, 68, "full")


def p_woman(pl):
    base(pl, 0.14)
    coat(pl, d=0.55, tie=False, lapels=False, shirt=False, shoulders=(12, 88))
    fur = pl.mask("poly", [(24, 94), (38, 84), (62, 84), (76, 94), (70, 104), (50, 99), (30, 104)])
    pl.region(fur, 0.72, 50, curv=1.0, c=(50, 94), outline=False)
    pl.dots(fur, 0.07, r=0.45, seed=9)
    pl.region(pl.mask("poly", [(42, 84), (50, 96), (58, 84)]), 0.12, 90)
    for k in range(9):
        a = math.radians(200 + k * 17.5)
        x, y = 50 + math.cos(a) * -8.5, 85 + abs(math.sin(a)) * 7
    for k in range(9):
        t = k / 8
        x = 42.5 + t * 15
        y = 86 + math.sin(t * math.pi) * 7
        pl.blob("ell", x - 1.2, y - 1.2, x + 1.2, y + 1.2, carve=True)
        pl.ring(x - 1.2, y - 1.2, x + 1.2, y + 1.2, 0.35)
    neck(pl, 8, d=0.25, bottom=88)
    head(pl, 15.5, 20.5, cy=57, jaw=0.86, ears=False)
    hair(pl, "bob", cy=57, rx=15.5, ry=20.5)
    cloche(pl)
    face(pl, cy=57, rx=15.5, ry=20.5, brow=0.35, mouth="flat", lashes=True, lips=True, nose=0.8)
    pl.blob("ell", 58.5, 64, 59.8, 65.3)


def p_dockworker(pl):
    base(pl)
    coat(pl, d=0.7, tie=False, lapels=True, shirt=False, shoulders=(2, 98))
    scarf = pl.mask("poly", [(37, 84), (63, 84), (60, 94), (54, 98), (57, 110), (51, 108), (48, 97), (40, 93)])
    pl.region(scarf, 0.45, 30, outline=True)
    pl.dots(scarf, 0.05, r=0.55, seed=4)
    neck(pl, 12.5, d=0.45)
    head(pl, 18.5, 21.5, jaw=1.15)
    flat_cap(pl)
    pl.darken(pl.mask("rect", 32, 44, 68, 50), 0.3, soft=2)
    face(pl, rx=18.5, ry=21.5, brow=1.5, mouth="flat", lines=2, nose=1.2)
    stubble(pl, 50, 56, 18.5, 21.5, 0.12, seed=6)


def p_smuggler(pl):
    base(pl)
    coat(pl, d=0.8, tie=False, lapels=False, shirt=False, shoulders=(4, 96))
    for s in (-1, 1):
        col = pl.mask("poly", [(50 + s * 6, 80), (50 + s * 20, 78), (50 + s * 26, 96), (50 + s * 10, 104)])
        pl.region(col, 0.62 if s < 0 else 0.9, 60 * s, outline=True)
    for y in (108, 120):
        for s in (-1, 1):
            pl.blob("ell", 50 + s * 8 - 1.6, y - 1.6, 50 + s * 8 + 1.6, y + 1.6, carve=True)
            pl.ring(50 + s * 8 - 1.6, y - 1.6, 50 + s * 8 + 1.6, y + 1.6, 0.4)
    neck(pl, 11, d=0.5, bottom=84)
    head(pl, 17, 21.5, jaw=1.05)
    watch_cap(pl)
    face(pl, rx=17, ry=21.5, brow=1.6, eyes="narrow", mouth="flat", lines=2)
    beard = pl.mask("chord", 32, 42, 68, 79, 15, 165) * (1 - pl.mask("ell", 43, 65, 57, 72))
    beard *= head_mask_cache(pl, 17, 21.5, 1.05)
    pl.darken(beard, 0.35, soft=1)
    stubble(pl, 50, 56, 17, 21.5, 0.2, seed=7)
    pl.blob("ell", 31.5, 60, 33.5, 62.5, carve=True)
    pl.ring(31.2, 59.8, 33.8, 62.8, 0.5)
    # pipe
    pl.stroke([(53, 69), (62, 72), (64, 72)], 1.3)
    pl.blob("poly", [(62, 66), (68, 66), (67.5, 74), (62.5, 74)])
    pl.stroke([(62.8, 67), (67.2, 67)], 0.6, carve=True)


def head_mask_cache(pl, rx, ry, jaw, cx=50, cy=56):
    pts = []
    for i in range(64):
        t = i / 64 * 2 * math.pi
        x, y = math.cos(t), math.sin(t)
        if y > 0:
            x *= 1 + (jaw - 1) * y * 0.5 if jaw >= 1 else 1 - (1 - jaw) * y * y * 0.8
        pts.append((cx + x * rx, cy + y * ry))
    return pl.mask("poly", pts)


def p_union_boss(pl):
    base(pl)
    coat(pl, d=0.7, tie=True, lapels=True, shoulders=(0, 100), neck_w=12)
    vest = pl.mask("poly", [(38, 96), (62, 96), (60, 126), (40, 126)]) * (1 - pl.mask("poly", [(44, 88), (50, 116), (56, 88)]))
    pl.region(vest, 0.5, 80, outline=True)
    pl.stroke([(40, 112), (46, 116), (54, 116), (60, 112)], 0.6, carve=True)
    pl.stroke([(40.3, 112.6), (46, 116.6), (54, 116.6), (59.7, 112.6)], 0.35)
    neck(pl, 14, d=0.35)
    head(pl, 20.5, 22, jaw=1.22)
    pl.darken(pl.mask("ell", 34, 70, 66, 82), 0.2, soft=2)
    pl.stroke([(38, 75.5), (50, 79), (62, 75.5)], 0.6)
    bowler(pl)
    pl.darken(pl.mask("rect", 30, 43, 70, 47), 0.25, soft=2)
    face(pl, rx=20.5, ry=22, brow=1.3, mouth="smile", lines=2, nose=1.25)
    for s in (-1, 1):
        pl.stroke([(50 + s * 12, 60), (50 + s * 14, 66)], 0.5)
    cigar(pl, 44, 69, ang=160)


def p_arms_dealer(pl):
    base(pl, 0.2)
    coat(pl, d=0.9, tie=False, lapels=True, neck_w=9)
    pl.blob("poly", [(44.5, 90), (50, 92.5), (55.5, 90), (55.5, 95.5), (50, 93), (44.5, 95.5)])
    for s in (-1, 1):
        col = pl.mask("poly", [(50 + s * 10, 86), (50 + s * 24, 80), (50 + s * 30, 100), (50 + s * 16, 104)])
        pl.region(col, 0.8 if s < 0 else 1.0, 60 * s, outline=True)
    neck(pl, 9.5, d=0.4)
    head(pl, 16, 22.5, jaw=0.92)
    hair(pl, "slick", rx=16, ry=22.5)
    face(pl, rx=16, ry=22.5, brow=1.1, eyes="narrow", mouth="smirk", lines=1, nose=1.1)
    mustache(pl, 50, 67.2, "pencil")


def p_priest(pl):
    base(pl, 0.15)
    coat(pl, d=0.95, tie=False, lapels=False, shirt=False)
    col = pl.mask("poly", [(38, 84), (62, 84), (63, 92), (37, 92)])
    pl.region(col, 0.9, 0, outline=True)
    pl.blob("poly", [(46.5, 86), (53.5, 86), (53.5, 91.5), (46.5, 91.5)], carve=True)
    pl.ring(46.5, 86, 53.5, 91.5, 0.4)
    neck(pl, 9.5, d=0.3, bottom=86)
    head(pl, 16.5, 22, jaw=0.98)
    hair(pl, "short", rx=16.5)
    face(pl, rx=16.5, brow=0.8, mouth="flat", lines=2, glasses=True)


def p_agent(pl):
    base(pl)
    coat(pl, d=0.55, tie=True, lapels=True, neck_w=9)
    neck(pl, 9.5, d=0.32)
    head(pl, 16.5, 21.5, jaw=1.0)
    fedora(pl, d=0.48, brim_y=39, wide=0.85)
    pl.darken(pl.mask("rect", 33, 42, 67, 47), 0.25, soft=2)
    face(pl, rx=16.5, ry=21.5, brow=1.0, mouth="flat", glasses=True)


PEOPLE = {"boss": p_boss, "crewman": p_crewman, "cop": p_cop, "shopkeeper": p_shopkeeper, "woman": p_woman,
          "dockworker": p_dockworker, "smuggler": p_smuggler, "union_boss": p_union_boss,
          "arms_dealer": p_arms_dealer, "priest": p_priest, "agent": p_agent}


def medallion(ink, fw, seed):
    """Put the engraved ink in an oval medallion on cream paper; returns RGBA."""
    S = 4
    W, H = fw, int(fw * 1.25)
    Ws, Hs = W * S, H * S
    X, Y = np.meshgrid(np.arange(Ws) + 0.5, np.arange(Hs) + 0.5)
    cx, cy = Ws / 2, Hs / 2
    rx, ry = Ws / 2 - 3 * S, Hs / 2 - 4 * S
    e = np.sqrt(((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2)
    px = 1.0 / rx  # one final px in e-units ~ S/rx
    pxf = S / rx
    inside = np.clip((1 - e) / pxf * 1.0 + 0.5, 0, 1)
    band_in = 0.915
    ang = np.arctan2((Y - cy) / ry, (X - cx) / rx)
    # twisted rope in the band
    rope_ph = (ang / (2 * math.pi) * (68 if fw > 150 else 44) + (e - band_in) / (1 - band_in) * 1.4) % 1.0
    rope = (np.abs(rope_ph - 0.5) < 0.22) & (e > band_in + 1.8 * pxf) & (e < 1 - 2.2 * pxf)
    frame_ink = np.zeros_like(e)
    frame_ink = np.maximum(frame_ink, np.clip(1.1 - np.abs(e - band_in) / pxf, 0, 1))
    frame_ink = np.maximum(frame_ink, np.clip(0.9 - np.abs(e - (1 - 1.1 * pxf)) / pxf, 0, 1))
    frame_ink = np.maximum(frame_ink, rope * 0.9)
    frame_ink = down(frame_ink, S)
    inside = down(inside, S)
    inner = down(np.clip((band_in - e) / pxf + 0.5, 0, 1), S)
    tile = paper_tile(256, PAPER * np.array([1.0, 0.985, 0.95]), seed, fibres=100, fox=2)
    Yg, Xg = np.meshgrid(np.arange(H), np.arange(W), indexing="ij")
    paper = tile[Yg % 256, Xg % 256]
    ink_all = np.maximum(ink[:H, :W] * inner, frame_ink)
    rgb = mix(paper, INK, ink_all * 0.95)
    out = np.zeros((H, W, 4))
    out[..., :3] = rgb
    out[..., 3] = inside
    return out


def make_portraits():
    for i, (kind, fn) in enumerate(PEOPLE.items()):
        for fw, suffix, period in ((240, "", 3.0), (168, "_md", 2.6), (120, "_sm", 2.2)):
            pl = Plate(fw, seed=200 + i)
            fn(pl)
            ink = pl.render(period)
            out = medallion(ink, fw, 300 + i)
            save(out, "portraits/%s%s.png" % (kind, suffix))
