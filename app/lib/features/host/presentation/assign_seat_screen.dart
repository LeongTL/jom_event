import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../people/data/people_repository.dart';
import '../../people/domain/person.dart';
import '../../people/presentation/person_row.dart' show PersonAvatar;
import '../data/host_repository.dart';
import '../domain/host.dart';

/// Host mode: give someone a seat by hand (/host-mode/assign-seat). Any registered person found by name or @username,
/// for this event or another of mine, with no order needed. A late receipt can be linked.
class AssignSeatScreen extends ConsumerStatefulWidget {
  const AssignSeatScreen({
    super.key,
    this.eventId,
    this.userId,
    this.receiptId,
  });
  final String? eventId, userId, receiptId;

  @override
  ConsumerState<AssignSeatScreen> createState() => _AssignSeatState();
}

class _AssignSeatState extends ConsumerState<AssignSeatScreen> {
  Timer? _pause;
  String _query = '';
  List<Person>? _results;
  Person? _person;
  String? _eventId;
  int _people = 1;
  bool _over = false, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _eventId = widget.eventId;
    final uid = widget.userId;
    if (uid != null) {
      ref.read(peopleRepositoryProvider).person(uid).then((p) {
        if (mounted) setState(() => _person = p);
      });
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    super.dispose();
  }

  void _changed(String text) {
    _pause?.cancel();
    final q = text.trim();
    _query = q;
    if (q.length < 2) {
      setState(() => _results = null);
      return;
    }
    _pause = Timer(const Duration(milliseconds: 300), () async {
      try {
        final found = await ref.read(peopleRepositoryProvider).search(q);
        if (mounted && q == _query) setState(() => _results = found);
      } catch (_) {
        if (mounted && q == _query) {
          setState(() => _error = 'Could not search. Check your connection.');
        }
      }
    });
  }

  Future<void> _assign() async {
    final person = _person, event = _eventId;
    if (person == null || event == null) {
      setState(() => _error = 'Choose who gets the seat.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(hostRepositoryProvider)
          .assignSeat(
            eventId: event,
            userId: person.userId,
            people: _people,
            receiptId: widget.receiptId,
            allowOverCapacity: _over,
          );
      ref.invalidate(pendingReceiptsProvider);
      ref.invalidate(hostEventsProvider);
      ref.invalidate(hostGuestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${person.name} has a seat')));
        context.canPop() ? context.pop() : context.go('/host-mode/home');
      }
    } on HostError catch (e) {
      if (mounted) setState(() => _error = e.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events =
        ref.watch(hostEventsProvider('published')).value ??
        const <HostEventRow>[];
    final current = events.where((e) => e.id == _eventId).firstOrNull;
    final full =
        current != null &&
        current.seatsSold + _people > (current.capacity ?? 0);
    return Scaffold(
      key: const Key('assign-seat'),
      backgroundColor: Calm.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          const BookingNav(title: 'Assign a seat'),
          if (_person == null) ...[
            TextField(
              key: const Key('assign-search'),
              onChanged: _changed,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'Search name or @username',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            for (final p in _results ?? const <Person>[])
              KeyedSubtree(
                key: Key('assign-person-${p.userId}'),
                child: CardBox(
                  gap: 8,
                  onTap: () => setState(() => _person = p),
                  child: _PersonLine(p),
                ),
              ),
          ] else
            CardBox(
              key: const Key('assign-selected'),
              onTap: () => setState(() => _person = null),
              child: _PersonLine(_person!),
            ),
          const SizedBox(height: 8),
          const Text('Event', style: TextStyle(color: Calm.mut)),
          DropdownButton<String>(
            key: const Key('assign-event'),
            isExpanded: true,
            value: events.any((e) => e.id == _eventId) ? _eventId : null,
            hint: const Text('Choose an event'),
            items: [
              for (final e in events)
                DropdownMenuItem(value: e.id, child: Text(e.title)),
            ],
            onChanged: (v) => setState(() => _eventId = v),
          ),
          const SizedBox(height: 12),
          const Text('People', style: TextStyle(color: Calm.mut)),
          Row(
            children: [
              for (final n in [1, 2])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('assign-people-$n'),
                    label: Text('$n'),
                    selected: _people == n,
                    onSelected: (_) => setState(() => _people = n),
                  ),
                ),
            ],
          ),
          if (full)
            SwitchListTile(
              key: const Key('assign-over-capacity'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow over capacity'),
              subtitle: const Text('Add them even though every spot is taken.'),
              value: _over,
              onChanged: (v) => setState(() => _over = v),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Calm.bad,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: const Key('assign-confirm'),
            child: JomButton(
              label: 'Give seat',
              busy: _busy,
              onPressed: _assign,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonLine extends StatelessWidget {
  const _PersonLine(this.p);
  final Person p;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      PersonAvatar(p, size: 40),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            '@${p.username}',
            style: const TextStyle(color: Calm.mut, fontSize: 13),
          ),
        ],
      ),
    ],
  );
}
