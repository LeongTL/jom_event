import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

enum StatusTone { neutral, good, warn, bad }

/// The small rounded status label ("Confirmed", "Processing"...) in the prototype's colours.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = StatusTone.neutral});

  /// A pill for a booking status as the database spells it.
  factory StatusPill.booking(String status, {Key? key}) {
    final (label, tone) = switch (status) {
      'confirmed' => ('Confirmed', StatusTone.good),
      'processing' => ('Processing', StatusTone.warn),
      'attended' => ('Attended', StatusTone.good),
      'cancelled' => ('Cancelled', StatusTone.bad),
      'no_show' => ('No-show', StatusTone.bad),
      _ => (_readable(status), StatusTone.neutral),
    };
    return StatusPill(key: key, label: label, tone: tone);
  }

  final String label;
  final StatusTone tone;

  static String _readable(String s) {
    final text = s.replaceAll('_', ' ');
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    final (background, ink) = switch (tone) {
      StatusTone.good => (const Color(0xFF1FBF75), const Color(0xFFFFFFFF)),
      StatusTone.warn => (const Color(0xFFFFB020), const Color(0xFF2A1A00)),
      StatusTone.bad => (const Color(0xFFFF5A67), const Color(0xFFFFFFFF)),
      StatusTone.neutral => (k.card, k.sheetInk),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(label, style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
