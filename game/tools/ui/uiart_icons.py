"""Linocut icon set for the Famiglia UI kit (called from make_ui_art.py).

Each icon is a list of drawing operations in a 0..100 unit square: ink (255) or carve (0),
applied in order on a 4x canvas. The block is then 'printed': edges are roughened with
noise, and tapered gouges are cut along the lit (top-left) edges like a real lino block.
Icons are white on transparent (tint them with modulate): 32, 64 and 128 px.
"""
import math
import numpy as np
from PIL import Image, ImageDraw
from uiart_common import (to_arr, from_mask, blur, shift, erode, down, pnoise, save, font)

INK, CUT = 255, 0


class Pen:
    def __init__(self, N):
        self.N = N
        self.u = N / 100.0
        self.im = Image.new("L", (N, N), 0)
        self.d = ImageDraw.Draw(self.im)

    def p(self, pts):
        return [(x * self.u, y * self.u) for x, y in pts]

    def poly(self, pts, c=INK):
        self.d.polygon(self.p(pts), fill=c)

    def rect(self, x0, y0, x1, y1, c=INK, r=0):
        if r:
            self.d.rounded_rectangle([x0 * self.u, y0 * self.u, x1 * self.u, y1 * self.u], radius=r * self.u, fill=c)
        else:
            self.d.rectangle([x0 * self.u, y0 * self.u, x1 * self.u, y1 * self.u], fill=c)

    def ell(self, x0, y0, x1, y1, c=INK, w=0):
        box = [x0 * self.u, y0 * self.u, x1 * self.u, y1 * self.u]
        if w:
            self.d.ellipse(box, outline=c, width=max(1, int(w * self.u)))
        else:
            self.d.ellipse(box, fill=c)

    def circ(self, cx, cy, r, c=INK, w=0):
        self.ell(cx - r, cy - r, cx + r, cy + r, c, w)

    def line(self, pts, w, c=INK):
        self.d.line(self.p(pts), fill=c, width=max(1, int(w * self.u)), joint="curve")
        # round caps
        for x, y in (pts[0], pts[-1]):
            r = w / 2
            self.ell(x - r, y - r, x + r, y + r, c)

    def arc(self, x0, y0, x1, y1, a0, a1, w, c=INK):
        self.d.arc([x0 * self.u, y0 * self.u, x1 * self.u, y1 * self.u], a0, a1, fill=c, width=max(1, int(w * self.u)))

    def text(self, s, cx, cy, size, fn="PlayfairDisplay-Variable.ttf@900", c=CUT):
        f = font(fn, int(size * self.u))
        self.d.text((cx * self.u, cy * self.u), s, font=f, fill=c, anchor="mm")


def bez(p0, p1, p2, n=16):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in np.linspace(0, 1, n)]


# ------------------------------------------------------------------------------ designs

def i_fedora(g):
    g.ell(6, 56, 94, 80)
    g.poly([(22, 64), (25, 40), (30, 28), (40, 21), (50, 27), (60, 21), (70, 28), (75, 40), (78, 64)])
    g.line([(28, 52), (72, 52)], 2.6, CUT)
    g.line([(26, 61), (74, 61)], 2.6, CUT)
    g.line(bez((50, 29), (48, 36), (50, 44)), 2.2, CUT)
    g.arc(10, 60, 90, 78, 15, 165, 2.2, CUT)
    g.poly([(62, 53.5), (68, 53.5), (66, 59.5), (60, 59.5)], CUT)


def i_badge(g):
    pts = [(50, 6), (64, 14), (80, 14), (82, 44)] + bez((82, 44), (78, 76), (50, 94))[1:] + \
          bez((50, 94), (22, 76), (18, 44))[1:] + [(20, 14), (36, 14)]
    g.poly(pts)
    g.circ(50, 50, 21, CUT, w=3)
    star = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 15 if i % 2 == 0 else 6.5
        star.append((50 + math.cos(a) * r, 50 + math.sin(a) * r))
    g.circ(50, 50, 18.5, CUT)
    g.poly(star, INK)
    g.rect(30, 19, 70, 27, CUT, r=2)
    g.rect(33, 21.5, 67, 24.5, INK)
    g.circ(50, 50, 3, CUT)


def i_pistol(g):
    g.rect(40, 30, 93, 40, r=1.5)
    g.rect(86, 25, 90, 31)
    g.rect(28, 25, 54, 50, r=3)
    g.poly([(24, 27), (30, 18), (34, 20), (34, 28)])
    g.poly([(30, 46), (46, 46), (44, 56), (38, 84), (20, 86), (16, 80), (26, 58)])
    g.ell(40, 44, 62, 66, INK, w=4)
    g.line([(31, 35), (51, 35)], 2.4, CUT)
    g.line([(31, 42), (51, 42)], 2.4, CUT)
    g.line([(44, 36.5), (93, 36.5)], 1.4, CUT)
    for k in range(4):
        g.line([(24 + k * 4, 60 + k * 1), (22 + k * 4, 80)], 1.6, CUT)
    g.line([(50, 48), (54, 58)], 3, INK)
    g.circ(30, 51, 2.5, CUT)


def i_tommy(g):
    g.poly([(3, 42), (27, 38), (29, 50), (6, 62), (2, 58)])
    g.rect(26, 35, 62, 48, r=2)
    g.rect(60, 39, 90, 45)
    g.rect(62, 34, 81, 50, r=1.5)
    g.rect(88, 36, 97, 47, r=1)
    g.circ(47, 57, 11)
    g.poly([(31, 47), (39, 47), (36, 68), (28, 67)])
    g.poly([(67, 49), (74, 49), (73, 66), (66, 66)])
    for k in range(6):
        x = 64.5 + k * 3
        g.line([(x, 36), (x, 48)], 1.3, CUT)
    g.circ(47, 57, 7, CUT, w=2.0)
    g.circ(47, 57, 2.4, CUT)
    g.line([(28, 41), (58, 41)], 1.6, CUT)
    g.line([(8, 55), (26, 45)], 1.6, CUT)
    g.rect(40, 30, 44, 35)


def i_barrel(g):
    pts = []
    for t in np.linspace(0, 1, 24):
        y = 10 + 80 * t
        pts.append((50 + 26 + 9 * math.sin(math.pi * t), y))
    for t in np.linspace(1, 0, 24):
        y = 10 + 80 * t
        pts.append((50 - 26 - 9 * math.sin(math.pi * t), y))
    g.poly(pts)
    g.ell(25, 6, 75, 16)
    g.ell(28, 8, 72, 14, CUT, w=1.6)
    for y in (27, 32, 68, 73):
        g.arc(14, y - 5, 86, y + 5, 0, 180, 2.0, CUT)
    for xo in (-16, -5, 6, 17):
        g.line(bez((50 + xo * 0.85, 36), (50 + xo * 1.12, 50), (50 + xo * 0.85, 64)), 1.4, CUT)
    g.circ(62, 50, 3.2, CUT)
    g.circ(62, 50, 1.5, INK)


def i_crate(g):
    g.poly([(10, 32), (68, 32), (68, 90), (10, 90)])
    g.poly([(10, 32), (28, 14), (88, 14), (68, 32)])
    g.poly([(68, 32), (88, 14), (88, 72), (68, 90)])
    g.line([(10, 32), (68, 32), (88, 14)], 2.2, CUT)
    g.line([(68, 32), (68, 90)], 2.2, CUT)
    for y in (51, 71):
        g.line([(12, y), (66, y)], 1.6, CUT)
    for t in (0.33, 0.66):
        g.line([(70, 32 + (90 - 32) * t - 18 * 0), (86, 14 + (72 - 14) * t)], 1.4, CUT)
    g.line([(14, 86), (64, 36)], 3.2, CUT)
    g.line([(14, 86), (64, 36)], 1.0, INK)
    for x, y in ((14, 36), (64, 36), (14, 86), (64, 86)):
        g.circ(x, y, 1.6, CUT)
    for k in range(3):
        g.line([(34 + k * 17, 20), (46 + k * 17, 26)], 1.2, CUT)


def i_anchor(g):
    g.circ(50, 13, 8, INK, w=4.2)
    g.rect(46.5, 20, 53.5, 82, r=2)
    g.rect(28, 27, 72, 33, r=3)
    g.circ(28, 30, 4)
    g.circ(72, 30, 4)
    g.arc(15, 30, 85, 90, 15, 165, 7)
    g.poly([(10, 52), (24, 62), (13, 70)])
    g.poly([(90, 52), (76, 62), (87, 70)])
    g.poly([(44, 82), (56, 82), (50, 92)])
    g.line([(50, 36), (50, 76)], 1.4, CUT)


def i_warehouse(g):
    g.poly([(8, 44), (50, 16), (92, 44), (92, 90), (8, 90)])
    g.line([(6, 45), (50, 16), (94, 45)], 1.8, CUT)
    g.poly([(4, 44), (50, 12), (96, 44), (92, 47), (50, 18), (8, 47)], INK)
    g.rect(33, 55, 67, 90, CUT)
    g.rect(35.5, 57.5, 64.5, 90, INK)
    g.line([(36, 58), (64, 88)], 2.2, CUT)
    g.line([(64, 58), (36, 88)], 2.2, CUT)
    g.line([(50, 58), (50, 90)], 1.6, CUT)
    for x0 in (14, 74):
        g.rect(x0, 54, x0 + 12, 66, CUT)
        g.line([(x0 + 6, 54), (x0 + 6, 66)], 1.2, INK)
        g.line([(x0, 60), (x0 + 12, 60)], 1.2, INK)
    g.circ(50, 35, 6, CUT)
    g.line([(44, 35), (56, 35)], 1.2, INK)
    g.line([(50, 29), (50, 41)], 1.2, INK)
    for y in (72, 80):
        g.line([(10, y), (31, y)], 1.0, CUT)
        g.line([(69, y), (90, y)], 1.0, CUT)


def i_still(g):
    g.ell(8, 38, 58, 80)
    g.ell(22, 26, 44, 46)
    g.rect(29, 18, 37, 30, r=2)
    g.line([(33, 20)] + bez((33, 20), (56, 6), (78, 36))[1:], 4.5)
    g.rect(62, 40, 92, 88, r=3)
    g.rect(12, 78, 54, 90, r=1)
    for k in range(4):
        y = 50 + k * 9
        g.line(bez((65, y), (77, y - 5), (89, y)), 1.6, CUT)
    g.line([(62, 45), (92, 45)], 1.6, CUT)
    g.line([(62, 83), (92, 83)], 1.6, CUT)
    for x in (18, 28, 38, 48):
        g.poly([(x - 3.5, 90), (x, 80.5), (x + 3.5, 90)], CUT)
    g.arc(13, 43, 53, 75, 200, 250, 2.2, CUT)
    g.line([(92, 80), (98, 80)], 2.6)
    g.circ(97, 86, 1.6)
    g.line([(8, 59), (58, 59)], 1.4, CUT)


def i_tankard(g):
    g.rect(22, 30, 66, 90, r=5)
    for x in range(26, 64, 7):
        g.circ(x, 28, 7.5)
    g.circ(64, 34, 5)
    g.poly([(60, 34), (68, 34), (67, 46), (64, 50), (61, 44)])
    g.ell(56, 40, 90, 76, INK, w=7)
    g.line([(22, 44), (66, 44)], 2.0, CUT)
    g.line([(22, 78), (66, 78)], 2.0, CUT)
    for x in (32, 44, 56):
        g.line([(x, 48), (x, 74)], 1.4, CUT)
    for x, y, r in ((30, 25, 2.2), (42, 23, 2.8), (53, 26, 1.8), (36, 31, 1.4), (60, 27, 1.5)):
        g.circ(x, y, r, CUT)


def i_loco(g):
    g.rect(22, 34, 70, 58, r=1)
    g.ell(16, 34, 30, 58)
    g.poly([(27, 36), (24, 16), (40, 16), (36, 36)])
    g.rect(22, 12, 42, 18, r=1.5)
    g.ell(43, 26, 55, 38)
    g.rect(68, 22, 92, 62)
    g.rect(65, 18, 95, 24, r=1)
    g.rect(73, 28, 87, 40, CUT)
    g.rect(14, 58, 94, 66)
    g.poly([(4, 78), (18, 58), (22, 58), (22, 78)])
    for (cx, r) in ((40, 11), (63, 11)):
        g.circ(cx, 75, r)
        g.circ(cx, 75, r - 2.6, CUT, w=1.6)
        for k in range(6):
            a = k * math.pi / 3
            g.line([(cx, 75), (cx + math.cos(a) * (r - 3), 75 + math.sin(a) * (r - 3))], 1.2, CUT)
    for cx in (26, 85):
        g.circ(cx, 78, 6.5)
        g.circ(cx, 78, 3.5, CUT, w=1.2)
    g.line([(40, 71), (63, 71)], 2.4, INK)
    g.line([(8, 76), (18, 62)], 1.2, CUT)
    g.line([(12, 77), (20, 66)], 1.2, CUT)
    for x in (34, 58):
        g.line([(x, 34), (x, 58)], 1.4, CUT)
    g.circ(18, 46, 3, CUT)


def i_envelope(g):
    g.rect(8, 24, 92, 80, r=1.5)
    g.line([(9, 26), (50, 57), (91, 26)], 2.8, CUT)
    g.line([(10, 78), (40, 53)], 1.6, CUT)
    g.line([(90, 78), (60, 53)], 1.6, CUT)
    g.circ(50, 57, 11, CUT)
    g.circ(50, 57, 9)
    g.circ(50, 57, 5.5, CUT, w=1.2)
    g.poly([(44, 64), (40, 74), (46, 70)])
    g.poly([(56, 64), (60, 74), (54, 70)])


def i_ledger(g):
    g.poly([(20, 12), (84, 12), (84, 84), (20, 84)])
    g.poly([(24, 84), (84, 84), (88, 80), (88, 90), (24, 90)])
    g.line([(24, 87), (86, 87)], 1.2, CUT)
    g.line([(31, 12), (31, 84)], 2.2, CUT)
    for y in (20, 24, 72, 76):
        g.line([(21, y), (29, y)], 1.3, CUT)
    g.rect(42, 28, 74, 48, CUT)
    g.rect(44.5, 30.5, 71.5, 45.5, INK)
    g.line([(48, 35), (68, 35)], 1.4, CUT)
    g.line([(50, 40.5), (66, 40.5)], 1.4, CUT)
    for (x, y, sx, sy) in ((84, 12, -1, 1), (84, 84, -1, -1)):
        g.poly([(x, y), (x + sx * 12, y), (x, y + sy * 12)], CUT)
        g.poly([(x - sx * 0.5, y + sy * 2), (x + sx * 9.5, y + sy * 2 * 0 + sy * 0.5), (x, y + sy * 10)], INK)
    g.text("$", 58, 64, 18, c=CUT)


def i_handshake(g):
    g.poly([(0, 74), (14, 92), (46, 62), (34, 46)])
    g.poly([(100, 74), (86, 92), (54, 62), (66, 46)])
    g.ell(28, 34, 72, 66)
    g.poly([(56, 36), (74, 30), (78, 38), (62, 46)])
    for k in range(4):
        x = 38 + k * 7
        g.line(bez((x, 42), (x + 5, 46), (x + 3, 56)), 1.8, CUT)
    g.line(bez((34, 44), (44, 38), (58, 40)), 1.8, CUT)
    g.line([(4, 70), (16, 84)], 2.2, CUT)
    g.line([(96, 70), (84, 84)], 2.2, CUT)
    g.line([(8, 64), (22, 80)], 1.4, CUT)
    g.line([(92, 64), (78, 80)], 1.4, CUT)


def i_skull(g):
    g.line([(12, 70), (88, 94)], 7)
    g.line([(88, 70), (12, 94)], 7)
    for x, y in ((12, 70), (88, 94), (88, 70), (12, 94)):
        g.circ(x - 2, y - 3, 4.2)
        g.circ(x + 2, y + 3, 4.2)
    g.ell(20, 6, 80, 64, CUT)
    g.rect(32, 52, 68, 88, CUT, r=8)
    g.ell(23, 9, 77, 61)
    g.ell(26, 40, 74, 68)
    g.rect(35, 55, 65, 85, r=7)
    g.ell(31, 34, 47, 52, CUT)
    g.ell(53, 34, 69, 52, CUT)
    g.poly([(50, 53), (45, 63), (55, 63)], CUT)
    g.line([(37, 70), (63, 70)], 1.4, CUT)
    for x in (41, 46, 50, 54, 59):
        g.line([(x, 66), (x, 80)], 1.3, CUT)
    g.arc(30, 14, 60, 40, 190, 260, 2.0, CUT)


def i_eye(g):
    top = bez((6, 50), (50, 14), (94, 50))
    bot = bez((94, 50), (50, 86), (6, 50))
    g.poly(top + bot)
    it = bez((14, 50), (50, 24), (86, 50))
    ib = bez((86, 50), (50, 76), (14, 50))
    g.poly(it + ib, CUT)
    g.circ(50, 50, 17)
    g.circ(50, 50, 11.5, CUT, w=1.6)
    g.circ(50, 50, 6.5)
    g.circ(44, 44, 3.5, CUT)
    for k in range(7):
        t = 0.15 + k * 0.7 / 6
        x = (1 - t) ** 2 * 6 + 2 * (1 - t) * t * 50 + t * t * 94
        y = (1 - t) ** 2 * 50 + 2 * (1 - t) * t * 14 + t * t * 50
        ang = math.atan2(y - 60, x - 50)
        g.line([(x, y), (x + math.cos(ang) * 9, y + math.sin(ang) * 9)], 2.2)
    g.arc(6, 30, 94, 94, 205, 335, 1.4, INK)


def i_copcap(g):
    g.ell(12, 16, 88, 42)
    g.poly([(20, 30), (80, 30), (74, 62), (26, 62)])
    g.line(bez((16, 30), (50, 44), (84, 30)), 1.8, CUT)
    g.line([(25, 50), (75, 50)], 1.8, CUT)
    g.line([(26, 61), (74, 61)], 1.8, CUT)
    g.ell(20, 54, 80, 82)
    g.rect(20, 54, 80, 66, CUT)
    g.rect(22, 54, 78, 64)
    g.arc(24, 58, 76, 78, 20, 160, 1.6, CUT)
    shield = [(50, 30), (57, 33), (57, 41), (50, 47), (43, 41), (43, 33)]
    g.poly(shield, CUT)
    g.poly([(50, 33), (54.5, 35), (54.5, 40), (50, 44), (45.5, 40), (45.5, 35)], INK)
    g.circ(50, 38.5, 1.4, CUT)


def i_truck(g):
    g.rect(6, 62, 94, 68)
    g.poly([(52, 28), (74, 28), (78, 62), (52, 62)])
    g.rect(50, 24, 76, 30, r=1)
    g.poly([(74, 42), (90, 42), (95, 48), (95, 62), (74, 62)])
    g.rect(6, 40, 52, 62)
    g.rect(56, 33, 71, 46, CUT)
    for x in (13, 22, 31, 40):
        g.line([(x, 42), (x, 60)], 1.4, CUT)
    g.line([(7, 50), (51, 50)], 1.3, CUT)
    for x in (82, 86, 90):
        g.line([(x, 46), (x, 58)], 1.2, CUT)
    g.arc(64, 58, 92, 86, 180, 360, 3.2)
    for cx in (22, 78):
        g.circ(cx, 73, 12, CUT)
        g.circ(cx, 73, 10.5)
        g.circ(cx, 73, 7, CUT, w=1.4)
        for k in range(8):
            a = k * math.pi / 4
            g.line([(cx, 73), (cx + math.cos(a) * 6.8, 73 + math.sin(a) * 6.8)], 1.1, CUT)
        g.circ(cx, 73, 2.2)
    g.circ(94, 47, 3)


def i_ship(g):
    g.poly([(2, 52), (10, 60), (96, 60), (90, 78), (16, 78)])
    g.rect(38, 42, 68, 60)
    g.rect(42, 34, 62, 42)
    g.poly([(68, 22), (79, 22), (80, 52), (68, 52)])
    g.circ(84, 16, 5)
    g.circ(92, 9, 6.5)
    g.circ(76, 18, 3.5)
    g.line([(22, 26), (22, 60)], 2.4)
    g.line([(22, 30), (36, 52)], 1.4)
    g.line([(88, 36), (88, 60)], 2.0)
    g.line([(68, 29), (80, 29)], 1.6, CUT)
    for x in range(16, 88, 8):
        g.circ(x, 67, 1.8, CUT)
    g.line([(14, 73), (91, 73)], 1.4, CUT)
    for x0 in (44, 52):
        g.rect(x0, 36.5, x0 + 5, 40, CUT)
    for yy in (86, 94):
        pts = [(x, yy + 2.2 * math.sin(x / 5.0)) for x in range(4, 97, 3)]
        g.line(pts, 2.2)


def i_moneybag(g):
    g.ell(16, 34, 84, 94)
    g.poly([(40, 20), (60, 20), (58, 38), (42, 38)])
    zig = [(30, 8)]
    for k in range(1, 8):
        zig.append((30 + k * 40 / 7, 8 + (6 if k % 2 else 0)))
    g.poly(zig + [(62, 22), (38, 22)])
    g.line([(38, 25), (62, 25)], 2.6, CUT)
    g.line([(58, 25), (70, 34)], 2.4, INK)
    g.line([(60, 26), (68, 20)], 2.4, INK)
    g.text("$", 50, 66, 42, c=CUT)
    g.arc(22, 40, 78, 92, 200, 250, 2.0, CUT)


def i_banknotes(g):
    for k in range(3):
        o = k * 6
        g.poly([(8 + o, 34 - o), (84 + o, 34 - o), (84 + o, 76 - o), (8 + o, 76 - o)], CUT)
        g.poly([(10 + o, 36 - o), (82 + o, 36 - o), (82 + o, 74 - o), (10 + o, 74 - o)])
    o = 12
    g.ell(38 + o, 41 - o, 56 + o, 69 - o, CUT)
    g.ell(40.5 + o, 43.5 - o, 53.5 + o, 66.5 - o)
    g.rect(14 + o, 26, 82 + o, 27.5, CUT)
    g.rect(14 + o, 57, 82 + o, 58.5, CUT)
    g.text("1", 22 + o, 42 - o + 6, 12, c=CUT)
    g.text("1", 76 + o, 42 - o + 6, 12, c=CUT)


def i_car(g):
    g.poly([(6, 54), (18, 50), (28, 34), (62, 34), (72, 48), (92, 52), (94, 66), (6, 66)])
    g.rect(31, 38, 45, 49, CUT)
    g.rect(49, 38, 63, 49, CUT)
    g.arc(10, 54, 38, 82, 180, 360, 3)
    g.arc(62, 54, 90, 82, 180, 360, 3)
    for cx in (24, 76):
        g.circ(cx, 68, 11, CUT)
        g.circ(cx, 68, 9.5)
        g.circ(cx, 68, 6, CUT, w=1.3)
        g.circ(cx, 68, 2)
    g.line([(8, 58), (92, 58)], 1.3, CUT)
    g.circ(92, 55, 2.5, CUT)


def i_telephone(g):
    g.ell(26, 82, 74, 96)
    g.rect(44, 28, 56, 88, r=2)
    g.poly([(38, 22), (62, 22), (56, 34), (44, 34)])
    g.ell(34, 8, 66, 26)
    g.circ(50, 17, 6.5, CUT, w=1.6)
    g.circ(50, 17, 2.2, CUT)
    g.line([(44, 42), (34, 42), (32, 36)], 2.6)
    g.rect(22, 38, 32, 70, r=4)
    g.ell(17, 64, 37, 80)
    g.ell(20, 67, 34, 77, CUT, w=1.4)
    g.line(bez((27, 80), (30, 94), (44, 90)), 2.0)
    g.line([(46, 32), (46, 86)], 1.3, CUT)
    g.arc(29, 85, 71, 95, 200, 340, 1.4, CUT)


ICONS = {
    "fedora": i_fedora, "badge": i_badge, "pistol": i_pistol, "tommy_gun": i_tommy, "barrel": i_barrel,
    "crate": i_crate, "anchor": i_anchor, "warehouse": i_warehouse, "still": i_still, "brewery": i_tankard,
    "locomotive": i_loco, "envelope": i_envelope, "ledger": i_ledger, "handshake": i_handshake,
    "skull": i_skull, "eye": i_eye, "cop_cap": i_copcap, "truck": i_truck, "ship": i_ship,
    "money_bag": i_moneybag, "banknotes": i_banknotes, "car": i_car, "telephone": i_telephone,
}


def print_block(mask, final, seed, hatch=True):
    """Roughen the block edges and cut tapered gouges on the lit side."""
    S = mask.shape[0] // final
    rng = np.random.default_rng(seed)
    N = mask.shape[0]
    n = pnoise(N, N, 40, rng, per=N / final * 64) * 0.10 + pnoise(N, N, 140, rng, per=N / final * 64) * 0.05
    m = blur(mask, 0.35 * S)
    m = np.clip((m + n - 0.5) * 5 + 0.5, 0, 1)
    if hatch:
        mb = (m > 0.5).astype(float)
        inner = erode(mb, int(1.1 * S))
        step = max(1, int(0.9 * S))
        close = np.zeros_like(mb)
        K = 4
        for k in range(1, K + 1):
            close += 1 - shift(mb, k * step, k * step)
        close = close / K * inner
        X, Y = np.meshgrid(np.arange(N), np.arange(N))
        period = (4.6 if final >= 100 else 5.5) * S
        ph = ((X - Y) % period) / period
        tri = np.minimum(ph, 1 - ph) * 2  # 0 at line centre .. 1 between lines
        wobble = pnoise(N, N, 20, rng, per=N) * 0.08
        gouge = np.clip((close * 0.62 + wobble - tri) * 6, 0, 1) * (close > 0.2)
        m = m * (1 - gouge)
    return m


def make_icons():
    for i, (name, fn) in enumerate(ICONS.items()):
        for final, suffix, hatch in ((128, "_128", True), (64, "", True), (32, "_32", False)):
            S = 4
            N = final * S
            g = Pen(N)
            fn(g)
            m = print_block(to_arr(g.im), final, 1000 + i, hatch=hatch)
            m = down(m, S)
            out = np.ones((final, final, 4))
            out[..., 3] = m
            save(out, "icons/%s%s.png" % (name, suffix))
