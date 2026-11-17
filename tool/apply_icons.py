#!/usr/bin/env python3
"""
يرسم أيقونة «البيان» (المصحف المفتوح بالسطرين المتطابقين) ويضعها في مشروعي
iOS وأندرويد بعد `flutter create`. يُشغَّل في البناء الآلي:
  python3 tool/apply_icons.py ios|android
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
GOLD = (217, 182, 106)
HI = (246, 223, 160)


def bezier(p0, p1, p2, p3, n=60):
    pts = []
    for i in range(n + 1):
        t = i / n
        mt = 1 - t
        x = mt**3 * p0[0] + 3 * mt**2 * t * p1[0] + 3 * mt * t**2 * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt**2 * t * p1[1] + 3 * mt * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def quad(p0, p1, p2, n=40):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1])
            for t in (i / n for i in range(n + 1))]


def draw_icon(size: int = 1024) -> Image.Image:
    ss = 4
    S = size * ss
    img = Image.new("RGB", (S, S))
    # خلفية متدرّجة قطرية
    top, bot = (22, 105, 90), (8, 41, 31)
    grad = Image.new("RGB", (2, 2))
    grad.putpixel((0, 0), top)
    grad.putpixel((1, 0), tuple((a + b) // 2 for a, b in zip(top, bot)))
    grad.putpixel((0, 1), tuple((a + b) // 2 for a, b in zip(top, bot)))
    grad.putpixel((1, 1), bot)
    img.paste(grad.resize((S, S), Image.BILINEAR))
    d = ImageDraw.Draw(img, "RGBA")

    k = S * 0.78 / 120
    ox = oy = S * 0.11

    def P(x, y):
        return (ox + x * k, oy + y * k)

    for right in (False, True):
        fx = (lambda v: 120 - v) if right else (lambda v: v)
        pts = [P(60, 92)]
        pts += [P(*q) for q in bezier((60, 92), (fx(48), 84), (fx(34), 82), (fx(20), 84))]
        pts += [P(fx(20), 40)]
        pts += [P(*q) for q in bezier((fx(20), 40), (fx(34), 38), (fx(48), 40), (60, 48))]
        d.polygon(pts, fill=GOLD + (26,))
        d.line(pts + [pts[0]], fill=GOLD, width=int(3.2 * k), joint="curve")
        for y, h in ((56, False), (66, True), (76, False)):
            line = [P(*q) for q in bezier((fx(28), y), (fx(38), y - 1), (fx(47), y + 1), (fx(53), y + 4))]
            d.line(line, fill=HI if h else GOLD + (140,), width=int((3.6 if h else 2.2) * k))
    arc = [P(*q) for q in quad((53, 70), (60, 61), (67, 70))]
    for i in range(0, len(arc) - 2, 6):
        d.line(arc[i:i + 3], fill=HI, width=int(1.8 * k))
    # كلمة «البيان» فوق المصحف (مكان النجمة سابقًا)
    font = ImageFont.truetype(str(ROOT / "assets" / "fonts" / "ui" / "ArefRuqaa-Bold.ttf"),
                              int(26 * k), layout_engine=ImageFont.Layout.RAQM)
    word = "البيان"
    x0, y0, x1, y1 = d.textbbox((0, 0), word, font=font, direction="rtl")
    cx, cy = P(60, 22)
    d.text((cx - (x0 + x1) / 2, cy - (y0 + y1) / 2), word, font=font, fill=HI, direction="rtl")
    return img.resize((size, size), Image.LANCZOS)


def ios(icon: Image.Image) -> None:
    folder = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for f in folder.glob("*.png"):
        f.unlink()
    icon.save(folder / "icon-1024.png")
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "icon-1024.png", "idiom": "universal",
                    "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2))
    print("✓ أيقونة iOS")


def android(icon: Image.Image) -> None:
    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for name, px in sizes.items():
        out = res / f"mipmap-{name}" / "ic_launcher.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        icon.resize((px, px), Image.LANCZOS).save(out)
    print("✓ أيقونات أندرويد")


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "preview"
    # الأيقونة مرسومة مسبقًا (كلمة «البيان» تحتاج libraqm لتشكيل الحروف،
    # وقد لا تتوفر في جهاز البناء). لإعادة رسمها: python3 tool/apply_icons.py render
    pre = ROOT / "assets" / "icon" / "app_icon_1024.png"
    if target == "render":
        pre.parent.mkdir(parents=True, exist_ok=True)
        draw_icon().save(pre)
        print(f"✓ {pre}")
        sys.exit(0)
    img = Image.open(pre).convert("RGB") if pre.exists() else draw_icon()
    if target == "ios":
        ios(img)
    elif target == "android":
        android(img)
    else:
        img.save(ROOT / "build" / "icon-preview.png") if (ROOT / "build").exists() else img.save("icon-preview.png")
