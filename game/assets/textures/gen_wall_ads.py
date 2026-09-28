# Generates wall_ads.jpg: a 2x4 atlas of invented 1920s painted wall advertisements
# (each 1024x512), fresh paint; the facade shader ages them into ghost signs, the rooftop
# billboards show them as new. All brands are made up. Run: python3 gen_wall_ads.py
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

HERE = os.path.dirname(os.path.abspath(__file__))
F = os.path.join(HERE, "..", "fonts", "signs") + "/"
OUT = os.path.join(HERE, "wall_ads.jpg")
W, H = 1024, 512


def font(name, size):
    return ImageFont.truetype(F + name, size)


def centered(d, y, text, f, fill, spacing=0):
    if spacing:
        widths = [d.textlength(ch, font=f) for ch in text]
        tw = sum(widths) + spacing * (len(text) - 1)
        x = (W - tw) / 2
        for ch, w in zip(text, widths):
            d.text((x, y), ch, font=f, fill=fill)
            x += w + spacing
        return
    tw = d.textlength(text, font=f)
    d.text(((W - tw) / 2, y), text, font=f, fill=fill)


def fit(d, text, name, size, maxw):
    while size > 10:
        f = font(name, size)
        if d.textlength(text, font=f) <= maxw:
            return f
        size -= 4
    return font(name, size)


def border(d, fg, inset=18, w=8):
    d.rectangle([inset, inset, W - inset, H - inset], outline=fg, width=w)
    d.rectangle([inset + 16, inset + 16, W - inset - 16, H - inset - 16], outline=fg, width=3)


def s1(d):  # cigars
    fg = (236, 226, 200)
    gold = (214, 176, 90)
    d.rectangle([0, 0, W, H], fill=(122, 34, 28))
    border(d, fg)
    centered(d, 50, "SMOKE", font("IMFeENsc28P.ttf", 64), fg, spacing=14)
    centered(d, 120, "PALISADE", fit(d, "PALISADE", "Limelight-Regular.ttf", 190, 900), fg)
    d.rectangle([140, 330, W - 140, 336], fill=gold)
    centered(d, 350, "CIGARS  5c", font("AlfaSlabOne-Regular.ttf", 84), gold)


def s2(d):  # liver pills
    fg = (232, 222, 196)
    d.rectangle([0, 0, W, H], fill=(36, 50, 78))
    border(d, fg)
    centered(d, 48, "Dr. HARTWELL'S", font("PlayfairDisplay.ttf", 88), fg)
    centered(d, 160, "LIVER PILLS", fit(d, "LIVER PILLS", "Bevan-Regular.ttf", 150, 900), (230, 196, 120))
    t = "FOR TORPID LIVERS & SICK HEADACHE"
    centered(d, 350, t, fit(d, t, "IMFeENsc28P.ttf", 60, 880), fg)
    centered(d, 420, "25 CENTS AT ALL DRUGGISTS", font("IMFeENsc28P.ttf", 44), fg)


def s3(d):  # flour
    fg = (238, 232, 212)
    gold = (226, 190, 90)
    d.rectangle([0, 0, W, H], fill=(40, 70, 52))
    border(d, fg)
    cx = W / 2
    pts = []
    import math
    for k in range(10):
        r = 62 if k % 2 == 0 else 26
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((cx + math.cos(a) * r, 108 + math.sin(a) * r))
    d.polygon(pts, fill=gold)
    centered(d, 180, "HUDSON STAR", fit(d, "HUDSON STAR", "AlfaSlabOne-Regular.ttf", 130, 900), fg)
    centered(d, 322, "FLOUR", font("AlfaSlabOne-Regular.ttf", 110), gold, spacing=30)
    centered(d, 434, "ALWAYS RISES", font("IMFeENsc28P.ttf", 36), fg, spacing=10)


def s4(d):  # coffee
    fg = (232, 190, 70)
    cream = (220, 210, 190)
    d.rectangle([0, 0, W, H], fill=(24, 22, 20))
    border(d, cream)
    centered(d, 55, "DRINK", font("Rye-Regular.ttf", 70), cream)
    centered(d, 140, "HARBOR LIGHT", fit(d, "HARBOR LIGHT", "Rye-Regular.ttf", 140, 920), fg)
    centered(d, 300, "COFFEE", font("Limelight-Regular.ttf", 120), cream, spacing=18)
    centered(d, 440, "ROASTED FRESH ON WEST STREET", font("IMFeENsc28P.ttf", 34), fg)


def s5(d):  # furniture
    fg = (236, 232, 220)
    d.rectangle([0, 0, W, H], fill=(20, 20, 22))
    d.rectangle([0, 0, W, 120], fill=(139, 30, 26))
    centered(d, 18, "FIVE POINTS", font("AlfaSlabOne-Regular.ttf", 76), fg)
    centered(d, 140, "FURNITURE Co.", fit(d, "FURNITURE Co.", "PlayfairDisplay.ttf", 140, 920), fg)
    t = "3 ROOMS FURNISHED $98"
    centered(d, 310, t, fit(d, t, "Bevan-Regular.ttf", 70, 900), (226, 190, 90))
    centered(d, 410, "EASY TERMS - $1 A WEEK", font("IMFeENsc28P.ttf", 52), fg)


def s6(d):  # soap
    fg = (38, 58, 100)
    d.rectangle([0, 0, W, H], fill=(226, 216, 190))
    border(d, fg)
    centered(d, 50, "SILVER THREAD", fit(d, "SILVER THREAD", "Limelight-Regular.ttf", 130, 900), fg)
    centered(d, 200, "LAUNDRY SOAP", fit(d, "LAUNDRY SOAP", "AlfaSlabOne-Regular.ttf", 120, 880), (139, 30, 26))
    t = "WASHES WHITER - SAVES THE HANDS"
    centered(d, 360, t, fit(d, t, "IMFeENsc28P.ttf", 50, 860), fg)


def s7(d):  # storage
    fg = (238, 228, 204)
    d.rectangle([0, 0, W, H], fill=(110, 52, 36))
    border(d, fg)
    centered(d, 44, "EXCELSIOR", fit(d, "EXCELSIOR", "Bevan-Regular.ttf", 150, 900), fg)
    centered(d, 210, "STORAGE & MOVING", fit(d, "STORAGE & MOVING", "AlfaSlabOne-Regular.ttf", 100, 900), fg)
    centered(d, 340, "FIREPROOF WAREHOUSE", font("IMFeENsc28P.ttf", 58), (230, 200, 130))
    centered(d, 420, "TELEPHONE CANAL 4-2071", font("IMFeENsc28P.ttf", 44), fg)


def s8(d):  # hats
    fg = (236, 226, 200)
    d.rectangle([0, 0, W, H], fill=(60, 44, 32))
    border(d, fg)
    centered(d, 40, "BELMONT", fit(d, "BELMONT", "AbrilFatface-Regular.ttf", 190, 900), fg)
    centered(d, 250, "HATS", font("Sancreek-Regular.ttf", 130), (214, 176, 90), spacing=24)
    t = "$3 - WORN BY MEN WHO KNOW"
    centered(d, 410, t, fit(d, t, "IMFeENsc28P.ttf", 52, 860), fg)


atlas = Image.new("RGB", (W * 2, H * 4))
for i, fn in enumerate([s1, s2, s3, s4, s5, s6, s7, s8]):
    im = Image.new("RGB", (W, H))
    fn(ImageDraw.Draw(im))
    im = im.filter(ImageFilter.GaussianBlur(0.8))   # brush-soft edges
    atlas.paste(im, ((i % 2) * W, (i // 2) * H))
atlas.save(OUT, quality=88)
print("wrote", OUT, os.path.getsize(OUT))
