import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/people_repository.dart';
import '../domain/person.dart';

// Mirrors identity.check_username; the server stays the judge (reserved words, contact-like names, taken).
final _format = RegExp(r'^[a-z0-9_][a-z0-9_.]{1,18}[a-z0-9_]$');
bool _validName(String u) => _format.hasMatch(u) && !u.contains('..');

/// One field: change my @username, with a live "is it free" message.
class EditUsernameScreen extends ConsumerWidget {
  const EditUsernameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    key: const Key('edit-username-screen'),
    backgroundColor: Calm.bg,
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const BookingNav(title: 'Edit username'),
        ref
            .watch(myUsernameProvider)
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Text(
                'Could not load your username. Check your connection.',
                style: TextStyle(color: Calm.mut),
              ),
              data: (u) => _Form(current: u ?? ''),
            ),
      ],
    ),
  );
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.current});
  final String current;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _controller = TextEditingController(text: widget.current);
  Timer? _pause;
  String _status = '';
  bool _good = false; // the name is valid, changed and free
  bool _failed = false; // the status line is an error
  bool _saving = false;

  String get _name => _controller.text.trim().toLowerCase();

  @override
  void dispose() {
    _pause?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _show(String text, {bool good = false, bool failed = false}) =>
      setState(() {
        _status = text;
        _good = good;
        _failed = failed;
      });

  void _changed(String _) {
    _pause?.cancel();
    final name = _name;
    if (name == widget.current || name.isEmpty) return _show('');
    if (!_validName(name)) {
      return _show(
        const UsernameError('username_invalid').message,
        failed: true,
      );
    }
    _show('Checking…');
    _pause = Timer(const Duration(milliseconds: 300), () async {
      try {
        final free = await ref.read(peopleRepositoryProvider).available(name);
        if (!mounted || name != _name) return; // typed on meanwhile
        free
            ? _show('@$name is available', good: true)
            : _show(
                const UsernameError('username_taken').message,
                failed: true,
              );
      } catch (_) {
        if (mounted && name == _name) {
          _show('Could not check. Check your connection.', failed: true);
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final go = GoRouter.of(context);
    try {
      await ref.read(peopleRepositoryProvider).setUsername(_name);
      ref.invalidate(myUsernameProvider);
      go.pop();
    } on UsernameError catch (e) {
      if (mounted) {
        _saving = false;
        _show(e.message, failed: true);
      }
    } catch (_) {
      if (mounted) {
        _saving = false;
        _show(const UsernameError('other').message, failed: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        key: const Key('username-field'),
        controller: _controller,
        onChanged: _changed,
        autocorrect: false,
        enableSuggestions: false,
        maxLength: 20,
        decoration: const InputDecoration(
          prefixText: '@',
          labelText: 'Username',
          counterText: '',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _status,
        key: const Key('username-status'),
        style: TextStyle(
          color: _failed ? Calm.bad : (_good ? Calm.ok : Calm.mut),
          fontSize: 13.5,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'People find you by this name. You can change it any time while no one else has it.',
        style: TextStyle(color: Calm.mut, fontSize: 12.5),
      ),
      const SizedBox(height: 20),
      KeyedSubtree(
        key: const Key('username-save'),
        child: JomButton(
          label: 'Save',
          busy: _saving,
          onPressed: _good ? _save : null,
        ),
      ),
    ],
  );
}
