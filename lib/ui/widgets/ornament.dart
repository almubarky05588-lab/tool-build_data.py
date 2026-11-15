import 'dart:math' as math;

import 'package:flutter/material.dart';

/// الزخرفة النجمية الثُّمانية (نمط الخاتم) — الخيار «أ» المعتمد.
/// بلاطة 80×80: نجمة ثمانية من مربعين متداخلين، مثمّن داخلي، دائرة صغيرة،
/// وخطوط من رؤوس النجمة إلى أطراف البلاطة تتشابك مع البلاطات المجاورة.
class KhatamPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double tile;

  KhatamPainter({required this.color, this.strokeWidth = 1.1, this.tile = 80});

  static Path _tilePath(double t) {
    final k = t / 80;
    const c = 40.0;
    const bigR = 26.0;
    final smallR = bigR * math.cos(math.pi / 4) / math.cos(math.pi / 8);
    final p = Path();

    // النجمة
    for (var i = 0; i <= 16; i++) {
      final a = math.pi / 8 * i - math.pi / 2;
      final r = i.isEven ? bigR : smallR;
      final x = (c + r * math.cos(a)) * k;
      final y = (c + r * math.sin(a)) * k;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    // المثمّن الداخلي
    final o = smallR * 0.62;
    for (var i = 0; i <= 8; i++) {
      final a = math.pi / 4 * i + math.pi / 8 - math.pi / 2;
      final x = (c + o * math.cos(a)) * k;
      final y = (c + o * math.sin(a)) * k;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    // الخطوط الواصلة
    for (var i = 0; i < 8; i++) {
      final a = math.pi / 4 * i - math.pi / 2;
      final d = i.isEven ? 40.0 : 40.0 * math.sqrt2;
      p.moveTo((c + bigR * math.cos(a)) * k, (c + bigR * math.sin(a)) * k);
      p.lineTo((c + d * math.cos(a)) * k, (c + d * math.sin(a)) * k);
    }
    p.addOval(Rect.fromCircle(center: Offset(c * k, c * k), radius: 4 * k));
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
    final base = _tilePath(tile);
    final path = Path();
    for (double y = 0; y < size.height; y += tile) {
      for (double x = 0; x < size.width; x += tile) {
        path.addPath(base, Offset(x, y));
      }
    }
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(KhatamPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || old.tile != tile;
}

/// زخرفة ثابتة تملأ المساحة، مع تلاشٍ اختياري نحو الأسفل أو الأعلى.
class OrnamentFill extends StatelessWidget {
  final Color color;
  final double strokeWidth;

  /// 1 = تتلاشى للأسفل، -1 = تتلاشى للأعلى، 0 = بلا تلاشٍ.
  final int fade;

  const OrnamentFill({
    super.key,
    required this.color,
    this.strokeWidth = 1.1,
    this.fade = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = RepaintBoundary(
      child: CustomPaint(
        painter: KhatamPainter(color: color, strokeWidth: strokeWidth),
        size: Size.infinite,
      ),
    );
    if (fade != 0) {
      child = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => LinearGradient(
          begin: fade > 0 ? Alignment.topCenter : Alignment.bottomCenter,
          end: fade > 0 ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Colors.white, Color(0x88FFFFFF), Color(0x00FFFFFF)],
          stops: const [0, 0.45, 1],
        ).createShader(r),
        child: child,
      );
    }
    return IgnorePointer(child: child);
  }
}

/// زخرفة مع لمعة ذهبية متحركة تعبر الخطوط من الزاوية العليا اليسرى
/// إلى الزاوية السفلى اليمنى (لشاشة البداية فقط).
class ShimmerOrnament extends StatefulWidget {
  final Color dim;
  final Color bright;
  final Duration period;

  const ShimmerOrnament({
    super.key,
    required this.dim,
    required this.bright,
    this.period = const Duration(milliseconds: 2600),
  });

  @override
  State<ShimmerOrnament> createState() => _ShimmerOrnamentState();
}

class _ShimmerOrnamentState extends State<ShimmerOrnament>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: KhatamPainter(color: widget.dim)),
          ),
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              // موضع الشريط على القطر: يبدأ قبل الزاوية العليا اليسرى
              // وينتهي بعد الزاوية السفلى اليمنى.
              final t = Curves.easeInOut.transform(_c.value) * 1.5 - 0.25;
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [
                    Color(0x00FFFFFF),
                    Colors.white,
                    Color(0x00FFFFFF),
                  ],
                  stops: [
                    (t - 0.12).clamp(0.0, 1.0),
                    t.clamp(0.0, 1.0),
                    (t + 0.12).clamp(0.0, 1.0),
                  ],
                ).createShader(r),
                child: child,
              );
            },
            child: RepaintBoundary(
              child: CustomPaint(
                painter: KhatamPainter(color: widget.bright, strokeWidth: 1.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// فاصل زخرفي صغير: خطان ونجمة ثمانية في الوسط (ثابت).
class OrnamentDivider extends StatelessWidget {
  final Color color;
  const OrnamentDivider({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: CustomPaint(painter: _DividerPainter(color), size: Size.infinite),
    );
  }
}

class _DividerPainter extends CustomPainter {
  final Color color;
  _DividerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const bigR = 13.0;
    final smallR = bigR * math.cos(math.pi / 4) / math.cos(math.pi / 8);
    final star = Path();
    for (var i = 0; i <= 16; i++) {
      final a = math.pi / 8 * i - math.pi / 2;
      final r = i.isEven ? bigR : smallR;
      final x = cx + r * math.cos(a);
      final y = cy + r * math.sin(a);
      if (i == 0) {
        star.moveTo(x, y);
      } else {
        star.lineTo(x, y);
      }
    }
    canvas.drawPath(star, p);
    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = color);
    final gap = 24.0;
    final edge = 20.0;
    canvas.drawLine(Offset(edge, cy), Offset(cx - gap, cy), p);
    canvas.drawLine(Offset(cx + gap, cy), Offset(size.width - edge, cy), p);
    for (final x in [edge, size.width - edge]) {
      canvas.drawCircle(Offset(x, cy), 2.2, Paint()..color = color);
    }
    for (final x in [edge + 40, size.width - edge - 40]) {
      final d = Path()
        ..moveTo(x - 6, cy)
        ..lineTo(x, cy - 5)
        ..lineTo(x + 6, cy)
        ..lineTo(x, cy + 5)
        ..close();
      canvas.drawPath(d, p);
    }
  }

  @override
  bool shouldRepaint(_DividerPainter old) => old.color != color;
}
