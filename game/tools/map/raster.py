"""Small raster toolkit for the map baker (numpy + Pillow only, no scipy)."""
from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageFilter


def edt(feature: np.ndarray, maxd: int) -> np.ndarray:
    """Exact Euclidean distance (pixels) from every pixel to the nearest True pixel of `feature`,
    capped at `maxd`. Separable: exact 1-D row distances, then a bounded column min-plus pass."""
    h, w = feature.shape
    idx = np.arange(w, dtype=np.float32)[None, :]
    big = np.float32(1e7)
    left = np.where(feature, idx, -big)
    np.maximum.accumulate(left, axis=1, out=left)
    right = np.where(feature, idx, big)[:, ::-1]
    right = np.minimum.accumulate(right, axis=1)[:, ::-1]
    g = np.minimum(idx - left, right - idx)
    del left, right
    np.minimum(g, np.float32(maxd), out=g)
    g2 = g * g
    del g
    d2 = g2.copy()
    tmp = np.empty_like(g2)
    for dy in range(1, maxd + 1):
        dd = np.float32(dy * dy)
        if dd >= maxd * maxd:
            break
        np.add(g2[:-dy], dd, out=tmp[:-dy])
        np.minimum(d2[dy:], tmp[:-dy], out=d2[dy:])
        np.add(g2[dy:], dd, out=tmp[dy:])
        np.minimum(d2[:-dy], tmp[dy:], out=d2[:-dy])
    np.sqrt(d2, out=d2)
    np.minimum(d2, np.float32(maxd), out=d2)
    return d2


def resize_f(a: np.ndarray, size, resample=Image.BILINEAR) -> np.ndarray:
    """Resize a float32 2-D array to size=(w, h)."""
    return np.asarray(Image.fromarray(a.astype(np.float32), "F").resize(size, resample), dtype=np.float32)


def _box1d(a: np.ndarray, r: int, axis: int) -> np.ndarray:
    if r <= 0:
        return a
    pad = [(0, 0), (0, 0)]
    pad[axis] = (r + 1, r)
    p = np.pad(a, pad, mode="edge")
    c = np.cumsum(p, axis=axis, dtype=np.float64)
    n = a.shape[axis]
    if axis == 0:
        out = c[2 * r + 1:2 * r + 1 + n] - c[:n]
    else:
        out = c[:, 2 * r + 1:2 * r + 1 + n] - c[:, :n]
    return (out / (2 * r + 1)).astype(np.float32)


def blur_f(a: np.ndarray, sigma: float) -> np.ndarray:
    """Gaussian-ish blur of a float array (three box passes)."""
    if sigma <= 0.3:
        return a.astype(np.float32)
    w = math.sqrt(12 * sigma * sigma / 3 + 1)
    r = max(1, int(round((w - 1) / 2)))
    out = a.astype(np.float32)
    for _ in range(3):
        out = _box1d(out, r, 0)
        out = _box1d(out, r, 1)
    return out


def value_noise(w: int, h: int, cells_x: int, rng: np.random.Generator) -> np.ndarray:
    """Smooth value noise in [0, 1], `cells_x` lattice cells across."""
    cx = max(2, cells_x)
    cy = max(2, int(round(cells_x * h / w)))
    small = rng.random((cy + 1, cx + 1)).astype(np.float32)
    return resize_f(small, (w, h), Image.BICUBIC)


def fbm(w: int, h: int, base_cells: int, octaves: int, rng, gain=0.55) -> np.ndarray:
    total = np.zeros((h, w), np.float32)
    amp, norm, cells = 1.0, 0.0, base_cells
    for _ in range(octaves):
        total += (value_noise(w, h, cells, rng) - 0.5) * amp
        norm += amp
        amp *= gain
        cells *= 2
    return total / norm  # roughly -0.5..0.5


# ----------------------------------------------------------------------------- marching squares
# Corner bits: a=top-left 1, b=top-right 2, c=bottom-right 4, d=bottom-left 8 (bit set = above level).
# Edges: 0 top (a-b), 1 right (b-c), 2 bottom (d-c), 3 left (a-d).
_CASES = {
    1: [(0, 3)], 2: [(0, 1)], 3: [(1, 3)], 4: [(1, 2)], 5: [(0, 1), (2, 3)], 6: [(0, 2)], 7: [(2, 3)],
    8: [(2, 3)], 9: [(0, 2)], 10: [(0, 3), (1, 2)], 11: [(1, 2)], 12: [(1, 3)], 13: [(0, 1)], 14: [(0, 3)],
}


def contours(field: np.ndarray, level: float, mask: np.ndarray | None = None):
    """Iso-lines of `field` at `level` as a list of polylines [(x, y), ...] in pixel-centre coordinates
    (x = column, y = row). `mask` (same shape as field) restricts which cells are traced."""
    f = field.astype(np.float64) - level
    up = f > 0
    code = (up[:-1, :-1] * 1 + up[:-1, 1:] * 2 + up[1:, 1:] * 4 + up[1:, :-1] * 8).astype(np.int8)
    sel = (code != 0) & (code != 15)
    if mask is not None:
        sel &= mask[:-1, :-1]
    ys, xs = np.nonzero(sel)

    def edge_key_pt(y, x, e):
        if e == 0:
            a, b = f[y, x], f[y, x + 1]
            t = a / (a - b)
            return ("h", y, x), (x + t, y)
        if e == 2:
            a, b = f[y + 1, x], f[y + 1, x + 1]
            t = a / (a - b)
            return ("h", y + 1, x), (x + t, y + 1)
        if e == 3:
            a, b = f[y, x], f[y + 1, x]
            t = a / (a - b)
            return ("v", y, x), (x, y + t)
        a, b = f[y, x + 1], f[y + 1, x + 1]
        t = a / (a - b)
        return ("v", y, x + 1), (x + 1, y + t)

    adj: dict = {}
    pts: dict = {}
    for y, x in zip(ys.tolist(), xs.tolist()):
        for e1, e2 in _CASES[int(code[y, x])]:
            k1, p1 = edge_key_pt(y, x, e1)
            k2, p2 = edge_key_pt(y, x, e2)
            pts[k1] = p1
            pts[k2] = p2
            adj.setdefault(k1, []).append(k2)
            adj.setdefault(k2, []).append(k1)
    seen = set()
    lines = []
    # open chains first (endpoints have a single neighbour), then closed loops
    starts = [k for k, v in adj.items() if len(v) == 1] + list(adj.keys())
    for s in starts:
        if s in seen:
            continue
        chain = [s]
        seen.add(s)
        cur = s
        while True:
            nxt = None
            for c in adj[cur]:
                if c not in seen:
                    nxt = c
                    break
            if nxt is None:
                break
            chain.append(nxt)
            seen.add(nxt)
            cur = nxt
        if len(chain) > 1:
            poly = [pts[k] for k in chain]
            if s in adj.get(chain[-1], []) and len(chain) > 2:
                poly.append(poly[0])
            lines.append(poly)
    return lines


def polyline_length(pts) -> float:
    return sum(math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1))


def smooth_polyline(pts, iterations=2):
    """Chaikin corner cutting (keeps endpoints)."""
    for _ in range(iterations):
        if len(pts) < 3:
            return pts
        closed = pts[0] == pts[-1]
        out = [pts[0]]
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            out.append((0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1))
            out.append((0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1))
        out.append(pts[-1])
        if closed:
            out[-1] = out[1]
            out[0] = out[1]
        pts = out
    return pts


def resample_polyline(pts, step):
    """Points every `step` pixels along the polyline, with tangent angles."""
    out = []
    if len(pts) < 2:
        return out
    seg = []
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        seg.append((x0, y0, x1, y1, math.hypot(x1 - x0, y1 - y0)))
    total = sum(s[4] for s in seg)
    d = 0.0
    si = 0
    acc = 0.0
    while d <= total and si < len(seg):
        while si < len(seg) and acc + seg[si][4] < d:
            acc += seg[si][4]
            si += 1
        if si >= len(seg):
            break
        x0, y0, x1, y1, L = seg[si]
        t = 0.0 if L == 0 else (d - acc) / L
        out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, math.atan2(y1 - y0, x1 - x0)))
        d += step
    return out
