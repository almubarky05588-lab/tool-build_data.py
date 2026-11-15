/// نماذج بيانات المصحف والمتشابهات.
library;

/// كلمة في المصحف: موقعها (سورة:آية:كلمة) ورمزها في خط الصفحة.
class QWord {
  final int surah;
  final int ayah;
  final int index; // 0 = علامة آية منفصلة في سطر مستقل
  final String glyph; // رمز الكلمة (فارغ إذا كانت علامة آية فقط)
  final String marker; // رمز علامة نهاية الآية إن وُجد
  final int page;

  const QWord(this.surah, this.ayah, this.index, this.glyph, this.marker, this.page);

  String get key => '$surah:$ayah:$index';
  String get ayahKey => '$surah:$ayah';
}

enum LineType { header, basmala, text }

class QLine {
  final LineType type;
  final int surah; // لسطر اسم السورة
  final String glyphs; // لسطر البسملة
  final List<QWord> words;

  const QLine.header(this.surah)
      : type = LineType.header,
        glyphs = '',
        words = const [];
  const QLine.basmala(this.glyphs)
      : type = LineType.basmala,
        surah = 0,
        words = const [];
  const QLine.text(this.words)
      : type = LineType.text,
        surah = 0,
        glyphs = '';
}

class QPage {
  final int number;
  final List<QLine> lines;
  const QPage(this.number, this.lines);
}

class SurahInfo {
  final int number;
  final String name;
  final int ayahs;
  final int page;
  final String place;
  const SurahInfo(this.number, this.name, this.ayahs, this.page, this.place);
}

class PartStart {
  final int number;
  final int surah;
  final int ayah;
  final int page;
  const PartStart(this.number, this.surah, this.ayah, this.page);
}

/// مجموعة متشابهة: أعضاء (كل عضو آية أو آيات متتالية) وكلمات الاختلاف لكل عضو.
class MutGroup {
  final int id;
  final List<List<String>> members; // [["2:47","2:48"], ["2:122","2:123"]]
  final List<Set<String>> diffs; // كلمات الاختلاف لكل عضو "s:a:w"
  final bool showContext;

  const MutGroup(this.id, this.members, this.diffs, this.showContext);

  int memberOf(String ayahKey) {
    for (var i = 0; i < members.length; i++) {
      if (members[i].contains(ayahKey)) return i;
    }
    return -1;
  }
}
