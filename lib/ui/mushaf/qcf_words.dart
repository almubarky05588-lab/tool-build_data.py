import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/page_fonts.dart';

/// عرض كلمات آية (أو آيات) بخطوط صفحاتها الأصلية، مع تلوين كلمات الاختلاف.
/// يُستعمل في لوحة مواضع التشابه وفي الفهرس.
class QcfWords extends StatefulWidget {
  final List<QWord> words;
  final Set<String> highlight;
  final Color highlightColor;
  final double fontSize;
  final int? maxWords;

  const QcfWords({
    super.key,
    required this.words,
    required this.highlight,
    required this.highlightColor,
    this.fontSize = 22,
    this.maxWords,
  });

  @override
  State<QcfWords> createState() => _QcfWordsState();
}

class _QcfWordsState extends State<QcfWords> {
  late Future<void> _fonts;

  static String _pages(List<QWord> words) => words.map((w) => w.page).toSet().join(',');

  @override
  void initState() {
    super.initState();
    _fonts = PageFonts.ensureAll(widget.words.map((w) => w.page).toSet());
  }

  @override
  void didUpdateWidget(QcfWords old) {
    super.didUpdateWidget(old);
    if (_pages(old.words) != _pages(widget.words)) {
      _fonts = PageFonts.ensureAll(widget.words.map((w) => w.page).toSet());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    return FutureBuilder<void>(
      future: _fonts,
      builder: (context, snap) {
        final ready = widget.words.every((w) => PageFonts.isReady(w.page));
        if (!ready && snap.connectionState != ConnectionState.done) {
          return SizedBox(height: widget.fontSize * 1.8);
        }
        var list = widget.words;
        final cut = widget.maxWords != null && list.length > widget.maxWords!;
        if (cut) list = list.sublist(0, widget.maxWords!);
        final fs = widget.fontSize;
        return Wrap(
          textDirection: TextDirection.rtl,
          spacing: fs * 0.28,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final w in list)
              Text.rich(
                TextSpan(children: [
                  if (w.glyph.isNotEmpty)
                    TextSpan(
                      text: w.glyph,
                      style: TextStyle(
                        color: widget.highlight.contains(w.key) ? widget.highlightColor : c.ink,
                      ),
                    ),
                  if (w.marker.isNotEmpty)
                    TextSpan(text: w.marker, style: TextStyle(color: c.gold)),
                ]),
                textDirection: TextDirection.rtl,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: PageFonts.family(w.page),
                  fontSize: fs,
                  height: 1.75,
                ),
              ),
            if (cut)
              Text('…', style: TextStyle(fontSize: fs * 0.8, color: c.sub, height: 1.75)),
          ],
        );
      },
    );
  }
}
