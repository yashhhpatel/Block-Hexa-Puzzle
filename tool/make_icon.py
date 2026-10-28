"""Draws the app icon (legacy + adaptive foreground) and splash logo."""
import math, os
from PIL import Image, ImageDraw, ImageFilter

RES = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res")
NAVY_TOP, NAVY_BOT = (28, 56, 140), (8, 18, 52)

def hex_pts(cx, cy, r):
    return [(cx + r * math.cos(math.pi / 3 * i), cy + r * math.sin(math.pi / 3 * i)) for i in range(6)]

def shade(c, k):
    return tuple(max(0, min(255, int(v + (255 - v) * k if k > 0 else v * (1 + k)))) for v in c)

def gem(d, cx, cy, r, col):
    d.polygon(hex_pts(cx, cy, r), fill=shade(col, -0.3))
    d.polygon(hex_pts(cx, cy - r * 0.04, r * 0.88), fill=col)
    d.polygon(hex_pts(cx, cy - r * 0.08, r * 0.62), fill=shade(col, 0.18))
    d.ellipse([cx - r * 0.5, cy - r * 0.62, cx + 0.05 * r, cy - r * 0.42], fill=shade(col, 0.6))

def foreground(size, scale):
    """Cluster of gems + one empty outlined cell, centred."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = size * 0.15 * scale
    c = size / 2
    w, h = 1.5 * r, math.sqrt(3) * r
    cells = [((0, -0.5), (255, 77, 141)), ((1, 0), (62, 201, 245)), ((-1, 0), (255, 201, 58)),
             ((0, 0.5), (139, 224, 74)), ((-1, 1), (142, 92, 255))]
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    ex, ey = c + w, c + h
    gd.polygon(hex_pts(ex, ey, r * 0.95), outline=(94, 200, 255, 255), width=max(2, int(r * 0.16)))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(r * 0.12)))
    d.polygon(hex_pts(ex, ey, r * 0.92), fill=(7, 18, 51, 255), outline=(150, 220, 255, 255), width=max(2, int(r * 0.07)))
    for (q, y), col in cells:
        gem(d, c + q * w, c + y * h, r * 0.97, col)
    return im

def background(size):
    im = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(im)
    for y in range(size):
        t = y / size
        d.line([(0, y), (size, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(NAVY_TOP, NAVY_BOT)))
    return im

def legacy(size):
    big = 512
    im = background(big)
    im.alpha_composite(foreground(big, 1.0))
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=big * 0.22, fill=255)
    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out.resize((size, size), Image.LANCZOS)

dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for name, k in dens.items():
    d = os.path.join(RES, "mipmap-" + name)
    os.makedirs(d, exist_ok=True)
    legacy(int(48 * k)).save(os.path.join(d, "ic_launcher.png"))
    # Adaptive foreground: 108dp canvas, art inside the 66dp safe zone.
    foreground(1024, 0.62).resize((int(108 * k),) * 2, Image.LANCZOS).save(os.path.join(d, "ic_launcher_foreground.png"))
    foreground(1024, 0.55).resize((int(160 * k),) * 2, Image.LANCZOS).save(os.path.join(d, "splash_logo.png"))
print("ok")
