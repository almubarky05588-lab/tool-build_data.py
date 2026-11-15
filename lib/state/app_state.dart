import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// طريقة إظهار مواضع التشابه في الصفحة.
enum HighlightMode { color, margin, both }

/// موضع العودة بعد الانتقال إلى موضع متشابه.
class ReturnPoint {
  final int page;
  final String label; // مثل «البقرة، الآية ٤٨»
  const ReturnPoint(this.page, this.label);
}

/// حالة التطبيق: الإعدادات وآخر صفحة والتنقل بين المواضع.
class AppState extends ChangeNotifier {
  static const _kMode = 'mode';
  static const _kDark = 'dark';
  static const _kDiffOnly = 'diffOnly';
  static const _kReturn = 'returnButton';
  static const _kLastPage = 'lastPage';
  static const _kBookmarks = 'bookmarks';

  SharedPreferences? _prefs;

  HighlightMode mode = HighlightMode.color;
  bool dark = false;
  bool diffOnly = true;
  bool returnButton = true;
  int lastPage = 1;
  List<int> bookmarks = [];

  /// الصفحة الحالية في المصحف.
  int currentPage = 1;

  /// تبويب الشاشة الرئيسية (0 الرئيسية، 1 المصحف، 2 المتشابهات، 3 الإعدادات).
  int tab = 0;

  /// طلب الانتقال لصفحة؛ يزيد العدّاد في كل طلب جديد.
  int jumpRequest = 0;
  int jumpTarget = 1;

  /// كلمة/آية يُراد إبرازها بعد الانتقال (مثل «2:123»).
  String? focusAyah;

  ReturnPoint? returnPoint;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    mode = HighlightMode.values[(p.getInt(_kMode) ?? 0).clamp(0, 2)];
    dark = p.getBool(_kDark) ?? false;
    diffOnly = p.getBool(_kDiffOnly) ?? true;
    returnButton = p.getBool(_kReturn) ?? true;
    lastPage = (p.getInt(_kLastPage) ?? 1).clamp(1, 604);
    bookmarks = (p.getStringList(_kBookmarks) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    currentPage = lastPage;
    jumpTarget = lastPage;
  }

  void setMode(HighlightMode m) {
    mode = m;
    _prefs?.setInt(_kMode, m.index);
    notifyListeners();
  }

  void setDark(bool v) {
    dark = v;
    _prefs?.setBool(_kDark, v);
    notifyListeners();
  }

  void setDiffOnly(bool v) {
    diffOnly = v;
    _prefs?.setBool(_kDiffOnly, v);
    notifyListeners();
  }

  void setReturnButton(bool v) {
    returnButton = v;
    if (!v) returnPoint = null;
    _prefs?.setBool(_kReturn, v);
    notifyListeners();
  }

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  /// يُستدعى من شاشة المصحف عند تغيّر الصفحة.
  void onPageShown(int page) {
    currentPage = page;
    lastPage = page;
    _prefs?.setInt(_kLastPage, page);
    notifyListeners();
  }

  /// فتح صفحة في المصحف من أي شاشة.
  void openPage(int page, {String? focus}) {
    jumpTarget = page.clamp(1, 604);
    jumpRequest++;
    focusAyah = focus;
    tab = 1;
    notifyListeners();
  }

  /// الانتقال إلى موضع متشابه مع حفظ موضع العودة.
  void goToMutashabih(int page, String ayahKey, {ReturnPoint? from}) {
    if (from != null && returnButton) returnPoint = from;
    openPage(page, focus: ayahKey);
  }

  void goBack() {
    final r = returnPoint;
    returnPoint = null;
    if (r != null) openPage(r.page);
  }

  void dismissReturn() {
    returnPoint = null;
    notifyListeners();
  }

  void clearFocus() {
    if (focusAyah == null) return;
    focusAyah = null;
    notifyListeners();
  }

  bool isBookmarked(int page) => bookmarks.contains(page);

  void toggleBookmark(int page) {
    if (bookmarks.contains(page)) {
      bookmarks.remove(page);
    } else {
      bookmarks.add(page);
      bookmarks.sort();
    }
    _prefs?.setStringList(_kBookmarks, bookmarks.map((e) => '$e').toList());
    notifyListeners();
  }
}

/// يوفّر AppState لكل الشجرة: AppScope.of(context)
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// قراءة بدون الاشتراك في التحديثات (للأحداث).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
