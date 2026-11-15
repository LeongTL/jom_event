import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/calm.dart';
import '../../shared/widgets/jom_button.dart';
import 'admin_repository.dart';

final _applicationProvider = FutureProvider.autoDispose
    .family<Application, String>(
      (ref, id) => ref.watch(adminRepositoryProvider).application(id),
    );

final _qrProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, path) => ref.watch(adminRepositoryProvider).qrUrl(path),
);

/// One application in full, with Approve and Reject. Leaves (pops) once a decision is saved.
class ApplicationDetail extends ConsumerStatefulWidget {
  const ApplicationDetail({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<ApplicationDetail> createState() => _ApplicationDetailState();
}

class _ApplicationDetailState extends ConsumerState<ApplicationDetail> {
  var _busy = false;
  var _rejecting = false;
  String? _error;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision, {String? reason}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .review(widget.userId, decision, reason: reason);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = adminMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sendReject() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = adminMessage('reason_required'));
      return;
    }
    _decide('reject', reason: reason);
  }

  Widget _row(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Calm.mut, fontSize: 13)),
        Text(
          (value == null || value.isEmpty) ? 'Not given' : value,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(_applicationProvider(widget.userId));
    return Scaffold(
      backgroundColor: Calm.bg,
      appBar: AppBar(
        backgroundColor: Calm.surface,
        title: const Text('Application'),
      ),
      body: app.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(adminMessage(e))),
        data: (a) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: const Key('app-detail'),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  a.hostName,
                  style: const TextStyle(
                    fontFamily: Calm.serif,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _row('Area', a.area),
                _row('About', a.bio),
                _row('SSM number', a.ssmNumber),
                _row('Account holder', a.accountHolder),
                _row('Bank', a.bank),
                _row('Account number', a.accountNumber),
                if (a.qrPath != null) _Qr(path: a.qrPath!),
                const SizedBox(height: 16),
                if (_rejecting) ...[
                  TextField(
                    key: const Key('app-reject-reason'),
                    controller: _reason,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason (the applicant will see it)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  KeyedSubtree(
                    key: const Key('app-reject-send'),
                    child: JomButton(
                      label: 'Send rejection',
                      busy: _busy,
                      onPressed: _sendReject,
                    ),
                  ),
                ] else ...[
                  KeyedSubtree(
                    key: const Key('app-approve'),
                    child: JomButton(
                      label: 'Approve',
                      busy: _busy,
                      onPressed: () => _decide('approve'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  KeyedSubtree(
                    key: const Key('app-reject'),
                    child: JomButton(
                      label: 'Reject',
                      primary: false,
                      onPressed: () => setState(() => _rejecting = true),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Calm.bad)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Qr extends ConsumerWidget {
  const _Qr({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(_qrProvider(path)).value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DuitNow QR',
            style: TextStyle(color: Calm.mut, fontSize: 13),
          ),
          if (url != null)
            Image.network(
              url,
              key: const Key('app-qr'),
              height: 220,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, _, _) => const Text("Couldn't load the QR."),
            ),
        ],
      ),
    );
  }
}
