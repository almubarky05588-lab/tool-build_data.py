import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../data/quran_repository.dart';
import '../state/app_state.dart';
import 'index_screen.dart';
import 'mushaf/mutashabih_sheet.dart';
import 'widgets/logo.dart';
import 'widgets/ornament.dart';

/// الشاشة الرئيسية: متابعة القراءة، اختصارات، ومتشابهات آخر صفحة.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    final last = state.lastPage;
    final surah = repo.surahForPage(last);
    final groups = repo.groupsOnPage(last);

    final orn = c.gold.withValues(alpha: state.dark ? 0.16 : 0.24);
    return Stack(
      children: [
        // زخرفة ثابتة أعلى الشاشة وأسفلها
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 300,
          child: OrnamentFill(color: orn, fade: 1),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 180,
          child: OrnamentFill(color: orn, fade: -1),
        ),
        SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          // ------------------------------------------------ الترحيب
          Row(
            children: [
              BayanMark(size: 38, color: c.greenText, highlight: c.gold),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مصحف المتشابهات', style: cairo(13, color: c.sub)),
                  Text('البيان',
                      style: TextStyle(
                        fontFamily: 'ArefRuqaa',
                        fontWeight: FontWeight.w700,
                        fontSize: 30,
                        color: c.greenText,
                        height: 1.2,
                      )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ------------------------------------------------ تابع القراءة
          InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: () => state.openPage(last),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF13604E), Color(0xFF0A3329)],
                ),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: OrnamentFill(color: Color(0x29D9B66A), fade: -1),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('تابع القراءة',
                          style: cairo(13, weight: FontWeight.w500, color: const Color(0xFFA9C7BC))),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('آخر قراءة',
                            style: cairo(11, color: const Color(0xFFCFE3DB))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('سورة ${surah.name}',
                      style: cairo(26, weight: FontWeight.w700, color: Colors.white)),
                  Text('صفحة ${ar(last)} — ${juzName(repo.juzForPage(last))}',
                      style: cairo(13, color: const Color(0xFFCFE3DB))),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: last / 604,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFD9B66A)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          groups.isEmpty
                              ? 'لا مواضع متشابهة في الصفحة'
                              : 'في الصفحة ${countPlaces(groups.length)} متشابهة',
                          style: cairo(12, color: const Color(0xFFCFE3DB)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9B66A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('متابعة',
                                style: cairo(13.5,
                                    weight: FontWeight.w700, color: const Color(0xFF0A3329))),
                            const Icon(Icons.chevron_left_rounded,
                                size: 18, color: Color(0xFF0A3329)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ------------------------------------------------ اختصارات
          Row(
            children: [
              _Quick(
                icon: Icons.format_list_bulleted_rounded,
                label: 'السور',
                color: c.greenText,
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const IndexScreen())),
              ),
              const SizedBox(width: 10),
              _Quick(
                icon: Icons.grid_view_rounded,
                label: 'الأجزاء',
                color: c.group(1),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const IndexScreen(initialTab: 1))),
              ),
              const SizedBox(width: 10),
              _Quick(
                icon: Icons.layers_rounded,
                label: 'المتشابهات',
                color: c.group(2),
                onTap: () => state.setTab(2),
              ),
              const SizedBox(width: 10),
              _Quick(
                icon: Icons.bookmark_rounded,
                label: 'العلامات',
                color: c.group(0),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const IndexScreen(initialTab: 2))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OrnamentDivider(color: c.gold.withValues(alpha: 0.8)),
          const SizedBox(height: 4),

          // ------------------------------------------------ متشابهات آخر صفحة
          Row(
            children: [
              Text('متشابهات آخر صفحة',
                  style: cairo(16, weight: FontWeight.w700, color: c.ink)),
              const Spacer(),
              TextButton(
                onPressed: () => state.setTab(2),
                child: Text('عرض الكل', style: cairo(12.5, weight: FontWeight.w500, color: c.gold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('لا مواضع متشابهة في صفحة ${ar(last)}.',
                  style: cairo(13, color: c.sub)),
            ),
          for (final id in groups.take(4)) _GroupRow(groupId: id, page: last),
        ],
      ),
        ),
      ],
    );
  }
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Quick({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: c.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 8),
              Text(label, style: cairo(12, weight: FontWeight.w600, color: c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  final int groupId;
  final int page;
  const _GroupRow({required this.groupId, required this.page});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    final g = repo.groups[groupId];
    final color = c.group(groupId);
    // العضو الموجود في هذه الصفحة أولًا
    final here = g.members.indexWhere((m) => m.any((k) => repo.pageOfAyah(k) == page));
    final main = here < 0 ? 0 : here;
    final others = [
      for (var i = 0; i < g.members.length; i++)
        if (i != main) repo.memberLabel(g.members[i]),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showMutashabihSheet(
          context,
          ayahKey: g.members[main].first,
          originPage: page,
          onlyGroup: groupId,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: c.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repo.memberLabel(g.members[main]),
                        style: cairo(14, weight: FontWeight.w700, color: c.ink)),
                    Text('يتشابه مع: ${others.join('، ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: cairo(12, color: c.sub)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(countPlaces(g.members.length),
                    style: cairo(11, weight: FontWeight.w600, color: color)),
              ),
              Icon(Icons.chevron_left_rounded, color: c.sub),
            ],
          ),
        ),
      ),
    );
  }
}
