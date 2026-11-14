import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/people_repository.dart';
import '../domain/person.dart';
import 'person_row.dart';

/// Who follows [userId], or who they follow, a page at a time.
class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    required this.followers,
  });
  final String userId;
  final bool followers;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  final _items = <Person>[];
  bool _loading = true;
  bool _more = false; // the last page was full, so there may be another
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _set(bool loading, String? error) => setState(() {
    _loading = loading;
    _error = error;
  });

  Future<void> _load() async {
    _set(true, null);
    try {
      final repo = ref.read(peopleRepositoryProvider);
      final page = widget.followers
          ? await repo.followers(widget.userId, offset: _items.length)
          : await repo.following(widget.userId, offset: _items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _more = page.length == peoplePageSize;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        _set(false, 'Could not load. Check your connection.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('follow-list-screen'),
    backgroundColor: Calm.bg,
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        BookingNav(title: widget.followers ? 'Followers' : 'Following'),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Calm.bad)),
        if (!_loading && _error == null && _items.isEmpty)
          const Text('Nobody yet', style: TextStyle(color: Calm.mut)),
        for (final p in _items) PersonRow(p),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_more && !_loading)
          TextButton(
            key: const Key('list-more'),
            onPressed: _load,
            child: const Text('Show more'),
          ),
      ],
    ),
  );
}
