#!/usr/bin/env python3
"""Game-style app icons for Blendfall and PondPulse.

Style notes (from top-grossing casual puzzlers - Block Blast, Candy Crush,
Royal Match, Water Sort): saturated gradient bg + radial glow, one big glossy
focal subject with 3D depth and specular highlights, sparkles, no text.
Rendered at 2048 and downscaled to 1024 for clean antialiasing.
"""
from PIL import Image, ImageDraw, ImageFilter
import math

S = 2048  # working canvas; final is 1024


# ---------------------------------------------------------------- helpers

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(size, top, bottom):
    col = Image.new("RGB", (1, 256))
    for y in range(256):
        col.putpixel((0, y), lerp(top, bottom, y / 255))
    return col.resize((size, size), Image.BICUBIC)


def radial_glow(base, center, radius, color, peak_alpha):
    glow = Image.new("L", (256, 256), 0)
    d = ImageDraw.Draw(glow)
    for i in range(60, 0, -1):
        r = 128 * i / 60
        a = int(peak_alpha * (1 - i / 60) ** 2)
        d.ellipse([128 - r, 128 - r, 128 + r, 128 + r], fill=a)
    glow = glow.resize((radius * 2, radius * 2), Image.BICUBIC)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    tint = Image.new("RGBA", glow.size, color + (255,))
    tint.putalpha(glow)
    layer.paste(tint, (center[0] - radius, center[1] - radius), tint)
    return Image.alpha_composite(base, layer)


def over(img, draw_fn):
    """Draw semi-transparent shapes on a fresh layer and composite them.
    ImageDraw alone *replaces* pixels (leaving see-through holes); this blends."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    img.alpha_composite(layer)


def sparkle(img, cx, cy, r, alpha=255, color=(255, 255, 255)):
    def f(d):
        pts = []
        for i in range(8):
            ang = math.pi / 4 * i - math.pi / 2
            rad = r if i % 2 == 0 else r * 0.22
            pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
        d.polygon(pts, fill=color + (alpha,))
    over(img, f)


def glossy_block(size, color, depth_color, radius_frac=0.24):
    """A glossy 3D game block: extruded bottom, gloss band, specular dot."""
    w = size
    ext = int(w * 0.10)
    img = Image.new("RGBA", (w, w + ext), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(w * radius_frac)
    d.rounded_rectangle([0, ext, w, w + ext], r, fill=depth_color + (255,))
    d.rounded_rectangle([0, 0, w, w], r, fill=color + (255,))
    # gloss band over the top half
    over(img, lambda gd: gd.rounded_rectangle(
        [int(w * 0.06), int(w * 0.06), w - int(w * 0.06), int(w * 0.52)],
        int(r * 0.8), fill=(255, 255, 255, 70)))
    # specular dot
    over(img, lambda gd: gd.ellipse(
        [w * 0.12, w * 0.10, w * 0.34, w * 0.26], fill=(255, 255, 255, 165)))
    return img


def drop_shadow(canvas, layer, pos, blur=40, alpha=110, dy=28):
    sil = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    mask = layer.split()[3]
    sil.paste((10, 10, 40, alpha), (0, 0), mask)
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sh.paste(sil, (pos[0], pos[1] + dy), sil)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh)
    canvas.alpha_composite(layer, pos)


def vignette(img, strength=70):
    v = Image.new("L", (256, 256), 0)
    d = ImageDraw.Draw(v)
    for i in range(128):
        a = int(strength * (i / 128) ** 2.2)
        d.rectangle([i, i, 255 - i, 255 - i], outline=255 - a)
    v = v.resize(img.size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(60))
    out = img.copy()
    edge = Image.new("RGBA", img.size, (12, 6, 32, 0))
    edge.putalpha(Image.eval(v, lambda p: int((255 - p) * strength / 255)))
    out.alpha_composite(edge)
    return out


# ---------------------------------------------------------------- Blendfall

def blendfall_icon():
    img = vertical_gradient(S, (72, 38, 158), (36, 96, 218)).convert("RGBA")
    img = radial_glow(img, (S // 2, int(S * 0.44)), int(S * 0.62), (255, 214, 120), 150)

    # faint oversized ghost blocks for depth
    over(img, lambda gd: (
        gd.rounded_rectangle([-S * 0.12, S * 0.62, S * 0.26, S * 1.02], int(S * 0.07), fill=(255, 255, 255, 18)),
        gd.rounded_rectangle([S * 0.78, S * 0.05, S * 1.16, S * 0.45], int(S * 0.07), fill=(255, 255, 255, 16))))

    # the story: red + yellow tumble in, orange is born (bigger, front, glowing)
    red = glossy_block(int(S * 0.30), (255, 82, 92), (176, 32, 60)).rotate(14, expand=True, resample=Image.BICUBIC)
    yel = glossy_block(int(S * 0.30), (255, 208, 64), (196, 138, 12)).rotate(-11, expand=True, resample=Image.BICUBIC)
    org = glossy_block(int(S * 0.44), (255, 148, 42), (198, 84, 10)).rotate(5, expand=True, resample=Image.BICUBIC)

    drop_shadow(img, red, (int(S * 0.13), int(S * 0.15)), blur=60, alpha=120, dy=40)
    drop_shadow(img, yel, (int(S * 0.55), int(S * 0.13)), blur=60, alpha=120, dy=40)
    img = radial_glow(img, (int(S * 0.50), int(S * 0.62)), int(S * 0.34), (255, 240, 200), 160)
    drop_shadow(img, org, (int(S * 0.26), int(S * 0.40)), blur=80, alpha=150, dy=56)

    sparkle(img, S * 0.235, S * 0.545, S * 0.028, 235)
    sparkle(img, S * 0.76, S * 0.50, S * 0.020, 210)
    sparkle(img, S * 0.70, S * 0.755, S * 0.030, 235)
    sparkle(img, S * 0.30, S * 0.085, S * 0.016, 180)
    sparkle(img, S * 0.845, S * 0.335, S * 0.014, 170)

    img = vignette(img, 90)
    return img.resize((1024, 1024), Image.LANCZOS)


# ---------------------------------------------------------------- PondPulse

def duck(size):
    """A glossy rubber duck facing right, on a transparent layer."""
    w = size
    img = Image.new("RGBA", (w, w), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    Y = (255, 205, 42)
    YD = (225, 162, 12)
    # tail nub
    d.polygon([(w * 0.09, w * 0.56), (w * 0.30, w * 0.48), (w * 0.30, w * 0.76)], fill=Y + (255,))
    # body
    d.ellipse([w * 0.08, w * 0.44, w * 0.86, w * 0.92], fill=Y + (255,))
    # underside shade (composited, clipped to body by drawing then re-capping)
    over(img, lambda sd: sd.ellipse([w * 0.14, w * 0.70, w * 0.82, w * 0.95], fill=YD + (110,)))
    # head
    d.ellipse([w * 0.46, w * 0.10, w * 0.88, w * 0.52], fill=Y + (255,))
    # wing: darker outline ellipse with lighter fill, tilted feel
    d.ellipse([w * 0.25, w * 0.575, w * 0.57, w * 0.795], fill=YD + (255,))
    d.ellipse([w * 0.265, w * 0.59, w * 0.555, w * 0.765], fill=lerp(Y, (255, 255, 255), 0.10) + (255,))
    # beak
    d.ellipse([w * 0.82, w * 0.29, w * 1.005, w * 0.405], fill=(255, 126, 34, 255))
    d.ellipse([w * 0.82, w * 0.345, w * 0.975, w * 0.425], fill=(232, 95, 20, 255))
    # eye + catchlight
    ex, ey, er = w * 0.705, w * 0.265, w * 0.052
    d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(28, 32, 48, 255))
    d.ellipse([ex - er * 0.30, ey - er * 0.55, ex + er * 0.35, ey + er * 0.10], fill=(255, 255, 255, 255))
    # rosy cheek
    over(img, lambda cd: cd.ellipse([w * 0.585, w * 0.375, w * 0.675, w * 0.435], fill=(255, 140, 100, 110)))
    # gloss highlights
    over(img, lambda gd: gd.ellipse([w * 0.52, w * 0.135, w * 0.66, w * 0.23], fill=(255, 255, 255, 150)))
    over(img, lambda gd: gd.ellipse([w * 0.16, w * 0.475, w * 0.40, w * 0.575], fill=(255, 255, 255, 80)))
    return img


def pondpulse_icon():
    img = vertical_gradient(S, (52, 199, 226), (18, 84, 176)).convert("RGBA")
    img = radial_glow(img, (S // 2, int(S * 0.40)), int(S * 0.60), (210, 255, 255), 110)

    # soft sun glints high on the water
    over(img, lambda d: (
        d.ellipse([S * 0.06, S * 0.055, S * 0.24, S * 0.095], fill=(255, 255, 255, 55)),
        d.ellipse([S * 0.70, S * 0.115, S * 0.93, S * 0.150], fill=(255, 255, 255, 42))))

    # ripple rings around where the duck sits
    ripples = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(ripples)
    cx, cy = S * 0.50, S * 0.72
    for rw, alpha, wd in [(0.46, 190, 0.016), (0.36, 150, 0.013), (0.27, 110, 0.011)]:
        rx, ry = S * rw, S * rw * 0.34
        rd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry],
                   outline=(235, 252, 255, alpha), width=int(S * wd))
    img.alpha_composite(ripples.filter(ImageFilter.GaussianBlur(3)))

    # lily pad tucked to the left, mostly behind the duck
    pad = Image.new("RGBA", img.size, (0, 0, 0, 0))
    pd = ImageDraw.Draw(pad)
    px, py, prx, pry = S * 0.145, S * 0.615, S * 0.125, S * 0.048
    pd.pieslice([px - prx, py - pry, px + prx, py + pry], 20, 340, fill=(58, 182, 104, 255))
    pd.pieslice([px - prx * 0.8, py - pry * 0.66, px + prx * 0.8, py + pry * 0.66], 20, 340, fill=(92, 214, 134, 255))
    img.alpha_composite(pad)

    # the duck
    dk = duck(int(S * 0.72))
    drop_shadow(img, dk, (int(S * 0.14), int(S * 0.10)), blur=70, alpha=130, dy=60)

    # splash droplets off the tail (away from the beak)
    over(img, lambda d: [
        (d.ellipse([S * dx - S * r, S * dy - S * r * 1.3, S * dx + S * r, S * dy + S * r * 1.3],
                   fill=(205, 244, 255, 220)),
         d.ellipse([S * dx - S * r * 0.4, S * dy - S * r * 0.8, S * dx, S * dy - S * r * 0.2],
                   fill=(255, 255, 255, 235)))
        for dx, dy, r in [(0.145, 0.415, 0.018), (0.215, 0.33, 0.013), (0.10, 0.50, 0.011)]])

    sparkle(img, S * 0.865, S * 0.565, S * 0.026, 235)
    sparkle(img, S * 0.80, S * 0.815, S * 0.020, 200)
    sparkle(img, S * 0.30, S * 0.145, S * 0.018, 190)

    img = vignette(img, 70)
    return img.resize((1024, 1024), Image.LANCZOS)


if __name__ == "__main__":
    out1 = "/Users/rongo/Desktop/ios/Blendfall/Blendfall/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    out2 = "/Users/rongo/Desktop/ios/PondPulse/PondPulse/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    blendfall_icon().convert("RGB").save(out1)
    pondpulse_icon().convert("RGB").save(out2)
    print("wrote both icons")
