import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'data/page_fonts.dart';
import 'data/quran_repository.dart';
import 'state/app_state.dart';
import 'ui/home_shell.dart';
import 'ui/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const AlBayanApp());
}

class AlBayanApp extends StatefulWidget {
  const AlBayanApp({super.key});

  @override
  State<AlBayanApp> createState() => _AlBayanAppState();
}

class _AlBayanAppState extends State<AlBayanApp> {
  final AppState _state = AppState();
  late final Future<void> _init = _boot();

  Future<void> _boot() async {
    await Future.wait([
      _state.load(),
      QuranRepository.load(),
      PageFonts.ensureBasmala(),
      // إبقاء شاشة البداية لحظة قصيرة على الأقل
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);
    await PageFonts.ensure(_state.lastPage);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          final colors = _state.dark ? AppColors.dark : AppColors.light;
          return AppColorsScope(
            colors: colors,
            child: MaterialApp(
              title: 'البيان',
              debugShowCheckedModeBanner: false,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: buildTheme(colors, _state.dark ? Brightness.dark : Brightness.light),
              builder: (context, child) => MediaQuery(
                // نص المصحف مضبوط على مقاس الصفحة، فلا نسمح بتكبير الخط من النظام هنا
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.of(context)
                      .textScaler
                      .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
                ),
                child: child!,
              ),
              home: FutureBuilder<void>(
                future: _init,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return SplashScreen(error: '${snap.error}');
                  }
                  if (snap.connectionState != ConnectionState.done) {
                    return const SplashScreen();
                  }
                  return const HomeShell();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
