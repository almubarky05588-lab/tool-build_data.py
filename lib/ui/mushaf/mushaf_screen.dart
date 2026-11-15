import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/theme.dart';
import '../widgets/ornament.dart';
import '../../data/models.dart';
import '../../data/page_fonts.dart';
import '../../data/quran_repository.dart';
import '../../state/app_state.dart';
import '../index_screen.dart';
import 'mushaf_page.dart';
import 'mutashabih_sheet.dart';

/// شاشة المصحف: 604 صفحات بالتقليب، مع شريط المتشابه وزر العودة.
class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  PageController? _controller;
  int _handledJump = -1;
  Timer? _focusTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    _controller ??= PageController(initialPage: state.lastPage - 1);
    if (state.jumpRequest != _handledJump) {
      _handledJump = state.jumpRequest;
      final target = state.jumpTarget - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctrl = _controller;
        if (ctrl != null && ctrl.hasClients && ctrl.page?.round() != target) {
          ctrl.jumpToPage(target);
        }
      });
      if (state.focusAyah != null) {
        _focusTimer?.cancel();
        _focusTimer = Timer(const Duration(seconds: 4), state.clearFocus);
      }
    }
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final page = index + 1;
    AppScope.read(context).onPageShown(page);
    // تحميل خطوط الصفحات المجاورة مسبقًا لتقليب سلس
    for (final p in [page - 1, page + 1, page + 2]) {
      PageFonts.ensure(p);
    }
  }

  void _openWord(QWord w, int page) {
    if (QuranRepository.instance.groupsForAyah(w.ayahKey).isEmpty) return;
    showMutashabihSheet(context, ayahKey: w.ayahKey, originPage: page);
  }

  void _openMarker(int groupId, QLine line, int page) {
    final g = QuranRepository.instance.groups[groupId];
    final ayah = line.words.firstWhere((w) => g.memberOf(w.ayahKey) >= 0).ayahKey;
    showMutashabihSheet(context, ayahKey: ayah, originPage: page, onlyGroup: groupId);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    final page = state.currentPage;
    final surah = repo.surahForPage(page);
    final juz = repo.juzForPage(page);
    final groupsHere = repo.groupsOnPage(page);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 170,
            child: OrnamentFill(
              color: AppColorsScope.of(context).gold.withValues(alpha: 0.2),
              fade: 1,
            ),
          ),
          SafeArea(
        child: Column(
          children: [
            // ------------------------------------------------ الشريط العلوي
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.home_rounded,
                    tooltip: 'الرئيسية',
                    onTap: () => state.setTab(0),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(surah.name,
                            style: cairo(17, weight: FontWeight.w700, color: c.greenText)),
                        Text(juzName(juz), style: cairo(11.5, color: c.sub)),
                      ],
                    ),
                  ),
                  _RoundButton(
                    icon: state.isBookmarked(page)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    tooltip: 'علامة',
                    onTap: () => state.toggleBookmark(page),
                  ),
                  const SizedBox(width: 6),
                  _RoundButton(
                    icon: Icons.format_list_bulleted_rounded,
                    tooltip: 'الفهرس',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const IndexScreen()),
                    ),
                  ),
                ],
              ),
            ),
            // ------------------------------------------------ شريط المتشابه
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  if (groupsHere.isNotEmpty) ...[
                    SizedBox(
                      width: 12.0 + 8.0 * (groupsHere.length.clamp(1, 4) - 1),
                      height: 12,
                      child: Stack(
                        children: [
                          for (var i = 0; i < groupsHere.length.clamp(0, 4); i++)
                            PositionedDirectional(
                              start: i * 8.0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: c.group(groupsHere[i]),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.bg, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      groupsHere.isEmpty
                          ? 'لا مواضع متشابهة في هذه الصفحة'
                          : 'في الصفحة ${countPlaces(groupsHere.length)} متشابهة',
                      style: cairo(12.5, weight: FontWeight.w500, color: c.ink),
                    ),
                  ),
                  _ModeToggle(mode: state.mode, onChanged: state.setMode),
                ],
              ),
            ),
            // ------------------------------------------------ الصفحة
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: QuranRepository.totalPages,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) => _PageFrame(
                      pageNo: index + 1,
                      onWordTap: (w) => _openWord(w, index + 1),
                      onMarkerTap: (g, l) => _openMarker(g, l, index + 1),
                    ),
                  ),
                  if (state.focusAyah != null)
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: c.green,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'وصلت إلى ${repo.memberLabel([state.focusAyah!])}',
                            style: cairo(12.5, weight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ------------------------------------------------ الأسفل
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: state.returnPoint != null
                  ? _ReturnPill(point: state.returnPoint!)
                  : _Pager(page: page, controller: _controller),
            ),
          ],
        ),
      ),
          ],
        ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  final int pageNo;
  final void Function(QWord) onWordTap;
  final void Function(int, QLine) onMarkerTap;
  const _PageFrame({required this.pageNo, required this.onWordTap, required this.onMarkerTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: c.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.goldLight),
          boxShadow: const [
            BoxShadow(color: Color(0x1A5A4519), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -6),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.gold.withValues(alpha: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
          child: Column(
            children: [
              Row(
                children: [
                  Text('سورة ${repo.surahForPage(pageNo).name}',
                      style: cairo(11, weight: FontWeight.w500, color: c.gold)),
                  const Spacer(),
                  Text(juzName(repo.juzForPage(pageNo)),
                      style: cairo(11, weight: FontWeight.w500, color: c.gold)),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: MushafPage(
                  pageNo: pageNo,
                  onWordTap: onWordTap,
                  onMarkerTap: onMarkerTap,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(ar(pageNo),
                    style: cairo(12, weight: FontWeight.w700, color: c.greenText)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: c.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.line),
          ),
          child: Icon(icon, size: 20, color: c.greenText),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final HighlightMode mode;
  final ValueChanged<HighlightMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    Widget seg(String label, HighlightMode m) {
      final on = mode == m;
      return GestureDetector(
        onTap: () => onChanged(m),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: on ? c.paper : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              style: cairo(12,
                  weight: on ? FontWeight.w700 : FontWeight.w400,
                  color: on ? c.greenText : c.sub)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('تلوين', HighlightMode.color),
          seg('هامش', HighlightMode.margin),
          seg('معًا', HighlightMode.both),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final PageController? controller;
  const _Pager({required this.page, required this.controller});

  void _go(int target) {
    final ctrl = controller;
    if (ctrl == null || target < 1 || target > 604) return;
    ctrl.animateToPage(target - 1,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    return Row(
      children: [
        TextButton.icon(
          onPressed: page > 1 ? () => _go(page - 1) : null,
          icon: Icon(Icons.chevron_right_rounded, color: c.sub),
          label: Text('السابقة', style: cairo(12.5, color: c.sub)),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: c.green, borderRadius: BorderRadius.circular(20)),
          child: Text('صفحة ${ar(page)} من ٦٠٤',
              style: cairo(13, weight: FontWeight.w600, color: Colors.white)),
        ),
        const Spacer(),
        TextButton(
          onPressed: page < 604 ? () => _go(page + 1) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('التالية', style: cairo(12.5, color: c.sub)),
              Icon(Icons.chevron_left_rounded, color: c.sub),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReturnPill extends StatelessWidget {
  final ReturnPoint point;
  const _ReturnPill({required this.point});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final state = AppScope.read(context);
    return Center(
      child: Material(
        color: c.pillColor,
        borderRadius: BorderRadius.circular(24),
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: state.goBack,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: c.gold, shape: BoxShape.circle),
                  child: const Icon(Icons.undo_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('العودة إلى صفحة ${ar(point.page)}',
                        style: cairo(14, weight: FontWeight.w700, color: Colors.white)),
                    Text(point.label, style: cairo(11, color: const Color(0xFFBFB6A3))),
                  ],
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: state.dismissReturn,
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFD9D2C3)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x1FFFFFFF),
                    minimumSize: const Size(30, 30),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on AppColors {
  /// لون داكن لزر العودة العائم في الوضعين.
  Color get pillColor =>
      paper.computeLuminance() > 0.5 ? const Color(0xFF1F1B14) : const Color(0xFF2A3833);
}
