#!/usr/bin/env python3
"""
البيان — سكربت تجهيز بيانات المصحف والمتشابهات.

يجلب المصادر من GitHub بنسخ مثبّتة (commit محدد)، ثم يولّد ملفات التطبيق
في مجلد assets/ ويتحقق منها قبل الكتابة. لا يُكتب أي نص قرآني يدويًا:
النص يُعرض بخطوط مجمع الملك فهد (QPC V2) عبر رموز الكلمات (glyphs)
الموجودة في بيانات التخطيط.

المصادر:
  1) تخطيط صفحات مصحف المدينة (QPC V2) سطرًا بسطر:
     https://github.com/zonetecde/mushaf-layout
  2) خطوط مجمع الملك فهد الأصلية QCF V2 (خط لكل صفحة):
     https://github.com/nuqayah/qpc-fonts
  3) بيانات المتشابهات (CC0) — مبنية على عمل القارئ إدريس العاصم رحمه الله:
     https://github.com/Waqar144/Quran_Mutashabihat_Data

التشغيل:
  pip install fonttools
  python3 tool/build_data.py

المخرجات:
  assets/fonts/qcf2/p001.ttf … p604.ttf, bsml.ttf
  assets/fonts/ui/Cairo.ttf, ArefRuqaa-Bold.ttf
  assets/quran/pages.json         صفحات المصحف سطرًا بسطر
  assets/quran/meta.json          السور والأجزاء والأحزاب
  assets/quran/mutashabihat.json  مجموعات المتشابه وكلمات الاختلاف
"""

from __future__ import annotations

import difflib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / ".cache"
ASSETS = ROOT / "assets"

SOURCES = {
    "layout": ("https://github.com/zonetecde/mushaf-layout",
               "421e9eaa991897ecd50d7abb79160651a45976d3"),
    "muts": ("https://github.com/Waqar144/Quran_Mutashabihat_Data",
             "7b259fc73669701695df1e9902215972255a18ee"),
    # خطوط مجمع الملك فهد الأصلية QCF V2 (خط لكل صفحة + خط البسملة)
    "fonts": ("https://github.com/nuqayah/qpc-fonts",
              "8a4f39d563ea69c994416a1692827e38156c548d"),
    # خطوط الواجهة (رخصة OFL): Cairo والرقعة
    "ui": ("https://github.com/google/fonts",
           "cc39c4c2c304bc368c9b7c311ea2bcc6013299fe"),
}
SPARSE = {"layout": ["mushaf/QPC2/", "src/data/"], "fonts": ["mushaf-v2/"],
          "ui": ["ofl/cairo/", "ofl/arefruqaa/"]}

TOTAL_PAGES = 604
TOTAL_AYAHS = 6236

# بدايات الأجزاء (سورة، آية) — من حزمة quran-meta (رواية حفص).
JUZ_STARTS = [
    (1, 1), (2, 142), (2, 253), (3, 93), (4, 24), (4, 148), (5, 82), (6, 111),
    (7, 88), (8, 41), (9, 93), (11, 6), (12, 53), (15, 1), (17, 1), (18, 75),
    (21, 1), (23, 1), (25, 21), (27, 56), (29, 46), (33, 31), (36, 28),
    (39, 32), (41, 47), (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
]

# بدايات أرباع الأحزاب (240 ربعًا) — من حزمة quran-meta.
RUB_STARTS = [
    (1,1),(2,26),(2,44),(2,60),(2,75),(2,92),(2,106),(2,124),(2,142),(2,158),(2,177),(2,189),
    (2,203),(2,219),(2,233),(2,243),(2,253),(2,263),(2,272),(2,283),(3,15),(3,33),(3,52),(3,75),
    (3,93),(3,113),(3,133),(3,153),(3,171),(3,186),(4,1),(4,12),(4,24),(4,36),(4,58),(4,74),
    (4,88),(4,100),(4,114),(4,135),(4,148),(4,163),(5,1),(5,12),(5,27),(5,41),(5,51),(5,67),
    (5,82),(5,97),(5,109),(6,13),(6,36),(6,59),(6,74),(6,95),(6,111),(6,127),(6,141),(6,151),
    (7,1),(7,31),(7,47),(7,65),(7,88),(7,117),(7,142),(7,156),(7,171),(7,189),(8,1),(8,22),
    (8,41),(8,61),(9,1),(9,19),(9,34),(9,46),(9,60),(9,75),(9,93),(9,111),(9,122),(10,11),
    (10,26),(10,53),(10,71),(10,90),(11,6),(11,24),(11,41),(11,61),(11,84),(11,108),(12,7),(12,30),
    (12,53),(12,77),(12,101),(13,5),(13,19),(13,35),(14,10),(14,28),(15,1),(15,50),(16,1),(16,30),
    (16,51),(16,75),(16,90),(16,111),(17,1),(17,23),(17,50),(17,70),(17,99),(18,17),(18,32),(18,51),
    (18,75),(18,99),(19,22),(19,59),(20,1),(20,55),(20,83),(20,111),(21,1),(21,29),(21,51),(21,83),
    (22,1),(22,19),(22,38),(22,60),(23,1),(23,36),(23,75),(24,1),(24,21),(24,35),(24,53),(25,1),
    (25,21),(25,53),(26,1),(26,52),(26,111),(26,181),(27,1),(27,27),(27,56),(27,82),(28,12),(28,29),
    (28,51),(28,76),(29,1),(29,26),(29,46),(30,1),(30,31),(30,54),(31,22),(32,11),(33,1),(33,18),
    (33,31),(33,51),(33,60),(34,10),(34,24),(34,46),(35,15),(35,41),(36,28),(36,60),(37,22),(37,83),
    (37,145),(38,21),(38,52),(39,8),(39,32),(39,53),(40,1),(40,21),(40,41),(40,66),(41,9),(41,25),
    (41,47),(42,13),(42,27),(42,51),(43,24),(43,57),(44,17),(45,12),(46,1),(46,21),(47,10),(47,33),
    (48,18),(49,1),(49,14),(50,27),(51,31),(52,24),(53,26),(54,9),(55,1),(56,1),(56,75),(57,16),
    (58,1),(58,14),(59,11),(60,7),(62,1),(63,4),(65,1),(66,1),(67,1),(68,1),(69,1),(70,19),
    (72,1),(73,20),(75,1),(76,19),(78,1),(80,1),(82,1),(84,1),(87,1),(90,1),(94,1),(100,9),
]

ARABIC_DIGITS = re.compile("[%s-%s]+" % (chr(0x0660), chr(0x0669)))
# تشكيل وعلامات وقف وحروف صغيرة وتطويل — تُحذف عند مقارنة الكلمات فقط.
_MARK_RANGES = [(0x0610, 0x061A), (0x064B, 0x065F), (0x0670, 0x0670),
                (0x06D6, 0x06ED), (0x0640, 0x0640), (0x08D3, 0x08FF)]
MARKS = re.compile("[" + "".join("%s-%s" % (chr(a), chr(b))
                                 for a, b in _MARK_RANGES) + "]")


def log(msg: str) -> None:
    print(msg, flush=True)


def fail(msg: str) -> None:
    print(f"✗ خطأ: {msg}", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------- جلب المصادر
def fetch(name: str) -> Path:
    url, commit = SOURCES[name]
    dest = CACHE / name
    if (dest / ".git").exists():
        head = subprocess.run(["git", "-C", str(dest), "rev-parse", "HEAD"],
                              capture_output=True, text=True).stdout.strip()
        if head == commit:
            return dest
        shutil.rmtree(dest)
    log(f"• جلب {name} …")
    dest.mkdir(parents=True, exist_ok=True)
    run = lambda *a: subprocess.run(["git", "-C", str(dest), *a], check=True,
                                    capture_output=True)
    run("init", "-q")
    run("remote", "add", "origin", url)
    if name in SPARSE:
        run("config", "core.sparseCheckout", "true")
        (dest / ".git" / "info" / "sparse-checkout").write_text(
            "\n".join(SPARSE[name]) + "\n")
        run("fetch", "-q", "--depth", "1", "--filter=blob:none", "origin", commit)
    else:
        run("fetch", "-q", "--depth", "1", "origin", commit)
    run("checkout", "-q", "FETCH_HEAD")
    return dest


# ---------------------------------------------------------------- الخطوط
def build_fonts(fonts: Path) -> None:
    src = fonts / "mushaf-v2"
    out = ASSETS / "fonts" / "qcf2"
    out.mkdir(parents=True, exist_ok=True)
    for p in range(1, TOTAL_PAGES + 1):
        ttf = src / f"QCF2{p:03d}.ttf"
        if not ttf.exists():
            fail(f"خط الصفحة {p} غير موجود")
        merge_overlaps(ttf, out / f"p{p:03d}.ttf")
    merge_overlaps(src / "QCF2BSML.ttf", out / "bsml.ttf")
    log(f"✓ الخطوط: {TOTAL_PAGES} خط صفحة + خط البسملة (بعد دمج الخطوط المتداخلة)")


def merge_overlaps(src: Path, dst: Path) -> None:
    """
    بعض حروف خطوط المجمع مرسومة بأشكال متداخلة (مثل ذيل النون فوق جسم الكلمة).
    محرّك الرسم في iOS يرسم مناطق التداخل باهتة (رمادية)، فندمج الأشكال المتداخلة
    في شكل واحد. الشكل الناتج مطابق بصريًا للأصل (اتحاد هندسي لنفس المنطقة)،
    ولا يغيّر أي حرف أو موضع.
    """
    from fontTools.ttLib import TTFont
    from fontTools.ttLib.removeOverlaps import removeOverlaps

    font = TTFont(str(src))
    removeOverlaps(font, removeHinting=True)
    font.save(str(dst))


def build_ui_fonts(ui: Path) -> None:
    out = ASSETS / "fonts" / "ui"
    out.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ui / "ofl" / "cairo" / "Cairo[slnt,wght].ttf", out / "Cairo.ttf")
    shutil.copyfile(ui / "ofl" / "arefruqaa" / "ArefRuqaa-Bold.ttf",
                    out / "ArefRuqaa-Bold.ttf")
    log("✓ خطوط الواجهة: Cairo والرقعة")


def check_glyphs(pages) -> None:
    """كل رمز في بيانات الصفحة يجب أن يكون موجودًا في خط تلك الصفحة."""
    from fontTools.ttLib import TTFont

    out = ASSETS / "fonts" / "qcf2"
    bsml = TTFont(str(out / "bsml.ttf"), lazy=True).getBestCmap()
    for pg in pages:
        cmap = TTFont(str(out / f"p{pg['p']:03d}.ttf"), lazy=True).getBestCmap()
        for ln in pg["l"]:
            if ln["t"] == "x":
                chars = "".join(w[3] + w[4] for w in ln["w"])
                table = cmap
            elif ln["t"] == "b":
                chars, table = ln["g"], bsml
            else:
                continue
            for ch in chars.replace(" ", ""):
                if ord(ch) not in table:
                    fail(f"رمز مفقود U+{ord(ch):04X} في خط الصفحة {pg['p']}")
    log("✓ كل رموز الكلمات موجودة في خطوط صفحاتها")


# ---------------------------------------------------------------- الصفحات
def build_pages(layout: Path):
    """يرجع (pages, ayah_words, ayah_page, surah_names)."""
    pages = []
    ayah_words: dict[tuple[int, int], list] = {}  # (s,a) -> [(w, normalized)]
    ayah_page: dict[tuple[int, int], int] = {}
    surah_names: dict[int, str] = {}

    for p in range(1, TOTAL_PAGES + 1):
        data = json.loads((layout / "mushaf" / "QPC2" / f"page-{p:03d}.json")
                          .read_text(encoding="utf-8"))
        if data["page"] != p:
            fail(f"رقم الصفحة غير مطابق في الملف {p}")
        lines = []
        for ln in data["lines"]:
            t = ln["type"]
            if t == "surah-header":
                s = int(ln["surah"])
                surah_names[s] = ln["text"].replace("سورة", "").strip()
                lines.append({"t": "h", "s": s})
            elif t == "basmala":
                lines.append({"t": "b", "g": ln["qpcV2"]})
            elif t == "text":
                words = []
                for w in ln["words"]:
                    s, a, i = (int(x) for x in w["location"].split(":"))
                    text, glyph = w["word"], w["qpcV2"]
                    has_num = bool(ARABIC_DIGITS.search(text))
                    plain = ARABIC_DIGITS.sub("", text).strip()
                    if has_num and not plain:
                        gw, gm = "", glyph            # علامة آية في سطر مستقل
                    elif has_num:
                        if " " not in glyph:
                            fail(f"تعذّر فصل علامة الآية {s}:{a}:{i} ص{p}")
                        gw, gm = glyph.rsplit(" ", 1)
                    else:
                        gw, gm = glyph, ""
                    if plain:
                        norm = MARKS.sub("", plain).replace("ٱ", "ا").replace(" ", "")
                        ayah_words.setdefault((s, a), []).append((i, norm))
                    ayah_page.setdefault((s, a), p)
                    words.append([s, a, i, gw, gm])
                lines.append({"t": "x", "w": words})
            else:
                fail(f"نوع سطر غير معروف: {t} ص{p}")
        pages.append({"p": p, "l": lines})
    return pages, ayah_words, ayah_page, surah_names


def validate_pages(pages, ayah_words, ayah_page) -> None:
    if len(pages) != TOTAL_PAGES:
        fail("عدد الصفحات غير صحيح")
    for pg in pages:
        n = len(pg["l"])
        if pg["p"] > 2 and n != 15:
            fail(f"الصفحة {pg['p']} فيها {n} سطرًا بدل 15")
    if len(ayah_words) != TOTAL_AYAHS:
        fail(f"عدد الآيات {len(ayah_words)} بدل {TOTAL_AYAHS}")
    for key, ws in ayah_words.items():
        idx = [i for i, _ in ws]
        if idx != list(range(1, len(idx) + 1)):
            fail(f"ترتيب كلمات الآية {key} غير متسلسل")
    for s, a in JUZ_STARTS + RUB_STARTS:
        if (s, a) not in ayah_page:
            fail(f"بداية جزء/ربع غير موجودة {s}:{a}")
    total_words = sum(len(v) for v in ayah_words.values())
    log(f"✓ الصفحات: {len(pages)} صفحة، {len(ayah_words)} آية، {total_words} كلمة")


# ---------------------------------------------------------------- الفهارس
def build_meta(layout: Path, ayah_words, ayah_page, surah_names):
    info = json.loads((layout / "src" / "data" / "surahs.json")
                      .read_text(encoding="utf-8"))
    surahs = []
    for s in range(1, 115):
        count = sum(1 for (ss, _) in ayah_words if ss == s)
        meta = info[s - 1]
        if meta["id"] != s or meta["totalAyah"] != count:
            fail(f"عدد آيات سورة {s} غير مطابق ({count} / {meta['totalAyah']})")
        surahs.append({
            "n": s,
            "name": surah_names.get(s, meta["arabic"]),
            "ayahs": count,
            "page": ayah_page[(s, 1)],
            "place": "مكية" if meta["revelationPlace"] == "Mecca" else "مدنية",
        })
    juz = [{"n": i + 1, "s": s, "a": a, "page": ayah_page[(s, a)]}
           for i, (s, a) in enumerate(JUZ_STARTS)]
    rub = [{"n": i + 1, "s": s, "a": a, "page": ayah_page[(s, a)]}
           for i, (s, a) in enumerate(RUB_STARTS)]
    log("✓ الفهارس: 114 سورة، 30 جزءًا، 240 ربعًا")
    return {"surahs": surahs, "juz": juz, "rub": rub}


# ---------------------------------------------------------------- المتشابهات
def build_mutashabihat(muts_dir: Path, ayah_words):
    keys = sorted(ayah_words)                      # الترقيم المطلق يبدأ من 0
    raw = json.loads((muts_dir / "mutashabiha_data.json").read_text(encoding="utf-8"))

    def member(v) -> list[tuple[int, int]]:
        arr = v if isinstance(v, list) else [v]
        for n in arr:
            if not 0 <= n < TOTAL_AYAHS:
                fail(f"رقم آية خارج النطاق في المتشابهات: {n}")
        return [keys[n] for n in arr]

    def words_of(m):
        return [(s, a, i, norm) for (s, a) in m for (i, norm) in ayah_words[(s, a)]]

    def diff(x, y):
        """كلمات الاختلاف بين عضوين، محصورة في منطقة التشابه.

        نحدد منطقة التشابه في كل آية بالمقاطع المتطابقة (كلمتان فأكثر)،
        ونأخذ كلمات الاختلاف داخلها مع كلمة واحدة قبلها وبعدها (موضع الافتراق).
        ما خارج المنطقة نص مختلف أصلًا فلا يُلوَّن، حتى لا تتلوّن الآية كلها.
        """
        sm = difflib.SequenceMatcher(None, [w[3] for w in x], [w[3] for w in y],
                                     autojunk=False)
        blocks = [b for b in sm.get_matching_blocks() if b.size >= 2] or \
                 [b for b in sm.get_matching_blocks() if b.size >= 1]
        if not blocks:
            return set(), set()
        ax0 = max(blocks[0].a - 1, 0)
        ax1 = min(blocks[-1].a + blocks[-1].size + 1, len(x))
        by0 = max(blocks[0].b - 1, 0)
        by1 = min(blocks[-1].b + blocks[-1].size + 1, len(y))
        dx, dy = set(), set()
        for op, i1, i2, j1, j2 in sm.get_opcodes():
            if op != "equal":
                dx.update(i for i in range(i1, i2) if ax0 <= i < ax1)
                dy.update(j for j in range(j1, j2) if by0 <= j < by1)
        return dx, dy

    # المصدر يكرر المجموعة نفسها من منظور كل آية فيها (أ↔ب↔ج)، وأحيانًا
    # مجموعة جزئية داخل مجموعة أكبر. نُبقي مجموعة واحدة لكل مجموعة مواضع،
    # ونحذف المجموعة إذا كانت كل مواضعها داخل مجموعة أكبر.
    cand = []
    for juz in sorted(raw, key=int):
        for g in raw[juz]:
            members = [member(g["src"]["ayah"])] + [member(m["ayah"]) for m in g["muts"]]
            key = frozenset(tuple(m) for m in members)
            cand.append((key, members, g))
    keep, seen = [], set()
    for key, members, g in cand:
        if key in seen or any(key < other for other, _, _ in cand):
            continue
        seen.add(key)
        keep.append((members, g))
    log(f"  حذف التكرار: {len(cand)} → {len(keep)} مجموعة")

    groups, by_ayah = [], {}
    for members, g in keep:
        wl = [words_of(m) for m in members]
        src_diff, member_diffs = set(), []
        for other in wl[1:]:
            dx, dy = diff(wl[0], other)
            src_diff |= dx
            member_diffs.append(sorted(dy))
        diffs = [sorted(src_diff)] + member_diffs
        gid = len(groups)
        groups.append({
            "m": [[f"{s}:{a}" for s, a in m] for m in members],
            "d": [[f"{wl[k][j][0]}:{wl[k][j][1]}:{wl[k][j][2]}" for j in diffs[k]]
                  for k in range(len(members))],
            "c": g.get("ctx", 0),
        })
        for m in members:
            for s, a in m:
                lst = by_ayah.setdefault(f"{s}:{a}", [])
                if gid not in lst:
                    lst.append(gid)
    log(f"✓ المتشابهات: {len(groups)} مجموعة، تشمل {len(by_ayah)} آية")
    return {"groups": groups, "byAyah": by_ayah}


def spot_check(muts) -> None:
    """فحص يدوي معروف: البقرة 48 مع 123 يجب أن تكونا في مجموعة واحدة."""
    a, b = set(muts["byAyah"].get("2:48", [])), set(muts["byAyah"].get("2:123", []))
    if not (a & b):
        fail("الفحص المرجعي فشل: البقرة 48 و123 ليستا في مجموعة واحدة")
    log("✓ الفحص المرجعي: البقرة 48 ↔ 123")


def write_json(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")),
                    encoding="utf-8")
    log(f"  ← {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KB)")


def main() -> None:
    layout = fetch("layout")
    muts_dir = fetch("muts")
    fonts = fetch("fonts")
    ui = fetch("ui")
    build_fonts(fonts)
    build_ui_fonts(ui)
    pages, ayah_words, ayah_page, surah_names = build_pages(layout)
    validate_pages(pages, ayah_words, ayah_page)
    check_glyphs(pages)
    meta = build_meta(layout, ayah_words, ayah_page, surah_names)
    muts = build_mutashabihat(muts_dir, ayah_words)
    spot_check(muts)
    write_json(ASSETS / "quran" / "pages.json", pages)
    write_json(ASSETS / "quran" / "meta.json", meta)
    write_json(ASSETS / "quran" / "mutashabihat.json", muts)
    log("✓ اكتمل التجهيز")


if __name__ == "__main__":
    main()
