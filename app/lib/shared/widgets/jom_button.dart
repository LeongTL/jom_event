import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The big rounded button from the prototype (`.btn`): 54 tall, accent when primary, card colour when secondary.
class JomButton extends StatelessWidget {
  const JomButton({super.key, required this.label, required this.onPressed, this.primary = true, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  /// Shows a spinner and ignores taps while something is happening.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    final background = primary ? k.accent : k.card;
    final ink = primary ? k.accentInk : k.sheetInk;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: ink,
          disabledBackgroundColor: background.withValues(alpha: .6),
          disabledForegroundColor: ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: busy ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: ink)) : Text(label),
      ),
    );
  }
}
