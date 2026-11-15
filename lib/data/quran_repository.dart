import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';
import 'models.dart';

/// مخزن بيانات المصحف والمتشابهات — يُحمَّل مرة واحدة عند بدء التطبيق
/// من الملفات المولّدة بسكربت tool/build_data.py.
class QuranRepository {
  static const totalPages = 604;

  final List<QPage> pages;
  final List<SurahInfo> surahs;
  final List<PartStart> juz;
  final List<PartStart> rub;
  final List<MutGroup> groups;
  final Map<String, List<int>> byAyah;
  final Map<String, List<QWord>> ayahWords;

  QuranRepository._(this.pages, this.surahs, this.juz, this.rub, this.groups,
      this.byAyah, this.ayahWords);

  static QuranRepository? _instance;
  static QuranRepository get instance => _instance!;

  static Future<QuranRepository> load() async {
    if (_instance != null) return _instance!;
    final pagesJson = await rootBundle.loadString('assets/quran/pages.json');
    final metaJson = await rootBundle.loadString('assets/quran/meta.json');
    final mutsJson = await rootBundle.loadString('assets/quran/mutashabihat.json');
    _instance = await Isolate.run(() => _parse(pagesJson, metaJson, mutsJson));
    return _instance!;
  }

  static QuranRepository _parse(String pagesJson, String metaJson, String mutsJson) {
    final pages = <QPage>[];
    final ayahWords = <String, List<QWord>>{};
    for (final p in (jsonDecode(pagesJson) as List)) {
      final num = p['p'] as int;
      final lines = <QLine>[];
      for (final l in (p['l'] as List)) {
        switch (l['t'] as String) {
          case 'h':
            lines.add(QLine.header(l['s'] as int));
          case 'b':
            lines.add(QLine.basmala(l['g'] as String));
          default:
            final words = <QWord>[];
            for (final w in (l['w'] as List)) {
              final word = QWord(w[0] as int, w[1] as int, w[2] as int,
                  w[3] as String, w[4] as String, num);
              words.add(word);
              ayahWords.putIfAbsent(word.ayahKey, () => []).add(word);
            }
            lines.add(QLine.text(words));
        }
      }
      pages.add(QPage(num, lines));
    }

    final meta = jsonDecode(metaJson) as Map<String, dynamic>;
    final surahs = [
      for (final s in meta['surahs'] as List)
        SurahInfo(s['n'] as int, s['name'] as String, s['ayahs'] as int,
            s['page'] as int, s['place'] as String),
    ];
    List<PartStart> parts(String key) => [
          for (final j in meta[key] as List)
            PartStart(j['n'] as int, j['s'] as int, j['a'] as int, j['page'] as int),
        ];

    final muts = jsonDecode(mutsJson) as Map<String, dynamic>;
    final groups = <MutGroup>[];
    final rawGroups = muts['groups'] as List;
    for (var i = 0; i < rawGroups.length; i++) {
      final g = rawGroups[i] as Map<String, dynamic>;
      groups.add(MutGroup(
        i,
        [for (final m in g['m'] as List) List<String>.from(m as List)],
        [for (final d in g['d'] as List) Set<String>.from(d as List)],
        (g['c'] ?? 0) != 0,
      ));
    }
    final byAyah = <String, List<int>>{
      for (final e in (muts['byAyah'] as Map<String, dynamic>).entries)
        e.key: List<int>.from(e.value as List),
    };

    return QuranRepository._(
        pages, surahs, parts('juz'), parts('rub'), groups, byAyah, ayahWords);
  }

  // ------------------------------------------------------------ استعلامات

  QPage page(int n) => pages[n - 1];

  List<int> groupsForAyah(String ayahKey) => byAyah[ayahKey] ?? const [];

  /// رقم مجموعة التلوين لهذه الكلمة، أو null إن لم تكن موضع تشابه.
  /// [diffOnly]: تلوين كلمات الاختلاف فقط، وإلا تُلوَّن الآية كاملة.
  int? highlightGroup(QWord w, {required bool diffOnly}) {
    if (w.glyph.isEmpty) return null;
    final ids = byAyah[w.ayahKey];
    if (ids == null) return null;
    for (final id in ids) {
      final g = groups[id];
      final m = g.memberOf(w.ayahKey);
      if (m < 0) continue;
      if (!diffOnly || g.diffs[m].isEmpty || g.diffs[m].contains(w.key)) return id;
    }
    return null;
  }

  /// مجموعات التشابه التي لها كلمات في هذا السطر (لعلامات الهامش).
  List<int> groupsInLine(QLine line, {required bool diffOnly}) {
    final out = <int>[];
    for (final w in line.words) {
      final g = highlightGroup(w, diffOnly: diffOnly);
      if (g != null && !out.contains(g)) out.add(g);
    }
    return out;
  }

  /// مجموعات التشابه الموجودة في الصفحة.
  List<int> groupsOnPage(int pageNo) {
    final out = <int>[];
    for (final line in page(pageNo).lines) {
      for (final w in line.words) {
        for (final id in groupsForAyah(w.ayahKey)) {
          if (!out.contains(id)) out.add(id);
        }
      }
    }
    return out;
  }

  int pageOfAyah(String ayahKey) => ayahWords[ayahKey]!.first.page;

  SurahInfo surah(int n) => surahs[n - 1];

  /// السورة التي تبدأ بها الصفحة (أول كلمة فيها).
  SurahInfo surahForPage(int pageNo) {
    for (final line in page(pageNo).lines) {
      if (line.type == LineType.header) return surah(line.surah);
      if (line.words.isNotEmpty) return surah(line.words.first.surah);
    }
    return surahs.first;
  }

  int juzForPage(int pageNo) {
    var n = 1;
    for (final j in juz) {
      if (j.page <= pageNo) n = j.number;
    }
    return n;
  }

  /// «البقرة، الآية ٤٨» أو «البقرة، الآيات ٤٧–٤٨»
  String memberLabel(List<String> member) {
    final first = member.first.split(':');
    final s = surah(int.parse(first[0]));
    if (member.length == 1) return '${s.name}، الآية ${ar(first[1])}';
    final last = member.last.split(':')[1];
    return '${s.name}، الآيات ${ar(first[1])}–${ar(last)}';
  }

  /// كلمات العضو مرتبة (قد تكون أكثر من آية).
  List<QWord> memberWords(List<String> member) => [
        for (final k in member) ...?ayahWords[k],
      ];

  int memberPage(List<String> member) => pageOfAyah(member.first);
}
