import 'dart:math' as math;

import 'package:flutter/material.dart';

/// علامة «البيان»: مصحف مفتوح يتطابق فيه سطران مضيئان، وفوقهما كلمة «البيان».
/// منقولة من تصميم الشعار في فيجما (مساحة رسم 120×120).
class BayanMark extends StatelessWidget {
  final double size;
  final Color color;
  final Color highlight;

  const BayanMark({
    super.key,
    this.size = 96,
    required this.color,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(color, highlight),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final Color color;
  final Color hi;
  _MarkPainter(this.color, this.hi);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 120;
    canvas.scale(k, k);

    Path page(bool right) {
      double x(double v) => right ? 120 - v : v;
      return Path()
        ..moveTo(60, 92)
        ..cubicTo(x(48), 84, x(34), 82, x(20), 84)
        ..lineTo(x(20), 40)
        ..cubicTo(x(34), 38, x(48), 40, 60, 48)
        ..close();
    }

    final fill = Paint()..color = color.withValues(alpha: 0.10);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round;
    for (final r in [false, true]) {
      final p = page(r);
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }

    for (final r in [false, true]) {
      double x(double v) => r ? 120 - v : v;
      for (final (y, h) in [(56.0, false), (66.0, true), (76.0, false)]) {
        final line = Path()
          ..moveTo(x(28), y)
          ..cubicTo(x(38), y - 1, x(47), y + 1, x(53), y + 4);
        canvas.drawPath(
          line,
          Paint()
            ..color = h ? hi : color.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = h ? 3.6 : 2.2
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // قوس منقّط يصل بين السطرين المتطابقين
    final arc = Path()
      ..moveTo(53, 70)
      ..quadraticBezierTo(60, 61, 67, 70);
    final dash = Paint()
      ..color = hi
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final metric in arc.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 5) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 2, metric.length)), dash);
      }
    }

    // كلمة «البيان» فوق المصحف
    final tp = TextPainter(
      text: TextSpan(
        text: 'البيان',
        style: TextStyle(fontFamily: 'ArefRuqaa', fontSize: 26, color: hi, height: 1.2),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, Offset(60 - tp.width / 2, 22 - tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color || old.hi != hi;
}

/// أيقونة التطبيق: مربع أخضر بزوايا دائرية وفيه العلامة الذهبية.
class BayanAppIcon extends StatelessWidget {
  final double size;
  const BayanAppIcon({super.key, this.size = 132});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.225),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16695A), Color(0xFF08291F)],
        ),
        border: Border.all(color: const Color(0x59D9B66A), width: size / 90),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      alignment: Alignment.center,
      child: BayanMark(
        size: size * 0.78,
        color: const Color(0xFFD9B66A),
        highlight: const Color(0xFFF6DFA0),
      ),
    );
  }
}
