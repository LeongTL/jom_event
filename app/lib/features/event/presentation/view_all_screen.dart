import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/models/event_summary.dart';
import '../data/event_repository.dart';
import 'poster_card.dart';

const _cats = [('make', '🎨', 'Make'), ('move', '🏃', 'Move'), ('meet', '🫶', 'Meet'), ('free', '🆓', 'Free')];

bool _in(EventSummary e, String cat) => cat == 'free' ? e.isFree : e.categories.contains(cat);

/// "Everything in KL": a chip per category with its count, and either sections (All) or one grid (a chip).
class ViewAllScreen extends ConsumerStatefulWidget {
  const ViewAllScreen({super.key});

  @override
  ConsumerState<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends ConsumerState<ViewAllScreen> {
  String _cat = 'all';

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    final all = ref.watch(viewAllProvider);
    return Scaffold(
      key: const Key('view-all'),
      backgroundColor: k.sheet,
      body: DefaultTextStyle.merge(
        style: TextStyle(color: k.sheetInk),
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 9, 20, 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('EVERYTHING IN KL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: k.sheetInk.withValues(alpha: .6))),
                  Text(all.hasValue ? 'All ${all.value!.length} events' : 'All events',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                ]),
              ),
              GestureDetector(
                key: const Key('view-all-close'),
                onTap: () => context.canPop() ? context.pop() : context.go('/explore'),
                child: Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: k.card, shape: BoxShape.circle),
                    child: const Text('✕', style: TextStyle(fontSize: 18))),
              ),
            ]),
          ),
          Expanded(
            child: all.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('Could not load events. Check your connection.')),
              data: (list) => list.isEmpty ? const Center(child: Text('Nothing right now')) : _body(context, list),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _body(BuildContext context, List<EventSummary> list) {
    final k = context.jom;
    final chips = [('all', '✨', 'All', list.length), for (final (key, g, t) in _cats) (key, g, t, list.where((e) => _in(e, key)).length)]
        .where((c) => c.$4 > 0)
        .toList();
    void open(EventSummary e) => context.push('/event/${e.id}');
    Widget grid(List<EventSummary> l) => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 200),
          itemCount: l.length,
          itemBuilder: (_, i) => PosterCard(event: l[i], onTap: () => open(l[i])),
        );
    return Column(children: [
      SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
          children: [
            for (final (key, g, t, n) in chips)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  key: Key('chip-$key'),
                  onTap: () => setState(() => _cat = key),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _cat == key ? k.accent : k.card, borderRadius: BorderRadius.circular(18)),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '$g $t '),
                        TextSpan(text: '$n', style: TextStyle(fontSize: 12.5, color: (_cat == key ? k.accentInk : k.sheetInk).withValues(alpha: .65))),
                      ]),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _cat == key ? k.accentInk : k.sheetInk),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 40),
          children: _cat == 'all'
              ? [
                  for (final (key, g, t) in _cats)
                    if (list.any((e) => _in(e, key))) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Expanded(child: Text('$g $t', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                          Text('${list.where((e) => _in(e, key)).length}', style: TextStyle(fontSize: 12, color: k.sheetInk.withValues(alpha: .55))),
                        ]),
                      ),
                      grid(list.where((e) => _in(e, key)).toList()),
                    ],
                ]
              : [grid(list.where((e) => _in(e, _cat)).toList())],
        ),
      ),
    ]);
  }
}
