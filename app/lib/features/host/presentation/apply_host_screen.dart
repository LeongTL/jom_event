import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/host_repository.dart';
import '../domain/host.dart';
import 'host_parts.dart';

/// Becoming a host (/host-mode/apply), and the same form prefilled to change the host details and payout account
/// (/host-mode/payout-account).
class ApplyHostScreen extends ConsumerWidget {
  const ApplyHostScreen({super.key, this.edit = false});
  final bool edit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!edit) return const _ApplyForm(initial: null);
    return ref
        .watch(hostMeProvider)
        .when(
          loading: () =>
              Scaffold(backgroundColor: Calm.bg, body: hostLoading()),
          error: (_, _) => Scaffold(
            backgroundColor: Calm.bg,
            body: hostFailed('your details'),
          ),
          data: (me) => _ApplyForm(initial: me),
        );
  }
}

class _ApplyForm extends ConsumerStatefulWidget {
  const _ApplyForm({required this.initial});
  final HostProfile? initial;

  @override
  ConsumerState<_ApplyForm> createState() => _ApplyFormState();
}

class _ApplyFormState extends ConsumerState<_ApplyForm> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _bio = TextEditingController(text: widget.initial?.bio);
  late final _holder = TextEditingController(text: widget.initial?.holder);
  late final _bank = TextEditingController(text: widget.initial?.bank);
  late final _number = TextEditingController(
    text: widget.initial?.accountNumber,
  );
  late final _ssm = TextEditingController(text: widget.initial?.ssm);
  late String? _area = widget.initial?.area;
  bool _busy = false;
  String? _error;

  bool get _valid =>
      [_name, _holder, _bank, _number].every((c) => c.text.trim().isNotEmpty) &&
      _area != null;

  Future<void> _submit() async {
    final go = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    String? blank(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await ref
          .read(hostRepositoryProvider)
          .apply(
            HostApplication(
              name: _name.text.trim(),
              area: _area!,
              bio: blank(_bio),
              holder: _holder.text.trim(),
              bank: _bank.text.trim(),
              accountNumber: _number.text.trim(),
              ssm: blank(_ssm),
            ),
          );
      ref.invalidate(hostMeProvider);
      ref.invalidate(hostDashboardProvider);
      go.go(widget.initial == null ? '/host-mode/home' : '/host-mode/profile');
    } on HostError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Scaffold(
      backgroundColor: Calm.bg,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
            children: [
              BookingNav(title: editing ? 'Host details' : 'Become a host'),
              const SoftNote(
                'We pay your earnings to this account 3 working days after each event.',
              ),
              HostField(
                label: 'Host name',
                fieldKey: const Key('apply-name'),
                controller: _name,
                hint: 'What guests will see',
                onChanged: (_) => setState(() {}),
              ),
              FieldBox(
                label: 'Area',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in kAreas.keys)
                      KeyedSubtree(
                        key: Key('apply-area-$a'),
                        child: PickChip(
                          a,
                          on: _area == a,
                          onTap: () => setState(() => _area = a),
                        ),
                      ),
                  ],
                ),
              ),
              HostField(
                label: 'About you (optional)',
                fieldKey: const Key('apply-bio'),
                controller: _bio,
                lines: 3,
                hint: 'A line or two for your host page',
              ),
              HostField(
                label: 'Account holder',
                fieldKey: const Key('apply-holder'),
                controller: _holder,
                onChanged: (_) => setState(() {}),
              ),
              HostField(
                label: 'Bank',
                fieldKey: const Key('apply-bank'),
                controller: _bank,
                onChanged: (_) => setState(() {}),
              ),
              HostField(
                label: 'Account number',
                fieldKey: const Key('apply-number'),
                controller: _number,
                keyboard: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              HostField(
                label: 'Business registration (optional)',
                fieldKey: const Key('apply-ssm'),
                controller: _ssm,
                hint: 'SSM number',
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Calm.bad,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          CtaBar(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: const Key('apply-submit'),
                  child: JomButton(
                    label: editing ? 'Save' : 'Become a host',
                    busy: _busy,
                    onPressed: _valid ? _submit : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
