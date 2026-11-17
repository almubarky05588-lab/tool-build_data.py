import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'widgets/logo.dart';
import 'widgets/ornament.dart';

/// شاشة البداية — تظهر أثناء تحميل بيانات المصحف.
class SplashScreen extends StatelessWidget {
  final String? error;
  const SplashScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F4E40), Color(0xFF06231C)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // زخرفة ذهبية على كامل الصفحة مع لمعة تنزل من أعلى اليسار إلى أسفل اليمين
            const ShimmerOrnament(
              dim: Color(0x33D9B66A),
              bright: Color(0xFFFFE9A8),
            ),
            // تعتيم خفيف خلف الشعار ليبقى واضحًا
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 0.75,
                  colors: [Color(0xEB09342A), Color(0x8C09342A), Color(0x0009342A)],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              const BayanAppIcon(size: 160),
              const SizedBox(height: 28),
              Text('مصحف المتشابهات',
                  style: cairo(20, weight: FontWeight.w600, color: Colors.white)),
              const Spacer(flex: 4),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'تعذّر تحميل بيانات المصحف\n$error',
                    textAlign: TextAlign.center,
                    style: cairo(13, color: const Color(0xFFF2B8B8)),
                  ),
                ),
              const SizedBox(height: 48),
            ],
          ),
            ),
          ],
        ),
      ),
    );
  }
}
