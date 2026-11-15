import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/people_repository.dart';
import 'person_screen.dart';

/// `/u/:username`: a shared link to a person or host. Opens their page, or says there is no such profile.
class PersonByUsernameScreen extends ConsumerWidget {
  const PersonByUsernameScreen({super.key, required this.username});
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(personIdByUsernameProvider(username))
      .when(
        loading: () => Scaffold(
          backgroundColor: Calm.bg,
          body: SafeArea(child: Skeleton.page()),
        ),
        error: (_, _) => const _NotFound(
          text: 'Could not load this profile. Check your connection.',
        ),
        data: (id) => id == null
            ? const _NotFound(text: 'This profile is not available.')
            : PersonScreen(userId: id),
      );
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('person-not-found'),
    backgroundColor: Calm.bg,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Calm.mut),
        ),
      ),
    ),
  );
}
