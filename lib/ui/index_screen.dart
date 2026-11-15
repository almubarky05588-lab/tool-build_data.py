import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../data/quran_repository.dart';
import '../state/app_state.dart';

/// فهرس السور والأجزاء والعلامات.
class IndexScreen extends StatelessWidget {
  final int initialTab;
  const IndexScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الفهرس'),
          bottom: TabBar(
            labelStyle: cairo(14, weight: FontWeight.w700),
            unselectedLabelStyle: cairo(14),
            labelColor: c.greenText,
            unselectedLabelColor: c.sub,
            indicatorColor: c.gold,
            tabs: const [Tab(text: 'السور'), Tab(text: 'الأجزاء'), Tab(text: 'العلامات')],
          ),
        ),
        body: const TabBarView(children: [_Surahs(), _Juz(), _Bookmarks()]),
      ),
    );
  }
}

void _open(BuildContext context, int page) {
  AppScope.read(context).openPage(page);
  Navigator.of(context).popUntil((r) => r.isFirst);
}

class _Surahs extends StatelessWidget {
  const _Surahs();

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: repo.surahs.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: c.line, indent: 72),
      itemBuilder: (context, i) {
        final s = repo.surahs[i];
        return ListTile(
          onTap: () => _open(context, s.page),
          leading: _NumberBadge(number: s.number),
          title: Text('سورة ${s.name}', style: cairo(15.5, weight: FontWeight.w700, color: c.ink)),
          subtitle: Text('${s.place} — ${ar(s.ayahs)} ${s.ayahs <= 10 && s.ayahs >= 3 ? 'آيات' : 'آية'}',
              style: cairo(12, color: c.sub)),
          trailing: Text('ص ${ar(s.page)}', style: cairo(12.5, color: c.gold)),
        );
      },
    );
  }
}

class _Juz extends StatelessWidget {
  const _Juz();

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: repo.juz.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: c.line, indent: 72),
      itemBuilder: (context, i) {
        final j = repo.juz[i];
        return ListTile(
          onTap: () => _open(context, j.page),
          leading: _NumberBadge(number: j.number),
          title: Text(juzName(j.number), style: cairo(15.5, weight: FontWeight.w700, color: c.ink)),
          subtitle: Text('يبدأ من ${repo.memberLabel(['${j.surah}:${j.ayah}'])}',
              style: cairo(12, color: c.sub)),
          trailing: Text('ص ${ar(j.page)}', style: cairo(12.5, color: c.gold)),
        );
      },
    );
  }
}

class _Bookmarks extends StatelessWidget {
  const _Bookmarks();

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final state = AppScope.of(context);
    final repo = QuranRepository.instance;
    if (state.bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('لا توجد علامات بعد.\nاضغط رمز العلامة أعلى صفحة المصحف لحفظها.',
              textAlign: TextAlign.center, style: cairo(14, color: c.sub, height: 1.7)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final p in state.bookmarks)
          ListTile(
            onTap: () => _open(context, p),
            leading: Icon(Icons.bookmark_rounded, color: c.gold),
            title: Text('صفحة ${ar(p)}', style: cairo(15, weight: FontWeight.w700, color: c.ink)),
            subtitle: Text('سورة ${repo.surahForPage(p).name} — ${juzName(repo.juzForPage(p))}',
                style: cairo(12, color: c.sub)),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: c.sub),
              onPressed: () => state.toggleBookmark(p),
            ),
          ),
      ],
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  const _NumberBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.goldLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.gold.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Text(ar(number), style: cairo(14, weight: FontWeight.w700, color: c.greenText)),
    );
  }
}
