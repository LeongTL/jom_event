import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/calm.dart';

/// Stands in for a screen a later task builds, so the whole route map can exist and be tested now.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.note,
    this.child,
    this.tabBarBelow = false,
  });

  final String title;
  final String? note;
  final Widget? child;

  /// Leaves room under the content for the floating tab bar.
  final bool tabBarBelow;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, tabBarBelow ? 120 : 24),
          children: [
            if (context.canPop())
              Align(
                alignment: Alignment.centerLeft,
                child: BackButton(onPressed: () => context.pop()),
              ),
            Text(
              title,
              key: const Key('screen-title'),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              note ?? 'This screen is built in a later task.',
              style: TextStyle(color: k.sheetInk.withValues(alpha: .7)),
            ),
            if (child != null) ...[const SizedBox(height: 24), child!],
          ],
        ),
      ),
    );
  }
}
