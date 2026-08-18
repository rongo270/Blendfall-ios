#!/usr/bin/env python3
"""Android adaptive-icon layers + Play Store assets for Blendfall, PondPulse, BlockBlitz.

Adaptive icons: the OS masks the 108dp canvas down to a ~72dp circle/squircle,
so backgrounds are full-bleed scenes and foreground subjects stay inside the
center ~60% (safe zone). Layers are rendered at 2048 and exported at the five
density sizes; Play assets are 512x512 icon + 1024x500 feature graphic.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_icons import (Image, ImageDraw, ImageFilter, S, lerp, vertical_gradient,
                        radial_glow, over, sparkle, glossy_block, drop_shadow,
                        vignette, duck)

DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def export_layers(bg, fg, res_dir):
    for dpi, px in DENSITIES.items():
        d = os.path.join(res_dir, f"mipmap-{dpi}")
        os.makedirs(d, exist_ok=True)
        bg.resize((px, px), Image.LANCZOS).convert("RGB").save(os.path.join(d, "ic_launcher_bg.png"))
        fg.resize((px, px), Image.LANCZOS).save(os.path.join(d, "ic_launcher_fg.png"))


def feature_graphic(bg_sq, fg_sq, path):
    """1024x500: stretch the background scene wide, subject centered."""
    W, H = 1024, 500
    bg = bg_sq.resize((W, W), Image.LANCZOS).crop((0, (W - H) // 2, W, (W - H) // 2 + H))
    sub = fg_sq.resize((int(H * 1.5), int(H * 1.5)), Image.LANCZOS)
    bg.alpha_composite(sub, ((W - sub.width) // 2, (H - sub.height) // 2))
    bg.convert("RGB").save(path)


# ---------------------------------------------------------------- Blendfall

def blendfall_bg():
    img = vertical_gradient(S, (72, 38, 158), (36, 96, 218)).convert("RGBA")
    img = radial_glow(img, (S // 2, int(S * 0.46)), int(S * 0.55), (255, 214, 120), 130)
    over(img, lambda gd: (
        gd.rounded_rectangle([-S * 0.10, S * 0.66, S * 0.22, S * 1.00], int(S * 0.06), fill=(255, 255, 255, 16)),
        gd.rounded_rectangle([S * 0.80, S * 0.06, S * 1.14, S * 0.40], int(S * 0.06), fill=(255, 255, 255, 14))))
    return vignette(img, 60)


def blendfall_fg():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # subject spans ~58% of the canvas, centered (adaptive safe zone)
    red = glossy_block(int(S * 0.185), (255, 82, 92), (176, 32, 60)).rotate(14, expand=True, resample=Image.BICUBIC)
    yel = glossy_block(int(S * 0.185), (255, 208, 64), (196, 138, 12)).rotate(-11, expand=True, resample=Image.BICUBIC)
    org = glossy_block(int(S * 0.27), (255, 148, 42), (198, 84, 10)).rotate(5, expand=True, resample=Image.BICUBIC)
    drop_shadow(img, red, (int(S * 0.265), int(S * 0.235)), blur=40, alpha=110, dy=26)
    drop_shadow(img, yel, (int(S * 0.525), int(S * 0.225)), blur=40, alpha=110, dy=26)
    drop_shadow(img, org, (int(S * 0.345), int(S * 0.40)), blur=55, alpha=140, dy=36)
    sparkle(img, S * 0.315, S * 0.485, S * 0.020, 235)
    sparkle(img, S * 0.665, S * 0.44, S * 0.015, 210)
    sparkle(img, S * 0.63, S * 0.63, S * 0.020, 235)
    return img


# ---------------------------------------------------------------- PondPulse

def pondpulse_bg():
    img = vertical_gradient(S, (52, 199, 226), (18, 84, 176)).convert("RGBA")
    img = radial_glow(img, (S // 2, int(S * 0.44)), int(S * 0.55), (210, 255, 255), 100)
    over(img, lambda d: (
        d.ellipse([S * 0.20, S * 0.14, S * 0.36, S * 0.175], fill=(255, 255, 255, 45)),
        d.ellipse([S * 0.62, S * 0.20, S * 0.80, S * 0.23], fill=(255, 255, 255, 36))))
    # ripple rings kept inside the visible mask area
    ripples = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(ripples)
    cx, cy = S * 0.50, S * 0.60
    for rw, alpha, wd in [(0.30, 170, 0.012), (0.225, 130, 0.010), (0.16, 100, 0.009)]:
        rx, ry = S * rw, S * rw * 0.36
        rd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry],
                   outline=(235, 252, 255, alpha), width=int(S * wd))
    img.alpha_composite(ripples.filter(ImageFilter.GaussianBlur(3)))
    return vignette(img, 50)


def pondpulse_fg():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dk = duck(int(S * 0.52))
    drop_shadow(img, dk, (int(S * 0.225), int(S * 0.22)), blur=50, alpha=120, dy=40)
    over(img, lambda d: [
        (d.ellipse([S * dx - S * r, S * dy - S * r * 1.3, S * dx + S * r, S * dy + S * r * 1.3],
                   fill=(205, 244, 255, 220)),
         d.ellipse([S * dx - S * r * 0.4, S * dy - S * r * 0.8, S * dx, S * dy - S * r * 0.2],
                   fill=(255, 255, 255, 235)))
        for dx, dy, r in [(0.235, 0.42, 0.013), (0.29, 0.35, 0.010)]])
    sparkle(img, S * 0.72, S * 0.545, S * 0.018, 230)
    sparkle(img, S * 0.30, S * 0.645, S * 0.014, 200)
    return img


# ---------------------------------------------------------------- BlockBlitz

BB = {"sky": (79, 195, 247), "sky_d": (21, 118, 170),
      "purple": (171, 71, 188), "purple_d": (106, 27, 128),
      "green": (102, 187, 106), "green_d": (46, 115, 52),
      "amber": (255, 179, 0), "amber_d": (176, 108, 0)}


def blockblitz_bg():
    img = vertical_gradient(S, (46, 52, 110), (16, 20, 48)).convert("RGBA")
    img = radial_glow(img, (S // 2, int(S * 0.45)), int(S * 0.55), (255, 224, 130), 110)
    # faint grid lines, like the 8x8 board
    over(img, lambda d: [
        d.line([(S * x / 8, 0), (S * x / 8, S)], fill=(255, 255, 255, 10), width=int(S * 0.004))
        for x in range(1, 8)] + [
        d.line([(0, S * y / 8), (S, S * y / 8)], fill=(255, 255, 255, 10), width=int(S * 0.004))
        for y in range(1, 8)])
    return vignette(img, 60)


def blockblitz_subject(img, scale=1.0, cx=0.5, cy=0.5):
    """2x2 glossy block cluster with a lightning bolt across it."""
    b = int(S * 0.20 * scale)
    gap = int(S * 0.012 * scale)
    x0 = int(S * cx - b - gap // 2)
    y0 = int(S * cy - b - gap // 2)
    for (col, dcol), (ox, oy) in zip(
        [(BB["sky"], BB["sky_d"]), (BB["purple"], BB["purple_d"]),
         (BB["green"], BB["green_d"]), (BB["amber"], BB["amber_d"])],
        [(0, 0), (b + gap, 0), (0, b + gap), (b + gap, b + gap)],
    ):
        blk = glossy_block(b, col, dcol)
        drop_shadow(img, blk, (x0 + ox, y0 + oy), blur=40, alpha=120, dy=24)
    # the "blitz" bolt, glossy yellow-white with a dark edge
    w = S * scale
    bolt = [(0.545, 0.30), (0.42, 0.525), (0.495, 0.525), (0.455, 0.71),
            (0.60, 0.475), (0.52, 0.475)]
    pts = [((S * cx) + (px - 0.5) * w * 0.72, (S * cy) + (py - 0.5) * w * 0.72) for px, py in bolt]
    over(img, lambda d: d.polygon(pts, fill=(20, 24, 52, 160)))
    pts2 = [(x, y - S * 0.008 * scale) for x, y in pts]
    over(img, lambda d: d.polygon(pts2, fill=(255, 234, 90, 255)))
    sparkle(img, S * (cx - 0.20), S * (cy + 0.16), S * 0.018 * scale, 230)
    sparkle(img, S * (cx + 0.21), S * (cy - 0.17), S * 0.014 * scale, 210)
    return img


def blockblitz_fg():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return blockblitz_subject(img, scale=1.32)


def blockblitz_full():
    """Play Store 512: full composition, subject larger than the masked launcher."""
    img = blockblitz_bg()
    img = blockblitz_subject(img, scale=2.1)
    return img


APPS = {
    "Blendfall": (blendfall_bg, blendfall_fg, None),
    "PondPulse": (pondpulse_bg, pondpulse_fg, None),
    "BlockBlitz": (blockblitz_bg, blockblitz_fg, blockblitz_full),
}

if __name__ == "__main__":
    base = os.path.expanduser("~/AndroidStudioProjects")
    ios_icons = {
        "Blendfall": os.path.expanduser("~/Desktop/ios/Blendfall/Blendfall/Assets.xcassets/AppIcon.appiconset/AppIcon.png"),
        "PondPulse": os.path.expanduser("~/Desktop/ios/PondPulse/PondPulse/Assets.xcassets/AppIcon.appiconset/AppIcon.png"),
    }
    for app, (bg_fn, fg_fn, full_fn) in APPS.items():
        res = os.path.join(base, app, "app/src/main/res")
        bg, fg = bg_fn(), fg_fn()
        export_layers(bg, fg, res)
        assets = os.path.join(base, app, "PlayStore_Assets")
        os.makedirs(assets, exist_ok=True)
        # Play icon: reuse the finished iOS 1024 art where it exists, else compose
        if app in ios_icons:
            Image.open(ios_icons[app]).resize((512, 512), Image.LANCZOS).save(
                os.path.join(assets, "icon_512.png"))
        else:
            full_fn().resize((512, 512), Image.LANCZOS).convert("RGB").save(
                os.path.join(assets, "icon_512.png"))
        feature_graphic(bg, fg, os.path.join(assets, "feature_graphic_1024x500.png"))
        print("done", app)
