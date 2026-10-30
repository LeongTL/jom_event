import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/domain/ticket.dart';
import '../../event/domain/event_labels.dart';
import '../data/review_repository.dart';
import '../domain/review.dart';

/// Stars, tags and a few words about an event I attended. The server decides who may review; a booking that
/// was not attended just gets a short note here instead of the form.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _body = TextEditingController();
  final _tags = <String>{};
  var _stars = 0;
  var _busy = false;
  var _needStar = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_stars == 0) return setState(() => _needStar = true);
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reviewRepositoryProvider).submit(
        widget.bookingId,
        _stars,
        [
          for (final t in reviewTags.keys)
            if (_tags.contains(t)) t,
        ],
        _body.text.trim(),
      );
      ref.invalidate(myReviewsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Thanks for your review')),
      );
      if (mounted) context.canPop() ? context.pop() : context.go('/tickets');
    } on ReviewError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not send your review. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final past = ref.watch(ticketsProvider(TicketScope.past));
    return Scaffold(
      key: const Key('review-screen'),
      backgroundColor: Calm.bg,
      body: past.when(
        loading: () => Padding(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 0),
          child: Skeleton.rows(2),
        ),
        error: (_, _) => const Center(
          child: Text('Could not load this event. Check your connection.'),
        ),
        data: (list) {
          final t = list.where((t) => t.id == widget.bookingId).firstOrNull;
          if (t == null || t.booking.status != 'attended') {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: const [
                BookingNav(title: 'Review'),
                Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'Only events you attended can be reviewed.',
                      style: TextStyle(color: Calm.mut),
                    ),
                  ),
                ),
              ],
            );
          }
          return _form(t);
        },
      ),
    );
  }

  Widget _form(Ticket t) {
    final e = t.event;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
          children: [
            const BookingNav(title: 'Review'),
            Text(
              e.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: Calm.serif,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                dateLabel(e.startsAt),
                if (e.hostName != null) e.hostName!,
              ].join(' · '),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Calm.mut, fontSize: 13.5),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  GestureDetector(
                    key: Key('star-$i'),
                    onTap: () => setState(() {
                      _stars = i;
                      _needStar = false;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i <= _stars ? Icons.star : Icons.star_border,
                        size: 40,
                        color: const Color(0xFFD69A2D),
                      ),
                    ),
                  ),
              ],
            ),
            if (_needStar)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Tap a star to rate',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Calm.bad, fontSize: 13),
                ),
              ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in reviewTags.entries)
                  GestureDetector(
                    key: Key('tag-${tag.key}'),
                    onTap: () => setState(
                      () => _tags.contains(tag.key)
                          ? _tags.remove(tag.key)
                          : _tags.add(tag.key),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _tags.contains(tag.key)
                            ? Calm.accSoft
                            : Calm.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _tags.contains(tag.key) ? Calm.acc : Calm.line,
                        ),
                      ),
                      child: Text(
                        tag.value,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: _tags.contains(tag.key) ? Calm.acc : Calm.ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Your review',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Calm.mut,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('review-body'),
              controller: _body,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'What was it like?',
                filled: true,
                fillColor: Calm.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Calm.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Calm.line),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '✓ Verified attendee',
              textAlign: TextAlign.center,
              style: TextStyle(color: Calm.mut, fontSize: 13),
            ),
          ],
        ),
        CtaBar(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: const Key('submit-review'),
                child: JomButton(
                  label: 'Submit review',
                  busy: _busy,
                  onPressed: _submit,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
