import 'package:flutter/material.dart';

import '../../../core/theme/calm.dart';

/// A price bubble with a point at the bottom. The selected pin is accent, a booked one is dark.
class PricePin extends StatelessWidget {
  const PricePin({
    super.key,
    required this.label,
    this.selected = false,
    this.booked = false,
  });
  final String label;
  final bool selected, booked;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Calm.acc : (booked ? Calm.ink : Colors.white);
    final border = selected ? Calm.acc : (booked ? Calm.ink : Calm.line);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 12 : 10,
            vertical: selected ? 6 : 5,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E1B2430),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: selected ? 14 : 13,
              fontWeight: FontWeight.w600,
              color: selected || booked ? Colors.white : Calm.ink,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -5),
          child: Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                  right: BorderSide(color: border),
                  bottom: BorderSide(color: border),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
