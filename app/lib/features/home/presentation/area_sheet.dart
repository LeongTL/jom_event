import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location.dart';
import '../../../core/theme/tokens.dart';

/// "Where to?": pick an area and a radius, then Show events. Nothing is fetched until the button is tapped.
class AreaSheet extends ConsumerStatefulWidget {
  const AreaSheet({super.key});

  @override
  ConsumerState<AreaSheet> createState() => _AreaSheetState();
}

class _AreaSheetState extends ConsumerState<AreaSheet> {
  late String _area = ref.read(areaSelectionProvider).area;
  late int _km = ref.read(areaSelectionProvider).km;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: k.line, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Where to?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in kAreas.keys) ChoiceChip(label: Text(a), selected: _area == a, onSelected: (_) => setState(() => _area = a)),
        ]),
        const SizedBox(height: 18),
        Text('Within', style: TextStyle(color: k.sheetInk.withValues(alpha: .6))),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final km in const [2, 5, 10]) ChoiceChip(label: Text('$km km'), selected: _km == km, onSelected: (_) => setState(() => _km = km)),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              ref.read(areaSelectionProvider.notifier).choose(_area, _km);
              Navigator.of(context).pop();
            },
            child: const Text('Show events'),
          ),
        ),
      ]),
    );
  }
}
