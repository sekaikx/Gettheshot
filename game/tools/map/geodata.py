"""Downloads (cached outside the repo) and loads the public-domain source data for the map.

Natural Earth vectors (public domain) from github.com/nvkelso/natural-earth-vector, relief and
bathymetry from the AWS Terrain Tiles at zoom 6, which at that zoom are built only from USGS
GMTED2010 and NOAA ETOPO1 (both public domain; checked via the tiles' x-imagery-sources header).
"""
from __future__ import annotations

import io
import json
import math
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

NE_BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
FONT_BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
TERRAIN = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
CACHE = Path(os.environ.get("FAMIGLIA_MAP_CACHE", Path.home() / ".cache" / "famiglia-map"))

# lon/lat box of everything that can appear on the plate (the image corners reach 118W..31W, 12N..54N)
BBOX = (-128.0, -22.0, 5.0, 62.0)


def _get(url: str) -> bytes:
    import requests  # only needed when something is not cached yet
    r = requests.get(url, timeout=120)
    r.raise_for_status()
    return r.content


def cached(name: str, url: str) -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    p = CACHE / name
    if not p.exists() or p.stat().st_size == 0:
        print("  download", url, file=sys.stderr)
        data = _get(url)
        tmp = p.with_suffix(p.suffix + ".part")
        tmp.write_bytes(data)
        tmp.replace(p)
    return p


def ne(name: str) -> list:
    """Features of a Natural Earth layer that touch BBOX, geometry as lists of numpy (N, 2) lon/lat arrays."""
    p = cached(name + ".geojson", NE_BASE + name + ".geojson")
    gj = json.loads(p.read_text(encoding="utf-8"))
    out = []
    for f in gj["features"]:
        g = f.get("geometry")
        if not g:
            continue
        t, c = g["type"], g["coordinates"]
        if t == "Polygon":
            polys = [c]
        elif t == "MultiPolygon":
            polys = c
        elif t == "LineString":
            polys = [[c]]
        elif t == "MultiLineString":
            polys = [[l] for l in c]
        elif t == "Point":
            polys = [[[c]]]
        else:
            continue
        keep = []
        for poly in polys:
            rings = [np.asarray(r, dtype=np.float64)[:, :2] for r in poly if len(r) > 0]
            if not rings:
                continue
            o = rings[0]
            if (o[:, 0].max() < BBOX[0] or o[:, 0].min() > BBOX[1] or o[:, 1].max() < BBOX[2]
                    or o[:, 1].min() > BBOX[3]):
                continue
            keep.append(rings)
        if keep:
            out.append({"props": f["properties"], "polys": keep, "type": t})
    return out


def font(family: str, filename: str, dest: Path) -> Path:
    dest.mkdir(parents=True, exist_ok=True)
    p = dest / filename
    if not p.exists():
        p.write_bytes(cached("font_" + filename, FONT_BASE + family + "/" + filename).read_bytes())
    return p


def font_licence(family: str, dest: Path, name: str = "OFL.txt") -> Path:
    p = dest / name
    if not p.exists():
        p.write_bytes(cached("ofl_" + family + ".txt", FONT_BASE + family + "/OFL.txt").read_bytes())
    return p


# ----------------------------------------------------------------------------- terrain
TERRAIN_Z = 6


def _tile_xy(lat, lon, z):
    n = 2 ** z
    x = (lon + 180.0) / 360.0 * n
    y = (1.0 - np.arcsinh(np.tan(np.radians(lat))) / math.pi) / 2.0 * n
    return x, y


def elevation_sampler():
    """Returns f(lat_array, lon_array) -> elevation metres (bilinear), from a z6 terrarium mosaic."""
    z = TERRAIN_Z
    x0, y0 = _tile_xy(BBOX[3], BBOX[0], z)
    x1, y1 = _tile_xy(BBOX[2], BBOX[1], z)
    tx0, ty0, tx1, ty1 = int(x0), int(y0), int(x1), int(y1)
    w, h = (tx1 - tx0 + 1) * 256, (ty1 - ty0 + 1) * 256
    mosaic = np.zeros((h, w), np.float32)
    for ty in range(ty0, ty1 + 1):
        for tx in range(tx0, tx1 + 1):
            p = cached(f"terrarium_{z}_{tx}_{ty}.png", TERRAIN.format(z=z, x=tx, y=ty))
            a = np.asarray(Image.open(p).convert("RGB"), dtype=np.float32)
            e = a[..., 0] * 256.0 + a[..., 1] + a[..., 2] / 256.0 - 32768.0
            mosaic[(ty - ty0) * 256:(ty - ty0 + 1) * 256, (tx - tx0) * 256:(tx - tx0 + 1) * 256] = e

    def sample(lat, lon):
        fx, fy = _tile_xy(np.asarray(lat), np.asarray(lon), z)
        px = (fx - tx0) * 256.0 - 0.5
        py = (fy - ty0) * 256.0 - 0.5
        px = np.clip(px, 0, w - 1.001)
        py = np.clip(py, 0, h - 1.001)
        ix, iy = np.floor(px).astype(np.int64), np.floor(py).astype(np.int64)
        fx_, fy_ = (px - ix).astype(np.float32), (py - iy).astype(np.float32)
        a = mosaic[iy, ix]; b = mosaic[iy, ix + 1]; c = mosaic[iy + 1, ix]; d = mosaic[iy + 1, ix + 1]
        return (a * (1 - fx_) + b * fx_) * (1 - fy_) + (c * (1 - fx_) + d * fx_) * fy_

    return sample
