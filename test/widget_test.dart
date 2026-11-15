import 'package:flutter_test/flutter_test.dart';

import 'package:albayan/core/arabic.dart';
import 'package:albayan/data/models.dart';

void main() {
  test('تحويل الأرقام إلى أرقام عربية', () {
    expect(ar(48), '٤٨');
    expect(ar(604), '٦٠٤');
    expect(ar('2:123'), '٢:١٢٣');
  });

  test('صياغة عدد المواضع', () {
    expect(countPlaces(2), 'موضعان');
    expect(countPlaces(3), '٣ مواضع');
    expect(countPlaces(11), '١١ موضعًا');
  });

  test('أسماء الأجزاء', () {
    expect(juzName(1), 'الجزء الأول');
    expect(juzName(30), 'الجزء الثلاثون');
  });

  test('العضو الذي تنتمي له الآية في المجموعة', () {
    final g = MutGroup(
      0,
      [
        ['2:47', '2:48'],
        ['2:122', '2:123'],
      ],
      [<String>{}, <String>{}],
      true,
    );
    expect(g.memberOf('2:48'), 0);
    expect(g.memberOf('2:123'), 1);
    expect(g.memberOf('3:1'), -1);
  });
}
