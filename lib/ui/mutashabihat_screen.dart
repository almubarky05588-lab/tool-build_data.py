import 'package:flutter/material.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import 'widgets/ornament.dart';
import '../data/models.dart';
import '../data/quran_repository.dart';
import 'mushaf/mutashabih_sheet.dart';
import 'mushaf/qcf_words.dart';

/// فهرس المتشابهات: كل المجموعات مع البحث بالسورة أو رقم الآية.
class MutashabihatScreen extends StatefulWidget {
  const MutashabihatScreen({super.key});

  @override
  State<MutashabihatScreen> createState() => _MutashabihatScreenState();
}

class _MutashabihatScreenState extends State<MutashabihatScreen> {
  String _query = '';

  List<MutGroup> _filtered() {
    final repo = QuranRepository.instance;
    final q = ar(_query.trim());
    if (q.isEmpty) return repo.groups;
    return [
      for (final g in repo.groups)
        if (g.members.any((m) => repo.memberLabel(m).contains(q))) g,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final groups = _filtered();
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('فهرس المتشابهات',
                          style: cairo(24, weight: FontWeight.w700, color: c.greenText)),
                      Text('${ar(groups.length)} مجموعة — اضغط أي مجموعة لفتح مواضعها',
                          style: cairo(12.5, color: c.sub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: cairo(14, color: c.ink),
              decoration: InputDecoration(
                hintText: 'ابحث باسم السورة أو رقم الآية',
                hintStyle: cairo(13.5, color: c.sub),
                prefixIcon: Icon(Icons.search_rounded, color: c.sub),
                filled: true,
                fillColor: c.paper,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.line),
                ),
              ),
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? Center(child: Text('لا نتائج', style: cairo(14, color: c.sub)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                    itemCount: groups.length,
                    itemBuilder: (context, i) => _GroupCard(group: groups[i]),
                  ),
          ),
        ],
      ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final MutGroup group;
  const _GroupCard({required this.group});

  /// مقطع قصير حول أول كلمة اختلاف في العضو الأول.
  List<QWord> _snippet(QuranRepository repo) {
    final words = repo.memberWords(group.members.first).where((w) => w.glyph.isNotEmpty).toList();
    final diff = group.diffs.first;
    var start = words.indexWhere((w) => diff.contains(w.key));
    start = start < 0 ? 0 : (start - 2).clamp(0, words.length);
    final end = (start + 7).clamp(0, words.length);
    return words.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    final color = c.group(group.id);
    final others = [for (final m in group.members.skip(1)) repo.memberLabel(m)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showMutashabihSheet(
          context,
          ayahKey: group.members.first.first,
          onlyGroup: group.id,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: c.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(repo.memberLabel(group.members.first),
                        style: cairo(14, weight: FontWeight.w700, color: c.ink)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(countPlaces(group.members.length),
                        style: cairo(11, weight: FontWeight.w600, color: color)),
                  ),
                  Icon(Icons.chevron_left_rounded, color: c.sub, size: 20),
                ],
              ),
              Text('يتشابه مع: ${others.join('، ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: cairo(12, color: c.sub)),
              const SizedBox(height: 4),
              QcfWords(
                words: _snippet(repo),
                highlight: group.diffs.first,
                highlightColor: color,
                fontSize: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
