import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/quran_repository.dart';
import '../../state/app_state.dart';
import 'qcf_words.dart';

/// يفتح لوحة مواضع التشابه لآية معيّنة.
/// [originPage]: الصفحة التي فُتحت منها اللوحة (لزر العودة)، وتكون null من الفهرس.
Future<void> showMutashabihSheet(
  BuildContext context, {
  required String ayahKey,
  int? originPage,
  int? onlyGroup,
}) {
  final repo = QuranRepository.instance;
  final ids = onlyGroup != null ? [onlyGroup] : repo.groupsForAyah(ayahKey);
  if (ids.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.68,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => _SheetBody(
        ayahKey: ayahKey,
        groupIds: ids,
        originPage: originPage,
        scroll: scroll,
      ),
    ),
  );
}

class _SheetBody extends StatelessWidget {
  final String ayahKey;
  final List<int> groupIds;
  final int? originPage;
  final ScrollController scroll;

  const _SheetBody({
    required this.ayahKey,
    required this.groupIds,
    required this.originPage,
    required this.scroll,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    final first = repo.groups[groupIds.first];
    final total = groupIds.length == 1 ? first.members.length : null;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c.group(first.id), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text('مواضع التشابه', style: cairo(19, weight: FontWeight.w700, color: c.greenText)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: c.sub),
              style: IconButton.styleFrom(backgroundColor: c.chip),
            ),
          ],
        ),
        Text(
          total != null
              ? '${countPlaces(total)} — الكلمات الملوّنة مواضع الاختلاف'
              : 'الآية في ${ar(groupIds.length)} مجموعات متشابهة',
          style: cairo(12.5, color: c.sub),
        ),
        const SizedBox(height: 14),
        for (final id in groupIds) ...[
          if (groupIds.length > 1) _GroupTitle(group: repo.groups[id]),
          for (var m = 0; m < repo.groups[id].members.length; m++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MemberCard(
                group: repo.groups[id],
                memberIndex: m,
                isCurrent: originPage != null && repo.groups[id].members[m].contains(ayahKey),
                originPage: originPage,
                originLabel: repo.memberLabel([ayahKey]),
              ),
            ),
        ],
        if (originPage != null && AppScope.read(context).returnButton)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.undo_rounded, color: c.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'بعد الانتقال يظهر لك زر «العودة إلى صفحة ${ar(originPage!)}»',
                    style: cairo(12, color: c.sub),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final MutGroup group;
  const _GroupTitle({required this.group});

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c.group(group.id), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(countPlaces(group.members.length),
              style: cairo(13, weight: FontWeight.w700, color: c.group(group.id))),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final MutGroup group;
  final int memberIndex;
  final bool isCurrent;
  final int? originPage;
  final String originLabel;

  const _MemberCard({
    required this.group,
    required this.memberIndex,
    required this.isCurrent,
    required this.originPage,
    required this.originLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColorsScope.of(context);
    final repo = QuranRepository.instance;
    final member = group.members[memberIndex];
    final color = c.group(group.id);
    final page = repo.memberPage(member);
    final state = AppScope.read(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: isCurrent ? color.withValues(alpha: 0.07) : c.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? color.withValues(alpha: 0.5) : c.line,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(repo.memberLabel(member),
                  style: cairo(14.5, weight: FontWeight.w700, color: c.ink)),
              const SizedBox(width: 8),
              Text('صفحة ${ar(page)}', style: cairo(11.5, color: c.sub)),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                  child: Text('أنت هنا',
                      style: cairo(11, weight: FontWeight.w600, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          QcfWords(
            words: repo.memberWords(member),
            highlight: group.diffs[memberIndex],
            highlightColor: color,
            fontSize: 21,
          ),
          if (group.diffs[memberIndex].isEmpty && group.members.length > 1)
            Text('مطابقة للموضع الآخر لفظًا', style: cairo(11.5, color: c.sub)),
          if (!isCurrent) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                state.goToMutashabih(
                  page,
                  member.first,
                  from: originPage == null ? null : ReturnPoint(originPage!, originLabel),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: c.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.chevron_left_rounded),
              label: Text('اذهب إلى الموضع في صفحة ${ar(page)}',
                  style: cairo(14, weight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}
