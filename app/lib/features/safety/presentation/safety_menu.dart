import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../chat/data/chat_repository.dart';
import '../data/safety_repository.dart';
import '../domain/safety.dart';

/// The round "more" button with Report (and, for a person, Block). [menuKey] is the key the caller picks
/// (`person-menu`, `chat-menu`, `event-menu`).
class SafetyMenu extends ConsumerWidget {
  const SafetyMenu.person({
    super.key,
    required this.menuKey,
    required String this.userId,
    required String this.name,
  }) : eventId = null;

  const SafetyMenu.event({
    super.key,
    required this.menuKey,
    required String this.eventId,
  }) : userId = null,
       name = null;

  final Key menuKey;
  final String? userId, name, eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    key: menuKey,
    tooltip: 'More',
    onSelected: (v) {
      if (v == 'report') {
        showReportSheet(
          context,
          userId != null ? ReportTarget.user : ReportTarget.event,
          (userId ?? eventId)!,
        );
      } else {
        confirmBlock(context, ref, userId!, name!);
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        key: Key(eventId != null ? 'event-report' : 'menu-report'),
        value: 'report',
        child: Text(eventId != null ? 'Report this event' : 'Report'),
      ),
      if (userId != null)
        const PopupMenuItem(
          key: Key('menu-block'),
          value: 'block',
          child: Text('Block'),
        ),
    ],
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.more_horiz, size: 22, color: Calm.ink),
    ),
  );
}

Future<void> confirmBlock(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String name,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Block $name?'),
      content: const Text(
        'They will not be able to find you, follow you or message you. You can unblock them in Profile.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('block-confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (yes != true) return;
  try {
    await ref.read(safetyRepositoryProvider).block(userId);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(safetyMessage('other'))));
    return;
  }
  ref.invalidate(blockedUsersProvider);
  ref.invalidate(chatThreadsProvider);
  messenger.showSnackBar(SnackBar(content: Text('$name is blocked.')));
  router.canPop() ? router.pop() : router.go('/explore');
}

/// Pick a reason, optionally add a note, send. Nothing is shown to the person reported.
Future<void> showReportSheet(
  BuildContext context,
  ReportTarget target,
  String targetId,
) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Calm.bg,
    builder: (_) =>
        _ReportSheet(target: target, targetId: targetId, messenger: messenger),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.target,
    required this.targetId,
    required this.messenger,
  });
  final ReportTarget target;
  final String targetId;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(safetyRepositoryProvider)
          .report(
            target: widget.target,
            targetId: widget.targetId,
            reason: reason,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.messenger.showSnackBar(
        const SnackBar(content: Text('Thanks, we will look at it.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = safetyMessage('other');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              switch (widget.target) {
                ReportTarget.user => 'Report this person',
                ReportTarget.event => 'Report this event',
                ReportTarget.message => 'Report this message',
              },
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Why are you reporting it? They will not be told.',
              style: TextStyle(color: Calm.mut, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final r in ReportReason.values)
              ListTile(
                key: Key('report-reason-${r.wire}'),
                contentPadding: EdgeInsets.zero,
                title: Text(r.label),
                trailing: Icon(
                  _reason == r
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Calm.acc,
                ),
                onTap: () => setState(() => _reason = r),
              ),
            TextField(
              key: const Key('report-note'),
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Add a note (optional)',
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Calm.bad)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('report-submit'),
                onPressed: _reason == null || _busy ? null : _submit,
                child: const Text('Send report'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
