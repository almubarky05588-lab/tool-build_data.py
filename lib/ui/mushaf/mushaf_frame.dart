import 'package:flutter/material.dart';

import '../../state/app_state.dart';

/// إطار مصحف المدينة وترويسات السور، مقتطعة من الطبعة الرسمية لمجمع الملك فهد
/// (الحجم العادي الأخضر ١٤٤١هـ) بالسكربت tool/extract_mushaf_art.py.
/// الأرقام أدناه من frame.json الذي يكتبه السكربت.
class MushafFrame {
  MushafFrame._();

  static const asset = 'assets/mushaf/frame.png';

  /// عرض الإطار ÷ ارتفاعه.
  static const aspect = 0.6468;

  /// حدود منطقة النص داخل الإطار (نِسَب: يسار، أعلى، يمين، أسفل).
  static const inner = [0.05464, 0.03682, 0.94536, 0.96289];

  /// الهامش الرأسي داخل منطقة النص قبل أول سطر وبعد آخر سطر (نسبة من ارتفاعها).
  static const pad = 0.0091;

  /// لون دوائر أرقام الآيات داخل الإطار.
  static const markerColor = Color(0xFF2E7D4F);

  /// الإطار في الوضعين؛ في الليلي يُخفَّف سطوعه ويصير داخل الصفحة داكنًا.
  static bool enabled(AppState state) => true;

  /// تخفيف سطوع الزخارف في الوضع الليلي.
  static const dimDark = ColorFilter.matrix(<double>[
    0.62, 0, 0, 0, 0, //
    0, 0.62, 0, 0, 0, //
    0, 0, 0.62, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  static Widget art(String asset, {required bool dark}) {
    final img = Image.asset(asset, fit: BoxFit.fill);
    return dark ? ColorFiltered(colorFilter: dimDark, child: img) : img;
  }

  /// الفاتحة وأول البقرة بتخطيط خاص في المطبوع، فلا ترويسة مقتطعة لهما.
  static bool hasBanner(int surah) => surah >= 3 && surah <= 114;

  static String banner(int surah) => 'assets/mushaf/surah/${surah.toString().padLeft(3, '0')}.png';
}

/// صفحة بإطار مصحف المدينة: الترويسة (الجزء يمينًا والسورة يسارًا) فوق الإطار،
/// ورقم الصفحة تحته، والنص داخل منطقة النص بالضبط.
class FramedPage extends StatelessWidget {
  final String juz;
  final String surah;
  final String pageNumber;
  final Widget child;
  final TextStyle labelStyle;
  final bool dark;
  final Color darkPaper;

  const FramedPage({
    super.key,
    required this.juz,
    required this.surah,
    required this.pageNumber,
    required this.child,
    required this.labelStyle,
    this.dark = false,
    this.darkPaper = const Color(0xFF1A201D),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      const labelH = 24.0;
      final availH = cons.maxHeight - labelH * 2;
      var fw = cons.maxWidth;
      var fh = fw / MushafFrame.aspect;
      if (fh > availH) {
        fh = availH;
        fw = fh * MushafFrame.aspect;
      }
      final r = MushafFrame.inner;
      final innerH = (r[3] - r[1]) * fh;
      final padV = innerH * MushafFrame.pad;
      return Center(
        child: SizedBox(
          width: fw,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: labelH,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: fw * 0.06),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(juz, style: labelStyle),
                      const Spacer(),
                      Text(surah, style: labelStyle),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: fw,
                height: fh,
                child: Stack(
                  children: [
                    Positioned(
                      left: r[0] * fw,
                      top: r[1] * fh,
                      right: (1 - r[2]) * fw,
                      bottom: (1 - r[3]) * fh,
                      child: ColoredBox(color: dark ? darkPaper : Colors.white),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: MushafFrame.art(MushafFrame.asset, dark: dark),
                      ),
                    ),
                    Positioned(
                      left: r[0] * fw,
                      top: r[1] * fh + padV,
                      right: (1 - r[2]) * fw,
                      bottom: (1 - r[3]) * fh + padV,
                      child: child,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: labelH,
                child: Center(child: Text(pageNumber, style: labelStyle)),
              ),
            ],
          ),
        ),
      );
    });
  }
}
