"""Map projection for Famiglia's country map. Mirrors scripts/core/map_projection.gd exactly.

Lambert Conformal Conic on a sphere (R = 1), standard parallels 33N and 45N, origin 39N 83W.
The map window lon -100..-52, lat 20.5..49 is sampled along its edges every FIT_STEP degrees,
its projected bounding box is fitted into the image (uniform scale, FIT_MARGIN pixels on the
limiting axis) and centred. Pixel coordinates use the edge convention: pixel i spans [i, i+1),
so UV = px / IMAGE_SIZE, which is how Godot maps a texture onto a rect.
"""
from __future__ import annotations

import math

import numpy as np

STD_PARALLEL_1 = 33.0
STD_PARALLEL_2 = 45.0
ORIGIN_LAT = 39.0
CENTRAL_LON = -83.0
WIN_LON_MIN, WIN_LON_MAX = -100.0, -52.0
WIN_LAT_MIN, WIN_LAT_MAX = 20.5, 49.0
IMAGE_W, IMAGE_H = 3600, 2250
FIT_MARGIN = 120.0
FIT_STEP = 0.25
EARTH_RADIUS_MILES = 3958.8

_p1 = math.radians(STD_PARALLEL_1)
_p2 = math.radians(STD_PARALLEL_2)
_p0 = math.radians(ORIGIN_LAT)
N = math.log(math.cos(_p1) / math.cos(_p2)) / math.log(
    math.tan(math.pi / 4 + _p2 / 2) / math.tan(math.pi / 4 + _p1 / 2))
F = math.cos(_p1) * math.tan(math.pi / 4 + _p1 / 2) ** N / N
RHO0 = F / math.tan(math.pi / 4 + _p0 / 2) ** N


def lcc(lat, lon):
    """Unit-sphere LCC. Works on floats or numpy arrays. Returns (x, y), y up."""
    lat = np.asarray(lat, dtype=np.float64)
    lon = np.asarray(lon, dtype=np.float64)
    rho = F / np.tan(math.pi / 4 + np.radians(lat) / 2) ** N
    th = N * (np.radians(lon) - math.radians(CENTRAL_LON))
    return rho * np.sin(th), RHO0 - rho * np.cos(th)


def _fit():
    xs, ys = [], []
    steps = int(round((WIN_LON_MAX - WIN_LON_MIN) / FIT_STEP))
    for i in range(steps + 1):
        lon = WIN_LON_MIN + i * FIT_STEP
        for lat in (WIN_LAT_MIN, WIN_LAT_MAX):
            x, y = lcc(lat, lon)
            xs.append(float(x)); ys.append(float(y))
    steps = int(round((WIN_LAT_MAX - WIN_LAT_MIN) / FIT_STEP))
    for i in range(steps + 1):
        lat = WIN_LAT_MIN + i * FIT_STEP
        for lon in (WIN_LON_MIN, WIN_LON_MAX):
            x, y = lcc(lat, lon)
            xs.append(float(x)); ys.append(float(y))
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    scale = min((IMAGE_W - 2 * FIT_MARGIN) / (maxx - minx), (IMAGE_H - 2 * FIT_MARGIN) / (maxy - miny))
    return scale, (minx + maxx) / 2, (miny + maxy) / 2


SCALE, CX, CY = _fit()


def to_px(lat, lon):
    """Pixel coordinates (edge convention) on the full-size country_map.png."""
    x, y = lcc(lat, lon)
    return IMAGE_W / 2 + (x - CX) * SCALE, IMAGE_H / 2 - (y - CY) * SCALE


def to_uv(lat, lon):
    px, py = to_px(lat, lon)
    return px / IMAGE_W, py / IMAGE_H


def from_px(px, py):
    """Inverse: pixel -> (lat, lon) in degrees."""
    x = (np.asarray(px, dtype=np.float64) - IMAGE_W / 2) / SCALE + CX
    y = -(np.asarray(py, dtype=np.float64) - IMAGE_H / 2) / SCALE + CY
    rho = np.sign(N) * np.hypot(x, RHO0 - y)
    th = np.arctan2(x, RHO0 - y)
    lat = 2 * np.arctan((F / rho) ** (1 / N)) - math.pi / 2
    return np.degrees(lat), CENTRAL_LON + np.degrees(th / N)


def scale_factor(lat):
    """Point scale k of the projection at a latitude (1.0 on the standard parallels)."""
    phi = math.radians(lat)
    rho = F / math.tan(math.pi / 4 + phi / 2) ** N
    return rho * N / math.cos(phi)


def px_per_mile(lat=39.0):
    return SCALE * scale_factor(lat) / EARTH_RADIUS_MILES


def convergence_deg(lon):
    """Angle between grid north (image up) and true north at a longitude, degrees (+ = clockwise)."""
    return N * (lon - CENTRAL_LON)


def catmull_rom(points, samples=8):
    """Uniform Catmull-Rom through points [(x, y)...] (pixel space). Same as MapProjection.smooth()."""
    n = len(points)
    if n < 3:
        return list(points)
    out = []
    for i in range(n - 1):
        p0 = points[i - 1] if i > 0 else points[i]
        p1 = points[i]
        p2 = points[i + 1]
        p3 = points[i + 2] if i + 2 < n else points[i + 1]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t
                                    + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in range(2)))
    out.append(tuple(points[-1]))
    return out
