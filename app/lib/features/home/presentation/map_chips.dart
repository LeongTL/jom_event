import 'package:flutter/material.dart';

import '../../../core/theme/calm.dart';

const mapChips = [
  ('all', 'All'),
  ('make', 'Make'),
  ('move', 'Move'),
  ('meet', 'Meet'),
  ('free', 'Free'),
  ('tonight', 'Tonight'),
];

/// The filter chips over the map; [selected] is one of the keys above.
class MapChips extends StatelessWidget {
  const MapChips({super.key, required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final (k, l) in mapChips)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: Key('map-chip-$k'),
              onTap: () => onSelect(k),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == k ? Calm.acc : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected == k ? Calm.acc : Calm.line,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F1B2430),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: selected == k ? Colors.white : Calm.ink,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
