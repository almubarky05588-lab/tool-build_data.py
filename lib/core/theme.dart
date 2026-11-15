import 'package:flutter/material.dart';

/// ألوان «البيان» — مطابقة لتصميم فيجما.
class AppColors {
  final Color bg;
  final Color paper;
  final Color ink;
  final Color sub;
  final Color line;
  final Color green;
  final Color greenText;
  final Color gold;
  final Color goldLight;
  final Color chip;
  final List<Color> groups;

  const AppColors({
    required this.bg,
    required this.paper,
    required this.ink,
    required this.sub,
    required this.line,
    required this.green,
    required this.greenText,
    required this.gold,
    required this.goldLight,
    required this.chip,
    required this.groups,
  });

  static const light = AppColors(
    bg: Color(0xFFF7F2E7),
    paper: Color(0xFFFFFCF5),
    ink: Color(0xFF1F1B14),
    sub: Color(0xFF6B6253),
    line: Color(0xFFE6DCC6),
    green: Color(0xFF0E4A3C),
    greenText: Color(0xFF0E4A3C),
    gold: Color(0xFFB8913F),
    goldLight: Color(0xFFE9D9B0),
    chip: Color(0xFFEDE5D3),
    groups: [
      Color(0xFFB0325A),
      Color(0xFF0F7A78),
      Color(0xFFC2650E),
      Color(0xFF4B5BB5),
      Color(0xFF6E7F1F),
    ],
  );

  static const dark = AppColors(
    bg: Color(0xFF0D1412),
    paper: Color(0xFF141D1A),
    ink: Color(0xFFE9E2D1),
    sub: Color(0xFF9A9283),
    line: Color(0xFF25312C),
    green: Color(0xFF1F5C4B),
    greenText: Color(0xFF8FD3B8),
    gold: Color(0xFFD6B26B),
    goldLight: Color(0xFF4A3E24),
    chip: Color(0xFF1C2622),
    groups: [
      Color(0xFFF28AAA),
      Color(0xFF5CCBC4),
      Color(0xFFF4A65B),
      Color(0xFF9AA8F2),
      Color(0xFFC3D26A),
    ],
  );

  Color group(int id) => groups[id % groups.length];
}

/// نمط خط Cairo بوزن محدد (الخط متغيّر الوزن).
TextStyle cairo(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height}) {
  return TextStyle(
    fontFamily: 'Cairo',
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
    height: height,
  );
}

ThemeData buildTheme(AppColors c, Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: c.green,
    brightness: b,
  ).copyWith(
    primary: c.green,
    surface: c.bg,
    onSurface: c.ink,
    secondary: c.gold,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    fontFamily: 'Cairo',
    dividerColor: c.line,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.greenText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: cairo(18, weight: FontWeight.w700, color: c.greenText),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}

/// يتيح الوصول للألوان الحالية من أي ودجت: AppColorsScope.of(context)
class AppColorsScope extends InheritedWidget {
  final AppColors colors;
  const AppColorsScope({super.key, required this.colors, required super.child});

  static AppColors of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppColorsScope>()?.colors ?? AppColors.light;

  @override
  bool updateShouldNotify(AppColorsScope oldWidget) => oldWidget.colors != colors;
}
