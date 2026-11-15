import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import 'home_screen.dart';
import 'mushaf/mushaf_screen.dart';
import 'mutashabihat_screen.dart';
import 'settings_screen.dart';

/// الهيكل الرئيسي: أربعة تبويبات، والمصحف يُعرض بملء الشاشة بلا شريط سفلي.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = AppColorsScope.of(context);
    final showBar = state.tab != 1;
    return PopScope(
      canPop: state.tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) state.setTab(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: state.tab,
          children: const [
            HomeScreen(),
            MushafScreen(),
            MutashabihatScreen(),
            SettingsScreen(),
          ],
        ),
        bottomNavigationBar: showBar
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: c.paper,
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _TabItem(icon: Icons.home_rounded, label: 'الرئيسية', index: 0),
                        _TabItem(icon: Icons.menu_book_rounded, label: 'المصحف', index: 1),
                        _TabItem(icon: Icons.layers_rounded, label: 'المتشابهات', index: 2),
                        _TabItem(icon: Icons.tune_rounded, label: 'الإعدادات', index: 3),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  const _TabItem({required this.icon, required this.label, required this.index});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = AppColorsScope.of(context);
    final on = state.tab == index;
    final color = on ? c.greenText : c.sub.withValues(alpha: 0.8);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => state.setTab(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: cairo(11, weight: on ? FontWeight.w700 : FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}
