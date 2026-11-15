import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/calm.dart';
import 'admin_repository.dart';
import 'application_detail.dart';

/// Pending host applications, oldest first. Tap one to read it and decide.
class ApplicationsPage extends ConsumerWidget {
  const ApplicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(pendingApplicationsProvider);
    return list.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: TextButton(
          onPressed: () => ref.invalidate(pendingApplicationsProvider),
          child: Text('${adminMessage(e)} Tap to retry.'),
        ),
      ),
      data: (rows) => rows.isEmpty
          ? const Center(
              child: Text(
                'No applications waiting.',
                key: Key('app-empty'),
                style: TextStyle(color: Calm.mut),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final r in rows)
                  Card(
                    key: Key('app-row-${r.userId}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(r.hostName),
                      subtitle: Text(
                        '${r.area} · applied ${r.createdAt.toLocal().toString().substring(0, 10)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ApplicationDetail(userId: r.userId),
                          ),
                        );
                        ref.invalidate(pendingApplicationsProvider);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
