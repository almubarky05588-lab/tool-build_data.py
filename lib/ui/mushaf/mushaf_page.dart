import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/page_fonts.dart';
import '../../data/quran_repository.dart';
import '../../state/app_state.dart';
import 'mushaf_frame.dart';

/// عرض صفحة واحدة من المصحف بأسطرها الخمسة عشر كما في المطبوع،
/// مع تلوين مواضع التشابه أو علاماتها في الهامش.
class MushafPage extends StatefulWidget {
  final int pageNo;
  final void Function(QWord word) onWordTap;
  final void Function(int groupId, QLine line) onMarkerTap;

  const MushafPage({
    super.key,
    required this.pageNo,
    required this.onWordTap,
    required this.onMarkerTap,
  });

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late Future<void> _fonts;

  @override
  void initState() {
    super.initState();
    _fonts = Future.wait([
      PageFonts.ensure(widget.pageNo),
      PageFonts.ensureBasmala(),
    ]);
  }

  @override
  void didUpdateWidget(MushafPage old) {
    super.didUpdateWidget(old);
    if (old.pageNo != widget.pageNo) {
      _fonts = Future.wait([PageFonts.ensure(widget.pageNo), PageFonts.ensureBasmala()]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _fonts,
      builder: (context, snap) {
        if (!PageFonts.isReady(widget.pageNo) &&
            snap.connectionState != ConnectionState.done) {
          return const SizedBox.expand();
        }
        return LayoutBuilder(
          builder: (context, cons) => _PageBody(
            page: QuranRepository.instance.page(widget.pageNo),
            width: cons.maxWidth,
            height: cons.maxHeight,
            onWordTap: widget.onWordTap,
            onMarkerTap: widget.onMarkerTap,
          ),
        );
      },
    );
  }
}

class _PageBody extends StatelessWidget {
  final QPage page;
  final double width;
  final double height;
  final void Function(QWord) onWordTap;
  final void Function(int, QLine) onMarkerTap;

  const _PageBody({
    required this.page,
    required this.width,
    required this.height,
    required this.onWordTap,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    final showMargin = state.mode != HighlightMode.color;
    final showColor = state.mode != HighlightMode.margin;

    // 15 سطرًا في كل صفحة؛ الصفحتان الأولى والثانية أقصر وتتوسطان الصفحة.
    const slots = 15;
    final lineH = height / slots;
    final marginW = showMargin ? math.min(30.0, width * 0.08) : 0.0;
    final textW = width - marginW;
    final fs = math.min(textW / 17.4, lineH / 1.5);
    final family = PageFonts.family(page.number);
    final shortPage = page.number <= 2;
    final framed = MushafFrame.enabled(state);

    final rows = <Widget>[];
    for (final line in page.lines) {
      Widget content;
      switch (line.type) {
        case LineType.header:
          if (framed && MushafFrame.hasBanner(line.surah)) {
            // ترويسة السورة من الطبعة الرسمية بعرض السطر كاملًا
            rows.add(SizedBox(
              height: lineH,
              width: width,
              child: MushafFrame.art(MushafFrame.banner(line.surah), dark: state.dark),
            ));
            continue;
          }
          content = _SurahHeader(name: repo.surah(line.surah).name, height: lineH, fs: fs);
        case LineType.basmala:
          content = Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                line.glyphs,
                textDirection: TextDirection.rtl,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: PageFonts.bsmlFamily,
                  fontSize: fs * 1.05,
                  color: c.ink,
                  height: 1.2,
                ),
              ),
            ),
          );
        case LineType.text:
          content = _TextLine(
            line: line,
            family: family,
            fs: fs,
            lineH: lineH,
            width: textW,
            centered: shortPage,
            showColor: showColor,
            markerColor: framed && !state.dark ? MushafFrame.markerColor : null,
            diffOnly: state.diffOnly,
            focusAyah: state.focusAyah,
            onWordTap: onWordTap,
          );
      }

      Widget marker = SizedBox(width: marginW);
      if (showMargin && line.type == LineType.text) {
        final ids = repo.groupsInLine(line, diffOnly: state.diffOnly);
        if (ids.isNotEmpty) {
          marker = SizedBox(
            width: marginW,
            child: _MarginMarker(
              groupIds: ids,
              size: math.min(marginW * 0.72, lineH * 0.6),
              onTap: () => onMarkerTap(ids.first, line),
            ),
          );
        }
      }

      rows.add(SizedBox(
        height: lineH,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [marker, Expanded(child: content)],
        ),
      ));
    }

    return Column(
      mainAxisAlignment: shortPage ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: rows,
    );
  }
}

/// سطر نص: كلمات بخط الصفحة، موزّعة على عرض السطر.
class _TextLine extends StatelessWidget {
  final QLine line;
  final String family;
  final double fs;
  final double lineH;
  final double width;
  final bool centered;
  final bool showColor;
  final Color? markerColor;
  final bool diffOnly;
  final String? focusAyah;
  final void Function(QWord) onWordTap;

  const _TextLine({
    required this.line,
    required this.family,
    required this.fs,
    required this.lineH,
    required this.width,
    required this.centered,
    required this.showColor,
    this.markerColor,
    required this.diffOnly,
    required this.focusAyah,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    final base = TextStyle(
      fontFamily: family,
      fontSize: fs,
      height: lineH / fs,
      leadingDistribution: TextLeadingDistribution.even,
      color: c.ink,
    );

    var natural = 0.0;
    final words = <Widget>[];
    for (final w in line.words) {
      final gid = showColor ? repo.highlightGroup(w, diffOnly: diffOnly) : null;
      final span = TextSpan(children: [
        if (w.glyph.isNotEmpty)
          TextSpan(text: w.glyph, style: gid == null ? null : TextStyle(color: c.group(gid))),
        if (w.marker.isNotEmpty) TextSpan(text: w.marker, style: TextStyle(color: markerColor ?? c.gold)),
      ]);
      final tp = TextPainter(
        text: TextSpan(style: base, children: [span]),
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.noScaling,
      )..layout();
      natural += tp.width;
      tp.dispose();

      Widget word = Text.rich(
        span,
        style: base,
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.noScaling,
        softWrap: false,
      );
      if (focusAyah != null && w.ayahKey == focusAyah) {
        word = DecoratedBox(
          decoration: BoxDecoration(
            color: c.gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: word,
        );
      }
      words.add(GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onWordTap(w),
        child: word,
      ));
    }

    final overflow = natural > width;
    final full = !centered && !overflow && natural > width * 0.8;
    Widget row = Row(
      textDirection: TextDirection.rtl,
      mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: full ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
      children: full
          ? words
          : [
              for (var i = 0; i < words.length; i++) ...[
                if (i > 0) SizedBox(width: overflow ? fs * 0.12 : fs * 0.28),
                words[i],
              ],
            ],
    );
    if (overflow) {
      row = FittedBox(fit: BoxFit.scaleDown, child: row);
    }
    return full ? row : Center(child: row);
  }
}

class _SurahHeader extends StatelessWidget {
  final String name;
  final double height;
  final double fs;
  const _SurahHeader({required this.name, required this.height, required this.fs});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: height * 0.1),
      child: Container(
        decoration: BoxDecoration(
          color: c.goldLight.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(height * 0.3),
          border: Border.all(color: c.gold.withValues(alpha: 0.7), width: 1.2),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rate_rounded, size: fs * 0.7, color: c.gold),
              SizedBox(width: fs * 0.4),
              Text(
                'سورة $name',
                textScaler: TextScaler.noScaling,
                style: cairo(fs * 0.85, weight: FontWeight.w700, color: c.greenText),
              ),
              SizedBox(width: fs * 0.4),
              Icon(Icons.star_rate_rounded, size: fs * 0.7, color: c.gold),
            ],
          ),
        ),
      ),
    );
  }
}

/// علامة الهامش: دائرة بلون المجموعة وعدد المواضع الأخرى.
class _MarginMarker extends StatelessWidget {
  final List<int> groupIds;
  final double size;
  final VoidCallback onTap;
  const _MarginMarker({required this.groupIds, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    final g = repo.groups[groupIds.first];
    final color = c.group(g.id);
    final others = g.members.length - 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 4)],
              ),
              alignment: Alignment.center,
              child: Text(
                ar(others),
                textScaler: TextScaler.noScaling,
                style: cairo(size * 0.55, weight: FontWeight.w700, color: Colors.white, height: 1),
              ),
            ),
            if (groupIds.length > 1)
              Positioned(
                top: -2,
                left: -2,
                child: Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  decoration: BoxDecoration(
                    color: c.group(groupIds[1]),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.paper, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
