#!/usr/bin/env python3
"""
يقتطع زخارف مصحف المدينة من صور الطبعة الرسمية (مجمع الملك فهد، الحجم العادي
الأخضر ١٤٤١هـ — النسخة الرقمية المجانية المسموح باستخدامها في البرمجيات):
  - إطار الصفحة  → assets/mushaf/frame.png (وسطه شفاف) + frame.json (حدود منطقة النص)
  - ترويسات السور → assets/mushaf/surah/NNN.png
الاستعمال (في البناء الآلي):
  python3 tool/extract_mushaf_art.py <مجلد صور الصفحات pNNN.png> <مجلد الإخراج>
صورة صفحة المصحف رقم N هي صفحة PDF رقم N+OFFSET.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

Image.MAX_IMAGE_PIXELS = None
OFFSET = 3
FRAME_PAGE = 50
FRAME_W = 1400
BANNER_W = 1200
ROOT = Path(__file__).resolve().parent.parent


def clusters(idx):
    out, start, prev = [], None, None
    for v in idx:
        if start is None:
            start = prev = v
        elif v - prev > 4:
            out.append((start, prev))
            start = v
        prev = v
    if start is not None:
        out.append((start, prev))
    return out


def geometry(img: Image.Image):
    g = np.asarray(img.convert("L"))
    dark = g < 70
    nonwhite = g < 240
    # خطّا الإطار الأسودان المزدوجان: الأول الخارجي والثاني الداخلي في كل جهة
    cols = clusters(np.where(dark.mean(0) > 0.3)[0])
    rows = clusters(np.where(dark.mean(1) > 0.4)[0])
    if len(cols) < 4 or len(rows) < 4:
        raise RuntimeError(f"تعذّر تحديد الإطار: cols={cols} rows={rows}")
    inner = (cols[1][1] + 1, rows[1][1] + 1, cols[-2][0] - 1, rows[-2][0] - 1)
    br = np.where(nonwhite.mean(1) > 0.5)[0]
    bc = np.where(nonwhite.mean(0) > 0.5)[0]
    band = (int(bc[0]), int(br[0]), int(bc[-1]) + 1, int(br[-1]) + 1)
    return band, tuple(int(v) for v in inner)


def page_img(src: Path, n: int) -> Image.Image:
    hits = sorted(src.glob(f"p{n + OFFSET}-*.png")) or sorted(src.glob(f"p{n + OFFSET}.png"))
    if not hits:
        raise FileNotFoundError(f"صورة صفحة {n} غير موجودة")
    return Image.open(hits[0]).convert("RGB")


def quantize(im: Image.Image) -> Image.Image:
    alpha = im.getchannel("A") if im.mode == "RGBA" else None
    q = im.convert("RGB").quantize(colors=96, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    if alpha is None:
        return q
    rgba = q.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


def make_frame(src: Path, out: Path) -> dict:
    img = page_img(src, FRAME_PAGE)
    band, inner = geometry(img)
    x0, y0, x1, y1 = band
    crop = img.crop(band).convert("RGBA")
    w, h = crop.size
    # وسط الإطار شفاف
    ix0, iy0, ix1, iy1 = inner[0] - x0, inner[1] - y0, inner[2] - x0, inner[3] - y0
    a = np.asarray(crop).copy()
    a[iy0:iy1, ix0:ix1, 3] = 0
    # البياض خارج الحافة المتموجة شفاف (تعبئة من الأطراف)
    mask = Image.fromarray(((a[:, :, :3].min(2) > 235) & (a[:, :, 3] > 0)).astype(np.uint8) * 255)
    for seed in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if mask.getpixel(seed) == 255:
            ImageDraw.floodfill(mask, seed, 128)
    a[np.asarray(mask) == 128, 3] = 0
    frame = Image.fromarray(a)
    scale = FRAME_W / w
    frame = frame.resize((FRAME_W, round(h * scale)), Image.LANCZOS)
    quantize(frame).save(out / "frame.png", optimize=True)
    pad = 0.0091 * (iy1 - iy0)
    meta = {
        "aspect": w / h,
        "inner": [ix0 / w, iy0 / h, ix1 / w, iy1 / h],
        "pad": pad / (iy1 - iy0),
    }
    (out / "frame.json").write_text(json.dumps(meta, indent=1))
    return meta


def make_banners(src: Path, out: Path) -> list[Path]:
    heads = json.loads((ROOT / "tool" / "surah_headers.json").read_text())
    (out / "surah").mkdir(parents=True, exist_ok=True)
    made = []
    for hd in heads:
        if hd["n"] != 15:
            continue  # الفاتحة وأول البقرة بتخطيط خاص
        img = page_img(src, hd["p"])
        _, (ix0, iy0, ix1, iy1) = geometry(img)
        ih = iy1 - iy0
        pad = 0.0091 * ih
        slot = (ih - 2 * pad) / 15
        expect = iy0 + pad + hd["i"] * slot
        # الترويسة شريط أخضر: نبحث عن أقرب شريط أخضر بارتفاع سطر تقريبًا للموضع المتوقع
        a = np.asarray(img.crop((ix0, iy0, ix1, iy1))).astype(int)
        green = (a[:, :, 1] > a[:, :, 0] + 12) & (a[:, :, 1] > a[:, :, 2] + 8)
        frac = green.mean(1)
        bands, st = [], None
        for y, v in enumerate(frac > 0.35):
            if v and st is None:
                st = y
            if (not v or y == len(frac) - 1) and st is not None:
                if y - st > slot * 0.5:
                    bands.append((st + iy0, y + iy0))
                st = None
        if not bands:
            print(f"⚠️ لا شريط أخضر لسورة {hd['s']} (صفحة {hd['p']})")
            continue
        top, bot = min(bands, key=lambda b: abs(b[0] - expect))
        if abs(top - expect) > slot * 1.6:
            print(f"⚠️ الشريط بعيد عن المتوقع لسورة {hd['s']}")
        m = round(slot * 0.04)  # إطار الشريط الداكن فوقه وتحته
        b = img.crop((ix0 + 2, top - m, ix1 - 2, bot + m))
        g = np.asarray(b.convert("L"))
        cols = np.where((g < 200).mean(0) > 0.15)[0]
        if len(cols):
            b = b.crop((int(cols[0]), 0, int(cols[-1]) + 1, b.height))
        b = b.resize((BANNER_W, round(b.height * BANNER_W / b.width)), Image.LANCZOS)
        p = out / "surah" / f"{hd['s']:03d}.png"
        quantize(b).save(p, optimize=True)
        made.append(p)
    return made


def contact(out: Path, made: list[Path]) -> None:
    thumbs = [Image.open(p).convert("RGB") for p in made]
    tw, th = 600, 70
    cols = 2
    sheet = Image.new("RGB", (cols * (tw + 10), ((len(thumbs) + 1) // cols) * (th + 10)), "white")
    for k, t in enumerate(thumbs):
        t = t.resize((tw, th))
        sheet.paste(t, ((k % cols) * (tw + 10), (k // cols) * (th + 10)))
    sheet.save(out / "contact.jpg", quality=80)


def main() -> None:
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    meta = make_frame(src, out)
    print("✓ الإطار", meta)
    made = make_banners(src, out)
    print(f"✓ ترويسات السور: {len(made)}")
    contact(out, made)


if __name__ == "__main__":
    main()
