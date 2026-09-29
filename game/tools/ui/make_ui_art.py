#!/usr/bin/env python3
"""Famiglia UI kit: generates every texture of the 1920s printed-ephemera UI.

    python3 game/tools/ui/make_ui_art.py            # everything
    python3 game/tools/ui/make_ui_art.py sheets     # one group (sheets, buttons, tabs,
        seal, stamps, keys, halftone, misc, icons, portraits)

Output goes to game/assets/ui/. All randomness is seeded, so running it again gives
identical files. Drawing is supersampled (4x for shapes, icons and portraits) and
downsampled with premultiplied alpha.

9-patch geometry: every sheet has a middle period P which tiles (the paper grain, the
deckled edge and ruled lines are all periodic in P), so StyleBoxTexture can use
AXIS_STRETCH_MODE_TILE_FIT without seams or blur. The margins printed by this
script are mirrored in scripts/ui/ui_kit.gd (NINE).
"""
import sys
import math
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from uiart_common import *  # noqa: F401,F403
import uiart_common as C

GEOM = {}


# ----------------------------------------------------------------------------------------
# Sheets (9-patch paper, card, ledger, leather, telegram)
# ----------------------------------------------------------------------------------------

def sheet(name, P, margins, tile, pad, deckle=0.0, deckle_rough=1.0, corner=2.0, seed=1,
          shadow=(2, 4, 4.0, 0.42), burn=(12.0, 0.20), burncol=(0.50, 0.34, 0.17),
          paint=None, open_bottom=False, corner_bottom=None, fringe=0.0, content=None, Ph=None,
          sides=(1.0, 1.0, 1.0, 1.0)):
    """Build a 9-patch sheet. margins=(l,t,r,b); pad = transparent room for the shadow.

    paint(rgb, alpha, g) may modify rgb/alpha in place; g has X, Y, W, H, d (distance to
    the paper edge in px, periodic in P along the edges), and the margins.
    """
    ml, mt, mr, mb = margins
    Ph = Ph or P
    W, H = ml + P + mr, mt + Ph + mb
    rng = np.random.default_rng(seed)
    X, Y = np.meshgrid(np.arange(W), np.arange(H))
    T = tile.shape[0]
    rgb = tile[(Y - mt) % T, (X - ml) % T].copy()
    top = pad + edge_fn(W, P, deckle * sides[1], rng, rough=deckle_rough)
    bot = pad + edge_fn(W, P, deckle * sides[3], rng, rough=deckle_rough)
    lef = pad + edge_fn(H, Ph, deckle * sides[0], rng, rough=deckle_rough)
    rig = pad + edge_fn(H, Ph, deckle * sides[2], rng, rough=deckle_rough)
    Xc, Yc = X + 0.5, Y + 0.5
    dt = Yc - top[None, :]
    db = (H - bot[None, :]) - Yc
    dl = Xc - lef[:, None]
    dr = (W - rig[:, None]) - Xc
    if open_bottom:
        db = np.full_like(db, 1e3)
    d = np.minimum(np.minimum(dt, db), np.minimum(dl, dr))
    rb = corner if corner_bottom is None else corner_bottom
    for (cx, cy, r, sx, sy) in ((pad + corner, pad + corner, corner, -1, -1),
                                (W - pad - corner, pad + corner, corner, 1, -1),
                                (pad + rb, H - pad - rb, rb, -1, 1),
                                (W - pad - rb, H - pad - rb, rb, 1, 1)):
        if r <= 0 or (open_bottom and sy > 0):
            continue
        zone = ((Xc - cx) * sx > 0) & ((Yc - cy) * sy > 0)
        dc = r - np.hypot(Xc - cx, Yc - cy)
        d = np.where(zone, np.minimum(d, dc + 0.0), d)
    # fine fibrous fringe on deckled edges (periodic in P)
    fn = pnoise(P, P, 90, rng)[(Y - mt) % P, (X - ml) % P]
    soft = 1.0 + fringe
    alpha = np.clip((d + fringe * 0.6 * fn) / soft + 0.5, 0, 1)
    # edge burn / ageing
    if burn and burn[1] > 0:
        bn = pnoise(P, P, 6, rng)[(Y - mt) % P, (X - ml) % P]
        b = np.exp(-np.maximum(d, 0) / burn[0]) * burn[1] * (0.75 + 0.25 * bn)
        rgb = mix(rgb, np.array(burncol) * rgb, np.clip(b, 0, 1))
    g = dict(X=X, Y=Y, W=W, H=H, d=d, ml=ml, mt=mt, mr=mr, mb=mb, P=P, pad=pad, rng=rng)
    if paint:
        paint(rgb, alpha, g)
    out = np.zeros((H, W, 4))
    if shadow:
        sx, sy, sb, sa = shadow
        a_img = from_mask(alpha)
        sh = to_arr(a_img.filter(ImageFilter.GaussianBlur(sb)))
        sh = shift(sh, sx, sy) * sa
        if open_bottom:
            sh[H - 2:, :] = 0
        out[..., :3] = np.array([0.16, 0.10, 0.05])
        out[..., 3] = sh
    out = over(out, rgb, alpha)
    save(out, name)
    exp = pad + deckle * 0.45
    GEOM[name] = dict(size=[W, H], margins=[ml, mt, mr, mb], expand=round(exp, 1),
                      content=content)
    return out


def ink_line_mask(d, at, width):
    """AA mask of a line running parallel to the paper edge at distance `at`."""
    return np.clip(width / 2 + 0.5 - np.abs(d - at), 0, 1)


def make_sheets():
    P = 256
    cream = paper_tile(P, PAPER, 11, fibres=180, fox=3)
    manila = paper_tile(P, PAPER2 * np.array([1.0, 0.98, 0.93]), 12, fibres=220, fox=4, cloud=0.05)
    ledger_t = paper_tile(P, LEDGER_PAPER, 13, fibres=140, fox=2, cloud=0.03)
    news_t = paper_tile(P, NEWS, 14, fibres=320, fox=1, specks=60, cloud=0.03, grain=0.04)
    tele_t = paper_tile(P, TELEGRAM, 15, fibres=160, fox=2, cloud=0.035)

    # seamless tiles, 512, for large backgrounds
    save(paper_tile(512, PAPER, 21, fibres=700, fox=10), "paper/paper_cream.png")
    save(paper_tile(512, PAPER2 * np.array([1.0, 0.97, 0.9]), 22, fibres=800, fox=12, cloud=0.06),
         "paper/paper_manila.png")
    save(paper_tile(512, NEWS, 23, fibres=1100, fox=3, specks=240, cloud=0.035, grain=0.045),
         "paper/paper_newsprint.png")

    # card: cream, deckled edge, soft drop shadow
    sheet("panels/card.png", P, (40, 40, 40, 40), cream, pad=14, deckle=4.5, deckle_rough=1.6,
          corner=3, seed=31, shadow=(3, 5, 5.0, 0.5), burn=(16, 0.28), fringe=0.8,
          content=[26, 22, 26, 24])
    # paper panel: plain manila, trimmed straight
    sheet("panels/paper.png", P, (32, 32, 32, 32), manila, pad=12, deckle=1.0, corner=2,
          seed=32, shadow=(2, 4, 4.5, 0.48), burn=(12, 0.22), content=[20, 16, 20, 18])
    # slip: small tooltip / note paper
    sheet("panels/slip.png", 64, (14, 14, 14, 14), cream[:64, :64], pad=6, deckle=1.2, corner=1.5,
          seed=33, shadow=(1, 2, 2.0, 0.45), burn=(6, 0.18), content=[10, 7, 10, 8])

    # newsprint page: straight, low contrast
    sheet("panels/newsprint.png", P, (28, 28, 28, 28), news_t, pad=10, deckle=0.8, corner=1,
          seed=34, shadow=(2, 4, 5.0, 0.45), burn=(20, 0.18), burncol=(0.7, 0.55, 0.35),
          content=[20, 14, 20, 16])

    # ledger page: green rules, red double margin, header rule
    def ledger_paint(rgb, alpha, g):
        X, Y, W, H, d = g["X"], g["Y"], g["W"], g["H"], g["d"]
        ml, mt, mr = g["ml"], g["mt"], g["mr"]
        rng = g["rng"]
        pn = pnoise(g["P"], g["P"], 40, rng)[(Y - mt) % g["P"], (X - ml) % g["P"]]
        prt = 0.75 + 0.2 * pn  # printing unevenness
        rule_col = np.array([0.36, 0.55, 0.52])
        rows = (((Y - mt) % 32) == 31) & (Y > mt) & (d > 6)
        rgb[:] = mix(rgb, rule_col, rows * 0.55 * prt)
        head = ((Y == mt - 12) | (Y == mt - 11) | (Y == mt - 7)) & (d > 6)
        rgb[:] = mix(rgb, GREEN, head * 0.8 * prt)
        for x0 in (ml - 22, ml - 18):
            col = (X == x0) & (d > 4)
            rgb[:] = mix(rgb, OX * 1.1, col * 0.75 * prt)
        for x0 in (W - mr + 10, W - mr + 13):
            col = (X == x0) & (Y > mt - 12) & (d > 4)
            rgb[:] = mix(rgb, rule_col, col * 0.6 * prt)
    sheet("panels/ledger.png", P, (96, 64, 48, 40), ledger_t, pad=10, deckle=0.8, corner=1.5,
          seed=35, shadow=(1, 3, 3.0, 0.45), burn=(14, 0.16), paint=ledger_paint,
          content=[80, 50, 30, 26])

    # ledger strip (HUD bar): straight top, torn bottom; fixed height, tiles horizontally
    def strip_paint(rgb, alpha, g):
        X, Y, W, H, d = g["X"], g["Y"], g["W"], g["H"], g["d"]
        ml, mt = g["ml"], g["mt"]
        rng = g["rng"]
        pn = pnoise(g["P"], g["P"], 40, rng)[(Y - mt) % g["P"], (X - ml) % g["P"]]
        prt = 0.75 + 0.2 * pn
        rule_col = np.array([0.36, 0.55, 0.52])
        for y0 in (mt + 2, mt + 36):
            rgb[:] = mix(rgb, rule_col, ((Y == y0) & (d > 3)) * 0.5 * prt)
        rgb[:] = mix(rgb, GREEN, (((Y == mt - 4) | (Y == mt - 2)) & (d > 3)) * 0.7 * prt)
        for x0 in (ml - 16, ml - 12):
            rgb[:] = mix(rgb, OX * 1.1, ((X == x0) & (d > 2)) * 0.75 * prt)
    sheet("panels/ledger_strip.png", P, (84, 12, 24, 16), ledger_t, pad=6, deckle=3.0, deckle_rough=1.4,
          corner=0, seed=36, shadow=(0, 5, 5.0, 0.55), burn=(10, 0.2), paint=strip_paint, Ph=56,
          sides=(0.2, 0.0, 0.2, 1.0), fringe=0.6, content=[64, 8, 16, 12])

    # desk: dark walnut, seamless
    T = 512
    rng = np.random.default_rng(44)
    Xw, Yw = np.meshgrid(np.arange(T), np.arange(T))
    # four horizontal planks per tile; grain runs along x (anisotropic FFT noise -> seamless)
    def aniso(cx, cy):
        F = np.fft.fft2(rng.standard_normal((T, T)))
        fy = np.fft.fftfreq(T)[:, None] * T
        fx = np.fft.fftfreq(T)[None, :] * T
        n = np.real(np.fft.ifft2(F * np.exp(-(fx / cx) ** 2 - (fy / cy) ** 2)))
        return (n - n.mean()) / (n.std() + 1e-9)
    plank = Yw // 128
    lum = np.zeros((T, T))
    for k in range(4):
        warp = aniso(2.0, 6.0) * 0.8 + aniso(5.0, 14.0) * 0.25
        yy = (Yw % 128) / 128.0
        rings = np.sin(2 * np.pi * (yy * rng.uniform(5, 9) + warp + rng.uniform(0, 1)))
        streak = aniso(3.0, 90.0)
        pores = aniso(40.0, 220.0)
        tone = rng.uniform(0.88, 1.05)
        lk = tone * (0.80 + 0.06 * rings + 0.06 * streak + 0.035 * pores)
        lum = np.where(plank == k, lk, lum)
    seam = ((Yw % 128) == 0) | ((Yw % 128) == 127)
    lum = np.where(seam, lum * 0.45, lum)
    lum = np.where((Yw % 128) == 1, lum * 1.12, lum)
    wood = np.array([0.31, 0.185, 0.105])[None, None, :] * lum[..., None]
    save(np.clip(wood, 0, 1), "paper/desk_wood.png")

    # leather book cover with stitched edge
    rng = np.random.default_rng(41)
    base = np.array([0.33, 0.17, 0.10])
    peb = np.abs(pnoise(P, P, 70, rng))
    mott = fbm(P, P, 3, 4, rng)
    crease = np.clip(1 - np.abs(pnoise(P, P, 14, rng)) * 6, 0, 1) ** 3
    lum = 0.92 + 0.10 * mott - 0.18 * np.clip(0.9 - peb, 0, 1) ** 2 - 0.12 * crease
    leather = np.clip(base[None, None, :] * lum[..., None], 0, 1)

    def leather_paint(rgb, alpha, g):
        X, Y, d, P_ = g["X"], g["Y"], g["d"], g["P"]
        ml, mt = g["ml"], g["mt"]
        rng = g["rng"]
        wear = pnoise(P_, P_, 20, rng)[(Y - mt) % P_, (X - ml) % P_]
        scuff = np.clip(1.6 - d / 2.2, 0, 1) * (0.55 + 0.45 * wear)
        rgb[:] = mix(rgb, np.array([0.62, 0.42, 0.26]), np.clip(scuff, 0, 1) * 0.6)
        groove = ink_line_mask(d, 25, 1.2)
        hi = ink_line_mask(d, 26.6, 1.0)
        rgb[:] = mix(rgb, np.array([0.12, 0.06, 0.03]), groove * 0.7)
        rgb[:] = mix(rgb, np.array([0.55, 0.36, 0.22]), hi * 0.45)
        # stitches on a line at d=14; dash period 16 (divides P)
        st_line = ink_line_mask(d, 14, 2.2)
        # parameter along the edge: use X on top/bottom bands, Y on sides
        W, H = g["W"], g["H"]
        side = np.minimum(X, W - 1 - X) < np.minimum(Y, H - 1 - Y)
        u = np.where(side, Y, X)
        ph = (u % 16)
        dash = np.clip(np.minimum(ph - 2.5, 11.5 - ph) + 0.5, 0, 1)
        hole = np.clip(1.4 - np.minimum(np.abs(ph - 2.0), np.abs(ph - 12.0)), 0, 1) * ink_line_mask(d, 14, 2.4)
        rgb[:] = mix(rgb, np.array([0.08, 0.04, 0.02]), hole * 0.8)
        thread = st_line * dash
        tcol = np.array([0.84, 0.74, 0.55]) * (0.85 + 0.15 * np.clip((d - 13) / 2, -1, 1))[..., None]
        rgb[:] = mix(rgb, tcol, thread * 0.95)
    sheet("panels/leather.png", P, (48, 48, 48, 48), leather, pad=10, deckle=0.6, corner=12,
          seed=42, shadow=(2, 6, 6.0, 0.6), burn=(10, 0.35), burncol=(0.35, 0.25, 0.2),
          paint=leather_paint, content=[34, 34, 34, 34])

    # telegram strip: yellow-cream, printed header rule
    def tele_paint(rgb, alpha, g):
        X, Y, W, H, d = g["X"], g["Y"], g["W"], g["H"], g["d"]
        mt, mb, pad = g["mt"], g["mb"], g["pad"]
        inx = (X > pad + 12) & (X < W - pad - 12)
        prn = np.array([0.23, 0.19, 0.14])
        rgb[:] = mix(rgb, prn, ((Y >= mt - 19) & (Y <= mt - 17) & inx) * 0.85)
        rgb[:] = mix(rgb, prn, ((Y == mt - 13) & inx) * 0.7)
        rgb[:] = mix(rgb, prn, ((Y == H - mb + 8) & inx) * 0.45)
    sheet("panels/telegram.png", P, (28, 56, 28, 28), tele_t, pad=10, deckle=1.5, deckle_rough=0.5,
          corner=1, seed=43, shadow=(2, 4, 4.0, 0.45), burn=(10, 0.22), paint=tele_paint,
          content=[22, 46, 22, 20])


# ----------------------------------------------------------------------------------------
# Art Deco frame
# ----------------------------------------------------------------------------------------

def deco_frame(name, navy=False):
    S = 4
    M, P, pad = 96, 128, 10
    W = H = 2 * M + P
    tile = paper_tile(P, PAPER, 51, fibres=90, fox=1)
    if navy:
        rng = np.random.default_rng(52)
        mot = fbm(P, P, 3, 4, rng) * 0.05 + pnoise(P, P, 140, rng) * 0.03
        tile = np.clip(NAVY[None, None, :] * (1 + mot)[..., None], 0, 1)
    X, Y = np.meshgrid(np.arange(W), np.arange(H))
    rgb = tile[(Y - M) % P, (X - M) % P].copy()
    # quadrant drawing at 4x
    Q = W // 2
    layers = {k: Image.new("L", (Q * S, Q * S), 0) for k in ("outer", "brass", "ink", "red", "fan")}
    dr = {k: ImageDraw.Draw(v) for k, v in layers.items()}
    s = lambda v: v * S
    E = Q * S + 8  # beyond the quadrant (to the mirror seam)

    def hline(layer, y, x0, w):
        dr[layer].rectangle([s(x0), s(y) - w * S / 2, E, s(y) + w * S / 2], fill=255)

    def vline(layer, x, y0, w):
        dr[layer].rectangle([s(x) - w * S / 2, s(y0), s(x) + w * S / 2, E], fill=255)
    o = pad
    # outer keyline
    hline("outer", o + 5, o + 5, 2.0)
    vline("outer", o + 5, o + 5, 2.0)
    # brass band
    dr["brass"].rectangle([s(o + 10), s(o + 10), E, s(o + 17)], fill=255)
    dr["brass"].rectangle([s(o + 10), s(o + 10), s(o + 17), E], fill=255)

    # stepped inner lines
    def stepped(off, layer, w):
        a = o + 22 + off
        steps = [(E / S, a), (70, a), (70, a + 9), (56, a + 9), (56, a + 20), (a + 20, a + 20),
                 (a + 20, 56), (a + 9, 56), (a + 9, 70), (a, 70), (a, E / S)]
        dr[layer].line([(s(x), s(y)) for x, y in steps], fill=255, width=int(w * S), joint="curve")
    stepped(0, "ink", 1.6)
    stepped(4.5, "red", 1.1)
    # quarter sunburst from the corner of the brass band
    cx, cy = s(o + 17), s(o + 17)
    for i in range(10):
        a = math.radians(4 + i * (82 / 9))
        r1 = s(46 + (6 if i % 2 else 0))
        dr["fan"].line([(cx + math.cos(a) * s(4), cy + math.sin(a) * s(4)),
                        (cx + math.cos(a) * r1, cy + math.sin(a) * r1)], fill=255, width=int(1.1 * S))
    # a small diamond in the corner and a dot on the step
    dcx, dcy = s(o + 13.5), s(o + 13.5)
    dr["ink"].polygon([(dcx, dcy - s(5)), (dcx + s(5), dcy), (dcx, dcy + s(5)), (dcx - s(5), dcy)], fill=255)
    # clip fan to inside the stepped line (roughly: below the band and above/left of the steps)
    fan = to_arr(layers["fan"])
    clip = Image.new("L", (Q * S, Q * S), 0)
    cd = ImageDraw.Draw(clip)
    a = o + 22
    cd.polygon([(s(o + 18), s(o + 18)), (s(70 - 2), s(o + 18)), (s(70 - 2), s(a + 7)), (s(54), s(a + 7)),
                (s(54), s(a + 18)), (s(a + 18), s(a + 18)), (s(a + 18), s(54)), (s(a + 7), s(54)),
                (s(a + 7), s(70 - 2)), (s(o + 18), s(70 - 2))], fill=255)
    fan *= to_arr(clip)
    quads = {}
    for k in layers:
        m = fan if k == "fan" else to_arr(layers[k])
        m = down(m, S)
        full = np.zeros((H, W))
        full[:Q, :Q] = m
        full[:Q, Q:] = m[:, ::-1]
        full[Q:, :Q] = m[::-1, :]
        full[Q:, Q:] = m[::-1, ::-1]
        quads[k] = full
    rng = np.random.default_rng(53)
    prn = 0.9 + 0.1 * pnoise(P, P, 50, rng)[(Y - M) % P, (X - M) % P]
    brass = np.clip(BRASS[None, None, :] * (0.97 + 0.035 * pnoise(P, P, 40, rng)[(Y - M) % P, (X - M) % P])[..., None], 0, 1)
    if navy:
        rgb = mix(rgb, BRASS * 0.9, quads["outer"] * prn)
        rgb = mix(rgb, brass, quads["brass"] * prn)
        rgb = mix(rgb, PAPER * 0.92, quads["ink"] * prn)
        rgb = mix(rgb, OX * 1.35, quads["red"] * prn)
        rgb = mix(rgb, brass, quads["fan"] * prn * 0.9)
    else:
        rgb = mix(rgb, NAVY, quads["outer"] * prn)
        rgb = mix(rgb, brass, quads["brass"] * prn)
        rgb = mix(rgb, INK, quads["ink"] * prn)
        rgb = mix(rgb, OX, quads["red"] * prn)
        rgb = mix(rgb, brass * 0.95, quads["fan"] * prn)
    # the sheet outline (paper edge, straight), with shadow
    Xc, Yc = X + 0.5, Y + 0.5
    d = np.minimum(np.minimum(Xc - pad, W - pad - Xc), np.minimum(Yc - pad, H - pad - Yc))
    alpha = np.clip(d + 0.5, 0, 1)
    b = np.exp(-np.maximum(d, 0) / 14) * (0.15 if navy else 0.22)
    rgb = mix(rgb, rgb * np.array([0.55, 0.4, 0.25]), b)
    sh = shift(blur(alpha, 5), 2, 5) * 0.5
    out = np.zeros((H, W, 4))
    out[..., :3] = [0.14, 0.09, 0.05]
    out[..., 3] = sh
    out = over(out, rgb, alpha)
    save(out, name)
    GEOM[name] = dict(size=[W, H], margins=[M, M, M, M], expand=pad, content=[70, 66, 70, 66])


# ----------------------------------------------------------------------------------------
# Buttons, tabs, fields, checkboxes, bars
# ----------------------------------------------------------------------------------------

def make_buttons():
    P = 64
    lab = paper_tile(P, PAPER * np.array([1.0, 0.99, 0.96]), 61, fibres=40, fox=0)
    lab_h = paper_tile(P, np.array([0.95, 0.90, 0.78]), 61, fibres=40, fox=0)
    lab_d = paper_tile(P, np.array([0.80, 0.77, 0.70]), 61, fibres=40, fox=0)
    rng = np.random.default_rng(62)
    cov = pnoise(P, P, 60, rng)

    def stamp_paint(ink, fill=None, fill_amt=0.0, strength=1.0):
        def f(rgb, alpha, g):
            X, Y, d = g["X"], g["Y"], g["d"]
            c = cov[(Y - g["mt"]) % P, (X - g["ml"]) % P]
            c2 = pnoise(P, P, 16, np.random.default_rng(63))[(Y - g["mt"]) % P, (X - g["ml"]) % P]
            knock = np.clip((c + 1.3) * 1.2, 0, 1)
            wob = 0.35 * c2
            if fill is not None:
                fm = np.clip(d - 3.0, 0, 1) * np.clip((c + 2.7) * 2.0, 0, 1) * fill_amt
                rgb[:] = mix(rgb, fill * (0.94 + 0.08 * c2)[..., None], fm)
            m = np.maximum(ink_line_mask(d + wob, 3.4, 2.3), ink_line_mask(d + wob, 6.8, 1.0))
            rgb[:] = mix(rgb, ink, m * knock * strength)
        return f
    mg = (16, 14, 16, 14)
    cont = [14, 8, 14, 9]
    sheet("buttons/stamp_normal.png", P, mg, lab, pad=3, deckle=0.6, corner=1.5, seed=64,
          shadow=(1, 2, 1.6, 0.45), burn=(5, 0.15), paint=stamp_paint(INK), content=cont)
    sheet("buttons/stamp_hover.png", P, mg, lab_h, pad=3, deckle=0.6, corner=1.5, seed=64,
          shadow=(1, 3, 2.2, 0.5), burn=(5, 0.18), paint=stamp_paint(OX), content=cont)
    sheet("buttons/stamp_pressed.png", P, mg, lab_h, pad=3, deckle=0.6, corner=1.5, seed=64,
          shadow=(0, 1, 1.0, 0.35), burn=(5, 0.1),
          paint=stamp_paint(np.array([0.30, 0.07, 0.05]), fill=OX * 0.9, fill_amt=0.93), content=cont)
    sheet("buttons/stamp_disabled.png", P, mg, lab_d, pad=3, deckle=0.6, corner=1.5, seed=64,
          shadow=(1, 2, 1.6, 0.25), burn=(5, 0.1), paint=stamp_paint(np.array([0.45, 0.41, 0.36]), strength=0.6),
          content=cont)
    def focus_paint(rgb, alpha, g):
        d = g["d"]
        m = np.maximum(ink_line_mask(d, 3.4, 2.3), ink_line_mask(d, 6.8, 1.0))
        rgb[:] = NAVY
        alpha[:] = alpha * m * 0.9
    sheet("buttons/stamp_focus.png", P, mg, lab_h, pad=3, deckle=0.6, corner=1.5, seed=64,
          shadow=None, burn=None, paint=focus_paint, content=cont)

    # index tabs (open bottom), for TabBar / TabContainer
    tp = 32
    cream = paper_tile(tp, LEDGER_PAPER, 65, fibres=16, fox=0)
    man = paper_tile(tp, np.array([0.80, 0.70, 0.50]), 66, fibres=20, fox=0)
    man_h = paper_tile(tp, np.array([0.86, 0.77, 0.57]), 66, fibres=20, fox=0)

    def tab_paint(shade):
        def f(rgb, alpha, g):
            d, Y, H = g["d"], g["Y"], g["H"]
            rgb[:] = mix(rgb, INK, ink_line_mask(d, 0.6, 1.0) * 0.45)
            if shade:
                rgb[:] = mix(rgb, rgb * 0.7, np.clip((Y - (H - 12)) / 12.0, 0, 1) ** 1.5)
        return f
    tm = (18, 12, 18, 6)
    for nm, t, sh in (("tab_selected", cream, False), ("tab_unselected", man, True), ("tab_hover", man_h, True)):
        sheet("tabs/%s.png" % nm, tp, tm, t, pad=3, deckle=0.4, corner=8, corner_bottom=0,
              seed=67, shadow=(1, -1, 2.0, 0.35), burn=(6, 0.12), open_bottom=True, paint=tab_paint(sh),
              content=[14, 7, 14, 5])

    # typed-form field (LineEdit): faint paper with an ink baseline
    fp = 32
    field_t = paper_tile(fp, np.array([0.97, 0.94, 0.86]), 68, fibres=10, fox=0)

    def field_paint(col, w):
        def f(rgb, alpha, g):
            Y, H, pad = g["Y"], g["H"], g["pad"]
            base = np.clip(w / 2 + 0.5 - np.abs(Y + 0.5 - (H - pad - 2.5)), 0, 1)
            rgb[:] = mix(rgb, col, base)
            alpha[:] = np.maximum(alpha * 0.55, base)
        return f
    for nm, col, w in (("field_normal", INK, 1.2), ("field_focus", OX, 2.2)):
        sheet("fields/%s.png" % nm, fp, (10, 10, 10, 10), field_t, pad=2, deckle=0, corner=0, seed=69,
              shadow=None, burn=None, paint=field_paint(col, w), content=[8, 5, 8, 6])

    # progress bar: ruled ledger box + hatched fill
    def box_paint(rgb, alpha, g):
        d = g["d"]
        rgb[:] = mix(rgb, INK, ink_line_mask(d, 0.8, 1.2) * 0.85)
    sheet("bars/bar_bg.png", 32, (6, 6, 6, 6), field_t, pad=0, corner=0, seed=70, shadow=None,
          burn=(4, 0.2), paint=box_paint, content=[2, 2, 2, 2])
    hp = 16
    X, Y = np.meshgrid(np.arange(hp * 2), np.arange(hp * 2))
    for nm, col in (("bar_fill", OX), ("bar_fill_green", GREEN), ("bar_fill_ink", INK)):
        ph = ((X + Y) % 8)
        hatch = np.clip(np.minimum(ph, 8 - ph) - 1.2, 0, 1)
        img = np.zeros((hp * 2, hp * 2, 4))
        img[..., :3] = col
        img[..., 3] = 0.55 + 0.45 * hatch
        img[:2, :, 3] *= 0.6
        save(img, "bars/%s.png" % nm)
    GEOM["bars/bar_fill.png"] = dict(size=[32, 32], margins=[2, 2, 2, 2], expand=0)

    # scrollbar: ink double rule track + leather-tab grabber
    tw = 14
    tr = np.zeros((32, tw, 4))
    tr[..., :3] = INK
    xs = np.arange(tw)
    tr[:, :, 3] = ((np.abs(xs - 5) < 0.6) | (np.abs(xs - 8) < 0.6))[None, :] * 0.5
    save(tr, "bars/scroll_track.png")
    gi = Image.new("RGBA", (tw * 4, 48 * 4), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gi)
    gd.rounded_rectangle([4 * 2, 4, tw * 4 - 4 * 2, 48 * 4 - 4], radius=16,
                         fill=(106, 58, 34, 255), outline=(30, 20, 10, 255), width=5)
    for yy in (80, 96, 112):
        gd.line([(18, yy), (tw * 4 - 18, yy)], fill=(214, 190, 140, 255), width=4)
    gi = gi.resize((tw, 48), Image.LANCZOS)
    save_img(gi, "bars/scroll_grabber.png")
    save_img(gi.transpose(Image.Transpose.ROTATE_90), "bars/scroll_grabber_h.png")
    save(np.transpose(tr, (1, 0, 2)), "bars/scroll_track_h.png")
    GEOM["bars/scroll_grabber.png"] = dict(size=[tw, 48], margins=[4, 12, 4, 12], expand=0)


def make_small_icons():
    """Checkboxes, radio, arrows (drawn with a slightly shaky ink hand)."""
    S = 4
    rng = np.random.default_rng(71)

    def shaky_rect(d, x0, y0, x1, y1, w, col):
        pts = []
        for (ax, ay, bx, by) in ((x0, y0, x1, y0), (x1, y0, x1, y1), (x1, y1, x0, y1), (x0, y1, x0, y0)):
            for t in np.linspace(0, 1, 6):
                pts.append((ax + (bx - ax) * t + rng.normal(0, 0.8), ay + (by - ay) * t + rng.normal(0, 0.8)))
        d.line(pts + [pts[0]], fill=col, width=w, joint="curve")
    ink = (30, 20, 10, 255)
    ox = (139, 30, 26, 255)
    for nm, mark in (("check_off", None), ("check_on", "x"), ("radio_off", None), ("radio_on", "dot"),
                     ("check_off_disabled", None), ("check_on_disabled", "x")):
        im = Image.new("RGBA", (24 * S, 24 * S), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        col = (110, 100, 88, 200) if "disabled" in nm else ink
        mcol = (120, 90, 80, 200) if "disabled" in nm else ox
        if nm.startswith("check"):
            d.rectangle([3 * S, 3 * S, 21 * S, 21 * S], fill=(240, 232, 212, 200))
            shaky_rect(d, 3 * S, 3 * S, 21 * S, 21 * S, int(1.8 * S), col)
            if mark:
                d.line([(6 * S, 6 * S), (18 * S, 19 * S)], fill=mcol, width=int(3.0 * S))
                d.line([(18 * S, 5.5 * S), (6.5 * S, 18.5 * S)], fill=mcol, width=int(2.6 * S))
        else:
            d.ellipse([3 * S, 3 * S, 21 * S, 21 * S], fill=(240, 232, 212, 200), outline=col, width=int(1.8 * S))
            if mark:
                d.ellipse([8 * S, 8 * S, 16 * S, 16 * S], fill=mcol)
        save_img(im.resize((24, 24), Image.LANCZOS), "small/%s.png" % nm)
    # arrows
    for nm, pts in (("arrow_down", [(4, 7), (16, 7), (10, 15)]), ("arrow_up", [(4, 14), (16, 14), (10, 6)]),
                    ("arrow_right", [(7, 4), (15, 10), (7, 16)])):
        im = Image.new("RGBA", (20 * S, 20 * S), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.polygon([(x * S, y * S) for x, y in pts], fill=ink)
        save_img(im.resize((20, 20), Image.LANCZOS), "small/%s.png" % nm)
    im = Image.new("RGBA", (16 * S, 24 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(3 * S, 10 * S), (13 * S, 10 * S), (8 * S, 3 * S)], fill=ink)
    d.polygon([(3 * S, 14 * S), (13 * S, 14 * S), (8 * S, 21 * S)], fill=ink)
    save_img(im.resize((16, 24), Image.LANCZOS), "small/updown.png")
    # brass push pin (for pinned cards)
    im = Image.new("RGBA", (28 * S, 28 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([7 * S, 9 * S, 23 * S, 25 * S], fill=(20, 12, 6, 90))
    d.ellipse([4 * S, 4 * S, 20 * S, 20 * S], fill=(120, 30, 24, 255), outline=(60, 14, 10, 255), width=S)
    d.ellipse([7 * S, 6 * S, 12 * S, 11 * S], fill=(230, 160, 140, 200))
    save_img(im.filter(ImageFilter.GaussianBlur(1)).resize((28, 28), Image.LANCZOS), "small/pin.png")


# ----------------------------------------------------------------------------------------
# Rules / dividers
# ----------------------------------------------------------------------------------------

def make_rules():
    # thick-thin double rule, tiles horizontally
    w, h = 64, 8
    r = np.zeros((h, w, 4))
    r[..., :3] = INK
    r[1:4, :, 3] = 1.0
    r[5:6, :, 3] = 0.9
    save(r, "rules/rule_double.png")
    r = np.zeros((3, w, 4))
    r[..., :3] = INK
    r[1, :, 3] = 0.9
    save(r, "rules/rule_thin.png")
    # dotted leader
    r = np.zeros((4, 8, 4))
    r[..., :3] = INK
    r[1:3, 2:4, 3] = 0.8
    save(r, "rules/leader_dots.png")
    # deco divider: lines + stepped diamond ornament, 360x20
    S = 4
    W, H = 360, 20
    im = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(im)
    cx, cy = W * S / 2, H * S / 2
    d.rectangle([0, cy - 1.5 * S, cx - 30 * S, cy + 0.5 * S], fill=255)
    d.rectangle([cx + 30 * S, cy - 1.5 * S, W * S, cy + 0.5 * S], fill=255)
    d.rectangle([20 * S, cy + 3 * S, cx - 30 * S, cy + 3.8 * S], fill=255)
    d.rectangle([cx + 30 * S, cy + 3 * S, W * S - 20 * S, cy + 3.8 * S], fill=255)
    for k, rr in ((0, 9), (1, 5)):
        pass
    d.polygon([(cx, cy - 9 * S), (cx + 9 * S, cy), (cx, cy + 9 * S), (cx - 9 * S, cy)], fill=255)
    d.polygon([(cx, cy - 5 * S), (cx + 5 * S, cy), (cx, cy + 5 * S), (cx - 5 * S, cy)], fill=0)
    d.polygon([(cx, cy - 2.5 * S), (cx + 2.5 * S, cy), (cx, cy + 2.5 * S), (cx - 2.5 * S, cy)], fill=255)
    for sx in (-1, 1):
        for i, off in enumerate((15, 21, 26)):
            x = cx + sx * off * S
            hh = (6 - i * 1.6) * S
            d.rectangle([x - 1.2 * S, cy - hh, x + 1.2 * S, cy + hh], fill=255)
    m = down(to_arr(im), S)
    out = np.zeros((H, W, 4))
    out[..., :3] = 1.0
    out[..., 3] = m
    save(out, "rules/deco_divider.png")


# ----------------------------------------------------------------------------------------
# Wax seal
# ----------------------------------------------------------------------------------------

def make_seal():
    S = 4
    F = 128
    N = F * S
    rng = np.random.default_rng(81)
    X, Y = np.meshgrid(np.arange(N) + 0.5, np.arange(N) + 0.5)
    cx, cy = N * 0.5, N * 0.47
    R = N * 0.34
    th = np.arctan2(Y - cy, X - cx)
    rr = np.hypot(X - cx, Y - cy)
    wob = np.zeros_like(th)
    for k in range(2, 14):
        wob += rng.uniform(0.2, 1) / k ** 1.3 * np.sin(k * th + rng.uniform(0, 6.3))
    blob = (rr < R * (1 + 0.07 * wob)).astype(float)
    im = from_mask(blob)
    d = ImageDraw.Draw(im)
    # drips / squeeze-out
    for ang, ln, wd in ((1.78, 0.36, 0.075), (1.30, 0.20, 0.06), (2.40, 0.10, 0.10), (-0.5, 0.05, 0.16)):
        ex, ey = cx + math.cos(ang) * R * (1.0 + ln), cy + math.sin(ang) * R * (1.0 + ln)
        bx, by = cx + math.cos(ang) * R * 0.8, cy + math.sin(ang) * R * 0.8
        d.line([(bx, by), (ex, ey)], fill=255, width=int(N * wd * 0.8))
        rw = N * wd * 0.55
        d.ellipse([ex - rw, ey - rw * 0.9, ex + rw, ey + rw * 1.1], fill=255)
    m = to_arr(im)
    m = (blur(m, 10) > 0.5).astype(float)
    # height field
    h = blur(m, 22) * 1.0
    inner = (rr < R * 0.70).astype(float)
    ring = ((rr > R * 0.74) & (rr < R * 0.80)).astype(float)
    h -= blur(inner, 5) * 0.38
    h += blur(ring, 3) * 0.10
    # a ring of little beads just inside the rim
    beads = np.zeros_like(h)
    bi = Image.new("L", (N, N), 0)
    bd = ImageDraw.Draw(bi)
    for i in range(36):
        a = i / 36 * 2 * math.pi
        x, y = cx + math.cos(a) * R * 0.87, cy + math.sin(a) * R * 0.87
        bd.ellipse([x - N * 0.009, y - N * 0.009, x + N * 0.009, y + N * 0.009], fill=255)
    beads = blur(to_arr(bi), 3)
    h += beads * 0.06
    h += pnoise(N, N, 30, rng, per=N) * 0.004
    gy, gx = np.gradient(h * 60.0)
    nz = np.ones_like(h)
    nl = np.sqrt(gx * gx + gy * gy + nz)
    nx, ny, nz = -gx / nl, -gy / nl, nz / nl
    L = np.array([-0.55, -0.65, 0.55])
    L /= np.linalg.norm(L)
    lam = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    # Blinn spec
    Hv = L + np.array([0, 0, 1.0])
    Hv /= np.linalg.norm(Hv)
    spec = np.clip(nx * Hv[0] + ny * Hv[1] + nz * Hv[2], 0, 1) ** 40
    tone = np.clip(0.30 + 0.78 * lam, 0, 1)
    mm = m
    out = np.zeros((N, N, 4))
    out[..., :3] = tone[..., None]
    out[..., 3] = mm
    # contact shadow
    sh = shift(blur(mm, 8), int(N * 0.012), int(N * 0.02)) * 0.55
    base = np.zeros((N, N, 4))
    base[..., 3] = sh
    base = over(base, out[..., :3], out[..., 3])
    save(premul_down(base, S), "seal/wax_seal.png")
    hi = np.zeros((N, N, 4))
    hi[..., :3] = 1.0
    hi[..., 3] = np.clip(spec * 0.9, 0, 1) * mm
    save(premul_down(hi, S), "seal/wax_seal_hi.png")
    GEOM["seal"] = dict(size=[F, F], center=[0.5, 0.47], face_radius=round(0.34 * 0.70, 3))


# ----------------------------------------------------------------------------------------
# Rubber stamps
# ----------------------------------------------------------------------------------------

def distress(m, rng, amount=1.0, per=None):
    h, w = m.shape
    per = per or max(h, w)
    n1 = pnoise(h, w, 45, rng, per=256)
    n2 = pnoise(h, w, 220, rng, per=256)
    edge = blur(m, 2.2) + n1 * 0.10 * amount + n2 * 0.06 * amount
    mm = np.clip((edge - 0.5) * 6 + 0.5, 0, 1)
    cov = np.clip((pnoise(h, w, 25, rng, per=256) + 1.6 * (2 - amount)) * 1.4, 0, 1)
    specks = np.clip((pnoise(h, w, 300, rng, per=256) - 1.6) * 3, 0, 1)
    ink = mm * cov * (0.78 + 0.22 * np.clip(n1, -1, 1)) * (1 - specks * 0.9)
    return np.clip(ink, 0, 1)


def make_stamps():
    S = 4
    rng = np.random.default_rng(91)
    specs = [("PAID", "PlayfairDisplay-Variable.ttf@900", 42, "box", 6),
             ("CONFIDENTIAL", "CourierPrime-Bold.ttf", 30, "box", 4),
             ("OVERDUE", "PlayfairDisplay-Variable.ttf@900", 34, "box2", 4),
             ("SEIZED", "PlayfairDisplay-Variable.ttf@900", 38, "box", 5),
             ("CASE FILE", "CourierPrime-Bold.ttf", 30, "box2", 3),
             ("RECEIVED", "CourierPrime-Bold.ttf", 28, "box", 3),
             ("URGENT", "PlayfairDisplay-Variable.ttf@900", 34, "box", 4)]
    for text, fn, size, kind, sp in specs:
        fnt = font(fn, size * S)
        tm = text_mask(text, fnt, pad=0, spacing=sp * S)
        th, tw = tm.shape
        padx, pady = int(14 * S), int(9 * S)
        bw = int(3.2 * S)
        extra = int(5 * S) if kind == "box2" else 0
        H = th + 2 * (pady + bw + extra) + 2 * S
        W = tw + 2 * (padx + bw + extra) + 2 * S
        im = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(im)
        o = S
        d.rounded_rectangle([o, o, W - 1 - o, H - 1 - o], radius=4 * S, outline=255, width=bw)
        if kind == "box2":
            o2 = o + bw + int(2.2 * S)
            d.rounded_rectangle([o2, o2, W - 1 - o2, H - 1 - o2], radius=2 * S, outline=255, width=int(1.3 * S))
        m = to_arr(im)
        y0 = (H - th) // 2
        x0 = (W - tw) // 2
        m[y0:y0 + th, x0:x0 + tw] = np.maximum(m[y0:y0 + th, x0:x0 + tw], tm)
        ink = distress(m, rng)
        out = np.zeros((H, W, 4))
        out[..., :3] = 1.0
        out[..., 3] = ink
        name = text.lower().replace(" ", "_")
        save(premul_down(out[: H // S * S, : W // S * S], S), "stamps/%s.png" % name)
    # blank 9-patch stamp frame for arbitrary text
    P, M = 64, 18
    W = H = P + 2 * M
    im = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([S, S, W * S - 1 - S, H * S - 1 - S], radius=4 * S, outline=255, width=int(3.2 * S))
    m = down(to_arr(im), S)
    # distress periodic in P: build noise on P tile
    Xg, Yg = np.meshgrid(np.arange(W), np.arange(H))
    n = pnoise(P, P, 30, rng, per=64)[(Yg - M) % P, (Xg - M) % P]
    sp = pnoise(P, P, 90, rng, per=64)[(Yg - M) % P, (Xg - M) % P]
    ink = m * np.clip((n + 1.5) * 1.3, 0, 1) * (0.8 + 0.2 * np.clip(n, -1, 1)) * (1 - np.clip((sp - 1.7) * 3, 0, 1))
    out = np.zeros((H, W, 4))
    out[..., :3] = 1.0
    out[..., 3] = ink
    save(out, "stamps/stamp_frame.png")
    GEOM["stamps/stamp_frame.png"] = dict(size=[W, H], margins=[M, M, M, M], expand=0, content=[16, 8, 16, 8])
    # speckle overlay (paper showing through ink), tile
    T = 128
    sp = pnoise(T, T, 60, rng, per=128)
    k = np.clip((sp - 0.9) * 2.0, 0, 1) * 0.9 + np.clip((pnoise(T, T, 200, rng, per=128) - 1.5) * 3, 0, 1)
    out = np.zeros((T, T, 4))
    out[..., :3] = PAPER
    out[..., 3] = np.clip(k, 0, 1)
    save(out, "stamps/ink_speckle.png")


# ----------------------------------------------------------------------------------------
# Typewriter key caps
# ----------------------------------------------------------------------------------------

def keycap(label, wide_w=None, F=48):
    S = 4
    D = 42
    Wf = wide_w if wide_w else F
    W, H = Wf * S, F * S
    X, Y = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    cy = (F / 2 - 1.5) * S
    r = D / 2 * S
    if wide_w:
        x0, x1 = (F / 2) * S, (Wf - F / 2) * S
    else:
        x0 = x1 = W / 2

    def sd(rad, ccy=cy):  # signed distance to a pill of radius rad
        px = np.clip(X, x0, x1)
        return np.hypot(X - px, Y - ccy) - rad
    ring = sd(r)
    top = sd(r * 0.80)
    out = np.zeros((H, W, 4))
    # shadow
    sh = np.clip(-sd(r, cy + 2.6 * S) / (2.5 * S), 0, 1) * 0.55
    out[..., 3] = sh
    # chrome ring
    ay = (Y - (cy - r)) / (2 * r)
    chrome = 0.86 - 0.42 * ay + 0.18 * np.exp(-((ay - 0.2) / 0.08) ** 2)
    ring_a = np.clip(-ring / S + 0.5, 0, 1)
    cr = np.stack([chrome * 0.93, chrome * 0.92, chrome * 0.88], -1)
    cr = mix(cr, np.array([0.18, 0.16, 0.14]), np.clip(1 - np.abs(ring / S + 0.9), 0, 1) * 0.8)
    out = over(out, np.clip(cr, 0, 1), ring_a)
    # glass top: black celluloid under a domed glass
    top_a = np.clip(-top / S + 0.5, 0, 1)
    gt = 0.07 + 0.06 * np.clip((Y - cy) / r, -1, 1)
    gl = np.stack([gt * 1.1, gt, gt * 0.9], -1)
    out = over(out, gl, top_a)
    # glass highlight crescent (upper-left)
    hl = np.clip(-sd(r * 0.66, cy - r * 0.17) / S, 0, 1) * np.clip(sd(r * 0.60, cy + r * 0.02) / S, 0, 1)
    hl *= np.clip((cy - Y) / (r * 0.4) + 0.2, 0, 1)
    out = over(out, np.ones((H, W, 3)), hl * 0.28 * top_a)
    # legend
    if label:
        size = 22 if len(label) == 1 else (15 if len(label) <= 3 else 12)
        fnt = font("CourierPrime-Bold.ttf", size * S)
        tm = text_mask(label, fnt)
        th, tw = tm.shape
        lay = np.zeros((H, W))
        yy = int(cy - th / 2 + 0.5 * S)
        xx = int((x0 + x1) / 2 - tw / 2)
        lay[yy:yy + th, xx:xx + tw] = tm
        out = over(out, np.ones((H, W, 3)) * np.array([0.95, 0.92, 0.84]), lay * top_a)
    return premul_down(out, S)


def make_keys():
    singles = list("EFGRVQJMNHZCWASDXTYP") + [str(i) for i in range(1, 10)] + ["0"]
    for k in singles:
        save(keycap(k), "keys/key_%s.png" % k)
    for k, w in (("TAB", 76), ("ESC", 76), ("ALT", 76), ("SHIFT", 92), ("SPACE", 110), ("ENTER", 96), ("CTRL", 84)):
        save(keycap(k, wide_w=w), "keys/key_%s.png" % k.lower())
    save(keycap(""), "keys/key_blank.png")
    save(keycap("", wide_w=96), "keys/key_blank_wide.png")
    GEOM["keys/key_blank_wide.png"] = dict(size=[96, 48], margins=[24, 0, 24, 0], expand=0)


# ----------------------------------------------------------------------------------------
# Halftone photos + photo frame
# ----------------------------------------------------------------------------------------

def halftone(dark, cell, angle=45.0, S=4):
    """dark: HxW darkness at S x final resolution. Returns ink mask at final res."""
    H, W = dark.shape
    X, Y = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    a = math.radians(angle)
    u = (X * math.cos(a) + Y * math.sin(a)) / (cell * S)
    v = (-X * math.sin(a) + Y * math.cos(a)) / (cell * S)
    fu = u - np.floor(u) - 0.5
    fv = v - np.floor(v) - 0.5
    dist = np.sqrt(fu * fu + fv * fv)
    rad = np.sqrt(np.clip(dark, 0, 1)) * 0.72
    ink = np.clip((rad - dist) * cell * S * 0.8 + 0.5, 0, 1)
    ink = np.where(dark > 0.9, np.maximum(ink, (dark - 0.9) * 10), ink)
    return down(ink, S)


def photo_skyline(W, H, S, rng):
    w, h = W * S, H * S
    X, Y = np.meshgrid(np.arange(w), np.arange(h))
    sky = 0.12 + 0.20 * (Y / h)
    img = Image.fromarray(np.uint8(sky * 255))
    d = ImageDraw.Draw(img)
    hz = int(h * 0.66)
    # clouds / smoke
    for i in range(6):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h * 0.35)
        d.ellipse([cx - w * 0.12, cy - h * 0.05, cx + w * 0.12, cy + h * 0.05], fill=int(255 * 0.06))
    # far buildings
    x = 0
    while x < w:
        bw = rng.uniform(0.03, 0.08) * w
        bh = rng.uniform(0.10, 0.30) * h
        d.rectangle([x, hz - bh, x + bw, hz], fill=int(255 * 0.42))
        x += bw * rng.uniform(0.7, 1.0)
    # near towers
    x = rng.uniform(0, 0.05) * w
    while x < w:
        bw = rng.uniform(0.06, 0.12) * w
        bh = rng.uniform(0.25, 0.55) * h
        top = hz - bh
        d.rectangle([x, top, x + bw, hz], fill=int(255 * 0.78))
        if rng.uniform() < 0.5:  # setback tower + spire
            d.rectangle([x + bw * 0.2, top - bh * 0.18, x + bw * 0.8, top], fill=int(255 * 0.78))
            d.polygon([(x + bw * 0.45, top - bh * 0.18), (x + bw * 0.5, top - bh * 0.34), (x + bw * 0.55, top - bh * 0.18)], fill=int(255 * 0.78))
        for wy in np.arange(top + 4 * S, hz - 3 * S, 4.5 * S):
            for wx in np.arange(x + 2 * S, x + bw - 2 * S, 3.5 * S):
                if rng.uniform() < 0.35:
                    d.rectangle([wx, wy, wx + 1.5 * S, wy + 2 * S], fill=int(255 * 0.35))
        x += bw + rng.uniform(0.0, 0.03) * w
    # water
    d.rectangle([0, hz, w, h], fill=int(255 * 0.55))
    arr = to_arr(img)
    ripple = (np.sin(Y / (1.6 * S) + np.sin(X / (9.0 * S)) * 2.0) > 0.55) & (Y > hz)
    arr = np.where(ripple, arr * 0.55, arr)
    # a tug with smoke
    tug = Image.new("L", (w, h), 0)
    td = ImageDraw.Draw(tug)
    tx, ty = w * 0.62, hz + h * 0.17
    td.polygon([(tx, ty), (tx + w * 0.2, ty), (tx + w * 0.18, ty + h * 0.07), (tx + w * 0.02, ty + h * 0.07)], fill=255)
    td.rectangle([tx + w * 0.05, ty - h * 0.07, tx + w * 0.12, ty], fill=255)
    td.rectangle([tx + w * 0.085, ty - h * 0.14, tx + w * 0.105, ty - h * 0.07], fill=255)
    tm = to_arr(tug)
    arr = np.where(tm > 0.5, 0.9, arr)
    sm = blur(to_arr(Image.new("L", (w, h), 0)), 1)
    arr = np.clip(arr + pnoise(h, w, 60, rng, per=w) * 0.03, 0, 1)
    return arr


def photo_pier(W, H, S, rng):
    w, h = W * S, H * S
    X, Y = np.meshgrid(np.arange(w), np.arange(h))
    arr = 0.15 + 0.15 * (Y / h)
    img = Image.fromarray(np.uint8(arr * 255))
    d = ImageDraw.Draw(img)
    hz = int(h * 0.55)
    d.rectangle([0, hz, w, h], fill=int(0.5 * 255))
    # freighter hull
    d.polygon([(w * 0.08, hz - h * 0.02), (w * 0.86, hz - h * 0.02), (w * 0.95, hz - h * 0.2), (w * 0.78, hz + h * 0.1), (w * 0.1, hz + h * 0.1)], fill=int(0.85 * 255))
    d.rectangle([w * 0.45, hz - h * 0.22, w * 0.68, hz - h * 0.02], fill=int(0.45 * 255))
    d.rectangle([w * 0.52, hz - h * 0.40, w * 0.58, hz - h * 0.22], fill=int(0.8 * 255))
    d.rectangle([w * 0.52, hz - h * 0.35, w * 0.58, hz - h * 0.33], fill=int(0.3 * 255))
    for mx in (0.25, 0.8):
        d.line([(w * mx, hz - h * 0.02), (w * mx, hz - h * 0.5)], fill=int(0.8 * 255), width=int(1.4 * S))
        d.line([(w * mx, hz - h * 0.45), (w * (mx - 0.12), hz - h * 0.12)], fill=int(0.8 * 255), width=int(1.0 * S))
    for i in range(10):
        wx = w * (0.14 + i * 0.03)
        d.ellipse([wx, hz + h * 0.02, wx + 1.6 * S, hz + h * 0.02 + 1.6 * S], fill=int(0.35 * 255))
    # smoke
    for i in range(7):
        cx, cy = w * (0.55 - i * 0.07), h * (0.12 - i * 0.012) + hz * 0.0
        r = w * (0.03 + i * 0.012)
        d.ellipse([cx - r, cy - r * 0.7, cx + r, cy + r * 0.7], fill=int((0.45 - i * 0.04) * 255))
    # pier deck + crates + figures in foreground
    d.polygon([(0, h * 0.78), (w, h * 0.72), (w, h), (0, h)], fill=int(0.62 * 255))
    for i in range(5):
        cx = w * (0.05 + i * 0.09)
        d.rectangle([cx, h * 0.68, cx + w * 0.07, h * 0.8], fill=int(0.75 * 255))
        d.line([(cx, h * 0.68), (cx + w * 0.07, h * 0.8)], fill=int(0.4 * 255), width=S)
    for fx in (0.6, 0.66, 0.74):
        cx = w * fx
        d.ellipse([cx - 2.2 * S, h * 0.6, cx + 2.2 * S, h * 0.6 + 4.2 * S], fill=int(0.9 * 255))
        d.polygon([(cx - 4 * S, h * 0.64), (cx + 4 * S, h * 0.64), (cx + 3 * S, h * 0.85), (cx - 3 * S, h * 0.85)], fill=int(0.9 * 255))
        d.rectangle([cx - 4.5 * S, h * 0.595, cx + 4.5 * S, h * 0.605], fill=int(0.9 * 255))
    a = to_arr(img)
    a = np.clip(a + pnoise(h, w, 60, rng, per=w) * 0.03, 0, 1)
    return a


def make_halftone():
    S = 4
    rng = np.random.default_rng(101)
    for nm, fn, (W, H) in (("halftone_skyline", photo_skyline, (320, 200)), ("halftone_pier", photo_pier, (320, 200))):
        dark = fn(W, H, S, rng)
        ink = halftone(dark, 3.2, 45, S)
        out = np.zeros((H, W, 4))
        out[..., :3] = 1.0  # white: tint with modulate (INK on newsprint, brass on a poster)
        out[..., 3] = np.clip(ink * 0.95, 0, 1)
        save(out, "photos/%s.png" % nm)
    # photo frame 9-patch: white-ish photo border + keyline
    P = 64
    tile = paper_tile(P, np.array([0.95, 0.93, 0.88]), 102, fibres=10, fox=0)

    def pf(rgb, alpha, g):
        d = g["d"]
        rgb[:] = mix(rgb, INK, ink_line_mask(d, 7.5, 1.3) * 0.9)
        # the middle is left transparent (the photo shows through)
        alpha[:] = alpha * np.clip(9.5 - d, 0, 1)
    sheet("photos/photo_frame.png", P, (16, 16, 16, 16), tile, pad=4, deckle=0.4, corner=1, seed=103,
          shadow=(1, 3, 2.5, 0.45), burn=(4, 0.15), paint=pf, content=[9, 9, 9, 9])


# ----------------------------------------------------------------------------------------
# Tear-off calendar + thermometer
# ----------------------------------------------------------------------------------------

def make_calendar():
    S = 4
    W, H = 92, 108
    rng = np.random.default_rng(111)
    X, Y = np.meshgrid(np.arange(W), np.arange(H))
    tile = paper_tile(128, np.array([0.96, 0.94, 0.88]), 112, fibres=40, fox=1)
    rgb = tile[Y % 128, X % 128].copy()
    pad = 5
    Xc, Yc = X + 0.5, Y + 0.5
    d = np.minimum(np.minimum(Xc - pad, W - pad - Xc), np.minimum(Yc - pad - 12, H - pad - Yc))
    # torn top edge (stub of the previous page) just below the binding
    torn = pad + 13 + 2.0 * np.abs(np.sin(X * 1.7) * np.cos(X * 0.63))
    d = np.minimum(d, Yc - torn)
    alpha = np.clip(d + 0.5, 0, 1)
    # page curl: lower-right corner a bit darker
    curl = np.clip(1 - np.hypot(W - pad - Xc, H - pad - Yc) / 26, 0, 1)
    rgb = mix(rgb, rgb * 0.8, curl * 0.5)
    # red month band
    band = (Yc > pad + 16) & (Yc < pad + 36) & (d > 0)
    rgb = mix(rgb, OX, band * 0.95)
    # thin ink rule under band
    rgb = mix(rgb, INK, ((Y == pad + 38) & (d > 3)) * 0.8)
    out = np.zeros((H, W, 4))
    out[..., :3] = [0.14, 0.09, 0.05]
    out[..., 3] = shift(blur(alpha, 2.5), 1, 3) * 0.5
    out = over(out, rgb, alpha)
    # binding strip with rivets
    bi = np.zeros((H, W))
    bi[pad:pad + 13, pad - 1:W - pad + 1] = 1
    bcol = np.array([0.16, 0.12, 0.10]) * (1 + 0.4 * np.clip((pad + 4 - Y) / 5, -1, 1))[..., None]
    out = over(out, np.clip(bcol, 0, 1), bi)
    for rx in (pad + 10, W - pad - 10):
        rv = np.clip(3.2 - np.hypot(Xc - rx, Yc - (pad + 6.5)), 0, 1)
        out = over(out, np.clip(BRASS * (1.1 - 0.2 * (Yc - pad - 5) / 3)[..., None], 0, 1), rv)
    save(out, "misc/calendar_page.png")
    GEOM["misc/calendar_page.png"] = dict(size=[W, H], band=[pad + 16, pad + 36], body=[pad + 40, H - pad])


def make_thermo():
    S = 4
    W, H = 250, 44
    X, Y = np.meshgrid(np.arange(W * S) + 0.5, np.arange(H * S) + 0.5)
    out = np.zeros((H * S, W * S, 4))
    # enamel-sign card
    tile = paper_tile(64, np.array([0.93, 0.89, 0.78]), 121, fibres=20, fox=0)
    # tube geometry (final px)
    bx, by, br = 20, 22, 10.0
    t0, t1, ty, tr = 26, 236, 22, 4.2
    s = S
    card = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(card).rounded_rectangle([2 * s, 2 * s, W * s - 2 * s, H * s - 2 * s], radius=8 * s, fill=255)
    cm = to_arr(card)
    cgrid = tile[(Y // S).astype(int) % 64, (X // S).astype(int) % 64]
    sh = shift(blur(cm, 2.5 * S), 1 * S, 3 * S) * 0.45
    out[..., :3] = [0.14, 0.09, 0.05]
    out[..., 3] = sh
    ccol = mix(cgrid, INK, np.clip(1.2 - np.abs(blur(cm, 1.0) - 0.5) * 8, 0, 1) * 0.0)
    out = over(out, ccol, cm)
    # keyline around card
    kl = to_arr(Image.new("L", (W * S, H * S), 0))
    ki = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(ki).rounded_rectangle([5 * s, 5 * s, W * s - 5 * s, H * s - 5 * s], radius=6 * s, outline=255, width=int(1.1 * s))
    out = over(out, np.ones_like(out[..., :3]) * INK, to_arr(ki) * 0.8)
    # ticks: 0..100 every 10 along t0+4 .. t1-4
    ti = Image.new("L", (W * S, H * S), 0)
    td = ImageDraw.Draw(ti)
    red = Image.new("L", (W * S, H * S), 0)
    rd = ImageDraw.Draw(red)
    a0, a1 = t0 + 6, t1 - 6
    for i in range(0, 21):
        x = (a0 + (a1 - a0) * i / 20) * s
        L = 5.5 if i % 2 == 0 else 3.0
        dd = rd if i >= 15 else td
        dd.line([(x, (ty - tr - 1.5) * s), (x, (ty - tr - 1.5 - L) * s)], fill=255, width=int(1.2 * s))
        dd.line([(x, (ty + tr + 1.5) * s), (x, (ty + tr + 1.5 + L) * s)], fill=255, width=int(1.2 * s))
    out = over(out, np.ones_like(out[..., :3]) * INK, to_arr(ti) * 0.9)
    out = over(out, np.ones_like(out[..., :3]) * OX, to_arr(red) * 0.95)
    # glass tube + bulb
    gi = Image.new("L", (W * S, H * S), 0)
    gd = ImageDraw.Draw(gi)
    gd.rounded_rectangle([t0 * s, (ty - tr) * s, t1 * s, (ty + tr) * s], radius=tr * s, fill=255)
    gd.ellipse([(bx - br) * s, (by - br) * s, (bx + br) * s, (by + br) * s], fill=255)
    gm = to_arr(gi)
    glass = np.ones_like(out[..., :3]) * np.array([0.86, 0.87, 0.86])
    out = over(out, glass, gm * 0.55)
    edge = np.clip(1 - np.abs(blur(gm, 0.8 * S) - 0.5) * 3.2, 0, 1) * gm
    out = over(out, np.ones_like(out[..., :3]) * np.array([0.35, 0.33, 0.30]), edge * 0.7)
    # mercury in bulb (baked), the tube column is drawn at runtime
    bulb = np.clip((br - 2.6) * s - np.hypot(X - bx * s, Y - by * s), 0, 1)
    merc = np.ones_like(out[..., :3]) * OX
    out = over(out, merc, bulb)
    hi = np.clip(2.5 * s - np.hypot(X - (bx - 3) * s, Y - (by - 3) * s), 0, 1)
    out = over(out, np.ones_like(out[..., :3]), hi * 0.55)
    save(premul_down(out, S), "misc/thermometer.png")
    GEOM["misc/thermometer.png"] = dict(size=[W, H], column=[bx + 4, ty - 2.2, a1, 4.4], scale=[a0, a1])


# ----------------------------------------------------------------------------------------

def main():
    groups = sys.argv[1:] or ["sheets", "deco", "buttons", "small", "rules", "seal", "stamps", "keys",
                              "halftone", "misc", "icons", "portraits"]
    for g in groups:
        print("==", g, flush=True)
        if g == "sheets":
            make_sheets()
        elif g == "deco":
            deco_frame("panels/deco_frame.png")
            deco_frame("panels/deco_frame_navy.png", navy=True)
        elif g == "buttons":
            make_buttons()
        elif g == "small":
            make_small_icons()
        elif g == "rules":
            make_rules()
        elif g == "seal":
            make_seal()
        elif g == "stamps":
            make_stamps()
        elif g == "keys":
            make_keys()
        elif g == "halftone":
            make_halftone()
        elif g == "misc":
            make_calendar()
            make_thermo()
        elif g == "icons":
            import uiart_icons
            uiart_icons.make_icons()
        elif g == "portraits":
            import uiart_portraits
            uiart_portraits.make_portraits()
    for k, v in GEOM.items():
        print(k, json.dumps(v))


if __name__ == "__main__":
    main()
