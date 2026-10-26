import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/models/event_summary.dart';
import '../data/event_repository.dart';
import 'event_cards.dart';

const _chips = [('all', 'All'), ('make', 'Make'), ('move', 'Move'), ('meet', 'Meet'), ('free', 'Free')];

bool _in(EventSummary e, String cat) => cat == 'all' || (cat == 'free' ? e.isFree : e.categories.contains(cat));

/// "All events": a chip per category and every event nearest first. Opened with a category when it comes from a
/// section's View all.
class ViewAllScreen extends ConsumerStatefulWidget {
  const ViewAllScreen({super.key, this.category});
  final String? category;

  @override
  ConsumerState<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends ConsumerState<ViewAllScreen> {
  late String _cat = _chips.any((c) => c.$1 == widget.category) ? widget.category! : 'all';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(viewAllProvider);
    return Scaffold(
      key: const Key('view-all'),
      backgroundColor: Calm.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 20, 40),
        children: [
          Row(children: [
            GestureDetector(
              key: const Key('view-all-close'),
              onTap: () => context.canPop() ? context.pop() : context.go('/explore'),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Calm.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Calm.line)),
                child: const Icon(Icons.chevron_left, size: 22),
              ),
            ),
            const Expanded(child: Text('All events', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
            const SizedBox(width: 40),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (key, label) in _chips)
              GestureDetector(
                key: Key('chip-$key'),
                onTap: () => setState(() => _cat = key),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _cat == key ? Calm.accSoft : Calm.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cat == key ? Calm.acc : Calm.line),
                  ),
                  child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _cat == key ? Calm.acc : Calm.ink)),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          ...all.when(
            loading: () => [const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))],
            error: (_, _) => [const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('Could not load events. Check your connection.')))],
            data: (list) {
              final shown = [...list.where((e) => _in(e, _cat))]..sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
              return shown.isEmpty
                  ? [const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Text('Nothing right now', style: TextStyle(color: Calm.mut))))]
                  : [
                      Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('${shown.length} ${shown.length == 1 ? 'event' : 'events'} · nearest first', key: const Key('view-all-count'), style: const TextStyle(fontSize: 13, color: Calm.mut))),
                      for (final e in shown) EventRow(event: e),
                    ];
            },
          ),
        ],
      ),
    );
  }
}
