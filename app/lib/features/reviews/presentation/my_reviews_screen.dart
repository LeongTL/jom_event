import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/domain/ticket.dart';
import '../../event/domain/event_labels.dart';
import '../data/review_repository.dart';
import '../domain/review.dart';

/// The reviews I wrote, newest first. There is no edit or delete: the database keeps one review per booking.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles = {for (final t in ref.watch(ticketsProvider(TicketScope.past)).value ?? const <Ticket>[]) t.id: t.event.title};
    return Scaffold(
      key: const Key('my-reviews-screen'),
      backgroundColor: Calm.bg,
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        const BookingNav(title: 'My reviews'),
        ref.watch(myReviewsProvider).when(
              loading: () => Skeleton.rows(2),
              error: (_, _) => const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('Could not load your reviews. Check your connection.'))),
              data: (list) => list.isEmpty
                  ? const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('You have not written any reviews yet.', style: TextStyle(color: Calm.mut))))
                  : Column(children: [for (final r in list) _Row(r, titles[r.bookingId] ?? 'Event')]),
            ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.r, this.title);
  final Review r;
  final String title;

  @override
  Widget build(BuildContext context) => CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(shortDate(r.createdAt), style: const TextStyle(fontSize: 13, color: Calm.mut)),
          ]),
          const SizedBox(height: 4),
          Row(children: [for (var i = 1; i <= 5; i++) Icon(i <= r.stars ? Icons.star : Icons.star_border, size: 18, color: const Color(0xFFD69A2D))]),
          if (r.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in r.tags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Calm.chip, borderRadius: BorderRadius.circular(10)),
                  child: Text(reviewTags[t] ?? t, style: const TextStyle(fontSize: 12.5)),
                ),
            ]),
          ],
          if ((r.body ?? '').isNotEmpty) ...[const SizedBox(height: 8), Text(r.body!, style: const TextStyle(fontFamily: Calm.serif, fontSize: 15, height: 1.4))],
        ]),
      );
}
