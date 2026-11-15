// يرسم شاشة البداية والرئيسية إلى صور في build/screens/ للتحقق البصري.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:albayan/core/theme.dart';
import 'package:albayan/data/quran_repository.dart';
import 'package:albayan/state/app_state.dart';
import 'package:albayan/ui/home_screen.dart';
import 'package:albayan/ui/splash_screen.dart';

Future<void> _font(String family, String path) async {
  final l = FontLoader(family)..addFont(rootBundle.load(path));
  await l.load();
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/screens')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _wrap(AppState state, GlobalKey key, Widget child) => AppScope(
      state: state,
      child: AppColorsScope(
        colors: AppColors.light,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(AppColors.light, Brightness.light),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: RepaintBoundary(key: key, child: child),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // نفس مقاس آيفون تقريبًا
  });

  testWidgets('شاشة البداية', (tester) async {
    await tester.runAsync(() async {
      await _font('Cairo', 'assets/fonts/ui/Cairo.ttf');
      await _font('ArefRuqaa', 'assets/fonts/ui/ArefRuqaa-Bold.ttf');
    });
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(_wrap(AppState(), key, const SplashScreen()));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.takeException(), isNull);
    await _shot(tester, key, 'splash');
  });

  testWidgets('الرئيسية', (tester) async {
    await tester.runAsync(() async {
      await QuranRepository.load();
      await _font('Cairo', 'assets/fonts/ui/Cairo.ttf');
      await _font('ArefRuqaa', 'assets/fonts/ui/ArefRuqaa-Bold.ttf');
    });
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final state = AppState()
      ..lastPage = 21
      ..currentPage = 21;
    await tester.pumpWidget(_wrap(state, key, const Scaffold(body: HomeScreen())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _shot(tester, key, 'home');
  });
}
