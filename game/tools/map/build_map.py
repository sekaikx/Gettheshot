#!/usr/bin/env python3
"""Bake Famiglia's country map: a 1920s atlas plate of the eastern United States and Canada.

    python3 game/tools/map/build_map.py            # writes game/assets/map/country_map.png (+ _small)
    python3 game/tools/map/build_map.py --preview  # half-size, quick look (writes to /tmp unless --out)
    python3 game/tools/map/build_map.py --debug    # also writes $TMPDIR/country_map_debug.png with the game's
                                                    # cities and sources as dots (projection check)
    python3 game/tools/map/build_map.py --check godot_render.png   # compare with check_projection.tscn

Sources (downloaded once into ~/.cache/famiglia-map, or $FAMIGLIA_MAP_CACHE; never into the repo):
Natural Earth 1:10m vectors (public domain), AWS Terrain Tiles z6 = USGS GMTED2010 + NOAA ETOPO1
(public domain), IM Fell fonts by Igino Marini (SIL OFL). Needs numpy + Pillow (+ requests to download).
The projection lives in mapproj.py and is mirrored exactly by scripts/core/map_projection.gd.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import tempfile
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import geodata  # noqa: E402
import mapproj as mp  # noqa: E402
import raster  # noqa: E402
from plate_data import BOAT_ROUTES, CITIES, LANES, RAILS, ROUTES, SOURCES  # noqa: E402
from plate_labels import LABELS, OUTLINED, PLACES, STYLES  # noqa: E402

HERE = Path(__file__).resolve().parent
GAME = HERE.parent.parent
OUT_DIR = GAME / "assets" / "map"
FONT_DIR = OUT_DIR / "fonts"
# the --debug copy (plate + python-projected dots) stays out of the repo
DEBUG_PNG = Path(tempfile.gettempdir()) / "country_map_debug.png"

# ----------------------------------------------------------------------------- palette (RGB 0-255)
PAPER = (233, 223, 199)
INK = (30, 20, 10)
WATER_INK = (44, 74, 102)
COAST_INK = (26, 32, 40)
RELIEF_INK = (104, 74, 46)
OXBLOOD = (139, 30, 26)
NAVY = (43, 58, 85)
# tints are printed on white, then multiplied onto the paper
STATE_TINTS = [
    (248, 200, 204),  # rose
    (252, 236, 168),  # straw
    (210, 230, 184),  # sage green
    (224, 212, 238),  # lilac
    (248, 212, 160),  # buff orange
]
CANADA_TINTS = [
    (244, 200, 196), (240, 226, 176), (206, 224, 196), (222, 214, 230), (238, 214, 180),
]
FOREIGN_TINT = {
    "MEX": (236, 222, 178), "CUB": (246, 214, 176), "BHS": (244, 196, 188), "BMU": (244, 196, 188),
    "HTI": (214, 226, 190), "DOM": (240, 222, 184), "JAM": (244, 196, 188), "PRI": (250, 214, 190),
    "BLZ": (244, 196, 188), "GTM": (220, 214, 232), "HND": (214, 226, 190), "TCA": (244, 196, 188),
    "CYM": (244, 196, 188), "SPM": (206, 218, 236), "GRL": (230, 226, 214), "VGB": (244, 196, 188),
    "VIR": (250, 214, 190), "SLV": (240, 222, 184), "NIC": (240, 222, 184),
}
NEWFOUNDLAND_TINT = (246, 198, 186)
WATER_TINT = (206, 226, 230)
DEEP_TINT = (190, 214, 224)
LAND_NEUTRAL = (240, 232, 214)


# ----------------------------------------------------------------------------- context
class Ctx:
    def __init__(self, res: float, ss: int):
        self.R = res
        self.ss = ss
        self.U = res * ss                      # work pixels per plate pixel
        self.WW = int(round(mp.IMAGE_W * self.U))
        self.WH = int(round(mp.IMAGE_H * self.U))
        self.FW = int(round(mp.IMAGE_W * res))
        self.FH = int(round(mp.IMAGE_H * res))

    def P(self, lat, lon):
        """lat/lon -> work-pixel draw coordinates (PIL convention: integer = pixel centre)."""
        x, y = mp.to_px(lat, lon)
        return x * self.U - 0.5, y * self.U - 0.5

    def ring(self, arr):
        """(N, 2) lon/lat array -> list of (x, y) work coordinates."""
        x, y = self.P(arr[:, 1], arr[:, 0])
        return list(zip(x.tolist(), y.tolist()))

    def w(self, v):
        """plate pixels -> work pixels"""
        return v * self.U

    def mask(self, fill=0):
        return Image.new("L", (self.WW, self.WH), fill)


def log(msg, t0=[time.time()]):
    print(f"[{time.time() - t0[0]:6.1f}s] {msg}", file=sys.stderr, flush=True)


# ----------------------------------------------------------------------------- compositing
class Canvas:
    """RGB multiplicative print canvas (255 = bare paper)."""

    def __init__(self, ctx: Ctx, base: Image.Image):
        self.ctx = ctx
        self.img = base
        self.white = Image.new("RGB", base.size, (255, 255, 255))

    def ink(self, mask: Image.Image, color, opacity: float = 1.0, knock: Image.Image | None = None):
        if opacity < 1.0:
            mask = mask.point(lambda v, o=opacity: int(v * o + 0.5))
        if knock is not None:
            mask = ImageChops.multiply(mask, ImageChops.invert(knock))
        layer = Image.new("RGB", self.img.size, color)
        factor = Image.composite(layer, self.white, mask)
        self.img = ImageChops.multiply(self.img, factor)

    def clear(self, mask: Image.Image):
        """Back to bare paper where mask is set (for cartouche panels)."""
        self.img = Image.composite(self.white, self.img, mask)


# ----------------------------------------------------------------------------- polyline helpers
class Path2:
    def __init__(self, pts):
        a = np.asarray(pts, dtype=np.float64)
        self.p = a
        d = np.hypot(np.diff(a[:, 0]), np.diff(a[:, 1])) if len(a) > 1 else np.zeros(0)
        self.cum = np.concatenate([[0.0], np.cumsum(d)])
        self.length = float(self.cum[-1])

    def at(self, s):
        s = min(max(s, 0.0), self.length)
        i = int(np.searchsorted(self.cum, s, side="right") - 1)
        i = min(max(i, 0), len(self.p) - 2)
        seg = self.cum[i + 1] - self.cum[i]
        t = 0.0 if seg == 0 else (s - self.cum[i]) / seg
        a, b = self.p[i], self.p[i + 1]
        return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, math.atan2(b[1] - a[1], b[0] - a[0])

    def at_ext(self, s):
        """Like at(), but runs straight on past either end (for names longer than their path)."""
        if 0.0 <= s <= self.length or len(self.p) < 2:
            return self.at(s)
        if s < 0:
            a, b = self.p[0], self.p[1]
            seg = self.cum[1]
            t = s / seg if seg else 0.0
        else:
            a, b = self.p[-2], self.p[-1]
            seg = self.cum[-1] - self.cum[-2]
            t = 1.0 + (s - self.length) / seg if seg else 1.0
        return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, math.atan2(b[1] - a[1], b[0] - a[0])

    def sub(self, s0, s1):
        s0 = max(0.0, s0); s1 = min(self.length, s1)
        if s1 <= s0:
            return []
        i0 = int(np.searchsorted(self.cum, s0, side="right"))
        i1 = int(np.searchsorted(self.cum, s1, side="left"))
        x0, y0, _ = self.at(s0)
        x1, y1, _ = self.at(s1)
        mid = [tuple(self.p[i]) for i in range(i0, i1)]
        return [(x0, y0)] + mid + [(x1, y1)]


def draw_pattern(draw: ImageDraw.ImageDraw, pts, pattern, width, fill=255, phase=0.0):
    """pattern: [('d', len) dash | ('g', len) gap | ('o', radius) dot], lengths in work px."""
    if len(pts) < 2:
        return
    path = Path2(pts)
    s = -phase
    k = 0
    guard = 0
    while s < path.length and guard < 2_000_000:
        guard += 1
        kind, v = pattern[k % len(pattern)]
        if kind == "d":
            seg = path.sub(s, s + v)
            if len(seg) >= 2:
                draw.line(seg, fill=fill, width=max(1, int(round(width))), joint="curve")
            s += v
        elif kind == "g":
            s += v
        else:
            if s >= 0:
                x, y, _ = path.at(s)
                draw.ellipse([x - v, y - v, x + v, y + v], fill=fill)
        k += 1


def draw_ticks(draw, pts, spacing, half_len, width, fill=255):
    path = Path2(pts)
    s = spacing / 2
    while s < path.length:
        x, y, a = path.at(s)
        nx, ny = -math.sin(a), math.cos(a)
        draw.line([(x - nx * half_len, y - ny * half_len), (x + nx * half_len, y + ny * half_len)],
                  fill=fill, width=max(1, int(round(width))))
        s += spacing


def offset_path(pts, d):
    """Offset a polyline sideways by d (positive = to the left of travel in image coords... i.e. normal)."""
    out = []
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[max(0, i - 1)]
        x1, y1 = pts[min(n - 1, i + 1)]
        a = math.atan2(y1 - y0, x1 - x0)
        out.append((pts[i][0] - math.sin(a) * d, pts[i][1] + math.cos(a) * d))
    return out


# ----------------------------------------------------------------------------- data
class Geo:
    pass


def load_geo() -> Geo:
    g = Geo()
    log("loading Natural Earth")
    g.land = geodata.ne("ne_10m_land")
    g.minor = geodata.ne("ne_10m_minor_islands")
    g.coast = geodata.ne("ne_10m_coastline")
    lakes = geodata.ne("ne_10m_lakes") + geodata.ne("ne_10m_lakes_north_america")
    keep_res = {"Lac Saint-Jean", "Lake Abitibi", "Lac Seul", "Lake of the Woods", "Lake St. Joseph",
                "Lake Nipigon", "Rainy Lake", "Lake Winnipeg"}
    g.lakes = [f for f in lakes if (f["props"].get("featurecla") in ("Lake", "Alkaline Lake")
                                    or f["props"].get("name") in keep_res)]
    g.rivers = geodata.ne("ne_10m_rivers_lake_centerlines")
    g.rivers_na = geodata.ne("ne_10m_rivers_north_america")
    g.admin1 = [f for f in geodata.ne("ne_10m_admin_1_states_provinces_lakes")
                if f["props"].get("adm0_a3") in ("USA", "CAN")]
    g.countries = geodata.ne("ne_10m_admin_0_countries")
    g.adm1_lines = [f for f in geodata.ne("ne_10m_admin_1_states_provinces_lines")
                    if f["props"].get("ADM0_A3") in ("USA", "CAN", "MEX")]
    g.intl = geodata.ne("ne_10m_admin_0_boundary_lines_land")
    return g


def fill_polys(draw, ctx, feats, fill, holes=0, min_px=0.0):
    for f in feats:
        for poly in f["polys"]:
            outer = ctx.ring(poly[0])
            if len(outer) < 3:
                continue
            if min_px > 0:
                xs = [p[0] for p in outer]; ys = [p[1] for p in outer]
                if max(xs) - min(xs) < min_px and max(ys) - min(ys) < min_px:
                    continue
            draw.polygon(outer, fill=fill)
            if holes is not None:
                for h in poly[1:]:
                    hr = ctx.ring(h)
                    if len(hr) >= 3:
                        draw.polygon(hr, fill=holes)


# ----------------------------------------------------------------------------- tints
def adjacency(ids: np.ndarray, n: int):
    adj = [set() for _ in range(n)]
    for a, b in ((ids[:, :-1], ids[:, 1:]), (ids[:-1, :], ids[1:, :])):
        m = (a != b) & (a > 1) & (b > 1)
        pairs = np.unique(np.stack([a[m], b[m]], axis=1), axis=0)
        for x, y in pairs.tolist():
            adj[x].add(y); adj[y].add(x)
    return adj


def colour_regions(regions, adj):
    """DSATUR graph colouring with balanced colour use. Returns {region_index: colour_index}."""
    col = {}
    counts = [0] * 5
    todo = [r["id"] for r in regions if r["kind"] in ("us", "ca")]
    while todo:
        def key(i):
            sat = len({col[j] for j in adj[i] if j in col})
            return (sat, len(adj[i]), -i)
        i = max(todo, key=key)
        used = {col[j] for j in adj[i] if j in col}
        free = [c for c in range(5) if c not in used] or list(range(5))
        c = min(free, key=lambda c: (counts[c], c))
        col[i] = c
        counts[c] += 1
        todo.remove(i)
    return col


# ----------------------------------------------------------------------------- lettering
class Lettering:
    def __init__(self, ctx: Ctx):
        self.ctx = ctx
        self.masks = {"ink": ctx.mask(), "water": ctx.mask(), "relief": ctx.mask(), "outline": ctx.mask()}
        self.symbols = ctx.mask()          # place symbols (ink)
        self.strip = ctx.mask()            # the band under each name where engraved lines are left open
        self.ii = None                     # integral image of "land" (plate px) for side-of-shore tests
        self.rects = []                    # occupied boxes, plate px: (x0, y0, x1, y1)
        self.fonts = {}
        self.files = {
            "sc": str(FONT_DIR / "IMFeENsc28P.ttf"),
            "it": str(FONT_DIR / "IMFeENit28P.ttf"),
            "rm": str(FONT_DIR / "IMFeENrm28P.ttf"),
            "dp": str(FONT_DIR / "IMFeDPsc28P.ttf"),
            "deco": str(FONT_DIR / "Limelight-Regular.ttf"),
        }

    def set_land(self, landish: np.ndarray):
        """landish: bool work-res array (True = land, big lakes and sea False)."""
        step = max(1, int(round(self.ctx.U)))
        a = landish[::step, ::step].astype(np.float64)
        self.ii_scale = self.ctx.U / step
        ii = np.zeros((a.shape[0] + 1, a.shape[1] + 1))
        ii[1:, 1:] = a.cumsum(0).cumsum(1)
        self.ii = ii

    def landfrac(self, box):
        """Fraction of land inside a plate-px box."""
        if self.ii is None:
            return 0.5
        h, w = self.ii.shape[0] - 1, self.ii.shape[1] - 1
        f = self.ii_scale
        x0 = int(min(max(box[0] * f, 0), w)); x1 = int(min(max(box[2] * f, 0), w))
        y0 = int(min(max(box[1] * f, 0), h)); y1 = int(min(max(box[3] * f, 0), h))
        if x1 <= x0 or y1 <= y0:
            return 0.0
        ii = self.ii
        return float(ii[y1, x1] - ii[y0, x1] - ii[y1, x0] + ii[y0, x0]) / ((x1 - x0) * (y1 - y0))

    def side_ok(self, boxes, side, tol=0.06):
        """side: 'land' / 'water' / 'one' (all on the same side of the shore) / None."""
        if side is None or not boxes:
            return True
        fr = [self.landfrac(b) for b in boxes]
        if side == "land":
            return min(fr) >= 1 - tol
        if side == "water":
            return max(fr) <= tol
        return min(fr) >= 1 - tol or max(fr) <= tol

    def add_strip(self, glyphs, font):
        """Open the engraved lines under a name: a band along the glyph centres."""
        if not glyphs:
            return
        cap_h = -font.getbbox("H", anchor="ls")[1]
        d = ImageDraw.Draw(self.strip)
        pts = [(x, y) for _, _, x, y, _ in glyphs]
        w = max(2, int(round(cap_h * 1.45)))
        if len(pts) == 1:
            x, y = pts[0]
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)
        else:
            # extend half a glyph past both ends
            (x0, y0), (x1, y1) = pts[0], pts[1]
            (x2, y2), (x3, y3) = pts[-2], pts[-1]
            a0 = math.atan2(y1 - y0, x1 - x0); a1 = math.atan2(y3 - y2, x3 - x2)
            e = cap_h * 0.55
            pts = [(x0 - math.cos(a0) * e, y0 - math.sin(a0) * e)] + pts + [(x3 + math.cos(a1) * e, y3 + math.sin(a1) * e)]
            d.line(pts, fill=255, width=w, joint="curve")
            r = w / 2
            for (x, y) in (pts[0], pts[-1]):
                d.ellipse([x - r, y - r, x + r, y + r], fill=255)

    def font(self, key, size_plate):
        px = max(6, int(round(size_plate * self.ctx.U)))
        k = (key, px)
        if k not in self.fonts:
            self.fonts[k] = ImageFont.truetype(self.files[key], px)
        return self.fonts[k]

    def measure(self, text, font, tracking_w):
        advs = [font.getlength(ch) for ch in text]
        return advs, sum(advs) + tracking_w * max(0, len(text) - 1)

    def layout(self, text, font, pts, tracking_w, align=0.5):
        """Glyph centres and angles along a work-space polyline, centred (align=0.5) on its length."""
        if pts[-1][0] < pts[0][0]:
            pts = pts[::-1]
        path = Path2(pts)
        advs, total = self.measure(text, font, tracking_w)
        s = (path.length - total) * align
        out = []
        for ch, a in zip(text, advs):
            if ch != " ":
                x, y, ang = path.at_ext(s + a / 2)
                out.append((ch, a, x, y, ang))
            s += a + tracking_w
        return out

    def boxes(self, glyphs, font):
        U = self.ctx.U
        cap_h = -font.getbbox("H", anchor="ls")[1]
        out = []
        for ch, a, x, y, ang in glyphs:
            hw = max(a, cap_h) * 0.55 / U
            out.append((x / U - hw, y / U - hw, x / U + hw, y / U + hw))
        return out

    def collides(self, boxes, pad=0.0):
        if not self.rects or not boxes:
            return 0
        r = np.asarray(self.rects)
        n = 0
        for (x0, y0, x1, y1) in boxes:
            n += int(np.any((x0 - pad < r[:, 2]) & (x1 + pad > r[:, 0]) & (y0 - pad < r[:, 3]) & (y1 + pad > r[:, 1])))
        return n

    def draw_glyphs(self, glyphs, font, target, record=True, outline=0, strip=False):
        asc, desc = font.getmetrics()
        cap_h = -font.getbbox("H", anchor="ls")[1]
        size = int(max(max((q[1] for q in glyphs), default=1), asc + desc) * 2.2) + 8
        for ch, a, x, y, ang in glyphs:
            im = Image.new("L", (size, size), 0)
            gd = ImageDraw.Draw(im)
            org = (size / 2, size / 2 + cap_h / 2)
            if outline > 0:
                sw = max(1, int(round(outline)))
                gd.text(org, ch, font=font, fill=255, anchor="ms", stroke_width=sw, stroke_fill=255)
                gd.text(org, ch, font=font, fill=0, anchor="ms")
            else:
                gd.text(org, ch, font=font, fill=255, anchor="ms")
            im = im.rotate(-math.degrees(ang), resample=Image.BICUBIC, center=(size / 2, size / 2))
            ox, oy = int(round(x - size / 2)), int(round(y - size / 2))
            region = (ox, oy, ox + size, oy + size)
            cur = target.crop(region)
            target.paste(ImageChops.lighter(cur, im), region)
        if record:
            self.rects.extend(self.boxes(glyphs, font))
        if strip:
            self.add_strip(glyphs, font)

    def on_path(self, text, font, pts, tracking_w, target, align=0.5, record=True, outline=0, strip=False):
        """Draw text glyph by glyph along a work-space polyline. outline > 0: open (hollow) capitals."""
        glyphs = self.layout(text, font, pts, tracking_w, align)
        self.draw_glyphs(glyphs, font, target, record, outline, strip)
        return glyphs

    def straight(self, text, font, cx, cy, ang, tracking_w, target, record=True, outline=0, strip=False):
        _, total = self.measure(text, font, tracking_w)
        L = total / 2 + 10
        pts = [(cx - math.cos(ang) * L, cy - math.sin(ang) * L), (cx + math.cos(ang) * L, cy + math.sin(ang) * L)]
        self.on_path(text, font, pts, tracking_w, target, record=record, outline=outline, strip=strip)

    def free(self, box, pad=0.0):
        x0, y0, x1, y1 = box
        for (a0, b0, a1, b1) in self.rects:
            if x0 - pad < a1 and x1 + pad > a0 and y0 - pad < b1 and y1 + pad > b0:
                return False
        return True


def parallel_angle(ctx, lat, lon):
    x0, y0 = ctx.P(lat, lon - 0.05)
    x1, y1 = ctx.P(lat, lon + 0.05)
    return math.atan2(float(y1 - y0), float(x1 - x0))


# which side of the shore a minor name must keep to while it is nudged for room
SIDE = {"cape": "water", "bay": "water", "lake_s": None, "river": "land", "mount": "land", "region": "land",
        "island": None, "note": None}
MAJOR = {"country", "country2", "state", "state_m", "state_s", "prov", "foreign", "ocean", "sea", "lake"}


def label_path(ctx, L, text, font, tw, lat, lon, opt):
    if "path" in opt:
        pts = [ctx.P(a, b) for a, b in opt["path"]]
        return mp.catmull_rom([(float(x), float(y)) for x, y in pts], 16)
    if "rot" in opt:
        cx, cy = (float(v) for v in ctx.P(lat, lon))
        ang = parallel_angle(ctx, lat, lon) + math.radians(opt["rot"])
        _, total = L.measure(text, font, tw)
        h = total / 2 + 10
        return [(cx - math.cos(ang) * h, cy - math.sin(ang) * h), (cx + math.cos(ang) * h, cy + math.sin(ang) * h)]
    _, total = L.measure(text, font, tw)
    ppd = mp.SCALE * mp.scale_factor(lat) * math.cos(math.radians(lat)) * math.pi / 180 * ctx.U
    span = (total / 2) / ppd * 1.25 + 0.3
    lons = np.linspace(lon - span, lon + span, 161)
    x, y = ctx.P(np.full_like(lons, lat), lons)
    return list(zip(x.tolist(), y.tolist()))


def place_labels(ctx: Ctx, L: Lettering):
    """Major names go exactly where the table says (and are reported if they crowd a live game city);
    minor ones (rivers, capes, bays, islands, relief) are nudged a little to find room, or left out."""
    reserved = len(L.rects)
    nudges = [(0, 0), (0, -9), (0, 9), (-14, 0), (14, 0), (0, -17), (0, 17), (-24, -6), (24, 6), (-24, 6), (24, -6),
              (-34, 0), (34, 0), (0, -26), (0, 26), (-34, -16), (34, 16), (-34, 16), (34, -16), (-48, 0), (48, 0),
              (0, -36), (0, 36)]
    skipped = []
    for kind, text, lat, lon, opt in LABELS:
        if opt.get("skip"):
            continue
        fkey, size, trk, color, _ = STYLES[kind]
        size = opt.get("size", size)
        trk = opt.get("tracking", trk)
        font = L.font(fkey, size)
        tw = trk * size * ctx.U
        outlined = kind in OUTLINED
        target = L.masks["outline" if outlined else color]
        pts = label_path(ctx, L, text, font, tw, lat, lon, opt)
        glyphs = L.layout(text, font, pts, tw)
        if outlined:
            L.draw_glyphs(glyphs, font, target, record=False, outline=OUTLINED[kind] * ctx.U)
            continue
        if kind in MAJOR:
            bx = L.boxes(glyphs, font)
            saved = L.rects
            L.rects = saved[:reserved]
            if L.collides(bx):
                log(f"  note: '{text}' sits on a live game place's label zone")
            L.rects = saved
            L.draw_glyphs(glyphs, font, target, strip=True)
            continue
        placed = False
        side = opt.get("side", SIDE.get(kind))
        for dx, dy in nudges:
            g2 = [(ch, a, x + dx * ctx.U, y + dy * ctx.U, ang) for ch, a, x, y, ang in glyphs]
            b2 = L.boxes(g2, font)
            if L.collides(b2, pad=1.0) == 0 and L.side_ok(b2, side):
                L.draw_glyphs(g2, font, target, strip=True)
                placed = True
                break
        if not placed:
            skipped.append(text)
    if skipped:
        log(f"  left out for lack of room: {', '.join(skipped)}")


def reserve_game_places(ctx, L: Lettering):
    """The game draws its cities and sources live: keep their dots and names clear of baked type."""
    for _, name, lat, lon in CITIES + SOURCES:
        x, y = mp.to_px(lat, lon)
        x, y = float(x), float(y)
        L.rects.append((x - 22, y - 22, x + 22, y + 22))
        L.rects.append((x + 10, y - 15, x + 14 + 11 * len(name), y + 15))


def place_places(ctx: Ctx, L: Lettering):
    draw = ImageDraw.Draw(L.symbols)
    placed = 0
    for lat, lon, name, kind in PLACES:
        if kind == "skip" or not name:
            continue
        x, y = mp.to_px(lat, lon)
        x, y = float(x), float(y)
        if not (90 < x < mp.IMAGE_W - 90 and 90 < y < mp.IMAGE_H - 90):
            continue
        size = 17 if kind == "town" else 16
        fkey = "rm" if kind == "town" else "sc"
        if kind == "national":
            size, fkey = 19, "sc"
        font = L.font(fkey, size)
        tw = (0.03 if kind == "town" else 0.08) * size * ctx.U
        _, total = L.measure(name, font, tw)
        tl = total / ctx.U
        th = size * 0.72
        r = 3.6 if kind != "town" else 3.0
        cands = [(r + 4, 0, "l"), (-(r + 4), 0, "r"), (r + 3, -th * 0.75, "l"), (-(r + 3), -th * 0.75, "r"),
                 (r + 3, th * 0.75, "l"), (-(r + 3), th * 0.75, "r"), (0, -(th * 0.9 + r), "c"),
                 (0, th * 0.9 + r, "c")]
        sym_box = (x - r - 2, y - r - 2, x + r + 2, y + r + 2)
        if not L.free(sym_box):
            continue
        chosen = None
        for dx, dy, al in cands:
            if al == "l":
                box = (x + dx, y + dy - th / 2, x + dx + tl, y + dy + th / 2)
            elif al == "r":
                box = (x + dx - tl, y + dy - th / 2, x + dx, y + dy + th / 2)
            else:
                box = (x - tl / 2, y + dy - th / 2, x + tl / 2, y + dy + th / 2)
            if box[0] < 90 or box[2] > mp.IMAGE_W - 90 or box[1] < 90 or box[3] > mp.IMAGE_H - 90:
                continue
            if L.free(box, pad=2) and L.side_ok([(box[0] - 1, box[1], box[2] + 1, box[3])], "one", 0.09):
                chosen = box
                break
        if chosen is None:
            continue
        # symbol
        U = ctx.U
        cx, cy = x * U - 0.5, y * U - 0.5
        rr = r * U
        lw = max(1, int(round(1.1 * U)))
        if kind == "national":
            draw.ellipse([cx - rr * 1.25, cy - rr * 1.25, cx + rr * 1.25, cy + rr * 1.25], outline=255, width=lw)
            star(draw, cx, cy, rr * 0.95, rr * 0.4, 5, 255)
        elif kind == "capital":
            draw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=255, width=lw)
            draw.ellipse([cx - rr * 0.45, cy - rr * 0.45, cx + rr * 0.45, cy + rr * 0.45], fill=255)
        else:
            draw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=255, width=lw)
        ymid = (chosen[1] + chosen[3]) / 2
        L.straight(name, font, (chosen[0] + chosen[2]) / 2 * U, ymid * U, 0.0, tw, L.masks["ink"], record=False,
                   strip=True)
        L.rects.append(chosen)
        L.rects.append(sym_box)
        placed += 1
    log(f"placed {placed} place names")


def star(draw, cx, cy, r_out, r_in, points, fill, rot=-math.pi / 2):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * math.pi / points
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    draw.polygon(pts, fill=fill)


# ----------------------------------------------------------------------------- relief
def build_relief(ctx: Ctx, land_small: np.ndarray, sample):
    """Elevation on a half-plate grid (plate px * 0.5) via the inverse projection."""
    h, w = land_small.shape
    gx, gy = np.meshgrid((np.arange(w) + 0.5) * (mp.IMAGE_W / w), (np.arange(h) + 0.5) * (mp.IMAGE_H / h))
    lat, lon = mp.from_px(gx, gy)
    return sample(lat, lon).astype(np.float32)


def hachures(ctx: Ctx, elev: np.ndarray, land_small: np.ndarray, rng) -> Image.Image:
    """Engraved hachures: short strokes down the fall line, heavier on steeper and shadowed slopes."""
    h, w = elev.shape
    cell_km = (mp.IMAGE_W / w) / mp.px_per_mile() * 1.609
    e = np.maximum(elev, 0.0)
    # water cells take the elevation of the surrounding land, so shores do not read as slopes
    wgt = land_small.astype(np.float32)
    fill = raster.blur_f(e * wgt, 4.0) / np.maximum(raster.blur_f(wgt, 4.0), 1e-3)
    e = np.where(land_small, e, fill)
    e = raster.blur_f(e, 0.9)
    gy, gx = np.gradient(e)
    gx /= cell_km; gy /= cell_km                # metres per km
    slope = np.hypot(gx, gy)
    m = ctx.mask()
    d = ImageDraw.Draw(m)
    step = 4.6                                   # plate px between strokes
    sx = w / mp.IMAGE_W
    ys = np.arange(90, mp.IMAGE_H - 90, step)
    xs = np.arange(90, mp.IMAGE_W - 90, step)
    U = ctx.U
    light = np.array([-0.7071, -0.7071])        # light from the north-west
    for yy in ys:
        jy = rng.uniform(-1.4, 1.4, len(xs))
        jx = rng.uniform(-1.4, 1.4, len(xs))
        for x, dx, dy in zip(xs, jx, jy):
            px, py = x + dx, yy + dy
            ix, iy = int(px * sx), int(py * sx)
            if ix < 1 or iy < 1 or ix >= w - 1 or iy >= h - 1 or not land_small[iy, ix]:
                continue
            s = slope[iy, ix]
            if s < 6.0:
                continue
            strength = min(1.0, (s - 6.0) / 24.0)
            if strength < 0.08:
                continue
            ux, uy = -gx[iy, ix] / s, -gy[iy, ix] / s       # downhill
            shade = 0.55 + 0.45 * max(0.0, -(ux * light[0] + uy * light[1]))  # slopes facing away from light
            length = (3.0 + 4.6 * strength) * U
            width = max(1, int(round((0.7 + 1.2 * strength * shade) * U)))
            val = int(255 * min(1.0, 0.45 + 0.6 * strength * shade))
            cx, cy = px * U, py * U
            d.line([(cx - ux * length * 0.35, cy - uy * length * 0.35), (cx + ux * length * 0.65, cy + uy * length * 0.65)],
                   fill=val, width=width)
    return m


# ----------------------------------------------------------------------------- rivers along a route
def river_graph(feats, name_set):
    nodes = {}
    coords = []
    edges = {}

    def nid(lon, lat):
        k = (round(lon, 3), round(lat, 3))
        if k not in nodes:
            nodes[k] = len(coords)
            coords.append((lat, lon))
            edges[nodes[k]] = []
        return nodes[k]

    for f in feats:
        if str(f["props"].get("name")) not in name_set:
            continue
        for poly in f["polys"]:
            for ring in poly:
                prev = None
                for lon, lat in ring.tolist():
                    i = nid(lon, lat)
                    if prev is not None and prev != i:
                        edges[prev].append(i); edges[i].append(prev)
                    prev = i
    return coords, edges


def river_path(coords, edges, a, b):
    import heapq
    arr = np.asarray(coords)
    def nearest(p):
        d = (arr[:, 0] - p[0]) ** 2 + ((arr[:, 1] - p[1]) * math.cos(math.radians(p[0]))) ** 2
        return int(np.argmin(d))
    s, t = nearest(a), nearest(b)
    dist = {s: 0.0}; prev = {}
    pq = [(0.0, s)]
    while pq:
        dd, u = heapq.heappop(pq)
        if u == t:
            break
        if dd > dist.get(u, 1e18):
            continue
        for v in edges[u]:
            la0, lo0 = coords[u]; la1, lo1 = coords[v]
            nd = dd + math.hypot(la1 - la0, (lo1 - lo0) * math.cos(math.radians(la0)))
            if nd < dist.get(v, 1e18):
                dist[v] = nd; prev[v] = u
                heapq.heappush(pq, (nd, v))
    if t not in dist:
        return [a, b]
    out = [t]
    while out[-1] != s:
        out.append(prev[out[-1]])
    out.reverse()
    return [tuple(coords[i]) for i in out]


def resolve_route(wps, rivers):
    out = []
    graphs = {}
    i = 0
    while i < len(wps):
        w = wps[i]
        if isinstance(w, str) and w.startswith("river:"):
            name = w.split(":", 1)[1]
            if name not in graphs:
                graphs[name] = river_graph(rivers, {name})
            coords, edges = graphs[name]
            a, b = out[-1], wps[i + 1]
            seg = river_path(coords, edges, a, b)
            out.extend(seg[1:-1])
        else:
            out.append(tuple(w))
        i += 1
    return out


def thin_latlon(pts, tol_px=1.5):
    """Douglas-Peucker in plate pixels, keeps lat/lon output."""
    if len(pts) < 3:
        return pts
    xy = [tuple(map(float, mp.to_px(a, b))) for a, b in pts]
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        i, j = stack.pop()
        (x0, y0), (x1, y1) = xy[i], xy[j]
        L = math.hypot(x1 - x0, y1 - y0) or 1e-9
        best, bi = -1.0, -1
        for k in range(i + 1, j):
            d = abs((x1 - x0) * (y0 - xy[k][1]) - (x0 - xy[k][0]) * (y1 - y0)) / L
            if d > best:
                best, bi = d, k
        if best > tol_px:
            keep[bi] = True
            stack.append((i, bi)); stack.append((bi, j))
    return [p for p, k in zip(pts, keep) if k]


# ----------------------------------------------------------------------------- decorations
def text_center(draw_mask, L: Lettering, text, fkey, size, cx, cy, tracking=0.0, target=None):
    font = L.font(fkey, size)
    tw = tracking * size * L.ctx.U
    L.straight(text, font, cx * L.ctx.U, cy * L.ctx.U, 0.0, tw, target if target is not None else draw_mask,
               record=False)
    _, total = L.measure(text, font, tw)
    return total / L.ctx.U


def cartouche(ctx: Ctx, canvas: Canvas, L: Lettering, box):
    """Art-deco title cartouche; box in plate px (x0, y0, x1, y1)."""
    U = ctx.U
    x0, y0, x1, y1 = box
    cxm = (x0 + x1) / 2
    panel = ctx.mask()
    pd = ImageDraw.Draw(panel)
    fan_r = 150
    pd.rectangle([x0 * U, y0 * U, x1 * U, y1 * U], fill=255)
    pd.pieslice([(cxm - fan_r) * U, (y0 - fan_r * 0.62) * U, (cxm + fan_r) * U, (y0 + fan_r * 1.38) * U],
                180, 360, fill=255)
    canvas.clear(panel)
    # a faint cream wash inside
    wash = panel.point(lambda v: int(v * 0.35))
    canvas.ink(wash, (250, 238, 214))
    ink = ctx.mask()
    d = ImageDraw.Draw(ink)
    lw = lambda v: max(1, int(round(v * U)))
    # frame: heavy outer rule, hairline inside, stepped deco corners
    d.rectangle([x0 * U, y0 * U, x1 * U, y1 * U], outline=255, width=lw(4.5))
    g = 11
    d.rectangle([(x0 + g) * U, (y0 + g) * U, (x1 - g) * U, (y1 - g) * U], outline=255, width=lw(1.4))
    g2 = 17
    d.rectangle([(x0 + g2) * U, (y0 + g2) * U, (x1 - g2) * U, (y1 - g2) * U], outline=255, width=lw(1.0))
    for (sx, sy) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        dx = 1 if sx == x0 else -1
        dy = 1 if sy == y0 else -1
        for k, s in enumerate((34, 24, 14)):
            px0, py0 = sx + dx * (g2 + 2), sy + dy * (g2 + 2)
            px1, py1 = px0 + dx * s, py0 + dy * s
            d.rectangle([min(px0, px1) * U, min(py0, py1) * U, max(px0, px1) * U, max(py0, py1) * U],
                        outline=255, width=lw(1.0 if k else 1.6))
        # little diamond in the corner square
        cxd, cyd = sx + dx * (g2 + 9), sy + dy * (g2 + 9)
        d.polygon([(cxd * U, (cyd - 4) * U), ((cxd + 4) * U, cyd * U), (cxd * U, (cyd + 4) * U), ((cxd - 4) * U, cyd * U)],
                  fill=255)
    # sunburst fan on top
    fcx, fcy = cxm, y0 + 2
    d.arc([(fcx - fan_r) * U, (fcy - fan_r) * U, (fcx + fan_r) * U, (fcy + fan_r) * U], 180, 360, fill=255, width=lw(4.0))
    d.arc([(fcx - fan_r + 10) * U, (fcy - fan_r + 10) * U, (fcx + fan_r - 10) * U, (fcy + fan_r - 10) * U], 180, 360,
          fill=255, width=lw(1.2))
    for k in range(1, 18):
        a = math.pi + k * math.pi / 18
        r0, r1 = 34, fan_r - 16
        w_ = 2.2 if k % 2 == 0 else 1.0
        d.line([((fcx + math.cos(a) * r0) * U, (fcy + math.sin(a) * r0) * U),
                ((fcx + math.cos(a) * r1) * U, (fcy + math.sin(a) * r1) * U)], fill=255, width=lw(w_))
    d.pieslice([(fcx - 26) * U, (fcy - 26) * U, (fcx + 26) * U, (fcy + 26) * U], 180, 360, fill=255)
    # rules between lines of the title
    def rule(y, half, orn=True):
        d.line([((cxm - half) * U, y * U), ((cxm + half) * U, y * U)], fill=255, width=lw(1.2))
        if orn:
            d.polygon([((cxm) * U, (y - 5) * U), ((cxm + 7) * U, y * U), (cxm * U, (y + 5) * U), ((cxm - 7) * U, y * U)],
                      fill=255)
    ty = y0 + 70
    text_center(ink, L, "THE", "sc", 30, cxm, ty, 0.6)
    ty += 72
    text_center(ink, L, "LIQUOR TRAFFIC", "deco", 60, cxm, ty, 0.06)
    ty += 52
    text_center(ink, L, "of the", "it", 30, cxm, ty)
    ty += 56
    text_center(ink, L, "UNITED STATES & CANADA", "sc", 34, cxm, ty, 0.14)
    ty += 42
    rule(ty, (x1 - x0) / 2 - 70)
    ty += 44
    text_center(ink, L, "1920  —  1933", "deco", 40, cxm, ty, 0.2)
    ty += 48
    text_center(ink, L, "Shewing Rum Row & the Twelve-Mile Limit, the Mother-Ship Lanes,", "it", 22, cxm, ty)
    ty += 28
    text_center(ink, L, "the Principal Railroads, Rivers, Ports of Entry & Boundaries", "it", 22, cxm, ty)
    ty += 40
    rule(ty, 90, orn=False)
    ty += 30
    text_center(ink, L, "COMPILED  FROM  THE  LATEST  OFFICIAL  SURVEYS", "sc", 15, cxm, ty, 0.12)
    ty += 24
    text_center(ink, L, "Engraved for the Famiglia Atlas  ·  New York", "it", 17, cxm, ty)
    canvas.ink(ink, INK)


def compass_rose(ctx: Ctx, canvas: Canvas, L: Lettering, lat, lon, R):
    U = ctx.U
    x, y = mp.to_px(lat, lon)
    x, y = float(x), float(y)
    rot = math.radians(mp.convergence_deg(lon))  # true north here, clockwise from image up
    panel = ctx.mask()
    ImageDraw.Draw(panel).ellipse([(x - R - 26) * U, (y - R - 26) * U, (x + R + 26) * U, (y + R + 26) * U], fill=255)
    canvas.clear(panel.filter(ImageFilter.GaussianBlur(3 * U)))
    dark = ctx.mask()
    light = ctx.mask()
    dd = ImageDraw.Draw(dark)
    dl = ImageDraw.Draw(light)
    lw = lambda v: max(1, int(round(v * U)))
    P = lambda r, a: ((x + math.sin(a + rot) * r) * U, (y - math.cos(a + rot) * r) * U)
    # rings with degree ticks
    for rr, wv in ((R + 18, 1.2), (R + 6, 2.2), (R - 2, 0.9)):
        dd.ellipse([(x - rr) * U, (y - rr) * U, (x + rr) * U, (y + rr) * U], outline=255, width=lw(wv))
    for k in range(360 // 5):
        a = math.radians(k * 5)
        r0 = R + 6 if k % 2 else R + 1
        dd.line([P(r0, a), P(R + 18, a)], fill=255, width=lw(0.9 if k % 2 else 1.3))
    # 32/16/8 point star: long cardinal points, shorter intercardinals, fine by-points
    def point(a, r, wid, split=True):
        tip = P(r, a)
        l_ = P(wid, a - math.pi / 2)
        r_ = P(wid, a + math.pi / 2)
        c = P(0, 0)
        dd.polygon([c, l_, tip], fill=255)           # dark half
        dl.polygon([c, r_, tip], fill=255)           # light half: outline only
        dd.line([c, r_, tip, l_, c], fill=255, width=lw(1.1))
    for k in range(16):
        a = k * math.pi / 8
        if k % 4 == 0:
            continue
        r = R * (0.62 if k % 2 == 0 else 0.44)
        point(a, r, R * 0.07)
    for k in range(4):
        point(k * math.pi / 2, R, R * 0.13)
    dd.ellipse([(x - 6) * U, (y - 6) * U, (x + 6) * U, (y + 6) * U], fill=255)
    canvas.ink(light, (246, 236, 214))
    canvas.ink(dark, INK)
    # N / E / S / W
    lm = ctx.mask()
    for lab, a in (("N", 0.0), ("E", math.pi / 2), ("S", math.pi), ("W", -math.pi / 2)):
        px, py = P(R + 38, a)
        font = L.font("sc", 30 if lab == "N" else 22)
        L.straight(lab, font, px, py, rot, 0, lm, record=False)
    canvas.ink(lm, INK)
    return (x - R - 40, y - R - 40, x + R + 40, y + R + 40)


def scale_bar(ctx: Ctx, canvas: Canvas, L: Lettering, x0, y0):
    U = ctx.U
    ppm = mp.px_per_mile(39.0)
    miles = 400
    length = miles * ppm
    ink = ctx.mask()
    d = ImageDraw.Draw(ink)
    lw = lambda v: max(1, int(round(v * U)))
    h = 9
    # fine divisions for the first 100 miles, then 100-mile blocks
    d.rectangle([x0 * U, y0 * U, (x0 + length) * U, (y0 + h) * U], outline=255, width=lw(1.4))
    for k in range(4):
        if k % 2 == 0:
            a = x0 + k * 100 * ppm
            d.rectangle([a * U, y0 * U, (a + 100 * ppm) * U, (y0 + h) * U], fill=255)
    for k in range(0, 10):
        a = x0 - 100 * ppm + k * 10 * ppm
        if k % 2 == 0:
            d.rectangle([a * U, y0 * U, (a + 10 * ppm) * U, (y0 + h / 2) * U], fill=255)
    d.rectangle([(x0 - 100 * ppm) * U, y0 * U, x0 * U, (y0 + h) * U], outline=255, width=lw(1.2))
    tm = ctx.mask()
    for m_, lab in ((-100, "100"), (0, "0"), (100, "100"), (200, "200"), (300, "300"), (400, "400")):
        a = x0 + m_ * ppm
        d.line([(a * U, (y0 - 5) * U), (a * U, (y0 + h) * U)], fill=255, width=lw(1.2))
        text_center(tm, L, lab, "rm", 17, a, y0 - 14, 0.0, target=tm)
    text_center(tm, L, "SCALE  OF  STATUTE  MILES", "sc", 17, x0 + length / 2 - 50 * ppm, y0 + h + 24, 0.25, target=tm)
    text_center(tm, L, "True at the 39th parallel  ·  1 inch to 100 miles on this plate (approx.)", "it", 14,
                x0 + length / 2 - 50 * ppm, y0 + h + 46, 0.0, target=tm)
    canvas.ink(ink, INK)
    canvas.ink(tm, INK)


def legend(ctx: Ctx, canvas: Canvas, L: Lettering, box):
    U = ctx.U
    x0, y0, x1, y1 = box
    panel = ctx.mask()
    ImageDraw.Draw(panel).rectangle([x0 * U, y0 * U, x1 * U, y1 * U], fill=255)
    canvas.clear(panel)
    canvas.ink(panel.point(lambda v: int(v * 0.3)), (250, 238, 214))
    ink = ctx.mask(); red = ctx.mask(); blue = ctx.mask(); rib = ctx.mask(); tm = ctx.mask()
    d = ImageDraw.Draw(ink); dr = ImageDraw.Draw(red); db = ImageDraw.Draw(blue); dri = ImageDraw.Draw(rib)
    lw = lambda v: max(1, int(round(v * U)))
    d.rectangle([x0 * U, y0 * U, x1 * U, y1 * U], outline=255, width=lw(3))
    d.rectangle([(x0 + 7) * U, (y0 + 7) * U, (x1 - 7) * U, (y1 - 7) * U], outline=255, width=lw(1))
    text_center(tm, L, "REFERENCES", "sc", 26, (x0 + x1) / 2, y0 + 42, 0.35, target=tm)
    d.line([((x0 + 110) * U, (y0 + 58) * U), ((x1 - 110) * U, (y0 + 58) * U)], fill=255, width=lw(1))
    rows = [
        ("International Boundary", "intl"), ("State & Provincial Boundaries", "state"),
        ("Railroads (freight lines)", "rail"), ("Rivers & Lakes", "river"),
        ("Twelve-Mile Limit (Treaty of 1924)", "limit"), ("Mother-Ship Lanes to Rum Row", "lane"),
        ("100-Fathom Line", "fathom"), ("National Capitals", "national"), ("State & Provincial Capitals", "capital"),
        ("Other Towns", "town"),
    ]
    y = y0 + 90
    sx0, sx1 = x0 + 30, x0 + 130
    for label, kind in rows:
        pts = [(sx0 * U, y * U), (sx1 * U, y * U)]
        if kind == "intl":
            dri.line(pts, fill=255, width=lw(10))
            draw_pattern(d, pts, [("d", 12 * U), ("g", 4 * U), ("o", 1.4 * U), ("g", 4 * U)], 2.2 * U)
        elif kind == "state":
            draw_pattern(d, pts, [("o", 1.0 * U), ("g", 5 * U)], 1)
        elif kind == "rail":
            d.line(pts, fill=255, width=lw(1.5))
            draw_ticks(d, pts, 7 * U, 3 * U, 1.1 * U)
        elif kind == "river":
            db.line([(sx0 * U, (y + 3) * U), ((sx0 + 30) * U, (y - 3) * U), ((sx0 + 60) * U, (y + 2) * U),
                     (sx1 * U, (y - 2) * U)], fill=255, width=lw(1.6), joint="curve")
        elif kind == "limit":
            draw_pattern(dr, pts, [("d", 9 * U), ("g", 5 * U)], 1.6 * U)
        elif kind == "lane":
            draw_pattern(dr, pts, [("o", 1.3 * U), ("g", 5.5 * U)], 1)
        elif kind == "fathom":
            draw_pattern(db, pts, [("o", 0.9 * U), ("g", 3.5 * U)], 1)
        elif kind in ("national", "capital", "town"):
            cx, cy, rr = (sx0 + sx1) / 2 * U, y * U, 3.4 * U
            if kind == "national":
                d.ellipse([cx - rr * 1.25, cy - rr * 1.25, cx + rr * 1.25, cy + rr * 1.25], outline=255, width=lw(1.1))
                star(d, cx, cy, rr * 0.95, rr * 0.4, 5, 255)
            elif kind == "capital":
                d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=255, width=lw(1.1))
                d.ellipse([cx - rr * 0.45, cy - rr * 0.45, cx + rr * 0.45, cy + rr * 0.45], fill=255)
            else:
                d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=255, width=lw(1.1))
        font = L.font("rm", 19)
        _, total = L.measure(label, font, 0)
        L.straight(label, font, (sx1 + 20) * U + total / 2, y * U, 0.0, 0, tm, record=False)
        y += 33
    canvas.ink(rib, (226, 120, 100), 0.45)
    canvas.ink(blue, WATER_INK)
    canvas.ink(red, OXBLOOD)
    canvas.ink(ink, INK)
    canvas.ink(tm, INK)


def frame(ctx: Ctx, canvas: Canvas, L: Lettering):
    """Neat line, degree band with ticks and figures, heavy outer border."""
    U = ctx.U
    W, H = mp.IMAGE_W, mp.IMAGE_H
    inner = 78.0      # neat line inset (plate px)
    band = 52.0
    outer = inner - band
    # clear outside the neat line
    m = ctx.mask(255)
    ImageDraw.Draw(m).rectangle([inner * U, inner * U, (W - inner) * U, (H - inner) * U], fill=0)
    canvas.clear(m)
    ink = ctx.mask()
    d = ImageDraw.Draw(ink)
    lw = lambda v: max(1, int(round(v * U)))
    d.rectangle([inner * U, inner * U, (W - inner) * U, (H - inner) * U], outline=255, width=lw(2.2))
    d.rectangle([(inner - 11) * U, (inner - 11) * U, (W - inner + 11) * U, (H - inner + 11) * U], outline=255, width=lw(0.9))
    d.rectangle([outer * U, outer * U, (W - outer) * U, (H - outer) * U], outline=255, width=lw(4.5))
    d.rectangle([(outer - 7) * U, (outer - 7) * U, (W - outer + 7) * U, (H - outer + 7) * U], outline=255, width=lw(1.2))
    # corner ornaments
    for cx, cy in ((outer, outer), (W - outer, outer), (outer, H - outer), (W - outer, H - outer)):
        s = band - 4
        sgx = 1 if cx < W / 2 else -1
        sgy = 1 if cy < H / 2 else -1
        x0_, y0_ = cx, cy
        x1_, y1_ = cx + sgx * (s - 1), cy + sgy * (s - 1)
        d.rectangle([min(x0_, x1_) * U, min(y0_, y1_) * U, max(x0_, x1_) * U, max(y0_, y1_) * U], fill=255)
        mx, my = (x0_ + x1_) / 2, (y0_ + y1_) / 2
        star(d, mx * U, my * U, 13 * U, 5 * U, 4, 0, rot=0)
    # graticule crossings with the neat line: ticks every degree, figures every five
    tm = ctx.mask()
    edges = [("top", inner), ("bottom", H - inner), ("left", inner), ("right", W - inner)]

    def crossings(kind, val):
        pts = []
        if kind == "mer":
            lats = np.linspace(5, 62, 2000)
            x, y = mp.to_px(lats, np.full_like(lats, val))
        else:
            lons = np.linspace(-130, -20, 3000)
            x, y = mp.to_px(np.full_like(lons, val), lons)
        return np.asarray(x), np.asarray(y)

    for kind, rng_ in (("mer", range(-125, -19)), ("par", range(8, 60))):
        for v in rng_:
            x, y = crossings(kind, v)
            for ename, e in edges:
                arr = y if ename in ("top", "bottom") else x
                other = x if ename in ("top", "bottom") else y
                s = np.sign(arr - e)
                idx = np.nonzero(np.diff(s) != 0)[0]
                for i in idx:
                    t = (e - arr[i]) / (arr[i + 1] - arr[i])
                    o = other[i] + (other[i + 1] - other[i]) * t
                    lo, hi = inner, (W - inner if ename in ("top", "bottom") else H - inner)
                    if not (lo + 4 < o < hi - 4):
                        continue
                    major = v % 5 == 0
                    tl = 11 if major else 6
                    if ename == "top":
                        d.line([(o * U, (e - tl) * U), (o * U, e * U)], fill=255, width=lw(1.4 if major else 0.9))
                    elif ename == "bottom":
                        d.line([(o * U, e * U), (o * U, (e + tl) * U)], fill=255, width=lw(1.4 if major else 0.9))
                    elif ename == "left":
                        d.line([((e - tl) * U, o * U), (e * U, o * U)], fill=255, width=lw(1.4 if major else 0.9))
                    else:
                        d.line([(e * U, o * U), ((e + tl) * U, o * U)], fill=255, width=lw(1.4 if major else 0.9))
                    if major and (kind == "mer") == (ename in ("top", "bottom")):
                        lab = f"{abs(v)}°"
                        if ename == "top":
                            text_center(tm, L, lab, "rm", 20, o, e - 27, target=tm)
                        elif ename == "bottom":
                            text_center(tm, L, lab, "rm", 20, o, e + 29, target=tm)
                        elif ename == "left":
                            text_center(tm, L, lab, "rm", 20, e - 29, o + 1, target=tm)
                        else:
                            text_center(tm, L, lab, "rm", 20, e + 29, o + 1, target=tm)
    # imprint lines below the frame
    text_center(tm, L, "Longitude West from Greenwich", "it", 18, W * 0.30, H - outer + 18, target=tm)
    text_center(tm, L, "Lambert Conformal Conic Projection  ·  Standard Parallels 33° and 45°",
                "it", 18, W * 0.70, H - outer + 18, target=tm)
    text_center(tm, L, "PLATE  VII", "sc", 18, W - 200, outer - 12, 0.3, target=tm)
    text_center(tm, L, "THE  FAMIGLIA  ATLAS", "sc", 18, 230, outer - 12, 0.3, target=tm)
    canvas.ink(ink, INK)
    canvas.ink(tm, INK)


# ----------------------------------------------------------------------------- paper
def make_paper(w, h, rng) -> np.ndarray:
    """Aged paper, float RGB 0..1 at final size."""
    base = np.array(PAPER, np.float32) / 255.0
    mot = raster.fbm(w, h, 5, 6, rng)                      # -0.5..0.5 broad mottling
    tone = raster.fbm(w, h, 3, 3, rng)
    grain = rng.normal(0.0, 1.0, (h, w)).astype(np.float32)
    grain = np.asarray(Image.fromarray(np.clip(grain * 40 + 128, 0, 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(0.6)), dtype=np.float32) / 255.0 - 0.5
    # fibres
    fib = Image.new("L", (w, h), 0)
    fd = ImageDraw.Draw(fib)
    n_f = int(w * h / 900)
    for _ in range(n_f):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        a = rng.uniform(0, math.pi)
        L = rng.uniform(6, 42) * (w / 3600) ** 0.5
        curv = rng.uniform(-0.08, 0.08)
        pts = []
        for k in range(6):
            t = k / 5
            aa = a + curv * t * 6
            pts.append((x + math.cos(aa) * L * t, y + math.sin(aa) * L * t))
        fd.line(pts, fill=int(rng.uniform(60, 200)), width=1)
    fib = np.asarray(fib.filter(ImageFilter.GaussianBlur(0.55)), dtype=np.float32) / 255.0
    fib2 = Image.new("L", (w, h), 0)
    fd = ImageDraw.Draw(fib2)
    for _ in range(n_f // 3):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        a = rng.uniform(0, math.pi)
        L = rng.uniform(8, 30) * (w / 3600) ** 0.5
        fd.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=int(rng.uniform(80, 220)), width=1)
    fib2 = np.asarray(fib2.filter(ImageFilter.GaussianBlur(0.5)), dtype=np.float32) / 255.0
    # edge toning
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    de = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)) / (0.09 * min(w, h))
    edge = np.clip(1.0 - de, 0, 1) ** 2.2
    edge *= 0.75 + 0.5 * (raster.value_noise(w, h, 18, rng))
    # foxing
    fox = np.zeros((h, w), np.float32)
    n_spots = int(95 * (w * h) / (3600 * 2250)) + 10
    for _ in range(n_spots):
        if rng.random() < 0.6:   # near an edge
            side = rng.integers(4)
            t = rng.uniform(0, 1)
            dpt = abs(rng.normal(0, 0.07))
            x = t * w if side < 2 else (dpt * w if side == 2 else (1 - dpt) * w)
            y = (dpt * h if side == 0 else (1 - dpt) * h) if side < 2 else t * h
        else:
            x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(2, 26) * (w / 3600)
        x0, x1 = int(max(0, x - r * 3)), int(min(w, x + r * 3))
        y0, y1 = int(max(0, y - r * 3)), int(min(h, y + r * 3))
        if x1 <= x0 or y1 <= y0:
            continue
        sy, sx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        dist = np.hypot(sx - x, sy - y) / r
        wob = raster.value_noise(x1 - x0, y1 - y0, 5, rng) * 0.7
        v = np.clip(1.2 - dist - wob * 0.6, 0, 1)
        ring = np.exp(-((dist - 0.85) / 0.18) ** 2) * 0.5
        fox[y0:y1, x0:x1] += (v ** 1.5 * 0.55 + ring * (v > 0)) * rng.uniform(0.25, 0.9)
        # scattered satellites
        for _k in range(int(rng.integers(0, 6))):
            qx, qy = x + rng.normal(0, r * 2), y + rng.normal(0, r * 2)
            qr = rng.uniform(0.6, 2.2) * (w / 3600)
            qx0, qx1 = int(max(0, qx - qr * 2)), int(min(w, qx + qr * 2 + 1))
            qy0, qy1 = int(max(0, qy - qr * 2)), int(min(h, qy + qr * 2 + 1))
            if qx1 > qx0 and qy1 > qy0:
                gy_, gx_ = np.mgrid[qy0:qy1, qx0:qx1].astype(np.float32)
                fox[qy0:qy1, qx0:qx1] += np.clip(1.0 - np.hypot(gx_ - qx, gy_ - qy) / qr, 0, 1) * 0.6
    fox = np.clip(fox, 0, 1.2)
    # compose (multiplicative darkening, yellow-brown bias)
    paper = np.empty((h, w, 3), np.float32)
    ageing = np.array([0.02, 0.05, 0.13], np.float32)   # how much each channel darkens with age
    fox_col = np.array([0.20, 0.36, 0.58], np.float32)
    for c in range(3):
        v = base[c] * (1.0 + mot * 0.07 + grain * 0.035 + tone * 0.03)
        v *= 1.0 - edge * (0.10 + ageing[c] * 1.4)
        v *= 1.0 - (tone + 0.5) * ageing[c] * 0.35
        v *= 1.0 - fib * 0.075
        v += fib2 * 0.035
        v *= 1.0 - fox * fox_col[c] * 0.5
        paper[..., c] = v
    return np.clip(paper, 0, 1)


# ----------------------------------------------------------------------------- the plate
def build(args):
    ctx = Ctx(args.res, args.ss)
    rng = np.random.default_rng(1929)
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    for fam, fn in (("imfellenglishsc", "IMFeENsc28P.ttf"), ("imfellenglish", "IMFeENit28P.ttf"),
                    ("imfellenglish", "IMFeENrm28P.ttf"), ("imfelldoublepicasc", "IMFeDPsc28P.ttf"),
                    ("limelight", "Limelight-Regular.ttf")):
        geodata.font(fam, fn, FONT_DIR)
    geodata.font_licence("imfellenglishsc", FONT_DIR)
    geodata.font_licence("limelight", FONT_DIR, "OFL-Limelight.txt")
    g = load_geo()
    WW, WH = ctx.WW, ctx.WH
    log(f"work canvas {WW}x{WH} (U={ctx.U})")

    # ---- land, lakes, water
    land_img = ctx.mask()
    dl = ImageDraw.Draw(land_img)
    fill_polys(dl, ctx, g.land, 255, holes=0)
    fill_polys(dl, ctx, g.minor, 255, holes=None)
    lake_img = ctx.mask()
    fill_polys(ImageDraw.Draw(lake_img), ctx, g.lakes, 255, holes=0, min_px=2.0 * ctx.U)
    big_img = ctx.mask()
    fill_polys(ImageDraw.Draw(big_img), ctx, g.lakes, 255, holes=0, min_px=34.0 * ctx.U)
    land = np.asarray(land_img) > 127
    lakes = np.asarray(lake_img) > 127
    dry = land & ~lakes
    lined = (~land) | (np.asarray(big_img) > 127)     # sea and the big lakes get engraved water lines
    del big_img
    log("land/lakes rasterised")

    # ---- regions
    regions = []
    ids_img = Image.new("L", (WW, WH), 1)          # 1 = land with no region, 0 = water
    di = ImageDraw.Draw(ids_img)
    nid = 2
    for f in g.admin1:
        p = f["props"]
        kind = "us" if p["adm0_a3"] == "USA" else "ca"
        regions.append({"id": nid, "kind": kind, "name": p.get("name"), "code": p.get("postal") or p.get("iso_3166_2")})
        fill_polys(di, ctx, [f], nid, holes=None)
        nid += 1
    for f in g.countries:
        a3 = f["props"].get("ADM0_A3")
        if a3 in ("USA", "CAN"):
            continue
        regions.append({"id": nid, "kind": "foreign", "name": f["props"].get("NAME"), "code": a3})
        fill_polys(di, ctx, [f], nid, holes=None)
        nid += 1
        if nid > 250:
            break
    ids = np.asarray(ids_img).copy()
    ids[~land] = 0
    ids_land = ids.copy()          # small lakes keep their region: no colour band around them
    ids[~dry] = 0
    log(f"{len(regions)} regions rasterised")
    adj = adjacency(ids_land, nid)
    col = colour_regions(regions, adj)
    pal_light = np.zeros((256, 3), np.float32)
    pal_light[0] = WATER_TINT
    pal_light[1] = LAND_NEUTRAL
    for r in regions:
        if r["kind"] == "us":
            pal_light[r["id"]] = STATE_TINTS[col[r["id"]]]
        elif r["kind"] == "ca":
            if r["name"] and "Newfoundland" in r["name"]:
                pal_light[r["id"]] = NEWFOUNDLAND_TINT
            else:
                pal_light[r["id"]] = CANADA_TINTS[col[r["id"]]]
        else:
            pal_light[r["id"]] = FOREIGN_TINT.get(r["code"], (236, 226, 204))
    pal_light /= 255.0
    # fade the inks a touch towards the paper: seventy years in a drawer
    pal_light[2:] = pal_light[2:] * 0.86 + np.array([0.96, 0.94, 0.89], np.float32) * 0.14

    # ---- edge bands (the stronger ribbon of colour inside every boundary)
    b = np.zeros_like(dry)
    b[:, 1:] |= ids_land[:, 1:] != ids_land[:, :-1]
    b[:, :-1] |= ids_land[:, 1:] != ids_land[:, :-1]
    b[1:, :] |= ids_land[1:, :] != ids_land[:-1, :]
    b[:-1, :] |= ids_land[1:, :] != ids_land[:-1, :]
    band_w = int(round(13 * ctx.U))
    dist = raster.edt(b, band_w)
    band = np.clip(1.0 - dist / band_w, 0, 1) ** 1.6
    band[~dry] = 0
    del dist, b, ids_land
    log("edge bands")

    # ---- elevation (relief + bathymetry) on a half-plate grid
    sample = geodata.elevation_sampler()
    hs = 0.5 if args.res >= 1.0 else args.res
    sw, sh = int(mp.IMAGE_W * hs), int(mp.IMAGE_H * hs)
    land_small = np.asarray(land_img.resize((sw, sh), Image.BILINEAR)) > 127
    dry_small = np.asarray(Image.fromarray((dry * 255).astype(np.uint8)).resize((sw, sh), Image.BILINEAR)) > 127
    elev = build_relief(ctx, land_small, sample)
    log("elevation sampled")

    # ---- tint layer
    tint = np.empty((WH, WW, 3), np.uint8)
    deep = raster.resize_f(np.clip((-elev - 150.0) / 700.0, 0, 1), (WW, WH))
    deep = np.asarray(Image.fromarray((deep * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6 * ctx.U)),
                      dtype=np.float32) / 255.0
    tex = raster.fbm(WW // 4, WH // 4, 60, 3, rng)
    tex = raster.resize_f(tex, (WW, WH))
    for c in range(3):
        lt = pal_light[:, c][ids]
        v = lt ** (1.0 + band * 1.35 + tex * 0.35)
        wv = WATER_TINT[c] / 255.0 + (DEEP_TINT[c] - WATER_TINT[c]) / 255.0 * deep
        v = np.where(ids == 0, wv, v)
        tint[..., c] = np.clip(v * 255.0, 0, 255).astype(np.uint8)
    del band, deep, tex
    canvas = Canvas(ctx, Image.fromarray(tint, "RGB"))
    del tint
    log("tints")

    # ---- lettering first (the engraver leaves the lines open under the names)
    L = Lettering(ctx)
    L.set_land(dry)
    reserve_game_places(ctx, L)
    place_labels(ctx, L)
    place_places(ctx, L)
    alltext = ImageChops.lighter(ImageChops.lighter(L.masks["ink"], L.masks["water"]), L.masks["relief"])
    alltext = ImageChops.lighter(alltext, L.symbols)
    knock = alltext.filter(ImageFilter.GaussianBlur(3.2 * ctx.U)).point(lambda v: min(255, v * 7))
    knock = ImageChops.lighter(knock, alltext)
    knock_l = ImageChops.lighter(knock, L.strip.filter(ImageFilter.GaussianBlur(1.0 * ctx.U)))
    log("lettering laid out")

    # ---- relief hachures
    hm = hachures(ctx, elev, dry_small, rng)
    hm = ImageChops.multiply(hm, Image.fromarray((dry * 255).astype(np.uint8)))
    canvas.ink(hm, RELIEF_INK, 0.9, knock)
    del hm
    log("hachures")

    # ---- graticule
    gm = ctx.mask()
    gd = ImageDraw.Draw(gm)
    for lon in range(-125, -19, 5):
        lats = np.linspace(5, 62, 400)
        x, y = ctx.P(lats, np.full_like(lats, lon))
        gd.line(list(zip(x.tolist(), y.tolist())), fill=255, width=max(1, int(round(0.9 * ctx.U))))
    for lat in range(10, 61, 5):
        lons = np.linspace(-130, -20, 800)
        x, y = ctx.P(np.full_like(lons, lat), lons)
        gd.line(list(zip(x.tolist(), y.tolist())), fill=255, width=max(1, int(round(0.9 * ctx.U))), joint="curve")
    canvas.ink(gm, NAVY, 0.30, knock_l)
    del gm

    # ---- water lining
    wmax = int(round(34 * ctx.U))
    dwater = raster.edt(dry, wmax)
    wl = np.zeros((WH, WW), np.float32)
    offs = [(2.7, 0.95, 0.95), (5.6, 0.9, 0.78), (8.9, 0.85, 0.62), (12.7, 0.8, 0.5), (17.2, 0.75, 0.38),
            (22.5, 0.7, 0.27), (28.8, 0.65, 0.17)]
    for dpl, wid, alpha in offs:
        dd = dpl * ctx.U
        hw = wid * ctx.U / 2
        cov = np.clip(hw + 0.5 - np.abs(dwater - dd), 0, 1)
        np.maximum(wl, cov * alpha, out=wl)
    wl[~lined] = 0
    wl_img = Image.fromarray((wl * 255).astype(np.uint8))
    del wl
    canvas.ink(wl_img, WATER_INK, 0.85, knock)
    del wl_img
    log("water lining")

    # ---- 100-fathom line (from ETOPO1)
    fath = ctx.mask()
    fd = ImageDraw.Draw(fath)
    e_bl = raster.blur_f(elev, 1.2)
    lines = raster.contours(e_bl, -183.0)
    for ln in lines:
        pts = [((x + 0.5) / hs * ctx.U - 0.5, (y + 0.5) / hs * ctx.U - 0.5) for x, y in ln]
        if raster.polyline_length(pts) < 160 * ctx.U:
            continue
        # only open water (not through land)
        pts = raster.smooth_polyline(pts, 2)
        draw_pattern(fd, pts, [("o", 0.95 * ctx.U), ("g", 4.2 * ctx.U)], 1)
    fath = ImageChops.multiply(fath, Image.fromarray(((~land) * 255).astype(np.uint8)))
    canvas.ink(fath, WATER_INK, 0.8, knock_l)
    del fath
    log("fathom line")

    # ---- rivers
    rv = ctx.mask()
    rd = ImageDraw.Draw(rv)
    widths = {1: 2.5, 2: 2.3, 3: 2.1, 4: 1.9, 5: 1.75, 6: 1.6, 7: 1.4, 8: 1.25, 9: 1.1, 10: 0.95, 11: 0.8}
    for feats, maxrank in ((g.rivers_na, 10), (g.rivers, 9)):
        for f in feats:
            sr = int(f["props"].get("scalerank") or 12)
            if sr > maxrank:
                continue
            wv = widths.get(sr, 0.8)
            for poly in f["polys"]:
                for ring in poly:
                    pts = ctx.ring(ring)
                    if len(pts) >= 2:
                        rd.line(pts, fill=255, width=max(1, int(round(wv * ctx.U))), joint="curve")
    rv = ImageChops.multiply(rv, Image.fromarray((dry * 255).astype(np.uint8)))
    canvas.ink(rv, WATER_INK, 0.95, knock)
    del rv
    log("rivers")

    # ---- coast and lake shores
    cm = ctx.mask()
    cd = ImageDraw.Draw(cm)
    cw = max(1, int(round(1.55 * ctx.U)))
    for f in g.coast:
        for poly in f["polys"]:
            for ring in poly:
                pts = ctx.ring(ring)
                if len(pts) >= 2:
                    cd.line(pts, fill=255, width=cw, joint="curve")
    for f in g.minor:
        for poly in f["polys"]:
            pts = ctx.ring(poly[0])
            if len(pts) >= 3:
                cd.line(pts + [pts[0]], fill=255, width=max(1, cw - 1), joint="curve")
    for f in g.lakes:
        for poly in f["polys"]:
            for ring in poly:
                pts = ctx.ring(ring)
                if len(pts) >= 3:
                    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
                    if max(xs) - min(xs) < 2 * ctx.U and max(ys) - min(ys) < 2 * ctx.U:
                        continue
                    cd.line(pts + [pts[0]], fill=255, width=max(1, int(round(1.15 * ctx.U))), joint="curve")
    canvas.ink(cm, COAST_INK, 0.95)
    del cm
    log("coast")

    # ---- boundaries
    rib = ctx.mask()
    ib = ctx.mask()
    sb = ctx.mask()
    for f in g.intl:
        p = f["props"]
        pair = {p.get("ADM0_LEFT"), p.get("ADM0_RIGHT")}
        if "United States of America" not in pair:
            continue
        for poly in f["polys"]:
            for ring in poly:
                pts = ctx.ring(ring)
                ImageDraw.Draw(rib).line(pts, fill=255, width=int(round(11 * ctx.U)), joint="curve")
                draw_pattern(ImageDraw.Draw(ib), pts, [("d", 13 * ctx.U), ("g", 4 * ctx.U), ("o", 1.35 * ctx.U),
                                                       ("g", 4 * ctx.U)], 2.1 * ctx.U)
    sd = ImageDraw.Draw(sb)
    for f in g.adm1_lines:
        p = f["props"]
        if "statistical" in str(p.get("FEATURECLA", "")) or "indicator" in str(p.get("FEATURECLA", "")):
            continue
        mex = p.get("ADM0_A3") == "MEX"
        for poly in f["polys"]:
            for ring in poly:
                pts = ctx.ring(ring)
                draw_pattern(sd, pts, [("o", (0.8 if mex else 1.05) * ctx.U), ("g", (5.5 if mex else 4.6) * ctx.U)], 1)
    canvas.ink(rib.filter(ImageFilter.GaussianBlur(1.5 * ctx.U)), (232, 128, 104), 0.42, L.strip)
    canvas.ink(sb, INK, 0.9, knock_l)
    canvas.ink(ib, INK, 1.0, knock_l)
    del rib, ib, sb
    log("boundaries")

    # ---- twelve-mile limit (contour of the distance from US Atlantic land)
    lines_json = {"rails": {}, "routes": {}, "lanes": {}, "limit_12mi": [], "fathom_100": []}
    limit_px = 12 * 1.15078 * mp.px_per_mile(36.0)       # 12 nautical miles in plate px
    fs = 0.5
    fw, fh = int(mp.IMAGE_W * fs), int(mp.IMAGE_H * fs)
    land_f = np.asarray(land_img.resize((fw, fh), Image.BILINEAR)) > 127
    dfar = raster.edt(land_f, int(limit_px * fs) + 6)
    yy, xx = np.mgrid[0:fh, 0:fw]
    la, lo = mp.from_px((xx + 0.5) / fs, (yy + 0.5) / fs)
    atlantic = ((la > 24.3) & (la < 44.75) & (lo > -81.9) & ~((la < 27.4) & (lo > -79.35))
                & ~((la < 30.0) & (lo < -81.25)) & ~((la > 42.5) & (lo > -67.2)))
    lim = ctx.mask()
    ld = ImageDraw.Draw(lim)
    for ln in raster.contours(dfar, limit_px * fs, mask=atlantic):
        pts = [((x + 0.5) / fs, (y + 0.5) / fs) for x, y in ln]
        if raster.polyline_length(pts) < 200:
            continue
        pts = raster.smooth_polyline(pts, 3)
        wpts = [(x * ctx.U - 0.5, y * ctx.U - 0.5) for x, y in pts]
        draw_pattern(ld, wpts, [("d", 9 * ctx.U), ("g", 5 * ctx.U)], 1.5 * ctx.U)
        la_, lo_ = mp.from_px(np.array([p[0] for p in pts]), np.array([p[1] for p in pts]))
        lines_json["limit_12mi"].append(thin_latlon([(round(float(a), 4), round(float(b), 4)) for a, b in zip(la_, lo_)], 1.0))
    canvas.ink(lim, OXBLOOD, 0.9, knock_l)
    del lim, dfar, la, lo, atlantic
    log("12-mile limit")

    # ---- mother-ship lanes
    lm = ctx.mask()
    lmd = ImageDraw.Draw(lm)
    for lid, (name, wps) in LANES.items():
        pts = mp.catmull_rom([tuple(map(float, ctx.P(a, b))) for a, b in wps], 16)
        draw_pattern(lmd, pts, [("o", 1.35 * ctx.U), ("g", 6.0 * ctx.U)], 1)
        lines_json["lanes"][lid] = [list(p) for p in wps]
    canvas.ink(lm, OXBLOOD, 0.85, knock_l)
    del lm

    # ---- railroads
    rr = ctx.mask()
    rrd = ImageDraw.Draw(rr)
    for rid, (name, wps) in RAILS.items():
        pts = mp.catmull_rom([tuple(map(float, ctx.P(a, b))) for a, b in wps], 8)
        rrd.line(pts, fill=255, width=max(1, int(round(1.5 * ctx.U))), joint="curve")
        draw_ticks(rrd, pts, 7.5 * ctx.U, 2.8 * ctx.U, 1.05 * ctx.U)
        lines_json["rails"][rid] = [list(p) for p in wps]
    canvas.ink(rr, INK, 0.95, knock_l)
    del rr
    log("railroads")

    # ---- routes (not drawn; exported for the game with river-following geometry)
    for rid, wps in ROUTES.items():
        pts = resolve_route(wps, g.rivers)
        lines_json["routes"][rid] = [[round(a, 4), round(b, 4)] for a, b in thin_latlon(pts, 0.8)]

    # ---- place symbols and all lettering
    canvas.ink(L.symbols, INK)
    canvas.ink(L.masks["relief"], RELIEF_INK, 0.95)
    canvas.ink(L.masks["water"], WATER_INK, 0.98)
    canvas.ink(L.masks["ink"], INK, 0.96)
    canvas.ink(L.masks["outline"], INK, 0.55)
    log("lettering inked")

    # ---- decorations
    compass_rose(ctx, canvas, L, 22.95, -94.1, 88)
    cartouche(ctx, canvas, L, (2740, 470, 3440, 1040))
    legend(ctx, canvas, L, (2800, 1500, 3400, 1930))
    scale_bar(ctx, canvas, L, 2915, 2045)
    frame(ctx, canvas, L)
    log("decorations")

    # ---- print: slight ink spread, downsample, onto the paper
    img = canvas.img.filter(ImageFilter.GaussianBlur(0.45 * ctx.ss))
    img = img.resize((ctx.FW, ctx.FH), Image.LANCZOS)
    ink_f = np.asarray(img, dtype=np.float32) / 255.0
    paper = make_paper(ctx.FW, ctx.FH, np.random.default_rng(7))
    # ink sits a little unevenly on the paper: lighten dark ink where the paper grain is high
    speck = raster.value_noise(ctx.FW, ctx.FH, int(900 * ctx.R), np.random.default_rng(11))
    darkness = 1.0 - ink_f.mean(axis=2, keepdims=True)
    ink_f = ink_f + darkness * (speck[..., None] - 0.5) * 0.10
    out = np.clip(paper * ink_f, 0, 1)
    log("printed")
    result = Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGB")
    if getattr(args, "boxes", False):
        bx = result.copy()
        bd = ImageDraw.Draw(bx)
        for i, (a0, b0, a1, b1) in enumerate(L.rects):
            col = (255, 0, 0) if i < 2 * len(CITIES + SOURCES) else (0, 90, 255)
            bd.rectangle([a0 * ctx.R, b0 * ctx.R, a1 * ctx.R, b1 * ctx.R], outline=col)
        bx.save("/tmp/claude-0/-home-user-Gettheshot/0e428329-ae5b-57e9-8af2-ef0568aaa57b/scratchpad/map/boxes.png")
    return result, lines_json


def debug_overlay(img: Image.Image) -> Image.Image:
    out = img.copy()
    d = ImageDraw.Draw(out)
    s = img.width / mp.IMAGE_W
    for kind, pts in (("city", CITIES), ("source", SOURCES)):
        for _, name, lat, lon in pts:
            x, y = mp.to_px(lat, lon)
            x, y = float(x) * s, float(y) * s
            r = 5 * s
            d.ellipse([x - r - 0.5, y - r - 0.5, x + r - 0.5, y + r - 0.5], fill=(255, 0, 255))
    return out


def blobs(img: Image.Image, color, tol=40):
    a = np.asarray(img.convert("RGB"), dtype=np.int32)
    m = (np.abs(a[..., 0] - color[0]) < tol) & (np.abs(a[..., 1] - color[1]) < tol) & (np.abs(a[..., 2] - color[2]) < tol)
    # label connected components (simple flood fill on the few pixels)
    ys, xs = np.nonzero(m)
    pts = set(zip(ys.tolist(), xs.tolist()))
    out = []
    while pts:
        stack = [pts.pop()]
        comp = []
        while stack:
            y, x = stack.pop()
            comp.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    q = (y + dy, x + dx)
                    if q in pts:
                        pts.remove(q)
                        stack.append(q)
        if len(comp) >= 6:
            cy = sum(p[0] for p in comp) / len(comp) + 0.5
            cx = sum(p[1] for p in comp) / len(comp) + 0.5
            out.append((cx, cy, len(comp)))
    return out


def check(godot_png: Path, debug_png: Path):
    g = Image.open(godot_png)
    dbg = Image.open(debug_png)
    gs = blobs(g, (0, 255, 0))
    ps = blobs(dbg, (255, 0, 255))
    sx = mp.IMAGE_W / g.width
    worst = 0.0
    rows = []
    for _, name, lat, lon in CITIES + SOURCES:
        x, y = (float(v) for v in mp.to_px(lat, lon))
        def near(bl, scale):
            if not bl:
                return None
            b = min(bl, key=lambda q: (q[0] * scale - x) ** 2 + (q[1] * scale - y) ** 2)
            return b[0] * scale, b[1] * scale
        gp = near(gs, sx)
        pp = near(ps, mp.IMAGE_W / dbg.width)
        if gp is None or pp is None:
            rows.append(f"  {name:26s} MISSING")
            worst = 1e9
            continue
        err = math.hypot(gp[0] - pp[0], gp[1] - pp[1])
        worst = max(worst, err)
        rows.append(f"  {name:26s} python ({pp[0]:7.1f},{pp[1]:7.1f})  godot ({gp[0]:7.1f},{gp[1]:7.1f})  diff {err:4.2f}px")
    print("\n".join(rows))
    print(f"CHECK {'OK' if worst <= 2.0 else 'FAIL'}: {len(gs)} godot dots, {len(ps)} python dots, worst {worst:.2f}px")
    return worst <= 2.0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--preview", action="store_true", help="half size, written to --out (default /tmp)")
    ap.add_argument("--res", type=float, default=None, help="output scale (1.0 = 3600x2250)")
    ap.add_argument("--ss", type=int, default=2, help="supersampling factor")
    ap.add_argument("--out", type=str, default=None, help="output png (default game/assets/map/country_map.png)")
    ap.add_argument("--debug", action="store_true", help="also write <out>_debug.png with the game places as dots")
    ap.add_argument("--boxes", action="store_true", help="(dev) write the lettering boxes over the plate")
    ap.add_argument("--check", type=str, default=None, help="compare a check_projection.tscn render with the debug png")
    args = ap.parse_args()
    if args.check:
        dbg = Path(args.out) if args.out else DEBUG_PNG
        sys.exit(0 if check(Path(args.check), dbg) else 1)
    if args.res is None:
        args.res = 0.5 if args.preview else 1.0
    out = Path(args.out) if args.out else (Path("/tmp/country_map_preview.png") if args.preview
                                           else OUT_DIR / "country_map.png")
    img, lines = build(args)
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, optimize=True)
    log(f"wrote {out} {img.size}")
    if not args.preview and args.res == 1.0 and not args.out:
        small = img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
        small.save(OUT_DIR / "country_map_small.png", optimize=True)
        lines["meta"] = {
            "image_size": [mp.IMAGE_W, mp.IMAGE_H], "scale_px_per_unit": mp.SCALE, "center": [mp.CX, mp.CY],
            "projection": "Lambert Conformal Conic, sphere, std parallels 33/45, origin 39N 83W",
            "window": [mp.WIN_LON_MIN, mp.WIN_LON_MAX, mp.WIN_LAT_MIN, mp.WIN_LAT_MAX],
        }
        (OUT_DIR / "map_lines.json").write_text(json.dumps(lines, indent=1), encoding="utf-8")
        log("wrote country_map_small.png and map_lines.json")
    if args.debug:
        dbg = debug_overlay(img)
        dpath = out.with_name(out.stem + "_debug.png") if args.out else DEBUG_PNG
        dbg.save(dpath)
        log(f"wrote {dpath}")


if __name__ == "__main__":
    main()
