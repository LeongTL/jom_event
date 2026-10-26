import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';

/// "Where to?": pick an area and a radius, then Show events. Nothing is fetched until the button is tapped.
class AreaSheet extends ConsumerStatefulWidget {
  const AreaSheet({super.key});

  @override
  ConsumerState<AreaSheet> createState() => _AreaSheetState();
}

class _AreaSheetState extends ConsumerState<AreaSheet> {
  late String _area = ref.read(areaSelectionProvider).area;
  late int _km = ref.read(areaSelectionProvider).km;

  Widget _chip(String label, bool on, VoidCallback tap, {Key? key}) => GestureDetector(
        key: key,
        onTap: tap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? Calm.accSoft : Calm.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: on ? Calm.acc : Calm.line)),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: on ? Calm.acc : Calm.ink)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Calm.line, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Where to?', style: TextStyle(fontFamily: Calm.serif, fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final a in kAreas.keys) _chip(a, _area == a, () => setState(() => _area = a), key: Key('area-$a'))]),
        const SizedBox(height: 18),
        const Text('Within', style: TextStyle(color: Calm.mut, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [for (final km in const [2, 5, 10]) _chip('$km km', _km == km, () => setState(() => _km = km), key: Key('km-$km'))]),
        const SizedBox(height: 22),
        JomButton(
          label: 'Show events',
          onPressed: () {
            ref.read(areaSelectionProvider.notifier).choose(_area, _km);
            Navigator.of(context).pop();
          },
        ),
      ]),
    );
  }
}
