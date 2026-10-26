import 'package:flutter/material.dart';

import '../../core/theme/calm.dart';

/// The Calm button (`.btn`): 50 tall, 12 radius, accent when primary, white with a hairline when secondary.
class JomButton extends StatelessWidget {
  const JomButton({super.key, required this.label, required this.onPressed, this.primary = true, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  /// Shows a spinner and ignores taps while something is happening.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final background = primary ? Calm.acc : Calm.surface;
    final ink = primary ? Colors.white : Calm.ink;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: ink,
          disabledBackgroundColor: background.withValues(alpha: .6),
          disabledForegroundColor: ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: primary ? BorderSide.none : const BorderSide(color: Calm.line)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: busy ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: ink)) : Text(label),
      ),
    );
  }
}
