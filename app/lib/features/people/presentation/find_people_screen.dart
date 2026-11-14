import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/people_repository.dart';
import '../domain/person.dart';
import 'person_row.dart';

/// Search guests and hosts by name or @username.
class FindPeopleScreen extends ConsumerStatefulWidget {
  const FindPeopleScreen({super.key});

  @override
  ConsumerState<FindPeopleScreen> createState() => _FindPeopleScreenState();
}

class _FindPeopleScreenState extends ConsumerState<FindPeopleScreen> {
  Timer? _pause;
  String _query = '';
  List<Person>? _results; // null until a search of 2+ characters has answered
  String? _error;

  @override
  void dispose() {
    _pause?.cancel();
    super.dispose();
  }

  void _set(List<Person>? results, String? error) => setState(() {
    _results = results;
    _error = error;
  });

  void _changed(String text) {
    _pause?.cancel();
    final q = text.trim();
    _query = q;
    if (q.length < 2) {
      return _set(null, null);
    }
    _pause = Timer(const Duration(milliseconds: 300), () async {
      try {
        final found = await ref.read(peopleRepositoryProvider).search(q);
        if (mounted && q == _query) _set(found, null);
      } catch (_) {
        if (mounted && q == _query) {
          _set(null, 'Could not search. Check your connection.');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('find-people-screen'),
    backgroundColor: Calm.bg,
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const BookingNav(title: 'Find people'),
        TextField(
          key: const Key('people-search'),
          onChanged: _changed,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Search name or @username',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Calm.bad)),
        if (_results != null && _results!.isEmpty)
          const Text('No one found', style: TextStyle(color: Calm.mut)),
        for (final p in _results ?? const <Person>[]) PersonRow(p),
      ],
    ),
  );
}
