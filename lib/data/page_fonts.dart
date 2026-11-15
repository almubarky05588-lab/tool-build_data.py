import 'package:flutter/services.dart';

/// تحميل خطوط صفحات المصحف (QCF V2) عند الحاجة.
/// لكل صفحة خط مستقل؛ يُحمَّل مرة واحدة ثم يبقى متاحًا.
class PageFonts {
  static final Map<int, Future<void>> _loading = {};
  static final Set<int> _ready = {};
  static Future<void>? _bsml;

  static String family(int page) => 'qcf_p${page.toString().padLeft(3, '0')}';
  static const bsmlFamily = 'qcf_bsml';

  static bool isReady(int page) => _ready.contains(page);

  static Future<void> ensure(int page) {
    if (page < 1 || page > 604) return Future.value();
    return _loading.putIfAbsent(page, () async {
      final name = page.toString().padLeft(3, '0');
      final loader = FontLoader(family(page))
        ..addFont(rootBundle.load('assets/fonts/qcf2/p$name.ttf'));
      await loader.load();
      _ready.add(page);
    });
  }

  static Future<void> ensureAll(Iterable<int> pages) =>
      Future.wait([for (final p in pages) ensure(p)]);

  static Future<void> ensureBasmala() {
    return _bsml ??= (FontLoader(bsmlFamily)
          ..addFont(rootBundle.load('assets/fonts/qcf2/bsml.ttf')))
        .load();
  }
}
