import 'package:flutter/material.dart';

import '../../core/theme/calm.dart';

enum StatusTone { neutral, good, warn, bad }

/// The small rounded status label ("Confirmed", "Processing"...) in the Calm colours.
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
    final (background, ink) = switch (tone) {
      StatusTone.good => (Calm.okSoft, Calm.ok),
      StatusTone.warn => (Calm.warnSoft, Calm.warn),
      StatusTone.bad => (Calm.badSoft, Calm.bad),
      StatusTone.neutral => (Calm.chip, Calm.mut),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(label, style: TextStyle(color: ink, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
