import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// تحكّم في تقليب الصفحات: الصفحة الحالية (من 0) والانتقال إليها.
class CurlController extends ChangeNotifier {
  int _page;
  _CurlPageViewState? _view;

  CurlController({int initialPage = 0}) : _page = initialPage;

  int get page => _page;

  void jumpTo(int index) {
    if (index == _page) return;
    _page = index;
    notifyListeners();
  }

  /// تقليب متحرك إلى الصفحة التالية (+1) أو السابقة (-1).
  void turn(int dir) => _view?._animateTurn(dir);
}

/// عرض صفحات بتقليب «ثني الورقة»: الصفحة تنثني من زاويتها اليسرى
/// (كعب المصحف على اليمين كالمصحف العربي) مع ظل وظهر ورقة.
class CurlPageView extends StatefulWidget {
  final CurlController controller;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ValueChanged<int> onPageChanged;
  final Color background;

  const CurlPageView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    required this.onPageChanged,
    required this.background,
  });

  @override
  State<CurlPageView> createState() => _CurlPageViewState();
}

class _CurlPageViewState extends State<CurlPageView> with SingleTickerProviderStateMixin {
  final Map<int, GlobalKey> _keys = {};
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  // حالة التقليب الجارية
  int _dir = 0; // +1 التالية، -1 السابقة، 0 لا شيء
  double _u = 0; // 0 = الصفحة العليا كما هي، 1 = انقلبت كاملة
  double _cornerY = 0; // ارتفاع الزاوية الممسوكة (أعلى أو أسفل)
  double _lift = 0; // رفع الزاوية مع حركة الإصبع
  ui.Image? _top;
  ui.Image? _under;
  Offset? _start;
  bool _dragging = false;
  Size _size = Size.zero;

  int get _page => widget.controller.page;

  @override
  void initState() {
    super.initState();
    widget.controller._view = this;
    widget.controller.addListener(_onJump);
  }

  @override
  void didUpdateWidget(CurlPageView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onJump);
      widget.controller._view = this;
      widget.controller.addListener(_onJump);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onJump);
    _anim.dispose();
    _top?.dispose();
    _under?.dispose();
    super.dispose();
  }

  void _onJump() {
    if (!mounted) return;
    _anim.stop();
    _reset();
    setState(() {});
    widget.onPageChanged(_page);
  }

  GlobalKey _key(int i) => _keys.putIfAbsent(i, () => GlobalKey());

  Future<ui.Image?> _capture(int index) async {
    final ctx = _keys[index]?.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro is! RenderRepaintBoundary || !ro.attached) return null;
    try {
      final dpr = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
      return await ro.toImage(pixelRatio: dpr);
    } catch (_) {
      return null;
    }
  }

  bool _canTurn(int dir) {
    final target = _page + dir;
    return target >= 0 && target < widget.itemCount;
  }

  Future<bool> _begin(int dir, double cornerY) async {
    if (!_canTurn(dir)) return false;
    _dir = dir;
    _cornerY = cornerY;
    _u = dir > 0 ? 0 : 1;
    // الصفحة التي تنثني فوق، والتي تنكشف تحتها
    final topIndex = dir > 0 ? _page : _page - 1;
    final underIndex = dir > 0 ? _page + 1 : _page;
    final imgs = await Future.wait([_capture(topIndex), _capture(underIndex)]);
    if (!mounted || _dir != dir) {
      for (final i in imgs) {
        i?.dispose();
      }
      return false;
    }
    _top?.dispose();
    _under?.dispose();
    _top = imgs[0];
    _under = imgs[1];
    if (_top == null) {
      _reset();
      return false;
    }
    setState(() {});
    return true;
  }

  void _reset() {
    _dir = 0;
    _u = 0;
    _lift = 0;
    _dragging = false;
    final t = _top, u = _under;
    _top = null;
    _under = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      t?.dispose();
      u?.dispose();
    });
  }

  void _finish(bool completed, int dir) {
    if (completed) {
      widget.controller._page = _page + dir;
      widget.onPageChanged(_page);
    }
    _reset();
    if (mounted) setState(() {});
  }

  Future<void> _animateTo(double target, {required bool completes, required int dir}) async {
    final from = _u;
    final lift0 = _lift;
    _anim.stop();
    _anim.duration = Duration(milliseconds: (650 * (target - from).abs()).round().clamp(180, 650));
    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    void tick() {
      setState(() {
        _u = from + (target - from) * curve.value;
        _lift = lift0 * (1 - curve.value);
      });
    }

    _anim.addListener(tick);
    try {
      await _anim.forward(from: 0).orCancel;
    } catch (_) {
      // أُلغيت الحركة
    } finally {
      _anim.removeListener(tick);
      curve.dispose();
    }
    _finish(completes, dir);
  }

  Future<void> _animateTurn(int dir) async {
    if (_dir != 0 || _anim.isAnimating || !_canTurn(dir)) return;
    final ok = await _begin(dir, _size.height);
    if (!ok) return;
    _lift = -_size.height * 0.1;
    await _animateTo(dir > 0 ? 1 : 0, completes: true, dir: dir);
  }

  // ---------------------------------------------------------------- السحب
  void _onStart(DragStartDetails d) {
    if (_dir != 0 || _anim.isAnimating) return;
    _start = d.localPosition;
    _dragging = true;
  }

  void _onUpdate(DragUpdateDetails d) {
    final s = _start;
    if (s == null || !_dragging) return;
    final dx = d.localPosition.dx - s.dx;
    final dy = d.localPosition.dy - s.dy;
    if (_dir == 0) {
      if (dx.abs() < 3) return;
      final dir = dx > 0 ? 1 : -1;
      if (!_canTurn(dir)) return;
      _begin(dir, s.dy < _size.height / 2 ? 0 : _size.height);
      _dir = dir;
      return;
    }
    final w = _size.width;
    setState(() {
      _u = _dir > 0 ? (dx / w).clamp(0.0, 1.0) : (1 - (-dx / w)).clamp(0.0, 1.0);
      _lift = dy * 0.6;
    });
  }

  void _onEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    _start = null;
    final dir = _dir;
    if (dir == 0) return;
    final v = d.velocity.pixelsPerSecond.dx;
    final complete = dir > 0 ? (_u > 0.3 || v > 600) : (_u < 0.7 || v < -600);
    final target = complete ? (dir > 0 ? 1.0 : 0.0) : (dir > 0 ? 0.0 : 1.0);
    _animateTo(target, completes: complete, dir: dir);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      _size = cons.biggest;
      final p = _page;
      Widget slot(int i, {required bool live}) {
        Widget child = RepaintBoundary(
          key: _key(i),
          child: ColoredBox(color: widget.background, child: widget.itemBuilder(context, i)),
        );
        if (!live) child = IgnorePointer(child: ExcludeSemantics(child: child));
        return Positioned.fill(child: child);
      }

      // نحتفظ بمفاتيح الصفحات المجاورة فقط
      _keys.removeWhere((k, _) => (k - p).abs() > 1);
      final turning = _dir != 0 && _top != null;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onStart,
        onHorizontalDragUpdate: _onUpdate,
        onHorizontalDragEnd: _onEnd,
        onHorizontalDragCancel: () {
          if (_dir != 0 && !_anim.isAnimating) _animateTo(_dir > 0 ? 0 : 1, completes: false, dir: _dir);
        },
        child: Stack(
          children: [
            if (p - 1 >= 0) slot(p - 1, live: false),
            if (p + 1 < widget.itemCount) slot(p + 1, live: false),
            slot(p, live: !turning),
            if (turning)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CurlPainter(
                    top: _top!,
                    under: _under,
                    u: _u,
                    cornerY: _cornerY,
                    lift: _lift,
                    background: widget.background,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _CurlPainter extends CustomPainter {
  final ui.Image top;
  final ui.Image? under;
  final double u;
  final double cornerY;
  final double lift;
  final Color background;

  _CurlPainter({
    required this.top,
    required this.under,
    required this.u,
    required this.cornerY,
    required this.lift,
    required this.background,
  });

  static List<Offset> _clip(List<Offset> poly, Offset m, Offset n, bool keepFront) {
    final out = <Offset>[];
    double side(Offset q) => (q.dx - m.dx) * n.dx + (q.dy - m.dy) * n.dy;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final sa = side(a), sb = side(b);
      final ina = keepFront ? sa >= 0 : sa < 0;
      final inb = keepFront ? sb >= 0 : sb < 0;
      if (ina) out.add(a);
      if (ina != inb) {
        final t = sa / (sa - sb);
        out.add(Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t));
      }
    }
    return out;
  }

  static Path _path(List<Offset> poly) => Path()..addPolygon(poly, true);

  Offset _clamp(Offset p, Size s) {
    final w = s.width, h = s.height;
    var spine = Offset(w, cornerY);
    var v = p - spine;
    if (v.distance > w) p = spine + v / v.distance * w;
    spine = Offset(w, cornerY > h / 2 ? 0 : h);
    final diag = math.sqrt(w * w + h * h);
    v = p - spine;
    if (v.distance > diag) p = spine + v / v.distance * diag;
    return p;
  }

  void _drawImage(Canvas canvas, ui.Image img, Size s, [Paint? paint]) {
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Offset.zero & s,
      paint ?? (Paint()..filterQuality = FilterQuality.medium),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final u2 = under;
    if (u2 != null) _drawImage(canvas, u2, size);

    final c = Offset(0, cornerY);
    final bend = 1 - (2 * u - 1).abs();
    final p = _clamp(Offset(u * 2 * w, cornerY + lift * bend), size);
    final d = p - c;
    final len = d.distance;
    if (len < 0.5) {
      _drawImage(canvas, top, size);
      return;
    }
    final n = d / len;
    final m = Offset((c.dx + p.dx) / 2, (c.dy + p.dy) / 2);
    final rect = [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)];
    final stay = _clip(rect, m, n, true);
    final flap = _clip(rect, m, n, false);
    Offset refl(Offset q) {
      final s = (q.dx - m.dx) * n.dx + (q.dy - m.dy) * n.dy;
      return Offset(q.dx - 2 * s * n.dx, q.dy - 2 * s * n.dy);
    }

    final flapR = flap.map(refl).toList();

    // ظل على الصفحة المكشوفة قرب خط الثني
    if (flap.length >= 3) {
      canvas.save();
      canvas.clipPath(_path(flap));
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.linear(m, m - n * 80, [
            const Color(0x61281E0A),
            const Color(0x00281E0A),
          ]),
      );
      canvas.restore();
    }

    // الجزء الثابت من الصفحة العليا
    if (stay.length >= 3) {
      canvas.save();
      canvas.clipPath(_path(stay));
      _drawImage(canvas, top, size);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.linear(m, m + n * 26, [
            const Color(0x2E281E0A),
            const Color(0x00281E0A),
          ]),
      );
      canvas.restore();
    }

    // الجزء المنثني (ظهر الورقة)
    if (flapR.length >= 3) {
      final fp = _path(flapR);
      canvas.drawPath(
        fp.shift(const Offset(0, 2)),
        Paint()
          ..color = const Color(0x59281E0A)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawPath(fp, Paint()..color = Color.alphaBlend(const Color(0x14785F28), background));
      canvas.save();
      canvas.clipPath(fp);
      // النص معكوسًا وشفافًا جدًا كما يظهر من خلف الورق
      final dd = Offset(-n.dy, n.dx);
      final r00 = 2 * dd.dx * dd.dx - 1, r01 = 2 * dd.dx * dd.dy;
      final r10 = r01, r11 = 2 * dd.dy * dd.dy - 1;
      final tx = m.dx - (r00 * m.dx + r01 * m.dy);
      final ty = m.dy - (r10 * m.dx + r11 * m.dy);
      canvas.save();
      canvas.transform(Float64List.fromList([
        r00, r10, 0, 0, //
        r01, r11, 0, 0, //
        0, 0, 1, 0, //
        tx, ty, 0, 1, //
      ]));
      _drawImage(canvas, top, size, Paint()..color = const Color(0x12000000));
      canvas.restore();
      canvas.drawRect(
        Rect.fromLTWH(-w, -h, w * 4, h * 4),
        Paint()
          ..shader = ui.Gradient.linear(
            m,
            m - n * (len * 0.6),
            [const Color(0x00FFFFFF), const Color(0x59FFFFFF), const Color(0x2E785F28)],
            [0, 0.25, 1],
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CurlPainter old) =>
      old.u != u ||
      old.lift != lift ||
      old.cornerY != cornerY ||
      old.top != top ||
      old.under != under ||
      old.background != background;
}
