import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../backend_check.dart';
import '../money.dart';
import '../theme/tokens.dart';
import 'placeholder_screen.dart';

/// Explore until Home (Task 15) exists. Reads the live backend, which proves the connection, the data layer,
/// EventSummary and formatMoney together.
class ExplorePlaceholder extends ConsumerWidget {
  const ExplorePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final check = ref.watch(backendCheckProvider);
    return PlaceholderScreen(
      title: 'Explore',
      note: 'Home (Task 15) replaces this. For now it reads the live backend to show the app is connected.',
      tabBarBelow: true,
      child: check.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Could not reach the backend', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$e', style: TextStyle(color: k.sheetInk.withValues(alpha: .6), fontSize: 12)),
        ]),
        data: (data) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.check_circle, color: const Color(0xFF1FBF75), size: 20),
            const SizedBox(width: 8),
            const Text('Connected to the backend', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text('${data.totalEvents} events across KL and Selangor', style: TextStyle(color: k.sheetInk.withValues(alpha: .7))),
          const SizedBox(height: 16),
          Text('HAPPENING NOW OR SOON', style: TextStyle(color: k.sheetInk.withValues(alpha: .6), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          for (final e in data.now.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [e.colorA, e.colorB], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: SizedBox(width: 48, height: 48, child: Center(child: Text(e.glyph, style: const TextStyle(fontSize: 24)))),
              ),
              title: Text(e.title),
              subtitle: Text('${formatMoney(e.priceSen)} · ${e.area ?? 'KL'}'),
              onTap: () => context.push('/event/${e.id}'),
            ),
        ]),
      ),
    );
  }
}
