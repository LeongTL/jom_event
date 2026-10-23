import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The on/off switch (prototype .sw): 50 x 30, a white knob. A null [onChanged] makes it fixed.
class JomSwitch extends StatelessWidget {
  const JomSwitch({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(color: value ? k.accent : k.line, borderRadius: BorderRadius.circular(15)),
        child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      ),
    );
  }
}
