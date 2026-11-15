import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'widgets/ornament.dart';
import '../state/app_state.dart';

/// إعدادات العرض.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = AppColorsScope.of(context);

    Widget option(String title, String desc, HighlightMode m) {
      final on = state.mode == m;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => state.setMode(m),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: on ? c.greenText.withValues(alpha: 0.08) : c.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: on ? c.greenText.withValues(alpha: 0.6) : c.line,
                width: on ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: on ? c.greenText : c.sub),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: cairo(14, weight: FontWeight.w600, color: c.ink)),
                      Text(desc, style: cairo(11.5, color: c.sub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget toggle(String title, String desc, bool value, ValueChanged<bool> onChanged) {
      return SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeTrackColor: c.green,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Text(title, style: cairo(14, weight: FontWeight.w600, color: c.ink)),
        subtitle: desc.isEmpty ? null : Text(desc, style: cairo(11.5, color: c.sub)),
      );
    }

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 200,
          child: OrnamentFill(
            color: AppColorsScope.of(context).gold.withValues(alpha: 0.2),
            fade: 1,
          ),
        ),
        SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Text('الإعدادات', style: cairo(24, weight: FontWeight.w700, color: c.greenText)),
          const SizedBox(height: 14),
          Text('طريقة إظهار المتشابه', style: cairo(15, weight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 8),
          option('تلوين الكلمات', 'تُلوَّن مواضع الاختلاف داخل نص الصفحة', HighlightMode.color),
          option('علامة في الهامش', 'دائرة ملوّنة بجانب السطر برقم المواضع الأخرى', HighlightMode.margin),
          option('الاثنان معًا', 'تلوين داخل النص مع علامة في الهامش', HighlightMode.both),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: c.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.line),
            ),
            child: Column(
              children: [
                toggle('تلوين مواضع الاختلاف فقط', 'بدل تلوين الآية المتشابهة كاملة',
                    state.diffOnly, state.setDiffOnly),
                Divider(height: 1, color: c.line),
                toggle('زر العودة للصفحة الأصلية', 'يظهر بعد كل انتقال إلى موضع متشابه',
                    state.returnButton, state.setReturnButton),
                Divider(height: 1, color: c.line),
                toggle('الوضع الليلي', '', state.dark, state.setDark),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('عن التطبيق', style: cairo(15, weight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.line),
            ),
            child: Text(
              'نص المصحف معروض بخطوط مجمع الملك فهد لطباعة المصحف الشريف (QCF V2) '
              'على تخطيط مصحف المدينة سطرًا بسطر.\n\n'
              'بيانات المتشابهات مبنية على عمل القارئ إدريس العاصم رحمه الله '
              '(مشروع Quran Mutashabihat Data، رخصة CC0)، وهي تركّز على ما يُشكل على '
              'الحفّاظ وليست حصرًا لكل المتشابهات. كلمات الاختلاف محددة آليًا بمقارنة الآيات.\n\n'
              'تطبيق مجاني — نسأل الله أن يجعله خالصًا لوجهه.',
              style: cairo(12.5, color: c.sub, height: 1.7),
            ),
          ),
        ],
      ),
        ),
      ],
    );
  }
}
