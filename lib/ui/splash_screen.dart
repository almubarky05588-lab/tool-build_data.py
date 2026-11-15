import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'widgets/logo.dart';

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
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              const BayanAppIcon(size: 132),
              const SizedBox(height: 18),
              const Text(
                'البيان',
                style: TextStyle(
                  fontFamily: 'ArefRuqaa',
                  fontWeight: FontWeight.w700,
                  fontSize: 58,
                  color: Color(0xFFF1DCA6),
                  height: 1.3,
                ),
              ),
              Text('مصحف المتشابهات',
                  style: cairo(20, weight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 6),
              Text('قراءةٌ متقنة… والمتشابه أمام عينيك',
                  style: cairo(13.5, color: const Color(0xFFA9C7BC))),
              const Spacer(flex: 4),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'تعذّر تحميل بيانات المصحف\n$error',
                    textAlign: TextAlign.center,
                    style: cairo(13, color: const Color(0xFFF2B8B8)),
                  ),
                )
              else
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFFD9B66A),
                  ),
                ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
