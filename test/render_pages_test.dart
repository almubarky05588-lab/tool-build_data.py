// يرسم صفحات مختارة من المصحف إلى صور PNG في build/screens/
// للتحقق البصري من سلامة الرسم والتلوين (تُرفع الصور في البناء الآلي).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:albayan/core/theme.dart';
import 'package:albayan/data/page_fonts.dart';
import 'package:albayan/data/quran_repository.dart';
import 'package:albayan/state/app_state.dart';
import 'package:albayan/ui/mushaf/mushaf_page.dart';

Future<void> _loadUiFont(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cases = <(int, HighlightMode, bool)>[
    (1, HighlightMode.color, false),
    (2, HighlightMode.color, false),
    (7, HighlightMode.color, false),
    (7, HighlightMode.margin, false),
    (19, HighlightMode.both, false),
    (19, HighlightMode.color, true),
    (50, HighlightMode.color, false),
    (604, HighlightMode.color, false),
  ];

  for (final (page, mode, dark) in cases) {
    testWidgets('رسم الصفحة $page (${mode.name}${dark ? '، ليلي' : ''})', (tester) async {
      await tester.runAsync(() async {
        await QuranRepository.load();
        await PageFonts.ensure(page);
        await PageFonts.ensureBasmala();
        await _loadUiFont('Cairo', 'assets/fonts/ui/Cairo.ttf');
      });

      final state = AppState()..mode = mode;
      final colors = dark ? AppColors.dark : AppColors.light;
      final key = GlobalKey();
      tester.view.physicalSize = const Size(412 * 2, 760 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: AppColorsScope(
            colors: colors,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: RepaintBoundary(
                key: key,
                child: Container(
                  color: colors.paper,
                  padding: const EdgeInsets.all(14),
                  child: MushafPage(
                    pageNo: page,
                    onWordTap: (_) {},
                    onMarkerTap: (_, __) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('build/screens')..createSync(recursive: true);
        final name = 'p${page.toString().padLeft(3, '0')}_${mode.name}${dark ? '_dark' : ''}.png';
        File('${dir.path}/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
